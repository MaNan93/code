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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_cpl_tlp_fragment.sv#6 $
// -------------------------------------------------------------------------
/////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_cpl_tlp_fragment
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NVF;
  import DWC_pcie_ctl_pkg::PF_WD;
  import DWC_pcie_ctl_pkg::VF_WD;
  import DWC_pcie_ctl_pkg::VFI_WD;
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::BUSNUM_WD;
  import DWC_pcie_ctl_pkg::DEVNUM_WD;  
  import DWC_pcie_core_pkg::xadm_radm_tx_npr_t;
  import radm_ms_pkg::N_RADM_CPL_TLP;
  import radm_ms_pkg::CPL_LUT_FRAG_DEPTH;
  import radm_ms_pkg::CPL_LUT_FRAG_PTR_WD;
  import radm_ms_pkg::CPL_ENTRY_WIDTH;  
  import radm_ms_pkg::CPL_ENTRY_WIDTH2;        
  import radm_ms_pkg::FUNC_NUM_INDEX;
  import radm_ms_pkg::TIMEOUT_GRANULARITY;
  import radm_ms_pkg::N_FLT_MASK;
  import radm_ms_pkg::N_XADM_RADM_TX_NPR_IF;
  import radm_ms_pkg::XTLH_WRITE_TO_LUT_DELAY;

                              (
  //--------------------------input signals-----------------------------
  // transmitted NP TLP inputs
  input        [DEVNUM_WD -1:0]                              cfg_pbus_dev_num,           // "static" // Device number
  input        [BUSNUM_WD -1:0]                              cfg_pbus_num,               // "static" // Bus number
  input        xadm_radm_tx_npr_t                            xadm_radm_tx_npr,
  input        [N_XADM_RADM_TX_NPR_IF-1:0]                            xtlh_xmt_14bit_tag,         
  input        [N_FLT_MASK-1:0]                              cfg_filter_rule_mask,       // "static" // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
  input        [N_XADM_RADM_TX_NPR_IF-1:0]                            xtlh_xmt_tlp_done,          // transmitted TLP is done
  input        [N_XADM_RADM_TX_NPR_IF-1:0][CPL_LUT_FRAG_PTR_WD-1:0]   xtlh_xmt_tlp_tag,           // transmitted TLP tag
 
  input        [N_RADM_CPL_TLP-1:0][CPL_LUT_FRAG_PTR_WD-1:0] cpl_tlp_ant_tag,         // CPL TLP one clock cycle Early TAG 

  //////////////////// Updates from tlp check  /////////////////////////////
  input        [N_RADM_CPL_TLP-1:0]                          update_lut_content_pipe,    // Update request from TLP check module.
  input        [N_RADM_CPL_TLP-1:0][CPL_LUT_FRAG_PTR_WD-1:0] update_lut_addr_pipe,       // Address for the LUT entry update.
  input        [N_RADM_CPL_TLP-1:0][CPL_ENTRY_WIDTH2-1:0]    update_lut_byte_cnt_pipe,   // Byte count update at the lut entry.
  input        [N_RADM_CPL_TLP-1:0]                          cpl_last_pipe,              // received CPL last indication to perform update on last CPL TLP in multi TLP per same tags.
  //////////////////// Signals from CPL Timer module ///////////////////////
  input                                                      timer_freq,
  input        [NF-1:0]                                      func_timeout,
  input        [PF_WD-1:0]                                   timeout_pf,

  input                                                      timer_expired_incr,
  input                                                      timeout_error,              // CPL TLP timeout error.  
  input        [CPL_LUT_FRAG_PTR_WD-1:0]                     timeout_addr,               // CPL TLP Timeout address.  
  input        [CPL_LUT_FRAG_PTR_WD-1:0]                     timeout_addr_reg,           // CPL TLP timeoug address flopped value.
  input                                                      rstctl_core_flush_req,
  input                                                      timeout_addr_reg_frag_sel,
  output       [TIMEOUT_GRANULARITY-1:0]                     cpl_lut_frag_pertag_timer_value,    // pertag timer value at timeout addr_reg

  //////////////////////// Output Signals  ////////////////////////////////
  output logic [N_RADM_CPL_TLP-1:0][CPL_ENTRY_WIDTH-1:0]     cpl_lut_frag_vec,           // LUT vec outputs for each early tags of CPL TLPs.
  output logic [CPL_ENTRY_WIDTH-1:0]                         cpl_lut_frag_error_vec,     // LUT vec  output based on the timeout address value to present it to the application. 
  output logic [N_RADM_CPL_TLP-1:0][CPL_ENTRY_WIDTH2-1:0]    cpl_lut_frag_vec2,          // LUT vec2 outputs for each early tags of CPL TLP.
  output logic [CPL_ENTRY_WIDTH2-1:0]                        cpl_lut_frag_error_vec2,    // LUT vec2 output based on the timeout address value to present it to the application. 
  output logic [N_RADM_CPL_TLP-1:0]                          cpl_lut_frag_valid,         // Valid indication for each early tags of the CPL TLPs. 
  output logic                                               cpl_lut_frag_error_valid,   // Valid output based on the timeout address value. 
  output  logic                                              cpl_lut_frag_empty,         // fragmented lut empty without any valid entries. 
  output  logic [CPL_LUT_FRAG_DEPTH-1:0]                     valid,                                      // Valid bits (per entry)
  output logic  [N_XADM_RADM_TX_NPR_IF-1:0]                  int_update_lut_d,           // eDPC RAM2P register enable, radm_cpl_pending logic(at timer)
  output logic  [N_XADM_RADM_TX_NPR_IF-1:0][FUNC_NUM_INDEX-1:0] lutin_func_num_d,        // radm_cpl_pending logic(at timer)


  input                                                      core_clk,                   // core clock input to the module
  input                                                      core_rst_n                  // active low reset input
);
/////////////////////////////////////////////////////////////////////
// local wires and registers
/////////////////////////////////////////////////////////////////////
// ----------------------------------------------------------
// Delay the xtlh interface, if doing rid_to_pfvf
// ----------------------------------------------------------
  logic  [N_XADM_RADM_TX_NPR_IF-1:0]                               int_xtlh_xmt_tlp_done;          // transmitted TLP is done
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][NP_REQ_TX_TYPE_WD-1:0]        int_np_req_type;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][CPL_LUT_FRAG_PTR_WD-1:0]      int_xtlh_xmt_tlp_tag;           // transmitted TLP tag
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][2:0]                          int_xtlh_xmt_tlp_attr;          // transmitted TLP attibutes

  logic  [N_XADM_RADM_TX_NPR_IF-1:0][2:0]                          int_xtlh_xmt_tlp_tc;            // transmitted TLP tc
  logic  [N_XADM_RADM_TX_NPR_IF-1:0]                               int_xtlh_xmt_cpl_trgt_interface_no;

  logic  [N_XADM_RADM_TX_NPR_IF-1:0][11:0]                         int_xtlh_xmt_tlp_len_inbytes;   // transmitted TLP length in bytes
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][7-1:0]                        int_xtlh_xmt_tlp_low_addr;

  
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][PF_WD-1:0]                    int_pf_from_rid;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][PF_WD-1:0]                    pf_from_rid;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0]                               int_update_lut;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0]                               int_dont_update_lut;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][CPL_LUT_FRAG_PTR_WD-1:0]      req_addr;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0]                               int_xtlh_xmt_tlp_done_d;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][CPL_LUT_FRAG_PTR_WD-1:0]      req_addr_d;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0]                               int_dont_update_lut_d;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][FUNC_NUM_INDEX-1:0]           lutin_func;
  logic  [CPL_LUT_FRAG_DEPTH-1:0][CPL_ENTRY_WIDTH-1:0]             cpl_lut;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][CPL_ENTRY_WIDTH-1:0]          lutin;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][CPL_ENTRY_WIDTH-1:0]          lutin_d;
  logic  [CPL_LUT_FRAG_DEPTH-1:0][CPL_ENTRY_WIDTH2-1:0]            cpl_lut2;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][CPL_ENTRY_WIDTH2-1:0]         lutin2;
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][CPL_ENTRY_WIDTH2-1:0]         lutin2_d;

  ///////////////////////////////////////////////////////////////////////
  // valid and valid_new array to manage the valid entry for each locaion.
  //
  ///////////////////////////////////////////////////////////////////////
  always @(posedge core_clk or negedge core_rst_n)
  begin: LUT_VALID_PROCESS
    if(!core_rst_n) begin
      valid      <= #TP 0;
    end else begin
      // VALID clearance based on the cpl tlp reception       
      for(int i=0;i<N_RADM_CPL_TLP;i=i+1) begin
        if(update_lut_content_pipe[i] && cpl_last_pipe[i])  begin
          valid[update_lut_addr_pipe[i]]  <= #TP 1'b0;
        end
      end
        // pertag timeout
        if(timeout_error
        ) begin
           valid[timeout_addr_reg]  <= #TP 1'b0;
        end
        // tlp transmitted towards wire
      for(int i=0;i<N_XADM_RADM_TX_NPR_IF;i=i+1) begin
        if(int_update_lut_d[i]) begin
          valid[req_addr_d[i]] <= #TP 1'b1;
        end
      end  
    end // else end
  end // always end
  ///////////////////////////////////////////////////////
  // Fragmented LUT empty condition
  //
  ///////////////////////////////////////////////////////
  always @(posedge core_clk or negedge core_rst_n) begin: LUT_EMPTY 
    if(!core_rst_n) begin
      cpl_lut_frag_empty <= #TP 1'b0;
    end else begin
      cpl_lut_frag_empty <= #TP ~(|valid);
    end
  end  
  ///////////////////////////////////////////////////////////////////
  // VALID and VALID new output for each received CPL TLP packet
  //
  ///////////////////////////////////////////////////////////////////
  always @(posedge core_clk or negedge core_rst_n)  
  begin : CPL_LUT_VALID
    if(!core_rst_n) begin
    for(int i=0;i<N_RADM_CPL_TLP;i=i+1) begin
      cpl_lut_frag_valid[i] <= #TP 1'b0; 
    end  
    end else begin
    for(int i=0;i<N_RADM_CPL_TLP;i=i+1) begin
      if(cpl_tlp_ant_tag[i] <CPL_LUT_FRAG_DEPTH)  
        cpl_lut_frag_valid[i]  <= #TP valid[cpl_tlp_ant_tag[i]];
      else
        cpl_lut_frag_valid[i] <= #TP 1'b0; 
    end
  end
  end
  ///////////////////////////////////////////////////////////////////
  // Preparing the CPL LUT input data for each of the transmitted
  // NP TLP attributes.
  //
  ///////////////////////////////////////////////////////////////////
  logic [N_XADM_RADM_TX_NPR_IF-1:0] int_xtlh_xmt_14bit_tag;
  
  generate
  for (genvar num_tx_tlp=0; num_tx_tlp<N_XADM_RADM_TX_NPR_IF; num_tx_tlp = num_tx_tlp+1) begin : u_radm_np_tlp_storage_gen
  logic  [N_XADM_RADM_TX_NPR_IF-1:0][CPL_LUT_FRAG_PTR_WD-1:0]      xtlh_xmt_tlp_tag_mapped;
  assign xtlh_xmt_tlp_tag_mapped[num_tx_tlp]        = xtlh_xmt_tlp_tag[num_tx_tlp];

  assign  int_xtlh_xmt_tlp_done[num_tx_tlp]         = xtlh_xmt_tlp_done[num_tx_tlp];
  assign  int_xtlh_xmt_tlp_len_inbytes[num_tx_tlp]  = xadm_radm_tx_npr.len_bytes[num_tx_tlp];  
  assign  int_xtlh_xmt_tlp_low_addr[num_tx_tlp]     = xadm_radm_tx_npr.low_addr[num_tx_tlp]; 
  assign  int_np_req_type[num_tx_tlp]               = xadm_radm_tx_npr.np_req_type[num_tx_tlp]; 
  assign  int_xtlh_xmt_tlp_attr[num_tx_tlp]         = xadm_radm_tx_npr.attr[num_tx_tlp]; 
  assign  int_xtlh_xmt_tlp_tc[num_tx_tlp]           = xadm_radm_tx_npr.tc[num_tx_tlp]; 
  assign  int_xtlh_xmt_cpl_trgt_interface_no[num_tx_tlp] = xadm_radm_tx_npr.cpl_trgt_interface_no[num_tx_tlp];
  assign  int_xtlh_xmt_14bit_tag[num_tx_tlp]        = xtlh_xmt_14bit_tag[num_tx_tlp]      ;
  assign  int_xtlh_xmt_tlp_tag[num_tx_tlp]          = xtlh_xmt_tlp_tag_mapped[num_tx_tlp] ; 
  assign  int_pf_from_rid[num_tx_tlp]               = pf_from_rid[num_tx_tlp]             ;
  
  // NP TLP transmitted update the LUT
  assign int_update_lut[num_tx_tlp] = ( int_xtlh_xmt_tlp_done[num_tx_tlp]
             );
  // NP TLP transmitted during FLR so dont update the LUT
  assign int_dont_update_lut[num_tx_tlp] = int_xtlh_xmt_tlp_done[num_tx_tlp]
             ;
  assign  req_addr[num_tx_tlp]   = int_xtlh_xmt_tlp_tag[num_tx_tlp];

  assign  pf_from_rid[num_tx_tlp] = xadm_radm_tx_npr.req_id[num_tx_tlp][FUNC_NUM_INDEX-1:0];      
  assign  lutin_func[num_tx_tlp]  = int_pf_from_rid[num_tx_tlp];

  always@(*) begin
      lutin[num_tx_tlp] = {
               int_xtlh_xmt_14bit_tag[num_tx_tlp], 
               int_np_req_type[num_tx_tlp],
               int_xtlh_xmt_cpl_trgt_interface_no[num_tx_tlp], 
               int_xtlh_xmt_tlp_attr[num_tx_tlp], 
               int_xtlh_xmt_tlp_tc[num_tx_tlp], 
               lutin_func[num_tx_tlp]};
      lutin2[num_tx_tlp]  = {int_xtlh_xmt_tlp_len_inbytes[num_tx_tlp][11:0],int_xtlh_xmt_tlp_low_addr[num_tx_tlp]};
  end // always_comb
  //////////////////////////////////////////////////////////////////////////// 
  // Registering of the input to improve timing.
  ////////////////////////////////////////////////////////////////////////////  
  delay_n
  
  #(XTLH_WRITE_TO_LUT_DELAY, 1+1+1+CPL_LUT_FRAG_PTR_WD+CPL_ENTRY_WIDTH + CPL_ENTRY_WIDTH2) u_xtlh_write_to_lut_delay(
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .din        ({int_xtlh_xmt_tlp_done[num_tx_tlp], int_update_lut[num_tx_tlp], int_dont_update_lut[num_tx_tlp], req_addr[num_tx_tlp], lutin[num_tx_tlp] ,lutin2[num_tx_tlp]}),
      .dout        ({int_xtlh_xmt_tlp_done_d[num_tx_tlp], int_update_lut_d[num_tx_tlp], int_dont_update_lut_d[num_tx_tlp], req_addr_d[num_tx_tlp], lutin_d[num_tx_tlp] ,lutin2_d[num_tx_tlp]})
  );
  end
  endgenerate

  // extracting from lutin_d the vf, pf information to be used at radm_cpl_pending logic(at timer)  
  always_comb begin
     for(int i=0;i<N_XADM_RADM_TX_NPR_IF;i=i+1) begin
        lutin_func_num_d[i] = lutin_d[i][FUNC_NUM_INDEX-1:0];
     end
  end

  ////////////////////////////////////////////////////////
  // NP TLP Attribute storage inside the LUT.
  //
  ////////////////////////////////////////////////////////
  always @(posedge core_clk or negedge core_rst_n) 
  begin: LUT_PROCESS
    if(!core_rst_n) begin
      for (int i=0; i<CPL_LUT_FRAG_DEPTH; i=i+1) begin
        cpl_lut[i]   <= #TP 0;
      end
    end else begin
      // update lut at address=req_addr=int_xtlh_xmt_tlp_tag
      for(int i=0;i<N_XADM_RADM_TX_NPR_IF;i=i+1) begin
        if(int_update_lut_d[i]) begin
          cpl_lut[req_addr_d[i]] <= #TP lutin_d[i];
        end  
      end
    end
  end
  /////////////////////////////////////////////////////////////
  // Byte counts and lower address value storage within a LUT.
  //
  // This information is getting used to track the total number
  // bytes received with split CPL TLPs.
  // Error is getting generated in case total number of requested 
  // byte counts does not match with received byte counts.
  /////////////////////////////////////////////////////////////
  always @(posedge core_clk or negedge core_rst_n) 
  begin: LUT_BYTE_CNT_PROCESS
    if (!core_rst_n) begin
      for(int i=0; i<CPL_LUT_FRAG_DEPTH; i=i+1) begin
        cpl_lut2[i]  <= #TP 0;
      end
    end else begin
      for(int i=0;i<N_XADM_RADM_TX_NPR_IF;i=i+1) begin
        if(int_update_lut_d[i]) begin
          cpl_lut2[req_addr_d[i]] <= #TP lutin2_d[i];
        end  
      end
      for(int i=0;i<N_RADM_CPL_TLP;i=i+1) begin
        if(update_lut_content_pipe[i]) begin
          cpl_lut2[update_lut_addr_pipe[i]] <= #TP update_lut_byte_cnt_pipe[i];
        end
      end
    end
  end
  ///////////////////////////////////////////////////////////
  // LUT Vec outputs based on the cpl tlp tag value.
  // One clock cycle early tag is getting used to pass flopped 
  // value to the tlp check module.
  //
  ///////////////////////////////////////////////////////////        
  always @(posedge core_clk or negedge core_rst_n) 
  begin : CPL_LUT_VECS
    if (!core_rst_n) begin
      cpl_lut_frag_vec2  <= #TP {N_RADM_CPL_TLP*CPL_ENTRY_WIDTH2{1'b0}};
      cpl_lut_frag_vec   <= #TP {N_RADM_CPL_TLP*CPL_ENTRY_WIDTH{1'b0}};
    end else begin
    for(int i=0;i<N_RADM_CPL_TLP;i=i+1) begin
    if(cpl_tlp_ant_tag[i] <CPL_LUT_FRAG_DEPTH) begin 
      cpl_lut_frag_vec2[i] <= #TP cpl_lut2[cpl_tlp_ant_tag[i]];
      cpl_lut_frag_vec[i]    <= #TP cpl_lut[cpl_tlp_ant_tag[i]];
    end else begin
      cpl_lut_frag_vec2[i] <= #TP '0;
      cpl_lut_frag_vec[i]    <= #TP '0;
    end
    end
  end
  end
  //////////////////////////////////////////////////////////
  // Ouptut of the NP TLP attributed for the CPL Timeout.
  //
  // Timer logic block uses this information to output the NP
  // TLP attributes to the application for which CPL Timeout 
  // has occured. 
  //////////////////////////////////////////////////////////
  delay_n
  
  #(1, (CPL_ENTRY_WIDTH + CPL_ENTRY_WIDTH2 + 1) ) u_timeout_lut_vec_delay(
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .din        ({cpl_lut[timeout_addr], cpl_lut2[timeout_addr], valid[timeout_addr]} ),
      .dout       ({cpl_lut_frag_error_vec ,cpl_lut_frag_error_vec2 ,cpl_lut_frag_error_valid})
  );
