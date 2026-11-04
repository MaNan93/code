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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #19 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/msg_formation.sv#19 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module formation message TLP and MSI TLP
// --- Note: MSI are treated as memory write
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
 
 module msg_formation 
 (
// ---- inputs ---------------
    core_rst_n,
    core_clk,
    cfg_pbus_num,
    cfg_pbus_dev_num,
    device_type,
    pm_xtlh_block_tlp,
    cfg_nond0_vdm_block,

    msg_code,
    msg_fmt,
    msg_type,
    msg_req_id,
    msg_obff_code,
    msg_xmt_request,

    set_slot_pwr_limit_val,
    set_slot_pwr_limit_scale,

    cfg_msi_addr,
    cfg_msi_data,
    cfg_msi_64,
    cfg_multi_msi_en,
    msi_req,
    msi_func_num,
    msi_tc,
    msi_vector,

    cfg_msix_en,
    msix_addr,
    msix_data,
    app_ltr_msg_req,
    app_ltr_msg_latency,
    app_ltr_msg_func_num,
    cdm2msgg_ltr_clr_msg_req,

    ven_msg_fmt,
    ven_msg_type,
    ven_msg_tc,
    ven_msg_td,
    ven_msg_ep,
    ven_msg_attr,
    ven_msg_len,
    ven_msg_func_num,
    ven_msg_tag,
    ven_msg_code,
    ven_msg_data,
    ven_msg_req,

    xadm_msg_halt,
    cfg_rasdp_error_mode,
    ras_err_inj_en_array,
    ras_err_inj_mask,

    msg_ptm_master_time,
    msg_ptm_data,
    msg_ptm_len,
    msg_is_ptm,
    msg_ptm_responseD,


// ---- outputs ---------------
    ras_err_inj_done,
    msg_gen_dv,
    msg_gen_hv,
    msg_gen_eot,
    msg_gen_data,
    msg_gen_hdr,
    msg_rn_vendorID,
    msg_rn_subType,
    msg_rn_reason,
    msg_xmt_grant,
    app_ltr_msg_grant,
    msgf_ltr_clr_msg_grant,
    msi_grant,
    ven_msg_grant
);
parameter INST          = 0;                   // The uniquifying parameter for each port logic instance.
parameter TP            = `TP;                 // Clock to Q delay (simulator insurance)
parameter NF            = `CX_NFUNC;           // number of functions
parameter PF_WD         = `CX_NFUNC_WD;        // number of bits needed to represent the pf number [0..NF-1], when this block is configured for sriov it is calculated as log2(NF), hardcoded to 3 otherwise
localparam PF_I_WD      = (NF==1) ? 1 : $clog2(NF);
parameter ST_HDR        = `ST_HDR;
parameter HDR_PROT_WD   = 0  
                                   + `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD //extended heade ecc/parity protection width
                                   ;
parameter DATA_PAR_WD          = `TRGT_DATA_PROT_WD;
parameter NW                   = `CX_NW;       // Number of 32-bit dwords handled by the datapath each clock.
parameter DW                   = (32*NW);      // Width of datapath in bits.
parameter RAS_PROT_RANGE       = `CX_RAS_PROT_RANGE;
parameter RAS_PROT_TYPE        = `CX_RAS_PROT_TYPE;
parameter RAS_CORR_EN          = `CX_RAS_CORRECTION_EN;
parameter RAS_PARITY_MODE      = `CX_RAS_PARITY_MODE;
parameter ERROR_INJ_EN_WD      = `CX_RAS_ERROR_INJ_EN_WD;
parameter ERROR_INJ_MASK_WD    = `CX_RAS_ERROR_INJ_MASK_WD;

parameter BUSNUM_WD     = `CX_BUSNUM_WD;       // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD     = `CX_DEVNUM_WD;       // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.

localparam ATTR_WD = `SF_HDR_TLP_ATTR;
localparam PIPE_VF_INDEX = 0 +1 ;
localparam PIPE_VF_INDEX_WIDTH = 1 + PF_WD + 3 + 5 //msi_req + msi_func_num + msi_tc + msi_vector
                                ;
localparam TAG_SIZE = `CX_TAG_SIZE;
                                
// ----- inputs -----
input                   core_rst_n;
input                   core_clk;
input   [BUSNUM_WD-1:0] cfg_pbus_num;               // bus number
input   [DEVNUM_WD-1:0] cfg_pbus_dev_num;           // device number
input   [3:0]           device_type;                // Device type
input                   pm_xtlh_block_tlp;          // Block MSG & MSI.
input                   cfg_nond0_vdm_block;        // Block VDM.
// Internal Message from msg_arbitration block
input   [7:0]           msg_code;                   // internal MSG code
input   [1:0]           msg_fmt;                    // internal MSG fmt
input   [4:0]           msg_type;                   // internal MSG type
input   [15:0]          msg_req_id;                 // internal MSG req id
input   [3:0]           msg_obff_code;
input                   msg_xmt_request;            // internal MSG xmt request
// Values used for Slot Power Messages
input   [7:0]           set_slot_pwr_limit_val;
input   [1:0]           set_slot_pwr_limit_scale;
// MSI
input   [(64*NF)-1:0]   cfg_msi_addr;               // MSI address
input   [(32*NF)-1:0]   cfg_msi_data;               // MSI data
input   [NF-1:0]        cfg_msi_64;                 // MSI is enabled for 64 bit addressing
input   [(3*NF)-1:0]    cfg_multi_msi_en;           // Multiple MSI Message
input                   msi_req;                    // MSI/MSI-X request
input   [PF_WD-1:0]     msi_func_num;               // MSI/MSI-X Function number
input   [2:0]           msi_tc;                     // MSI/MSI-X TC
input   [4:0]           msi_vector;                 // MSI vector, used to modify the lower 5-bit msi_data
// MSI-X
input   [NF-1:0]        cfg_msix_en;                // MSI-X enable
input   [63:0]          msix_addr;                  // MSI-X address
input   [31:0]          msix_data;                  // MSI-X data
// SII: LTR Message Interface
input                   app_ltr_msg_req;            // LTR message request
input   [31:0]          app_ltr_msg_latency;        // LTR message latency
input   [PF_WD-1:0]     app_ltr_msg_func_num;       // LTR function number
input                   cdm2msgg_ltr_clr_msg_req;   // Internal LTR clear message request

