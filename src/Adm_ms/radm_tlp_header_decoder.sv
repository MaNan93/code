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
// --   RCS information:
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_tlp_header_decoder.sv#7 $
// -------------------------------------------------------------------------

//////////////////////////////////////////////////////////////
// Module performs the following actions
//
// - Decodes the Prefixes and map them as part of Header.
// - Decodes the header lengh size from first header DW and differentiate the Header DWs from Data.
// - Differentiate the header and data with help of the separate control signals.
// - Counts the P TLP packets and pass the information with each QDW to the next stage formation queues.
// - Drops small errored TLP received within a clock cycle.
// - Generates the condition for prefix removal from next stage formation queues.
// - Marks QDW as prefix only QDW or MAC/PCRC/ECRC only QDW.
//////////////////////////////////////////////////////////////
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_tlp_header_decoder
  import radm_ms_pkg::PKT_ORD_WD;
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NW;
  import DWC_pcie_ctl_pkg::NVC;
  import DWC_pcie_core_pkg::DW;
  import pcie_pkg::decoded_tlp_type_s;
  import pcie_pkg::f_decode_tlp_type;
  import pcie_pkg::f_decode_ohc_len ;
  import DWC_pcie_core_pkg::RX_NQDW;
  import DWC_pcie_core_pkg::QDW_DW;
  import DWC_pcie_core_pkg::QDW_PAR;
  import DWC_pcie_core_pkg::rtlh_radm_datapath_t;
  import DWC_pcie_core_pkg::radm_tb_tlp_ordering_t;


                                (
  input                                          core_clk,                          // Clock Input
  input                                          core_rst_n,                        // Active low reset   
  input                                          flit_mode_en,                      // Flit mode enabled or not
  input   [NF-1:0]                               cfg_ecrc_chk_en,                   // ecrc check enable  
  // Interfaces from RTLH to RADM
  input DWC_pcie_core_pkg::rtlh_radm_datapath_t  rtlh_radm,                         // rtlh to radm input
`ifndef SYNTHESIS
  output DWC_pcie_core_pkg::radm_tb_tlp_ordering_t  radm_tlp_order,                 // TLP ordering output for TB model   
`endif // !SYNTHESIS  
  output  logic   [NVC-1:0][RX_NQDW-1:0]         hdec_form_nqdw_hv_p,               // Header Valid indication for P TLP formation queue
  output  logic   [NVC-1:0][RX_NQDW-1:0]         hdec_form_nqdw_dv_p,               // Data valid indication for P TLP formation queue 
  output  logic   [NVC-1:0][RX_NQDW-1:0]         hdec_form_nqdw_eot_p,              // End of the TLP for P TLP formation queue         
  output  logic   [NVC-1:0][RX_NQDW-1:0]         hdec_form_nqdw_hv_np,              // Header Valid indication for NP TLP formation queue 
  output  logic   [NVC-1:0][RX_NQDW-1:0]         hdec_form_nqdw_dv_np,              // Data valid indication for NP TLP formation queue 
  output  logic   [NVC-1:0][RX_NQDW-1:0]         hdec_form_nqdw_eot_np,             // End of the TLP for NP TLP formation queue         
  output  logic   [NVC-1:0][RX_NQDW-1:0]         hdec_form_nqdw_hv_cpl,             // Header Valid indication for CPL TLP formation queue
  output  logic   [NVC-1:0][RX_NQDW-1:0]         hdec_form_nqdw_dv_cpl,             // Data valid indication for CPL TLP formation queue   
  output  logic   [NVC-1:0][RX_NQDW-1:0]         hdec_form_nqdw_eot_cpl,            // End of the TLP for CPL TLP formation queue         
  output  logic   [RX_NQDW-1:0][QDW_DW+QDW_PAR-1:0]  hdec_form_nqdw_data,           // Generic data qdword (prefix/hdr/payload) of TLP packet
  output  logic   [RX_NQDW-1:0][4-1:0]           hdec_form_nqdw_hdwen,              // Header Dword enable
  output  logic   [RX_NQDW-1:0][4-1:0]           hdec_form_nqdw_ddwen,              // Data Dword enable
  output  logic   [RX_NQDW-1:0]                  hdec_form_nqdw_dllp_err,           // Indicates current packet should be dropped because of DLLP layer err
  output  logic   [RX_NQDW-1:0]                  hdec_form_nqdw_fm_poisoned,        // Indicates last tlp ends with poisoned flit marker
  output  logic   [RX_NQDW-1:0]                  hdec_form_nqdw_fm_nullified,       // Indicates last tlp ends with nullified flit marker
  output  logic   [NVC-1:0][RX_NQDW-1:0][PKT_ORD_WD-1:0] hdec_form_p_pkt_order_num, // P TLP Packet received counts
  output  logic   [RX_NQDW-1:0]                  hdec_form_mac_ecrc_qdw,            // mac/pcrc or ECRC only QDW.  
  output  logic   [RX_NQDW-1:0]                  hdec_form_prefix_qdw,              // Indication of the prefix alone QDW  
  output  logic   [NVC-1:0][2:0]                 hdec_form_discard_prefixes         // discard previous prefix from formation queue.
  );

  localparam RX_NQDW_WD = (NW==32) ? 4 : (NW==16)? 3 : (NW==8)? 2 : 1;              // number of qdw input count width.
  //////////////////////////////////////////////////////////////
  // Local wires and registers
  //////////////////////////////////////////////////////////////
  logic     [RX_NQDW-1:0][QDW_DW+QDW_PAR-1:0] int_rtlh_radm_nqdw_data;
  logic     [RX_NQDW-1:0][4-1:0]              int_rtlh_radm_nqdw_dwen,int_rtlh_radm_nqdw_dwen_r;
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_eot;
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_dllp_abort;
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_fm_poisoned;
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_fm_nullified;
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_sot;
  logic     [RX_NQDW-1:0]                     int_qdw_valid;
  logic     [RX_NQDW-1:0][1:0]                int_qdw_type;
  logic     [RX_NQDW-1:0][2:0]                int_qdw_vc;
  logic     [RX_NQDW-1:0]                     int_valid_with_header_dw;
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_hv; 
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_dv; 
  logic     [RX_NQDW-1:0][3:0]                int_rtlh_radm_nqdw_hdwen;
  logic     [RX_NQDW-1:0][3:0]                int_rtlh_radm_nqdw_ddwen;
  
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_hv_r; 
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_dv_r; 
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_eot_r;
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_eot_unmasked_r;
  logic     [RX_NQDW-1:0]                     int_valid_with_header_dw_r;
