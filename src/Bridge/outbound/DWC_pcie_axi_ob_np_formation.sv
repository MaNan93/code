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

// ---------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #17 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_ob_np_formation.sv#17 $
// ---------------------------------------------------------------------------------------
// --- Module Description:
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 module DWC_pcie_axi_ob_np_formation
 (
    slv_aclk,
    slv_aresetn,
    // GIF interface

    sif_np_cpl_stat,
    sif_np_tlpprfx,
    sif_np_th,
    sif_np_ph,
    sif_np_st,
    sif_np_atu_bypass,
    sif_np_dst_segment,
    sif_np_ats,
    sif_np_nw,
    sif_np_ido,
    sif_np_snp,
    sif_np_size,
    sif_np_burst,
    sif_np_tag,
    sif_np_id,
    sif_np_len,
    sif_np_tc,
    sif_np_ep,
    sif_np_ro,
    sif_np_ns,
    sif_np_wr,
    sif_np_rd,
    sif_np_atomic,
    sif_np_dmwr,
    sif_np_first_wrp_split_xact,
    sif_np_wrp_valid,
    sif_np_type,
    sif_np_addr,
    sif_np_strb,
    sif_np_data,

    // GIF generated request to core

    nprf_ready,

    nprf_cpl_stat,
    nprf_prfx,
    nprf_th,
    nprf_ph,
    nprf_st,
    nprf_atu_bypass,
    nprf_dst_segment,
    nprf_ats,
    nprf_nw,
    nprf_first_wrp_split_xact,
    nprf_wrp_valid,
    nprf_snp,
    nprf_tag,
    nprf_id,
    nprf_byte_len,
    nprf_tc,
    nprf_be,
    nprf_ep,
    nprf_attr,
    nprf_fmt,
    nprf_type,
    nprf_addr,
    nprf_data,
    nprf_hv,
    nprf_dv,
    nprf_eot,
    nprf_bad_eot,

    npdcmp_halt
   );

parameter SLV_BUS_NPDATA_WIDTH        = `CC_SLV_BUS_NPDATA_WIDTH;
parameter SLV_BUS_NPWSTRB_WIDTH       = `CC_SLV_BUS_NPWSTRB_WIDTH;
parameter SLV_BUS_ADDR_WIDTH          = `CC_SLV_BUS_ADDR_WIDTH;
parameter MAX_SLV_TAG_PW              = `CC_MAX_SLV_TAG_PW;         // pointer width of MAX_SLV_TAG
parameter BURST_LEN_PW                = `CC_SLV_INT_BURST_LEN_PW;
parameter SLV_MTU_PW                  = `CC_SLV_MTU_PW;
parameter SLV_BUS_ID_WIDTH            = `CC_SLV_BUS_ID_WIDTH;
parameter NFUNC_WD                    = `CX_NFUNC_WD;
parameter NVFUNC_WD                   = `CX_NVFUNC_WD;
parameter DC_CPL_STATUS_WD            = `DC_CPL_STATUS_WD;
parameter ATTR_WD                     = 3;
parameter NW_PRFX                     = `CX_NPRFX;
parameter PRFX_PAR_WD                 = `CX_PRFX_PAR_WD;
parameter TX_TLP_PREFIX_WD            = (32*NW_PRFX)+ PRFX_PAR_WD;
parameter TPH_ST_WD                   = 8;
parameter TPH_PH_WD                   = 2;
parameter TPH_TH_WD                   = 1;
parameter MISC_INFO_TPH_WD            = TPH_ST_WD + TPH_PH_WD + TPH_TH_WD;

