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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh_pipe_squelch.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Per Lane Squelching
// -----------------------------------------------------------------------------
// --- this module detects 2 out of 3 IDLs in an EI ordered set.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

 
 module rmlh_pipe_squelch 
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
 import DWC_pcie_core_pkg::S_RCVRY_LOCK;
 import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
 (
// ---- inputs ---------------
    core_clk,
    core_clk_ug,
    core_rst_n,
    cfg_elastic_buffer_mode,
    cfg_pipe_garbage_data_mode,
    rxvalid,
    rxdata,
    rxdatak,
    active_nb,
    disable_squelch_turnoff,
    current_data_rate,
    smlh_ltssm_state,
    rxdatavalid,
    deskew_ds_g6,
    mac_phy_rate,
    rxstartblock,
    rxsyncheader,
    rxosfound,

// ---- outputs ---------------
    int_gen3_rcvd_4eidle_set,
    sq_rxdatak,
    int_rpipe_rcvd_eidle_set,
    set_squelch,
    eios_eieos_det,
    squelch
    ,
    rmlh_rxvalid_deasserted
);

parameter   NB      = `CX_NB;   // Number of symbols (bytes) per clock cycle
parameter   NB2     = (NB>=16) ? 16 : NB;   // Number of symbols (bytes) per clock cycle
parameter   AW      = `CX_ANB_WD; // Width of the active number of bytes
parameter   SB_WD   = `CX_MAC_SB_WD; //Width of phy_mac_rxstartblock per lane
parameter   SH_WD   = `CX_MAC_SH_WD; //Width of phy_mac_rxsyncheader per lane
parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)

input            core_clk;
input            core_clk_ug;
input            core_rst_n;
input            cfg_elastic_buffer_mode;
input            cfg_pipe_garbage_data_mode;
input            rxvalid;
input [NB*8-1:0] rxdata;
input [NB-1:0]   rxdatak;
input [AW-1:0]   active_nb;
input            disable_squelch_turnoff;
input   [2:0]    current_data_rate;
input ltssm_state_e   smlh_ltssm_state;
input            rxdatavalid;
input            deskew_ds_g6;
input [2:0]      mac_phy_rate;
input [SB_WD-1:0] rxstartblock;
input [SH_WD-1:0] rxsyncheader;
input [SB_WD-1:0][4:0] rxosfound;

output           int_gen3_rcvd_4eidle_set;
output reg [NB-1:0]  sq_rxdatak;
output           int_rpipe_rcvd_eidle_set;
output           set_squelch;
output           squelch;
output reg       eios_eieos_det;
output reg       rmlh_rxvalid_deasserted;

wire       set_squelch_i;
wire       reset_squelch;
reg        squelch_reg;

wire [7:1] chk_com;
wire [7:2] chk_idl;

wire [3:0] comk;
wire       int_comk;
reg  [3:1] comkq;

wire [3:0] idlk;
reg  [3:2] idlkq ;
wire       int_rpipe_rcvd_eidle_set;
reg        r_rpipe_rcvd_eidle_set;
wire       s_rpipe_rcvd_eidle_set;
wire       g12_rxeios_detect;
reg        g12_rxeios_detect_d;
reg        latched_g12_rxeios_detect;
wire       int_g12_rxeios_detect;
wire       int_reset_squelch;
wire [7:0] current_rxdatak_i;
wire       g3_rxeios_rcvd;
wire       ltssm_current_data_rate_g3;
wire       ltssm_in_lpbkactive;
reg  [1:0] rxdatavalid_n_cnt;

assign     ltssm_current_data_rate_g3 = (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE || current_data_rate == `GEN6_RATE);  
assign     ltssm_in_lpbkactive = (smlh_ltssm_state == S_LPBK_ACTIVE);
assign                   ltssm_current_data_rate_g6 = (current_data_rate == `GEN6_RATE);
reg   [SB_WD-1:0]        int_rxosblock;
reg   [1:0]              g6_clk_cnt;
reg   [1:0]              g6_clk_cnt_d;
wire                     g6_clk_cnt_expired;
reg   [15:0]             eios_byte_rcvd;
reg   [15:0]             eios_byte_rcvd_i;
reg   [15:0]             eios_byte_rcvd_d;
wire  [7:0]              eios_ab_rcvd;
wire  [SB_WD-1:0]        g6_rxeios_rcvd;
reg        rxvalid_d;

