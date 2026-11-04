// ------------------------------------------------------------------------------
// 
// Copyright 2002 - 2024 Synopsys, INC.
// 
// This Synopsys IP and all associated documentation are proprietary to
// Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
// written license agreement with Synopsys, Inc. All other use, reproduction,
// modification, or distribution of the Synopsys IP or the associated
// documentation is strictly prohibited.
// Inclusivity & Diversity - Visit SolvNetPlus to read the "Synopsys Statement on
//            Inclusivity and Diversity" (Refer to article 000036315 at
//                        https://solvnetplus.synopsys.com)
// 
// Component Name   : DWC_pcie_ctl_cxl
// Component Version: 6.14a-lca02
// Release Type     : LCA
// Build ID         : 69.19.33.11.PCIeParseConfig_1.PCIeSimulate_24.PCIeTbCommon_85.SNPSPHYSetup_21
// ------------------------------------------------------------------------------

// -------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh_deskew3_rd_slv.sv#13 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC Layer Deskew Read process for Gen3 - Single Lane Version
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

module rmlh_deskew3_rd_slv
import DWC_pcie_core_pkg::ltssm_state_e;
import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
import DWC_pcie_core_pkg::S_CFG_COMPLETE;
import DWC_pcie_core_pkg::S_CFG_IDLE;
import DWC_pcie_core_pkg::S_RCVRY_LOCK;
import DWC_pcie_core_pkg::S_RCVRY_RCVRCFG;
import DWC_pcie_core_pkg::S_RCVRY_IDLE;
import DWC_pcie_core_pkg::S_L0;
import DWC_pcie_core_pkg::S_L0S;
import DWC_pcie_core_pkg::S_L123_SEND_EIDLE;
import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
import DWC_pcie_core_pkg::S_LPBK_EXIT;
#(
parameter INST = 0,                 // The uniquifying parameter for each port logic instance.
parameter NB   = `CX_NB,            // Number of symbols (bytes) per clock cycle
parameter NBK  = `CX_NBK,           // Number of symbols (bytes) per clock cycle for datak
parameter AW   = ((`CX_NB>=32)?6:(`CX_NB>=16)?5:4), // Width of active number symbols
parameter AW2  = ((`CX_NB>=16)?5:4), // Width of active number symbols
parameter SB_WD = `CX_MAC_SB_WD,    //Width of phy_mac_rxstartblock per lane
parameter SH_WD = `CX_MAC_SH_WD,    //Width of phy_mac_rxsyncheader per lane
parameter TP   = `TP                // Clock to Q delay (simulator insurance)
)

                          (
input                core_clk,
input                core_rst_n,
input                cfg_elastic_buffer_mode,
input   [2:0]        current_data_rate,
input   [(NB*8)-1:0] deskew_data,
input   [NBK-1:0]    deskew_datak,
input   [1:0]        deskew_error,    // rxerror - bit[1] from PHY + SKP parity error coming from buffer deskew_rxerror_i[0]
input                empty,
input                sds_rcvd_all,    // all other lanes active lane report full SDS received
input                skp_rcvd_all,    // all active lanes receiving SKP OS at same cycle time
input                ei_rcvd_all,     // all active lanes receiving EIOS at same cycle time
input                eie_rcvd_all,    // all active lanes receiving EIEOS at same cycle time
input                skp_ei_rcvd_all,    // all active lanes receiving SKP OS or EIOS at same cycle time
input                l0p_up_lanes_active,
input                l0p_ei_rcvd_any,
input                l0p_skp_rcvd_any,
input                l0p_skp_data_rcving,
input                unempty_all,     // all active lanes buffers are not empty
input                do_deskew,
input   [AW-1:0]     active_nb,
input                rxpkt_error,     // packet framing error
input                skp_error_g6,    // indicate all active lanes receiving error with SKIP-OS at gen6
input                os_rcvd_in_g6,   // indicate sdsos is received before deskew buffer
input                os_rcvd_dv_g6,   // indicate data_dv 
input   [4:0]        rxpkt_error_ptr,
input                cdm_ras_des_ferr_rec_dis,
input ltssm_state_e  smlh_ltssm_state,
input                cxl_mode_enable,
input                smlh_flit_mode_enable,
input                ltssm_lpbk_master,
input                prbs_en_int,

output               framing_err_dnew,
output reg           datastream,
output reg           goto_recovery,
output wire          unload,
output wire          sds_rcvd,
output reg           skp_rcvd,
output [2:0]         deskew_rd_state_o,
output reg           ei_rcvd,
output reg           eie_rcvd,
output wire          lane_err, //report it in the `Lane Error Status register. include undefined sync header & SKP parity err
output     [6:0]     framing_err_ptr_dnew,
output reg           lane_err_skp_parity,
output reg           lane_err_sync_header,
output reg           os_in_datastream,
output reg           g6_data_stream,
output wire          search_for_tokens,
output               skpos_first_cycle,
output reg           expect_eds,
output wire          accept_eds_cycle
);

localparam SYM_WD = (NB >= 4) ? 32 : (NB*8) ; // Width of OS Symbol Comparison
wire        ltssm_in_rcvrylock;
wire        ltssm_in_cfglinkwdstart;
wire        ltssm_in_cfgcomplete;
wire        ltssm_in_cfgidle;
wire        ltssm_in_rcvrycfg;
wire        ltssm_in_rcvryidle;
wire        ltssm_in_l0;
wire        ltssm_in_l0s;
wire        ltssm_in_l123;
logic       ltssm_in_lpbk_active_exit;
logic [127:0] data128b_sds_sym;
logic [127:0] data128b_skp_sym;
logic [127:0] data128b_ei_sym;
logic [127:0] data128b_eie_sym;
logic [127:0] shift_data128b_sds_sym;
logic [127:0] shift_data128b_skp_sym;
logic [127:0] shift_data128b_ei_sym;
logic [127:0] shift_data128b_eie_sym;
logic         deskew_data_sds_sym_0;
logic         deskew_data_sds_sym_n;
logic         deskew_data_skp_sbl_0;
logic         deskew_data_skp_sym_0;
logic         deskew_data_ei_sym_0 ;
logic         deskew_data_ei_sym_n ;
logic         deskew_data_eie_sym_0;
logic         deskew_data_eie_sym_n;
logic [7:0]   active_byte;
logic [7:0]   matched_deskew_data_sds_sym;
logic [7:0]   matched_deskew_data_skp_sym;
logic [7:0]   matched_deskew_data_ei_sym;
logic [7:0]   matched_deskew_data_eie_sym;

wire        fram_err_allowed;
wire [AW2-1:0]  int_active_nb;
assign int_active_nb = active_nb;
wire [SH_WD-1:0]  int_deskew_datak;
reg  [3:0]  block_cnt; // count 0-15 symbols in a block

assign int_deskew_datak = deskew_datak[SH_WD-1:0];

// Set OS format
always_comb begin
    case(current_data_rate)
        `GEN6_RATE: begin
            data128b_sds_sym = {4{`GEN6_32B_SDS_SYM_0}};
            data128b_skp_sym = {4{`GEN6_32B_SKP_SYM_0}};
            data128b_ei_sym  = {4{`GEN6_32B_EIOS_SYM_0}};
            data128b_eie_sym = {`GEN6_32B_EIEOS_SYM_3, `GEN6_32B_EIEOS_SYM_2, `GEN6_32B_EIEOS_SYM_1, `GEN6_32B_EIEOS_SYM_0};
        end
        `GEN5_RATE: begin
            data128b_sds_sym = {{15{`CX_GEN5_SDS_BODY_ENC}},`SDS_SYM_0};
            data128b_skp_sym = {16{`CX_GEN5_SKP_ENC}};
            data128b_ei_sym  = {16{`EIOS_SYM_0}};
            data128b_eie_sym = {2{{4{`EIEOS_SYM_1}},{4{`EIEOS_SYM_0}}}};
        end
        `GEN4_RATE: begin
            data128b_sds_sym = {{15{`SDS_SYM_1}},`SDS_SYM_0};
            data128b_skp_sym = {16{`SKP_SYM_0}};
            data128b_ei_sym  = {16{`EIOS_SYM_0}};
            data128b_eie_sym = {4{{2{ `EIEOS_SYM_1}},{2{ `EIEOS_SYM_0}}}};
        end
    default: begin // gen3
            data128b_sds_sym = {{15{`SDS_SYM_1}},`SDS_SYM_0};
            data128b_skp_sym = {16{`SKP_SYM_0}};
            data128b_ei_sym  = {16{`EIOS_SYM_0}};
            data128b_eie_sym = {8{ `EIEOS_SYM_1, `EIEOS_SYM_0}};
        end
    endcase
    // Shift the OS 
    shift_data128b_sds_sym = $bits( shift_data128b_sds_sym )'(data128b_sds_sym >> (block_cnt[3:0]*8));
    shift_data128b_skp_sym = $bits( shift_data128b_skp_sym )'(data128b_skp_sym >> (block_cnt[3:0]*8));
    shift_data128b_ei_sym  = $bits( shift_data128b_ei_sym  )'(data128b_ei_sym  >> (block_cnt[3:0]*8)); 
    shift_data128b_eie_sym = $bits( shift_data128b_eie_sym )'(data128b_eie_sym >> (block_cnt[3:0]*8));
end

// OS detection
always_comb begin
    deskew_data_sds_sym_0 = '0;
    deskew_data_skp_sym_0 = '0;
    deskew_data_ei_sym_0  = '0;
    deskew_data_eie_sym_0 = '0;
    deskew_data_skp_sbl_0 = '0;
    deskew_data_sds_sym_n = '0;
    deskew_data_ei_sym_n  = '0;
    deskew_data_eie_sym_n = '0;
    matched_deskew_data_sds_sym = '1;
    matched_deskew_data_skp_sym = '1;
    matched_deskew_data_ei_sym  = '1;
    matched_deskew_data_eie_sym = '1;
    active_byte = active_nb[3] ? 8'hFF :
 active_nb[2] ? 8'h0F :

 '0;

    if(!empty) begin
        if(|active_nb[3:0]) begin //1s,2s,4s,8s
            // compare with os per byte
            for( int ii = 0 ; ii < ((NB>=16) ? 8 : NB); ii++ ) begin
                if(active_byte[ii]) begin
                    matched_deskew_data_sds_sym[ii] = (deskew_data[ii*8 +: 8] == shift_data128b_sds_sym[ii*8 +: 8]);
                    matched_deskew_data_skp_sym[ii] = (deskew_data[ii*8 +: 8] == shift_data128b_skp_sym[ii*8 +: 8]);
                    matched_deskew_data_ei_sym[ii]  = (deskew_data[ii*8 +: 8] ==  shift_data128b_ei_sym[ii*8 +: 8]);
                    matched_deskew_data_eie_sym[ii] = (deskew_data[ii*8 +: 8] == shift_data128b_eie_sym[ii*8 +: 8]);
                end else begin
                    matched_deskew_data_sds_sym[ii] = 1'b1;
                    matched_deskew_data_skp_sym[ii] = 1'b1;
                    matched_deskew_data_ei_sym[ii]  = 1'b1;
                    matched_deskew_data_eie_sym[ii] = 1'b1;
                end
            end
            // check os every cycles
            deskew_data_sds_sym_n = &matched_deskew_data_sds_sym;
            deskew_data_ei_sym_n  = &matched_deskew_data_ei_sym;
            deskew_data_eie_sym_n = &matched_deskew_data_eie_sym;
            // check os at first cycle
            deskew_data_sds_sym_0 = (int_deskew_datak[1:0] == `SYNC_OS_BLOCK) && deskew_data_sds_sym_n;
            deskew_data_skp_sym_0 = (int_deskew_datak[1:0] == `SYNC_OS_BLOCK) && &matched_deskew_data_skp_sym[3:0]; // no check Symbol[7:4]
            deskew_data_ei_sym_0  = (int_deskew_datak[1:0] == `SYNC_OS_BLOCK) && deskew_data_ei_sym_n;
            deskew_data_eie_sym_0 = (int_deskew_datak[1:0] == `SYNC_OS_BLOCK) && deskew_data_eie_sym_n;
        end 
            deskew_data_skp_sbl_0 = (deskew_data[7:0] == data128b_skp_sym[7:0]) && (int_deskew_datak[1:0] == `SYNC_OS_BLOCK); // only check Symbol 0;
    end //!empty
end

wire [31:0]  data32b_skp_end_sym = `GEN6_32B_SKP_SYM_END;

wire [SB_WD-1:0] deskew_datak_os_block;
wire [SB_WD-1:0] deskew_datak_d_block;

assign deskew_datak_os_block[0] = (int_deskew_datak[1:0] == `SYNC_OS_BLOCK) && !empty;
assign deskew_datak_d_block[0]  = (int_deskew_datak[1:0] == `SYNC_DATA_BLOCK) && !empty;

assign ltssm_in_cfglinkwdstart = (smlh_ltssm_state == S_CFG_LINKWD_START);
assign ltssm_in_cfgcomplete    = (smlh_ltssm_state == S_CFG_COMPLETE);
assign ltssm_in_cfgidle        = (smlh_ltssm_state == S_CFG_IDLE);
assign ltssm_in_rcvrylock      = (smlh_ltssm_state == S_RCVRY_LOCK);
assign ltssm_in_rcvrycfg       = (smlh_ltssm_state == S_RCVRY_RCVRCFG);
assign ltssm_in_rcvryidle      = (smlh_ltssm_state == S_RCVRY_IDLE);
assign ltssm_in_l0             = (smlh_ltssm_state == S_L0);
assign ltssm_in_l0s            = (smlh_ltssm_state == S_L0S);
assign ltssm_in_l123           = (smlh_ltssm_state == S_L123_SEND_EIDLE);
wire   ltssm_in_lpbk_active_flit;
assign ltssm_in_lpbk_active_flit = ((smlh_ltssm_state == S_LPBK_ACTIVE) || (smlh_ltssm_state == S_LPBK_EXIT)) && smlh_flit_mode_enable;
assign ltssm_in_lpbk_active_exit = (smlh_ltssm_state == S_LPBK_ACTIVE) || (smlh_ltssm_state==S_LPBK_EXIT);
logic   in_prbs_lpbk;
assign in_prbs_lpbk = prbs_en_int && ltssm_in_lpbk_active_exit && ltssm_lpbk_master;

//framing error is always allowed to generate FRAMING_ERR states.
assign fram_err_allowed   = 1'b1;

localparam MAX_SYM_NUM    = 24+2*NB;
localparam MAX_CYCLE_NUM  = 5;
localparam ECNT_WIDTH     = (NB>=16 || `CX_MAX_PCIE_SPEED>=6) ? 7 : 6; // If nb==16, maximum value is 80. if gen6 rate, maximum value is 64+.
localparam S_NO_DESKEW    = 3'd0;
localparam S_WAIT_FOR_SDS = 3'd1;
localparam S_DATA_STREAM  = 3'd2;
localparam S_SKP_OS       = 3'd3;
localparam S_EI_OS        = 3'd4;
localparam S_EIE_OS       = 3'd5;
localparam S_FRAMING_ERR  = 3'd6;
localparam MSG_ENABLE     =
                                0;

// allow transparent processing of $display
reg        tmp_unload; //block_cnt delayed for one cycle based on tmp_unload
reg  [2:0] deskew_rd_state;
reg        sds_rcving;
reg        from_sds;
reg        sds_datablock_frm_err;
reg        datastream_frm_err;
reg        undefined_sync_header; //1 cycle long
reg  [ECNT_WIDTH-1:0] empty_cnt; //used for buffer empty check. not use block_cnt (0 in SKP_OS) instead as it is purely for !empty count

wire [ECNT_WIDTH-1:0] cycle_num;
wire       rxpkt_error_rising_edge;
reg        rxpkt_error_d;
reg        framing_err;
reg  [6:0] pre_framing_err_ptr;
reg  [6:0] framing_err_ptr;

wire [ECNT_WIDTH-1:0] empty_cnt_skp = active_nb == 16 ? 1 : active_nb == 8 ? 2 : active_nb == 4 ? 5 : active_nb == 2 ? 10 : 20; // PHY removes up to 20 SKP symbols
assign cycle_num = cfg_elastic_buffer_mode ? MAX_CYCLE_NUM + empty_cnt_skp : MAX_CYCLE_NUM; //empty mode - empty_cnt_skp+5; half full - 5

always @(posedge core_clk or negedge core_rst_n) begin : rxpkt_error_d_PROC
    if (!core_rst_n) begin
        rxpkt_error_d <= #TP '0;
    end else begin
        rxpkt_error_d <= #TP rxpkt_error;
    end
end

// use rxpkt_error_rising_edge to move deskew_rd_state into S_FRAMING_ERR from rxpkt_error
assign rxpkt_error_rising_edge = rxpkt_error & !rxpkt_error_d;

// Deskew receives back-to-back SDS-OS at gen6 rate. Second SDS-OS is allowed to check a status.
localparam S_WAIT_FOR_SKP = 2'd3;
localparam S_WAIT_2ND_SDS = 2'd2;
localparam S_WAIT_1ST_SDS = 2'd1;
localparam S_SDS_ALLOWED  = 2'd0;

reg [1:0] next_state_sds;
reg [1:0] current_state_sds;
reg       deskew_datak_os_block_0_d;
reg        proceed_data_g6;
wire       sds_rcvd_disable_g6;
logic      sds_consecutive_valid;

wire [3:0] next_sds_detect_cnt_all;
wire [3:0] next_sds_detect_cnt_even;
reg  [3:0] sds_detect_cnt_all;
reg  [3:0] sds_detect_cnt_even;
wire [(NB/4)-1:0]  pre_deskew_data_sds_sym_gen6;
assign pre_deskew_data_sds_sym_gen6[0] = (deskew_data[32*0 +: 32] == `GEN6_32B_SDS_SYM_0) && ((int_deskew_datak[1:0] == `SYNC_OS_BLOCK) ? 1 : deskew_datak_os_block_0_d);
assign pre_deskew_data_sds_sym_gen6[1] = (deskew_data[32*1 +: 32] == `GEN6_32B_SDS_SYM_0) && ((int_deskew_datak[1:0] == `SYNC_OS_BLOCK) ? 1 : deskew_datak_os_block_0_d);

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
assign next_sds_detect_cnt_all = {3'b000,pre_deskew_data_sds_sym_gen6[0]}
                             + {3'b000,pre_deskew_data_sds_sym_gen6[1]}
                             + sds_detect_cnt_all;
assign next_sds_detect_cnt_even = (
                                {3'b000,pre_deskew_data_sds_sym_gen6[0]})
                             + sds_detect_cnt_even;
// spyglass enable_block W164a
assign sds_consecutive_valid = |next_sds_detect_cnt_all[3:2] && |next_sds_detect_cnt_even[3:1];

always @(*) begin : next_state_sds_PROC
    next_state_sds = current_state_sds;
    case (current_state_sds)
        S_WAIT_FOR_SKP:
            if(deskew_data_skp_sbl_0 && sds_consecutive_valid)
                next_state_sds = S_SDS_ALLOWED;
            else if((deskew_datak_os_block[0] || deskew_datak_d_block[0]) && tmp_unload)
                next_state_sds = S_WAIT_1ST_SDS;
            else
                next_state_sds = S_WAIT_FOR_SKP;
        S_WAIT_2ND_SDS:
            if(deskew_data_skp_sbl_0 && sds_consecutive_valid)
                next_state_sds = S_SDS_ALLOWED;
            else if(deskew_datak_os_block[0] && tmp_unload)
                next_state_sds = S_WAIT_FOR_SKP;
            else
                next_state_sds = S_WAIT_2ND_SDS;
        S_WAIT_1ST_SDS:
            if(deskew_data_sds_sym_0)
                next_state_sds = S_WAIT_2ND_SDS;
            else
                next_state_sds = S_WAIT_1ST_SDS;
        default       : // S_SDS_ALLOWED
            if((current_data_rate == `GEN6_RATE && deskew_rd_state == S_WAIT_FOR_SDS) && (deskew_datak_os_block[0] || deskew_datak_d_block[0]) && tmp_unload)
                next_state_sds = S_WAIT_1ST_SDS;
            else
                next_state_sds = S_SDS_ALLOWED;
    endcase
end

always @(posedge core_clk or negedge core_rst_n) begin : current_state_sds_PROC
    if (!core_rst_n) begin
        current_state_sds         <= #TP S_SDS_ALLOWED;
        deskew_datak_os_block_0_d <= #TP 1'b0;
        sds_detect_cnt_all        <= #TP '0;
        sds_detect_cnt_even       <= #TP '0;
        proceed_data_g6           <= #TP '0;
    end else if(current_data_rate != `GEN6_RATE || deskew_rd_state != S_WAIT_FOR_SDS) begin
        current_state_sds         <= #TP S_SDS_ALLOWED;
        deskew_datak_os_block_0_d <= #TP 1'b0;
        sds_detect_cnt_all        <= #TP '0;
        sds_detect_cnt_even       <= #TP '0;
        proceed_data_g6           <= #TP '0;
    end else begin
        current_state_sds         <= #TP next_state_sds;
        deskew_datak_os_block_0_d <= #TP (empty) ? deskew_datak_os_block_0_d : deskew_datak_os_block[0];
        sds_detect_cnt_all        <= #TP (next_state_sds==S_SDS_ALLOWED || (next_state_sds==S_WAIT_1ST_SDS && pre_deskew_data_sds_sym_gen6==0)) ? 0 : (empty) ? sds_detect_cnt_all  : next_sds_detect_cnt_all;
        sds_detect_cnt_even       <= #TP (next_state_sds==S_SDS_ALLOWED || (next_state_sds==S_WAIT_1ST_SDS && pre_deskew_data_sds_sym_gen6==0)) ? 0 : (empty) ? sds_detect_cnt_even : next_sds_detect_cnt_even;
        proceed_data_g6           <= #TP (current_state_sds==S_WAIT_2ND_SDS && os_rcvd_in_g6) ? 1'b1 : 
                                     (proceed_data_g6 && !empty) ? 1'b0 : proceed_data_g6; // 4s, 8s
    end
end
assign sds_rcvd_disable_g6 = (current_state_sds==S_WAIT_2ND_SDS) && (~os_rcvd_dv_g6 || os_rcvd_in_g6 || proceed_data_g6);

reg first_skp_lpbk_flit;
reg [2:0] deskew_rd_state_d;

always @(posedge core_clk or negedge core_rst_n) begin : deskew_rd_state_d_PROC
    if ( ~core_rst_n )
        deskew_rd_state_d <= #TP S_NO_DESKEW;
    else
        deskew_rd_state_d <= #TP deskew_rd_state;
end // deskew_rd_state_d_PROC

wire g6_gen_framing_error ;
assign g6_gen_framing_error = (framing_err_dnew & current_data_rate == `GEN6_RATE);

// for l0p operation, controller receives different OSs(SKP-OS or EIOS) at same symbol time
wire  skp_rcvd_all_i;
wire  ei_rcvd_all_i;
assign skp_rcvd_all_i = (smlh_flit_mode_enable) ? skp_ei_rcvd_all : skp_rcvd_all;
assign ei_rcvd_all_i  = (smlh_flit_mode_enable) ? skp_ei_rcvd_all : ei_rcvd_all;
reg  [2:0] deskew_rd_last_state;
wire [2:0] int_deskew_rd_last_state;
wire       skp_from_sds_rcvd;
reg  [1:0] ei_rcvd_d;
always @(posedge core_clk or negedge core_rst_n) begin : deskew_ei_rcvd_d_PROC
    if ( !core_rst_n ) begin
        ei_rcvd_d <= #TP '0;
    end else begin
        ei_rcvd_d <= #TP {ei_rcvd_d[0],ei_rcvd};
    end
end
assign skp_from_sds_rcvd = from_sds;
assign int_deskew_rd_last_state = (deskew_rd_state==S_NO_DESKEW || deskew_rd_state==S_WAIT_FOR_SDS) ? deskew_rd_state : (deskew_rd_state_d!=deskew_rd_state) ? deskew_rd_state_d : deskew_rd_last_state;

always @(posedge core_clk or negedge core_rst_n) begin : deskew_rd_last_state_PROC
    if ( ~core_rst_n )
        deskew_rd_last_state <= #TP S_NO_DESKEW;
    else
        deskew_rd_last_state <= #TP int_deskew_rd_last_state;
end // deskew_rd_last_state_PROC
assign  deskew_rd_state_o = deskew_rd_state;

always @(posedge core_clk or negedge core_rst_n) begin : deskew_rd_seq_PROC
    if ( !core_rst_n ) begin
        deskew_rd_state       <= #TP S_NO_DESKEW;
        block_cnt             <= #TP '0;
        sds_rcving            <= #TP '0;
        skp_rcvd              <= #TP '0;
        ei_rcvd               <= #TP '0;
        eie_rcvd              <= #TP '0;
        expect_eds            <= #TP '0;
        undefined_sync_header <= #TP '0;
        framing_err           <= #TP '0;
        pre_framing_err_ptr   <= #TP '0;
        framing_err_ptr       <= #TP '0;
        goto_recovery         <= #TP '0;
        empty_cnt             <= #TP '0;
        from_sds              <= #TP '0;
        first_skp_lpbk_flit   <= #TP '0;
    end else if ( !do_deskew ) begin
        deskew_rd_state       <= #TP S_NO_DESKEW;
        block_cnt             <= #TP '0;
        sds_rcving            <= #TP '0;
        skp_rcvd              <= #TP '0;
        ei_rcvd               <= #TP '0;
        eie_rcvd              <= #TP '0;
        expect_eds            <= #TP '0;
        undefined_sync_header <= #TP '0;
        framing_err           <= #TP '0;
        pre_framing_err_ptr   <= #TP '0;
        framing_err_ptr       <= #TP '0;
        goto_recovery         <= #TP '0;
        empty_cnt             <= #TP '0;
        from_sds              <= #TP '0;
        first_skp_lpbk_flit   <= #TP '0;
    //pkt finder detects framing error if rxpkt_err in gen3 rate. If in S_NO_DESKEW state, rxpkt_err doesn't drive state to S_FRAMING_ERR
    end else if ( rxpkt_error_rising_edge && (deskew_rd_state != S_NO_DESKEW) && fram_err_allowed ) begin
        deskew_rd_state       <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
        framing_err           <= #TP 1;
        pre_framing_err_ptr   <= #TP {2'b00,rxpkt_error_ptr};
        framing_err_ptr       <= #TP 0;
        `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: packet finder detected Framing Err", $time); `endif
    end else begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Using the sequential part (flip-flop description) and combinational part(case construct) of an FSM in the same always block increases complexity of the design thereby reducing the readability. This code is a simple. So, disable SpyGlass from reporting this error.
        case ( deskew_rd_state )
// spyglass enable_block STARC05-2.11.3.1

            S_WAIT_FOR_SDS : begin
                ei_rcvd               <= #TP '0;
                eie_rcvd              <= #TP '0;
                empty_cnt             <= #TP '0;
                goto_recovery         <= #TP '0;
                undefined_sync_header <= #TP '0;
                framing_err           <= #TP '0;
                pre_framing_err_ptr   <= #TP '0;
                framing_err_ptr       <= #TP '0;
                if ( block_cnt == 0 && !(sds_rcving || sds_rcvd)) begin // waiting for the start of a block not having received SDS on this lane
                    if ( !empty ) begin
                     if ( deskew_data_sds_sym_0 ) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from repo
                        if ( tmp_unload ) //block_cnt based on tmp_unload
                            block_cnt     <= #TP block_cnt + active_nb[3:0];
                            sds_rcving    <= #TP 1;
                        end else if ( deskew_data_skp_sbl_0 ) begin // only identify sym 0 because the push side only checks sym 0
                            block_cnt     <= #TP '0; // do not advance as we do not expect other symbols for SKP OS
                        end else begin
                            if ( tmp_unload ) //block_cnt based on tmp_unload
                                block_cnt <= #TP block_cnt + active_nb[3:0];
                        end
// spyglass enable_block W164a
                    end
                end else if ( block_cnt == (16- int_active_nb) && (sds_rcving || sds_rcvd) ) begin
                    if ( !empty ) begin
                        if ( next_state_sds == S_WAIT_2ND_SDS || next_state_sds == S_WAIT_FOR_SKP) begin //waiting for an SKP_OS
                            block_cnt  <= #TP block_cnt;
                            sds_rcving <= #TP 1;
                        end else if (current_data_rate == `GEN6_RATE && next_state_sds == S_SDS_ALLOWED) begin // receiving an SKP-OS
                            sds_rcving          <= #TP '0;
                            from_sds            <= #TP 1;
                            block_cnt           <= #TP '0;
                            empty_cnt           <= #TP '0;
                            empty_cnt[AW-1:0]   <= #TP active_nb;
                            skp_rcvd            <= #TP 1; //SKP OS received
                            expect_eds          <= #TP (in_prbs_lpbk)? 0:1;  // EDS expected prior to OS
                            deskew_rd_state     <= #TP S_SKP_OS;
                            first_skp_lpbk_flit <= #TP ltssm_in_lpbk_active_flit;
                        end else 
                        if ( sds_rcvd_all | l0p_up_lanes_active) begin
                            sds_rcving      <= #TP '0;
                            from_sds        <= #TP 1;
                            block_cnt       <= #TP '0;
                            deskew_rd_state <= #TP S_DATA_STREAM;
                        end
                    end
                end else begin // block_cnt > 0, keep unloading until the end of the block, (1)
                    if ( !empty ) begin
                        if ( tmp_unload ) begin //block_cnt based on tmp_unload
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from repo
                          if(int_deskew_datak[1:0] == `SYNC_OS_BLOCK) // Align to startblock
                            block_cnt <= #TP active_nb[3:0];
                          else
                            block_cnt <= #TP block_cnt + active_nb[3:0];
// spyglass enable_block W164a
                        end
                    end
                    if ( sds_rcving == 1'b1 && !empty ) begin
                        if( !deskew_data_sds_sym_n ) begin
                            sds_rcving <= #TP '0;
                        end
                    end
                end
            end // S_WAIT_FOR_SDS

            S_DATA_STREAM : begin
                skp_rcvd        <= #TP '0;
                ei_rcvd         <= #TP '0;
                eie_rcvd        <= #TP '0;
                expect_eds      <= #TP '0;
                framing_err_ptr <= #TP '0;
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Using the sequential part (flip-flop description) and combinational part(case construct) of an FSM in the same always block increases complexity of the design thereby reducing the readability. This code is a simple. So, disable SpyGlass from reporting this error.
                if ( block_cnt == 0 ) begin
// spyglass enable_block STARC05-2.11.3.1
                    if ( !empty ) begin
                        empty_cnt <= #TP '0;
                        from_sds  <= #TP (l0p_up_lanes_active && deskew_rd_last_state==S_WAIT_FOR_SDS) ? from_sds : 0;
                        if ( tmp_unload ) //block_cnt based on tmp_unload
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from repo
                            block_cnt <= #TP block_cnt + active_nb[3:0];
// spyglass enable_block W164a
                        if ( deskew_error[1] && fram_err_allowed ) begin
                            deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                            framing_err         <= #TP 1; // we need assign it immediately
                            pre_framing_err_ptr <= #TP 7'h26;
                            `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Data Stream Err from PHY: PHY detects Rx Error", $time); `endif
                        end else
                        if ( from_sds && ~deskew_data_skp_sym_0 && fram_err_allowed && smlh_flit_mode_enable && current_data_rate != `GEN6_RATE && ~(l0p_up_lanes_active && skp_from_sds_rcvd)) begin //must be skp following sds for smlh_flit_mode_enable
                            deskew_rd_state <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                            framing_err     <= #TP 1; // we need assign it immediately
                            pre_framing_err_ptr <= #TP 7'h21;
                            `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: Not Receiving SKP OS Block following SDS", $time); `endif
                        end else
                        if ( from_sds && !deskew_datak_d_block[0] && fram_err_allowed && ~smlh_flit_mode_enable ) begin //not Data Block following SDS
                            deskew_rd_state <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                            framing_err     <= #TP 1; // we need assign it immediately
                            pre_framing_err_ptr <= #TP 7'h21;
                            `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: Receiving an OS Block following SDS", $time); `endif
                        end else if ( deskew_datak_os_block[0] ) begin  // OS block symbol 0
                            if ( tmp_unload ) begin //If tmp_unload, pop out the deskew_datak_os_block 1st Symbol
                                if ( deskew_data_skp_sym_0 ) begin
                                    empty_cnt           <= #TP '0;
                                    empty_cnt[AW-1:0]   <= #TP active_nb;
                                    skp_rcvd            <= #TP 1; //SKP OS received
                                    expect_eds          <= #TP (in_prbs_lpbk)? 0:1;  // EDS expected prior to OS
                                    deskew_rd_state     <= #TP S_SKP_OS;
                                    first_skp_lpbk_flit <= #TP ltssm_in_lpbk_active_flit;
                                end else if ( deskew_data_ei_sym_0 ) begin
                                    empty_cnt           <= #TP '0;
                                    ei_rcvd             <= #TP 1; //EIOS received
                                    expect_eds          <= #TP (in_prbs_lpbk)? 0:1;  // EDS expected prior to OS
                                    deskew_rd_state     <= #TP S_EI_OS;
                                end else if ( deskew_data_eie_sym_0 ) begin
                                    eie_rcvd            <= #TP 1; //EIEOS received
                                    expect_eds          <= #TP (in_prbs_lpbk)? 0:1;  // EDS expected prior to OS
                                    deskew_rd_state     <= #TP S_EIE_OS;
                                 end else if ( fram_err_allowed ) begin
                                    deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                                    framing_err         <= #TP 1; // we need assign it immediately
                                    pre_framing_err_ptr <= #TP 7'h22;
                                    `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: Data Block followed by OS Block different from SKP, EI, EIE", $time); `endif
                                end
                            end
                        end else if ( !deskew_datak_d_block[0] && fram_err_allowed ) begin  // unrecognized sync header (not Data or OS block)
                            if ( tmp_unload ) begin // after accounting for Lane-to-Lane de-skew, pop flag = 1
                                undefined_sync_header <= #TP 1; //report in the `Lane Error Status register. One cycle long pulse
                                deskew_rd_state       <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                                framing_err           <= #TP 1; // we need assign it immediately
                                pre_framing_err_ptr   <= #TP 7'h23;
                                `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: Block with an undefined Block Type", $time); `endif
                            end
                        end
                    end else begin //if ( block_cnt == 0 )
                        //if empty continuously over MAX_CYCLE_NUM cycles (might include 2 cycles for ~RxDataValid) in data stream, timeout to Recovery state
                        //this is used to prevent from stuck
                        empty_cnt <= #TP empty_cnt + 1; //not use block_cnt instead as block_cnt purely for !empty count
                        if ( (empty_cnt == cycle_num) && fram_err_allowed ) begin
                            deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                            framing_err         <= #TP 1; // we need assign it immediately
                            pre_framing_err_ptr <= #TP 7'h24;
                            `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Data Stream Timeout Err: Data Stream without data over three cycles", $time); `endif
                        end
                    end //empty
                end else begin // block_cnt > 0, keep unloading until the end of the block, (1)
                    from_sds <= #TP '0;
                    if ( deskew_datak_os_block[0] ) begin  // OS block symbol 0 in the middle of the data block
                        deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                        framing_err         <= #TP 1; // we need assign it immediately
                        pre_framing_err_ptr <= #TP 7'h25;
                        `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Middle Framing Err: OS Block during Data Stream in mid of a Block", $time); `endif
                    end else if ( empty )
                        empty_cnt <= #TP empty_cnt + 1;
                    else
                        empty_cnt <= #TP '0;
                    if ( !empty && deskew_error[1] && fram_err_allowed ) begin
                        deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                        framing_err         <= #TP 1; // we need assign it immediately
                        pre_framing_err_ptr <= #TP 7'h26;
                        `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Middle Data Stream Err from PHY: PHY detects Rx Error in mid of a Block", $time); `endif
                    end
// ccx_line_begin: ; unreachable because the push will occur after three clock cycles of rxvalid=0, safety code here. 
                    else if ( (empty_cnt == cycle_num) && fram_err_allowed ) begin //empty for 5 cycles continuously
                        deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                        framing_err         <= #TP 1; // we need assign it immediately
                        pre_framing_err_ptr <= #TP 7'h24;
                        `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Middle Data Stream Timeout Err: Data Stream without data over three cycles in mid of a Block", $time); `endif
                    end
// ccx_line_end
                    if ( tmp_unload ) //block_cnt based on tmp_unload
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from repo
                        block_cnt <= #TP block_cnt + active_nb[3:0];
// spyglass enable_block W164a
                end
            end // S_DATA_STREAM

            S_SKP_OS : begin
                block_cnt       <= #TP '0;
                expect_eds      <= #TP '0;
                framing_err_ptr <= #TP '0;
                if ( empty ) begin //1-bit empty_cnt is not enough as block_cnt=0, cannot use block_cnt to detect over 2-Block time
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from repo
                    empty_cnt <= #TP empty_cnt + int_active_nb; //use 2-Block time for timeout as max SKP OS can be 194 bits long for 8GT/s.
// spyglass enable_block W164a
                end
                if ( !empty && deskew_error[1] && fram_err_allowed ) begin
                    deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                    pre_framing_err_ptr <= #TP 7'h2A;
                    `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Data Stream Err from PHY: PHY detects Rx Error within SKP OS", $time); `endif
                end else
                //if not all lanes detect SKP at same cycle time, framing error. If flit mode is enabled, this checker is disabled because the invalid cycle is inserted between 2nd SDS-OS and an SKP-OS(an SDS-OS -> an SDS-OS -> Invalid cycle -> SKP-OS).
                if ( !skp_rcvd_all_i && (empty_cnt == {{(ECNT_WIDTH-AW2){1'b0}}, int_active_nb}) && fram_err_allowed && (~smlh_flit_mode_enable || ~from_sds) && ~l0p_skp_data_rcving) begin
                    deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                    pre_framing_err_ptr <= #TP 7'h27;
                    `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: Not all active lanes receiving SKP OS starting at same cycle time", $time); `endif
                //end else if ( (empty_cnt > MAX_SYM_NUM) && fram_err_allowed ) begin //2-Block timeout (Max 24 Sym SKP + 2 cycles of ~RxDataValid)
                end else if ( (empty_cnt > (( (current_data_rate==`GEN6_RATE) ? 72 : (~cfg_elastic_buffer_mode ? 28 : 31))+(int_active_nb<<1))) && fram_err_allowed ) begin //2-Block timeout (Max 24 Sym SKP + 2 cycles of ~RxDataValid). +3 for cfg_elastic_buffer_mode. Gen6 Max 56 Sym SKP + 2 cycle of ~RxDataValid
                    deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                    pre_framing_err_ptr <= #TP 7'h28;
                      `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: 2-Block timeout for SKP OS", $time); `endif
                end else if( !empty ) begin //first symbol after SKP
                        if ( first_skp_lpbk_flit && deskew_data_skp_sym_0 ) begin // check the 2nd SKP existing for flit loopback
                            deskew_rd_state <= #TP S_SKP_OS;
                        end else
                        // Wait for entering SKP-OS state in the continuing active lanes
                        if (smlh_flit_mode_enable && ((skp_from_sds_rcvd && ~skp_ei_rcvd_all) || (~skp_from_sds_rcvd && l0p_ei_rcvd_any) || l0p_skp_data_rcving)) begin
                            deskew_rd_state <= #TP S_SKP_OS;
                        end else
                        if ( !deskew_datak_d_block[0] && fram_err_allowed ) begin
                            deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                            pre_framing_err_ptr <= #TP 7'h29;
                             `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: SKP OS Block not followed by Data Block", $time); `endif
                            `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: Receiving consecutive OS Blocks within a Data Stream", $time); `endif
                        end else if (unempty_all && skp_rcvd_all_i && skp_error_g6 && fram_err_allowed ) begin // Detecting skp error for gen6
                            deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                            pre_framing_err_ptr <= #TP 7'h30;
                            `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: Not all active lanes receiving SKP OS starting at same cycle time", $time); `endif
                        end else if ( unempty_all ) begin //if all active lanes buffers are not empty, back to Data Stream. All active lanes start at same time for Data Stream
                            first_skp_lpbk_flit <= #TP '0;
                            block_cnt           <= #TP active_nb[3:0];
                            empty_cnt           <= #TP '0;
                            deskew_rd_state     <= #TP S_DATA_STREAM;
                            from_sds            <= #TP '0;
                        end
                end // !empty
            end // S_SKP_OS

            S_EI_OS : begin
                framing_err_ptr <= #TP 0;
                if ( !empty ) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from repo
                    block_cnt <= #TP block_cnt + active_nb[3:0];
// spyglass enable_block W164a
                end
                if ( empty && cfg_elastic_buffer_mode ) begin
                    empty_cnt <= #TP empty_cnt + 1;
                end // if ( empty
                expect_eds    <= #TP '0;
                if ( !ei_rcvd_all_i && ( block_cnt == int_active_nb) && fram_err_allowed ) begin //if not all lanes detect EI at same cycle time, framing error
                    block_cnt           <= #TP '0;
                    empty_cnt           <= #TP '0;
                    deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                    pre_framing_err_ptr <= #TP 7'h2B;
                    `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: Not all active lanes receiving EIOS starting at same cycle time", $time); `endif
                //for 1s,2s the detection of EIOS needs 4,2 cycles to recognize the first 4 Symbols
                end else if (
                              ((active_nb==2) && (block_cnt==2))
                              && !deskew_data_ei_sym_n && !empty && fram_err_allowed ) begin
                    block_cnt           <= #TP '0;
                    empty_cnt           <= #TP '0;
                    deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                    pre_framing_err_ptr <= #TP 7'h2C;
                    `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: At least one Symbol from the first 4 Symbols is not EIOS Symbol", $time); `endif
                //write side always push 16 symbols except SKP. even if truncation in EIOS, still push 16 symbols
                end else if (block_cnt == (16 - int_active_nb)) begin
                    empty_cnt       <= #TP '0;
                    deskew_rd_state <= #TP S_WAIT_FOR_SDS;
                    ei_rcvd         <= #TP '0;
                    block_cnt       <= #TP '0;
                end

                //after detecting 4 EIOS symbols, rxvalid is squelched, no push for empty mode
                if ( cfg_elastic_buffer_mode && empty_cnt == 3) begin // max 2 clocks with rxdatavalid==0 + 1 clock margin
                    deskew_rd_state <= #TP S_WAIT_FOR_SDS;
                    empty_cnt       <= #TP '0;
                    block_cnt       <= #TP '0;
                end // if ( cfg_elastic_buffer_mode
            end // S_EI_OS

            S_EIE_OS : begin
                framing_err_ptr    <= #TP '0;
                if ( !empty ) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from repo
                    block_cnt <= #TP block_cnt + active_nb[3:0];
// spyglass enable_block W164a
                end
                expect_eds <= #TP '0;
                if ( !eie_rcvd_all && ( block_cnt == int_active_nb) && fram_err_allowed ) begin //if not all lanes detect EIE at same cycle time, framing error
                    block_cnt           <= #TP '0;
                    deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                    pre_framing_err_ptr <= #TP 7'h2D;
                    `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: Not all active lanes receiving EIEOS starting at same cycle time", $time); `endif
                end else if ( !deskew_data_eie_sym_n && !empty && fram_err_allowed) begin //if not full eieos symbols, framing error
                    block_cnt           <= #TP '0;
                    deskew_rd_state     <= #TP cdm_ras_des_ferr_rec_dis ? deskew_rd_state : S_FRAMING_ERR;
                    pre_framing_err_ptr <= #TP 7'h2E;
                    `ifndef SYNTHESIS if ( MSG_ENABLE ) $display("%t %m: Rx Framing Err: Not full 16 eieos symbols are received", $time); `endif
                end else if (block_cnt == (16 - int_active_nb)) begin
                    //Gen3 spec: an EIEOS is received on any configured Lane in 128b/130b encoding, move from L0 to Recovery.
                    //cannot get all lanes rcvd EIEOS at the end of Block at same time as RxDataValid can be anywhere within a Block.
                    //if not all active lanes detect EIE at same cycle time, it is a framing error.
                    goto_recovery       <= #TP 1;
                    pre_framing_err_ptr <= #TP 7'h00;
                    deskew_rd_state     <= #TP S_WAIT_FOR_SDS;
                end
            end // S_EIE_OS

            S_FRAMING_ERR : begin
                first_skp_lpbk_flit   <= #TP '0;
                framing_err           <= #TP 1;
                pre_framing_err_ptr   <= #TP '0;
                framing_err_ptr       <= #TP pre_framing_err_ptr;
                empty_cnt             <= #TP '0;
                skp_rcvd              <= #TP '0;
                ei_rcvd               <= #TP '0;
                eie_rcvd              <= #TP '0;
                expect_eds            <= #TP '0;
                undefined_sync_header <= #TP '0;
                if ( ltssm_in_rcvrycfg ) begin //if framing_err in Rcvry.RcvrCfg, move to S_NO_DESKEW for LTSSM to move in Rcvry.Idle and timeout to Rcvry.RcvrLock
                    deskew_rd_state   <= #TP S_NO_DESKEW;
                end
            end // S_FRAMING_ERR

            default : begin
                first_skp_lpbk_flit  <= #TP '0;
                framing_err          <= #TP '0;
                pre_framing_err_ptr  <= #TP '0;
                framing_err_ptr      <= #TP '0;
                skp_rcvd             <= #TP '0;
                ei_rcvd              <= #TP '0;
                eie_rcvd             <= #TP '0;
                empty_cnt            <= #TP '0;
                expect_eds           <= #TP '0;
                if ( do_deskew ) begin
                    deskew_rd_state  <= #TP S_WAIT_FOR_SDS;
                end
            end // S_NO_DESKEW

        endcase
    end // do_deskew
end

reg sds_rcvd_all_d;
always @(posedge core_clk or negedge core_rst_n) begin : sds_rcvd_all_d_PROC
    if ( ~core_rst_n )
        sds_rcvd_all_d <= #TP 1'b0;
    else
        sds_rcvd_all_d <= #TP sds_rcvd_all;
end // sds_rcvd_all_d_PROC

always @( * ) begin : sds_datablock_frm_err_PROC
    sds_datablock_frm_err = 0;

    // not Data Block following SDS. Detecting this framing error asap is to block pkt_finder (rxdata_dv==0) to detect 8 symbols Idle data.
    // so ltssm will timeout in Cfg.Idle or Rcvry.Idle to Recovery.
    // skp following sds for smlh_flit_mode_enable = 1
    if ( smlh_flit_mode_enable && current_state_sds == S_WAIT_FOR_SKP && (sds_rcvd_all || sds_rcvd_all_d) && ~deskew_data_skp_sbl_0 && sds_consecutive_valid &&((deskew_datak_os_block[0] || deskew_datak_d_block[0]) && tmp_unload) && deskew_rd_state == S_WAIT_FOR_SDS) begin
            sds_datablock_frm_err = 1;
    end else if ( smlh_flit_mode_enable && from_sds && ~deskew_data_skp_sym_0 && fram_err_allowed && deskew_rd_state == S_DATA_STREAM && block_cnt == 0 && !empty && ~(l0p_up_lanes_active && skp_from_sds_rcvd)) begin // skp following sds for smlh_flit_mode_enable = 1
            sds_datablock_frm_err = 1;
    end else
    if ( deskew_rd_state == S_DATA_STREAM && block_cnt == 0 && !empty && from_sds && !deskew_datak_d_block[0] && fram_err_allowed && ~smlh_flit_mode_enable ) begin
        sds_datablock_frm_err = 1;
    end
end // sds_datablock_frm_err_PROC

always @( * ) begin : datastream_frm_err_PROC
    datastream_frm_err = 0;
    os_in_datastream = 0;

    // framing error generated in Data Stream. Use combinational logic to deassert deskew_rxdata_dv immediately once detecting framing error
    if ( deskew_rd_state == S_DATA_STREAM ) begin
        if ( block_cnt == 0 ) begin
            if ( !empty ) begin
                if ( deskew_error[1] ) // PHY error
                    datastream_frm_err = 1;
                else if ( !from_sds ) begin
                    if ( deskew_datak_os_block[0] ) begin
                        if ( tmp_unload ) begin
                            if ( !(deskew_data_skp_sym_0 || deskew_data_ei_sym_0 || deskew_data_eie_sym_0) ) // OS but not eieos/skp/eios
                                datastream_frm_err = 1;

                            os_in_datastream = 1;
                        end
                    end else if ( !deskew_datak_d_block[0] ) begin // ~OS and ~data
                        if ( tmp_unload )
                            datastream_frm_err = 1;
                    end
                end
            end else if ( empty_cnt == cycle_num) begin // empty over time
                datastream_frm_err = 1;
            end
        end else begin // if ( block_cnt > 0
            if ( deskew_datak_os_block[0] ) // OS in the middle of data block
                datastream_frm_err = 1;
            if ( !empty && deskew_error[1] ) // PHY error
                datastream_frm_err = 1;
            else if ( empty_cnt == cycle_num) // empty over time
                datastream_frm_err = 1;
        end
    end // if ( deskew_rd_state == S_DATA_STREAM

    if ( rxpkt_error_rising_edge && (deskew_rd_state != S_NO_DESKEW) && fram_err_allowed ) begin
        datastream_frm_err = 1;
    end
end // datastream_frm_err_PROC


assign framing_err_dnew = framing_err | sds_datablock_frm_err | datastream_frm_err;

reg  [6:0] datastream_frm_err_ptr;

always @( * ) begin : datastream_frm_err_ptr_PROC
    datastream_frm_err_ptr = 0;

    // framing error generated in Data Stream. Use combinational logic to deassert deskew_rxdata_dv immediately once detecting framing error
    if ( deskew_rd_state == S_DATA_STREAM ) begin
        if ( block_cnt == 0 ) begin
            if ( !empty ) begin
                if ( deskew_error[1] ) // PHY error
                    datastream_frm_err_ptr = 7'h26;
                else if ( !from_sds ) begin
                    if ( deskew_datak_os_block[0] ) begin
                        if ( tmp_unload ) begin
                            if ( !(deskew_data_skp_sym_0 || deskew_data_ei_sym_0 || deskew_data_eie_sym_0) ) // OS but not eieos/skp/eios
                                datastream_frm_err_ptr = 7'h22;
                        end
                    end else if ( !deskew_datak_d_block[0] ) // ~OS and ~data
                        datastream_frm_err_ptr = 7'h23;
                end
            end else if ( empty_cnt == cycle_num) begin // empty over time
                datastream_frm_err_ptr = 7'h24;
            end
        end else begin // if ( block_cnt > 0
            if ( deskew_datak_os_block[0] ) // OS in the middle of data block
                datastream_frm_err_ptr = 7'h25;
            if ( !empty && deskew_error[1] ) // PHY error
                datastream_frm_err_ptr = 7'h26;
            else if ( empty_cnt == cycle_num) // empty over time
                datastream_frm_err_ptr = 7'h24;
        end
    end // if ( deskew_rd_state == S_DATA_STREAM

    if ( rxpkt_error_rising_edge && (deskew_rd_state != S_NO_DESKEW) && fram_err_allowed ) begin
        datastream_frm_err_ptr = {2'b00,rxpkt_error_ptr};
    end
end // datastream_frm_err_ptr_PROC

assign framing_err_ptr_dnew = (smlh_flit_mode_enable && sds_datablock_frm_err) ? 7'h2f :
                              sds_datablock_frm_err ? 7'h21 :
                              datastream_frm_err    ? datastream_frm_err_ptr : framing_err_ptr;

//tmp_unload is used to pop data out of deskew buffer. it should be active once !empty
always @( * ) begin : tmp_unload_PROC
    tmp_unload = 0;

    if ( deskew_rd_state == S_WAIT_FOR_SDS ) begin
        if(|ei_rcvd_d) begin
            tmp_unload = 0; //wait for 2 cycles
        end else
        if ( block_cnt == 0 && !(sds_rcving || sds_rcvd) ) begin // waiting for the start of a block not having received SDS on this lane
            if ( !empty ) begin
                tmp_unload = 1;
            end
        end else if ( sds_rcvd ) begin // wait for all other lanes to report SDS received after having received a full SDS on this lane
            tmp_unload = 0;
            if ( !empty && (sds_rcvd_all || l0p_up_lanes_active ) ) begin //all lanes get sds, move to Data Stream
                tmp_unload = 1;
            end
        end else begin //block_cnt > 0
            if ( !empty )
                tmp_unload = 1; //keep unload if !empty
        end
    end else if ( deskew_rd_state == S_DATA_STREAM || deskew_rd_state == S_SKP_OS ) begin
        if ( !empty ) begin
        // Go ahead for l0p
          if (deskew_rd_state == S_DATA_STREAM && deskew_data_skp_sym_0 && skp_from_sds_rcvd && l0p_skp_data_rcving)
            tmp_unload = 1;
          else if (smlh_flit_mode_enable && deskew_rd_state == S_SKP_OS && ((~skp_from_sds_rcvd && l0p_ei_rcvd_any) || l0p_skp_data_rcving))
            tmp_unload = 0;
          else
        // Wait for entering SKP-OS state in the continuing active lanes
          if (smlh_flit_mode_enable && deskew_rd_state == S_SKP_OS && skp_from_sds_rcvd && (~skp_ei_rcvd_all || (deskew_datak_d_block[0] && ~unempty_all)))
            tmp_unload = 0;
          else
            tmp_unload = unempty_all; //pop-up data only when all lanes buffers are not empty under consideration of DataSkip
        end else begin
            tmp_unload = 0;
        end
    end else if ( !empty ) begin
        tmp_unload = 1; //keep unload if not empty
    end
end

//last Sym of SDS received
assign sds_rcvd = 
       ~sds_rcvd_disable_g6 &&
            (deskew_rd_state == S_WAIT_FOR_SDS) & (block_cnt == (16- int_active_nb)) & deskew_data_sds_sym_n &
                  sds_rcving;

always @( posedge core_clk or negedge core_rst_n ) begin : g6_data_stream_PROC
    if ( ~core_rst_n )
        g6_data_stream <= #TP '0;
    else if ( (sds_rcvd || sds_rcving) && (current_data_rate==`GEN6_RATE) )
        g6_data_stream <= #TP 1'b1;
    else if ( deskew_rd_state == S_EI_OS || deskew_rd_state == S_EIE_OS || deskew_rd_state == S_FRAMING_ERR || deskew_rd_state == S_NO_DESKEW || deskew_rd_state == S_WAIT_FOR_SDS || current_data_rate < `GEN6_RATE )
        g6_data_stream <= #TP '0;
end // g6_data_stream_PROC

//need !deskew_datak_os_block & unempty_all due to deskew_rd_state 1 cycle delay
//for cxl within data stream including SKP OS following Data Block the search_for_tokens = 1 always but deskew_rxdata_dv must deassert during SKP OS (skpos_first_cycle = 1 or fifo empty because of SKP OS not pushed in for deskew)
assign search_for_tokens = cxl_mode_enable ? ((deskew_rd_state == S_DATA_STREAM & ~(deskew_datak_os_block[0] & ~deskew_data_skp_sym_0)) | (deskew_rd_state == S_SKP_OS)) :
                                             (((deskew_rd_state == S_DATA_STREAM) & !deskew_datak_os_block[0] & ~(skp_from_sds_rcvd && l0p_up_lanes_active)) | ((deskew_rd_state == S_SKP_OS) & (~smlh_flit_mode_enable | skp_ei_rcvd_all) & unempty_all
 & (ltssm_in_lpbk_active_flit ? ~deskew_data_skp_sym_0 : 1'b1)));
assign skpos_first_cycle = cxl_mode_enable ? (((deskew_rd_state == S_DATA_STREAM) & deskew_datak_os_block[0] & deskew_data_skp_sym_0 & tmp_unload) | deskew_rd_state == S_EI_OS | deskew_rd_state == S_EIE_OS) : 1'b0; // to deasser the deskew_rxdata_dv in rml_deskew_slv.sv for the first cycle in SKP OS for CXL
assign accept_eds_cycle = (block_cnt == (16 - int_active_nb)) && unempty_all;

//for S_DATA_STREAM we need unempty_all to unload as DataSkip may be skewed, so data_valid signal cannot be asserted as long as any lane buffer is empty.
//no data pops out from buffer if any lane buffer is empty
assign unload = tmp_unload;

//lane_err includes skp_parity_err and undefined_sync_header. For more clear, use two saperate signals in the state machine
//lane_err includes margin_crc_err and margin_parity_err within Control-SKP-OS at gen4 
wire skp_parity_err;
assign skp_parity_err = deskew_error[0] & tmp_unload && ((deskew_rd_state == S_SKP_OS)
                        ); //SKP parity mismatch, 1 cycle long
reg lane_err_d;
always @(posedge core_clk or negedge core_rst_n)
begin : latch_lane_err
  if (!core_rst_n)
    lane_err_d <= #TP '0;
  else
    lane_err_d <= #TP skp_parity_err | undefined_sync_header;
end

assign lane_err = lane_err_d;

always @(posedge core_clk or negedge core_rst_n) begin : datastream_PROC
  if (!core_rst_n)
    datastream <= #TP '0;
  else
    datastream <= #TP (deskew_rd_state == S_DATA_STREAM) | (deskew_rd_state == S_SKP_OS);
end // datastream_PROC
always @(posedge core_clk or negedge core_rst_n)
begin : latch_lane_err_parity_sync_err
  if (!core_rst_n) begin
    lane_err_skp_parity  <= #TP '0;
    lane_err_sync_header <= #TP '0;
  end
  else begin
    lane_err_skp_parity  <= #TP skp_parity_err;
    lane_err_sync_header <= #TP undefined_sync_header;
  end
end

`ifndef SYNTHESIS
//VCS coverage off
wire [16*8-1:0] DESKEW_RD_STATE;
assign  DESKEW_RD_STATE = ( deskew_rd_state == S_NO_DESKEW    ) ? "NO_DESKEW"     :
                          ( deskew_rd_state == S_WAIT_FOR_SDS ) ? "WAIT_FOR_SDS"  :
                          ( deskew_rd_state == S_DATA_STREAM  ) ? "DATA_STREAM"   :
                          ( deskew_rd_state == S_SKP_OS       ) ? "SKP_OS"        :
                          ( deskew_rd_state == S_EI_OS        ) ? "EI_OS"         :
                          ( deskew_rd_state == S_EIE_OS       ) ? "EIE_OS"        :
                          ( deskew_rd_state == S_FRAMING_ERR  ) ? "FRAMING_ERR"   :  "BOGUS" ;
//VCS coverage on
`endif  // SYNTHESIS


endmodule // rmlh_deskew3_rd_slv
