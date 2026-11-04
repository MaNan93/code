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
// ---    $DateTime: 2023/09/27 02:27:25 $ 
// ---    $Revision: #8 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_stsh.sv#8 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_wack_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPop_haltable_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_status_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_dbNtfy_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rvData_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_genericData_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_stsh
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter        type P_CTX_TYPE = logic
  ,parameter        type P_INT_TYPE = logic
  ,parameter       type P_PIPE_TYPE = logic
  ,parameter                   P_BA = 0
  ,parameter                 P_CHAN = 16
  ,parameter         P_CRGB_ADDR_WD = `CC_CRGB_ADDR_WIDTH
  ,parameter         P_CRGB_DATA_WD = 32
  ,parameter              P_CTX_LAT = 3
  ,parameter       P_MAXINT_OUTSTND = 31
  ,parameter              P_RAM_LAT = 3
  ,parameter                P_TAGWD = 8
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_cdmregs_if.slave_mp         b_cdm
  ,DWC_pcie_edmapf_genericData_if.master_mp    b_channelRunning
  ,DWC_pcie_edmapf_aclks_if.slave_mp           b_clk
  ,DWC_pcie_edmapf_crgb_if.slave_mp            b_crgb
  ,DWC_pcie_edmapf_ctxPop_haltable_if.slave_mp b_ctxPop
  ,DWC_pcie_edmapf_rvData_if.master_mp         b_ctxPush
  ,DWC_pcie_edmapf_dbNtfy_if.slave_mp          b_doorbell
  ,DWC_pcie_edmapf_genericData_if.slave_mp     b_hwStop
  ,DWC_pcie_edmapf_tlp_if.master_mp            b_msi
  ,DWC_pcie_edmapf_wack_if.slave_mp            b_msiAck
  ,DWC_pcie_edmapf_ram2p_if.master_mp          b_ram
  ,DWC_pcie_edmapf_status_if.master_mp         b_status
  ,DWC_pcie_edmapf_wack_if.slave_mp            b_wrAck
  );

  // ##########################################################################
  //                              Local parameters                             
  // ##########################################################################

  localparam L_CHANWD = (P_CHAN == 1) ? 1 : $clog2(P_CHAN)                          ;

  // ##########################################################################
  //                               Wiring Declaration                          
  // ##########################################################################

  DWC_pcie_edmapf_ChNtfyEn_if #(
     .P_CHAN  (P_CHAN)
    ,.P_CHANWD(L_CHANWD)
                             )   b_DWC_pcie_edmapf_ChNtfyEn_if_0   ();
  DWC_pcie_edmapf_chanNotify_if #(
     .P_CHANWD(L_CHANWD)
                               ) b_DWC_pcie_edmapf_chanNotify_if_0 ();
  DWC_pcie_edmapf_crgb_if        b_DWC_pcie_edmapf_crgb_if_0       ();
  DWC_pcie_edmapf_crgb_if        b_DWC_pcie_edmapf_crgb_if_1       ();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(logic [P_CHAN-1:0])
                                )b_DWC_pcie_edmapf_genericData_if_0();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(intTypes_s [P_CHAN-1:0])
                                )b_DWC_pcie_edmapf_genericData_if_1();
  DWC_pcie_edmapf_genericData_if #(
     .P_DATATYPE(logic [P_CHAN-1:0])
                                )b_DWC_pcie_edmapf_genericData_if_2();
  DWC_pcie_edmapf_ram1p_if #(
     .PW(L_CHANWD)
    ,.WD($bits(msiInfo_s))
                          )      b_DWC_pcie_edmapf_ram1p_if_0      ();
  DWC_pcie_edmapf_ram1p_if #(
     .PW(L_CHANWD)
    ,.WD('d32)
                          )      b_DWC_pcie_edmapf_ram1p_if_1      ();
  DWC_pcie_edmapf_rvData_if #(
     .P_DATATYPE(P_PIPE_TYPE)
                           )     b_DWC_pcie_edmapf_rvData_if_0     ();
  DWC_pcie_edmapf_rvData_if #(
     .P_DATATYPE(P_PIPE_TYPE)
                           )     b_DWC_pcie_edmapf_rvData_if_1     ();
  DWC_pcie_edmapf_rvData_if #(
     .P_DATATYPE(P_PIPE_TYPE)
                           )     b_DWC_pcie_edmapf_rvData_if_2     ();
  DWC_pcie_edmapf_wack_if #(
     .P_CHANWD(L_CHANWD)
    ,.P_TAGWD (P_TAGWD)
                         )       b_DWC_pcie_edmapf_wack_if_0       ();

  // ##########################################################################
  //                              Instances Declaration                        
  // ##########################################################################

  DWC_pcie_edmapf_ctrl_stsh_stsHub
   #(
   .P_CHAN(P_CHAN)
  ) s_statusHub (
   .b_channelRunning ( b_channelRunning                             )
  ,.b_enabled        ( b_DWC_pcie_edmapf_genericData_if_2.slave_mp  )
  ,.b_interrupts     ( b_DWC_pcie_edmapf_genericData_if_1.slave_mp  )
  ,.b_status         ( b_status                                     )
  ,.b_xferPending    ( b_DWC_pcie_edmapf_genericData_if_0.slave_mp  )
  );

  DWC_pcie_edmapf_crgb
   #(
   .P_CHANNEL /* P_CHANNEL */           (P_CHANNEL)
  ,.P_CRGB_ADDR_WD /* P_CRGB_ADDR_WD */ (P_CRGB_ADDR_WD)
  ,.P_CRGB_DATA_WD /* P_CRGB_DATA_WD */ (P_CRGB_DATA_WD)
  ,.P_RAM /* E_HDMAREGZONE_INTERRUPTS */(E_HDMAREGZONE_INTERRUPTS)
  ,.P_RAM_ADDR_WD /* L_CHANWD */        (L_CHANWD)
  ,.P_RAM_DATA_WD /* 'd32 */            ('d32)
  ) u_crgbErr (
   .b_clk            ( b_clk                                        )
  ,.b_crgb           ( b_DWC_pcie_edmapf_crgb_if_1.slave_mp         )
  ,.b_ram            ( b_DWC_pcie_edmapf_ram1p_if_1.master_mp       )
  );

  DWC_pcie_edmapf_crgb
   #(
   .P_CHANNEL /* P_CHANNEL */           (P_CHANNEL)
  ,.P_CRGB_ADDR_WD /* P_CRGB_ADDR_WD */ (P_CRGB_ADDR_WD)
  ,.P_CRGB_DATA_WD /* P_CRGB_DATA_WD */ (P_CRGB_DATA_WD)
  ,.P_RAM /* E_HDMAREGZONE_MSI */       (E_HDMAREGZONE_MSI)
  ,.P_RAM_ADDR_WD /* L_CHANWD */        (L_CHANWD)
  ,.P_RAM_DATA_WD /* $bits(msiInfo_s) */($bits(msiInfo_s))
  ) u_crgbMsi (
   .b_clk            ( b_clk                                        )
  ,.b_crgb           ( b_DWC_pcie_edmapf_crgb_if_0.slave_mp         )
  ,.b_ram            ( b_DWC_pcie_edmapf_ram1p_if_0.master_mp       )
  );

  DWC_pcie_edmapf_crgb_1to2_rtr
  
    u_crgbSplit (
   .b_in             ( b_crgb                                       )
  ,.b_out1           ( b_DWC_pcie_edmapf_crgb_if_0.master_mp        )
  ,.b_out2           ( b_DWC_pcie_edmapf_crgb_if_1.master_mp        )
  );

  DWC_pcie_edmapf_ctrl_stsh_intMngr
   #(
   .P_CHAN     (P_CHAN)
  ,.P_INT_TYPE (P_INT_TYPE)
  ,.P_PIPE_TYPE(P_PIPE_TYPE)
  ) u_intMngr (
   .b_channelRunning ( b_DWC_pcie_edmapf_genericData_if_0.slave_mp  )
  ,.b_clk            ( b_clk                                        )
  ,.b_crgb           ( b_DWC_pcie_edmapf_ram1p_if_1.slave_mp        )
  ,.b_doorbell       ( b_DWC_pcie_edmapf_ChNtfyEn_if_0.slave_mp     )
  ,.b_en             ( b_DWC_pcie_edmapf_genericData_if_2.master_mp )
  ,.b_hwStop         ( b_hwStop                                     )
  ,.b_in             ( b_DWC_pcie_edmapf_rvData_if_2.slave_mp       )
  ,.b_int            ( b_DWC_pcie_edmapf_genericData_if_1.master_mp )
  ,.b_noMsiAck       ( b_DWC_pcie_edmapf_wack_if_0.master_mp        )
  ,.b_out            ( b_DWC_pcie_edmapf_rvData_if_1.master_mp      )
  );

  DWC_pcie_edmapf_ctrl_stsh_monitor
   #(
   .P_BA       (P_BA)
  ,.P_CHAN     (P_CHAN)
  ,.P_CHANNEL  (P_CHANNEL)
  ,.P_CTX_TYPE (P_CTX_TYPE)
  ,.P_PIPE_TYPE(P_PIPE_TYPE)
  ,.P_POP_LAT  (P_CTX_LAT)
  ) u_monitor (
   .b_cdm            ( b_cdm                                        )
  ,.b_clk            ( b_clk                                        )
  ,.b_ctxPop         ( b_ctxPop                                     )
  ,.b_ctxPush        ( b_ctxPush                                    )
  ,.b_doorbell       ( b_DWC_pcie_edmapf_chanNotify_if_0.slave_mp   )
  ,.b_out            ( b_DWC_pcie_edmapf_rvData_if_0.master_mp      )
  ,.b_wack           ( b_wrAck                                      )
  );

  DWC_pcie_edmapf_ctrl_stsh_msiMngr
   #(
   .P_CHAN /* P_CHAN */      (P_CHAN)
  ,.P_CHANNEL                (P_CHANNEL)
  ,.P_PIPE_TYPE              (P_PIPE_TYPE)
  ,.P_RAM_LAT /* P_RAM_LAT */(P_RAM_LAT)
  ) u_msiMngr (
   .b_clk            ( b_clk                                        )
  ,.b_crgb           ( b_DWC_pcie_edmapf_ram1p_if_0.slave_mp        )
  ,.b_in             ( b_DWC_pcie_edmapf_rvData_if_1.slave_mp       )
  ,.b_msi            ( b_msi                                        )
  ,.b_ram            ( b_ram                                        )
  );

  DWC_pcie_edmapf_ctrl_stsh_xfpMngr
   #(
   .P_CHAN          (P_CHAN)
  ,.P_MAXINT_OUTSTND(P_MAXINT_OUTSTND)
  ,.P_PIPE_TYPE     (P_PIPE_TYPE)
  ) u_xferPendMngr (
   .b_clk            ( b_clk                                        )
  ,.b_doorB2IntMngr  ( b_DWC_pcie_edmapf_ChNtfyEn_if_0.master_mp    )
  ,.b_doorB2mon      ( b_DWC_pcie_edmapf_chanNotify_if_0.master_mp  )
  ,.b_doorbell       ( b_doorbell                                   )
  ,.b_in             ( b_DWC_pcie_edmapf_rvData_if_0.slave_mp       )
  ,.b_msiAck         ( b_msiAck                                     )
  ,.b_msiRAck        ( b_DWC_pcie_edmapf_wack_if_0.slave_mp         )
  ,.b_out            ( b_DWC_pcie_edmapf_rvData_if_2.master_mp      )
  ,.b_xferPending    ( b_DWC_pcie_edmapf_genericData_if_0.master_mp )
  );

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endmodule
