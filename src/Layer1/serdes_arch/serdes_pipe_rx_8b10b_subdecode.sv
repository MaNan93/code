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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_8b10b_subdecode.sv#4 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side 8b/10b decode sub module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_8b10b_subdecode

  import serdes_pipe_pkg::*;
(
  // ------------- input -----------------
  input logic [SYM_10B_WD-1:0]  data_in,
  input logic                   disp_in,
  // ------------- output ----------------
  output logic [SYM_8B_WD-1:0]  data_out,
  output logic                  datak_out,
  output logic                  disp_out,
  output logic                  err_code,
  output logic                  err_disp
);

  // Split incoming data into 6-bit and 4-bit chunks. By convention,
  // the most-significant six bits are labeled abcdei and the bottom
  // four bits are labeled fghj.
  logic [5:0]  data_10b_abcdei;
  logic [3:0]  data_10b_fghj;
  assign data_10b_abcdei = data_in[9:4];
  assign data_10b_fghj = data_in[3:0];

  // Generate some enables (per the Widmer/Franaszek paper) from the
  // abcdei data.  These terms will be used to perform specific
  // translations on the incoming data stream.  Where W & F used
  // names like "P22", we'll use lower case (e.g. "p22").
  logic  p_13, p_22, p_31;
  assign p_13 = (data_10b_abcdei[5:2] inside {4'b0001, 4'b0010, 4'b0100, 4'b1000});
  assign p_22 = (data_10b_abcdei[5:2] inside {4'b0011, 4'b0101, 4'b0110, 4'b1001, 4'b1010, 4'b1100});
  assign p_31 = (data_10b_abcdei[5:2] inside {4'b1110, 4'b1101, 4'b1011, 4'b0111});

  logic  a_in, b_in, c_in, d_in, e_in, i_in;
  logic  e_eq_i;
  assign {a_in, b_in, c_in, d_in, e_in, i_in} = data_10b_abcdei;
  assign e_eq_i = (e_in == i_in);

  // The "typical" encoding from abcdei->ABCDE is simply to copy the
  // original bits and drop the i bit on the floor.  Generate that
  // value here and we'll modify it as necessary.
  logic [4:0]  data_8b_abcde_pre;
  assign data_8b_abcde_pre =  data_10b_abcdei[5:1];

  // Generate a set of bits to be flipped based on the 6b/5b input controls
  logic [4:0]  compl_8b_abcde;

  always_comb begin: compl_8b_abcde_PROC
    logic  l_compl_8b_abcde;
    l_compl_8b_abcde = (data_10b_abcdei == 6'b000111) || (data_10b_abcdei[3:0] == 4'b0000) || (p_13 && !e_in);
    compl_8b_abcde = {  // Bit 'A'
                      (((data_10b_abcdei[5:2] inside {4'b1001, 4'b0101}) && e_eq_i) ||
                      (p_31 && i_in) || (a_in && b_in && e_in && i_in) || l_compl_8b_abcde),
                        // Bit 'B'
                      (((data_10b_abcdei[5:2] inside {4'b0110, 4'b1010}) && e_eq_i) ||
                      (p_31 && i_in) || (a_in && b_in && e_in && i_in) || l_compl_8b_abcde),
                        // Bit 'C'
                      (((data_10b_abcdei[5:2] inside {4'b0110, 4'b0101}) && e_eq_i) ||
                      (p_31 && i_in) || (!a_in && !b_in && !e_in && !i_in) || l_compl_8b_abcde),
                        // Bit 'D'
                      (((data_10b_abcdei[5:2] inside {4'b1001, 4'b1010}) && e_eq_i) ||
                      (p_31 && i_in) || (a_in && b_in && e_in && i_in) || l_compl_8b_abcde),
                        // Bit 'E'
                      (((data_10b_abcdei[5:2] inside {4'b1001, 4'b0101}) && e_eq_i) ||
                      (p_13 && !i_in) || (!a_in && !b_in && !e_in && !i_in) || l_compl_8b_abcde)};
  end

  // Generate the output of the 6b/5b decoding table
  logic [4:0]  data_8b_abcde;
  assign data_8b_abcde = data_8b_abcde_pre ^ compl_8b_abcde;

  // Generate some terms which indicate the disparity of the received 6b data
  logic  disp_6b_neg, disp_6b_pos;
  logic  disp_6b_err_if_rd_neg, disp_6b_err_if_rd_pos;
  assign disp_6b_neg = (p_22 && !e_in && !i_in) || (p_13 && !i_in) || (p_13 && !e_in);
  assign disp_6b_pos = (p_22 && e_in && i_in) || (p_31 && i_in) || (p_31 && e_in);
  assign disp_6b_err_if_rd_neg = disp_6b_neg || (data_10b_abcdei == 6'b000111);
  assign disp_6b_err_if_rd_pos = disp_6b_pos || (data_10b_abcdei == 6'b111000);

  // Calculate disparity error as well as post-6b/5b disparity
  logic  disp_6b_err;
  logic  disp_post_5b;
  assign disp_6b_err = (disp_in) ? disp_6b_err_if_rd_pos : disp_6b_err_if_rd_neg;
  assign disp_post_5b = (disp_6b_err) ? (disp_6b_pos || (data_10b_abcdei == 6'b000111)) :
                                        (disp_in ^ (disp_6b_neg || disp_6b_pos));

  // 4b/3b decoder
  // Generate some controls which are specific to the 3b/4b portion of the encoder
  logic  f_in, g_in, h_in, j_in;
  assign {f_in, g_in, h_in, j_in} = data_10b_fghj;


  // The "typical" encoding from fghj->FGH is simply to copy the fgh bits and throw
  // away the 'i'.  Generate that value here and we'll modify it as necessary.
  logic [2:0]  data_8b_fgh_pre;
  assign data_8b_fgh_pre = data_10b_fghj[3:1];

  logic [2:0]  compl_8b_fgh;

  always_comb begin: compl_8b_fgh_PROC
    // Generate a set of bits to be flipped to one based on the 3b/4b input controls
    logic  flip_fgh;
    flip_fgh = (!c_in && !d_in && !e_in && !i_in && (h_in != j_in)) ||
               (data_10b_fghj == 4'b0011) || (f_in && g_in && j_in) || (!f_in && !g_in && !h_in);
    compl_8b_fgh = {  // Bit 'F'
                    ((f_in && h_in && j_in) || flip_fgh || (g_in && h_in && j_in)),
                      // Bit 'G'
                    ((!f_in && !h_in && !j_in) || flip_fgh || (!g_in && !h_in && !j_in)),
                      // Bit 'H'
                    ((f_in && h_in && j_in) || flip_fgh || (!g_in && !h_in && !j_in))};
  end

  // Generate the output of the 4b/3b decoding table
  logic [2:0]  data_8b_fgh;
  assign data_8b_fgh = data_8b_fgh_pre ^ compl_8b_fgh;

  // Generate some terms which indicate the disparity of the received 4b data
  logic  disp_4b_neg, disp_4b_pos;
  logic  disp_4b_err_if_rd_neg, disp_4b_err_if_rd_pos;
  assign disp_4b_neg = (!f_in && !h_in && !j_in) || (!f_in && !g_in && !j_in) ||
                       (!f_in && !g_in && !h_in) || (!g_in && !h_in && !j_in);
  assign disp_4b_pos = (f_in && h_in && j_in) || (f_in && g_in && j_in) ||
                       (f_in && g_in && h_in) || (g_in && h_in && j_in);
  assign disp_4b_err_if_rd_neg = disp_4b_neg || (data_10b_fghj == 4'b0011);
  assign disp_4b_err_if_rd_pos = disp_4b_pos || (data_10b_fghj == 4'b1100);

  // Calculate disparity error as well as post-6b/5b disparity
  logic  disp_4b_err;
  logic  disp_post_3b;
  assign disp_4b_err = (disp_post_5b) ? disp_4b_err_if_rd_pos : disp_4b_err_if_rd_neg;
  assign disp_post_3b = (disp_4b_err) ? (disp_4b_pos || (data_10b_fghj == 4'b0011)) :
                                        (disp_post_5b ^ (disp_4b_neg || disp_4b_pos));

  // Calculate coding errors
  logic  ghj_equiv;
  assign ghj_equiv = (g_in == h_in) && (h_in == j_in);
  assign err_code = (data_10b_abcdei[5:2] inside {4'b1111, 4'b0000}) ||
                    (p_13 && !e_in && !i_in) || (p_31 && e_in && i_in) ||
                    (data_10b_fghj inside {4'b1111, 4'b0000}) ||
                    (disp_6b_pos && (data_10b_fghj == 4'b1100)) ||
                    (disp_6b_neg && (data_10b_fghj == 4'b0011)) ||
                    (disp_4b_err_if_rd_pos && (data_10b_abcdei == 6'b000111)) ||
                    (disp_4b_err_if_rd_neg && (data_10b_abcdei == 6'b111000)) ||
                    (c_in && d_in && e_in && i_in && !f_in && !g_in && !h_in) ||
                    (!c_in && !d_in && !e_in && !i_in && f_in && g_in && h_in) ||
                    (e_eq_i && (e_in == f_in) && (e_in == g_in) && (e_in ==h_in)) ||
                    (!e_eq_i && (e_in == g_in) && ghj_equiv) ||
                    (e_eq_i && (e_in != g_in) && ghj_equiv && !((c_in == d_in) && (d_in == e_in))) ||
                    (!p_31 && e_in && !i_in && !g_in && !h_in && !j_in) ||
                    (!p_13 && !e_in && i_in && g_in && h_in && j_in) ||
                    (disp_6b_neg && disp_4b_neg) || (disp_6b_pos && disp_4b_pos);

  // Generate final outputs
  // Swizzle data around from ABCDE/FGH to HGFEDCBA
  assign data_out = {<< {data_8b_abcde, data_8b_fgh}};
  assign datak_out = (!c_in && !d_in && !e_in && !i_in) || (c_in && d_in && e_in && i_in) ||
                     (p_13 && !e_in && i_in && g_in && h_in && j_in) ||
                     (p_31 && e_in && !i_in && !g_in && !h_in && !j_in);
  assign err_disp = disp_6b_err || disp_4b_err;
  assign disp_out = disp_post_3b;

endmodule: serdes_pipe_rx_8b10b_subdecode
