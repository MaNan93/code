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
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_rasdes_ec_ramcont.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module is RAM event counter controller for RAS D.E.S.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_rasdes_ec_ramcont
#(
    parameter                               INST                    = 0,                               // The uniquifying parameter for each port logic instance.
    parameter                               TP                      = `TP,                             // Clock to Q delay (simulator insurance)
    parameter                               RASDES_RAM_DATA_WIDTH   = `CX_RAS_DES_EC_RAM_DATA_WIDTH,   // RAM data width
    parameter                               RASDES_RAM_ADDR_WIDTH   = `CX_RAS_DES_EC_RAM_ADDR_WIDTH,   // RAM address data width
    parameter                               NUMEVT                  = 16                               // The nuber of event counters implemeted in RAM
)
(
// -------------- Inputs ---------------
    input                                     aux_clk,               // Clock
    input                                     sticky_rst_n,          // Reset sticky registers only
    //---- Common ----
    input                                     ec_ram_actreq,         // RAM control activation request

    //---- Event counter ----
    // Please update (C1) and (C2) if you added/reduced the input ec_cnt_*.
    input  [NUMEVT-1:0]                       ec_clr_bus,            // Event counter per clear bus
    input                                     ec_clr_all,            // Event counter all clear
    input  [32*NUMEVT-1:0]                    ec_cnt_bus,            // Event counter bus

    //---- RAM interface ----
    input  [RASDES_RAM_DATA_WIDTH-1:0]        ec_ram_dataout,        // Event counter

    //---- Register read/write access
    input                                     reg_req,               // Register access request
    input  [8:0]                              reg_index,             // Register access event counter index
// -------------- Outputs ---------------
    //---- Common ----
    output                                    ec_ram_active,         // RAM control activeted
    output [NUMEVT-1:0]                       ec_ram_add_status,     // Event counter addition status (timing to clear counters)
    //---- RAM interface ----
    output                                    ec_ram_ena,            // Event counter
    output                                    ec_ram_wea,            // Event counter
    output      [RASDES_RAM_ADDR_WIDTH-1:0]   ec_ram_addra,          // Event counter
    output      [RASDES_RAM_DATA_WIDTH-1:0]   ec_ram_datain,         // Event counter
    output                                    ec_ram_enb,            // Event counter
    output      [RASDES_RAM_ADDR_WIDTH-1:0]   ec_ram_addrb,          // Event counter

    //---- Register read/write access ----
    output reg                                reg_ack,               // Register access ack
    output reg  [RASDES_RAM_DATA_WIDTH/2-1:0] reg_rdata              // Register access read data
) ;
    localparam [RASDES_RAM_ADDR_WIDTH-1:0]      RAM_ADDR_E                = (NUMEVT+1)/2 - 1 ; // 64bit RAM final address
    localparam                                  SR_MODE                   = RAM_ADDR_E<3 ; // Small ram mode
    localparam                                  INT_NUMEVT                = SR_MODE ? 8 : NUMEVT ;                     // Small ram mode
    localparam                                  INT_RASDES_RAM_ADDR_WIDTH = SR_MODE ? 2 : RASDES_RAM_ADDR_WIDTH ;      // Small ram mode
    localparam [INT_RASDES_RAM_ADDR_WIDTH-1:0]  INT_RAM_ADDR_E            = SR_MODE ? 3 : RAM_ADDR_E ;                 // Small ram mode

    //------------------------------------------------------------
    // Edit point
    //------------------------------------------------------------
    // End of RAM address (C1)
    // Please update this parameter if the input ec_cnt_* was added/reduced.

    wire  [RASDES_RAM_DATA_WIDTH/2-1:0]       ec_cnt_array[0:INT_NUMEVT-1] ;
    wire  [INT_NUMEVT-1:0]                    int_ec_clr_bus ;
    wire  [INT_NUMEVT-1:0]                    int_ec_ram_add_status ;
    genvar                                    ii;

    // Add index to each input signals (C2)
    // Please update this index if the input ec_cnt_* was added/reduced.
    generate
    for (ii=0; ii<INT_NUMEVT; ii=ii+1) begin : gen_ec_bus_for
      if (ii<NUMEVT) begin : gen_ec_bus_if
        if (RASDES_RAM_DATA_WIDTH/2 > 32) begin
          assign ec_cnt_array[ii]= {{(RASDES_RAM_DATA_WIDTH/2-32){1'b0}} ,ec_cnt_bus[32*ii +: 32]};
        end else begin
          assign ec_cnt_array[ii]= ec_cnt_bus[32*ii +: 32] ;
        end
          assign int_ec_clr_bus[ii]= ec_clr_bus[ii] ;
      end else begin : gen_ec_bus_else
          assign ec_cnt_array[ii]= {32{1'b0}} ;
          assign int_ec_clr_bus[ii]= 1'b0 ;
      end
    end
    endgenerate

    //------------------------------------------------------------
    // Common Control
    //------------------------------------------------------------
    //---- State Name Parameter ----
    parameter [3:0]                           ST_IDLE       = 0 ; // Idle state                              : Waiting for count enable or register access.
    parameter [3:0]                           ST_COUNT_PRE  = 1 ; // Start count control                     : Starting count control
    parameter [3:0]                           ST_COUNT      = 2 ; // Count state                             : Counting events
    parameter [3:0]                           ST_COUNT_DIS  = 3 ; // Disable count contol                    : Disabling count control
    parameter [3:0]                           ST_COUNT_POST = 4 ; // Extend count state                      : Adding tempolary counter to RAM data after disabled
    parameter [3:0]                           ST_REGACC_1ST = 5 ; // Register access 1st state               : Initialize Write/Read address to start register access
    parameter [3:0]                           ST_REGACC_IDL = 6 ; // Register access idle state              : Waiting for the RAM read data
    parameter [3:0]                           ST_REGACC_ACT = 7 ; // Register access active state            : Write or Read data is valid
    parameter [3:0]                           ST_COUNT_RST  = 8 ; // Count control reset state

    //---- Number with RAM address bit width
    parameter [INT_RASDES_RAM_ADDR_WIDTH-1:0] RAM_ADDR_0 = 0 ;
    parameter [INT_RASDES_RAM_ADDR_WIDTH-1:0] RAM_ADDR_1 = 1 ;
    parameter [INT_RASDES_RAM_ADDR_WIDTH-1:0] RAM_ADDR_2 = 2 ;
    parameter [INT_RASDES_RAM_ADDR_WIDTH-1:0] RAM_ADDR_3 = 3 ;

    reg   [3:0]                               int_state ;
    reg   [3:0]                               int_state_b ;

    reg   [INT_RASDES_RAM_ADDR_WIDTH-1:0]     int_ec_ram_addra ;
    reg   [INT_RASDES_RAM_ADDR_WIDTH-1:0]     int_ec_ram_addrb ;
    reg   [INT_RASDES_RAM_ADDR_WIDTH-1:0]     int_ec_ram_addra_ff ;
    reg   [INT_RASDES_RAM_ADDR_WIDTH-1:0]     int_ec_ram_addrb_ff ;

    reg   [INT_NUMEVT-1:0]                    ram_rst_sts ;

    wire                                      int_ec_ram_ena ;
    wire                                      int_ec_ram_enb ;
    wire                                      int_reg_req ;
    wire                                      error_sts ;

    // Constant Function to adjust the condition of the write data selector
    // If you want to increase read latency, change & replace waddr_minus1/2/3 -> waddr_minus2/3/4
    function automatic [INT_RASDES_RAM_ADDR_WIDTH-1:0] waddr_plus1 ;
        input [INT_RASDES_RAM_ADDR_WIDTH-1:0] addr ;
        case ( addr )
            INT_RAM_ADDR_E : waddr_plus1 = RAM_ADDR_0 ;
            default        : waddr_plus1 = addr + RAM_ADDR_1 ;
        endcase
    endfunction 

    function automatic [INT_RASDES_RAM_ADDR_WIDTH-1:0] waddr_minus1 ;
      input [INT_RASDES_RAM_ADDR_WIDTH-1:0] addr ;
      begin
        case ( addr )
            RAM_ADDR_0 : waddr_minus1 = INT_RAM_ADDR_E ;
            default    : waddr_minus1 = addr - RAM_ADDR_1 ;
        endcase
      end
    endfunction 

    function automatic [INT_RASDES_RAM_ADDR_WIDTH-1:0] waddr_minus2 ;
      input [INT_RASDES_RAM_ADDR_WIDTH-1:0] addr ;
      begin
        case ( addr )
            RAM_ADDR_0 : waddr_minus2 = INT_RAM_ADDR_E - RAM_ADDR_1 ;
            RAM_ADDR_1 : waddr_minus2 = INT_RAM_ADDR_E  ;
            default    : waddr_minus2 = addr - RAM_ADDR_2 ;
        endcase
      end
    endfunction

    function automatic [INT_RASDES_RAM_ADDR_WIDTH-1:0] waddr_minus3 ;
      input [INT_RASDES_RAM_ADDR_WIDTH-1:0] addr ;
      begin
        case ( addr )
            RAM_ADDR_0 : waddr_minus3 = INT_RAM_ADDR_E - RAM_ADDR_2 ;
            RAM_ADDR_1 : waddr_minus3 = INT_RAM_ADDR_E - RAM_ADDR_1  ;
            RAM_ADDR_2 : waddr_minus3 = INT_RAM_ADDR_E ;
            default    : waddr_minus3 = addr - RAM_ADDR_3 ;
        endcase
      end
    endfunction 

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_state       <= #TP ST_IDLE ;
            int_ec_ram_addra_ff <= #TP RAM_ADDR_0 ;
            int_ec_ram_addrb_ff <= #TP RAM_ADDR_0 ;
        end
        else begin
            int_state       <= #TP int_state_b ;
            int_ec_ram_addra_ff <= #TP int_ec_ram_addra ;
            int_ec_ram_addrb_ff <= #TP int_ec_ram_addrb ;
        end
    end

    assign error_sts   = reg_index >= NUMEVT ; // register access error check (dont use INT_NUMEVT)
    assign int_reg_req = reg_req & ~error_sts ;     // request with no error

    //------------------------------------------------------------
    // RAM Reset Control
    //------------------------------------------------------------
    generate
        // ram_rst_sts[index]==1 : Read data from RAM is not used and it is handled as all0 data.
        // ram_rst_sts[index]==0 : Read data from RAM is used.
        for (ii=0; ii<INT_NUMEVT; ii=ii+1) begin : gen_ram_rst_sts_for
            always @(posedge aux_clk or negedge sticky_rst_n) begin
                if (!sticky_rst_n) begin
                    ram_rst_sts[ii] <= #TP 1'b1 ;
                end
                else begin
                    if ( ec_clr_all || int_ec_clr_bus[ii] ) begin
                        ram_rst_sts[ii] <= #TP 1'b1 ;
                    end
                    else if ( int_ec_ram_ena && int_ec_ram_addra==(ii>>1) ) begin
                        ram_rst_sts[ii] <= #TP 1'b0 ;
                    end
                end
            end
        end
    endgenerate

    //------------------------------------------------------------
    // RAM Write Control
    //------------------------------------------------------------
    wire  [15:0]                              reg_index2addr ;            // Translation from RAM index to RAM address

    assign reg_index2addr = { 8'd0, reg_index[8:1] } ;

    always @(*) begin
        case ( int_state )
            ST_COUNT_PRE, ST_COUNT, ST_COUNT_DIS, ST_COUNT_POST, ST_REGACC_ACT, ST_REGACC_IDL : begin
                int_ec_ram_addra = waddr_plus1(int_ec_ram_addra_ff) ;
            end
            ST_REGACC_1ST : begin
                int_ec_ram_addra = waddr_minus3(reg_index2addr[INT_RASDES_RAM_ADDR_WIDTH-1:0]) ;
            end
            default : int_ec_ram_addra = waddr_minus3(RAM_ADDR_0) ;
        endcase
    end

    assign int_ec_ram_ena = (int_state==ST_COUNT)
                          | (int_state==ST_COUNT_DIS)
                          | (int_state==ST_COUNT_POST)
                          ;


    assign ec_ram_active = int_state==ST_COUNT_PRE
                         | int_state==ST_COUNT ;

    assign ec_ram_wea = ec_ram_ena ;

    //------------------------------------------------------------
    // RAM Read Control
    //------------------------------------------------------------
    always @(*) begin
        case ( int_state )
            ST_COUNT_PRE, ST_COUNT, ST_COUNT_DIS, ST_COUNT_POST, ST_REGACC_IDL, ST_REGACC_ACT : begin
                int_ec_ram_addrb = waddr_plus1(int_ec_ram_addrb_ff) ;
            end
            ST_REGACC_1ST : begin
                int_ec_ram_addrb = reg_index2addr[INT_RASDES_RAM_ADDR_WIDTH-1:0] ;
            end
            default : int_ec_ram_addrb = RAM_ADDR_0 ;
        endcase
    end

    assign int_ec_ram_enb = (int_state==ST_COUNT_PRE)
                          | (int_state==ST_COUNT)
                          | (int_state==ST_COUNT_DIS)
                          | (int_state==ST_COUNT_POST)
                          | (int_state==ST_REGACC_1ST)
                          | (int_state==ST_REGACC_IDL)
                          | (int_state==ST_REGACC_ACT)
                          ;

    generate
        if ( SR_MODE ) begin : gen_ec_ram_if
            assign ec_ram_ena   = (RAM_ADDR_E<int_ec_ram_addra) ? 1'b0 : int_ec_ram_ena ;
            assign ec_ram_enb   = (RAM_ADDR_E<int_ec_ram_addrb) ? 1'b0 : int_ec_ram_enb ;
            assign ec_ram_addra = (RAM_ADDR_E<int_ec_ram_addra) ? {RASDES_RAM_ADDR_WIDTH{1'b0}} : int_ec_ram_addra[RASDES_RAM_ADDR_WIDTH-1:0] ;
            assign ec_ram_addrb = (RAM_ADDR_E<int_ec_ram_addrb) ? {RASDES_RAM_ADDR_WIDTH{1'b0}} : int_ec_ram_addrb[RASDES_RAM_ADDR_WIDTH-1:0] ;
        end else begin : gen_ec_ram_else
            assign ec_ram_ena   = int_ec_ram_ena ;
            assign ec_ram_enb   = int_ec_ram_enb ;
            assign ec_ram_addra = int_ec_ram_addra ;
            assign ec_ram_addrb = int_ec_ram_addrb ;
        end
    endgenerate

    //-------------------------------------------------
    //   Event counter selector
    //-------------------------------------------------

// LMD: Undriven net Range
// LJ: All bits of this signal are driven.
// leda NTL_CON12 off
    wire  [RASDES_RAM_DATA_WIDTH-1:0]         add_data_array[0:INT_RAM_ADDR_E] ;
// leda NTL_CON12 on
    wire  [RASDES_RAM_DATA_WIDTH-1:0]         selected_add_data ;
    wire                                      dw0_clr_array[0:INT_RAM_ADDR_E] ;
    wire                                      dw1_clr_array[0:INT_RAM_ADDR_E] ;
    wire                                      dw0_clr ;
    wire                                      dw1_clr ;

    // Create write data
    // add_data_array is used with int_ec_ram_addra_ff, waddr_minus* will adjust the timing of selected_add_data.
    generate
        for (ii=0; ii<=INT_RAM_ADDR_E; ii=ii+1) begin : gen_add_data_array_for
            if ( waddr_plus1(ii)==INT_RAM_ADDR_E ) begin : gen_add_data_array_if_addr
                if ( (INT_NUMEVT%2)==0 ) begin : gen_add_data_array_if_evennum
                    assign add_data_array[ii] = {ec_cnt_array[2*waddr_plus1(ii)+1], ec_cnt_array[2*waddr_plus1(ii)]} ;
                end
                else begin : gen_add_data_array_else_evennum
                    assign add_data_array[ii] = {{RASDES_RAM_DATA_WIDTH/2{1'b0}},   ec_cnt_array[2*waddr_plus1(ii)]} ;
                end
            end
            else begin : gen_add_data_array_else_addr
                assign add_data_array[ii] = {ec_cnt_array[2*waddr_plus1(ii)+1], ec_cnt_array[2*waddr_plus1(ii)]} ;
            end
        end
    endgenerate

    assign selected_add_data = add_data_array[int_ec_ram_addra_ff] ;

    generate
        // write data for write address>=1
        for (ii=0; ii<=INT_RAM_ADDR_E; ii=ii+1) begin : gen_dw0_clr_array
            assign dw0_clr_array[ii] = ram_rst_sts[2*ii] ;
            assign int_ec_ram_add_status[2*ii] = int_ec_ram_ena & (int_ec_ram_addra_ff==waddr_minus1(ii)) ; // same with (int_ec_ram_addra==ii) but timing will be better
        end
        for (ii=0; ii<=INT_RAM_ADDR_E; ii=ii+1) begin : gen_dw1_clr_array
          if ( (INT_NUMEVT%2)==1 && ii==INT_RAM_ADDR_E ) begin : gen_dw1_clr_array_if_oddnum
            assign dw1_clr_array[ii] = 1'b1 ;
          end
          else begin :gen_dw1_clr_array_else_oddnum
            assign dw1_clr_array[ii] = ram_rst_sts[((2*ii)+1)] ;
            assign int_ec_ram_add_status[2*ii+1] = int_ec_ram_ena & (int_ec_ram_addra_ff==waddr_minus1(ii)) ; // same with (int_ec_ram_addra==ii) but timing will be better
          end
        end
    endgenerate

    assign ec_ram_add_status = int_ec_ram_add_status[NUMEVT-1:0] ;

    assign dw0_clr = dw0_clr_array[int_ec_ram_addra] ;
    assign dw1_clr = dw1_clr_array[int_ec_ram_addra] ;

    //-------------------------------------------------
    //   Event counter addition control
    //-------------------------------------------------
    wire  [RASDES_RAM_DATA_WIDTH/2-1:0]       dw0_add_data ;   // lower 32bit data
    wire  [RASDES_RAM_DATA_WIDTH/2-1:0]       dw1_add_data ;   // higher 32bit data
    wire  [RASDES_RAM_DATA_WIDTH/2-1:0]       dw0_load_data ;  // lower 32bit data
    wire  [RASDES_RAM_DATA_WIDTH/2-1:0]       dw1_load_data ;  // higher 32bit data
    wire                                      dw0_ovf ;        // overflow status of lower 32bit 
    wire                                      dw1_ovf ;        // overflow status of higher 32bit 
    wire  [RASDES_RAM_DATA_WIDTH/2-1:0]       ec_ram_datain_l ;  // lower 32bit data
    wire  [RASDES_RAM_DATA_WIDTH/2-1:0]       ec_ram_datain_h ;  // higher 32bit data
    wire  [RASDES_RAM_DATA_WIDTH-1:0]         int_ec_ram_datain ;

    assign dw0_add_data          = selected_add_data[RASDES_RAM_DATA_WIDTH/2-1:0] ;
    assign dw1_add_data          = selected_add_data[RASDES_RAM_DATA_WIDTH-1:RASDES_RAM_DATA_WIDTH/2] ;
    assign dw0_load_data         = ec_ram_dataout[RASDES_RAM_DATA_WIDTH/2-1:0] ;
    assign dw1_load_data         = ec_ram_dataout[RASDES_RAM_DATA_WIDTH-1:RASDES_RAM_DATA_WIDTH/2] ;

    assign dw0_ovf               = (~dw0_load_data) < dw0_add_data ;
    assign dw1_ovf               = (~dw1_load_data) < dw1_add_data ;

    // addition of lower 32bit
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The loss is avoided by the overflow control.
    assign ec_ram_datain_l = dw0_clr ? dw0_add_data :
                             dw0_ovf ? {RASDES_RAM_DATA_WIDTH/2{1'b1}} :
                                       dw0_load_data + dw0_add_data ;
// spyglass enable_block W164a
    // addition of higher 32bit
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The loss is avoided by the overflow control.
    assign ec_ram_datain_h = dw1_clr ? dw1_add_data :
                             dw1_ovf ? {RASDES_RAM_DATA_WIDTH/2{1'b1}} :
                                       dw1_load_data + dw1_add_data ;
// spyglass enable_block W164a

    assign ec_ram_datain = {ec_ram_datain_h, ec_ram_datain_l} ;

    // Supported max bit width of ec_ram_datain is 64 bit
    generate
      if (RASDES_RAM_DATA_WIDTH<64) begin : gen_int_ec_ram_datain_if
        assign int_ec_ram_datain = { ec_ram_datain_h
                                   , ec_ram_datain_l
                                   } ;
      end else begin : gen_int_ec_ram_datain_else
        assign int_ec_ram_datain = ec_ram_datain ;
      end
    endgenerate

    //------------------------------------------------------------
    // Register access Control
    //-----------------------------------------------------------
    wire                                      reg_ack_b ;
    reg   [RASDES_RAM_DATA_WIDTH/2-1:0]       reg_rdata_b ;
    assign reg_ack_b = reg_req & ~reg_ack &
                     ( error_sts                                                                                                                                            // Access to reserved field
                     | ((int_state==ST_COUNT) | (int_state==ST_COUNT_DIS) | (int_state==ST_COUNT_POST)) & (int_ec_ram_addra==reg_index2addr[INT_RASDES_RAM_ADDR_WIDTH-1:0])     // Read while event counter is active
                     | (int_state==ST_REGACC_ACT) ) ;                                                                                                                       // Read without any controls

    always @(*) begin
      if      ( error_sts    ) reg_rdata_b = {RASDES_RAM_DATA_WIDTH/2{1'd0}} ;
      else if ( reg_index[0] ) reg_rdata_b = int_ec_ram_datain[RASDES_RAM_DATA_WIDTH-1:RASDES_RAM_DATA_WIDTH/2] ;
      else                     reg_rdata_b = int_ec_ram_datain[RASDES_RAM_DATA_WIDTH/2-1:0] ;
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            reg_ack   <= #TP 1'b0 ;
            reg_rdata <= #TP 32'd0 ;
        end
        else begin
            reg_ack   <= #TP reg_ack_b ;
            reg_rdata <= #TP reg_rdata_b ;
        end
    end

    //------------------------------------------------------------
    // Event counter RAM Control State Machine
    //------------------------------------------------------------
    always @(*) begin
        case ( int_state )
            ST_IDLE : begin
                if ( int_reg_req ) begin
                    int_state_b = ST_REGACC_1ST ;
                end
                else if ( ec_ram_actreq ) begin
                    int_state_b = ST_COUNT_PRE ;
                end
                else begin
                    int_state_b = ST_IDLE ;
                end
            end
            //-----------------------------------------------
            //  Start counter control
            //-----------------------------------------------
            ST_COUNT_PRE : begin
                if ( int_ec_ram_addra_ff==INT_RAM_ADDR_E ) begin
                    int_state_b = ST_COUNT ;
                end
                else begin
                    int_state_b = ST_COUNT_PRE ;
                end
            end
            //-----------------------------------------------
            //  Counter control
            //-----------------------------------------------
            ST_COUNT : begin
                if ( !ec_ram_actreq ) begin
                    if ( int_ec_ram_addra_ff==INT_RAM_ADDR_E ) begin
                        // If address is INT_RAM_ADDR_E, it is possible to skip disable state.
                        int_state_b = ST_COUNT_POST ;
                    end
                    else begin
                        int_state_b = ST_COUNT_DIS ;
                    end
                end
                else begin
                    int_state_b = ST_COUNT ;
                end
            end
            //-----------------------------------------------
            //  Disabling counter control
            //  Waiting the end of ram address and preparing post process
            //-----------------------------------------------
            ST_COUNT_DIS : begin
                if ( int_ec_ram_addra_ff==INT_RAM_ADDR_E ) begin
                    int_state_b = ST_COUNT_POST ;
                end
                else begin
                    int_state_b = ST_COUNT_DIS ;
                end
            end
            //-----------------------------------------------
            //  Counter finalization
            //  After the counter disabled, all the common counters should be merged into RAM counter and should be cleared.
            //-----------------------------------------------
            ST_COUNT_POST : begin
                if ( int_ec_ram_addra_ff==INT_RAM_ADDR_E ) begin
                    int_state_b = ST_COUNT_RST ;
                end
                else begin
                    int_state_b = ST_COUNT_POST ;
                end
            end
            //-----------------------------------------------
            //  DBI access initialization
            //  1cycle inialization
            //-----------------------------------------------
            ST_REGACC_1ST : begin
                int_state_b = ST_REGACC_IDL ;
            end
            //-----------------------------------------------
            //  DBI access idle time
            //  Waiting for RAM control delay
            //-----------------------------------------------
            ST_REGACC_IDL : begin
                if ( int_ec_ram_addra_ff==waddr_minus2(reg_index2addr[INT_RASDES_RAM_ADDR_WIDTH-1:0]) ) begin // depends on the RAM Read/Write latency
                    int_state_b = ST_REGACC_ACT ;
                end
                else begin
                    int_state_b = ST_REGACC_IDL ;
                end
            end
            //-----------------------------------------------
            //  RAM register Read/Write control
            //-----------------------------------------------
            ST_REGACC_ACT : begin
                int_state_b = ST_COUNT_RST ;
            end
            //-----------------------------------------------
            //  Control initialization
            //  After the control finished, signals should be initialized for safety.
            //-----------------------------------------------
            // ST_COUNT_RST
            default : begin
                int_state_b = ST_IDLE ;
            end
        endcase
    end

`ifndef SYNTHESIS
//VCS coverage off
    wire [8*32-1:0] A_INT_STATE = int_state==ST_IDLE       ? "ST_IDLE"       :
                                  int_state==ST_COUNT_PRE  ? "ST_COUNT_PRE"  :
                                  int_state==ST_COUNT      ? "ST_COUNT"      :
                                  int_state==ST_COUNT_DIS  ? "ST_COUNT_DIS " :
                                  int_state==ST_COUNT_POST ? "ST_COUNT_POST" :
                                  int_state==ST_REGACC_1ST ? "ST_REGACC_1ST" :
                                  int_state==ST_REGACC_IDL ? "ST_REGACC_IDL" :
                                  int_state==ST_REGACC_ACT ? "ST_REGACC_ACT" :
                                  int_state==ST_COUNT_RST  ? "ST_COUNT_RST"  :
                                                             "BOGUS"         ;
//VCS coverage on
`endif //SYNTHESIS

endmodule //cdm_rasdes_ec_ramcont 
