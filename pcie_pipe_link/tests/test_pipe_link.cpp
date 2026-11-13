#include "Vclock.h"
#include "verilated.h"
#include <cstdlib>
#include <cstdint>
#include <iostream>

double sc_time_stamp() { return 0; }
static void check(bool ok, const char* text) {
    if (!ok) { std::cerr << text << '\n'; std::exit(1); }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vclock d;
    unsigned time = 0, ack_dsp = 0, ack_usp = 0;
    bool stop_gen5 = false;
    bool retain_clock_permission = false;
    auto tick = [&]() {
        d.pclk_62p5 = (time / 32) & 1;
        d.pclk_125 = ((time + 3) / 16) & 1;
        d.pclk_250 = ((time + 5) / 8) & 1;
        d.pclk_500 = ((time + 7) / 4) & 1;
        d.pclk_1000 = !stop_gen5 && (((time + 1) / 2) & 1);
        d.eval();
        ack_dsp |= d.dsp_phy_mac_phystatus;
        ack_usp |= d.usp_phy_mac_phystatus;
        if (retain_clock_permission) {
            check(d.dsp_phy_ref_clk_req_n && d.usp_phy_ref_clk_req_n,
                  "Low-power transition revoked existing clock permission");
        } else {
            if (d.dsp_phy_ref_clk_req_n) check(ack_dsp == 15, "DSP released clock before all ACKs");
            if (d.usp_phy_ref_clk_req_n) check(ack_usp == 15, "USP released clock before all ACKs");
        }
        ++time;
    };
    auto run = [&](int n) { while (n--) tick(); };
    auto data_on = [&]() {
        check(d.dsp_phy_mac_rxvalid == 15 && d.usp_phy_mac_rxvalid == 15,
              "Gen5 bidirectional data not enabled");
        check(d.dsp_phy_mac_rxdatavalid == 15 && d.usp_phy_mac_rxdatavalid == 15,
              "Gen5 data valid missing");
    };
    d.dsp_phy_rst_n = 0;
    d.usp_phy_rst_n = 0;
    d.dsp_mac_phy_txdatavalid = 15;
    d.usp_mac_phy_txdatavalid = 15;
    run(100);
    d.dsp_phy_rst_n = 1;
    d.usp_phy_rst_n = 1;
    run(3000);
    d.dsp_mac_phy_rate = 4;
    run(3000);
    check(d.dsp_active_rate == 4 && d.usp_active_rate == 0, "Independent Gen5 switch failed");
    check(d.dsp_phy_mac_rxvalid == 0 && d.usp_phy_mac_rxvalid == 0, "Rate mismatch leaked data");
    d.usp_mac_phy_rate = 4;
    run(3000);
    data_on();
    check((d.dsp_phy_mac_localfs & 63) == 47 && (d.dsp_phy_mac_locallf & 63) == 15,
          "Gen5 FS/LF mismatch");
    // PIPE 4.4 preset P4 is encoded as 15 at Gen4/Gen5; it maps to C0=47.
    // Distinct 6-bit lane fields; index 47 must not truncate to valid index 15.
    d.dsp_mac_phy_local_pset_index = 15 | (16 << 6) | (47 << 12) | (15 << 18);
    d.dsp_mac_phy_getlocal_pset_coef = 15;
    unsigned valid_seen = 0;
    for (int i = 0; i < 40; ++i) {
        tick();
        if (d.dsp_phy_mac_local_tx_coef_valid & 1) {
            valid_seen = 1;
            check(d.dsp_phy_mac_local_tx_coef_valid == 15, "Preset valid missing on a lane");
            const unsigned expected[] = {47 << 6, (42 << 6) | 5, 0, 47 << 6};
            for (unsigned lane = 0; lane < 4; ++lane) {
                unsigned bit = lane * 18;
                uint64_t packed = d.dsp_phy_mac_local_tx_pset_coef[bit / 32];
                packed |= uint64_t(d.dsp_phy_mac_local_tx_pset_coef[bit / 32 + 1]) << 32;
                check(((packed >> (bit % 32)) & 0x3ffff) == expected[lane],
                      "6-bit lane preset mapping mismatch");
            }
        }
    }
    check(valid_seen, "Gen5 preset result missing");
    d.dsp_mac_phy_getlocal_pset_coef = 0;
    run(100);
    ack_dsp = 0;
    d.dsp_mac_phy_rxeqeval = 15;
    run(1000);
    check(ack_dsp == 15 && (d.dsp_phy_mac_fomfeedback & 255) == 255,
          "Gen5 EQ completion missing");
    d.dsp_mac_phy_rxeqeval = 0;
    run(100);
    // One side enters low power without waiting for its peer to follow.
    ack_dsp = 0;
    d.dsp_mac_phy_powerdown = 5;
    run(1000);
    check(d.dsp_phy_mac_phystatus == 15 && !d.usp_phy_ref_clk_req_n,
          "Independent low-power status failed");
    d.dsp_mac_phy_asyncpowerchangeack = 1;
    run(1000);
    d.dsp_mac_phy_asyncpowerchangeack = 0;
    run(1000);
    check(d.dsp_phy_ref_clk_req_n && !d.usp_phy_ref_clk_req_n && d.usp_clock_ready,
          "One side changed peer clock request");
    d.dsp_mac_phy_powerdown = 0;
    run(1000);
    data_on();
    for (int power : {4, 5, 6, 4}) {
        ack_dsp = ack_usp = 0;
        d.dsp_mac_phy_powerdown = power;
        d.usp_mac_phy_powerdown = power;
        d.eval();
        check(!d.dsp_phy_ref_clk_req_n && !d.usp_phy_ref_clk_req_n,
              "Power transition did not reassert clock request");
        run(3000);
        check(ack_dsp == 15 && ack_usp == 15, "PowerDown completion missing");
        bool released = power == 4 || power == 5 || power == 6;
        if (power == 5 || power == 6) {
            check(d.dsp_phy_mac_phystatus == 15 && d.usp_phy_mac_phystatus == 15,
                  "Asynchronous status not held until ACK");
            check(!d.dsp_phy_ref_clk_req_n && !d.usp_phy_ref_clk_req_n,
                  "Clock released before asynchronous handshake");
            d.dsp_mac_phy_asyncpowerchangeack = 1;
            d.usp_mac_phy_asyncpowerchangeack = 1;
            run(1000);
            check(!d.dsp_phy_mac_phystatus && !d.usp_phy_mac_phystatus,
                  "Asynchronous status did not clear after ACK");
            check(!d.dsp_phy_ref_clk_req_n && !d.usp_phy_ref_clk_req_n,
                  "Clock released before ACK returned LOW");
            d.dsp_mac_phy_asyncpowerchangeack = 0;
            d.usp_mac_phy_asyncpowerchangeack = 0;
            run(1000);
        }
        check(d.dsp_phy_ref_clk_req_n == released && d.usp_phy_ref_clk_req_n == released,
              "Wrong shared reference clock request");
        if (power >= 4) {
            check(d.dsp_phy_mac_rxvalid == 0 && d.usp_phy_mac_rxvalid == 0 &&
                  d.dsp_phy_mac_rxelecidle == 15 && d.usp_phy_mac_rxelecidle == 15,
                  "L1 state did not isolate receive data");
        } else data_on();
        if (released) {
            // Stop selected source LOW, keep management reference running.
            while (d.pclk_1000) tick();
            stop_gen5 = true;
            run(200);
            check(d.dsp_phy_ref_clk_req_n && d.usp_phy_ref_clk_req_n,
                  "Clock permission lost while PCLK stopped");
            d.dsp_mac_phy_powerdown = 0;
            d.usp_mac_phy_powerdown = 0;
            d.eval();
            check(!d.dsp_phy_ref_clk_req_n && !d.usp_phy_ref_clk_req_n,
                  "Wake request depends on stopped PCLK");
            stop_gen5 = false;
            run(3000);
            data_on();
        }
    }
    // Direct P1.CPM -> P1.1/P1.2 transitions with selected PCLK stopped.
    for (int target : {5, 6}) {
        d.dsp_mac_phy_powerdown = 4;
        d.usp_mac_phy_powerdown = 4;
        run(3000);
        check(d.dsp_phy_ref_clk_req_n && d.usp_phy_ref_clk_req_n,
              "P1.CPM did not release clock before direct transition");
        while (d.pclk_1000) tick();
        stop_gen5 = true;
        run(200);
        retain_clock_permission = true;
        d.dsp_mac_phy_powerdown = target;
        d.usp_mac_phy_powerdown = target;
        ack_dsp = ack_usp = 0;
        run(3000);
        check(d.dsp_phy_mac_phystatus == 15 && d.usp_phy_mac_phystatus == 15,
              "Direct 4->5/6 lost PhyStatus with PCLK stopped");
        d.dsp_mac_phy_asyncpowerchangeack = 1;
        d.usp_mac_phy_asyncpowerchangeack = 1;
        run(1000);
        check(!d.dsp_phy_mac_phystatus && !d.usp_phy_mac_phystatus,
              "Direct transition status not cleared by ACK");
        d.dsp_mac_phy_asyncpowerchangeack = 0;
        d.usp_mac_phy_asyncpowerchangeack = 0;
        run(1000);
        check(d.dsp_phy_ref_clk_req_n && d.usp_phy_ref_clk_req_n,
              "Direct transition handshake failed");
        d.dsp_mac_phy_powerdown = target == 5 ? 6 : 5;
        d.usp_mac_phy_powerdown = target == 5 ? 6 : 5;
        run(3000);
        check(d.dsp_phy_mac_phystatus == 15 && d.usp_phy_mac_phystatus == 15,
              "5/6 transition lost asynchronous status");
        d.dsp_mac_phy_asyncpowerchangeack = 1;
        d.usp_mac_phy_asyncpowerchangeack = 1;
        run(1000);
        d.dsp_mac_phy_asyncpowerchangeack = 0;
        d.usp_mac_phy_asyncpowerchangeack = 0;
        run(1000);
        ack_dsp = ack_usp = 0;
        d.dsp_mac_phy_powerdown = 4;
        d.usp_mac_phy_powerdown = 4;
        run(1000);
        check(!ack_dsp && !ack_usp, "P1.CPM pulse appeared with PCLK stopped");
        stop_gen5 = false;
        run(3000);
        check(ack_dsp == 15 && ack_usp == 15,
              "5/6->4 lost completion after PCLK resumed");
        retain_clock_permission = false;
        d.dsp_mac_phy_powerdown = 0;
        d.usp_mac_phy_powerdown = 0;
        stop_gen5 = false;
        run(3000);
    }
    d.dsp_phy_rst_n = 0;
    d.eval();
    check(!d.dsp_phy_ref_clk_req_n, "Reset did not request reference clock");
    std::cout << "PASS: Gen5 independent rates, data, EQ preset, PowerDown 4/5/6, clock stop/wake\n";
}
