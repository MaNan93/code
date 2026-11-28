#include "Vpcie_pipe_pclk_switch.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <vector>

static vluint64_t sim_time = 0;

struct ClockState {
    uint64_t next_edge_ps[5]{8000, 4000, 2000, 1000, 500};
    uint64_t half_period_ps[5]{8000, 4000, 2000, 1000, 500};
    bool level[5]{false, false, false, false, false};
};

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    auto *dut = new Vpcie_pipe_pclk_switch;

    ClockState clks;
    dut->pclk_62p5 = 0;
    dut->pclk_125  = 0;
    dut->pclk_250  = 0;
    dut->pclk_500  = 0;
    dut->pclk_1000 = 0;
    dut->phy_rst_n = 0;
    dut->clk_en    = 1;
    dut->rate_req  = 0;
    dut->eval();

    bool prev_pclk = dut->pclk;
    uint64_t last_edge_ps = 0;
    uint64_t min_pulse_ps = UINT64_MAX;
    bool monitor_pulses = false;

    auto step_until = [&](uint64_t target_ps) {
        while (sim_time < target_ps) {
            uint64_t nxt = target_ps;
            for (int i = 0; i < 5; i++) {
                if (clks.next_edge_ps[i] < nxt) nxt = clks.next_edge_ps[i];
            }
            sim_time = nxt;
            for (int i = 0; i < 5; i++) {
                if (clks.next_edge_ps[i] == sim_time) {
                    clks.level[i] = !clks.level[i];
                    clks.next_edge_ps[i] += clks.half_period_ps[i];
                }
            }
            dut->pclk_62p5 = clks.level[0];
            dut->pclk_125  = clks.level[1];
            dut->pclk_250  = clks.level[2];
            dut->pclk_500  = clks.level[3];
            dut->pclk_1000 = clks.level[4];
            dut->eval();

            bool cur_pclk = dut->pclk;
            if (cur_pclk != prev_pclk) {
                if (monitor_pulses && last_edge_ps > 0) {
                    uint64_t width = sim_time - last_edge_ps;
                    if (width < 450) {
                        std::cerr << "FAIL: Runt clock pulse width=" << width
                                  << "ps at t=" << sim_time << "ps rate="
                                  << int(dut->active_rate) << "\n";
                        std::exit(1);
                    }
                    if (width < min_pulse_ps) min_pulse_ps = width;
                }
                last_edge_ps = sim_time;
                prev_pclk = cur_pclk;
            }
        }
    };

    // Hold reset for 100ns
    step_until(100000);
    dut->phy_rst_n = 1;
    step_until(160000);
    monitor_pulses = true;

    if (!dut->clock_ready || dut->active_rate != 0) {
        std::cerr << "FAIL: Reset state ready=" << int(dut->clock_ready)
                  << " active_rate=" << int(dut->active_rate) << "\n";
        return 1;
    }

    // Sweep Gen1..Gen6 (including rate 4 <-> 5 sharing pclk_1000 and down-switch)
    std::vector<int> rates = {1, 2, 3, 4, 5, 4, 5, 2, 0, 5, 0};
    for (int r : rates) {
        dut->rate_req = r;
        dut->eval();
        uint64_t start = sim_time;
        bool switched = false;
        for (int step = 0; step < 500; step++) {
            step_until(sim_time + 1000);
            if (dut->clock_ready && dut->active_rate == r) {
                switched = true;
                break;
            }
        }
        if (!switched) {
            std::cerr << "FAIL: Timeout switching to rate " << r
                      << " (active=" << int(dut->active_rate)
                      << " ready=" << int(dut->clock_ready) << ")\n";
            return 1;
        }
        // Hold rate for 40ns and count edges
        uint64_t hold_end = sim_time + 40000;
        int edges = 0;
        bool p = dut->pclk;
        while (sim_time < hold_end) {
            step_until(sim_time + 250);
            if (dut->pclk && !p) edges++;
            p = dut->pclk;
        }
        if (edges < 2) {
            std::cerr << "FAIL: Too few edges (" << edges << ") at rate " << r << "\n";
            return 1;
        }
        (void)start;
    }

    // Test Dynamic MAXPCLK gating via clk_en=0 / clk_en=1 at Gen6 (rate=5)
    dut->rate_req = 5;
    step_until(sim_time + 40000);
    dut->clk_en = 0;
    bool gated = false;
    for (int i = 0; i < 200; i++) {
        step_until(sim_time + 1000);
        if (dut->clk_gated) {
            gated = true;
            break;
        }
    }
    if (!gated || dut->pclk != 0 || dut->clock_ready != 0) {
        std::cerr << "FAIL: clk_en=0 did not cleanly gate clock (gated=" << gated
                  << " pclk=" << int(dut->pclk) << ")\n";
        return 1;
    }
    // Verify zero transitions while gated
    for (int i = 0; i < 50; i++) {
        step_until(sim_time + 1000);
        if (dut->pclk != 0) {
            std::cerr << "FAIL: pclk toggled while gated!\n";
            return 1;
        }
    }

    dut->clk_en = 1;
    bool un_gated = false;
    for (int i = 0; i < 200; i++) {
        step_until(sim_time + 1000);
        if (dut->clock_ready && !dut->clk_gated && dut->active_rate == 5) {
            un_gated = true;
            break;
        }
    }
    if (!un_gated) {
        std::cerr << "FAIL: clk_en=1 did not resume Gen6 clock cleanly\n";
        return 1;
    }

    std::cout << "PASS: test_clock_switch (Gen1..Gen6 + always_latch+and + clk_en gating, min_half_period="
              << min_pulse_ps << "ps)\n";
    delete dut;
    return 0;
}
