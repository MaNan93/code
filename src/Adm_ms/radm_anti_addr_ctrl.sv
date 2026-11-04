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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_anti_addr_ctrl.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/pcie_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_anti_addr_ctrl

  import radm_ms_pkg::HW_NFT;
  import radm_ms_pkg::HEW;
  import radm_ms_pkg::radm_ord_mgr_flt_data_s;
  import radm_ms_pkg::radm_hdr_dec_flt_s;
  import radm_ms_pkg::flt_in_s;
  import radm_ms_pkg::flt_cpl_lut_s;
  import pcie_pkg::mode_e;
  import pcie_pkg::tlp_hdr_pkt_s;
  import pcie_pkg::f_tlp_is_fm_p_rsvd;
  import pcie_pkg::f_tlp_is_fm_np_rsvd;

  import DWC_pcie_ctl_pkg::NPRFX;
    import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD ;

  import DWC_pcie_ctl_pkg::TAG_SIZE;

    import DWC_pcie_ctl_pkg::ANTI_CTRL_PIPE_DELAY; 


#(
) 

                            (

  // ---- inputs ---------------
  input                                                 core_clk,
  input                                                 radm_clk_ug,
  input                                                 core_rst_n,
  input                                                 flit_mode,
  input   radm_hdr_dec_flt_s                            hdr_dec_flt, 
  // end config
  input radm_ord_mgr_flt_data_s                         ord_flt_data,
  input                                                 rtlh_radm_parerr,
  input [NP_REQ_TX_TYPE_WD-1:0]                         lut_flt_np_req_type,          // NP request type from LUT for CPL Filter

   output radm_ord_mgr_flt_data_s                       ord_flt_data_in,
   output radm_hdr_dec_flt_s                            hdr_dec_flt_in,
   output logic  [63:0]                                 ant_extract_addr, 
   output logic                                         ant_extract_addr_valid, 
   output flt_cpl_lut_s                                 flt_cpl_lut,
   output logic                                         rtlh_radm_parerr_int,
   output logic  [15:0]                                 filt_ant_rid 
    
);
  
// ------------------------------ Signal declaration ------------------------------

logic  [63:0]         ant_extract_addr_int;
logic  [127:0]        flt_hdr_int; 
logic [HEW-1:0]       hdr_dw1_int;                    
logic [HEW-1:0]       hdr_dw2_int;
logic [HEW-1:0]       hdr_dw3_int;
logic [HEW-1:0]       hdr_dw4_int;
logic                 flt_adr_addr64;
logic [7:0]           flt_addr_byte0;
logic [7:0]           flt_addr_byte1;
logic [7:0]           flt_addr_byte2;
logic [7:0]           flt_addr_byte3;
logic [7:0]           flt_addr_byte4;
logic [7:0]           flt_addr_byte5;
logic [7:0]           flt_addr_byte6;
logic [7:0]           flt_addr_byte7;
logic [2:0]           tlp_ctrl_in;
logic [2:0]           tlp_ctrl_d;
logic [TAG_SIZE-1:0]  flt_cpl_lut_tag;
logic  [15:0]         filt_ant_rid_int; 

flt_in_s                            flt_in_s_gate;
flt_in_s                            flt_o_reg;


  assign tlp_ctrl_in      = ({hdr_dec_flt.hdr_dec_flt_hv,ord_flt_data.ord_flt_eot,ord_flt_data.ord_flt_dv});

  assign flt_hdr_int      = hdr_dec_flt.hdr_dec_flt_hdr[HW_NFT-1:0];

  assign  hdr_dw1_int         = flt_hdr_int[31:0];
  assign  hdr_dw2_int         = flt_hdr_int[63:32];
  assign  hdr_dw3_int         = flt_hdr_int[95:64];
  assign  hdr_dw4_int         = flt_hdr_int[127:96];