wire       rxvalid_i;
assign     rxvalid_i = cfg_elastic_buffer_mode ? rxvalid & rxdatavalid : rxvalid;

// Electrical Idle ordered set detection

// int_rpipe_rcvd_eidle_set is used in xmlh_ltssm to count EIDL o/s
//   so keep signal high if we continue to receive EIDL o/s
assign s_rpipe_rcvd_eidle_set =
                                   // in 1s mode do this
                                   active_nb[0] ?
                                       ( chk_com[1] & enuf(chk_idl[4:2]) ) : 1'b0
                                 |
                                   // in 2s mode do this
                                   active_nb[1] ?
                                       (  chk_com[1] & enuf(chk_idl[4:2])
                                        | chk_com[2] & enuf(chk_idl[5:3]) ) : 1'b0
                                 |
                                   // in 4s mode do this
                                   active_nb[2] ?
                                       (  chk_com[1] & enuf(chk_idl[4:2])
                                        | chk_com[2] & enuf(chk_idl[5:3])
                                        | chk_com[3] & enuf(chk_idl[6:4])
                                        | chk_com[4] & enuf(chk_idl[7:5]) ) : 1'b0;

always @(posedge core_clk or negedge core_rst_n) begin
  if (~core_rst_n)
    r_rpipe_rcvd_eidle_set <= #TP 1'b0;
  else
    r_rpipe_rcvd_eidle_set <= #TP s_rpipe_rcvd_eidle_set;
end

//to be sure int_rpipe_rcvd_eidle_set is only one cycle long for 1s.
//for SVA check
assign int_rpipe_rcvd_eidle_set =
                                 ltssm_current_data_rate_g6 ? |g6_rxeios_rcvd :
                                 ltssm_current_data_rate_g3 ? g3_rxeios_rcvd :
                                 ( (active_nb[0] | active_nb[1]) ? s_rpipe_rcvd_eidle_set & ~r_rpipe_rcvd_eidle_set :
                                  s_rpipe_rcvd_eidle_set );

// the squelch signal is asserted as quickly as possible
assign squelch =  set_squelch_i
                | squelch_reg & ~reset_squelch;

assign set_squelch = g12_rxeios_detect; //set_squelch_i;

// stay squelched until comma or rxvalid goes away. rxstartblock for gen3 data rate
assign g12_rxeios_detect =   chk_com[1] & enuf(chk_idl[4:2])
                           | chk_com[2] & enuf(chk_idl[5:3])
                           | chk_com[3] & enuf(chk_idl[6:4])
                           | chk_com[4] & enuf(chk_idl[7:5]);

always @(posedge core_clk or negedge core_rst_n) begin : g12_rxeios_detect_d_PROC
    if ( ~core_rst_n )
        g12_rxeios_detect_d <= #TP 0;
    else
        g12_rxeios_detect_d <= #TP g12_rxeios_detect;
end // g12_rxeios_detect_d_PROC

assign set_squelch_i = ~squelch_reg & (
                      ltssm_current_data_rate_g6 ? |g6_rxeios_rcvd :
                      ltssm_current_data_rate_g3 ? g3_rxeios_rcvd :
                      g12_rxeios_detect_d /*g12_rxeios_detect*/ ); // take next cycle. mask bytes for current cycle

assign reset_squelch = ~disable_squelch_turnoff & ( ~rxvalid | (
                                                             (~cfg_pipe_garbage_data_mode) ? (smlh_ltssm_state == S_RCVRY_LOCK) :
                                                             (ltssm_current_data_rate_g3) ? rxstartblock[0] :
                                                             int_reset_squelch )
                                                  );

assign int_comk = |comk;

