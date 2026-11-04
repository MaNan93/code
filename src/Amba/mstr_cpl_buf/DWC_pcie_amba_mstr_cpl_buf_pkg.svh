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
// ---    $Revision: #2 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_buf_pkg.svh#2 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_AMBA_MSTR_CPL_BUF_PKG__SVH__
`define __GUARD__DWC_PCIE_AMBA_MSTR_CPL_BUF_PKG__SVH__

package DWC_pcie_amba_mstr_cpl_buf_pkg;

  // Cut extraneous 0s from CX_NFUNC_WD vectors
  localparam K_NFWD = (`CX_NFUNC == 1) ? 1 : $clog2(`CX_NFUNC);

  localparam K_CPL_FMT   = 2'b00;
  localparam K_CPL_TYPE  = 5'b01010;

  localparam K_CPLD_FMT  = 2'b10;
  localparam K_CPLD_TYPE = 5'b01010;


  typedef enum logic {
    ST_WR_CPL_IDLE  = 1'b0
   ,ST_WR_MORE_DATA = 1'b1
  } kWrState_e;

  typedef enum logic {
    ST_RD_CPL_IDLE       = 1'b0
   ,ST_RD_CPL_MULTI_BEAT = 1'b1
  } kRdState_e;

  // Function to calculate the split completion length in DWORD's.
  // -----------------------------------------------------------------------------------
  function automatic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] fn_split_cpl_dw_len;
    // DW aligned max read request address
    input [`DC_MCB_MAX_CPL_NUM_DWORDS_WD-2:0] ireq_np_4kb_addr_dw_algnd;
    // Max payload size in DWORDs
    input [`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] cpl_max_payload_size_dw;
    // Completion DWORD length
    input [`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] cpl_dw_len;

    begin : func_split_cpl_dw_len
      reg [`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] num_dwords2max_mreq_np_bndry;
      reg [`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] num_dwords2max_pyld_bndry;

      num_dwords2max_mreq_np_bndry = `DC_MCB_MAX_CPL_NUM_DWORDS-ireq_np_4kb_addr_dw_algnd;
      num_dwords2max_pyld_bndry =
               |(num_dwords2max_mreq_np_bndry & (cpl_max_payload_size_dw-1)) ?
                (num_dwords2max_mreq_np_bndry & (cpl_max_payload_size_dw-1)) :
                cpl_max_payload_size_dw;

      if (cpl_dw_len <= cpl_max_payload_size_dw) begin
        // Remaining number of completion DWORDs to transfer is less than or equal to the max payload size.
        fn_split_cpl_dw_len = cpl_dw_len;
      end else begin
        fn_split_cpl_dw_len = num_dwords2max_pyld_bndry;
      end

    end
  endfunction

  // Function to decode the physical function Max_Payload_Size
  // -------------------------------------------------------------------------------------
  function automatic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] fn_max_payload_size_dw;
    input logic [K_NFWD -1:0] pf_num;
    input logic [`CX_NFUNC-1:0][`DC_MAX_PYLD_SIZE_ENC_WD-1:0] cfg_max_payload_size;

    begin : func_max_payload_size_dw
      logic [`DC_MAX_PYLD_SIZE_ENC_WD-1:0] pf_num_max_payload_size;
      // Extract Max_Payload_Size per function
      pf_num_max_payload_size = cfg_max_payload_size[pf_num];

      // Translate encoded Max_Payload_Size to DWORD's
      fn_max_payload_size_dw = 'd32; // default value
      case (pf_num_max_payload_size)
        // ccx_line_begin: ; REDUNDANT_CONFIG_ONLY, MAX MTU
       `DC_MAX_PYLD_SIZE_128_BYTES_ENC  :  fn_max_payload_size_dw = 'd32;
       `DC_MAX_PYLD_SIZE_256_BYTES_ENC  :  fn_max_payload_size_dw = 'd64;
       `DC_MAX_PYLD_SIZE_512_BYTES_ENC  :  fn_max_payload_size_dw = 'd128;
       `DC_MAX_PYLD_SIZE_1024_BYTES_ENC :  fn_max_payload_size_dw = 'd256;
       `DC_MAX_PYLD_SIZE_2048_BYTES_ENC :  fn_max_payload_size_dw = 'd512;
       `DC_MAX_PYLD_SIZE_4096_BYTES_ENC :  fn_max_payload_size_dw = 'd1024;
        // ccx_line_end
      endcase
    end
  endfunction

  // Function to convert the DWORD length to beats
  // Number of beats depends on the length and the data width address offset.
  // -----------------------------------------------------------------------------------
  function automatic [`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] fn_split_cpl_dw2beat_len;
    input [`DC_MCB_MAX_CPL_NUM_DWORDS_WD-2:0] ireq_np_4kb_addr_dw_algnd;
    input [`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] split_cpl_dw_len;

    begin : func_split_cpl_dw2beat_len
      reg [`DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] padded_split_cpl_dw_len;
      // Add the first beat DWORD address offset to the DWORD length
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
      padded_split_cpl_dw_len = split_cpl_dw_len +
                                ireq_np_4kb_addr_dw_algnd[`CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2-1:0];
      // spyglass enable_block W164a
      if (|padded_split_cpl_dw_len[`CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2-1:0]) begin
        // If the address is offset from the data width boundary then
        // divide the padded DWORD length by the number of DWORDS per beat
        // and add 1 to give the total number of data beats.
        fn_split_cpl_dw2beat_len = (`DC_MCB_MAX_CPL_NUM_DWORDS_WD)'((padded_split_cpl_dw_len >> `CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2)+1);
      end else begin
        // If address is aligned to data width boundary then divide the
        // DWORD length by the number of DWORDS per beat.
        fn_split_cpl_dw2beat_len = (`DC_MCB_MAX_CPL_NUM_DWORDS_WD)'(padded_split_cpl_dw_len >> `CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2);
      end
    end
  endfunction

endpackage : DWC_pcie_amba_mstr_cpl_buf_pkg

`endif // __GUARD__DWC_PCIE_AMBA_MSTR_CPL_BUF_PKG__SVH__

