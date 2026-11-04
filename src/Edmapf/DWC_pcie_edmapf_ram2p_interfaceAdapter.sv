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
// ---    $Revision: #8 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ram2p_interfaceAdapter.sv#8 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_standard_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ram2p_interfaceAdapter
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter                       DP = 4096
  ,parameter                       PW = 12
  ,parameter           P_ADDR_PROT_WD = 2
  ,parameter           P_DATA_PROT_WD = 8
  ,parameter               P_PIPELINE = 1
  ,parameter                 P_REG_IF = 1
  ,parameter                       WD = 8
  ,parameter           bool_e P_CLK_G = E_TRUE
  ,parameter bool_e P_RAS_DATA_BYPASS = E_FALSE
  ,parameter      RAS_DP_PROT_CHK_ID  = 0
  ,parameter      RAS_PROT_CORRECT_EN = `CX_RAS_CORRECTION_EN
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp           b_clk
  ,DWC_pcie_edmapf_ram2p_standard_if.master_mp b_external
  ,DWC_pcie_edmapf_ram2p_if.slave_mp           b_internal
  ,DWC_pcie_edmapf_rasdp_if.master_mp          b_ras
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################

  localparam L_DATA_PROT_WD = WD + ((P_RAS_DATA_BYPASS == E_TRUE) ? 0 : P_DATA_PROT_WD) ;


// SNPS_SysML_CODE_START
  /*
    Data structure to leading the RAM's access
  */
  typedef struct packed {
    logic valid;
    logic initialized;
    logic [PW-1:0] addr;
  } st_ramAccess;

  /*
    Shift register used to generate the valid signal and to report the right value if the slot was not initialized
  */
  st_ramAccess [P_PIPELINE+2*P_REG_IF:1] r_validPipelined;
  /*
    Array used to identify if the slot was initialized or not
  */
  logic                         [DP-1:0] r_initialized;
  /*
    Concatenating data to be delivered in the shift register
  */
  st_ramAccess                           s_dataIn;
  /*
    Signal used to enable the pipeline
  */
  logic                                  s_pipeRunning;
  /*
    Signal used to collect data from RAM interface
  */
  logic                         [WD-1:0] s_dataFromRAM;
  /*
    Internal clk signal which will be driven by the correct clk depending if the clock should be gated or not
  */
  logic                                  w_clk;

  /*
    Assigning the right clk depending if it should be gated or not
  */
  generate
    if (P_CLK_G)
      assign w_clk = b_clk.w_main_clk;
    else
      assign w_clk = b_clk.w_aux_clk;
  endgenerate

  /*
    Catch the first time that slot was initialized
  */
  always_ff @(posedge w_clk, negedge b_clk.w_reset_n) begin : s_initilized_PROC
    if(!b_clk.w_reset_n) begin
      r_initialized <= #`TP '0;
    end else begin
      foreach(r_initialized[i])
        if(b_internal.w_ena && (i == b_internal.w_addra)) begin
          r_initialized[i] <= #`TP '1;
        end
    end
  end : s_initilized_PROC
  
  /*
    Connecting the read control signals to the shift register and enabling the shift register
  */
  always_comb begin : c_s_dataIn_PROC
    s_dataIn      = '{
                      valid:       b_internal.w_enb
                     ,initialized: r_initialized[b_internal.w_addrb]
                     ,addr:        b_internal.w_addrb
                     };
    s_pipeRunning = s_dataIn.valid;
    foreach(r_validPipelined[i])
      s_pipeRunning = s_pipeRunning | r_validPipelined[i].valid;
  end : c_s_dataIn_PROC
  
  /*
    Generating the valid signal
  */
  always_ff @(posedge w_clk, negedge b_clk.w_reset_n) begin : s_r_validPipelined_PROC
    if (!b_clk.w_reset_n) begin
      r_validPipelined <= #`TP '0;
    end else /*if(s_pipeRunning)*/ begin
      r_validPipelined <= #`TP ($bits(r_validPipelined))'({r_validPipelined, s_dataIn});
    end
  end : s_r_validPipelined_PROC
  
  logic [P_DATA_PROT_WD-1:0] s_dataOut_ecc;
  logic [P_DATA_PROT_WD-1:0] s_dataIn_ecc;
  logic [WD-1:0]             s_dataIn_fixed;
  logic                      s_dataIn_chkEn;
  logic [PW-1:0]             s_addrb_temp; 
  logic [PW-1:0]             s_addrb_delayed;



  generate
    if (P_RAS_DATA_BYPASS) begin : DATA_BYPASS_GEN
      assign s_dataIn_fixed = s_dataFromRAM;
      always_comb begin : ras_proc
        b_ras.w_ras_dp_err_log = '0;
      end
    end else begin : DATA_ECC_GEN_1
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
        .PROT_TYPE                  (0                             ), // 0=Ecc, 1=Simple Parity
        .PROT_RANGE                 (K_RAS_RAM_PROT_RANGE          ), // Number of bits to calculate parity/ECC on
        .PROT_WD                    (P_DATA_PROT_WD                ), // Selects the width of the din_prot/dout_prot signals
        .PARITY_MODE                (K_RAS_PARITY_MODE             ), // selects the type of parity: 0=Even, 1=Odd
        .PROT_CORRECT_EN            (/* NC */                      ), // 0: no correction on single-errors, 1: correction on single-errors
        .TOTAL_WIDTH                ( WD + PW                      ), 
        .EXCLUDE_PROT_WIDTH         (0                             ),
        .RAS_DP_PROT_CHK_ID_BASE    (/* NC */                      ), // Associates the Bus Protection Checker with a unique identifier
        .ADDR_ECC_PROT_EN           (1                             ),
        .ADDR_LOG_EN                (1                             ),
        .ADDR_INDEX                 (WD                            ),
        .ADDR_WD                    (PW                            )
      ) u_ras_gen (
        .clk                        ( w_clk                                   )
        ,.rst_n                     ( b_clk.w_reset_n                         )
        ,.din                       ( {b_internal.w_addra, b_internal.w_dina} )
        ,.din_prot                  ( {P_DATA_PROT_WD{1'b0}}                  )
        ,.dout                      ( /* NC */                                )
        ,.dout_prot                 ( s_dataOut_ecc                           )
        ,.en                        ( 1'b1                                    )
        ,.bypass                    ( 1'b0                                    )
        ,.stall                     ( 1'b0                                    )
        ,.stallout                  ( /* Not Connected */                     )
        ,.valid_in                  ( b_internal.w_ena                        ) 
        ,.halt_out                  ( /* Not Connected */                     )
        ,.valid_out                 ( /* Not Connected */                     )
        ,.halt_in                   ( 1'b0                                    )
        ,.ras_dp_err_inband_kbd_in  ( 1'b0                                    )
        ,.ras_dp_err_inband_kbd_out ( /* Not Connected */                     )
        ,.ras_dp_err_log            ( /* Not Connected */                     )
          ,.ras_dp_err_inj          ( '0                                      )
      );
      
      // Checker
      ras_dp_pipe
       #(
        .PIPELINE_TYPE              (0                             ), // 0: delay_n
        .RESETVAL                   (0                             ),
        .N_STAGES                   (0                             ),
        .CAN_STALL                  (0                             ),
        .RESET_STALL                (0                             ),
        .BUS_PROTECT_GEN_EN         (0                             ), // 1: Bus Protection Generator is present
        .BUS_PROTECT_CHK_EN         (1                             ), // 0: Bus Protection Checker is not present (ECC/Parity)
        .PROT_TYPE                  (0                             ), // 0=Ecc, 1=Simple Parity
        .PROT_RANGE                 (K_RAS_RAM_PROT_RANGE          ), // Number of bits to calculate parity/ECC on
        .PROT_WD                    (P_DATA_PROT_WD                ), // Selects the width of the din_prot/dout_prot signals
        .PARITY_MODE                (K_RAS_PARITY_MODE             ), // selects the type of parity: 0=Even, 1=Odd
        .PROT_CORRECT_EN            (RAS_PROT_CORRECT_EN           ), // 0: no correction on single-errors, 1: correction on single-errors
        .TOTAL_WIDTH                ( WD + PW                      ), 
        .EXCLUDE_PROT_WIDTH         (0                             ),
        .RAS_DP_PROT_CHK_ID_BASE    (RAS_DP_PROT_CHK_ID            ), // Associates the Bus Protection Checker with a unique identifier
        .ADDR_ECC_PROT_EN           (1                             ),
        .ADDR_LOG_EN                (1                             ),
        .ADDR_INDEX                 (WD                            ),
        .ADDR_WD                    (PW                            )
      ) u_ras_chk (
        .clk                        ( w_clk                                   )
        ,.rst_n                     ( b_clk.w_reset_n                         )
        ,.din                       ( {s_addrb_delayed, s_dataFromRAM}        )
        ,.din_prot                  ( s_dataIn_ecc                            )
        ,.dout                      ( {s_addrb_temp, s_dataIn_fixed}          )
        ,.dout_prot                 ( /* NC */                                )
        ,.en                        ( 1'b1                                    )
        ,.bypass                    ( 1'b0                                    )
        ,.stall                     ( 1'b0                                    )
        ,.stallout                  ( /* Not Connected */                     )
        ,.valid_in                  ( s_dataIn_chkEn                          ) 
        ,.halt_out                  ( /* Not Connected */                     )
        ,.valid_out                 ( /* Not Connected */                     )
        ,.halt_in                   ( 1'b0                                    )
        ,.ras_dp_err_inband_kbd_in  ( 1'b0                                    )
        ,.ras_dp_err_inband_kbd_out ( /* Not Connected */                     )
        ,.ras_dp_err_log            ( b_ras.w_ras_dp_err_log                  )
          ,.ras_dp_err_inj          ( b_ras.w_ras_dp_err_inj                  )
      );
    end
  endgenerate

  /*
    Connecting from internal to the external interface
  */
  generate 
    if (P_REG_IF) begin : REG_GEN
        logic [L_DATA_PROT_WD-1:0] s_dataToRAM;
      always_ff @(posedge w_clk, negedge b_clk.w_reset_n) begin : s_b_external_PROC
        if (!b_clk.w_reset_n) begin
          b_external.w_ena       <= #`TP '0;
          b_external.w_enb       <= #`TP '0;
          b_external.w_addra     <= #`TP '0;
          b_external.w_addrb     <= #`TP '0;
        end else begin
          b_external.w_ena       <= #`TP b_internal.w_ena;
          b_external.w_enb       <= #`TP b_internal.w_enb && r_initialized[b_internal.w_addrb];
          b_external.w_addra     <= #`TP b_internal.w_addra;
          b_external.w_addrb     <= #`TP b_internal.w_addrb;
        end
      end : s_b_external_PROC

      if (P_RAS_DATA_BYPASS) begin : DATA_BYPASS_GEN

        always_ff @(posedge w_clk, negedge b_clk.w_reset_n) begin : s_b_external_data_PROC
          if (!b_clk.w_reset_n) begin
            s_dataToRAM       <= #`TP '0;
            s_dataFromRAM     <= #`TP '0;
          end else begin
            s_dataToRAM       <= #`TP b_internal.w_dina;
            s_dataFromRAM     <= #`TP b_external.w_doutb;
          end
        end : s_b_external_data_PROC

      end else begin : DATA_ECC_GEN_2

        always_ff @(posedge w_clk, negedge b_clk.w_reset_n) begin : s_b_external_data_PROC
          if (!b_clk.w_reset_n) begin
            s_dataToRAM                   <= #`TP '0;
            {s_dataIn_ecc, s_dataFromRAM} <= #`TP '0;
          end else begin
            s_dataToRAM                   <= #`TP {s_dataOut_ecc, b_internal.w_dina};
            {s_dataIn_ecc, s_dataFromRAM} <= #`TP b_external.w_doutb;
          end
        end : s_b_external_data_PROC
        
        //Making rd addr and data aligned, to enter checker
        //adding extra cycle to RAM Latency as the data used in checker (s_dataFromRAM) delayed internally by 1 cycle
        delay_n
         
        #(.N (P_PIPELINE+1), 
          .WD(PW)
         ) 
        u_delay_ram_addr_align 
         ( 
         .clk   (w_clk), 
         .rst_n (b_clk.w_reset_n), 
         .clear (1'b0), 
         .din   (b_external.w_addrb),       
         .dout  (s_addrb_delayed)       
         );

      end

      assign b_external.w_dina = s_dataToRAM;
    end else begin : NOREG_GEN

      assign b_external.w_ena   = b_internal.w_ena;
      assign b_external.w_enb   = b_internal.w_enb && r_initialized[b_internal.w_addrb];
      assign b_external.w_addra = b_internal.w_addra;
      assign b_external.w_addrb = b_internal.w_addrb;
      if (P_RAS_DATA_BYPASS) begin : DATA_BYPASS_GEN
        assign b_external.w_dina = b_internal.w_dina;
        assign s_dataFromRAM     = b_external.w_doutb;
      end else begin : DATA_ECC_GEN_3
        assign b_external.w_dina             = {s_dataOut_ecc, b_internal.w_dina};
        assign {s_dataIn_ecc, s_dataFromRAM} = b_external.w_doutb;
      end

    end
  endgenerate
  
  /*
    Connecting from external to the internal interface
  */
  assign s_dataIn_chkEn = r_validPipelined[P_PIPELINE+2*P_REG_IF].valid && r_validPipelined[P_PIPELINE+2*P_REG_IF].initialized;
  assign b_internal.w_doutb  = r_validPipelined[P_PIPELINE+2*P_REG_IF].valid && r_validPipelined[P_PIPELINE+2*P_REG_IF].initialized ? s_dataIn_fixed : '0;
  assign b_internal.w_validb = r_validPipelined[P_PIPELINE+2*P_REG_IF].valid;

// SNPS_SysML_CODE_END

endmodule
