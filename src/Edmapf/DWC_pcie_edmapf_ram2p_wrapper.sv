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
// ---    $Revision: #6 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ram2p_wrapper.sv#6 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_standard_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ram2p_wrapper
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter                DP = 4096
  ,parameter                PW = 12
  ,parameter         P_LATENCY = 1
  ,parameter                WD = 8
  ,parameter    bool_e P_CLK_G = E_TRUE
  ,parameter bool_e P_FLIPFLOP = E_FALSE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp          clk
  ,DWC_pcie_edmapf_ram2p_standard_if.slave_mp pins
  );


// SNPS_SysML_CODE_START
  /*
    Internal clk signal which will be driven by the correct clk depending if the clock should be gated or not
  */
  logic                                  w_clk;

  /*
    Assigning the right clk depending if it should be gated or not
  */
  generate
    if (P_CLK_G)
      assign w_clk = clk.w_main_clk;
    else
      assign w_clk = clk.w_aux_clk;
  endgenerate

  generate
    if (P_FLIPFLOP) begin : FLIPFLOP_GEN
      logic [DP-1:0][WD-1:0] r_ram;
      logic [DP-1:0][WD-1:0] s_ram;

      always_ff @(posedge w_clk, negedge clk.w_reset_n) begin : r_rdRam_PROC
        if (!clk.w_reset_n) begin
          pins.w_doutb <= #`TP '0;
        end else if(pins.w_enb) begin
          pins.w_doutb <= #`TP r_ram[pins.w_addrb];
        end else begin
          pins.w_doutb <= #`TP '0;
        end          
      end

      always_comb begin : s_ram_PROC
        for (int i=0; i<DP; i++) begin
          if (pins.w_ena && (i==pins.w_addra)) begin
            s_ram[i] = pins.w_dina;
          end else begin
            s_ram[i] = r_ram[i];
          end
        end
      end

      always_ff @(posedge w_clk, negedge clk.w_reset_n) begin : r_ram_PROC
        if (!clk.w_reset_n) begin
          r_ram <= #`TP '0;
        end else begin
          r_ram <= #`TP s_ram;
        end
      end

    end else begin : NOT_FLIPFLOP_GEN

      // RAM instance
      ram_2p_1c_wrapper #(
        .WD(WD),
        .PW(PW),
        .DP(DP),
        .RD_LATENCY(P_LATENCY)
      )
      u_ram2p(
        .clk   (w_clk),
        .addra (pins.w_addra ),
        .addrb (pins.w_addrb ),
        .dina  (pins.w_dina  ),
        .doutb (pins.w_doutb ),
        .ena   (pins.w_ena   ),
        .enb   (pins.w_enb   ),
        .wea   (pins.w_ena   )
        );


    end
  endgenerate
// SNPS_SysML_CODE_END

endmodule