//  logic     [RX_NQDW-1:0]                     int_qdw_valid_r;
  logic     [RX_NQDW-1:0][1:0]                int_qdw_type_r;
  logic     [RX_NQDW-1:0][2:0]                int_qdw_vc_r;
  logic     [RX_NQDW-1:0][QDW_DW+QDW_PAR-1:0] int_rtlh_radm_nqdw_data_r;
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_dllp_abort_r;
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_fm_poisoned_r;
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_fm_nullified_r;
  logic     [RX_NQDW-1:0][3:0]                int_rtlh_radm_nqdw_hdwen_r;
  logic     [RX_NQDW-1:0][3:0]                int_rtlh_radm_nqdw_ddwen_r;
  logic     [RX_NQDW-1:0][2:0]                prefix_count;
  logic     [RX_NQDW-1:0][3:0]                header_dw_count;
  logic     [RX_NQDW-1:0][3:0]                new_header_dw_count;
  logic     [3:0]                             header_dw_count_last;
  logic     [RX_NQDW-1:0][2:0]                valid_dw_count_within_qdw;
  logic     [RX_NQDW-1:0][1:0]                prefix_dws;
  logic     [RX_NQDW-1:0]                     prefix_check_disable;
  logic                                       prefix_check_disable_r;
  logic     [NVC-1:0][4-1:0]                  temp_p_pkt_order_num;
  logic     [NVC-1:0][PKT_ORD_WD-1:0]         current_p_pkt_order_num;  
  logic     [NVC-1:0][RX_NQDW-1:0][PKT_ORD_WD-1:0]  next_p_pkt_order_num;
  logic     [RX_NQDW-1:0]                     int_prefix_qdw;
  logic     [RX_NQDW-1:0]                     int_prefix_qdw_r;
  logic     [RX_NQDW-1:0][2:0]                mac_pcrc_ecrc_size;
  logic     [RX_NQDW-1:0]                     ecrc_present;
  logic     [2:0]                             mac_pcrc_ecrc_size_r;
  logic                                       ecrc_present_r;
  logic     [RX_NQDW-1:0][2:0]                mac_pcrc_ecrc_size_decode;
  logic     [RX_NQDW-1:0]                     ecrc_present_decode;
  logic     [RX_NQDW-1:0][3:0]                ohc_dw_placement_count;
  logic     [RX_NQDW-1:0][3:0]                ohc_dw_placement;
  logic     [3:0]                             ohc_dw_placement_count_last;
  logic     [RX_NQDW-1:0]                     ohc_c_is_idle_tlp;
  logic                                       ohc_c_is_idle_tlp_last;
  logic     [RX_NQDW-1:0]                     int_ohc_c_is_ide_tlp;

  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_mac_ecrc;
  logic     [RX_NQDW-1:0]                     int_rtlh_radm_nqdw_mac_ecrc_r;
  logic                                       poisoned_nullified_locked;


  logic     [RX_NQDW-1:0][2:0]                mac_pcrc_ecrc_size_decode_r;
  logic     [RX_NQDW-1:0]                     ecrc_present_decode_r;
  logic     [RX_NQDW-1:0]                     int_ohc_c_is_ide_tlp_r;
  logic     [RX_NQDW-1:0][3:0]                ohc_dw_placement_count_r;
  logic     [RX_NQDW-1:0]                     ohc_c_is_idle_tlp_r;


  
   
  localparam     P_TLP       = 2'b00;
  localparam     NP_TLP      = 2'b01;
  localparam     CPL_TLP     = 2'b10;
  localparam     NONE_TLP    = 2'b11;
  localparam     FLIT_PREFIX = 3'b100;  
  //////////// Structure extraction /////////////////////////
  assign int_rtlh_radm_nqdw_dwen       = rtlh_radm.dwen;
  assign int_rtlh_radm_nqdw_eot        = rtlh_radm.eot;
  assign int_rtlh_radm_nqdw_dllp_abort = rtlh_radm.dllp_err;
  assign int_qdw_valid                 = rtlh_radm.valid;
  assign int_rtlh_radm_nqdw_sot        = rtlh_radm.sot;

  // Decoding nullified TLP and poisoned TLP qdw.
  always_comb begin 
    poisoned_nullified_locked = 0;
    for(int i=RX_NQDW-1;i>=0;i--) begin
      if(rtlh_radm.eot[i] && (!poisoned_nullified_locked)) begin
        int_rtlh_radm_nqdw_fm_poisoned[i]  = rtlh_radm.fm_poisoned ;
        int_rtlh_radm_nqdw_fm_nullified[i] = rtlh_radm.fm_nullified ;
        poisoned_nullified_locked = 1'b1;
      end  
      else begin
        int_rtlh_radm_nqdw_fm_poisoned[i]  = '0;
        int_rtlh_radm_nqdw_fm_nullified[i] = '0;
      end  
  end
  end
 
  // mapping of input structure variable to internal variables.
  always_comb begin  
    for(int j=0;j<RX_NQDW;j++) begin
       int_rtlh_radm_nqdw_data[j]      = { rtlh_radm.data_prot[j], rtlh_radm.data[j]};
       int_valid_with_header_dw[j]     = rtlh_radm.hdr[j].valid;
       int_qdw_type[j]                 = (rtlh_radm.hdr[j].fc == NONE_TLP) && (!flit_mode_en) ? NP_TLP : rtlh_radm.hdr[j].fc ;  // NONE TLP type conversion to NP into non-flitmode
       int_qdw_vc[j]                   = rtlh_radm.hdr[j].vc;
    end
  end





  ///////////////////////////////////////////////////////////////////////////////
  // Masking of the small error packets.
  //
  // If small packet is there within a clock cycle with error than we are removing
  // the small error packet over here itself. We do not pass small error packets to
  // the formation queues.This helps to reduce the combinations logic at the 
  // formation queue level  
  //
  ///////////////////////////////////////////////////////////////////////////////
  logic   [RX_NQDW-1:0]   int_rtlh_radm_nqdw_eot_error;
  logic   [RX_NQDW-1:0]   int_rtlh_radm_nqdw_first_eot;
  logic   [RX_NQDW-1:0]   int_errored_tlp_mask , errored_tlp_mask;
  
  assign int_rtlh_radm_nqdw_eot_error = int_rtlh_radm_nqdw_eot  & int_rtlh_radm_nqdw_dllp_abort; 
  
  // We should not remove the first EOT in case it is not related to the valid header start.
  always_comb begin : FIRST_EOT_CHECK
  reg [RX_NQDW_WD-1:0]  c;
    c = 0;
    int_rtlh_radm_nqdw_first_eot = '0;
    for(int j=0;j<RX_NQDW;j=j+1) begin
      int_rtlh_radm_nqdw_first_eot[j] = (c == 3'h0) && (~int_rtlh_radm_nqdw_sot[j]) && int_rtlh_radm_nqdw_eot[j] ; 
      if(int_rtlh_radm_nqdw_eot[j])      
        c   = c + 1;
      end
  end
  
  // preparing the mask to remove small packets with error.  
  always_comb begin
  int_errored_tlp_mask = '1;
  int_errored_tlp_mask[RX_NQDW-1] = !(int_rtlh_radm_nqdw_eot[RX_NQDW-1] && int_rtlh_radm_nqdw_dllp_abort[RX_NQDW-1] && !int_rtlh_radm_nqdw_first_eot[RX_NQDW-1]);
  for(int n=RX_NQDW-2;n>=0;n=n-1) begin
    if(int_rtlh_radm_nqdw_eot_error[n] & (!int_rtlh_radm_nqdw_first_eot[n])) begin
      int_errored_tlp_mask[n] = 1'b0;
    end
    else if(int_rtlh_radm_nqdw_eot[n])
           int_errored_tlp_mask[n] = 1'b1;
         else         
           int_errored_tlp_mask[n] = int_errored_tlp_mask[n] & int_errored_tlp_mask[n+1];
   end        
  end

  always_ff@(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n)begin
        errored_tlp_mask    <= #TP '0;
    end else begin
        errored_tlp_mask    <= #TP int_errored_tlp_mask;
    end
  end

  logic  [RX_NQDW-1:0]   prfx_tlp_end,prfx_tlp_end_r;

  ///////////////////////////////////////////////////////
  // Prefix , header and data decoding from input qdw.
  always_comb begin : TLP_HEADER_DATA_AND_PRF_DECODE
    header_dw_count = '0;
    // Decoding of the prefix from QDW.
    // prefix check disabled during data
    prefix_check_disable[0]     = prefix_check_disable_r;
    // total number of prefixes within qdw
    prefix_count[0]             = check_prefixes(flit_mode_en,prefix_check_disable[0],int_qdw_valid[0],int_rtlh_radm_nqdw_data[0][QDW_DW-1 : 0],int_rtlh_radm_nqdw_dwen[0]);
    prefix_dws[0]               = prefix_count[0][1:0];

    prfx_tlp_end[0]             = (!int_valid_with_header_dw[0]) && (int_rtlh_radm_nqdw_eot[0]) && (|prefix_dws[0]);   
    // Header length decoding from first header DW
    new_header_dw_count[0]      = int_valid_with_header_dw[0] ? check_header_length(flit_mode_en,int_rtlh_radm_nqdw_data[0][prefix_dws[0]*32 +:32]) : 0;
    
    // remaining header counts after current QDW
    header_dw_count[0]           = int_qdw_valid[0] ? ((header_dw_count_last < 4'h4) ? 0 : (header_dw_count_last - 4'h4 )) : header_dw_count_last ;
 
    // spyglass disable_block W164a
    // SMD: LHS width is less than the RHS width in assignment.
    // SJ: Right side addition value can be be maximum 15 including prefix DWs counts. And so no possibility of overflow.
    // tracking header dw counts.
    header_dw_count[0]           = int_valid_with_header_dw[0] ? new_header_dw_count[0]+prefix_count[0] : header_dw_count[0]/*+prefix_count[0] */;      // prefixes are part of header on formq output
      // spyglass enable_block W164a

    // spyglass disable_block W164b
    // SMD: LHS width is greter than the RHS width in assignment.
    // SJ: Right side addition value can be upto 4. And we need 3 bit representation for the same. So looks ok.
    valid_dw_count_within_qdw[0] = int_rtlh_radm_nqdw_dwen[0][3] + int_rtlh_radm_nqdw_dwen[0][2] + int_rtlh_radm_nqdw_dwen[0][1] + int_rtlh_radm_nqdw_dwen[0][0];
    // spyglass enable_block W164b

   // repeating the header and data decoding from QDW 1 to N 
    for(int i=1;i<RX_NQDW ;i=i+1) begin
      prefix_check_disable[i]   = (int_valid_with_header_dw[i-1] && !int_rtlh_radm_nqdw_eot[i-1]) || (prefix_check_disable[i-1] && !int_rtlh_radm_nqdw_eot[i-1]);
      prefix_count[i]           = check_prefixes(flit_mode_en , prefix_check_disable[i],int_qdw_valid[i],int_rtlh_radm_nqdw_data[i][QDW_DW-1 : 0],int_rtlh_radm_nqdw_dwen[i]);
      prefix_dws[i]             = prefix_count[i][1:0];

      prfx_tlp_end[i]             = (!int_valid_with_header_dw[i]) && (int_rtlh_radm_nqdw_eot[i]) && (|prefix_dws[i]);   
 
      new_header_dw_count[i]    = int_valid_with_header_dw[i] ? check_header_length(flit_mode_en,int_rtlh_radm_nqdw_data[i][prefix_dws[i]*32 +:32]) : 0;
      
      header_dw_count[i]        = int_qdw_valid[i] ? ((header_dw_count[i-1] < 4'h4) ? 0 : (header_dw_count[i-1] - 4'h4)) : header_dw_count[i-1] ;
 
      // spyglass disable_block W164a
      // SMD: LHS width is less than the RHS width in assignment.
      // SJ: Right side addition value can be be maximum 15 including prefix DWs counts. And so no possibility of overflow.
      header_dw_count[i]           = int_valid_with_header_dw[i] ? new_header_dw_count[i]+prefix_count[i] : header_dw_count[i]/*+prefix_count[i]*/ ;
      // spyglass enable_block W164a

      // spyglass disable_block W164b
      // SMD: LHS width is greter than the RHS width in assignment.
      // SJ: Right side addition value can be upto 4. And we need 3 bit representation for the same. So looks ok.
      valid_dw_count_within_qdw[i] = int_rtlh_radm_nqdw_dwen[i][3] + int_rtlh_radm_nqdw_dwen[i][2] + int_rtlh_radm_nqdw_dwen[i][1] + int_rtlh_radm_nqdw_dwen[i][0];
      // spyglass enable_block W164b
   end
  end

  
  logic     [RX_NQDW-1:0][2:0]                prefix_count_r;
  logic     [RX_NQDW-1:0][3:0]                header_dw_count_r;
  logic     [RX_NQDW-1:0]                     int_qdw_valid_r;  
  logic     [RX_NQDW-1:0][2:0]                valid_dw_count_within_qdw_r;
 
  // Delay header and data control signals by 1 clock cycle.
  localparam  PIPEWIDTH_QDW_INFO = RX_NQDW*3 + RX_NQDW*4 + RX_NQDW + RX_NQDW*3 + RX_NQDW + RX_NQDW + RX_NQDW*4;
  delay_n
  
   #(1 ,PIPEWIDTH_QDW_INFO ) u_pipeline_qdw_info(
       .clk        (core_clk),
       .rst_n      (core_rst_n),
       .clear      (1'b0),
       .din        ({prefix_count,header_dw_count,int_qdw_valid,valid_dw_count_within_qdw,(int_rtlh_radm_nqdw_eot)/*  & int_errored_tlp_mask)*/,prfx_tlp_end,int_rtlh_radm_nqdw_dwen}),
       .dout       ({prefix_count_r,header_dw_count_r,int_qdw_valid_r,valid_dw_count_within_qdw_r,int_rtlh_radm_nqdw_eot_unmasked_r,prfx_tlp_end_r,int_rtlh_radm_nqdw_dwen_r})
   );
  
  always_comb begin : TLP_HV_DV_MAPPING
    // marking of qdw as prefix only qdw.
    int_prefix_qdw[0]           = prefix_count_r[0][2];
    // Logic to generate HV and HDWEN
    int_rtlh_radm_nqdw_hv[0]    = int_prefix_qdw[0] || prfx_tlp_end_r[0] || (|header_dw_count_r[0] && int_qdw_valid_r[0]);                             
    int_rtlh_radm_nqdw_hdwen[0] = int_prefix_qdw[0] ? 4'b1111 : prfx_tlp_end_r[0] ? int_rtlh_radm_nqdw_dwen_r[0] : header_dwen(int_rtlh_radm_nqdw_hv[0],header_dw_count_r[0]);
    // Logic to decode the DV and Data DWEN 
    int_rtlh_radm_nqdw_dv[0]    = int_prefix_qdw[0] || prfx_tlp_end_r[0] ? 1'b0 : (int_qdw_valid_r[0]  && (valid_dw_count_within_qdw_r[0] > {1'b0, header_dw_count_r[0][1:0]} ) && (|header_dw_count_r[0][3:2] == 0)) ;  
    int_rtlh_radm_nqdw_ddwen[0] =  data_dwen(int_rtlh_radm_nqdw_dv[0],header_dw_count_r[0],valid_dw_count_within_qdw_r[0]);
    
    // repeating the header and data decoding from QDW 1 to N 
    for(int i=1;i<RX_NQDW ;i=i+1) begin
      int_prefix_qdw[i]         = prefix_count_r[i][2];
      int_rtlh_radm_nqdw_hv[i]    = int_prefix_qdw[i] || prfx_tlp_end_r[i] || (|header_dw_count_r[i] && int_qdw_valid_r[i]);
      int_rtlh_radm_nqdw_hdwen[i] = int_prefix_qdw[i] ? 4'b1111 : prfx_tlp_end_r[i] ? int_rtlh_radm_nqdw_dwen_r[i] : header_dwen(int_rtlh_radm_nqdw_hv[i],header_dw_count_r[i]);
      int_rtlh_radm_nqdw_dv[i]    = int_prefix_qdw[i] || prfx_tlp_end_r[i] ? 1'b0 : (int_qdw_valid_r[i] && (valid_dw_count_within_qdw_r[i] > {1'b0,header_dw_count_r[i][1:0]} ) && (|header_dw_count_r[i][3:2] == 0)) ;
      int_rtlh_radm_nqdw_ddwen[i] =  data_dwen(int_rtlh_radm_nqdw_dv[i],header_dw_count_r[i],valid_dw_count_within_qdw_r[i]);
    end
  end

  ///////////////////////////////////////////////////////
  // Prefix , header and data decoding from input qdw.
 
  always_comb begin : TLP_MAC_QDW_MAPPING
    // remaining header counts after current QDW
    ohc_dw_placement_count[0]      = int_rtlh_radm_nqdw_eot_unmasked_r[RX_NQDW-1] ? '0 : int_qdw_valid[0] ? ((ohc_dw_placement_count_last < 4'h4) ? 0 : (ohc_dw_placement_count_last - 4'h4 )) : ohc_dw_placement_count_last ;
     // Decoding the OHC - C DW placement
    ohc_dw_placement[0]         = int_valid_with_header_dw[0] ? check_ohc_placement(flit_mode_en,int_rtlh_radm_nqdw_data[0][prefix_dws[0]*32 +:32]) : 0;

    // spyglass disable_block W164a
    // SMD: LHS width is less than the RHS width in assignment.
    // SJ: Right side addition value can be be maximum 15 including prefix DWs counts. And so no possibility of overflow.
    // checking the OHC-C DW placement.
    ohc_dw_placement_count[0]      = int_valid_with_header_dw[0]  && (|ohc_dw_placement[0]) ? ohc_dw_placement[0]+prefix_count[0] : ohc_dw_placement_count[0];  
    // spyglass enable_block W164a

    // Decoding size of MAC/PCRC or ECRC.
    if(!flit_mode_en)begin
       ecrc_present_decode[0]    = (|cfg_ecrc_chk_en) && (int_valid_with_header_dw[0] ? int_rtlh_radm_nqdw_data[0][prefix_dws[0]*32 + 23] : ecrc_present_r) ; 
    end else begin
      ecrc_present_decode[0] = (|cfg_ecrc_chk_en) && (int_valid_with_header_dw[0] ?(extract_mac_pcrc_ecrc_size_fm(int_rtlh_radm_nqdw_data[0][prefix_dws[0]*32 +:32],int_qdw_valid[0]) == 3'b001):ecrc_present_r);
    end
    mac_pcrc_ecrc_size_decode[0] = '0;

    // clearing MAC/PCRC or ECRC information of the QDW. 
//    ohc_c_is_idle_tlp[0]   = int_rtlh_radm_nqdw_eot[0] ? '0 : int_ohc_c_is_ide_tlp_r[0];  
    mac_pcrc_ecrc_size[0]  = int_rtlh_radm_nqdw_eot[0] ? '0 : mac_pcrc_ecrc_size_decode[0];
    ecrc_present[0]        = int_rtlh_radm_nqdw_eot[0] ? '0 : ecrc_present_decode[0];

   // repeating the header and data decoding from QDW 1 to N 
    for(int i=1;i<RX_NQDW ;i=i+1) begin
     
      ohc_dw_placement_count[i]      = int_rtlh_radm_nqdw_eot[i-1] ? '0 : int_qdw_valid[i] ? ((ohc_dw_placement_count[i-1] < 4'h4) ? 0 : (ohc_dw_placement_count[i-1] - 4'h4 )) : ohc_dw_placement_count[i-1] ;
      
      ohc_dw_placement[i]       = int_valid_with_header_dw[i] ? check_ohc_placement(flit_mode_en,int_rtlh_radm_nqdw_data[i][prefix_dws[i]*32 +:32]) : 0;

      // spyglass disable_block W164a
      // SMD: LHS width is less than the RHS width in assignment.
      // SJ: Right side addition value can be be maximum 15 including prefix DWs counts. And so no possibility of overflow.
      ohc_dw_placement_count[i]    = int_valid_with_header_dw[i]  && (|ohc_dw_placement[i]) ? ohc_dw_placement[i]+prefix_count[i] : ohc_dw_placement_count[i] ;  
      // spyglass enable_block W164a

      if(!flit_mode_en)begin
        ecrc_present_decode[i]  = (|cfg_ecrc_chk_en) && (int_valid_with_header_dw[i] ? int_rtlh_radm_nqdw_data[i][prefix_dws[i]*32 + 23] : ecrc_present[i-1]) ;
      end else begin
        ecrc_present_decode[i]=(|cfg_ecrc_chk_en) && (int_valid_with_header_dw[i] ?(extract_mac_pcrc_ecrc_size_fm(int_rtlh_radm_nqdw_data[i][prefix_dws[i]*32 +:32],int_qdw_valid[i]) == 3'b001):ecrc_present[i-1]);
      end
      mac_pcrc_ecrc_size_decode[i] = '0;

//      ohc_c_is_idle_tlp[i]   = int_rtlh_radm_nqdw_eot[i] ? '0 : int_ohc_c_is_ide_tlp[i];  
      mac_pcrc_ecrc_size[i]  = int_rtlh_radm_nqdw_eot[i] ? '0 : mac_pcrc_ecrc_size_decode[i];
      ecrc_present[i]        = int_rtlh_radm_nqdw_eot[i] ? '0 : ecrc_present_decode[i];
    end
  end



  localparam  PIPEWIDTH_MAC_ECR_INFO = RX_NQDW*3 + RX_NQDW + RX_NQDW + RX_NQDW*4 + RX_NQDW;
  delay_n
  
   #(1 ,PIPEWIDTH_MAC_ECR_INFO ) u_pipeline_mac_ecrc_info(
       .clk        (core_clk),
       .rst_n      (core_rst_n),
       .clear      (1'b0),
       .din        ({mac_pcrc_ecrc_size_decode,int_ohc_c_is_ide_tlp,ecrc_present_decode,ohc_dw_placement_count,ohc_c_is_idle_tlp}),
       .dout       ({mac_pcrc_ecrc_size_decode_r,int_ohc_c_is_ide_tlp_r,ecrc_present_decode_r,ohc_dw_placement_count_r,ohc_c_is_idle_tlp_r})
   );

  always_comb begin : TLP_MAC_QDW_MAPPING_1
    // spyglass disable_block ImproperRangeIndex-ML
    // SMD: INDEX larger than the bit width required for variable.
    // SJ: int_rtlh_radm_nqdw_data is extracted within a boundary of 127 to 0 only as index variable value can be 4 to 1 only during execution.  
    // checking OHC-C for IDE TLP.
    int_ohc_c_is_ide_tlp[0]        = int_qdw_valid_r[0] && (ohc_dw_placement_count_r[0] <= 4'h4) && (ohc_dw_placement_count_r[0] != 4'h0) ? (int_rtlh_radm_nqdw_data_r[0][((ohc_dw_placement_count_r[0][2:0]-1)*32+28) +:3] != 3'b111) : ohc_c_is_idle_tlp_last;
    // spyglass enable_block ImproperRangeIndex-ML

    // Marking QDW with only MAC/PCRC or ECRC
    int_rtlh_radm_nqdw_mac_ecrc[0] = int_rtlh_radm_nqdw_eot_unmasked_r[0] ? ((valid_dw_count_within_qdw_r[0] <= mac_pcrc_ecrc_size_decode_r[0]) && (int_ohc_c_is_ide_tlp[0] || !flit_mode_en)) 
                                                                 || (ecrc_present_decode_r[0] && (valid_dw_count_within_qdw_r[0] == 3'b001)) 
                                                                 : 1'b0;  
    ohc_c_is_idle_tlp[0]   = int_rtlh_radm_nqdw_eot_unmasked_r[0] ? '0 : int_ohc_c_is_ide_tlp[0];  
                                                                 
    for(int i=1;i<RX_NQDW ;i=i+1) begin
      // spyglass disable_block ImproperRangeIndex-ML
      // SMD: INDEX larger than the bit width required for variable.
      // SJ: int_rtlh_radm_nqdw_data is extrrcted within a boundary of 127 to 0 only as index variable value can be 4 to 1 only during execution.  
      int_ohc_c_is_ide_tlp[i]      =  int_qdw_valid_r[i] && (ohc_dw_placement_count_r[i] <= 4'h4) && (ohc_dw_placement_count_r[i] != 4'h0) ? (int_rtlh_radm_nqdw_data_r[i][((ohc_dw_placement_count_r[i][2:0]-1)*32+28) +:3] != 3'b111) : ohc_c_is_idle_tlp[i-1];
    // spyglass enable_block ImproperRangeIndex-ML

     int_rtlh_radm_nqdw_mac_ecrc[i] = int_rtlh_radm_nqdw_eot_unmasked_r[i] ? ((valid_dw_count_within_qdw_r[i] <= mac_pcrc_ecrc_size_decode_r[i]) && (int_ohc_c_is_ide_tlp[i]  || !flit_mode_en)) 
                                                                  || (ecrc_present_decode_r[i] && (valid_dw_count_within_qdw_r[i] == 3'b001)) 
                                                                  : 1'b0;  
      ohc_c_is_idle_tlp[i]   = int_rtlh_radm_nqdw_eot_unmasked_r[i] ? '0 : int_ohc_c_is_ide_tlp[i];  
 
    end
  end

  // Storing current clock cycle information after last valid QDW. 
  always @(posedge core_clk or negedge core_rst_n)
    if(~core_rst_n) begin
      header_dw_count_last        <= #TP '0;
      ohc_dw_placement_count_last <= #TP '0;
      ohc_c_is_idle_tlp_last      <= #TP '0;   
      prefix_check_disable_r   <= #TP '0;
      mac_pcrc_ecrc_size_r     <= #TP '0;
      ecrc_present_r           <= #TP '0;
    end else begin
      header_dw_count_last        <= #TP header_dw_count[RX_NQDW-1];
      ohc_dw_placement_count_last <= #TP ohc_dw_placement_count[RX_NQDW-1]; 
      ohc_c_is_idle_tlp_last      <= #TP ohc_c_is_idle_tlp[RX_NQDW-1];   
      prefix_check_disable_r   <= #TP (int_valid_with_header_dw[RX_NQDW-1] && !int_rtlh_radm_nqdw_eot[RX_NQDW-1]) || (prefix_check_disable[RX_NQDW-1] && !int_rtlh_radm_nqdw_eot[RX_NQDW-1]);
      mac_pcrc_ecrc_size_r     <= #TP mac_pcrc_ecrc_size[RX_NQDW-1];
      ecrc_present_r           <= #TP ecrc_present[RX_NQDW-1];
   end

assign int_rtlh_radm_nqdw_hv_r = int_rtlh_radm_nqdw_hv & errored_tlp_mask;
assign int_rtlh_radm_nqdw_dv_r = int_rtlh_radm_nqdw_dv & errored_tlp_mask;
assign int_prefix_qdw_r        = int_prefix_qdw & errored_tlp_mask;
assign int_rtlh_radm_nqdw_eot_r = int_rtlh_radm_nqdw_eot_unmasked_r & errored_tlp_mask;
assign int_rtlh_radm_nqdw_mac_ecrc_r = int_rtlh_radm_nqdw_mac_ecrc;


  // Delay control information by 1 clock cycle.
  localparam  PIPEWIDTH_1 =  2 + 3 + 1 + 1 + 1 + 1 ;
  generate
  for (genvar k = 0; k < RX_NQDW; k++)begin : g_pipe_delay_w_enable
  delay_n_w_enable
  
   #(1 ,PIPEWIDTH_1 ) u_pipeline_qdw_info_1(
       .clk        (core_clk),
       .rst_n      (core_rst_n),
       .clear      (1'b0),
       .en         (1'b1),
       .din        ({int_qdw_type[k] ,int_qdw_vc[k], int_valid_with_header_dw[k],
                    int_rtlh_radm_nqdw_dllp_abort[k], 
 int_rtlh_radm_nqdw_fm_poisoned[k], int_rtlh_radm_nqdw_fm_nullified[k] }),
       .dout       ({int_qdw_type_r[k], int_qdw_vc_r[k], int_valid_with_header_dw_r[k],
                    int_rtlh_radm_nqdw_dllp_abort_r[k], 
 int_rtlh_radm_nqdw_fm_poisoned_r[k], int_rtlh_radm_nqdw_fm_nullified_r[k] })
   );
  end
  endgenerate

 // Delay data information by 1 clock cycle.
  localparam  PIPEWIDTH_DATA =  (QDW_DW+QDW_PAR);
  generate
  for (genvar k = 0; k < RX_NQDW; k++)begin : g_pipe_data_delay_w_enable
  delay_n_w_enable
  
   #(1 ,PIPEWIDTH_DATA ) u_pipeline_qdw_data(
       .clk        (core_clk),
       .rst_n      (core_rst_n),
       .clear      (1'b0),
       .en         (int_qdw_valid[k]),
       .din        (int_rtlh_radm_nqdw_data[k]), 
       .dout       (int_rtlh_radm_nqdw_data_r[k])
   );
  end
  endgenerate

assign int_rtlh_radm_nqdw_hdwen_r = int_rtlh_radm_nqdw_hdwen;
assign int_rtlh_radm_nqdw_ddwen_r = int_rtlh_radm_nqdw_ddwen;
  
  ///////////////////////////////////////////////////////////////////
  // prefix only qdw detection logic without following any header or data.
  // Full QDW can be prefix DWs only in case of prefix support more than 3.
  //////////////////////////////////////////////////////////////////
  logic   [RX_NQDW-1:0]                  prefix_qdw_mask;          
  // masking logic to block prefix only qdw detection before valid header.
  always_comb begin
    prefix_qdw_mask = {RX_NQDW{1'b1}};
    prefix_qdw_mask[RX_NQDW-1] = !int_rtlh_radm_nqdw_eot_r[RX_NQDW-1];
    for(int i=RX_NQDW-2;i>=0;i=i-1)
      prefix_qdw_mask[i] = prefix_qdw_mask[i+1] && (int_rtlh_radm_nqdw_hv_r[i] ? (int_prefix_qdw_r[i] && !int_rtlh_radm_nqdw_eot_r[i]) : 1'b1);
  
  end
  // prefix only qdw logic. prefix only qdws passing to all formation queues.
  always @(posedge core_clk or negedge core_rst_n) begin  
    if(!core_rst_n) begin
      hdec_form_prefix_qdw                    <= #TP {RX_NQDW{1'b0}};
    end else begin
      hdec_form_prefix_qdw                  <= #TP int_prefix_qdw_r & prefix_qdw_mask;
    end
  end  
  //////////////////////////////////////////////////////////////////////////
  // Extending the TLP TYPE and VC information to the previous prefix only qdw 
  //
  /////////////////////////////////////////////////////////////////////////
  logic     [RX_NQDW-1:0][1:0]              qdw_type_r_with_prf;
  logic     [RX_NQDW-1:0][2:0]              qdw_vc_r_with_prf;
  logic     [RX_NQDW-1:0]                   last_valid_qdw;
  
  // decoding last valid qdw number in current clock cycle.
  always_comb begin
    last_valid_qdw = '0;
    for(int i=0;i<RX_NQDW;i=i+1) begin
      if(int_qdw_valid_r[i])
        last_valid_qdw = i;
    end    
  end
  // in case of valid low, next qdw tpye and vc information is getting assigned for continuety.
  // In case qdw is last valid qdw or with eot than we assign received information of RTLH else we continue with assignment of next qdw information. 
  always_comb begin
    qdw_type_r_with_prf = int_qdw_type_r;
    qdw_vc_r_with_prf   = int_qdw_vc_r;
    for(int i=RX_NQDW-2;i>=0;i=i-1) begin
      qdw_type_r_with_prf[i] = !int_qdw_valid_r[i] ? qdw_type_r_with_prf[i+1] : ((last_valid_qdw == i) || int_rtlh_radm_nqdw_eot_r[i]) ? int_qdw_type_r[i] : qdw_type_r_with_prf[i+1];
      qdw_vc_r_with_prf[i]   = !int_qdw_valid_r[i] ? qdw_vc_r_with_prf[i+1]   : ((last_valid_qdw == i) || int_rtlh_radm_nqdw_eot_r[i]) ? int_qdw_vc_r[i]   : qdw_vc_r_with_prf[i+1];
    end
  end 
  // 1 clock delay for header and data information
  localparam  OUTPIPEWIDTH =  (QDW_DW+QDW_PAR) + 4 + 4 + 1 + 1 + 1 ;
  generate
    for (genvar k = 0; k < RX_NQDW; k++)begin : g_pipe_delay_w_enable_1
  delay_n_w_enable
  
   #(1 ,OUTPIPEWIDTH ) u_pipeline_out_qdw_info(
       .clk        (core_clk),
       .rst_n      (core_rst_n),
       .clear      (1'b0),
       .en         ( |int_rtlh_radm_nqdw_hv_r[k] || |int_rtlh_radm_nqdw_dv_r[k] || |int_rtlh_radm_nqdw_eot_r[k]),
       .din        ({int_rtlh_radm_nqdw_data_r[k]  ,int_rtlh_radm_nqdw_hdwen_r[k],int_rtlh_radm_nqdw_ddwen_r[k],int_rtlh_radm_nqdw_dllp_abort_r[k]  
 , int_rtlh_radm_nqdw_fm_poisoned_r[k],int_rtlh_radm_nqdw_fm_nullified_r[k] }),
       .dout       ({hdec_form_nqdw_data[k],hdec_form_nqdw_hdwen[k],hdec_form_nqdw_ddwen[k],hdec_form_nqdw_dllp_err[k]
 , hdec_form_nqdw_fm_poisoned[k],hdec_form_nqdw_fm_nullified[k]})
   );
    end
  endgenerate

  // Delay header and data control signals by 1 clock cycle.
  localparam  PIPEWIDTH_MAC = RX_NQDW ;
  delay_n
  
   #(1 ,PIPEWIDTH_MAC ) u_pipeline_qdw_mac_ecrc_info(
       .clk        (core_clk),
       .rst_n      (core_rst_n),
       .clear      (1'b0),
       .din        (int_rtlh_radm_nqdw_mac_ecrc_r),
       .dout       (hdec_form_mac_ecrc_qdw)
   );

  /////////////////////////////////////////////////////////////////////////
  // Ouptut port assignments
  /////////////////////////////////////////////////////////////////////////
  always @(posedge core_clk or negedge core_rst_n) begin : proc
    if(!core_rst_n) begin
      for(int i=0;i<NVC;i=i+1) begin
        for(int j=0;j<RX_NQDW;j=j+1) begin
          hdec_form_nqdw_hv_p[i][j]           <= #TP 1'b0;
          hdec_form_nqdw_dv_p[i][j]    <= #TP 1'b0;
          hdec_form_nqdw_eot_p[i][j]   <= #TP 1'b0;
          hdec_form_nqdw_hv_np[i][j]   <= #TP 1'b0;
          hdec_form_nqdw_dv_np[i][j]   <= #TP 1'b0;
          hdec_form_nqdw_eot_np[i][j]  <= #TP 1'b0;
          hdec_form_nqdw_hv_cpl[i][j]  <= #TP 1'b0;
          hdec_form_nqdw_dv_cpl[i][j]  <= #TP 1'b0;
          hdec_form_nqdw_eot_cpl[i][j] <= #TP 1'b0;
        end
      end  
    end else begin
      for(int i=0;i<NVC;i=i+1) begin
        for(int j=0;j<RX_NQDW;j=j+1) begin
          hdec_form_nqdw_hv_p[i][j]    <= #TP int_rtlh_radm_nqdw_hv_r[j] && (((qdw_type_r_with_prf[j] == P_TLP)  && (int_qdw_vc_r[j] == i)) || (int_prefix_qdw_r[j] && prefix_qdw_mask[j]) ); 
          hdec_form_nqdw_hv_np[i][j]   <= #TP int_rtlh_radm_nqdw_hv_r[j] && (((qdw_type_r_with_prf[j] == NP_TLP) && (int_qdw_vc_r[j] == i)) || (int_prefix_qdw_r[j] && prefix_qdw_mask[j]) ); 
          hdec_form_nqdw_hv_cpl[i][j]  <= #TP int_rtlh_radm_nqdw_hv_r[j] && (((qdw_type_r_with_prf[j] == CPL_TLP) && (int_qdw_vc_r[j] == i)) || (int_prefix_qdw_r[j] && prefix_qdw_mask[j]) ); 
          
          hdec_form_nqdw_dv_p[i][j]    <= #TP int_rtlh_radm_nqdw_dv_r[j]  && (qdw_type_r_with_prf[j] == P_TLP)    && (int_qdw_vc_r[j] == i); 
          hdec_form_nqdw_dv_np[i][j]   <= #TP int_rtlh_radm_nqdw_dv_r[j]  && (qdw_type_r_with_prf[j] == NP_TLP)   && (int_qdw_vc_r[j] == i); 
          hdec_form_nqdw_dv_cpl[i][j]  <= #TP int_rtlh_radm_nqdw_dv_r[j]  && (qdw_type_r_with_prf[j] == CPL_TLP)  && (int_qdw_vc_r[j] == i); 

          hdec_form_nqdw_eot_p[i][j]   <= #TP int_rtlh_radm_nqdw_eot_r[j]  && (qdw_type_r_with_prf[j] == P_TLP)   && (int_qdw_vc_r[j] == i); 
          hdec_form_nqdw_eot_np[i][j]  <= #TP int_rtlh_radm_nqdw_eot_r[j]  && (qdw_type_r_with_prf[j] == NP_TLP)  && (int_qdw_vc_r[j] == i); 
          hdec_form_nqdw_eot_cpl[i][j] <= #TP int_rtlh_radm_nqdw_eot_r[j]  && (qdw_type_r_with_prf[j] == CPL_TLP) && (int_qdw_vc_r[j] == i); 
        end
      end  
    end
  end
  ////////////////////////////////////////////////////////////////////
  // discrad prefix only qdw from formation queue indication logic based 
  // on the first valid header.
  //////////////////////////////////////////////////////////////////////
  logic   [RX_NQDW_WD-1:0]       first_header_qdw;  
  logic   [NVC-1:0][2:0]         int_hdec_form_discard_prefixes;
  logic                          hdec_form_prefix_qdw_set;  

  // information for prfx only qdw on previous cycle  
  always @(posedge core_clk or negedge core_rst_n) begin  
  integer i;
    if(!core_rst_n) begin
      hdec_form_prefix_qdw_set <= #TP 1'b0;
    end else begin
      if(|(int_prefix_qdw_r & prefix_qdw_mask))
         hdec_form_prefix_qdw_set <= #TP 1'b1;
      else
      if(|int_hdec_form_discard_prefixes)
        hdec_form_prefix_qdw_set <= #TP 1'b0;
    end
  end  

  // Decoding of the first valid qdw with the header information
  always_comb begin 
    first_header_qdw = 0;
    for(int i=0;i<RX_NQDW;i=i+1) begin
      if((int_valid_with_header_dw_r[RX_NQDW-1-i]) || (int_rtlh_radm_nqdw_eot_r[RX_NQDW-1-i]))
        first_header_qdw = RX_NQDW-1-i;
    end
  end

  // Generating the discard prefix condition based on the first valid header type and vc
  always_comb begin 
   for(int i=0;i<NVC;i=i+1) begin
     for(int j=0;j<3;j=j+1) begin
       int_hdec_form_discard_prefixes[i][j]  = hdec_form_prefix_qdw_set && (|int_valid_with_header_dw_r || |int_rtlh_radm_nqdw_eot_r) && 
                                !( ((int_valid_with_header_dw_r[first_header_qdw] )|| (int_rtlh_radm_nqdw_eot_r[first_header_qdw])) && (qdw_type_r_with_prf[first_header_qdw] == j) && (int_qdw_vc_r[first_header_qdw] == i));
     end  
   end
  end 

  always @(posedge core_clk or negedge core_rst_n) begin 
    if(!core_rst_n) begin
      hdec_form_discard_prefixes  <= #TP '0;
    end else begin
      hdec_form_discard_prefixes  <= #TP int_hdec_form_discard_prefixes;
    end
  end 
  /////////////////////////////////////////////////////////
  // Generating P packet order number per VC.
  /////////////////////////////////////////////////////////
  generate
  for (genvar num_vc=0; num_vc<NVC; num_vc = num_vc+1) begin : u_radm_pkt_num_gen
    always_comb begin  : Proc
      temp_p_pkt_order_num[num_vc] = 0;
      next_p_pkt_order_num[num_vc] = hdec_form_p_pkt_order_num[num_vc];
      for(int n=0;n<RX_NQDW;n=n+1) begin
        if(int_rtlh_radm_nqdw_eot_r[n] && (!int_rtlh_radm_nqdw_dllp_abort_r[n]) && (!int_rtlh_radm_nqdw_fm_nullified_r[n])  && (qdw_type_r_with_prf[n] == P_TLP) && (int_qdw_vc_r[n] == num_vc)  ) 
          temp_p_pkt_order_num[num_vc]  = temp_p_pkt_order_num[num_vc] + 1;
    // spyglass disable_block W164a
    // SMD: LHS width is less than the RHS width in assignment.
    // SJ: Right side overflow and tructation of the upper bit is expected behavior over here.
    next_p_pkt_order_num[num_vc][n] = current_p_pkt_order_num[num_vc] + temp_p_pkt_order_num[num_vc];
    // spyglass enable_block W164a
      end
    end  
    // Storing the information of the packet order number for next clock cycle.
    always @(posedge core_clk or negedge core_rst_n) begin 
      if(!core_rst_n) begin
        hdec_form_p_pkt_order_num[num_vc] <= #TP {RX_NQDW*PKT_ORD_WD{1'b0}};
        current_p_pkt_order_num[num_vc] <= #TP {PKT_ORD_WD{1'b0}};
      end else begin
        hdec_form_p_pkt_order_num[num_vc] <= #TP next_p_pkt_order_num[num_vc];
        current_p_pkt_order_num[num_vc] <= #TP next_p_pkt_order_num[num_vc][RX_NQDW-1];
      end
    end
  end  
  endgenerate

  ////////////////////////////////////////////////////////////////
  // local functions
  ////////////////////////////////////////////////////////////////
  
  ////////////////////////////////////////////////////////////////
  // Function checks the number of prefixes present within a QDW.
  ////////////////////////////////////////////////////////////////
  function  automatic [2:0] check_prefixes;
    input               flit_mode_en;        // 1 : Flit mode 0 : Non Flit mode
    input               prf_chk_disable;     // prefic check is disabled (to avoid wrong decoding of prefixes from data or header dws)
    input               valid;               // valid qdw 
    input   [127:0]     data;                // qdw data
    input   [3:0]       dwen;
    reg     [7:0]       tlp_types_in_qdw;    // type field decoding from header dw  
    reg     [2:0]       prefix_count;        // prefix received count within qdw 
    reg                 prf_chk_end;         // prefix decoding end (To avoid wrong detection header dw as prefix.)
    reg                 prefix_detected;
    
    begin
      prefix_count   = 3'b000;
      check_prefixes = 2'b00;
      prf_chk_end    = 1'b0;

      for(int p=0;p<4;p=p+1) begin
        tlp_types_in_qdw = valid ? (dwen[p] ? data[(p*32) +:8] : 8'h0) : 8'h0;
        prefix_detected =  flit_mode_en ? ((tlp_types_in_qdw[7:5] == FLIT_PREFIX) && !tlp_types_in_qdw[4]) :     // Only local prefix decoding in flit mode.
                                          (tlp_types_in_qdw[7:5] == FLIT_PREFIX);  
         
        if(prefix_detected && !prf_chk_end) 
           prefix_count = prefix_count + 3'b001; 
        else
          prf_chk_end  = 1'b1;
      end  
      check_prefixes = prf_chk_disable ? 0 : prefix_count;
    end
  endfunction
  /////////////////////////////////////////////////////////
  // Function checks the length of the header in DW form. 
  /////////////////////////////////////////////////////////
  function automatic  [3:0]  check_header_length;
    input              flit_mode_en;                  // 1 : Flit mode 0 : Non Flit mode
    input   [31:0]     data;                          // First header dw input
    pcie_pkg::decoded_tlp_type_s dec_type;   

    reg [7:0] f_type;        // Header type
    reg [4:0] f_ohc;         // OHC type
    reg [2:0] hdr_ohc_len;   // OHC length
    reg [2:0] hdr_base_length;  // header base length

    f_type = data[7:0];   
    f_ohc  = data[12:8];

    dec_type    = pcie_pkg::f_decode_tlp_type(f_type, flit_mode_en);
    hdr_ohc_len = pcie_pkg::f_decode_ohc_len(f_ohc);
    hdr_base_length     = (dec_type.hdr_base_len > '0) ? dec_type.hdr_base_len : 3'h3;
 
    check_header_length = flit_mode_en ? {1'b0, hdr_base_length} + {1'b0, hdr_ohc_len} : {1'b0, hdr_base_length};

  endfunction
  /////////////////////////////////////////////////////////
  // Function checks the OHC C DW placement on input data. 
  /////////////////////////////////////////////////////////
  function automatic  [3:0]  check_ohc_placement;
    input              flit_mode_en;
    input   [31:0]     data;                          // First header dw input
    pcie_pkg::decoded_tlp_type_s dec_type;   

    reg [7:0] f_type;          // Header type
    reg [4:0] f_ohc;           // OHC type
    reg [2:0] hdr_base_length;  // header base length

    f_type = data[7:0];   
    f_ohc  = data[12:8];

    dec_type            = pcie_pkg::f_decode_tlp_type(f_type, flit_mode_en);
    hdr_base_length     = (dec_type.hdr_base_len > '0) ? dec_type.hdr_base_len : 3'h3;
    check_ohc_placement = (flit_mode_en && f_ohc[2]) ? ({1'b0, hdr_base_length} + {3'b000, f_ohc[0]} +  {3'b000, f_ohc[1]} +  {3'b000, f_ohc[2]}) : 4'h0;

  endfunction
  //////////////////////////////////////////////////////////
  // Function return the header dwen based on the number of header DWs counts.
  //////////////////////////////////////////////////////////
  function automatic  [3:0]  header_dwen;
    input        header_valid;                // header valid   
    input [3:0]  header_dw_count;            // header dw counts
    reg   [3:0]  int_header_dw_count;

    case(header_dw_count)
      4'h0    : int_header_dw_count = 4'b0000;
      4'h1    : int_header_dw_count = 4'b0001;
      4'h2    : int_header_dw_count = 4'b0011;
      4'h3    : int_header_dw_count = 4'b0111;
      default : int_header_dw_count = 4'b1111;
    endcase  
  
    header_dwen = header_valid ? int_header_dw_count : 4'b0000;
  endfunction
  ///////////////////////////////////////////////////////////
  // data dwen mapping function
  ///////////////////////////////////////////////////////////
  function automatic  [3:0]  data_dwen;
    input        data_valid;               // valid qdw with data dws
    input [3:0]  header_dw_count;         // header dws in current qdw
    input [2:0]  valid_dw_count_within_qdw;          // total valid dwq in current qdw
    reg   [3:0]  int_data_dwen;             // internal data dwen value base on qdw
    reg   [2:0]  data_dw_count;            // data dws count within current qdw 

    // spyglass disable_block W164a
    // SMD: LHS width is less than the RHS width in assignment.
    // SJ: Right side subtraction value can be be maximum 4.And so no possibility of overflow.
    data_dw_count = valid_dw_count_within_qdw - header_dw_count[2:0];
    // spyglass enable_block W164a
    
    case(data_dw_count)
      3'h0    : int_data_dwen = 4'b0000;
      3'h1    : int_data_dwen = 4'b0001;
      3'h2    : int_data_dwen = 4'b0011;
      3'h3    : int_data_dwen = 4'b0111;
      default : int_data_dwen = 4'b1111;
    endcase  
    
    data_dwen = data_valid ? int_data_dwen : 4'b0000;
  endfunction
  //////////////////////////////////////////////////////////////
  // Exxtract the MAC/PCRC or ECRC information into flit mode 
  //////////////////////////////////////////////////////////////
  function  automatic [2:0] extract_mac_pcrc_ecrc_size_fm(logic[32-1:0] data, logic valid);
    reg       ohc_c;         // OHC-C type
    reg [2:0] f_ts;          // TS field

    f_ts  = data[23:21];
    ohc_c = data[10];

    extract_mac_pcrc_ecrc_size_fm = (f_ts == 3'b001) ? 3'b001 : 3'b000; 
  endfunction

  `ifndef SYNTHESIS
  //////////////////////////////////////////////////////////////
  // TLP receive sequence output for testbench ordering check. 
  //////////////////////////////////////////////////////////////
  //VCS coverage off
  logic     [1:0]       prfx_count; 
  logic     [31:0]      header_dw1;
  always_comb begin : TLP_HEADER_ORDER_INFO     
  radm_tlp_order = '0;
  prfx_count     = '0;
  header_dw1     = '0;
  for(int i=0;i<RX_NQDW ;i=i+1) begin
    if(rtlh_radm.hdr[i].valid) begin
      prfx_count = check_prefixes(flit_mode_en,1'b0, 1'b1,int_rtlh_radm_nqdw_data[i][QDW_DW-1 : 0],int_rtlh_radm_nqdw_dwen[i]);
      header_dw1   = int_rtlh_radm_nqdw_data[i][prfx_count*32 +:32];

      radm_tlp_order.fmt[i]        = header_dw1[7:5];
      radm_tlp_order.tlp_type[i]   = header_dw1[4:0];
      radm_tlp_order.header_dw1[i] = header_dw1;
      radm_tlp_order.fc[i]         = rtlh_radm.hdr[i].fc;
      radm_tlp_order.vc[i]         = rtlh_radm.hdr[i].vc;
      radm_tlp_order.valid[i]      = 1'b1;
      radm_tlp_order.dllp_err[i]   = int_rtlh_radm_nqdw_dllp_abort[i];
      radm_tlp_order.nullified[i]  = 1'b0 || int_rtlh_radm_nqdw_fm_nullified[i];
      radm_tlp_order.eot[i]        = int_rtlh_radm_nqdw_eot[i];
    end
   else begin
      radm_tlp_order.dllp_err[i]   = int_rtlh_radm_nqdw_dllp_abort[i];
      radm_tlp_order.nullified[i]  = 1'b0 || int_rtlh_radm_nqdw_fm_nullified[i];
      radm_tlp_order.eot[i]        = int_rtlh_radm_nqdw_eot[i];
   end
  end
  end
  //VCS coverage on
  `endif // !SYNTHESIS




endmodule
