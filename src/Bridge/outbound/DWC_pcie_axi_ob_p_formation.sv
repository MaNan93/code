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
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_ob_p_formation.sv#11 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_axi_ob_p_formation
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter SLV_BUS_ID_WIDTH                 = 1,
  parameter SLV_BUS_ADDR_WIDTH               = 32,
  parameter SLAVE_BUS_ADDR_WIDTH             = 32,
  parameter SLV_BURST_LEN_PW                 = 3,
  parameter SLV_BUS_WSTRB_WIDTH              = 3,
  parameter SLV_BUS_DATA_WIDTH               = 3,
  parameter NFUNC_WD                         = 3,
  parameter DC_CPL_STATUS_WD                 = `DC_CPL_STATUS_WD,
  parameter CX_TAG_SIZE                      = `CX_TAG_SIZE,
  parameter MISC_INFO_TPH_WD                 = 11,
  parameter TX_TLP_PREFIX_WD                 = 32,
  parameter SLV_MTU_PW                       = 32,
  parameter PRF_TLP_DATA_WIDTH               = 32,
  parameter PRF_TLP_NUM_WSTRBS               = 8,
  parameter PRF_TLP_NUM_WSTRBS_GT_4          = 0,
  parameter PRF_TLP_NUM_DWORDS               = 3,
  parameter SLV_CONV_FAC_WIDTH               = 4,
  parameter CX_RAS_PROT_RANGE                = 2,
  parameter ATTR_WD                          = 3,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                               = `TP
  )
  (
  // -------------------------------------------------------------------------------------
  // Clocks and Resets
  // -------------------------------------------------------------------------------------
  input                                              slv_aclk,
  input                                              slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Posted Request interface
  // -------------------------------------------------------------------------------------
  input                                              sif_p_valid,
  input       [SLV_BUS_ADDR_WIDTH-1:0]               sif_p_addr,
  input       [2:0]                                  sif_p_size,
  input       [SLV_BURST_LEN_PW-1:0]                 sif_p_len,
  input                                              sif_p_last,
  input       [DC_CPL_STATUS_WD-1:0]                 sif_p_cpl_stat,
  input       [SLV_BUS_WSTRB_WIDTH-1:0]              sif_p_strb,
  input       [SLV_BUS_WSTRB_WIDTH-1:0]              sif_p_ep_strb,
  input       [SLV_BUS_WSTRB_WIDTH-1:0]              sif_p_silentDrop_strb,
  input       [SLV_BUS_WSTRB_WIDTH-1:0]              sif_p_silentDrop_strb_masked,
  input       [SLV_BUS_DATA_WIDTH-1:0]               sif_p_data,
  input       [7:0]                                  sif_p_msg_code,
  input       [4:0]                                  sif_p_type,
  input       [2:0]                                  sif_p_tc,
  input                                              sif_p_ep,
  input                                              sif_p_ro,
  input                                              sif_p_ns,
  input                                              sif_p_ido,
  input       [1:0]                                  sif_p_ats,
  input                                              sif_p_nw,
  input       [NFUNC_WD-1:0]                         sif_p_func_num,
  input       [MISC_INFO_TPH_WD-1:0]                 sif_p_tph,
  input       [TX_TLP_PREFIX_WD-1:0]                 sif_p_prfx,
  input       [CX_TAG_SIZE-1:0]                      sif_p_tag,
  input                                              sif_p_atu_bypass,
  input [8:0]                                        sif_p_dst_segment,
  input       [SLV_BUS_ID_WIDTH-1:0]                 sif_p_axi_id,
  input                                              sif_p_first_wrp_split_xact,
  input                                              sif_p_wrp_valid,
  output wire                                        prf_p_ready,
  // -------------------------------------------------------------------------------------
  // Posted Request interface
  // -------------------------------------------------------------------------------------
  output wire [7:0]                                  prf_tlp_byte_en,
  output wire                                        prf_tlp_dv,
  output wire                                        prf_tlp_eot,
  output wire                                        prf_tlp_hv,
  output wire [1:0]                                  prf_tlp_fmt,
  output wire [4:0]                                  prf_tlp_type,
  output wire [2:0]                                  prf_tlp_tc,
  output wire                                        prf_tlp_ep,
  output wire [ATTR_WD-1:0]                          prf_tlp_attr,
  output wire [SLV_MTU_PW-1:0]                       prf_tlp_byte_len,
  output wire [DC_CPL_STATUS_WD-1:0]                 prf_tlp_cpl_stat,
  output wire [SLV_BUS_ADDR_WIDTH -1:0]              prf_tlp_addr,
  output wire [PRF_TLP_DATA_WIDTH -1:0]              prf_tlp_data,
  output wire [PRF_TLP_NUM_WSTRBS -1:0]              prf_tlp_strb,
  output wire [PRF_TLP_NUM_WSTRBS -1:0]              prf_tlp_ep_strb,
  output wire [PRF_TLP_NUM_WSTRBS -1:0]              prf_tlp_silentDrop_strb,
  output wire [PRF_TLP_NUM_WSTRBS -1:0]              prf_tlp_silentDrop_strb_masked,
  output wire [1:0]                                  prf_tlp_ats,
  output wire                                        prf_tlp_nw,
  output wire [NFUNC_WD-1:0]                         prf_tlp_func_num,
  output wire                                        prf_tlp_th,
  output wire [1:0]                                  prf_tlp_ph,
  output wire [7:0]                                  prf_tlp_st,
  output wire [TX_TLP_PREFIX_WD-1:0]                 prf_tlp_prfx,
  output wire [CX_TAG_SIZE-1:0]                      prf_p_tag,
  output wire                                        prf_tlp_atu_bypass,
  output wire [8:0]                                  prf_tlp_dst_segment,
  output wire [SLV_BUS_ID_WIDTH-1:0]                 prf_tlp_axi_id,
  output wire                                        prf_first_wrp_split_xact,
  output wire                                        prf_wrp_valid,
  input                                              pdcmp_halt
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  // {type,tc,ep,ro,ns,cpl_stat,ido,ats,nw,func_num,vfunc_num,vfunc_active,tph,prfx,ln,itag,atu_byp,dst_segment,id}
  localparam P_REQ_INFO_PASS_WD ={11 +
                                  DC_CPL_STATUS_WD +
                                  1 +
                                  3 +
                                  NFUNC_WD +
                                  MISC_INFO_TPH_WD +
                                  TX_TLP_PREFIX_WD +
                                  CX_TAG_SIZE +
                                  1 +
                                  9 +
                                  2 +
                                  SLV_BUS_ID_WIDTH
                                 };

  localparam P_REQ_INFO_TYPE_MSB = P_REQ_INFO_PASS_WD-1;

  // {addr,size,len,msg_code,req_info_pass}
  localparam P_REQ_INFO_WD = {P_REQ_INFO_PASS_WD +
                              SLV_BUS_ADDR_WIDTH +
                              3 +
                              SLV_BURST_LEN_PW +
                              8
                             };
  // -------------------------------------------------------------------------------------
  // Wires/Regs
  // -------------------------------------------------------------------------------------
  wire [ATTR_WD-1:0]                                 sif_p_attr;

  wire                                               s_sif_p_last;

  // Pass through posted request info
  wire [P_REQ_INFO_PASS_WD-1:0]                      s_sif_p_req_info_pass;
  // All posted request info
  wire [P_REQ_INFO_WD-1:0]                           s_sif_p_req_info;



  // Posted interface signals to control block
  wire                                               s_p_valid;
  wire                                               s_p_last;
  wire [PRF_TLP_NUM_WSTRBS-1:0]                      s_p_strb;
  wire [PRF_TLP_NUM_WSTRBS-1:0]                      s_p_ep_strb;
  wire [PRF_TLP_NUM_WSTRBS-1:0]                      s_p_silentDrop_strb;
  wire [PRF_TLP_NUM_WSTRBS-1:0]                      s_p_silentDrop_strb_masked;
  wire [PRF_TLP_DATA_WIDTH-1:0]                      s_p_data;
  wire [SLV_MTU_PW-1:0]                              s_p_num_bytes_per_beat;
  wire [SLV_BUS_ADDR_WIDTH-1:0]                      s_p_addr;
  wire [2:0]                                         s_p_size;
  wire [SLV_BURST_LEN_PW-1:0]                        s_p_len;
  wire [7:0]                                         s_p_msg_code;
  wire [P_REQ_INFO_PASS_WD-1:0]                      s_p_req_info_pass;
  wire [4:0]                                         s_p_type;
  reg                                                r_p_valid;
  reg                                                r_p_last;
  reg  [PRF_TLP_NUM_WSTRBS-1:0]                      r_p_strb;
  reg  [PRF_TLP_NUM_WSTRBS-1:0]                      r_p_ep_strb;
  reg  [PRF_TLP_NUM_WSTRBS-1:0]                      r_p_silentDrop_strb;
  reg  [PRF_TLP_NUM_WSTRBS-1:0]                      r_p_silentDrop_strb_masked;
  reg  [PRF_TLP_DATA_WIDTH-1:0]                      r_p_data;
  reg  [SLV_BUS_ADDR_WIDTH-1:0]                      r_p_addr;
  reg  [2:0]                                         r_p_size;
  reg  [SLV_BURST_LEN_PW-1:0]                        r_p_len;
  reg  [7:0]                                         r_p_msg_code;
  reg  [P_REQ_INFO_PASS_WD-1:0]                      r_p_req_info_pass;
  reg  [4:0]                                         r_p_type;
  wire                                               prf_tlp_ro;
  wire                                               prf_tlp_ns;
  wire                                               prf_tlp_ido;


  wire                                               ctl_p_halt;

  wire [P_REQ_INFO_PASS_WD-1:0]                      ctl_p_req_info_pass;
  wire [MISC_INFO_TPH_WD-1:0]                        s_p_req_info_tph;

// -------------------------------------------------------------------------------------
// DESIGN
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// Pack request information
// -------------------------------------------------------------------------------------
  // Pack pass through posted request info
  // {type,tc,ep,ro,ns,ido,ats,nw,func_num,vfunc_num,vfunc_active,tph,prfx,ln, itag
  // first_wrp_split,atu_byp,dst_segment,id}

assign sif_p_attr  = {sif_p_ido,sif_p_ro,sif_p_ns};


  assign s_sif_p_req_info_pass = {{(P_REQ_INFO_PASS_WD-(5+3+1+ATTR_WD+DC_CPL_STATUS_WD                                                                                        +2+1
                                                                                        +NFUNC_WD
                                                                                        +MISC_INFO_TPH_WD
                                                                                        +TX_TLP_PREFIX_WD
                                                                                        +CX_TAG_SIZE
                                                                                        +1
                                                                                        +9
                                                                                        +2
                                                                                        +SLV_BUS_ID_WIDTH
                                                                                      )){1'b0}}
  , sif_p_type                // 5
  , sif_p_tc                  // 3
  , sif_p_ep                  // 1
  , sif_p_attr                // ATTR_WD
  , sif_p_cpl_stat            // DC_CPL_STATUS_WD
  , sif_p_ats                 // 2
  , sif_p_nw                  // 1
  , sif_p_func_num            // NFUNC_WD
  , sif_p_tph                 // MISC_INFO_TPH_WD
  , sif_p_prfx                //  TX_TLP_PREFIX_WD
  , sif_p_tag            //  CX_TAG_SIZE
  , sif_p_atu_bypass          // 1
  , sif_p_dst_segment         // 9
  , sif_p_first_wrp_split_xact // 1
  , sif_p_wrp_valid            // 1
  , sif_p_axi_id              // SLV_BUS_ID_WIDTH
  };

  // {addr,size,len,msg_code,req_info_pass}
  assign s_sif_p_req_info = {{(P_REQ_INFO_WD-(SLV_BUS_ADDR_WIDTH+3+SLV_BURST_LEN_PW+8+P_REQ_INFO_PASS_WD)){1'b0}}
  , sif_p_addr          // SLV_BUS_ADDR_WIDTH
  , sif_p_size          // 3
  , sif_p_len           // SLV_BURST_LEN_PW
  , sif_p_msg_code      // 8
  , s_sif_p_req_info_pass
  };

  // Mask last null write data beat
  assign s_sif_p_last = sif_p_last && sif_p_valid;

  // Build s_p_* interface
  assign s_p_valid              = sif_p_valid;
  assign s_p_last               = sif_p_last;
  assign s_p_strb               = sif_p_strb;
  assign s_p_ep_strb            = sif_p_ep_strb;
  assign s_p_silentDrop_strb    = sif_p_silentDrop_strb;
  assign s_p_silentDrop_strb_masked= sif_p_silentDrop_strb_masked;
  assign s_p_data               = sif_p_data;
  assign s_p_addr               = sif_p_addr;
  assign s_p_size               = sif_p_size;
  assign s_p_len                = sif_p_len;
  assign s_p_msg_code           = sif_p_msg_code;
  assign s_p_req_info_pass      = s_sif_p_req_info_pass;
  assign s_p_type               = s_p_req_info_pass[P_REQ_INFO_TYPE_MSB -: 5];

  // -------------------------------------------------------------------------------------
  // Register stage to improve timing
  // -------------------------------------------------------------------------------------
  always@(posedge slv_aclk or negedge slv_aresetn) begin
    if(!slv_aresetn)begin
      r_p_valid          <= #TP 1'b0;
      r_p_last           <= #TP 1'b0;
      r_p_strb           <= #TP {PRF_TLP_NUM_WSTRBS{1'b0}};
      r_p_ep_strb        <= #TP {PRF_TLP_NUM_WSTRBS{1'b0}};
      r_p_silentDrop_strb<= #TP {PRF_TLP_NUM_WSTRBS{1'b0}};
      r_p_silentDrop_strb_masked<= #TP {PRF_TLP_NUM_WSTRBS{1'b0}};
      r_p_data           <= #TP {PRF_TLP_DATA_WIDTH{1'b0}};
      r_p_addr           <= #TP {SLV_BUS_ADDR_WIDTH{1'b0}};
      r_p_size           <= #TP 3'h0;
      r_p_len            <= #TP {SLV_BURST_LEN_PW{1'b0}};
      r_p_msg_code       <= #TP 8'h00;
      r_p_req_info_pass  <= #TP {P_REQ_INFO_PASS_WD{1'b0}};
      r_p_type           <= #TP 5'h0;
    end else begin
      if(!ctl_p_halt)begin
        r_p_valid          <= #TP s_p_valid;
        r_p_last           <= #TP s_p_last;
        r_p_strb           <= #TP s_p_strb;
        r_p_ep_strb        <= #TP s_p_ep_strb;
        r_p_silentDrop_strb<= #TP s_p_silentDrop_strb;
        r_p_silentDrop_strb_masked<= #TP s_p_silentDrop_strb_masked;
        r_p_data           <= #TP s_p_data;
        r_p_addr           <= #TP s_p_addr;
        r_p_size           <= #TP s_p_size;
        r_p_len            <= #TP s_p_len;
        r_p_msg_code       <= #TP s_p_msg_code;
        r_p_req_info_pass  <= #TP s_p_req_info_pass;
        r_p_type           <= #TP s_p_type;
      end
    end
  end

  // -------------------------------------------------------------------------------------
  // Posted TLP formation control
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_ob_p_formation_ctl
  
  #(.PRF_TLP_DATA_WIDTH                      (PRF_TLP_DATA_WIDTH)
   ,.PRF_TLP_NUM_WSTRBS                      (PRF_TLP_NUM_WSTRBS)
   ,.PRF_TLP_NUM_WSTRBS_GT_4                 (PRF_TLP_NUM_WSTRBS_GT_4)
   ,.PRF_TLP_NUM_DWORDS                      (PRF_TLP_NUM_DWORDS)
   ,.SLV_BUS_ADDR_WIDTH                      (SLV_BUS_ADDR_WIDTH)
   ,.SLAVE_BUS_ADDR_WIDTH                    (SLAVE_BUS_ADDR_WIDTH)
   ,.SLV_MTU_PW                              (SLV_MTU_PW)
   ,.SLV_BURST_LEN_PW                        (SLV_BURST_LEN_PW)
   ,.P_REQ_INFO_PASS_WD                      (P_REQ_INFO_PASS_WD)
   ,.CX_RAS_PROT_RANGE                       (CX_RAS_PROT_RANGE)
  )
  u_ctl
  (
    // Clock and resets
    .slv_aclk                     (slv_aclk),
    .slv_aresetn                  (slv_aresetn),
    // s_p_* interface
    .p_valid                      (r_p_valid),
    .p_last                       (r_p_last),
    .p_strb                       (r_p_strb),
    .p_ep_strb                    (r_p_ep_strb),
    .p_silentDrop_strb            (r_p_silentDrop_strb),
    .p_silentDrop_strb_masked     (r_p_silentDrop_strb_masked),
    .p_data                       (r_p_data),
    .p_addr                       (r_p_addr),
    .p_size                       (r_p_size),
    .p_len                        (r_p_len),
    .p_msg_code                   (r_p_msg_code),
    .p_type                       (r_p_type),
    .p_req_info_pass              (r_p_req_info_pass),
    .ctl_p_halt                   (ctl_p_halt),
    // Posted Formation TLP interface
    .ctl_tlp_byte_en              (prf_tlp_byte_en),
    .ctl_tlp_dv                   (prf_tlp_dv),
    .ctl_tlp_eot                  (prf_tlp_eot),
    .ctl_tlp_hv                   (prf_tlp_hv),
    .ctl_tlp_fmt                  (prf_tlp_fmt),
    .ctl_tlp_byte_len             (prf_tlp_byte_len),
    .ctl_p_req_info_pass          (ctl_p_req_info_pass),
    .ctl_tlp_addr                 (prf_tlp_addr),
    .ctl_tlp_data                 (prf_tlp_data),
    .ctl_tlp_strb                 (prf_tlp_strb),
    .ctl_tlp_ep_strb              (prf_tlp_ep_strb),
    .ctl_tlp_silentDrop_strb      (prf_tlp_silentDrop_strb),
    .ctl_tlp_silentDrop_strb_masked(prf_tlp_silentDrop_strb_masked),
    .pdcmp_halt                   (pdcmp_halt)
  );

 // -------------------------------------------------------------------------------------
 // Assign outputs
 // -------------------------------------------------------------------------------------
  assign {
    prf_tlp_type                // 5
  , prf_tlp_tc                  // 3
  , prf_tlp_ep                  // 1
  , prf_tlp_attr                // ATTR_WD
  , prf_tlp_cpl_stat            // DC_CPL_STATUS_WD
  , prf_tlp_ats                 // 2
  , prf_tlp_nw                  // 1
  , prf_tlp_func_num            // NFUNC_WD
  , s_p_req_info_tph         // MISC_INFO_TPH_WD
  , prf_tlp_prfx                //  TX_TLP_PREFIX_WD
  , prf_p_tag                //  CX_TAG_SIZE
  , prf_tlp_atu_bypass          // 1
  , prf_tlp_dst_segment         // 9
  , prf_first_wrp_split_xact    // 1
  , prf_wrp_valid               // 1
  , prf_tlp_axi_id              // SLV_BUS_ID_WIDTH
  } = ctl_p_req_info_pass;

  assign { prf_tlp_st , prf_tlp_ph , prf_tlp_th } = s_p_req_info_tph;
assign prf_p_ready = !ctl_p_halt;

endmodule