// Following logic to decode flit mode reserved 64bit addr TLP 
  logic [1:0]                 s_tlp_fmt;
  logic                       s_tlp_fmt2;
  logic [4:0]                 s_tlp_type;
  logic [2:0]                 s_tlp_fm_p_rsvd_info;
  logic [2:0]                 s_tlp_fm_np_rsvd_info;
  logic                       s_tlp_is_fm_rsvd_addr64;
  logic                       s_tlp_is_fm_p_rsvd_routed_by_addr;
  logic                       s_tlp_is_fm_np_rsvd_routed_by_addr;

  tlp_hdr_pkt_s               s_tlp_hdr_pkt;

  assign s_tlp_fmt            = hdr_dw1_int[6:5];
  assign s_tlp_fmt2           = hdr_dw1_int[7]; 
  assign s_tlp_type           = hdr_dw1_int[4:0];

  always_comb begin
    s_tlp_hdr_pkt = '0;
    s_tlp_hdr_pkt.tlp_fmt     = {s_tlp_fmt2,s_tlp_fmt};
    s_tlp_hdr_pkt.tlp_type    = s_tlp_type;
  end


  assign s_tlp_fm_p_rsvd_info = f_tlp_is_fm_p_rsvd(mode_e'(flit_mode), s_tlp_hdr_pkt);
  assign s_tlp_is_fm_p_rsvd_routed_by_addr = s_tlp_fm_p_rsvd_info[1] && s_tlp_fm_p_rsvd_info[2];

  assign s_tlp_fm_np_rsvd_info = f_tlp_is_fm_np_rsvd(mode_e'(flit_mode), s_tlp_hdr_pkt);
  assign s_tlp_is_fm_np_rsvd_routed_by_addr = s_tlp_fm_np_rsvd_info[1] && s_tlp_fm_np_rsvd_info[2];

   assign s_tlp_is_fm_rsvd_addr64 =  s_tlp_is_fm_p_rsvd_routed_by_addr || s_tlp_is_fm_np_rsvd_routed_by_addr;

  assign  flt_adr_addr64      = hdr_dw1_int[5] || s_tlp_is_fm_rsvd_addr64;

  assign  flt_addr_byte7      = (flt_adr_addr64) ? hdr_dw3_int[7:0]   : 8'h00;
  assign  flt_addr_byte6      = (flt_adr_addr64) ? hdr_dw3_int[15:8]  : 8'h00;
  assign  flt_addr_byte5      = (flt_adr_addr64) ? hdr_dw3_int[23:16] : 8'h00;
  assign  flt_addr_byte4      = (flt_adr_addr64) ? hdr_dw3_int[31:24] : 8'h00;
  assign  flt_addr_byte3      = (flt_adr_addr64) ? hdr_dw4_int[7:0]   : hdr_dw3_int[7:0];
  assign  flt_addr_byte2      = (flt_adr_addr64) ? hdr_dw4_int[15:8]  : hdr_dw3_int[15:8];
  assign  flt_addr_byte1      = (flt_adr_addr64) ? hdr_dw4_int[23:16] : hdr_dw3_int[23:16];
  assign  flt_addr_byte0      = (flt_adr_addr64) ? hdr_dw4_int[31:24] : hdr_dw3_int[31:24];

  assign ant_extract_addr_int = {flt_addr_byte7, flt_addr_byte6, flt_addr_byte5, flt_addr_byte4,
                                  flt_addr_byte3, flt_addr_byte2, flt_addr_byte1, flt_addr_byte0};
  assign filt_ant_rid_int     = {hdr_dw3_int[7:0], hdr_dw3_int[15:8]};

  // Anticipated RID
  delay_n_w_enable
  
  #(  .N        (0), 
      .WD       ($bits(filt_ant_rid))
  ) u_delay_ant_rid
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (hdr_dec_flt.hdr_dec_flt_hv),
    .din        (filt_ant_rid_int),
    .dout       (filt_ant_rid)
  );

  // Anticipated Address going to CDM
  delay_n_w_enable
  
  #(  .N        (1), 
      .WD       ($bits(ant_extract_addr_int))
  ) u_delay_ant_addr
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (hdr_dec_flt.hdr_dec_flt_hv),
    .din        (ant_extract_addr_int),
    .dout       (ant_extract_addr)
  );

  delay_n
  
  #(  .N        (1), 
      .WD       (1)
  ) u_delay_ant_addr_vld
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (hdr_dec_flt.hdr_dec_flt_hv),
    .dout       (ant_extract_addr_valid)
  );



assign flt_cpl_lut.flt_cpl_lut_hv       =  hdr_dec_flt_in.hdr_dec_flt_hv;
assign flt_cpl_lut.flt_cpl_lut_hdr      =  hdr_dec_flt_in.hdr_dec_flt_hdr[HW_NFT-1:0]; 
assign flt_cpl_lut.flt_cpl_lut_eot      =  ord_flt_data_in.ord_flt_eot; 
assign flt_cpl_lut.flt_cpl_lut_dllp_err =  ord_flt_data_in.ord_flt_dllp_err; 
assign flt_cpl_lut.flt_cpl_lut_rid      =  filt_ant_rid;
// Note: Upper 4 bits are sending seperate to filter as NFT header has only 10 bits for TAG. 
// For CPL_LUT, to compare TAG it is required all 14 bit tag.
assign  flt_cpl_lut.flt_cpl_lut_uppr_4bit_tag  = hdr_dec_flt_in.hdr_dec_flt_c_d_r_14bit_t[13:10];





