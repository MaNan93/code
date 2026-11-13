#include "Vclock.h"
#include "verilated.h"
#include <cstdint>
#include <cstdlib>
#include <iostream>

double sc_time_stamp() { return 0; }

static void require(bool ok, const char* message) {
    if (!ok) { std::cerr << message << '\n'; std::exit(1); }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vclock dut;
    uint64_t time = 0, rise = 0, fall = 0, edges = 0;
    bool previous = false, monitor = false;
    int previous_sources = 0;
    const int half_period[] = {32, 16, 8, 4, 2};
    const int phase[] = {0, 3, 5, 7, 1};
    auto tick = [&]() {
        int sources = 0;
        for (int i = 0; i < 5; ++i)
            sources |= (((time + phase[i]) / half_period[i]) & 1) << i;
        dut.pclk_62p5 = sources & 1;
        dut.pclk_125 = (sources >> 1) & 1;
        dut.pclk_250 = (sources >> 2) & 1;
        dut.pclk_500 = (sources >> 3) & 1;
        dut.pclk_1000 = (sources >> 4) & 1;
        dut.eval();
        bool output = dut.pclk;
        if (!dut.phy_rst_n) monitor = false;
        if (output != previous && dut.phy_rst_n) {
            if (output) {
                require((sources & ~previous_sources) != 0,
                        "PCLK rose away from a source rising edge");
                if (monitor) require(time - fall >= 2, "Short PCLK low pulse");
                rise = time;
            } else {
                require((previous_sources & ~sources) != 0,
                        "PCLK fell away from a source falling edge");
                if (monitor) {
                    auto width = time - rise;
                    require(width == 2 || width == 4 || width == 8 || width == 16 || width == 32,
                            "Truncated or extended PCLK high pulse");
                }
                fall = time;
                monitor = true;
            }
            ++edges;
        }
        previous = output;
        previous_sources = sources;
        ++time;
    };
    auto run = [&](int count) { while (count--) tick(); };
    auto settle = [&](int rate) {
        dut.rate_request = rate;
        run(2000);
        require(dut.clock_ready && dut.active_rate == rate, "Clock failed to settle");
        for (int i = 0; i < 512; ++i) {
            tick();
            require(dut.pclk == ((previous_sources >> rate) & 1),
                    "Stable PCLK differs from selected source");
        }
    };
    dut.phy_rst_n = 0;
    dut.rate_request = 0;
    run(100);
    dut.phy_rst_n = 1;
    settle(0);
    for (int from = 0; from < 5; ++from) {
        for (int to = 0; to < 5; ++to) {
            settle(from);
            settle(to);
        }
    }
    for (int invalid = 5; invalid < 8; ++invalid) {
        dut.rate_request = invalid;
        run(1000);
        require(dut.active_rate == 4, "Invalid rate changed active source");
    }
    // Reset is deliberately excluded from pulse-width guarantees.
    dut.phy_rst_n = 0;
    run(100);
    dut.rate_request = 0;
    dut.phy_rst_n = 1;
    settle(0);
    std::cout << "PASS: all 25 rate pairs, phase offsets, invalid rates, reset; "
              << edges << " PCLK edges checked\n";
}
