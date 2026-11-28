#include "Vpcie_pipe_link.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>
#include <vector>

static vluint64_t sim_time = 0;

struct Clocks {
    uint64_t next_edge_ps[5]{8000, 4000, 2000, 1000, 500};
    uint64_t half_period_ps[5]{8000, 4000, 2000, 1000, 500};
    bool level[5]{false, false, false, false, false};
};

// Helper to get/set 80-bit per-lane slices in Verilator wide vector (WData words, NL=4 -> 320b -> 10 words)
static void set_lane_u64(uint32_t *vec, int lane, int width_bits, uint64_t lo, uint16_t hi16) {
    int base = lane * width_bits;
    for (int b = 0; b < width_bits; b++) {
        int word = (base + b) / 32;
        int bit  = (base + b) % 32;
        uint64_t v = (b < 64) ? ((lo >> b) & 1ULL) : ((hi16 >> (b - 64)) & 1ULL);
        if (v) vec[word] |= (1U << bit);
        else   vec[word] &= ~(1U << bit);
    }
}

static void get_lane_u80(const uint32_t *vec, int lane, int width_bits, uint64_t &lo, uint16_t &hi16) {
    lo = 0;
    hi16 = 0;
    int base = lane * width_bits;
    for (int b = 0; b < width_bits; b++) {
        int word = (base + b) / 32;
        int bit  = (base + b) % 32;
        uint64_t v = (vec[word] >> bit) & 1ULL;
        if (b < 64) lo |= (v << b);
        else        hi16 |= static_cast<uint16_t>(v << (b - 64));
    }
}

static void set_bits_field(uint32_t *vec, int lane, int width_bits, uint32_t val) {
    int base = lane * width_bits;
    for (int b = 0; b < width_bits; b++) {
        int word = (base + b) / 32;
        int bit  = (base + b) % 32;
        if ((val >> b) & 1U) vec[word] |= (1U << bit);
        else                 vec[word] &= ~(1U << bit);
    }
}