always @(posedge core_clk or negedge core_rst_n) begin : latched_g12_rxeios_detect_PROC
    if (~core_rst_n)
        latched_g12_rxeios_detect <= #TP 1'h0;
    else if (g12_rxeios_detect)
        latched_g12_rxeios_detect <= #TP 1'h1;
    else if (!rxvalid || int_comk) //keep latched_g12_rxeios_detect until !rxvalid (rxvalid goes low after EIOS)
        latched_g12_rxeios_detect <= #TP 1'h0;
end

assign int_g12_rxeios_detect = g12_rxeios_detect | latched_g12_rxeios_detect;

assign int_reset_squelch = int_comk & !int_g12_rxeios_detect;

// When LTSSM entries/exits L1 state, core_clk is stopped before the squelch_reg isn't cleared.
// This FF uses ungarted core clock.
always @(posedge core_clk_ug or negedge core_rst_n) begin : squelch_reg_PROC
    if (~core_rst_n)
        squelch_reg <= #TP 1'h0;
    else if (set_squelch_i)
        squelch_reg <= #TP 1'h1;
    else if (reset_squelch)
        squelch_reg <= #TP 1'h0;
end // squelch_reg_PROC

// function to determine when enough IDL symbols are detected.
function automatic enuf;
input [2:0] chk;
begin
// Spec requires 2 of 3 valid IDL characters. RocketIO needs weaker checking
     enuf =  chk[0] & chk[1]
           | chk[1] & chk[2]
           | chk[0] & chk[2];
end
endfunction // enuf

// detect commas (COM) and save some past history
assign chk_com = {comk[3:0], comkq[3:1]};

always @(posedge core_clk or negedge core_rst_n)
    if (~core_rst_n)
        comkq <= #TP 3'h0;
    else if ( cfg_elastic_buffer_mode && ~rxdatavalid )
        comkq <= #TP (rxvalid) ? comkq : 3'h0;
    else if (active_nb[2])  // 4s
        comkq <= #TP comk[3:1];
    else if (active_nb[1])  // 2s
        comkq <= #TP {comk[1:0], comkq[3]};
    else
        comkq <= #TP {comk[0], comkq[3:2]};

assign comk = {
               active_nb[2]                & rxvalid_i & rxdatak[3] & (rxdata[31:24] == `COMMA_8B),
               active_nb[2]                & rxvalid_i & rxdatak[2] & (rxdata[23:16] == `COMMA_8B),
               (active_nb[2]|active_nb[1]) & rxvalid_i & rxdatak[1] & (rxdata[15:8]  == `COMMA_8B),
               |active_nb                  & rxvalid_i & rxdatak[0] & (rxdata[7:0]   == `COMMA_8B)
               };

// detect idles (IDL) and save some past history

assign chk_idl = {idlk[3:0], idlkq[3:2]};

always @(posedge core_clk or negedge core_rst_n)
    if (~core_rst_n)
        idlkq <= #TP 2'h0;
    else if ( cfg_elastic_buffer_mode && ~rxdatavalid )
        idlkq <= #TP (rxvalid) ? idlkq : 2'h0;
    else if (active_nb[2])  // 4s
        idlkq <= #TP idlk[3:2];
    else if (active_nb[1])  // 2s
        idlkq <= #TP idlk[1:0];
    else
        idlkq <= #TP {idlk[0], idlkq[3]};

assign idlk = {
               active_nb[2]                & rxvalid_i & rxdatak[3] & (rxdata[31:24] == `EIDLE_8B),
               active_nb[2]                & rxvalid_i & rxdatak[2] & (rxdata[23:16] == `EIDLE_8B),
               (active_nb[2]|active_nb[1]) & rxvalid_i & rxdatak[1] & (rxdata[15:8]  == `EIDLE_8B),
               |active_nb                  & rxvalid_i & rxdatak[0] & (rxdata[7:0]   == `EIDLE_8B)
               };

