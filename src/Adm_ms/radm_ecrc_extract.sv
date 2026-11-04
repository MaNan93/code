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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_ecrc_extract.sv#4 $
// -------------------------------------------------------------------------
// Description: 
// --- ECRC checking for 128b/256b/512b/1024b
// --- Extracts eCRC from recieved packet and sent it back 
// ---------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
 
module radm_ecrc_extract

  import DWC_pcie_ctl_pkg::NF;
  import radm_ms_pkg::NHW;
  import radm_ms_pkg::radm_rx_tlp_s;
  import radm_ms_pkg::HW;
  import radm_ms_pkg::radm_ord_mgr_flt_data_s;
  import radm_ms_pkg::radm_hdr_dec_flt_s;
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NW;
  import DWC_pcie_ctl_pkg::DW;


                          (
    input                          core_clk,
    input                          core_rst_n,
    input                          flit_mode,
    input                          halt_en,
    input radm_rx_tlp_s            rx_tlp,          // Received TLP struct, from OutQ/IDE, to filter
    input radm_hdr_dec_flt_s       hdr_dec_flt,
    input   [2:0]                  flt_total_prfx_cnt,        // Filter Header total (Local + End to END) prefix count
    input   [2:0]                  flt_local_prfx_cnt,        // Filter Header local prefix count
    input   [NF-1:0]               cfg_ecrc_chk_en,
    input                          ecrc_err_inj_enable,
    output                         pkt_eot_with_vld_td,
    
    output radm_ord_mgr_flt_data_s ecrc_rmvd_flt_data,
    output                         tlp_ecrc_match_err,
    output                         malform_ecrc_err,
    output radm_hdr_dec_flt_s      hdr_dec_flt_p
  );

logic cfg_ecrc_strip_en; // ECRC strip enabled
assign cfg_ecrc_strip_en = 1'b1;
    
wire strip_ecrc;

// Removing local prefix signals 
logic                         td;
logic                         td_nfm;         // TD bit in Non Flit Mode
logic [2:0]                   ts_fm;          // TS field in Flit Mode
logic [2:0]                   total_prfx_cnt;

logic                         flt_ddv_d;
logic                         flt_eot_d;
logic                         form_filt_ecrc_enable_d;
logic                         flt_ant_1dw_eot;
logic                         latched_td;
logic                         pkt_td_stat;
logic                         pkt_td_stat_d;
radm_ord_mgr_flt_data_s       flt_data_d;
radm_ord_mgr_flt_data_s       flt_data_d_int;

radm_hdr_dec_flt_s      hdr_dec_flt_int;

delay_n_w_enable


  #(.N(1), .WD($bits(radm_hdr_dec_flt_s)))
  u_delay_hdr_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (hdr_dec_flt.hdr_dec_flt_hv || rx_tlp.tlp.data.dv || flt_data_r.ord_flt_eot),
    .din        (hdr_dec_flt),
    .dout       (hdr_dec_flt_int)
);

always_comb begin : hdr_dec_flt_PROC
  hdr_dec_flt_p                = hdr_dec_flt_int;
  hdr_dec_flt_p.hdr_dec_flt_hv = (hdr_dec_flt.hdr_dec_flt_hv || rx_tlp.tlp.data.dv || flt_data_r.ord_flt_eot) ? hdr_dec_flt_int.hdr_dec_flt_hv : 1'b0;
end      