parameter TP                          = `TP;                        // Clock to Q delay (simulator insurance)
parameter DATAPATH_WIDTH =
                                  DC_CPL_STATUS_WD +           // sif_np_cpl_stat
                                  TX_TLP_PREFIX_WD +           // sif_np_tlpprfx
                                  MISC_INFO_TPH_WD +           //sif_np_tph
                                  1 +                          // sif_np_atu_bypass
                                  9 +                          // sif_np_dst_segment
                                  2 +                          // sif_np_ats
                                  1 +                          // sif_np_nw,
                                  1 +                          // sif_np_first_wrp_split_xact,
                                  1 +                          // sif_np_wrp_valid,
                                  1 +                          // sif_np_snp
                                  MAX_SLV_TAG_PW +             // sif_np_tag
                                  SLV_BUS_ID_WIDTH + 1 +       // sif_np_id
                                  SLV_MTU_PW +                 // sif_np_byte_len
                                  3 +                          // sif_np_tc
                                  1 +                          // sif_np_ep
                                  3 +                          // sif_np_attr
                                  8 +                          // sif_np_be
                                  2 +                          // sif_np_fmt
                                  5 +                          // sif_np_type
                                  SLV_BUS_ADDR_WIDTH +         // sif_np_addr
                                  SLV_BUS_NPDATA_WIDTH +       // sif_np_data
                                  1 +                          // sif_np_hv
                                  1 +                          // sif_np_dv
                                  1 +                          // sif_np_eot
                                  1 ;                          // sif_np_bad_eot

parameter N_CYCLE_DELAY                 = 1; // Stall Delay
parameter CAN_STALL                     = 1; // Enable Delay

input  wire                                   slv_aclk;
input  wire                                   slv_aresetn;

input  wire [DC_CPL_STATUS_WD-1:0]            sif_np_cpl_stat;
input  wire [TX_TLP_PREFIX_WD-1:0]            sif_np_tlpprfx;
input  wire                                   sif_np_th;
input  wire [1:0]                             sif_np_ph;
input  wire [7:0]                             sif_np_st;
input  wire                                   sif_np_atu_bypass;
input  wire [8:0]                             sif_np_dst_segment;
input  wire                                   sif_np_nw;
input  wire [1:0]                             sif_np_ats;
input  wire                                   sif_np_ido;
input  wire                                   sif_np_snp;
input  wire [2:0]                             sif_np_size;
input  wire [1:0]                             sif_np_burst;
input  wire [MAX_SLV_TAG_PW -1:0]             sif_np_tag;
input  wire [SLV_BUS_ID_WIDTH-1:0]            sif_np_id;
input  wire [BURST_LEN_PW-1:0]                sif_np_len;
input  wire [2:0]                             sif_np_tc;
input  wire                                   sif_np_ep;
input  wire                                   sif_np_ro;
input  wire                                   sif_np_ns;
input  wire                                   sif_np_wr;
input  wire                                   sif_np_rd;
input  wire                                   sif_np_atomic;
input  wire                                   sif_np_dmwr;
input  wire                                   sif_np_first_wrp_split_xact;
input  wire                                   sif_np_wrp_valid;
input  wire [4:0]                             sif_np_type;
input  wire [SLV_BUS_ADDR_WIDTH-1:0]          sif_np_addr;
input  wire [SLV_BUS_NPWSTRB_WIDTH-1:0]       sif_np_strb;
input  wire [SLV_BUS_NPDATA_WIDTH-1:0]        sif_np_data;

output wire                                   nprf_ready;              // slave accept the master's request

// Core native interface

output wire [DC_CPL_STATUS_WD-1:0]            nprf_cpl_stat;
output wire [TX_TLP_PREFIX_WD-1:0]            nprf_prfx;
output wire                                   nprf_th;
output wire [1:0]                             nprf_ph;
output wire [7:0]                             nprf_st;
output wire                                   nprf_atu_bypass;
output wire [8:0]                             nprf_dst_segment;
output wire [1:0]                             nprf_ats;
output wire                                   nprf_nw;
output wire                                   nprf_first_wrp_split_xact;
output wire                                   nprf_wrp_valid;
output wire                                   nprf_snp;          // Slave request Format
output wire [MAX_SLV_TAG_PW -1:0]             nprf_tag;          // Slave request TAG
output wire [SLV_BUS_ID_WIDTH:0]              nprf_id;           // Slave request ID
output wire [SLV_MTU_PW-1:0]                  nprf_byte_len;     // Slave request Byte Length
output wire [2:0]                             nprf_tc;           // Slave request Traffic Class
output wire [7:0]                             nprf_be;           // Slave request Byte Enable
output wire                                   nprf_ep;           // Slave request EP
output wire [ATTR_WD-1:0]                     nprf_attr;         // Slave request Attribute
output wire [1:0]                             nprf_fmt;          // Slave request Format
output wire [4:0]                             nprf_type;         // Slave request Type
output wire [SLV_BUS_ADDR_WIDTH-1:0]          nprf_addr;         // Slave request Address
output wire [SLV_BUS_NPDATA_WIDTH-1:0]        nprf_data;         // Slave request Data
output wire                                   nprf_hv;           // Slave request Header Valid
output wire                                   nprf_dv;           // Slave request Data Valid
output wire                                   nprf_eot;          // Slave request End Of Xfer
output wire                                   nprf_bad_eot;      // Slave request Bad EOT
input  wire                                   npdcmp_halt;       // Halt from FIFO to the burst transfer

// --------------------- Internal signal declarations ------------------------

//wire                                      nprf_ready_ctrl;      // Internal nprf_ready
//wire                                      req_halt_in;          // Req Halt In
//wire                                      req_halt_out;         // Req Halt Out
//reg [SLV_MTU_PW-1:0]                      write_bytes;          // # Bytes Per Core Write


reg    [SLV_MTU_PW-1:0]                 s_byte_len;
wire   [SLV_MTU_PW-1:0]                 ss_byte_len;


wire   [1:0]                            sif_np_fmt;              // Internal format
wire   [ATTR_WD-1:0]                    sif_np_attr;             // Internal request attribute
wire                                    sif_np_addr64;           // 64 bit address detect
wire   [SLV_MTU_PW-1:0]                 sif_np_byte_len;
wire   [7:0]                            sif_np_be;               // Internal byte enable
wire                                    sif_np_hv;               // Internal header valid
wire                                    sif_np_dv;               // Internal data valid
wire                                    sif_np_eot;              // Internal eot
wire                                    sif_np_bad_eot;          // Internal bad eot
wire   [2:0]                            int_size;                // Internal size
wire   [63:0]                           sif_np_addr_nopar;
wire                                    sif_np_atomic_cas;       // Atomic Compare And Swap
wire                                    int_halt;

wire                                    byte_len_less_than_1dw;           // Byte Length Less Than 1 DW
wire                                    total_byte_len_less_than_1dw;     // Total Byte Length Less Than 1 DW
reg    [SLV_MTU_PW-1:0]                 s_num_bytes_per_beat;
reg    [3:0]                            int_rd_last_be;                   // Intermed Last Byte Enable for read requests
reg    [3:0]                            int_wr_last_be;                   // Intermed Last Byte Enable for write requests
reg    [3:0]                            int_first_be;                     // Internal First Byte Enable

wire   [3:0]                            first_be;                         // First Byte Enable
wire   [3:0]                            last_be;                          // Last Byte Enable
wire                                    dwlen_1;                          // DWORD Length One

wire                                    halt_in;                          // Request halt in
wire   [DATAPATH_WIDTH -1:0]            req_sdata_in;                     // Request stall data in
wire   [DATAPATH_WIDTH -1:0]            req_sdata_out;                    // Request stall data out

reg    [SLV_MTU_PW-1:0]                 total_byte_len;
wire   [SLV_MTU_PW-1:0]                 s_total_byte_len;
wire   [SLV_MTU_PW-3:0]                 total_dw_aligned_len;

wire   [SLV_MTU_PW-1:0]                 s_sif_np_len_shift_size;

// --------------------- Internal Design ------------------------


//assign nprf_ready     = !req_halt_out;



assign sif_np_addr_nopar = strip_addr_par(sif_np_addr);

assign sif_np_addr64 = (|sif_np_addr_nopar[63:32]) && ((sif_np_type == 5'b00000) || (sif_np_type == 5'b00001) || (sif_np_type==`ATOP_FETCH_ADD) || (sif_np_type==`ATOP_SWAP) || (sif_np_type==`ATOP_CAS) || (sif_np_type==`DMWR_TYPE));
assign sif_np_atomic_cas = (sif_np_type == 5'b01110) ? 1'b1 : 1'b0;

assign s_sif_np_len_shift_size = SLV_MTU_PW'(( sif_np_len + 1 ) << sif_np_size );


always @(*)
begin
  s_byte_len = {SLV_MTU_PW{1'b0}};
  case  (sif_np_size)
    3'b000: s_byte_len = sif_np_len + 1 ;
    3'b001: s_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size - {{(SLV_MTU_PW-1){1'b0}},sif_np_addr[0]});
    3'b010: s_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size - {{(SLV_MTU_PW-2){1'b0}},sif_np_addr[1:0]});
    3'b011: s_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size - {{(SLV_MTU_PW-3){1'b0}},sif_np_addr[2:0]});
    // ccx_line_begin: ; REDUNDANT: Data bus width in this config is 64 bits so size cannot exceed 8 bytes (code 011)
    3'b100: s_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size - {{(SLV_MTU_PW-4){1'b0}},sif_np_addr[3:0]});
    3'b101: s_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size - {{(SLV_MTU_PW-5){1'b0}},sif_np_addr[4:0]});
    3'b110: s_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size - {{(SLV_MTU_PW-6){1'b0}},sif_np_addr[5:0]});
// For future wider bus width support:
//  3'b111: s_byte_len = ;
    // ccx_line_end
    default
       s_byte_len = {SLV_MTU_PW{1'b0}};
  endcase

end


reg [SLV_MTU_PW-1:0] s_dmwr_s_byte_len;

always @(*) begin: proc_comb_s_dmwr_s_byte_len

  integer i;

  s_dmwr_s_byte_len = 0;
  for(i=0;i<SLV_BUS_NPWSTRB_WIDTH;i=i+1)
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
    s_dmwr_s_byte_len = s_dmwr_s_byte_len + sif_np_strb[i];
    // spyglass enable_block W164a

end

assign ss_byte_len = sif_np_dmwr ? s_dmwr_s_byte_len : s_byte_len;


assign byte_len_less_than_1dw = ss_byte_len < {{(SLV_MTU_PW-3){1'b0}},3'b100};

// Get First Byte Enable
always @(*)
  case  ({sif_np_addr[1:0], ss_byte_len[1:0]})
    4'b0000: int_first_be = byte_len_less_than_1dw ? 4'b0000 : 4'b1111;
    4'b0001: int_first_be = byte_len_less_than_1dw ? 4'b0001 : 4'b1111;
    4'b0010: int_first_be = byte_len_less_than_1dw ? 4'b0011 : 4'b1111;
    4'b0011: int_first_be = byte_len_less_than_1dw ? 4'b0111 : 4'b1111;
    4'b0100: int_first_be = byte_len_less_than_1dw ? 4'b0000 : 4'b1110;
    4'b0101: int_first_be = byte_len_less_than_1dw ? 4'b0010 : 4'b1110;
    4'b0110: int_first_be = byte_len_less_than_1dw ? 4'b0110 : 4'b1110;
    4'b0111: int_first_be = 4'b1110;
    4'b1000: int_first_be = byte_len_less_than_1dw ? 4'b0000 : 4'b1100;
    4'b1001: int_first_be = byte_len_less_than_1dw ? 4'b0100 : 4'b1100;
    4'b1010: int_first_be = 4'b1100;
    4'b1011: int_first_be = 4'b1100;
    4'b1100: int_first_be = byte_len_less_than_1dw ? 4'b0000 : 4'b1000;
    default:
      int_first_be = 4'b1000;
  endcase

assign first_be = sif_np_wr ? (sif_np_atomic ? 4'b0000 : sif_np_strb[3:0]) : int_first_be;


// Get Last Byte Enable
always @(*)
begin
  total_byte_len = {SLV_MTU_PW{1'b0}};
  case  (sif_np_size)
    3'b000: total_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size + {{(SLV_MTU_PW-2){1'b0}},sif_np_addr[1:0]});
    3'b001: total_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size + {{(SLV_MTU_PW-2){1'b0}},sif_np_addr[1],1'b0});
    3'b010: total_byte_len = s_sif_np_len_shift_size;
    3'b011: total_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size - {{(SLV_MTU_PW-3){1'b0}},sif_np_addr[2],2'h0});
    3'b100: total_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size - {{(SLV_MTU_PW-4){1'b0}},sif_np_addr[3:2],2'h0});
    3'b101: total_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size - {{(SLV_MTU_PW-5){1'b0}},sif_np_addr[4:2],2'h0});
    3'b110: total_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size - {{(SLV_MTU_PW-6){1'b0}},sif_np_addr[5:2],2'h0});
    // For future wider bus width support:
    //3'b111: total_byte_len = SLV_MTU_PW'(s_sif_np_len_shift_size + {{(SLV_MTU_PW-7){1'b0}},sif_np_addr[6:2],2'h0});
    default
       total_byte_len = {SLV_MTU_PW{1'b0}};
    endcase
end


reg [SLV_MTU_PW-1:0] s_dmwr_total_byte_len;

always @(*) begin: proc_comb_s_dmwr_total_byte_len

  integer i;

  s_dmwr_total_byte_len = 0;
  for(i=0;i<SLV_BUS_NPWSTRB_WIDTH;i=i+1)
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
    s_dmwr_total_byte_len = s_dmwr_total_byte_len + sif_np_strb[i];
    // spyglass enable_block W164a

end

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
// If Wrapping burst AtomicCompare the address is not modified.
assign s_total_byte_len = sif_np_dmwr ? (s_dmwr_total_byte_len + sif_np_addr[1:0]) : (sif_np_atomic_cas ? s_sif_np_len_shift_size : total_byte_len);
// spyglass enable_block W164a


assign total_byte_len_less_than_1dw = s_total_byte_len < {{(SLV_MTU_PW-3){1'b0}},3'b100};

always @(*) begin
    case  (s_total_byte_len[1:0])
     //2'b00: int_rd_last_be = 4'b1111;
     2'b01: int_rd_last_be = total_byte_len_less_than_1dw ? 4'b0000 : 4'b0001;
     2'b10: int_rd_last_be = total_byte_len_less_than_1dw ? 4'b0000 : 4'b0011;
     2'b11: int_rd_last_be = total_byte_len_less_than_1dw ? 4'b0000 : 4'b0111;
     default:
            int_rd_last_be = total_byte_len_less_than_1dw ? 4'b0000 : 4'b1111;
   endcase
end

assign dwlen_1 = (total_dw_aligned_len == {{(SLV_MTU_PW-1){1'b0}},1'b1});

always @(*) begin : proc_comb_num_bytes
  integer i;
  s_num_bytes_per_beat = {SLV_MTU_PW{1'b0}};

  for (i=0; i<SLV_BUS_NPWSTRB_WIDTH; i=i+1) begin
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
    s_num_bytes_per_beat = s_num_bytes_per_beat + sif_np_strb[i];
    // spyglass enable_block W164a
  end
end

always @(*) begin
    case  (s_num_bytes_per_beat[1:0]+sif_np_addr[1:0])
     //2'b00: int_wr_last_be = 4'b1111;
     2'b01: int_wr_last_be = total_byte_len_less_than_1dw ? 4'b0000 : 4'b0001;
     2'b10: int_wr_last_be = total_byte_len_less_than_1dw ? 4'b0000 : 4'b0011;
     2'b11: int_wr_last_be = total_byte_len_less_than_1dw ? 4'b0000 : 4'b0111;
     default:
            int_wr_last_be = total_byte_len_less_than_1dw ? 4'b0000 : 4'b1111;
   endcase
end

assign last_be  = sif_np_wr ? (sif_np_atomic ? 4'b0000 : int_wr_last_be) : (dwlen_1 ? 4'b0000 : int_rd_last_be);

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign total_dw_aligned_len  = s_total_byte_len[SLV_MTU_PW-1:2] + (|s_total_byte_len[1:0]) + !(|s_total_byte_len); // when it is 0 length, we need to have 1 dword for a PCIe packet
// spyglass enable_block W164a

// control signals
assign sif_np_hv             = sif_np_wr | sif_np_rd;
assign sif_np_dv             = sif_np_wr;
assign sif_np_eot            = sif_np_wr | sif_np_rd;
assign sif_np_bad_eot        = 1'b0;
assign sif_np_fmt            = {sif_np_wr, sif_np_addr64};
assign sif_np_byte_len       = (sif_np_wr && !sif_np_atomic && !sif_np_dmwr ) ? {{(SLV_MTU_PW-3){1'b0}},3'b100} : {total_dw_aligned_len,2'b00};
assign sif_np_attr           = {sif_np_ido,sif_np_ro,sif_np_ns};
assign sif_np_be             = {last_be,first_be};

assign nprf_ready            = !int_halt;

assign req_sdata_in = {
    sif_np_cpl_stat,
    sif_np_tlpprfx,
    sif_np_th,
    sif_np_ph,
    sif_np_st,
    sif_np_atu_bypass,
    sif_np_dst_segment,
    sif_np_ats,
    sif_np_nw,
    sif_np_first_wrp_split_xact,
    sif_np_wrp_valid,
    sif_np_snp,
    sif_np_tag,
   {sif_np_wr,sif_np_id},
    sif_np_byte_len,
    sif_np_tc,
    sif_np_ep,
    sif_np_attr,
    sif_np_be,
    sif_np_fmt,
    sif_np_type,
    sif_np_addr,
    sif_np_data,
    sif_np_hv,
    sif_np_dv,
    sif_np_eot,
    sif_np_bad_eot
   };


delay_1_w_stalling

#(N_CYCLE_DELAY, DATAPATH_WIDTH, CAN_STALL) u1_delay (
    .clk        (slv_aclk),
    .rst_n      (slv_aresetn),
    .clear      (1'b0),
    .din        (req_sdata_in),
    .stallout   (int_halt),

    .dout       (req_sdata_out),
    .stall      (halt_in)
);


// Recover Stall Data Out
assign {
    nprf_cpl_stat,
    nprf_prfx,
    nprf_th,
    nprf_ph,
    nprf_st,
    nprf_atu_bypass,
    nprf_dst_segment,
    nprf_ats,
    nprf_nw,
    nprf_first_wrp_split_xact,
    nprf_wrp_valid,
    nprf_snp,
    nprf_tag,
    nprf_id,
    nprf_byte_len,
    nprf_tc,
    nprf_ep,
    nprf_attr,
    nprf_be,
    nprf_fmt,
    nprf_type,
    nprf_addr,
    nprf_data,
    nprf_hv,
    nprf_dv,
    nprf_eot,
    nprf_bad_eot
    } = req_sdata_out;

// Stall Halt In
assign halt_in = npdcmp_halt & (nprf_dv | nprf_hv | nprf_eot);

parameter CX_RAS_PROT_RANGE = `CX_RAS_PROT_RANGE;
parameter ADDR_PAR_WD       = `CC_SLV_BUS_ADDR_WIDTH - `SLAVE_BUS_ADDR_WIDTH;

function automatic [63:0] strip_addr_par;
input [SLV_BUS_ADDR_WIDTH-1:0]   in_addr;
integer i,j;
begin
    strip_addr_par =0;
    for (i=0; i<ADDR_PAR_WD; i=i+1) begin
        for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
            strip_addr_par[i*CX_RAS_PROT_RANGE +j] = in_addr[i*CX_RAS_PROT_RANGE +j +i];
        end
    end
end
endfunction


endmodule