// chk_idl[7:2] = {idlk[3;0], idlkq[3:2]}, idlk[3:0] is for current cycle, idlkq[3:2] is for previous cycle,
// i.e. chk_idl[7:4] is for current cycle.
// current_rxdatak_i is rxdatak mask for current cycle. So only need consider idlk[3:0].
// If eios was detected on the previous cycle, rxvalid=0 on the current cycle, mask rxdatak = 0 regardless.
// for RIO_POPULATED, only need one IDL symbol, so take higher priority from byte 0, chk_idl[4] = idlk[0].
// for ~RIO_POPULATED, need two IDLs, so take higher priority from byte[1:0], chk_idl[5:4] = idlk[1:0].
assign current_rxdatak_i =                             // chk_idl[4] = 1 for chk_com[1] or chk_com[2]
                             ((chk_com[1] & (&chk_idl[4:3] | (chk_idl[4] & chk_idl[2]))) |
                              (chk_com[2] & (&chk_idl[4:3])))                              ? 8'b00000001 :
                             // chk_idl[5] = 1 for chk_com[2] or chk_com[3]
                             ((chk_com[2] & enuf(chk_idl[5:3])) |
                              (chk_com[3] & (&chk_idl[5:4])))                              ? 8'b00000011 :
                             // chk_idl[6] = 1 for chk_com[3] or chk_com[4]
                             ((chk_com[3] & enuf(chk_idl[6:4])) |
                              (chk_com[4] & (&chk_idl[6:5])))                              ? 8'b00000111 :
                             // chk_idl[7] = 1 for chk_com[4]
                             ( chk_com[4] & enuf(chk_idl[7:5]))                            ? 8'b00001111 : 8'b00000000 ;
                             // default is chk_com[5] = 1, so set to 0s for the next cycle

always @* begin : sq_rxdatak_PROC
    sq_rxdatak = 0;
    sq_rxdatak = g12_rxeios_detect ? (rxdatak & current_rxdatak_i[NB-1:0]) : rxdatak;
end // sq_rxdatak_PROC

always @(*) begin : eios_eieos_det_PROC
    eios_eieos_det = 0;
    eios_eieos_det = |{
        (active_nb[2])    & rxdatak[3] & (rxdata[31:24] == 8'h7C | rxdata[31:24] == 8'hFC),
        (active_nb[2])    & rxdatak[2] & (rxdata[23:16] == 8'h7C | rxdata[23:16] == 8'hFC),
        (|active_nb[2:1]) & rxdatak[1] & (rxdata[15:8]  == 8'h7C | rxdata[15:8]  == 8'hFC),
        |active_nb        & rxdatak[0] & (rxdata[7:0]   == 8'h7C | rxdata[7:0]   == 8'hFC)
                      };
end // eios_eieos_det_PROC


wire       eios_sym_n;     //symbol is not eios symbol
wire       sync_header_os; //OS sync header
wire       int_gen3_rcvd_4eidle_set;
reg  [4:0] sym_count;      //symbol count per EIOS
reg  [1:0] eios_count;     //consecutive EIOS count
reg  [31:0] pat_eios_sym;  // EIOS symbol pattern

    reg  [3:0] eios_sym_n_vec; //a vector of a symbol not a eios symbol

