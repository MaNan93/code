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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_cpl_tlp_store.sv#5 $
// ------------------------------------------------------------------------- 
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_cpl_tlp_store
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NVF;
  import DWC_pcie_ctl_pkg::PF_WD;
  import DWC_pcie_ctl_pkg::VFI_WD;
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::BUSNUM_WD;
  import DWC_pcie_ctl_pkg::DEVNUM_WD;  
  import DWC_pcie_core_pkg::xadm_radm_tx_npr_t;
  import radm_ms_pkg::CPL_LUT_PTR_WD;
  import radm_ms_pkg::CPL_LUT_FRAG_DEPTH;
  import radm_ms_pkg::CPL_LUT_FRAG_PTR_WD;
  import radm_ms_pkg::NFRAG;
  import radm_ms_pkg::FRAGI_WD;
  import radm_ms_pkg::CPL_ENTRY_WIDTH;  
  import radm_ms_pkg::CPL_ENTRY_WIDTH2;        
  import radm_ms_pkg::N_FLT_MASK;
  import radm_ms_pkg::TIMEOUT_GRANULARITY;
  import radm_ms_pkg::N_RADM_CPL_TLP;
  import radm_ms_pkg::N_XADM_RADM_TX_NPR_IF;
  import radm_ms_pkg::FUNC_NUM_INDEX;

                           (
  //--------------------------input signals-----------------------------
  input        [DEVNUM_WD -1:0]                           cfg_pbus_dev_num,           // "static" // Device number
  input        [BUSNUM_WD -1:0]                           cfg_pbus_num,               // "static" // Bus number
  input        xadm_radm_tx_npr_t                         xadm_radm_tx_npr,
  input        [N_XADM_RADM_TX_NPR_IF-1:0][CPL_LUT_PTR_WD-1:0]     xtlh_xmt_tlp_tag,           // transmitted TLP tag
  input        [N_XADM_RADM_TX_NPR_IF-1:0]                         xtlh_xmt_14bit_tag,         
  input        [N_FLT_MASK-1:0]                           cfg_filter_rule_mask,       // "static" // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
  // Updates from filter 
  input        [N_RADM_CPL_TLP-1:0]                       update_lut_content_pipe,    // Update request from TLP check module.
  input        [N_RADM_CPL_TLP-1:0][CPL_LUT_PTR_WD-1:0]   update_lut_addr_pipe,       // Address for the LUT entry update.
  input        [N_RADM_CPL_TLP-1:0][CPL_ENTRY_WIDTH2-1:0] update_lut_byte_cnt_pipe,   // Byte count update at the lut entry.
  input                                                   timer_freq,
  input        [NF-1:0]                                   func_timeout,
  input        [PF_WD-1:0]                                timeout_pf,
  input                                                   timer_expired_incr,
  input                                                   timeout_error,              // CPL TLP timeout error.  
  input        [CPL_LUT_PTR_WD-1:0]                       timeout_addr,               // CPL TLP Timeout address.  
  input        [CPL_LUT_PTR_WD-1:0]                       timeout_addr_reg,           // CPL TLP timeoug address flopped value.
  input                                                   rstctl_core_flush_req,
  input        [N_RADM_CPL_TLP-1:0][CPL_LUT_PTR_WD-1:0]   cpl_tlp_ant_tag,            // CPL TLP one clock cycle Early TAG 
  input        [N_RADM_CPL_TLP-1:0]                       cpl_last_pipe,              // received CPL last indication to perform update on last CPL TLP in multi TLP per same tags.
  //--------------------------Output Signals-------------------------
  output logic [N_RADM_CPL_TLP-1:0][CPL_ENTRY_WIDTH-1:0]  cpl_lut_vec,
  output       [CPL_ENTRY_WIDTH-1:0]                      cpl_lut_error_vec,          // LUT vec  output based on the timeout address value to present it to the application. 
  output logic [N_RADM_CPL_TLP-1:0][CPL_ENTRY_WIDTH2-1:0] cpl_lut_vec2,               // LUT vec2 outputs for each early tags of CPL TLP.
  output       [CPL_ENTRY_WIDTH2-1:0]                     cpl_lut_error_vec2,         // LUT vec2 output based on the timeout address value to present it to the application. 
  output logic [N_RADM_CPL_TLP-1:0]                       cpl_lut_valid,              // Valid indication for each early tags of the CPL TLPs. 
  output                                                  cpl_lut_error_valid,        // Valid output based on the timeout address register value. 
  output       [TIMEOUT_GRANULARITY-1:0]                  cpl_lut_pertag_timer_value, // pertag timer value to check timeout condition within a timer module.
  output                                                  cpl_lut_empty,              // cpl lut empty indication      
  output logic [NFRAG*CPL_LUT_FRAG_DEPTH-1:0]             radm_cpl_lut_valid,
  output logic [N_XADM_RADM_TX_NPR_IF-1:0]                int_update_lut_d,           // radm_cpl_pending logic
  output logic [N_XADM_RADM_TX_NPR_IF-1:0][FUNC_NUM_INDEX-1:0] lutin_func_num_d,      // radm_cpl_pending logic(at timer)

  input                                                   core_clk,                   // core clock input to the module
  input                                                   core_rst_n                  // active low reset input
);
  ///////////////////////////////////////////////////////////////////
  // Local wires and registers
  //
  ///////////////////////////////////////////////////////////////////
  logic  [N_RADM_CPL_TLP-1:0][FRAGI_WD-1:0]                int_np_tlp_frag_sel;
  logic  [N_RADM_CPL_TLP-1:0][FRAGI_WD-1:0]                int_np_tlp_frag_sel_reg;
  logic  [N_RADM_CPL_TLP-1:0][CPL_LUT_FRAG_PTR_WD-1:0]     int_cpl_tlp_ant_tag;
  logic  [N_RADM_CPL_TLP-1:0][FRAGI_WD-1:0]                int_lut_update_frag_sel;
  logic  [N_RADM_CPL_TLP-1:0][CPL_LUT_FRAG_PTR_WD-1:0]     int_update_lut_addr_pipe;
  logic  [FRAGI_WD-1:0]                                    int_timeout_addr_frag_sel;
  logic  [FRAGI_WD-1:0]                                    int_timeout_addr_reg_frag_sel;
 
  logic  [NFRAG-1:0][N_RADM_CPL_TLP-1:0][CPL_ENTRY_WIDTH-1:0]   int_cpl_lut_frag_vec;           
  logic  [NFRAG-1:0][N_RADM_CPL_TLP-1:0][CPL_ENTRY_WIDTH2-1:0]  int_cpl_lut_frag_vec2;  
  logic  [NFRAG-1:0][N_RADM_CPL_TLP-1:0]                   int_cpl_lut_frag_valid;        
 
  logic  [NFRAG-1:0][N_RADM_CPL_TLP-1:0]                   int_update_lut_content_pipe;       

  logic  [NFRAG-1:0][CPL_ENTRY_WIDTH-1:0]                  int_cpl_lut_frag_error_vec;       // LUT vec  output based on the timeout address value to present it to the application. 
  logic  [NFRAG-1:0][CPL_ENTRY_WIDTH2-1:0]                 int_cpl_lut_frag_error_vec2;      // LUT vec2 output based on the timeout address value to present it to the application. 
  logic  [NFRAG-1:0][1-1:0]                                int_cpl_lut_frag_error_valid;     // Valid output based on the timeout address  value. 

  logic  [NFRAG-1:0][TIMEOUT_GRANULARITY-1:0]              int_cpl_lut_frag_pertag_timer_value;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][FRAGI_WD-1:0]                  int_np_tlp_frag_wr_sel;
  logic  [NFRAG-1:0][N_XADM_RADM_TX_NPR_IF-1:0]                     int_xtlh_xmt_tlp_done;  
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][CPL_LUT_FRAG_PTR_WD-1:0]       int_xtlh_xmt_tlp_tag;

  logic    [N_XADM_RADM_TX_NPR_IF-1:0]                              xtlh_xmt_tlp_done;       // Separate transmitted TLP done signal for each fragments.

  logic  [NFRAG-1:0][N_XADM_RADM_TX_NPR_IF-1:0]                           frag_int_update_lut_d;  // eDPC RAM2P register enable
  logic  [NFRAG-1:0][N_XADM_RADM_TX_NPR_IF-1:0][FUNC_NUM_INDEX-1:0]       frag_lutin_func_num_d; 


  /////////////////////////////////////////////////////////////////////
  // Fragment selection decoding based on the TLP tags, update address
  // and timeout address.
  //
  // Fragment information is gettin gused to select the proper fragment
  // output for the next stage processing or update the proper fragment
  /////////////////////////////////////////////////////////////////////
  always@(*) begin
    for(int i=0;i<N_RADM_CPL_TLP;i=i+1) begin
        int_np_tlp_frag_sel[i]        =  1'b0;
        int_lut_update_frag_sel[i]    =  1'b0;
        int_cpl_tlp_ant_tag[i]        = cpl_tlp_ant_tag[i][CPL_LUT_FRAG_PTR_WD-1:0];
        int_update_lut_addr_pipe[i]   = update_lut_addr_pipe[i][CPL_LUT_FRAG_PTR_WD-1:0];
    end
  end
  
  assign  int_timeout_addr_frag_sel     = 1'b0;
  assign  int_timeout_addr_reg_frag_sel = 1'b0;
  ////////////////////////////////////////////////////////////////////////////
  // Routing of the NP TLP attributes to the appropriate fragment based on the
  // tag values.
  //
  ////////////////////////////////////////////////////////////////////////////
  assign xtlh_xmt_tlp_done[N_XADM_RADM_TX_NPR_IF-1:0] = xadm_radm_tx_npr.valid[N_XADM_RADM_TX_NPR_IF-1:0];
  
  always_comb begin
    for(int i=0;i<N_XADM_RADM_TX_NPR_IF;i=i+1) begin
      int_np_tlp_frag_wr_sel[i] = {FRAGI_WD{1'b0}};
    end
  end

  always@(*) begin
    for(int i=0;i<NFRAG;i=i+1) begin
      for(int j=0;j<N_XADM_RADM_TX_NPR_IF;j=j+1) begin
        int_xtlh_xmt_tlp_done[i][j] = (int_np_tlp_frag_wr_sel[j] == i) ? xtlh_xmt_tlp_done[j] : 1'b0;
      end  
    end
  end

  always@(*) begin
    for(int i=0;i<N_XADM_RADM_TX_NPR_IF;i=i+1) begin
      int_xtlh_xmt_tlp_tag[i] = xtlh_xmt_tlp_tag[i][CPL_LUT_FRAG_PTR_WD-1:0]; 
    end
  end
  //////////////////////////////////////////////////////////////////////
  // Selection of the lut vec and valid information based on the fragment
  // selection.
  //
  //////////////////////////////////////////////////////////////////////
  always @(posedge core_clk or negedge core_rst_n)  
  begin : CPL_FRAG_SEL_REG
    if(!core_rst_n) begin
      for(int i=0;i<N_RADM_CPL_TLP;i=i+1) 
        int_np_tlp_frag_sel_reg[i] <= #TP {FRAGI_WD{1'b0}}; 
    end else begin
      for(int i=0;i<N_RADM_CPL_TLP;i=i+1) 
        int_np_tlp_frag_sel_reg[i] <= #TP int_np_tlp_frag_sel[i];
    end
  end  
  
  always@(*) begin
    for(int i=0;i<N_RADM_CPL_TLP;i=i+1) begin
      cpl_lut_vec[i]    = int_cpl_lut_frag_vec[int_np_tlp_frag_sel_reg[i]][i];
      cpl_lut_vec2[i]   = int_cpl_lut_frag_vec2[int_np_tlp_frag_sel_reg[i]][i];
      cpl_lut_valid[i]  = int_cpl_lut_frag_valid[int_np_tlp_frag_sel_reg[i]][i];
   end  
  end
  //////////////////////////////////////////////////////////////////////
  // Routing of the lut update request to proper fragment.
  //
  //////////////////////////////////////////////////////////////////////
  always@(*) begin
    for(int i=0;i<NFRAG;i=i+1) begin
      for(int j=0;j<N_RADM_CPL_TLP ;j=j+1) begin
        int_update_lut_content_pipe[i][j] = (int_lut_update_frag_sel[j] == i) ? update_lut_content_pipe[j] : 1'b0;
      end  
    end
  end
  ///////////////////////////////////////////////////////////////////////   
  // Selection of the valid and lut vec for the timer block.
  //
  ///////////////////////////////////////////////////////////////////////
  assign  cpl_lut_error_vec             = int_cpl_lut_frag_error_vec[int_timeout_addr_frag_sel];
  assign  cpl_lut_error_vec2            = int_cpl_lut_frag_error_vec2[int_timeout_addr_frag_sel];
  assign  cpl_lut_error_valid           = int_cpl_lut_frag_error_valid[int_timeout_addr_frag_sel];

  assign cpl_lut_pertag_timer_value     = int_cpl_lut_frag_pertag_timer_value[int_timeout_addr_reg_frag_sel]; 

  ///////////////////////////////////////////////////////////////////////
  // generating valid output array
  ///////////////////////////////////////////////////////////////////////
  logic [NFRAG-1:0][CPL_LUT_FRAG_DEPTH-1:0]     cpl_lut_frag_valid;   
  
  always_comb begin
    for(int i=0;i<NFRAG;i++)
      radm_cpl_lut_valid[i*CPL_LUT_FRAG_DEPTH +: CPL_LUT_FRAG_DEPTH] = cpl_lut_frag_valid[i];
  end

  ////////////////////////////////////////////////////////////////////////
  // Compress the fragmented information to be used for radm_cpl_pending logic. 
  //
  ////////////////////////////////////////////////////////////////////////
  always@(*) begin
    int_update_lut_d = '0;
    lutin_func_num_d = '0;
    for(int i=0;i<NFRAG;i=i+1) begin
      for(int j=0;j<N_XADM_RADM_TX_NPR_IF ;j=j+1) begin
         if(frag_int_update_lut_d[i][j]) begin
            int_update_lut_d[j] = 1'b1;
            lutin_func_num_d[j] = frag_lutin_func_num_d[i][j];
         end
      end  
    end
  end  


  ////////////////////////////////////////////////////////////////////////
  // Instantiation of the fragment block based on the number of fragment 
  // configuration.
  //
  ////////////////////////////////////////////////////////////////////////
  logic  [NFRAG-1:0]        cpl_lut_frags_empty;

  assign cpl_lut_empty = &(cpl_lut_frags_empty);
  
  generate
  for (genvar num_frag=0; num_frag<NFRAG; num_frag = num_frag+1) begin : u_radm_cpl_tlp_fragment_gen
  radm_cpl_tlp_fragment
  
  u_radm_cpl_tlp_fragment(
  // ---- inputs ---------------
  .cfg_pbus_dev_num                           (cfg_pbus_dev_num),           // "static" // Device number
  .cfg_pbus_num                               (cfg_pbus_num),               // "static" // Bus number
  
  .xadm_radm_tx_npr                           (xadm_radm_tx_npr),
  
  .xtlh_xmt_14bit_tag                         (xtlh_xmt_14bit_tag), 
  .cfg_filter_rule_mask                       (cfg_filter_rule_mask),
  .xtlh_xmt_tlp_done                          (int_xtlh_xmt_tlp_done[num_frag]), 
  .xtlh_xmt_tlp_tag                           (int_xtlh_xmt_tlp_tag),       

 
  .update_lut_content_pipe                    (int_update_lut_content_pipe[num_frag]),    
  .update_lut_addr_pipe                       (int_update_lut_addr_pipe),       
  .update_lut_byte_cnt_pipe                   (update_lut_byte_cnt_pipe),   
  .timer_freq                                 (timer_freq),
  .func_timeout                               (func_timeout),
  
  .timeout_pf                                 (timeout_pf),
  .timer_expired_incr                         (timer_expired_incr),
  .timeout_error                              (timeout_error),        
  .timeout_addr                               (timeout_addr[CPL_LUT_FRAG_PTR_WD-1:0]),           
  .timeout_addr_reg                           (timeout_addr_reg[CPL_LUT_FRAG_PTR_WD-1:0]),   
  .rstctl_core_flush_req                      (rstctl_core_flush_req),

  .timeout_addr_reg_frag_sel                  ((int_timeout_addr_reg_frag_sel == num_frag)),
  .cpl_lut_frag_pertag_timer_value            (int_cpl_lut_frag_pertag_timer_value[num_frag]),
  
  .cpl_tlp_ant_tag                            (int_cpl_tlp_ant_tag),  
  
  .cpl_last_pipe                              (cpl_last_pipe),  
  //--------------------------Output Signals-------------------------
  .cpl_lut_frag_vec                           (int_cpl_lut_frag_vec[num_frag]),     
  .cpl_lut_frag_error_vec                     (int_cpl_lut_frag_error_vec[num_frag]),     
  .cpl_lut_frag_vec2                          (int_cpl_lut_frag_vec2[num_frag]),      
  .cpl_lut_frag_error_vec2                    (int_cpl_lut_frag_error_vec2[num_frag]),     
  .cpl_lut_frag_valid                         (int_cpl_lut_frag_valid[num_frag]),       
  .cpl_lut_frag_error_valid                   (int_cpl_lut_frag_error_valid[num_frag]),
  .cpl_lut_frag_empty                         (cpl_lut_frags_empty[num_frag]),
  .valid                                      (cpl_lut_frag_valid[num_frag]),
  .int_update_lut_d                           (frag_int_update_lut_d[num_frag]),
  .lutin_func_num_d                           (frag_lutin_func_num_d[num_frag]),

  .core_clk                                   (core_clk),                  
  .core_rst_n                                 (core_rst_n)                 
);
end
endgenerate

endmodule