///////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////
  // Pertag Timer
  //
  ///////////////////////////////////////////////////////////////
  logic [CPL_LUT_FRAG_DEPTH-1:0][TIMEOUT_GRANULARITY-1:0]  pertag_timer;  // Timeout values
  
  always @(posedge core_clk or negedge core_rst_n)
  begin: TRANSACTION_TIMEOUT_PROCESS
    if (!core_rst_n) begin
      for (int i=0; i<CPL_LUT_FRAG_DEPTH; i=i+1)
        pertag_timer[i]     <= #TP 0;
    end else begin

    pertag_timer <= #TP pertag_timer;

    if (rstctl_core_flush_req) begin
      // Time out all pending NP requests
      if (valid[timeout_addr_reg]  &&  timeout_addr_reg_frag_sel) begin
        pertag_timer[timeout_addr_reg] <= # TP {TIMEOUT_GRANULARITY{1'b1}};
      end
    end else begin

        // timer timeout (per function) occurred
        if (valid[timeout_addr_reg] && timeout_addr_reg_frag_sel && get_map_onehot_func(timeout_pf, func_timeout) && timer_freq
        )
            pertag_timer[timeout_addr_reg] <= #TP  pertag_timer[timeout_addr_reg] + 1'b1;



        // completion timeout occured
        if (timeout_error)
            pertag_timer[timeout_addr_reg] <= #TP 0;

        // new entry
        for(int i=0;i<N_XADM_RADM_TX_NPR_IF;i=i+1) begin
          if (int_xtlh_xmt_tlp_done_d[i])
            pertag_timer[req_addr_d[i]] <= #TP 0;
        end    

      end
    end
  end

  delay_n
  
  #(1, TIMEOUT_GRANULARITY ) u_pertag_timer_value_delay(
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .din        (pertag_timer[timeout_addr] ),
      .dout       (cpl_lut_frag_pertag_timer_value)
  );
  //////////////////////////////////////////////////////////
  // Function to get PF number in FLR state
  //
  //////////////////////////////////////////////////////////
  
  
       function    automatic get_map_onehot_func;
       input [PF_WD-1:0] local_func;
       input [NF-1:0]      onehot_function;
       integer     i;
       begin
           get_map_onehot_func = 0;
           for (i=0;i<NF;i=i+1) begin
               if (local_func==i)
                   get_map_onehot_func = onehot_function[i];
           end
       end
       endfunction

endmodule