// Vendor Specified message
input   [1:0]           ven_msg_fmt;                // Vendor MSG fmt
input   [4:0]           ven_msg_type;               // Vendor MSG type
input   [2:0]           ven_msg_tc;                 // Vendor MSG traffic class
input                   ven_msg_td;                 // Vendor MSG TLP digest
input                   ven_msg_ep;                 // Vendor MSG EP bit
input   [ATTR_WD-1:0]   ven_msg_attr;               // Vendor MSG attribute
input   [9:0]           ven_msg_len;                // Vendor MSG length
input   [PF_WD-1:0]     ven_msg_func_num;           // Vendor MSG function number
input   [TAG_SIZE-1:0]  ven_msg_tag;                // Vendor MSG tag
input   [7:0]           ven_msg_code;               // Vendor MSG code
input   [63:0]          ven_msg_data;               // Vendor MSG data
input                   ven_msg_req;                // Vendor MSG xmt request

input                   xadm_msg_halt;              // msg advance from XADM

input  [15:0]           msg_rn_vendorID;            // Vendor MSG ID, when Readiness Notification is used
input  [7:0]            msg_rn_subType;             // Vendor MSG subType Field, when Readiness Notification is used
input  [3:0]            msg_rn_reason;              // Vendor MSG Reason Field, when Readiness Notification is used
input                   cfg_rasdp_error_mode;
input   [ERROR_INJ_EN_WD  -1:0] ras_err_inj_en_array;
input   [ERROR_INJ_MASK_WD-1:0] ras_err_inj_mask;

input  [63:0]           msg_ptm_master_time;
input  [31:0]           msg_ptm_data;
input  [9:0]            msg_ptm_len;
input                   msg_is_ptm;
input                   msg_ptm_responseD;


// ----- outputs -----
output                  ras_err_inj_done;
output                  msg_gen_dv;                 // tlp msg data valid
output                  msg_gen_hv;                 // tlp msg end of transaction
output                  msg_gen_eot;                // tlp msg end of transaction
output [DW+DATA_PAR_WD-1:0]msg_gen_data;            // tlp msg data
output [ST_HDR+HDR_PROT_WD-1:0]msg_gen_hdr;         // tlp msg hdr - with protection code if RAS is used
output                  msg_xmt_grant;              // grant to msg_gen
// SII: LTR Message Interface
output                  app_ltr_msg_grant;          // LTR message grant
output                  msgf_ltr_clr_msg_grant;     // LTR clear message grant
output                  msi_grant;                  // grant
output                  ven_msg_grant;              // grant to vendor


// Output registers
wire [DW+DATA_PAR_WD-1:0]  msg_gen_data;
wire    [31:0]          msg_data;
reg                     msg_xmt_grant;
reg                     msi_grant;
reg                     ven_msg_grant;
reg                     msg_gen_dv;
reg                     msg_gen_hv;
logic     [ST_HDR+HDR_PROT_WD -1:0]   msg_gen_hdr;
reg     [ST_HDR -1:0]   msg_gen_hdr_nxt;
reg     [ST_HDR -1:0]   msg_gen_hdr_noprot; // header field used to generate protection code
reg     [ST_HDR -1:0]   msg_gen_hdr_int;

reg                     msg_gen_eot;
reg                     app_ltr_msg_grant;
reg                     msgf_ltr_clr_msg_grant;

logic   [NF-1:0][63:0]   cfg_msi_addr_v;               // MSI address
logic   [NF-1:0][31:0]   cfg_msi_data_v;               // MSI data
logic   [NF-1:0][2:0]    cfg_multi_msi_en_v;           // Multiple MSI Message
always_comb begin
    for(int i = 0; i < NF; i++)begin
        cfg_msi_addr_v[i] = cfg_msi_addr[64*i +: 64];
        cfg_msi_data_v[i] = cfg_msi_data[32*i +: 32];
        cfg_multi_msi_en_v[i] = cfg_multi_msi_en[3*i +: 3];
    end
end

// Internal reg/wires
wire                end_device;
assign end_device      = (device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY);
wire                rc_device;
assign rc_device       = (device_type == `PCIE_RC);
wire                bridge_device;
assign bridge_device   = (device_type == `PCIE_PCIX);
wire                pcie_sw_up;
assign pcie_sw_up      = (device_type == `PCIE_SW_UP);
wire                pcie_sw_down;
assign pcie_sw_down    = (device_type == `PCIE_SW_DOWN);
wire                upstream_port;
assign upstream_port   = end_device | bridge_device | pcie_sw_up;
wire                downstream_port;
assign downstream_port = rc_device | pcie_sw_down;

