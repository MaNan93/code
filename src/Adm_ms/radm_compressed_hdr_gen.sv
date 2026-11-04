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
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_compressed_hdr_gen.sv#1 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// generating compressed hdr fields to send to trgt1 interface 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module radm_compressed_hdr_gen
  
///////////////////////////////////////// 
//import radm_ms_pkg starts
import radm_ms_pkg::TRGT1_ADDR_WD;
import radm_ms_pkg::FLT_Q_ADDR_WIDTH;
import radm_ms_pkg::flt_p_hdr_o_s;
import radm_ms_pkg::flt_np_hdr_o_s;
import radm_ms_pkg::flt_cpl_hdr_o_s;
import radm_ms_pkg::radm_cfg_i_s;
import radm_ms_pkg::radm_tlp_hdr_s;
import radm_ms_pkg::hdr_fmt;
import radm_ms_pkg::hdr_destination;
import radm_ms_pkg::compressed_hdr_gen_ctl_s;
import radm_ms_pkg::radm_hdr_log_rcvd_flds_s;
import radm_ms_pkg::little_end_addr;
import radm_ms_pkg::f_tlp_addr_tph;
//import radm_ms_pkg ends
//////////////////////////////////////////

//////////////////////////////////////////
//import DWC_pcie_ctl_pkg starts
import DWC_pcie_ctl_pkg::PRFX_W_PAR;
//import DWC_pcie_ctl_pkg ends
/////////////////////////////////////

///////////////////////////////////
//import pcie_pkg starts
import pcie_pkg::tlp_hdr_pkt_s;
import pcie_pkg::f_tlp_hdr_extract;
import pcie_pkg::mode_e;
import pcie_pkg::E_NFM;
import pcie_pkg::fc_type_e;
import pcie_pkg::E_P;
import pcie_pkg::E_NP;
import pcie_pkg::E_CPL;
//import pcie_pkg ends
///////////////////////////////////

#(
  parameter type COMPRESSED_HDR_TYPE = flt_p_hdr_o_s,
  parameter fc_type_e FC_TYPE  = E_P
)


                              (
  // Input/Output Declaration
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                                       core_clk,               // PCIE core clock
  input                                       radm_clk_ug,            // PCIE core clock ungated
  input                                       core_rst_n,             // PCIE active low asynchronous reset
  input                                       flit_mode,
  // -------------------------------------------------------------------------------------
  // Input/Output Declaration 
  // -------------------------------------------------------------------------------------
  input  radm_cfg_i_s                         radm_cfg_i,
  input  radm_tlp_hdr_s                       rx_tlp_hdr,            // raw header from OutQ/IDE (this will be used instead of radm_trgt1_hdr_dmux)
  input  compressed_hdr_gen_ctl_s             compressed_hdr_flds,   // signals used to generate compressed hdr
  input  radm_hdr_log_rcvd_flds_s             log_rcvd_flds,
  input  [PRFX_W_PAR-1:0]                     tlp_prfx,
  output COMPRESSED_HDR_TYPE                  compressed_hdr
);

// configuaring mode
    mode_e MODE;
    assign MODE = mode_e'(flit_mode);