assign flt_ant_1dw_eot = strip_ecrc & rx_tlp.tlp.ctl.eot & (rx_tlp.tlp.data.dwen == {{NW-1{1'b0}}, 1'b1});



// one clk cycle delay to generate 1 DW EoT for eCRC stripping 
delay_n

 
  #(.N(1), .WD(4)) 
  u_delay_data_ctrl (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({pkt_td_stat, rx_tlp.ecrc_enable, rx_tlp.tlp.data.dv, rx_tlp.tlp.ctl.eot}),
    .dout       ({pkt_td_stat_d, form_filt_ecrc_enable_d, flt_ddv_d, flt_eot_d})
);


// TODO This is to keep the register formal equivalent  - to be removed !!!!!!!!!!!!!!!! ////////////
radm_ord_mgr_flt_data_s  flt_data_remap;
assign flt_data_remap.ord_flt_p_pkt_num              = rx_tlp.tlp.hdr.p_pkt_num  ;
assign flt_data_remap.ord_flt_dv                     = rx_tlp.tlp.data.dv        ;
assign flt_data_remap.ord_flt_dwen                   = rx_tlp.tlp.data.dwen      ;
assign flt_data_remap.ord_flt_data                   = rx_tlp.tlp.data.data      ;
assign flt_data_remap.ord_flt_eot                    = rx_tlp.tlp.ctl.eot        ;
assign flt_data_remap.ord_flt_dllp_err               = rx_tlp.tlp.ctl.dllp_err   ;
assign flt_data_remap.ord_flt_malformed_tlp_err      = rx_tlp.tlp.ctl.tlp_err    ;
assign flt_data_remap.ord_flt_poisoned               = rx_tlp.tlp.ctl.fm_poisoned;
///////////////////////////////////////////////////////////////////////////////////////////////////////

 radm_ord_mgr_flt_data_s  flt_data_r;

delay_n_w_enable


  #(.N(1), .WD($bits(radm_ord_mgr_flt_data_s))) 
  u_delay_w_enable_data (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         ((rx_tlp.tlp.data.dv | rx_tlp.tlp.ctl.eot | flt_data_r.ord_flt_eot)),
    .din        (flt_data_remap),
    .dout       (flt_data_r)
);

always_comb begin : data_block_PROC
  flt_data_d = flt_data_r;
  flt_data_d.ord_flt_dv  = (rx_tlp.tlp.data.dv | rx_tlp.tlp.ctl.eot | flt_data_r.ord_flt_eot) ? flt_data_r.ord_flt_dv  : 1'b0;
  flt_data_d.ord_flt_eot = (rx_tlp.tlp.data.dv | rx_tlp.tlp.ctl.eot | flt_data_r.ord_flt_eot) ? flt_data_r.ord_flt_eot : 1'b0;
end


always_comb begin : data_delay_proc
  flt_data_d_int             = flt_data_d;
  flt_data_d_int.ord_flt_dv  = flt_data_d.ord_flt_dv; //flt_ddv_d;
  flt_data_d_int.ord_flt_eot = flt_data_d.ord_flt_eot; //flt_eot_d;
end



// In Non-FLIT Mode - Header Packet -> <Local Prefix> <End to End Prefix> <Header DWs>
// In FLIT Mode - Header Packet -> <Local Prefix> <Header DWs> <End to End Prefix>
assign total_prfx_cnt = flit_mode ? flt_local_prfx_cnt : flt_total_prfx_cnt;

// Extract TD bit from header 
always_comb begin : extract_td_PROC
  td                    = 1'b0;
  td_nfm                = 1'b0;
  ts_fm                 = 1'b0;

  if (rx_tlp.tlp.hdr.hv) begin
    td_nfm = rx_tlp.tlp.hdr.hdr[total_prfx_cnt*32 + 23];
    ts_fm  = rx_tlp.tlp.hdr.hdr[total_prfx_cnt*32 + 21 +: 3];
    td     = flit_mode ? (ts_fm == 3'b001) : td_nfm;
  end

end

// Latching TD bit
always_ff @(posedge core_clk or negedge core_rst_n) begin : hdr_data_pipe_seq_PROC
  if (!core_rst_n) begin
    latched_td <= #TP 1'b0;
  end else begin
    if (rx_tlp.tlp.ctl.eot && (!halt_en)) begin 
        latched_td <= #TP 1'b0;
    end else begin
      if (rx_tlp.tlp.hdr.hv)
        latched_td <= #TP td;
    end
  end
end

// malform error when td bit is set but no data and ecrc (dv=0)
assign malform_ecrc_err = td && ~rx_tlp.tlp.data.dv && rx_tlp.tlp.ctl.eot; 

assign pkt_td_stat = (td | latched_td);
assign strip_ecrc  = cfg_ecrc_strip_en & pkt_td_stat_d;

wire anticipate_eot; // EOT must be anticipated 1 cycle earlier that the actual flag from the form_queue
assign anticipate_eot = flt_data_d_int.ord_flt_dv & strip_ecrc & flt_ant_1dw_eot & ~flt_data_d_int.ord_flt_eot & ~halt_en;

wire shift_eot;      // EOT must be shifted down 1 DW 
assign shift_eot = flt_data_d_int.ord_flt_eot & strip_ecrc;

logic anticipate_eot_d;
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        anticipate_eot_d <= #TP 1'b0;
    end else if (flt_data_d_int.ord_flt_eot && (!halt_en)) begin
        anticipate_eot_d <= #TP 1'b0;
    end else begin
        anticipate_eot_d <= #TP anticipate_eot;
    end
end


// Payload + EOT
assign ecrc_rmvd_flt_data.ord_flt_data       = flt_data_d_int.ord_flt_data; 

assign ecrc_rmvd_flt_data.ord_flt_eot        = (anticipate_eot_d)?     1'b0   : (anticipate_eot)? 1'b1 : flt_data_d_int.ord_flt_eot;
assign ecrc_rmvd_flt_data.ord_flt_dv         = (anticipate_eot_d)?     1'b0   : (shift_eot && (form_filt_ecrc_enable_d== 1'b0))  ? flt_data_d_int.ord_flt_dwen[1] : flt_data_d_int.ord_flt_dv;
assign ecrc_rmvd_flt_data.ord_flt_dwen       = (anticipate_eot_d)? {NW{1'b0}} : (shift_eot && (form_filt_ecrc_enable_d== 1'b0))  ? {1'b0, flt_data_d_int.ord_flt_dwen[NW-1:1]} : flt_data_d_int.ord_flt_dwen;
assign ecrc_rmvd_flt_data.ord_flt_dllp_err   = (anticipate_eot_d)?      1'b0  : (anticipate_eot)? rx_tlp.tlp.ctl.dllp_err : flt_data_d_int.ord_flt_dllp_err;
assign ecrc_rmvd_flt_data.ord_flt_p_pkt_num  = (anticipate_eot_d)?      1'b0  : (anticipate_eot)? rx_tlp.tlp.hdr.p_pkt_num : flt_data_d_int.ord_flt_p_pkt_num; 
assign ecrc_rmvd_flt_data.ord_flt_poisoned   = (anticipate_eot_d)?      1'b0  : (anticipate_eot)? rx_tlp.tlp.ctl.fm_poisoned : flt_data_d_int.ord_flt_poisoned; 
assign ecrc_rmvd_flt_data.ord_flt_malformed_tlp_err  = (anticipate_eot_d)? 1'b0  : (anticipate_eot)?  rx_tlp.tlp.ctl.tlp_err : flt_data_d_int.ord_flt_malformed_tlp_err; 

  logic           ecrc_hdr_valid;
  logic           ecrc_flt_data_valid;
  logic           ecrc_flt_eot;
  logic [NHW-1:0] lcl_prfx_rm_hdr_dwen;
  logic [NHW-1:0] ord_flt_hdr_wen_dft_tp;
  logic [HW-1:0]  lcl_prfx_rm_hdr;
  logic [HW-1:0]  flt_hdr_int;
  logic           flt_1dw_anticipate_eot; 
  
  logic [31:0]    form_ecrc_data_to_chkr;
  logic [DW-1:0]  ord_flt_data_to_chkr;
  
  // 2.7.1 ECRC Rules
  // all bits in variant fields must be set to 1b for ECRC
  // calculations.
  // * Bit 0 of the Type field is variant
  // * The EP bit is variant
  // * all other fields are invariant
  logic [HW-1:0] hdr_variant_bits;

  assign hdr_variant_bits = flit_mode ?  {{(HW-64){1'b0}}, 64'h0080000000000001} : {{(HW-32){1'b0}}, 32'h00400001};

  // Only compute ecrc when tlp digest is enabled, halt is disabled and eCRC check is enabled from CDM
  // Formation queue latches data and valid when halt is asserted and that data should not be part of ecrc computation
  assign ecrc_hdr_valid         = rx_tlp.tlp.hdr.hv & td & (~halt_en) & (|cfg_ecrc_chk_en);
  assign ecrc_flt_data_valid    = flt_data_d_int.ord_flt_dv & (pkt_td_stat_d) & (~halt_en) & (|cfg_ecrc_chk_en);
  assign ecrc_flt_eot           = flt_data_d_int.ord_flt_eot & (pkt_td_stat_d) & (~halt_en) & (|cfg_ecrc_chk_en);
  // EOT must be anticipated 1 cycle earlier that the actual flag from the form_queue
  assign flt_1dw_anticipate_eot = flt_data_d_int.ord_flt_dv & flt_ant_1dw_eot & ~flt_data_d_int.ord_flt_eot & ~halt_en;

// Header Alignment for eCRC calculation 
always_comb begin : ecrc_align_hdr_PROC
  lcl_prfx_rm_hdr       = 0;
  lcl_prfx_rm_hdr_dwen  = 0;
  flt_hdr_int           = 0;
  if (ecrc_hdr_valid) begin
    flt_hdr_int           = rx_tlp.tlp.hdr.hdr[HW-1:0] | (hdr_variant_bits << (32*total_prfx_cnt));
    lcl_prfx_rm_hdr       = flt_hdr_int >> (flt_local_prfx_cnt*32);
    lcl_prfx_rm_hdr_dwen  = rx_tlp.tlp.hdr.dwen >> flt_local_prfx_cnt;
  end
end
  
  // Adding DFT testpoint to close TA_09 violation
  delay_n_w_enable
  
  #( .N (1), .WD(NHW) ) 
  u_hdr_wen_dft_tp
  (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (rx_tlp.tlp.hdr.hv),
    .din        (rx_tlp.tlp.hdr.dwen),
    .dout       (ord_flt_hdr_wen_dft_tp)
  );

    assign ord_flt_data_to_chkr   = ecrc_err_inj_enable ? flip_ecrc_bit(flt_data_d_int.ord_flt_data[DW-1:0], flt_data_d_int.ord_flt_dwen) : flt_data_d_int.ord_flt_data[DW-1:0];
    assign form_ecrc_data_to_chkr = ecrc_err_inj_enable ? {rx_tlp.ecrc_data[31:1], ~rx_tlp.ecrc_data[0]} : rx_tlp.ecrc_data;

  radm_ecrc_check
  
    // Header to Data 1st stage pipeline is enabled 
    // Input pipeline is enabled for the module
    #(.HDR_DATA_PIPE (1), .CRC_LATENCY   (2))
    u_radm_ecrc_check (
      .core_clk               (core_clk                     ),
      .core_rst_n             (core_rst_n                   ),
      .flt_hdr                (lcl_prfx_rm_hdr              ), 
      .flt_hdr_dwen           (lcl_prfx_rm_hdr_dwen         ),
      .flt_hdr_hv             (ecrc_hdr_valid               ),
      .flt_data               (ord_flt_data_to_chkr         ), 
      .flt_ddwen              (flt_data_d_int.ord_flt_dwen  ),
      .flt_ddv                (ecrc_flt_data_valid          ),
      .flt_eot                (ecrc_flt_eot                 ),
      .flt_ant_1dw_eot        (flt_1dw_anticipate_eot       ),
      .form_filt_ecrc_data    (form_ecrc_data_to_chkr       ),
      .form_filt_ecrc_enable  (rx_tlp.ecrc_enable        ),
      .tlp_ecrc_match_err     (tlp_ecrc_match_err           ) 
    );
    

      assign pkt_eot_with_vld_td = ecrc_flt_eot;

// ------------------------- Function Declaration / Defination --------------------- //
function automatic [DW-1:0] flip_ecrc_bit (input [DW-1:0] data, input [NW-1:0] dwen);
  integer i;
  reg [$clog2(NW)-1:0] index;
  begin
    flip_ecrc_bit = data;
    if( dwen != 0 ) begin
      for (i=0; i<NW; i=i+1) begin
        if (dwen[i]) begin
          index = i;
        end
      end
      flip_ecrc_bit[32*index +: 32] = {data[32*index+1 +: 31], ~data[32*index +: 1]};
    end
  end
endfunction
// -------------------------End of Function Declaration / Defination --------------------- //

endmodule