always_comb  begin  
  flt_in_s_gate                                 = 'd0;
        
  flt_in_s_gate.rtlh_flt_parerr                 = rtlh_radm_parerr;
  flt_in_s_gate.flt_in_data                     = ord_flt_data;
  flt_in_s_gate.flt_in_hdr                      = hdr_dec_flt;
  flt_in_s_gate.flt_in_hdr.hdr_dec_flt_hv       = 1'b0;
  flt_in_s_gate.flt_in_data.ord_flt_eot         = 1'b0;
  flt_in_s_gate.flt_in_data.ord_flt_dv          = 1'b0;
  flt_in_s_gate.flt_in_hdr.hdr_dec_np_req_type  = 'd0;
end
  
  delay_n
  
  #(  .N        (ANTI_CTRL_PIPE_DELAY), 
      .WD       (1)
  ) u_hv_delay
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (tlp_ctrl_in[2]),
    .dout       (tlp_ctrl_d[2])
    );

  delay_n_w_enable
  
  #(  .N        (ANTI_CTRL_PIPE_DELAY), 
      .WD       ($bits(radm_hdr_dec_flt_s)) 
  ) u_hdr_delay_en
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (tlp_ctrl_in[2]),
    .din        (flt_in_s_gate.flt_in_hdr),
    .dout       (flt_o_reg.flt_in_hdr)
    );

  delay_n_w_enable
  
  #(  .N        (ANTI_CTRL_PIPE_DELAY), 
      .WD       (1) 
  ) u_ide_delay_en
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (1'b1),
    .din        (flt_in_s_gate.rtlh_flt_parerr),
    .dout       (flt_o_reg.rtlh_flt_parerr)
    );

  delay_n
  
  #(  .N        (ANTI_CTRL_PIPE_DELAY), 
      .WD       (2)
  ) u_dv_eot_delay
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (tlp_ctrl_in[1:0]),
    .dout       (tlp_ctrl_d[1:0])
    );

  delay_n_w_enable
  
  #(  .N        (ANTI_CTRL_PIPE_DELAY), 
      .WD       ($bits(radm_ord_mgr_flt_data_s)) 
  ) u_data_delay_en
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         ((|tlp_ctrl_in[1:0])),
    .din        (flt_in_s_gate.flt_in_data),
    .dout       (flt_o_reg.flt_in_data)
    );

  // One cycle early information for CPL LUT 
  delay_n_w_enable
  
  #(  .N        (ANTI_CTRL_PIPE_DELAY-1), 
      .WD       ($bits(flt_cpl_lut_tag)) 
  ) u_delay_lut_tag
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (hdr_dec_flt.hdr_dec_flt_hv),
    .din        (flt_cpl_lut_tag),
    .dout       (flt_cpl_lut.flt_cpl_lut_tag)
  );

   assign flt_cpl_lut_tag           = flit_mode ? flt_in_s_gate.flt_in_hdr.hdr_dec_flt_c_d_r_14bit_t[13:0] : {4'h0,hdr_dw1_int[15],hdr_dw1_int[11],hdr_dw3_int[23:16]} ;

always_comb  begin 
  ord_flt_data_in = 'd0;
  hdr_dec_flt_in  = 'd0;

  rtlh_radm_parerr_int               = flt_o_reg.rtlh_flt_parerr;
  ord_flt_data_in                    = flt_o_reg.flt_in_data;
  hdr_dec_flt_in                     = flt_o_reg.flt_in_hdr;
  ord_flt_data_in.ord_flt_eot        = tlp_ctrl_d[1];
  ord_flt_data_in.ord_flt_dv         = tlp_ctrl_d[0];
  hdr_dec_flt_in.hdr_dec_flt_hv      = tlp_ctrl_d[2];
  // No need to pipeline this signal, as CPL LUT output is aligned to HDR pipeline stage
  hdr_dec_flt_in.hdr_dec_np_req_type = lut_flt_np_req_type; //hdr_dec_flt.hdr_dec_np_req_type;
end

endmodule
