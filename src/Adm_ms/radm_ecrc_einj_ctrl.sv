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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_ecrc_einj_ctrl.sv#1 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// RADM eCRC error injection control module. This module sets the priority for
// error injection enable going to filters
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

module radm_ecrc_einj_ctrl
#(
  parameter N_TRGT1_INTF = `CX_RADM_NFC_TRGT_INTF
)(
  input                                   core_clk,              
  input                                   core_rst_n,            
  input         [N_TRGT1_INTF-1:0][3-1:0] pkt_err_inj_enable_in,        // Packet EoT with TD bit set                
  input                                   cdm_ras_des_einj0_enable,
  input         [3:0]                     cdm_ras_des_einj0_crc_type,
  input         [7:0]                     cdm_ras_des_einj0_count,
  input         [2:0]                     cdm_ras_des_einj0_vc_sel,
  input         [1:0]                     cdm_ras_des_einj0_fc_sel,     // 2'b00 - P, 2'b01 - NP, 2'b10 - CPL
  input                                   cdm_ras_des_einj0_intf_sel,

  output logic  [N_TRGT1_INTF-1:0][3-1:0] err_inj_enable,
  output logic  [2:0]                     ecrc_einj_evt
);

// CRC type for RADM error injection
localparam [3:0] CRC_TYPE = 4'b1011;

// ----------------------- Signal Declaration Start ------------------------//
logic [(3*N_TRGT1_INTF)-1:0]                        all_filt_valid_eot;
logic [(3*N_TRGT1_INTF)-1:0][(3*N_TRGT1_INTF)-1:0]  find_pkt;
logic [(3*N_TRGT1_INTF)-1:0]                        int_einj_priority_evt;
logic [N_TRGT1_INTF-1:0][3-1:0]                     int_einj_per_fc_evt;
logic [2:0]                                         ecrc_einj_priority_evt;
logic                                               rx_einj_en;
// ----------------------- Signal Declaration End --------------------------//

// Need to add functional support for VC based error injection (Once RTL supports different VCs)

assign rx_einj_en = cdm_ras_des_einj0_enable && (cdm_ras_des_einj0_crc_type==CRC_TYPE);

always_comb begin : concat_en_in_PROC
integer i;
  // Aligning and concatenating all packet EoT with TD set per target interface
  for (i = 0; i < N_TRGT1_INTF; i++) begin
    all_filt_valid_eot[3*i +: 3] = pkt_err_inj_enable_in[i];
  end
end

// Priority decoder for inserting error in all packets (When FC is set to 2'b11)
generate
  for (genvar cnt=0 ; cnt<(3*N_TRGT1_INTF) ; cnt=cnt+1 ) begin : gen_find_pkt_for
    assign find_pkt[cnt] = next_pkt_finder ( cnt, all_filt_valid_eot ) ;
  end
endgenerate

always_comb begin
  ecrc_einj_priority_evt = 0;
  int_einj_priority_evt  = 0;
  if ( rx_einj_en && (cdm_ras_des_einj0_fc_sel==2'b11) ) begin
    for (int j = 0; j < (3*N_TRGT1_INTF); j++) begin
      if ((cdm_ras_des_einj0_count > j) || (cdm_ras_des_einj0_count==8'd0)) begin
        if   ( |find_pkt[j] ) ecrc_einj_priority_evt = j + 1'b1;
          int_einj_priority_evt = int_einj_priority_evt | find_pkt[j];
      end
    end
  end
end
// Priority decoder ends here

// Error insertion logic based on FC and I/F type

generate
for (genvar i=0 ; i<N_TRGT1_INTF; i=i+1 ) begin : gen_einj_per_fc_evt
  always_comb begin
    int_einj_per_fc_evt[i]    = 0;
    if ( rx_einj_en && (cdm_ras_des_einj0_fc_sel!=2'b11) ) begin
      for (int j = 0; j < 3; j++) begin
        // This condition is not needed as in RX one error will be inserted at a time
        // if (cdm_ras_des_einj0_count>=8'd0) begin
          int_einj_per_fc_evt[i][j] =  pkt_err_inj_enable_in[i][j] && (cdm_ras_des_einj0_fc_sel == j) && (cdm_ras_des_einj0_intf_sel == i);
        // end
      end
    end
  end
end
endgenerate

// Error insertion logic based on FC and I/F type ends here

assign ecrc_einj_evt = (cdm_ras_des_einj0_fc_sel==2'b11) ? ecrc_einj_priority_evt : {2'b0, (|int_einj_per_fc_evt)};

generate
for (genvar i=0 ; i<N_TRGT1_INTF; i=i+1 ) begin : gen_einj_en_out
    assign err_inj_enable[i] = (cdm_ras_des_einj0_fc_sel==2'b11) ? int_einj_priority_evt[i*3 +: 3] : int_einj_per_fc_evt[i];
end
endgenerate

function automatic [(3*N_TRGT1_INTF)-1:0] next_pkt_finder ;
  input  [(3*N_TRGT1_INTF)-1:0] num;
  input  [(3*N_TRGT1_INTF)-1:0] cur_end;
  logic  [(3*N_TRGT1_INTF)-1:0] find_cnt;
  logic  [(3*N_TRGT1_INTF)-1:0] next_pkt_finder_pre;
  integer                       find_loop;
  begin
    find_cnt            = 'd0 ;
    next_pkt_finder_pre = 'd0;

    for ( find_loop=0; find_loop<(3*N_TRGT1_INTF); find_loop=find_loop+1 ) begin
        if ( cur_end[find_loop]==1'b1 ) begin 
          if ( find_cnt==num ) next_pkt_finder_pre = 1'b1<<find_loop ;
          find_cnt = find_cnt + 1'b1 ;
        end
    end

    next_pkt_finder = next_pkt_finder_pre ;
  end
endfunction
  
endmodule