static uint32_t get_bits_field(const uint32_t *vec, int lane, int width_bits) {
    uint32_t out = 0;
    int base = lane * width_bits;
    for (int b = 0; b < width_bits; b++) {
        int word = (base + b) / 32;
        int bit  = (base + b) % 32;
        out |= ((vec[word] >> bit) & 1U) << b;
    }
    return out;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    auto *dut = new Vpcie_pipe_link; // NL=4, DATA_WD=80, TXEI_WD=4, DIRFEEDBACK_WD=12, MAX_RATE=5

    Clocks clks;
    auto init_side = [&]() {
        dut->dsp_phy_rst_n = 0;
        dut->usp_phy_rst_n = 0;
        dut->dsp_mac_phy_maxpclkreq_n = 0;
        dut->usp_mac_phy_maxpclkreq_n = 0;
        dut->dsp_mac_phy_rate = 0;
        dut->usp_mac_phy_rate = 0;
        dut->dsp_mac_phy_powerdown = 0x2222; // P1 per lane
        dut->usp_mac_phy_powerdown = 0x2222;
        dut->dsp_mac_phy_txelecidle = 0xFFFF; // 4 bits per lane = all idle
        dut->usp_mac_phy_txelecidle = 0xFFFF;
        dut->dsp_mac_phy_txdatavalid = 0xF;
        dut->usp_mac_phy_txdatavalid = 0xF;
        dut->dsp_mac_phy_txdetectrx_loopback = 0;
        dut->usp_mac_phy_txdetectrx_loopback = 0;
        dut->dsp_mac_phy_rxstandby = 0;
        dut->usp_mac_phy_rxstandby = 0;
        dut->dsp_mac_phy_rxpolarity = 0;
        dut->usp_mac_phy_rxpolarity = 0;
        dut->dsp_serdes_pipe_turnoff_lanes = 0;
        dut->usp_serdes_pipe_turnoff_lanes = 0;
        dut->dsp_serdes_pipe_rxready = 0xF;
        dut->usp_serdes_pipe_rxready = 0xF;
        dut->dsp_mac_phy_rxeqeval = 0;
        dut->usp_mac_phy_rxeqeval = 0;
        dut->dsp_mac_phy_rxeqinprogress = 0;
        dut->usp_mac_phy_rxeqinprogress = 0;
        dut->dsp_mac_phy_getlocal_pset_coef = 0;
        dut->usp_mac_phy_getlocal_pset_coef = 0;
    };
    init_side();
    dut->eval();

    auto step_ps = [&](uint64_t delta_ps) {
        uint64_t target = sim_time + delta_ps;
        while (sim_time < target) {
            uint64_t nxt = target;
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
            // pclk_as_phy_input loop: controller o_pclk mirrors max_pclk
            dut->eval();
            dut->dsp_pclk = dut->dsp_max_pclk;
            dut->usp_pclk = dut->usp_max_pclk;
            dut->eval();
        }
    };

    // 1. Reset and align all 4 lanes at Gen1 (rate=0)
    step_ps(100000);
    dut->dsp_phy_rst_n = 0xF;
    dut->usp_phy_rst_n = 0xF;
    for (int i = 0; i < 500; i++) {
        step_ps(1000);
        if (dut->clocks_aligned == 0xF && dut->dsp_phy_mac_phystatus == 0 && dut->usp_phy_mac_phystatus == 0)
            break;
    }
    if (dut->clocks_aligned != 0xF) {
        std::cerr << "FAIL: Initial Gen1 clocks_aligned=" << int(dut->clocks_aligned) << "\n";
        return 1;
    }

    // 2. RxDetect in P1 across all 4 lanes
    dut->dsp_mac_phy_txdetectrx_loopback = 0xF;
    uint8_t detected_mask = 0;
    for (int i = 0; i < 400; i++) {
        step_ps(1000);
        for (int l = 0; l < 4; l++) {
            uint8_t st = (dut->dsp_phy_mac_rxstatus >> (l * 3)) & 0x7;
            if (((dut->dsp_phy_mac_phystatus >> l) & 1) && st == 3) detected_mask |= (1U << l);
        }
        if (detected_mask == 0xF) break;
    }
    dut->dsp_mac_phy_txdetectrx_loopback = 0;
    if (detected_mask != 0xF) {
        std::cerr << "FAIL: RxDetect detected_mask=0x" << std::hex << int(detected_mask) << "\n";
        return 1;
    }

    // 3. P1 -> P0 transition & Gen6 (rate=5, g6_8s 80b/lane) upgrade
    dut->dsp_mac_phy_powerdown = 0x0000;
    dut->usp_mac_phy_powerdown = 0x0000;
    dut->dsp_mac_phy_rate = (5 << 9) | (5 << 6) | (5 << 3) | 5;
    dut->usp_mac_phy_rate = (5 << 9) | (5 << 6) | (5 << 3) | 5;
    bool gen6_ready = false;
    for (int i = 0; i < 1000; i++) {
        step_ps(1000);
        if (dut->clocks_aligned == 0xF &&
            dut->dsp_active_rate == ((5 << 9) | (5 << 6) | (5 << 3) | 5) &&
            dut->usp_active_rate == ((5 << 9) | (5 << 6) | (5 << 3) | 5)) {
            gen6_ready = true;
            break;
        }
    }
    if (!gen6_ready) {
        std::cerr << "FAIL: Gen6 transition failed\n";
        return 1;
    }
    step_ps(30000); // settle P0 + Gen6

    // 4. EQ check at Gen6 (local coef + eval + dirfeedback)
    dut->dsp_mac_phy_getlocal_pset_coef = 0xF;
    set_bits_field(&dut->dsp_mac_phy_local_pset_index, 0, 6, 4);
    dut->dsp_mac_phy_rxeqinprogress = 0xF;
    dut->dsp_mac_phy_rxeqeval = 0xF;
    bool eq_done = false;
    uint32_t fom0 = 0;
    for (int i = 0; i < 200; i++) {
        step_ps(500);
        if ((dut->dsp_phy_mac_phystatus & 1) && get_bits_field(&dut->dsp_phy_mac_fomfeedback[0], 0, 8) != 0) {
            fom0 = get_bits_field(&dut->dsp_phy_mac_fomfeedback[0], 0, 8);
            eq_done = true;
            break;
        }
    }
    dut->dsp_mac_phy_getlocal_pset_coef = 0;
    dut->dsp_mac_phy_rxeqeval = 0;
    dut->dsp_mac_phy_rxeqinprogress = 0;
    if (!eq_done || fom0 != 0x38) {
        std::cerr << "FAIL: Gen6 EQ check eq_done=" << eq_done << " fom0=0x" << std::hex << fom0 << "\n";
        return 1;
    }

    // 5. Bidirectional 80-bit SerDes traffic on Gen6 across all 4 lanes + 4-bit partial idle test
    dut->dsp_mac_phy_txelecidle = 0x0000;
    dut->usp_mac_phy_txelecidle = 0x0000;
    set_lane_u64(dut->dsp_mac_phy_txdata.data(), 0, 80, 0xCAFEBABE12345678ULL, 0x00A5);
    set_lane_u64(dut->usp_mac_phy_txdata.data(), 3, 80, 0xDEADBEEF87654321ULL, 0x005A);

    bool seen_d2u = false, seen_u2d = false;
    for (int i = 0; i < 200; i++) {
        step_ps(500);
        uint64_t lo = 0; uint16_t hi = 0;
        if ((dut->usp_phy_mac_rxvalid & 1) && !(dut->usp_phy_mac_rxelecidle & 1)) {
            get_lane_u80(dut->usp_phy_mac_rxdata.data(), 0, 80, lo, hi);
            if (lo == 0xCAFEBABE12345678ULL && hi == 0x00A5) seen_d2u = true;
        }
        if ((dut->dsp_phy_mac_rxvalid & 8) && !(dut->dsp_phy_mac_rxelecidle & 8)) {
            get_lane_u80(dut->dsp_phy_mac_rxdata.data(), 3, 80, lo, hi);
            if (lo == 0xDEADBEEF87654321ULL && hi == 0x005A) seen_u2d = true;
        }
        if (seen_d2u && seen_u2d) break;
    }
    if (!seen_d2u || !seen_u2d) {
        std::cerr << "FAIL: Gen6 80b traffic failed d2u=" << seen_d2u << " u2d=" << seen_u2d << "\n";
        return 1;
    }

    // Partial 4-bit txelecidle (4'b1100) must still keep lane active until 4'b1111
    dut->dsp_mac_phy_txelecidle = 0x000C; // lane 0 partial idle = 4'b1100
    step_ps(15000);
    if (dut->usp_phy_mac_rxelecidle & 1) {
        std::cerr << "FAIL: Partial txelecidle 4'b1100 incorrectly forced rxelecidle=1!\n";
        return 1;
    }
    dut->dsp_mac_phy_txelecidle = 0x000F; // lane 0 all idle = 4'b1111
    bool went_idle = false;
    for (int i = 0; i < 100; i++) {
        step_ps(500);
        if ((dut->usp_phy_mac_rxelecidle & 1) && !(dut->usp_phy_mac_rxvalid & 1)) {
            went_idle = true;
            break;
        }
    }
    if (!went_idle) {
        std::cerr << "FAIL: Full 4'b1111 txelecidle did not set rxelecidle=1\n";
        return 1;
    }

    // 6. Per-lane Bifurcation Test + Dynamic MAXPCLK gating:
    // Lanes [1:0] remain Gen6 (rate=5, P0) actively transferring 80b data;
    // Lane  [2]   switches to Gen3 (rate=2, P0) independently transferring 80b data;
    // Lane  [3]   goes into L1 with maxpclkreq_n=1 (clk gated) -> verify ZERO impact on lanes [2:0]!
    dut->dsp_mac_phy_txelecidle = 0xF000; // lanes 0,1,2 active; lane 3 idle
    dut->usp_mac_phy_txelecidle = 0xF000;
    // Set rate: lane0=5, lane1=5, lane2=2, lane3=0
    uint16_t bif_rate = (0 << 9) | (2 << 6) | (5 << 3) | 5;
    dut->dsp_mac_phy_rate = bif_rate;
    dut->usp_mac_phy_rate = bif_rate;
    // Gate maxpclk on lane 3 only
    dut->dsp_mac_phy_powerdown = 0x2000; // lane 3 P1, lanes 0..2 P0
    dut->usp_mac_phy_powerdown = 0x2000;
    dut->dsp_mac_phy_maxpclkreq_n = 0x8;
    dut->usp_mac_phy_maxpclkreq_n = 0x8;

    bool bif_ready = false;
    for (int i = 0; i < 1000; i++) {
        step_ps(1000);
        if (dut->clocks_aligned == 0x7 &&
            dut->dsp_active_rate == bif_rate &&
            (dut->dsp_phy_mac_maxpclkack_n & 0x8) == 0x8 &&
            (dut->dsp_phy_mac_maxpclkack_n & 0x7) == 0x0) {
            bif_ready = true;
            break;
        }
    }
    if (!bif_ready) {
        std::cerr << "FAIL: Bifurcated mixed-rate/maxpclk state failed aligned=0x"
                  << std::hex << int(dut->clocks_aligned)
                  << " ack=0x" << int(dut->dsp_phy_mac_maxpclkack_n) << "\n";
        return 1;
    }

    set_lane_u64(dut->dsp_mac_phy_txdata.data(), 1, 80, 0x1122334455667788ULL, 0x0099);
    set_lane_u64(dut->usp_mac_phy_txdata.data(), 2, 80, 0x99AABBCCDDEEFF00ULL, 0x003C);
    bool l1_ok = false, l2_ok = false;
    for (int i = 0; i < 400; i++) {
        step_ps(500);
        uint64_t lo = 0; uint16_t hi = 0;
        if (dut->usp_phy_mac_rxvalid & 0x2) {
            get_lane_u80(dut->usp_phy_mac_rxdata.data(), 1, 80, lo, hi);
            if (lo == 0x1122334455667788ULL && hi == 0x0099) l1_ok = true;
        }
        if (dut->dsp_phy_mac_rxvalid & 0x4) {
            get_lane_u80(dut->dsp_phy_mac_rxdata.data(), 2, 80, lo, hi);
            if (lo == 0x99AABBCCDDEEFF00ULL && hi == 0x003C) l2_ok = true;
        }
        if (l1_ok && l2_ok) break;
    }
    if (!l1_ok || !l2_ok) {
        std::cerr << "FAIL: Bifurcated lane data failed l1_ok=" << l1_ok << " l2_ok=" << l2_ok << "\n";
        return 1;
    }

    std::cout << "PASS: test_pipe_link (Gen6 80b + 4b txelecidle + EQ + Dynamic MAXPCLK + Per-lane Bifurcation)\n";
    delete dut;
    return 0;
}