always @(*) begin : eios_sym_n_PROC
    pat_eios_sym = (current_data_rate == `GEN6_RATE) ? `GEN6_32B_EIOS_SYM_0 :
                     {4{`EIOS_SYM_0}};
    eios_sym_n_vec = 0;
    eios_sym_n_vec = {
        (|active_nb[AW-1:2])     & rxvalid_i & (rxdata[31:24] != pat_eios_sym[31:24]),
        (|active_nb[AW-1:2])     & rxvalid_i & (rxdata[23:16] != pat_eios_sym[23:16]),
        (|active_nb[AW-1:1])     & rxvalid_i & (rxdata[15:8]  != pat_eios_sym[15:8]),
        |active_nb               & rxvalid_i & (rxdata[7:0]   != pat_eios_sym[7:0])
                };
end
assign eios_sym_n = |eios_sym_n_vec && ltssm_current_data_rate_g3;
assign sync_header_os = (rxsyncheader[1:0] == `SYNC_OS_BLOCK) && ltssm_current_data_rate_g3 && rxvalid_i;

//count the number of ~rxdatavalid within a Block. Wrong if it is 3.
//~rxdatavalid can be two cycles anywhere within a Block.
always @(posedge core_clk or negedge core_rst_n) begin : rxdatavalid_n_cnt_PROC
    if (!core_rst_n) begin
        rxdatavalid_n_cnt <= #TP 0;
    end else if (rxvalid && rxstartblock[0]) begin //reset to 0 at rxstartblock
        rxdatavalid_n_cnt <= #TP 0;
    end else if (rxdatavalid_n_cnt == 3) begin //hold if rxdatavalid_n_cnt==3
        rxdatavalid_n_cnt <= #TP rxdatavalid_n_cnt;
    end else if (rxvalid && ~rxdatavalid) begin //increment by 1 if ~rxdatavalid
        rxdatavalid_n_cnt <= #TP rxdatavalid_n_cnt + 1;
    end else if (~rxvalid) begin //its wrong if ~rxvalid during a Block
        rxdatavalid_n_cnt <= #TP 3;
    end
end //always @(posedge

//if not eios sym, assign sym_count = 31 and keep it until rxstartblock
//if rxstartblock, trigger count down from (16 - active_nb)
always @(posedge core_clk or negedge core_rst_n) begin : sym_count_PROC
    if ( ~core_rst_n )
        sym_count <= #TP 31;
    else if (~rxvalid || ((rxdatavalid_n_cnt == 3) && (~cfg_elastic_buffer_mode)))
        sym_count <= #TP 31;
    else if (~rxdatavalid)
        sym_count <= #TP sym_count;
    else if (eios_sym_n)
        sym_count <= #TP 31;
    else if (rxstartblock[0] && sync_header_os && ~eios_sym_n)
        sym_count <= #TP 16 - active_nb;
    else if (sym_count >= 16)
        sym_count <= #TP sym_count;
    else if (~eios_sym_n)
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        sym_count <= #TP sym_count - active_nb;
// spyglass enable_block W164a
end

//if (sym_count != 0) at rxstartblock, it is not a EIOS (including length > or < 16 symbols)
always @(posedge core_clk or negedge core_rst_n) begin : eios_count_PROC
    if ( ~core_rst_n ) begin
        eios_count <= #TP 0;
    end else if ( current_data_rate == `GEN6_RATE && ltssm_in_lpbkactive ) begin
        if ( g6_clk_cnt_expired )
            eios_count <= #TP (g6_rxeios_rcvd[0]) ? eios_count + 1 : 0;
    end else if (((sym_count != 0) && rxstartblock[0]) || ~ltssm_in_lpbkactive)
        eios_count <= #TP 0;
    else if ((sym_count == 0) && rxstartblock[0] && sync_header_os)
        eios_count <= #TP eios_count + 1;
end

//first 3 EIOSs have to be full EIEOS 16 symbols and the forth EIOS needs the first 4 symbols matching
assign int_gen3_rcvd_4eidle_set = (current_data_rate >= `GEN6_RATE) ? ((eios_count == 3 && g6_rxeios_rcvd[0]) ) : ((eios_count == 3) && g3_rxeios_rcvd);

reg g3_rxeios_rcvd_4s; // Registered version of RxEIOS for 4s

always @(posedge core_clk or negedge core_rst_n) begin : rxeios_4s_PROC
    if(!core_rst_n)
        g3_rxeios_rcvd_4s <= #TP 1'b0;
    else
        g3_rxeios_rcvd_4s <= #TP (~eios_sym_n && rxstartblock[0] && sync_header_os);
end

//logic below for EIOS detection at Gen3 rate (only first 4 symbols)
assign g3_rxeios_rcvd = |active_nb[1:0] ? (sym_count == 12) : // 1s/2s
                       |active_nb[3:2] ? g3_rxeios_rcvd_4s                  : // 4s/8s
                        0;

assign int_rxosblock[0] = (rxvalid & rxdatavalid & rxstartblock[0] & ((rxsyncheader[1:0] == `SYNC_OS_BLOCK) | (smlh_ltssm_state == S_POLL_COMPLIANCE)));

// g6_clk_cnt 2-bit
always @* begin : g6_clk_cnt_PROC
        g6_clk_cnt = g6_clk_cnt_d;

    if ( int_rxosblock[0] )
        g6_clk_cnt = 0;
    else if ( ~rxvalid )
        g6_clk_cnt = 0;
    else if ( &g6_clk_cnt_d )
        g6_clk_cnt = g6_clk_cnt_d;
    else if ( rxdatavalid )
        g6_clk_cnt = g6_clk_cnt_d + 1'b1;
end // g6_clk_cnt_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : g6_clk_cnt_d_PROC
    if ( ~core_rst_n )
        g6_clk_cnt_d <= #TP 0;
    else
        g6_clk_cnt_d <= #TP g6_clk_cnt;
end // g6_clk_cnt_d_PROC

// record rx data for eios
always @* begin : eios_byte_rcvd_PROC
    integer i;
    eios_byte_rcvd = 0;

    for ( i=0; i<NB2; i=i+2 ) begin
        if ( rxdata[i*8 +: 8] == `EIOS_G6_S0 && rxvalid & rxdatavalid )
            eios_byte_rcvd[i] = 1'b1;

        if ( rxdata[(i+1)*8 +: 8] == `EIOS_G6_S1 && rxvalid & rxdatavalid )
            eios_byte_rcvd[i+1] = 1'b1;
    end
end // eios_byte_rcvd_PROC

// detect which byte has eios symbol true starting from 1st clock with int_rxosblock
always @* begin : eios_byte_rcvd_i_PROC
    eios_byte_rcvd_i = eios_byte_rcvd_d;

    if ( g6_clk_cnt_d == 0 && rxvalid && rxdatavalid ) begin // 2nd clock
        eios_byte_rcvd_i[8 +: 8]  = eios_byte_rcvd[0 +: 8];
    end

    if ( int_rxosblock[0] ) begin // 1st clock
        eios_byte_rcvd_i = eios_byte_rcvd;
    end

    if ( ~rxvalid ) begin
        eios_byte_rcvd_i = 0;
    end
end // eios_byte_rcvd_i_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : eios_byte_rcvd_d_PROC
    if ( ~core_rst_n ) begin
        eios_byte_rcvd_d <= #TP 0;
    end else begin
        eios_byte_rcvd_d <= #TP eios_byte_rcvd_i;
    end
end // eios_byte_rcvd_d_PROC

// any 5 or more aligned bytes of the first 8 bytes of a Block match the corresponding bytes of an EIOS, and
// either the first byte or the 8th byte of Block matches the corresponding byte of an EIOS
// during or at data stream, no need the first byte or 8th byte to match eios symbol
assign g6_clk_cnt_expired = (g6_clk_cnt == (16/NB - 1));
assign g6_rxeios_rcvd[0] = g6_clk_cnt_expired && ((eios_byte_rcvd_i[0] + eios_byte_rcvd_i[1] + eios_byte_rcvd_i[2] + eios_byte_rcvd_i[3] + eios_byte_rcvd_i[4] + eios_byte_rcvd_i[5] + eios_byte_rcvd_i[6] + eios_byte_rcvd_i[7]) >= 5) & (deskew_ds_g6 ? 1'b1 : (eios_byte_rcvd_i[0] | eios_byte_rcvd_i[8]));


always @(posedge core_clk or negedge core_rst_n)
    if (~core_rst_n) begin
        rxvalid_d <= #TP 0;
        rmlh_rxvalid_deasserted <= #TP 0;
    end else begin
        rxvalid_d <= #TP rxvalid;

        if( ~(squelch|squelch_reg) && !rxvalid && rxvalid_d) 
             rmlh_rxvalid_deasserted <= #TP 1;
        else
              rmlh_rxvalid_deasserted <= #TP 0;
    end


endmodule