// Register msi inputs and eventually delay them
// to ease calculation of msi_vf_index
wire             msi_req_reg;
wire [PF_WD-1:0] msi_func_num_reg;
wire [2:0]       msi_tc_reg;
wire [4:0]       msi_vector_reg;


reg     [4:0]           vector_en;
// LMD: Undriven net Range
// LJ: This input is driven
// leda NTL_CON12 off
  wire    [15:0]          msi_req_id = get_req_id(cfg_pbus_num, cfg_pbus_dev_num, msi_func_num_reg, device_type);
// leda NTL_CON12 on
wire    [15:0]          msg_rid;
wire                    msg_slot = (msg_code == `SET_SLOT_PWR_LIMIT) & msg_xmt_request;
reg     [2:0]           msg_tc;
reg     [63:0]          int_msi_addr;                   // MSI address
reg     [31:0]          int_msi_data;                   // MSI data
reg                     int_msi_64;
reg     [2:0]           int_multi_msi_en;
reg                     latchd_msi_req;
reg                     latchd_ven_msg_req;
reg                     latchd_msg_xmt_request;
reg                     latchd_app_ltr_msg_req;          // Registered state of app_ltr_msg_req
reg                     latchd_cdm2msgg_ltr_clr_msg_req; // Registered state of cdm2msgg_ltr_clr_msg_req
reg     [ST_HDR -1:0]   int_ltr_msg_hdr;                 // LTR message header
// Halt msg gen when RASDP error mode is active since there is no point in sending msgs
// if they are going to be nullified 
// Msgs which are requested when RASDP error mode is asserted are halted until error mode is
// cleared by the application.
// If a config does not support RASDP this signal is tied to 0
wire                    rasdp_halt_msg_gen;

assign rasdp_halt_msg_gen = 1'b0 
                            | cfg_rasdp_error_mode
                            ;

wire ras_err_inj_data_done;

assign ras_err_inj_done = ras_err_inj_data_done

                          ;

delay_n_w_stalling

#(.N(PIPE_VF_INDEX), .WD(PIPE_VF_INDEX_WIDTH), .CAN_STALL(1)) u_vf_index_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (msi_grant),
    .stall      (msi_grant),
    .din        ({msi_req, msi_func_num, msi_tc, msi_vector
                  }),
    .stallout   (),
    .dout       ({msi_req_reg, msi_func_num_reg, msi_tc_reg, msi_vector_reg
                 })
  );





always @(*)
begin: msi_addr_data_mux_PROC
    begin
        // LMD: Range index out of bound
        // LJ: This coding style may produce a warning from some lint tools as msi_func_num is not constrained to always be a power of 2 value.
        // leda E267 off
        int_msi_addr = cfg_msi_addr_v[msi_func_num_reg[PF_I_WD-1:0]];
        int_msi_addr[63:32] = cfg_msi_64[msi_func_num_reg[PF_I_WD-1:0]] ? int_msi_addr[63:32] : 32'b0;
        int_msi_data = cfg_msi_data_v[msi_func_num_reg[PF_I_WD-1:0]];
        int_multi_msi_en = cfg_multi_msi_en_v[msi_func_num_reg[PF_I_WD-1:0]];
        // leda E267 on
    end
    int_msi_64 = (int_msi_addr[63:32] == 32'b0) ? 1'b0 : 1'b1;
end

// Generate MSI Vector enables depending on multi MSI enable
always @(*)
begin
    case (int_multi_msi_en)
        3'b000 : vector_en = 5'b00000;
        3'b001 : vector_en = 5'b00001;
        3'b010 : vector_en = 5'b00011;
        3'b011 : vector_en = 5'b00111;
        3'b100 : vector_en = 5'b01111;
        3'b101 : vector_en = 5'b11111;
        default: vector_en = 5'b00000;
    endcase
end

// MSI-X mux
// If MSI-X is enabled, use msix_addr instead
wire    [63:0]  msi_addr;
wire            msi_64;
wire            msix_en;
assign msix_en = slice_fn(cfg_msix_en, msi_func_num_reg);

assign msi_addr = msix_en  ? msix_addr : int_msi_addr;
assign msi_64   = msix_en  ? (msix_addr[63:32] != 0) : int_msi_64;

// --------------------------------------------------------------------
// In order to serve the application that does not want to handle
// multi-cycle, the gates are added in the following code to get rid of the
// dependency of multi-cycle issue.
// Otherwise, it is wise to have multi-cycle and save a lots of gates.
// Beneath ifdef code is designed for this purposes

//`ifdef MULTI_CYCLE_ENABLE
//// The priority of the following is guaranteed in the clocked process below
//// the following asynch process.
//
//always @ (msg_code or msg_fmt or msg_req_id
//          or msg_slot or msg_type or latchd_msg_xmt_request or msi_addr
//          or latchd_msi_req or msi_req_id or msi_tc
//          or ven_msg_attr or ven_msg_code or cfg_pbus_num or cfg_pbus_dev_num
//          or ven_msg_ep or ven_msg_fmt or msi_64 or ven_msg_data
//          or ven_msg_len or latchd_ven_msg_req or ven_msg_func_num
//          or ven_msg_tag or ven_msg_tc or ven_msg_td or ven_msg_type)
//begin
//    // default field values
//    msg_gen_hdr[`F_HDR_CPL_BYTE_CNT           ] = 0;
//    msg_gen_hdr[`F_HDR_CPL_BCM                ] = 0;
//    msg_gen_hdr[`F_HDR_CPL_STATUS             ] = 0;
//    msg_gen_hdr[`F_HDR_CPL_REQ_ID             ] = 0;
//    msg_gen_hdr[`F_HDR_BYTE_EN                ] = 0;

//
//         unique case (1'b1)

//       latchd_msi_req: begin
//            msg_gen_hdr[`F_HDR_TLP_ADDR       ] = msi_addr;
//            msg_gen_hdr[`F_HDR_TLP_FMT        ] = {1'b1, msi_64}; // {fmt,type} == (cfg_msi_64 ? `MWR64 :`MWR32)};
//            msg_gen_hdr[`F_HDR_TLP_TYPE       ] = 5'b00000;           // {fmt,type} == (cfg_msi_64 ? `MWR64 :`MWR32)};
//            msg_gen_hdr[`F_HDR_TLP_TC         ] = msi_tc;
//            msg_gen_hdr[`F_HDR_TLP_TD         ] = 1'b0;
//            msg_gen_hdr[`F_HDR_TLP_EP         ] = 1'b0;
//            msg_gen_hdr[`F_HDR_TLP_ATTR       ] = 2'b00;
//            msg_gen_hdr[`F_HDR_TLP_BYTE_LEN   ] = 13'h004;
//            msg_gen_hdr[`F_HDR_TLP_TAG        ] = 8'h00;
//            msg_gen_hdr[`F_HDR_REQ_ID         ] = msi_req_id;
//            msg_gen_hdr[`F_HDR_BYTE_EN        ] = {4'b0000, 4'b1111};
//            msg_gen_hdr[`F_HDR_ADDR_ALIGN_EN  ] = 1'b1;
//        end
//        latchd_msg_xmt_request: begin
//            msg_gen_hdr[`F_HDR_TLP_ADDR       ] = 0;
//            msg_gen_hdr[`F_HDR_TLP_MSG_CODE   ] = msg_code; // OVERLOADED with BYTE_EN
//            msg_gen_hdr[`F_HDR_TLP_FMT        ] = msg_fmt;
//            msg_gen_hdr[`F_HDR_TLP_TYPE       ] = msg_type;
//            msg_gen_hdr[`F_HDR_TLP_TC         ] = 1'b0;
//            msg_gen_hdr[`F_HDR_TLP_TD         ] = 1'b0;
//            msg_gen_hdr[`F_HDR_TLP_EP         ] = 1'b0;
//            msg_gen_hdr[`F_HDR_TLP_ATTR       ] = 2'b00;
//            msg_gen_hdr[`F_HDR_TLP_BYTE_LEN   ] = (msg_slot) ? 13'h0004 : 13'h0000;
//            msg_gen_hdr[`F_HDR_ADDR_ALIGN_EN  ] = 1'b1;
//            msg_gen_hdr[`F_HDR_TLP_TAG        ] = 8'h00;
//            msg_gen_hdr[`F_HDR_REQ_ID         ] = msg_req_id;
////            msg_gen_hdr[`F_HDR_TLP_MSG_PYLD_DW1] = 0;         // OVERLOADED with ADDR
////            msg_gen_hdr[`F_HDR_TLP_MSG_PYLD_DW0] = 0;         // cant overload addr[63:32]
//        end // case: msg_xmt_request
//        // This implementation assumes that the vendor message contains no data by default
//        // AND that the vendor data is limited to the single DW allowed by the msg_gen_data
//        // path out of this block. It may be possible to use the 32 vendor bits of the header
//        // for data, with a more complex dv generation algorithm.
//        latchd_ven_msg_req: begin
//            msg_gen_hdr[`F_HDR_TLP_ADDR        ] = ven_msg_data;            // OVERLOADED with MSG_CODE....
//            msg_gen_hdr[`F_HDR_TLP_MSG_CODE    ] = ven_msg_code; // OVERLOADED with BYTE_EN
//            msg_gen_hdr[`F_HDR_TLP_FMT         ] = ven_msg_fmt;
//            msg_gen_hdr[`F_HDR_TLP_TYPE        ] = ven_msg_type;
//            msg_gen_hdr[`F_HDR_TLP_TC          ] = ven_msg_tc;
//            msg_gen_hdr[`F_HDR_TLP_TD          ] = ven_msg_td;
//            msg_gen_hdr[`F_HDR_TLP_EP          ] = ven_msg_ep;
//            msg_gen_hdr[`F_HDR_TLP_ATTR        ] = ven_msg_attr;
//            msg_gen_hdr[`F_HDR_TLP_BYTE_LEN    ] = {1'b0,ven_msg_len, 2'b0} ; // we support max of 64 bit data with ven_msg
////            msg_gen_hdr[`F_HDR_TLP_BYTE_LEN  ] = ven_msg_len *4;
//            msg_gen_hdr[`F_HDR_TLP_TAG         ] = ven_msg_tag;
//`ifdef MULTI_DEVICE_AND_BUS_PER_FUNC_EN

//`else
//            msg_gen_hdr[`F_HDR_REQ_ID          ] = {cfg_pbus_num, cfg_pbus_dev_num, ven_msg_func_num};
//`endif
//            msg_gen_hdr[`F_HDR_ADDR_ALIGN_EN   ] = 1'b1;
////            msg_gen_hdr[`F_HDR_TLP_MSG_PYLD_DW1] = ven_msg_data[63:32]; // OVERLOADED with ADDR
////            msg_gen_hdr[`F_HDR_TLP_MSG_PYLD_DW0] = ven_msg_data[31:0]; //  cant overload addr[63:32]
//        end
//        default : begin
//            msg_gen_hdr             = 0;
//        end
//    endcase // case(1'b1)
//
//end // always @ (...
//
//assign msg_gen_data = msg_slot ? {16'b0, 6'b0, set_slot_pwr_limit_scale, set_slot_pwr_limit_val} :
//                      msix_en  ? msix_data :
//                                 {16'h0, int_msi_data[15:5], ((int_msi_data[4:0] & ~vector_en) | (msi_vector & vector_en))};
//
//always @(posedge core_clk or negedge core_rst_n)
//begin
//    if (!core_rst_n) begin
//        msi_grant       <= #TP 0;
//        ven_msg_grant   <= #TP 0;
//        msg_xmt_grant   <= #TP 0;
//    end
//    else begin
//        msi_grant       <= #TP latchd_msi_req & !xadm_msg_halt;
//        ven_msg_grant   <= #TP latchd_ven_msg_req & !xadm_msg_halt;
//        msg_xmt_grant   <= #TP latchd_msg_xmt_request & !xadm_msg_halt;
//    end
//end
//
//always @(posedge core_clk or negedge core_rst_n)
//begin
//    if (!core_rst_n)
//    begin
//        msg_gen_dv              <= #TP 0;
//        msg_gen_hv              <= #TP 0;
//        msg_gen_eot             <= #TP 0;
//        latchd_msi_req          <= #TP 0;
//        latchd_ven_msg_req      <= #TP 0;
//        latchd_msg_xmt_request  <= #TP 0;
//    end
//    else if (msi_req & !msg_gen_hv & !msi_grant )
//    begin
//        msg_gen_dv              <= #TP 1'b1;
//        msg_gen_hv              <= #TP 1'b1;
//        msg_gen_eot             <= #TP 1'b1;
//        latchd_msi_req          <= #TP 1'b1;
//    end
//    else if (msg_xmt_request & !msg_gen_hv & !msg_xmt_grant )
//    begin
//        msg_gen_dv              <= #TP msg_slot;
//        msg_gen_hv              <= #TP 1'b1;
//        msg_gen_eot             <= #TP 1'b1;
//        latchd_msg_xmt_request  <= #TP 1'b1;
//    end
//    else if (ven_msg_req & !msg_gen_hv & !ven_msg_grant) begin
//        msg_gen_dv              <= #TP |ven_msg_len[1:0];
//        msg_gen_hv              <= #TP 1'b1;
//        msg_gen_eot             <= #TP 1'b1;
//        latchd_ven_msg_req      <= #TP 1'b1;
//    end
//    else if (!xadm_msg_halt) begin
//        msg_gen_dv              <= #TP 1'b0;
//        msg_gen_hv              <= #TP 1'b0;
//        msg_gen_eot             <= #TP 1'b0;
//        latchd_msi_req          <= #TP 0;
//        latchd_ven_msg_req      <= #TP 0;
//        latchd_msg_xmt_request  <= #TP 0;
//    end
//end // always @ (posedge core_clk or negedge core_rst_n)
//`else //MULTI_CYCLE_ENABLE
reg     [ST_HDR -1:0]    int_msg_xmt_hdr;
// LMD: Undriven net Range
// LJ: This signal is initialized a zero
// leda NTL_CON12 off
reg     [ST_HDR -1:0]    int_ven_hdr;
reg     [ST_HDR -1:0]    int_ide_hdr;
reg     [7:0]           byte11;
// leda NTL_CON12 on
reg     [ST_HDR -1:0]    int_msi_hdr;
// The priority of the following is guaranteed in the clocked process below
// the following asynch process.

always @ (*)
begin
    int_msi_hdr                             = {ST_HDR{1'b0}};
    int_msi_hdr[`F_HDR_TLP_ADDR         ]   = msi_addr;
    int_msi_hdr[`F_HDR_TLP_FMT          ]   = {1'b1, msi_64};   // {fmt,type} == (cfg_msi_64 ? `MWR64 :`MWR32)};
    int_msi_hdr[`F_HDR_TLP_TYPE         ]   = 5'b00000;         // {fmt,type} == (cfg_msi_64 ? `MWR64 :`MWR32)};
    int_msi_hdr[`F_HDR_TLP_TC           ]   = msi_tc_reg;
    int_msi_hdr[`F_HDR_TLP_TD           ]   = 1'b0;
    int_msi_hdr[`F_HDR_TLP_EP           ]   = 1'b0;
    int_msi_hdr[`F_HDR_TLP_ATTR         ]   = 3'b000;
    int_msi_hdr[`F_HDR_TLP_BYTE_LEN     ]   = 13'h004;
    int_msi_hdr[`F_HDR_TLP_TAG          ]   = {TAG_SIZE{1'b0}};
    int_msi_hdr[`F_HDR_REQ_ID           ]   = msi_req_id;
    int_msi_hdr[`F_HDR_BYTE_EN          ]   = {4'b0000, 4'b1111};
    int_msi_hdr[`F_HDR_ADDR_ALIGN_EN    ]   = 1'b1;
    int_msg_xmt_hdr                         = {ST_HDR{1'b0}};

     int_msg_xmt_hdr[`F_HDR_TLP_ADDR     ]  = 0;

     if (msg_code == `OBFF) begin
       int_msg_xmt_hdr[`F_HDR_TLP_ADDR   ]  = {60'd0,msg_obff_code};
     end
    if ((msg_code == `PTM_RES_TYPE) && (downstream_port == 1)) begin
       int_msg_xmt_hdr[`F_HDR_TLP_ADDR   ]  = msg_ptm_master_time;
    end
     if (msg_code == `VENDOR_TYPE1) begin
       int_msg_xmt_hdr[`F_HDR_TLP_ADDR   ]  = {16'd0,msg_rn_vendorID,msg_rn_subType,20'd0,msg_rn_reason};
     end

    int_msg_xmt_hdr[`F_HDR_TLP_MSG_CODE ]   = msg_code;         // OVERLOADED with BYTE_EN
    int_msg_xmt_hdr[`F_HDR_TLP_FMT      ]   = msg_fmt;
    int_msg_xmt_hdr[`F_HDR_TLP_TYPE     ]   = msg_type;
    msg_tc                                  = 3'b0;
    int_msg_xmt_hdr[`F_HDR_TLP_TC       ]   = msg_tc;
    int_msg_xmt_hdr[`F_HDR_TLP_TD       ]   = 1'b0;
    int_msg_xmt_hdr[`F_HDR_TLP_EP       ]   = 1'b0;
    int_msg_xmt_hdr[`F_HDR_TLP_ATTR     ]   = 3'b000;
    int_msg_xmt_hdr[`F_HDR_TLP_BYTE_LEN ]   = (msg_slot) ? 13'h0004 : 
                                              (msg_ptm_responseD && downstream_port) ? {1'b0, msg_ptm_len, 2'b0} :
                                                           13'h0000;
    int_msg_xmt_hdr[`F_HDR_ADDR_ALIGN_EN]   = 1'b1;
    int_msg_xmt_hdr[`F_HDR_TLP_TAG      ]   = {TAG_SIZE{1'b0}};
    int_msg_xmt_hdr[`F_HDR_REQ_ID       ]   = msg_req_id;

    int_ven_hdr                             = {ST_HDR{1'b0}};
    int_ven_hdr[`F_HDR_TLP_ADDR         ]   = ven_msg_data;                // OVERLOADED with MSG_CODE....
    int_ven_hdr[`F_HDR_TLP_MSG_CODE     ]   = ven_msg_code;     // OVERLOADED with BYTE_EN
    int_ven_hdr[`F_HDR_TLP_FMT          ]   = ven_msg_fmt;
    int_ven_hdr[`F_HDR_TLP_TYPE         ]   = ven_msg_type;
    int_ven_hdr[`F_HDR_TLP_TC           ]   = ven_msg_tc;
    int_ven_hdr[`F_HDR_TLP_TD           ]   = ven_msg_td;
    int_ven_hdr[`F_HDR_TLP_EP           ]   = ven_msg_ep;
    int_ven_hdr[`F_HDR_TLP_ATTR         ]   = ven_msg_attr;
    int_ven_hdr[`F_HDR_TLP_BYTE_LEN     ]   = {1'b0, ven_msg_len, 2'b0}; // we support max of 32 bit data with ven_msg
    int_ven_hdr[`F_HDR_TLP_TAG          ]   = ven_msg_tag;
    int_ven_hdr[`F_HDR_REQ_ID           ]   = get_req_id(cfg_pbus_num, cfg_pbus_dev_num, ven_msg_func_num, device_type);
    int_ven_hdr[`F_HDR_ADDR_ALIGN_EN    ]   = 1'b1;
// --------------------------------------------------------------------
// Build LTR Msg TLP
// --------------------------------------------------------------------
    int_ltr_msg_hdr                             = 0; // Intialise header fields to all zeros
    int_ltr_msg_hdr[`F_HDR_TLP_FMT          ]   = 2'b01; // Message request without data
    int_ltr_msg_hdr[`F_HDR_TLP_TYPE         ]   = 5'b10100; // Msg type, local; terminate at receiver.
    int_ltr_msg_hdr[`F_HDR_TLP_TC           ]   = 3'b000; // Traffic class 0
    // IDO not implemented for message requests.
    // TH is not applicable to message requests and is reserved.
    // TD set to 0
    // EP set to 0
    // ATTR is reserved.
    // AT must be set to 00, not checked by receiver.
    // LENGTH field set to all 10'b0, Msg with no data
    int_ltr_msg_hdr[`F_HDR_REQ_ID           ]   = app_ltr_msg_req ? get_req_id(cfg_pbus_num, cfg_pbus_dev_num, app_ltr_msg_func_num, device_type)
                                                                  : get_req_id(cfg_pbus_num, cfg_pbus_dev_num, {PF_WD{1'b0}}, device_type);
    // Msg is posted, TAG set to 8'b0
    int_ltr_msg_hdr[`F_HDR_TLP_MSG_CODE     ]   = `LTR_MSG_CODE; // LTR Message Code

    // Only use application latency field if auto-clear message is not being sent.
    int_ltr_msg_hdr[`F_HDR_TLP_ADDR         ]   = app_ltr_msg_req && !(cdm2msgg_ltr_clr_msg_req && !msg_gen_hv && !msgf_ltr_clr_msg_grant) ? {32'b0, app_ltr_msg_latency} : 64'b0; // Bytes 8 to 15

    int_ltr_msg_hdr[`F_HDR_ADDR_ALIGN_EN    ]   = 1'b1; // not applicable to Msg TLP's



end // always @ (...

assign msg_data = msg_slot ? {16'b0, 6'b0, set_slot_pwr_limit_scale, set_slot_pwr_limit_val} :
                      msg_is_ptm && downstream_port  ? msg_ptm_data :
                      msix_en  ? msix_data :
                      {int_msi_data[31:5], ((int_msi_data[4:0] & ~vector_en) | (msi_vector_reg & vector_en))};

 wire [DW-1:0] msg_data_int;
 assign msg_data_int = { {(DW-32){1'b0}},msg_data};
wire           sampling_data = !xadm_msg_halt;

 bus_protect_gen
  #(
  .PROT_TYPE  (RAS_PROT_TYPE),
  .PROT_RANGE (RAS_PROT_RANGE),
  .PROT_WD    (DATA_PAR_WD),
  .DATA_WD    (DW),
  .PARITY_MODE( RAS_PARITY_MODE )
  ) 
   u_msg_data_gen(
    .gen        (1'b1),
    .datain     (msg_data_int),
      .core_clk              (core_clk  ),
      .core_rst_n            (core_rst_n),
      .error_inj_mask        (ras_err_inj_mask[DATA_PAR_WD+DW-1:0]),
      .error_inj_en          (ras_err_inj_en_array[13]),
      .error_inj_data_valid  (msg_gen_dv && sampling_data),
      .error_inj_eot         (msg_gen_eot && sampling_data),
      .error_inj_done        (ras_err_inj_data_done),  
    .chkout     (msg_gen_data[DW+DATA_PAR_WD-1:DW]),
    .dataout    (msg_gen_data[DW-1:0])
        );

                               
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        msi_grant         <= #TP 0;
        ven_msg_grant     <= #TP 0;
        msg_xmt_grant     <= #TP 0;
        app_ltr_msg_grant      <= #TP 0;
        msgf_ltr_clr_msg_grant <= #TP 0;
    end
    else begin
        msi_grant         <= #TP latchd_msi_req & !xadm_msg_halt;
        ven_msg_grant     <= #TP latchd_ven_msg_req & !xadm_msg_halt;
        msg_xmt_grant     <= #TP latchd_msg_xmt_request & !xadm_msg_halt;
        app_ltr_msg_grant      <= #TP latchd_app_ltr_msg_req & !xadm_msg_halt;
        msgf_ltr_clr_msg_grant <= #TP latchd_cdm2msgg_ltr_clr_msg_req & !xadm_msg_halt;
    end
end


always @ (*)
begin: msg_gen_hdr_int_PROC
      if ((msi_req_reg && msi_req) & !msg_gen_hv & !msi_grant)
         msg_gen_hdr_int = int_msi_hdr;
      else if (msg_xmt_request & !msg_gen_hv & !msg_xmt_grant)
         msg_gen_hdr_int = int_msg_xmt_hdr;
      else if (app_ltr_msg_req & !msg_gen_hv & !app_ltr_msg_grant) 
         msg_gen_hdr_int = int_ltr_msg_hdr;
      else if (cdm2msgg_ltr_clr_msg_req & !msg_gen_hv & !msgf_ltr_clr_msg_grant) 
         msg_gen_hdr_int = int_ltr_msg_hdr;
      else if (ven_msg_req & !msg_gen_hv & !ven_msg_grant & !(cfg_nond0_vdm_block & pm_xtlh_block_tlp) ) 
         msg_gen_hdr_int = int_ven_hdr;
      else
         msg_gen_hdr_int = msg_gen_hdr[ST_HDR-1:0];
end


assign msg_gen_hdr_noprot = msg_gen_hdr_int;


always @(posedge core_clk or negedge core_rst_n)
begin: msg_gen_hdr_PROC
  if (!core_rst_n)
    msg_gen_hdr_nxt <= #TP 0;
  else
    msg_gen_hdr_nxt <= #TP msg_gen_hdr_noprot;
  end
bus_protect_gen
 #(
   .PROT_TYPE  ( RAS_PROT_TYPE        ),
   .PROT_RANGE ( RAS_PROT_RANGE       ),
   .PROT_WD    ( HDR_PROT_WD          ),
   .DATA_WD    ( ST_HDR               ),
   .PARITY_MODE( RAS_PARITY_MODE      )
   )
   u_msg_hdr_gen(
     .gen        ( 1'b1                                   ),
     .datain     ( msg_gen_hdr_nxt                        ),
      .core_clk              (core_clk  ),
      .core_rst_n            (core_rst_n),
      .error_inj_mask        (ras_err_inj_mask[HDR_PROT_WD+ST_HDR-1:0]),
      .error_inj_en          (ras_err_inj_en_array[12]),
      .error_inj_data_valid  (msg_gen_hv  && sampling_data),
      .error_inj_eot         (msg_gen_eot && sampling_data),
      .error_inj_done        (ras_err_inj_hdr_done),
     .chkout     ( msg_gen_hdr[ST_HDR +: HDR_PROT_WD] ),
     .dataout    ( msg_gen_hdr[ST_HDR-1: 0]          ));




always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
    begin
        msg_gen_dv              <= #TP '0;
        msg_gen_hv              <= #TP '0;
        msg_gen_eot             <= #TP '0;
        latchd_msi_req          <= #TP '0;
        latchd_ven_msg_req      <= #TP '0;
        latchd_msg_xmt_request  <= #TP '0;
        latchd_app_ltr_msg_req           <= #TP '0;
        latchd_cdm2msgg_ltr_clr_msg_req  <= #TP '0;
//        msg_gen_hdr             <= #TP 0;
    end
    else if ((msi_req_reg && msi_req) & !msg_gen_hv & !msi_grant & !rasdp_halt_msg_gen)
    begin
        msg_gen_dv              <= #TP 1'b1;
        msg_gen_hv              <= #TP 1'b1;
        msg_gen_eot             <= #TP 1'b1;
        latchd_msi_req          <= #TP 1'b1;
//        msg_gen_hdr             <= #TP int_msi_hdr;
    end
    else if (msg_xmt_request & !msg_gen_hv & !msg_xmt_grant & !rasdp_halt_msg_gen)
    begin
          msg_gen_dv              <= #TP msg_slot || (msg_ptm_responseD && downstream_port);
        msg_gen_hv              <= #TP 1'b1;
        msg_gen_eot             <= #TP 1'b1;
        latchd_msg_xmt_request  <= #TP 1'b1;
//        msg_gen_hdr             <= #TP int_msg_xmt_hdr;
    end
    else if (app_ltr_msg_req & !msg_gen_hv & !app_ltr_msg_grant & !rasdp_halt_msg_gen) begin
        msg_gen_hv              <= #TP 1'b1;
        msg_gen_dv              <= #TP 1'b0;
        msg_gen_eot             <= #TP 1'b1;
        latchd_app_ltr_msg_req  <= #TP 1'b1;
//        msg_gen_hdr             <= #TP int_ltr_msg_hdr;
    end
    else if (cdm2msgg_ltr_clr_msg_req & !msg_gen_hv & !msgf_ltr_clr_msg_grant & !rasdp_halt_msg_gen) begin
        msg_gen_hv                       <= #TP 1'b1;
        msg_gen_dv                       <= #TP 1'b0;
        msg_gen_eot                      <= #TP 1'b1;
        latchd_cdm2msgg_ltr_clr_msg_req  <= #TP 1'b1;
//        msg_gen_hdr                      <= #TP int_ltr_msg_hdr;
    end
    else if (ven_msg_req & !msg_gen_hv & !ven_msg_grant & !(cfg_nond0_vdm_block & pm_xtlh_block_tlp) & !rasdp_halt_msg_gen) begin
        msg_gen_dv              <= #TP |ven_msg_len[1:0];
        msg_gen_hv              <= #TP 1'b1;
        msg_gen_eot             <= #TP 1'b1;
        latchd_ven_msg_req      <= #TP 1'b1;
//        msg_gen_hdr             <= #TP int_ven_hdr;
    end 
    else if (!xadm_msg_halt) begin
        msg_gen_dv              <= #TP 1'b0;
        msg_gen_hv              <= #TP 1'b0;
        msg_gen_eot             <= #TP 1'b0;
        latchd_msi_req          <= #TP 0;
        latchd_ven_msg_req      <= #TP 0;
        latchd_msg_xmt_request  <= #TP 0;
        latchd_app_ltr_msg_req           <= #TP 1'b0;
        latchd_cdm2msgg_ltr_clr_msg_req  <= #TP 1'b0;
    end
end // always @ (posedge core_clk or negedge core_rst_n)


//`endif //MULTI_CYCLE_ENABLE

 // Function to get Requester ID given function #
function automatic[15:0] get_req_id;
input [BUSNUM_WD-1:0]   bus_num;
input [DEVNUM_WD-1:0]   dev_num;
input [PF_WD-1:0]       func_num;
input [3:0]             device_type;
integer i;

reg  [7:0]              int_bus_num;
reg  [4:0]              int_dev_num;
reg  [PF_WD-1:0]        int_func_num;
reg  [7:0]              func_num_8b;

begin
    int_bus_num = 0;
    int_dev_num = 0;
    int_func_num = 0;
    int_func_num[PF_WD-1:0] = func_num[PF_WD-1:0];
    func_num_8b = {{(8-PF_WD){1'b0}},func_num}; // drive at 0 most significant bits

    int_bus_num = bus_num[7:0];
    int_dev_num = dev_num[4:0];

    get_req_id = {int_bus_num, int_dev_num, func_num[2:0]};
end

endfunction // get_req_id

function automatic slice_fn;
    input [NF-1:0]          input_vec;
    input [PF_WD-1:0]    bit_loc;
    reg   [7:0]             int_bit_loc;
    integer                 i;
begin
        slice_fn = 0;
        int_bit_loc = 0;
        int_bit_loc[PF_WD-1:0] = bit_loc[PF_WD-1:0];

        for(i=0; i<NF; i=i+1) begin
            if(int_bit_loc==i)
                slice_fn = input_vec[i];
        end
end
endfunction // slice_fn

endmodule