// signals used in compressed hdr generation
    tlp_hdr_pkt_s                       tlp_hdr_extract; // extracted hdr from hdr decoding function
    logic [3:0]                         tlpmsg;
    logic                               addr64;
    logic [63:0]                        tlp_addr;
    logic [63:0]                        tlp_addr_tph;
    logic [7:0]                         tlp_addr_byte0;
    logic [3:0]                         tlp_addr_byte0_i;
    logic [63:0]                        obff_addr;
    logic                               obff_cpu_active;
    logic [3:0]                         tlp_obff_code;
    logic                               tlp_obff_msg;
    logic [TRGT1_ADDR_WD-1:0]           tlp_hdr_uppr_bytes;
    logic                               cpl_status_sc;
    logic                               cpl_status_ca;
    logic                               cpl_status_crs;
    logic                               cpl_status_ur;
    logic                               reserved_cpl_status;
    logic [15:0] [31:0]                 raw_tlp_hdr;
    logic [7:0]  [31:0]                 raw_tlp_prfx;

  // ---------------------------------- Signal declaration ends ----------------------------------

  assign raw_tlp_hdr = {{(512-(`CX_RX_HDW_MS*32)){1'b0}}, rx_tlp_hdr.header};
  assign raw_tlp_prfx = {{(256-(`CX_NPRFX*32)){1'b0}}, rx_tlp_hdr.prfx};
  // hdr extraction
  assign tlp_hdr_extract = f_tlp_hdr_extract(MODE, raw_tlp_prfx, raw_tlp_hdr);
  assign addr64          = tlp_hdr_extract.tlp_fmt[0];

generate
  if (FC_TYPE == E_P) begin: OBFF_and_hdr_upper_bytes_P

      // local param values for obff code
      localparam IDLE         = 4'b0000;
      localparam OBFF         = 4'b0001;
      localparam CPU_ACTIVE   = 4'b1111;

      assign tlpmsg          = {tlp_hdr_extract.tlp_fmt[1:0], tlp_hdr_extract.tlp_type[4:3]}; // tlp_hdr_dw[6:3]

      assign  tlp_obff_msg    = ((tlp_hdr_extract.tlp_msg_code == `OBFF)  && (tlp_hdr_extract.tlp_type[2:0] == 3'b100) && (tlpmsg == `MSG_4));
      assign  tlp_addr_byte0  = tlp_hdr_extract.tlp_addr[7:0];
        // An obff message where the obff_code is anything other than IDLE or OBFF is treated as CPU_ACTIVE.
        assign tlp_obff_code  = tlp_addr_byte0[3:0];
        assign obff_cpu_active  = rx_tlp_hdr.hv && tlp_obff_msg && (tlp_obff_code != IDLE) && (tlp_obff_code != OBFF);

        always_comb begin : proc_comb_obff_code
          // Initialize
          tlp_addr_byte0_i   = tlp_addr_byte0[3:0];

          if (obff_cpu_active) begin
            tlp_addr_byte0_i = CPU_ACTIVE;
          end
        end
        assign obff_addr      = {tlp_hdr_extract.tlp_addr[63:4], tlp_addr_byte0_i};
        assign tlp_addr         = obff_cpu_active ? obff_addr : tlp_hdr_extract.tlp_addr;
        
      // handling endians
      logic [63:0]   conv_addr;
      assign conv_addr = little_end_addr(tlp_hdr_extract.tlp_addr);

      // generating upper hdr bytes
      always_comb begin  : uppr_bytes_proc 
        tlp_hdr_uppr_bytes = '0;
            tlp_hdr_uppr_bytes = (addr64) ? {conv_addr[31:0], conv_addr[63:32]} : {32'b0, conv_addr[31:0]};
      end
      
      assign tlp_addr_tph    = f_tlp_addr_tph(tlp_hdr_extract.tlp_th,tlp_addr,flit_mode,tlp_hdr_extract.tlp_at);

  end else if (FC_TYPE == E_NP) begin: extract_address_for_NP
    assign tlp_addr = tlp_hdr_extract.tlp_addr;
    assign tlp_addr_tph  = f_tlp_addr_tph(tlp_hdr_extract.tlp_th,tlp_addr,flit_mode,tlp_hdr_extract.tlp_at);

  end else if (FC_TYPE == E_CPL) begin: cpl_status
    assign  cpl_status_sc  = (tlp_hdr_extract.tlp_cpl_status == `SU_CPL_STATUS);    // Successful  Completion
    assign  cpl_status_ca  = (tlp_hdr_extract.tlp_cpl_status == `CA_CPL_STATUS);    // Completion  Abort
    assign  cpl_status_crs = (tlp_hdr_extract.tlp_cpl_status == `CRS_CPL_STATUS);   // Request Retry Status
    assign  cpl_status_ur  = (tlp_hdr_extract.tlp_cpl_status == `UR_CPL_STATUS);    // unsupported request
    assign  reserved_cpl_status = !(cpl_status_sc  || cpl_status_ur || cpl_status_ca  || cpl_status_crs);
  end
endgenerate 

assign compressed_hdr.flt_q_hdr.flt_q_fmt          = hdr_fmt'(tlp_hdr_extract.tlp_fmt[1:0]);   // 2-bit format field     
assign compressed_hdr.flt_q_hdr.flt_q_tc           = tlp_hdr_extract.tlp_tc;
  assign compressed_hdr.flt_q_hdr.flt_q_td         = radm_cfg_i.cfg_filter_rule_mask[`CX_FLT_UNMASK_TD] ? tlp_hdr_extract.tlp_td : 1'b0;
  assign compressed_hdr.flt_q_hdr.flt_q_td_hdr_log = tlp_hdr_extract.tlp_td;
assign compressed_hdr.flt_q_hdr.flt_q_poisoned     = tlp_hdr_extract.tlp_ep;
assign compressed_hdr.flt_q_hdr.flt_q_attr         = tlp_hdr_extract.tlp_attr[`FLT_Q_ATTR_WIDTH-1:0];
assign compressed_hdr.flt_q_hdr.flt_q_dw_len       = tlp_hdr_extract.tlp_len;               
assign compressed_hdr.flt_q_hdr.flt_q_REQID        = tlp_hdr_extract.tlp_req_id;
assign compressed_hdr.flt_q_hdr.flt_q_TAG          = tlp_hdr_extract.tlp_tag;
assign compressed_hdr.flt_q_hdr.flt_q_func_nmbr    = compressed_hdr_flds.func_num_c;
assign compressed_hdr.flt_q_hdr.flt_pkt_num        = rx_tlp_hdr.p_pkt_num;
assign compressed_hdr.flt_q_hdr.flt_q_fmt2         = tlp_hdr_extract.tlp_fmt[2]; // second [2] bit of FMT field used to detect reserved TLP in FLIT mode
assign compressed_hdr.flt_q_hdr.flt_q_destination  = hdr_destination'(compressed_hdr_flds.destination); 
  assign compressed_hdr.flt_q_hdr.hdr_dec_flt_dest_seg   = {tlp_hdr_extract.tlp_dsv, tlp_hdr_extract.tlp_dst_seg};
  assign compressed_hdr.log_rcvd_flds              = log_rcvd_flds;
  assign compressed_hdr.flt_q_prfx                 = tlp_prfx;
        

// P,NP,CPL undriven
  assign compressed_hdr.flt_hdr_prot = '0;
assign compressed_hdr.flt_q_hv = '0;
        
         // Q DEMUX control
  // compressed hdr generation for each FC type
  generate
    if (FC_TYPE == E_CPL) begin: CPL_compressed_hdr_fields
      assign compressed_hdr.flt_q_hdr.flt_q_type             = tlp_hdr_extract.tlp_type;
        
      assign compressed_hdr.lut_np_req_type                  = compressed_hdr_flds.np_req_type;
      assign compressed_hdr.flt_q_hdr.flt_q_cpl_status       = reserved_cpl_status? `UR_CPL_STATUS : tlp_hdr_extract.tlp_cpl_status;   // pcie spec1.0a, 2.3.2:  treat reserved rcvd cpl_status as UR
      // from cpl lut
      assign compressed_hdr.flt_q_hdr.flt_q_cpl_last         = compressed_hdr_flds.cpl_last;        // CPL Control
      assign compressed_hdr.flt_q_hdr.flt_q_byte_cnt         = tlp_hdr_extract.tlp_byte_count;      // CPL HDR
      // completer ID "BDF" for Non-ARI & "BF" for ARI
      assign compressed_hdr.flt_q_hdr.flt_q_cplid            = tlp_hdr_extract.tlp_cpl_id;       // CPL HDR
      assign compressed_hdr.flt_q_hdr.flt_q_cpl_bcm          = tlp_hdr_extract.tlp_bcm;          // CPL HDR
      assign compressed_hdr.flt_q_hdr.flt_q_cpl_lower_addr   = tlp_hdr_extract.tlp_addr[6:0];    // CPL LOWER ADDR

      // not included in the function
      // the function only ectract it in case of NFM
        assign compressed_hdr.flt_q_hdr.hdr_dec_flt_cpltr_seg  = tlp_hdr_extract.tlp_cpl_seg;
    end
    else begin: PNP_compressed_hdr_fields
      // P,NP undriven
          assign compressed_hdr.radm_atu_sloc_region  = '0;
          assign compressed_hdr.radm_atu_sloc_match   = '0;
          assign compressed_hdr.radm_atu_cbuf_err     = '0;

      //P,NP common
      assign compressed_hdr.flt_q_hdr.flt_q_first_be     = tlp_hdr_extract.tlp_fdw_be;
      assign compressed_hdr.flt_q_hdr.flt_q_last_be      = tlp_hdr_extract.tlp_ldw_be;
      assign compressed_hdr.flt_q_hdr.flt_q_addr         = compressed_hdr_flds.hdr_log_valid? tlp_addr[FLT_Q_ADDR_WIDTH-1:0] : tlp_addr_tph[FLT_Q_ADDR_WIDTH-1:0];
      assign compressed_hdr.flt_q_hdr.flt_q_cpl_status   = compressed_hdr_flds.cpl_status;

      assign compressed_hdr.flt_q_hdr.flt_q_in_membar_range  = compressed_hdr_flds.in_membar_range;
      
      assign compressed_hdr.flt_q_hdr.flt_q_th = tlp_hdr_extract.tlp_th; // in NFM only 
      assign compressed_hdr.flt_q_hdr.flt_q_ph = tlp_hdr_extract.tlp_ph;
      assign compressed_hdr.flt_q_hdr.flt_q_st = tlp_hdr_extract.tlp_st[7:0];
      assign compressed_hdr.flt_q_hdr.hdr_dec_flt_reqtr_seg  = {tlp_hdr_extract.tlp_rsv, tlp_hdr_extract.tlp_req_seg};
      assign compressed_hdr.flt_q_hdr.flt_q_ats = tlp_hdr_extract.tlp_at;
        
      if (FC_TYPE == E_P) begin: P_compressed_hdr_fields   
        assign compressed_hdr.flt_q_hdr.flt_q_type  = tlp_hdr_extract.tlp_type;
          assign compressed_hdr.flt_q_hdr.flt_q_rom_req_in_range = compressed_hdr_flds.rom_req_in_range_c;
        assign compressed_hdr.flt_q_hdr.flt_q_hdr_uppr_bytes     = tlp_hdr_uppr_bytes;  
        // P undriven
          assign compressed_hdr.flt_q_hdr.radm_atu_uppr_bytes_valid = '0;
      end
      else if (FC_TYPE == E_NP) begin: NP_compressed_hdr_fields       
        assign compressed_hdr.flt_q_hdr.flt_q_type         = (flit_mode && ({tlp_hdr_extract.tlp_fmt,tlp_hdr_extract.tlp_type} == 7'b0000011)) ? 5'b00000 : tlp_hdr_extract.tlp_type;                
          assign compressed_hdr.flt_q_hdr.flt_q_rom_req_in_range    = compressed_hdr_flds.rom_req_in_range_c;
          assign compressed_hdr.flt_q_hdr.flt_q_io_req_in_range     = compressed_hdr_flds.io_req_in_range_c;
          assign compressed_hdr.flt_q_hdr.flt_q_nw        = flit_mode ? tlp_hdr_extract.tlp_nw : tlp_addr[0];
            assign compressed_hdr.flt_q_hdr.flt_q_cxlsrc  = flit_mode ? tlp_hdr_extract.tlp_cxlsrc : tlp_addr[3];
      end
    end
  endgenerate

endmodule
