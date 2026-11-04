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
// ---    $DateTime: 2024/01/12 11:11:14 $ 
// ---    $Revision: #10 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_stsh_msiMngr.sv#10 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram1p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rvData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_stsh_msiMngr
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       type P_PIPE_TYPE = logic
  ,parameter                 P_CHAN = 16
  ,parameter              P_RAM_LAT = 3
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp  b_clk
  ,DWC_pcie_edmapf_ram1p_if.slave_mp  b_crgb
  ,DWC_pcie_edmapf_rvData_if.slave_mp b_in
  ,DWC_pcie_edmapf_tlp_if.master_mp   b_msi
  ,DWC_pcie_edmapf_ram2p_if.master_mp b_ram
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################

  localparam L_CHANWD = (P_CHAN == 1) ? 1 : $clog2(P_CHAN)                          ;


// SNPS_SysML_CODE_START

  localparam integer LP_REG_DELAY_DENOM = 1000;
  localparam integer LP_REG_DELAY_TIME  = `TP * LP_REG_DELAY_DENOM;
  localparam L_DATA_WD = (K_COREBUSWD * K_RAS_PROT_RANGE) / (K_RAS_PROT_RANGE + 1);
  localparam L_PROT_WD = K_COREBUSWD - L_DATA_WD;
  

  typedef enum logic [1:0] {
    E_AR_NONE = 2'b00,
    E_AR_CRGB = 2'b01,
    E_AR_CTRL = 2'b10,
    E_AR_BOTH = 2'b11
  } arbiterRequest_e;

  typedef struct packed {
    intType_e            interrupt;
    glbData_s            globalCtx;
    logic [L_CHANWD-1:0] channel;
  } thinPipe_s;

  typedef struct packed {
    thinPipe_s pipe;
    logic      valid;
  } validPipe_s;

  function automatic validPipe_s f_pipeThinner(input P_PIPE_TYPE pipe);
    f_pipeThinner.pipe.globalCtx = pipe.globalCtx;
    f_pipeThinner.pipe.channel = pipe.channel;
    if (pipe.interrupts.pins.abort) begin
      f_pipeThinner.pipe.interrupt = E_INT_ABORT;
      f_pipeThinner.valid = '1;
    end else if(pipe.interrupts.pins.stop) begin
      f_pipeThinner.pipe.interrupt = E_INT_STOP;
      f_pipeThinner.valid = '1;
    end else if(pipe.interrupts.pins.watermark) begin
      f_pipeThinner.pipe.interrupt = E_INT_WATERMARK;
      f_pipeThinner.valid = '1;
    end else begin
      f_pipeThinner.pipe.interrupt = E_INT_WATERMARK;
      f_pipeThinner.valid = '0;
    end
    return f_pipeThinner;
  endfunction

  struct packed {
    logic                crgbOutWdone;
    logic [L_CHANWD-1:0] crgbInAddr  ;
    logic                crgbInValid ;
  }r,s;

  /*
  * r register.
  */
  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : r_PROC
    if (!b_clk.w_reset_n) begin
      r <= #`TP 0;
    end else begin
      r <= #`TP s;
    end
  end : r_PROC

  logic [L_DATA_WD-1:0]   s_dataNoProt               ;
  logic [L_PROT_WD-1:0]   s_dataProt                 ;
  logic [K_COREBUSWD-1:0] s_data                     ;
  logic [63:0]            s_addr                     ;
  logic                   s_inFifo_push_req_n        ;
  logic                   s_inFifo_pop_req_n         ;
  thinPipe_s              s_inFifo_data_in           ;
  thinPipe_s              w_inFifo_data_out          ;
  logic                   w_inFifo_full              ;
  logic                   s_dampingFifo_push_req_n   ;
  logic                   s_dampingFifo_pop_req_n    ;
  logic                   w_dampingFifo_empty        ;
  msiInfo_s               w_dampingFifo_data_out     ;
  arbiterRequest_e        s_arbiter_request          ;
  logic [1:0]             w_arbiter_grant            ;
  logic                   w_arbiter_granted          ;
  validPipe_s             s_pipe                     ;



  DWC_pcie_ctl_bcm65_td
    #( //Synchronous (Single Clock) FIFO with Static Flags
     .WIDTH           ( $bits(thinPipe_s)       )
    ,.DEPTH           ( P_RAM_LAT               )
    ,.AE_LEVEL        ( 1                       )
    ,.AF_LEVEL        ( 1                       )
    ,.ERR_MODE        ( 2                       )
    ,.RST_MODE        ( 0                       )
    ,.ADDR_WIDTH      ( $clog2(P_RAM_LAT)       )
    ,.REG_DELAY_TIME  ( LP_REG_DELAY_TIME       )
    ,.REG_DELAY_DENOM ( LP_REG_DELAY_DENOM      )
    )
    u_inFifo(
       .clk           ( b_clk.w_main_clk        )
      ,.rst_n         ( b_clk.w_reset_n         )
      ,.init_n        ( 1'b1                    )
      ,.push_req_n    ( s_inFifo_push_req_n     )
      ,.pop_req_n     ( s_inFifo_pop_req_n      )
      ,.data_in       ( s_inFifo_data_in        )
      ,.data_out      ( w_inFifo_data_out       )
      ,.full          ( w_inFifo_full           )
        ,.diag_n      ( 1'b0                    )
      // SMD: Output port to an instance is not connected
      // SJ:  These ports are not used.
      // spyglass disable_block W287b
      ,.empty         ( /* NC */                )
      ,.almost_empty  ( /* NC */                )
      ,.half_full     ( /* NC */                )
      ,.almost_full   ( /* NC */                )
      ,.error         ( /* NC */                )
      // spyglass enable_block W287b
      );

  assign s_pipe = f_pipeThinner(b_in.w_data);
  assign s_inFifo_push_req_n = !(b_in.w_valid && b_in.w_ready && s_pipe.valid);
  assign s_inFifo_pop_req_n  = s_dampingFifo_pop_req_n;
  assign s_inFifo_data_in    = s_pipe.pipe;


  /*
  * The MSI ram is only written by the crgb interface.
  */
  assign b_ram.w_ena    = b_crgb.w_wren;
  assign b_ram.w_wea    = b_crgb.w_wren;
  assign b_ram.w_addra  = b_crgb.w_addr;
  assign b_ram.w_dina   = b_crgb.w_din ;
  assign b_crgb.w_wdone = r.crgbOutWdone;
  assign s.crgbOutWdone = b_crgb.w_wren;

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // READ ARBITER
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  DWC_pcie_ctl_bcm55
   #(
     .N           ( 2                 )//Source count
    ,.OUTPUT_MODE ( 0                 )//Unregistered outputs
    ,.INDEX_WIDTH ( 1                 )//$clog2(N)
    )
    u_arbiter(
       .clk         ( b_clk.w_aux_clk            )
      ,.rst_n       ( b_clk.w_reset_n            )
      ,.init_n      ( 1'b1                       )
      ,.enable      ( 1'b1                       )
      ,.mask        ( 2'b00                      )
      ,.request     ( s_arbiter_request          )
      ,.grant       ( w_arbiter_grant            )
      ,.granted     ( w_arbiter_granted          )
      // SMD: Output port to an instance is not connected
      // SJ:  These ports are not used.
      // spyglass disable_block W287b
      ,.grant_index ( /* NC */                   )
      // spyglass enable_block W287b
      );

  /*
  * Sets the arbiter request signals.
  * CRGB request when registered crgb is valid.
  * CTRL request when the input is valid
  */
  always_comb begin : s_arbiter_request_PROC
    case ({b_in.w_valid && !w_inFifo_full, r.crgbInValid})
      default: s_arbiter_request = E_AR_NONE;
      2'b01  : s_arbiter_request = E_AR_CRGB;
      2'b10  : s_arbiter_request = E_AR_CTRL;
      2'b11  : s_arbiter_request = E_AR_BOTH;
    endcase
  end : s_arbiter_request_PROC

  /*
  * CRGB requets register.
  * The CRGB is registered because the input is a valid pulse.
  * This prevents the request loss during CTRL grants.
  * The registers become invalid after a sucessful grant.
  */
  always_comb begin : crgbInValid_PROC
    if (b_crgb.w_rden) begin
      s.crgbInValid = 1'b1;
    end else if ( w_arbiter_granted && w_arbiter_grant == E_AR_CRGB) begin
      s.crgbInValid = 1'b0;
    end else begin
      s.crgbInValid = r.crgbInValid;
    end
  end : crgbInValid_PROC

  assign s.crgbInAddr = b_crgb.w_rden ? b_crgb.w_addr : r.crgbInAddr;

  /*
  * Filtered arbiter request, this prevents arbiter lock during back2back requests.
  */

  /*
  * The interface is back pressured by the arbiter only.
  * If the read fifo is full of ctrl requests it should already have been back pressured by the inFifo.
  */
  assign b_in.w_ready = !w_inFifo_full && w_arbiter_granted && w_arbiter_grant == E_AR_CTRL;

  /*
  * MSI RAM Drivers.
  */
  always_comb begin : b_ram_w_addrb_PROC
    case (w_arbiter_grant)
      default   : b_ram.w_addrb = '0                 ;
      E_AR_CRGB : b_ram.w_addrb = r.crgbInAddr       ;
      E_AR_CTRL : b_ram.w_addrb = b_in.w_data.channel;
    endcase
  end : b_ram_w_addrb_PROC

  assign b_ram.w_enb = w_arbiter_granted;

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // READ FIFO
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  logic [1:0]  w_rdFifo_data_out ;

  DWC_pcie_ctl_bcm65_td
    #( //Synchronous (Single Clock) FIFO with Static Flags
     .WIDTH           ( 2                   )//arb grant output
    ,.DEPTH           ( P_RAM_LAT           )//enouph to allow the RAM requests to arrive
    ,.AE_LEVEL        ( 1                   )//do not care about this
    ,.AF_LEVEL        ( 1                   )//do not care about this
    ,.ERR_MODE        ( 2                   )//underflow/overflow latched checking
    ,.RST_MODE        ( 0                   )//asynchronous reset excluding memory
    ,.ADDR_WIDTH      ( $clog2(P_RAM_LAT)   )//$clog2(DEPTH)
    ,.REG_DELAY_TIME  ( LP_REG_DELAY_TIME   )
    ,.REG_DELAY_DENOM ( LP_REG_DELAY_DENOM  )
    )
    u_rdFifo(
       .clk             ( b_clk.w_aux_clk     )
      ,.rst_n           ( b_clk.w_reset_n     )
      ,.init_n          ( 1'b1                )
      ,.push_req_n      ( !w_arbiter_granted  )
      ,.pop_req_n       ( !b_ram.w_validb     )
      ,.data_in         ( w_arbiter_grant     )
      ,.data_out        ( w_rdFifo_data_out   )
      ,.diag_n          ( 1'b0                )
      // SMD: Output port to an instance is not connected
      // SJ:  These ports are not used.
      // spyglass disable_block W287b
      ,.full            ( /* NC */            )
      ,.empty           ( /* NC */            )
      ,.almost_empty    ( /* NC */            )
      ,.half_full       ( /* NC */            )
      ,.almost_full     ( /* NC */            )
      ,.error           ( /* NC */            )
      // spyglass enable_block W287b
      );


  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // DAMPING FIFO
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  DWC_pcie_ctl_bcm65_td
    #( //Synchronous (Single Clock) FIFO with Static Flags
     .WIDTH           ( $bits(msiInfo_s)         )//arb grant output
    ,.DEPTH           ( P_RAM_LAT                )//enouph to allow the RAM requests to arrive
    ,.AE_LEVEL        ( 1                        )//do not care about this
    ,.AF_LEVEL        ( 1                        )//do not care about this
    ,.ERR_MODE        ( 2                        )//underflow/overflow latched checking
    ,.RST_MODE        ( 0                        )//asynchronous reset excluding memory
    ,.ADDR_WIDTH      ( $clog2(P_RAM_LAT)        )//$clog2(DEPTH)
    ,.REG_DELAY_TIME  ( LP_REG_DELAY_TIME        )
    ,.REG_DELAY_DENOM ( LP_REG_DELAY_DENOM       )
    )
    u_dampingFifo(
       .clk             ( b_clk.w_aux_clk          )
      ,.rst_n           ( b_clk.w_reset_n          )
      ,.init_n          ( 1'b1                     )
      ,.push_req_n      ( s_dampingFifo_push_req_n )
      ,.pop_req_n       ( s_dampingFifo_pop_req_n  )
      ,.data_in         ( b_ram.w_doutb            )
      ,.data_out        ( w_dampingFifo_data_out   )
      ,.empty           ( w_dampingFifo_empty      )
      ,.diag_n          ( 1'b0                     )
      // SMD: Output port to an instance is not connected
      // SJ:  These ports are not used.
      // spyglass disable_block W287b
      ,.full            ( /* NC */                 )
      ,.almost_empty    ( /* NC */                 )
      ,.half_full       ( /* NC */                 )
      ,.almost_full     ( /* NC */                 )
      ,.error           ( /* NC */                 )
      // spyglass enable_block W287b
      );


  assign s_dampingFifo_pop_req_n  = b_msi.w_halt || w_dampingFifo_empty;
  assign s_dampingFifo_push_req_n = !(w_rdFifo_data_out == E_AR_CTRL && b_ram.w_validb);
  assign b_crgb.w_rdone           = w_rdFifo_data_out == E_AR_CRGB && b_ram.w_validb;
  assign b_crgb.w_dout            = b_crgb.w_rdone ? b_ram.w_doutb : {$bits(msiInfo_s){1'b0}};

  always_comb begin : addr_PROC
    case (w_inFifo_data_out.interrupt)
      E_INT_ABORT: s_addr = w_dampingFifo_data_out.abort_addr    ;
      E_INT_STOP : s_addr = w_dampingFifo_data_out.stop_addr     ;
      default    : s_addr = w_dampingFifo_data_out.watermark_addr;
    endcase
  end

  // Generator
  ras_dp_pipe
   #(
    .PIPELINE_TYPE              (0                             ), // 0: delay_n
    .RESETVAL                   (0                             ),
    .N_STAGES                   (0                             ),
    .CAN_STALL                  (0                             ),
    .RESET_STALL                (0                             ),
    .BUS_PROTECT_GEN_EN         (1                             ), // 1: Bus Protection Generator is present
    .BUS_PROTECT_CHK_EN         (0                             ), // 0: Bus Protection Checker is not present (ECC/Parity)
    .PROT_TYPE                  (1                             ), // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                 (K_RAS_PROT_RANGE              ), // Number of bits to calculate parity/ECC on
    .PROT_WD                    (L_PROT_WD                     ), // Selects the width of the din_prot/dout_prot signals
    .PARITY_MODE                (K_RAS_PARITY_MODE             ), // selects the type of parity: 0=Even, 1=Odd
    .PROT_CORRECT_EN            (/* NC */                      ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH                (L_DATA_WD                     ), 
    .EXCLUDE_PROT_WIDTH         (0                             ),
    .RAS_DP_PROT_CHK_ID_BASE    (/* NC */                      ), // Associates the Bus Protection Checker with a unique identifier
    .ADDR_ECC_PROT_EN           (/* NC */                      ),
    .ADDR_LOG_EN                (/* NC */                      ),
    .ADDR_INDEX                 (/* NC */                      ),
    .ADDR_WD                    (/* NC */                      )
  ) u_ras_gen (
     .clk                       ( b_clk.w_main_clk                        )
    ,.rst_n                     ( b_clk.w_reset_n                         )
    ,.din                       ( L_DATA_WD'(w_dampingFifo_data_out.msgd) )
    ,.din_prot                  ( {L_PROT_WD{1'b0}}                       )
    ,.dout                      ( s_dataNoProt                            )
    ,.dout_prot                 ( s_dataProt                              )
    ,.en                        ( 1'b1                                    )
    ,.bypass                    ( 1'b0                                    )
    ,.stall                     ( 1'b0                                    )
    ,.stallout                  ( /* Not Connected */                     )
    ,.valid_in                  ( !w_dampingFifo_empty                    )
    ,.halt_out                  ( /* Not Connected */                     )
    ,.valid_out                 ( /* Not Connected */                     )
    ,.halt_in                   ( 1'b0                                    )
    ,.ras_dp_err_inband_kbd_in  ( 1'b0                                    )
    ,.ras_dp_err_inband_kbd_out ( /* Not Connected */                     )
    ,.ras_dp_err_log            ( /* Not Connected */                     )
      ,.ras_dp_err_inj          ( '0                                      )
  );
  
  assign s_data = {s_dataProt,s_dataNoProt};

  /*
  * msi Driver
  */
  always_comb begin : msi_PROC
    b_msi.w_header     = '0;
    b_msi.w_data       = '0;
    b_msi.w_hv         = '0;
    b_msi.w_dv         = '0;
    b_msi.w_eot        = '0;
    b_msi.w_headerProt = '0;
    if (!w_dampingFifo_empty) begin
      b_msi.w_hv                                = 1'b1;
      b_msi.w_dv                                = 1'b1;
      b_msi.w_eot                               = 1'b1;
      b_msi.w_data                              = s_data;
      b_msi.w_header.common1.vfunc_active       = w_inFifo_data_out.globalCtx.tlpSettings.d_vf_en;
      b_msi.w_header.common1.vfunc_num          = w_inFifo_data_out.globalCtx.tlpSettings.d_vf[K_VFWD-2:0];
      b_msi.w_header.common1.pfunc_num          = w_inFifo_data_out.globalCtx.tlpSettings.d_pf[K_PFWD-1:0];
      b_msi.w_header.common1.tc                 = w_inFifo_data_out.globalCtx.tlpSettings.d_tc;
      b_msi.w_header.common1.attr.snoop         = '0 ; //w_inFifo_data_out.globalCtx.tlpSettings.d_sn;
      b_msi.w_header.common1.attr.relaxOrder    = '0 ; //w_inFifo_data_out.globalCtx.tlpSettings.d_ro;
      b_msi.w_header.common2.ats                = w_inFifo_data_out.globalCtx.tlpSettings.d_ats;
      b_msi.w_header.common2.dw_len             = 'd1;
      b_msi.w_header.common2.first_be           = 4'b1111;
      b_msi.w_header.common2.fmt                = {1'b1, |s_addr[63:32]};
      b_msi.w_header.common2.addr               = s_addr;
      b_msi.w_header.common2.prfx               = K_PRFXDEFAULT;
      b_msi.w_header.dma.req                    = (P_CHANNEL == E_WRITE) ? E_DMA_WRCH_INT : E_DMA_RDCH_INT;
      b_msi.w_header.dma.channel[L_CHANWD-1:0]  = w_inFifo_data_out.channel;
      b_msi.w_header.xadmPort.atu_bypass        = '1;
    end
  end : msi_PROC

// SNPS_SysML_CODE_END

endmodule
