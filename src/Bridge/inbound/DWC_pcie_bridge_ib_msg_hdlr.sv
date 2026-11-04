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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_ib_msg_hdlr.sv#5 $
// -------------------------------------------------------------------------
// --- Module description: Message Handler
// ---     This block manipulates the inbound TLP and feeds to the write queue
// --- in the case the TLP is of type Msg/MsgD and it has been translated by the
// --- iATU. It picks up the 3rd and 4th header DW delivered by the iATU on
// --- radm_trgt1_hdr_uppr_bytes and embeds it in the datapayload.
// --- Fields manipulated before input to the Write Decomposer:
// --- 1. DW Length
// --- 2. DV
// --- 3. EOT
// --- 4. DWEN
// --- 5. Data
// --- 6. halt to RADM interface
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_bridge_ib_msg_hdlr
 #(
   parameter DC_INBD_HEADER_PNP_1STG_WD   = `DC_INBD_HEADER_PNP_1STG_WD,
   parameter DC_INBD_HEADER_PNP_WD        = `DC_INBD_HEADER_PNP_WD,
   parameter CORE_REQ_DATA_BUS_WD         = `CC_CORE_DATA_BUS_WD,
   parameter INBD_MSG_HDR_PAR             = 64/`CX_RAS_PROT_RANGE,
   parameter INBD_MSG_HDR_WD              = 64+INBD_MSG_HDR_PAR,
   parameter TP                                     = `TP
 )
  (
  // -------------------------------------------------------------------------------------
  // clk &rsts
  // -------------------------------------------------------------------------------------
  input                                              core_aclk,
  input                                              core_rstn,
  // -------------------------------------------------------------------------------------
  // ins & Outs
  // -------------------------------------------------------------------------------------
  input [DC_INBD_HEADER_PNP_1STG_WD-1:0]             inbd_hdr_pnp,
  input [CORE_REQ_DATA_BUS_WD-1:0]                   inbd_data_pnp,
  input [63:0]                                       msg_uppr_bytes,
  input                                              dwn_strm_pkt_halt,

  output wire [DC_INBD_HEADER_PNP_1STG_WD-1:0]       inbd_hdr_pnp_mod,
  output wire [CORE_REQ_DATA_BUS_WD-1:0]             inbd_data_pnp_mod,
  output wire                                        inbd_halt_pnp_mod

 );

  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam DWEN_WD = `CX_NW -1;
   localparam MSG_UPPR_BYTES_LOW  = 0;
   localparam MSG_UPPR_BYTES_MID  = (INBD_MSG_HDR_WD/2)-1;
   localparam MSG_UPPR_BYTES_HIGH = INBD_MSG_HDR_WD - 1;
// LOG2 (CX_NW) only for CX_NW>2
   localparam NW_LOG_2 = $clog2(`CX_NW); // 0, ..., `CX_NW-1

  // width of data registers
  localparam DATA_WD = (`CX_NW > 2) ? MSG_UPPR_BYTES_HIGH : (CORE_REQ_DATA_BUS_WD-1);
  // -------------------------------------------------------------------------------------
  // Regs/Wires
  // -------------------------------------------------------------------------------------
  wire inbd_hdr_pnp_hv;
  wire inbd_hdr_pnp_dv;
  wire [9:0] inbd_hdr_pnp_len;
  wire [DWEN_WD:0] inbd_hdr_pnp_dwen;
  wire [CORE_REQ_DATA_BUS_WD-1:0] inbd_data_pnp_int;
  wire inbd_hdr_pnp_eot;
  wire [6:0] inbd_hdr_fmt_type;
  wire inbd_hdr_pnp_hdr_uppr_bytes_valid;

  reg  [DC_INBD_HEADER_PNP_1STG_WD-1:0] inbd_hdr_pnp_mod_int;
  wire inbd_hdr_pnp_mod_dv;
  wire [9:0] inbd_hdr_pnp_mod_len;
  wire [DWEN_WD:0] inbd_hdr_pnp_mod_dwen;
  wire [CORE_REQ_DATA_BUS_WD-1:0] inbd_data_pnp_mod_int;
  wire inbd_halt_pnp_mod_int;
  wire inbd_hdr_pnp_mod_eot;
  wire inbd_hdr_pnp_hv_no_halt;

  reg [9:0] inbd_hdr_pnp_len_reg;
  reg [6:0] inbd_hdr_pnp_fmt_type_reg;
  reg inbd_hdr_pnp_hdr_uppr_bytes_valid_reg;
  reg eot_reg1;
  reg eot_reg2;


  wire [CORE_REQ_DATA_BUS_WD-1:0] s_data_reg;
  wire [DWEN_WD:0] s_dwen_reg;
  wire halt_required;
  wire s_eot_reg;
  wire s_eot_reg2;
  wire s_msg;
  wire s_msgd;
  wire o_valid;

  reg  [INBD_MSG_HDR_PAR-1:0] s_calc_msg_uppr_bytes_par;
  wire [INBD_MSG_HDR_WD-1:0]  s_msg_uppr_bytes;

  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // Extracting hdr info from bus

  assign inbd_hdr_pnp_hv =inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW] ;
  assign inbd_hdr_pnp_hv_no_halt = (inbd_hdr_pnp_hv && !inbd_halt_pnp_mod_int);
  assign inbd_hdr_pnp_dv =inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW];
  assign inbd_hdr_pnp_len =(inbd_hdr_pnp_hv_no_halt) ? inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DW_LEN_HIGH:`INBD_HDR_PNP_RANGE_DW_LEN_LOW] :inbd_hdr_pnp_len_reg;
  assign inbd_hdr_pnp_dwen =inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DWEN_HIGH : `INBD_HDR_PNP_RANGE_DWEN_LOW] ;
  assign inbd_data_pnp_int =inbd_data_pnp ;
  assign inbd_hdr_pnp_eot =  inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW];
  assign inbd_hdr_fmt_type = (inbd_hdr_pnp_hv_no_halt) ? {inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW],inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]} : inbd_hdr_pnp_fmt_type_reg;
  assign inbd_hdr_pnp_hdr_uppr_bytes_valid = (inbd_hdr_pnp_hv_no_halt) ? inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_HIGH:`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_LOW] : inbd_hdr_pnp_hdr_uppr_bytes_valid_reg;

  // Calculating parity for header upper bytes
  always @( * )
  begin: S_CALC_MSG_UPPER_BYTES_PAR_COMB_PROC
  integer i;
  reg i_calc_msg_uppr_bytes_par;
    s_calc_msg_uppr_bytes_par = 0;
    for (i=0; i<INBD_MSG_HDR_PAR; i=i+1) begin
        i_calc_msg_uppr_bytes_par    = ^get_msg_uppr_bytes(msg_uppr_bytes, i);
        s_calc_msg_uppr_bytes_par[i] = `CX_RAS_PARITY_MODE^i_calc_msg_uppr_bytes_par;
    end
  end

  assign s_msg_uppr_bytes = add_msg_uppr_bytes_par(msg_uppr_bytes,s_calc_msg_uppr_bytes_par);


  // Registers to store HDR info when HV is low. This is needed as the controls to the mechanism depend on the type, length and xlate signals
    always@(posedge core_aclk or negedge core_rstn)
  begin: len
    if(!core_rstn) begin // reset value at the end of the packet
        inbd_hdr_pnp_len_reg     <= #TP 0;
      end else if (inbd_hdr_pnp_mod_eot && !dwn_strm_pkt_halt) begin
        inbd_hdr_pnp_len_reg     <= #TP 0;
      end else if (dwn_strm_pkt_halt || inbd_halt_pnp_mod_int) begin// holds the value if there is a halt
        inbd_hdr_pnp_len_reg  <= #TP inbd_hdr_pnp_len_reg;
      end else if (inbd_hdr_pnp_hv) begin
        inbd_hdr_pnp_len_reg     <= #TP inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DW_LEN_HIGH:`INBD_HDR_PNP_RANGE_DW_LEN_LOW] ;
      end
  end

    always@(posedge core_aclk or negedge core_rstn)
  begin: fmt_type
    if(!core_rstn) begin // reset value at the end of the packet
        inbd_hdr_pnp_fmt_type_reg     <= #TP 0;
      end else if (inbd_hdr_pnp_mod_eot && !dwn_strm_pkt_halt) begin
        inbd_hdr_pnp_fmt_type_reg     <= #TP 0;
      end else if (dwn_strm_pkt_halt || inbd_halt_pnp_mod_int) begin// holds the value if there is a halt
        inbd_hdr_pnp_fmt_type_reg  <= #TP inbd_hdr_pnp_fmt_type_reg;
      end else if (inbd_hdr_pnp_hv) begin
        inbd_hdr_pnp_fmt_type_reg     <= #TP {inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW],inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]};
      end
  end

      always@(posedge core_aclk or negedge core_rstn)
  begin: hdr_uppr_bytes_valid_delayed
    if(!core_rstn) begin // reset value at the end of the packet
        inbd_hdr_pnp_hdr_uppr_bytes_valid_reg     <= #TP 0;
      end else if (inbd_hdr_pnp_mod_eot && !dwn_strm_pkt_halt) begin
        inbd_hdr_pnp_hdr_uppr_bytes_valid_reg     <= #TP 0;
      end else if (dwn_strm_pkt_halt || inbd_halt_pnp_mod_int) begin// holds the value if there is a halt
        inbd_hdr_pnp_hdr_uppr_bytes_valid_reg  <= #TP inbd_hdr_pnp_hdr_uppr_bytes_valid_reg;
      end else if (inbd_hdr_pnp_hv) begin
        inbd_hdr_pnp_hdr_uppr_bytes_valid_reg     <= #TP inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_HIGH:`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_LOW];
      end
  end

  assign s_msg = (inbd_hdr_fmt_type[6:3] == `MSG_4) || (inbd_hdr_fmt_type[6:3] == `MSG_AS_4);
  assign s_msgd = (inbd_hdr_fmt_type[6:3] == `MSGD_4) || (inbd_hdr_fmt_type[6:3] == `MSGD_AS_4);


  // The following section manipulates DV, Length, EOT , DWEN and Data fields
  // Embeds the Msg_uppr_bytes in the data payload for Msg/MsgD TLPs
  // asserts halt when required

generate
  if (`CX_NW == 1) begin:databus32
    // length incremented by 2 DWs to account for hdr_uppr_bytes embeded in data payload
    assign inbd_hdr_pnp_mod_len = inbd_hdr_pnp_len + {8'b0,2'b10};


    // stream order: 1. msg_uppr_bytes Least Significant Word 2. msg_uppr_bytes Most Significant Word 3. rest of data
    // DWEN and DV should also reflect the changes in data
  reg [DATA_WD:0] data_reg1;
  reg [DATA_WD:0] data_reg2;
  reg [DWEN_WD:0] dwen_reg1;
  reg [DWEN_WD:0] dwen_reg2;
  reg  dv_reg1;
  reg  dv_reg2;
  wire s_dv_reg;


  always@(posedge core_aclk or negedge core_rstn)
  begin: data1
    if(!core_rstn) begin
        data_reg1     <= #TP 0;
        dwen_reg1     <= #TP 0;
      end else if (dwn_strm_pkt_halt) begin// holds the value if there is a downstream pkt halt
        data_reg1     <= #TP data_reg1;
        dwen_reg1     <= #TP dwen_reg1;
      end else if (inbd_hdr_pnp_dv) begin
        data_reg1     <= #TP inbd_data_pnp_int;
        dwen_reg1     <= #TP inbd_hdr_pnp_dwen;
      end
  end

    always@(posedge core_aclk or negedge core_rstn)
  begin: dv1
    if(!core_rstn) begin
  dv_reg1       <= #TP 0;
      end else if (dwn_strm_pkt_halt) begin// holds the value if there is a downstream pkt halt
  dv_reg1       <= #TP dv_reg1;
      end else begin
  dv_reg1       <= #TP inbd_hdr_pnp_dv;
      end
  end
  assign s_data_reg = (inbd_hdr_pnp_hv_no_halt) ?  s_msg_uppr_bytes [MSG_UPPR_BYTES_HIGH: (MSG_UPPR_BYTES_MID + 1)] : data_reg1;
  assign s_dwen_reg = (inbd_hdr_pnp_hv_no_halt) ? {{DWEN_WD{1'b1}},1'b1} : dwen_reg1;
  assign s_dv_reg = (inbd_hdr_pnp_hv_no_halt) ? 1'b1 : dv_reg1;
      always@(posedge core_aclk or negedge core_rstn)
  begin: data2
    if(!core_rstn) begin
        data_reg2     <= #TP 0;
        dwen_reg2     <= #TP 0;
      end else if (dwn_strm_pkt_halt) begin// holds the value if there is a downstream pkt halt
        data_reg2     <= #TP data_reg2;
        dwen_reg2     <= #TP dwen_reg2;
      end else begin
        data_reg2     <= #TP s_data_reg;
        dwen_reg2     <= #TP s_dwen_reg;
      end
  end
      always@(posedge core_aclk or negedge core_rstn)
  begin: dv2
    if(!core_rstn) begin
  dv_reg2       <= #TP 0;
      end else if (dwn_strm_pkt_halt) begin// holds the value if there is a downstream pkt halt
  dv_reg2       <= #TP dv_reg2;
      end else begin
  dv_reg2       <= #TP s_dv_reg;
      end
  end
 assign  inbd_data_pnp_mod_int = (inbd_hdr_pnp_hv_no_halt) ? s_msg_uppr_bytes [MSG_UPPR_BYTES_MID:MSG_UPPR_BYTES_LOW] : data_reg2 ;
 assign  inbd_hdr_pnp_mod_dwen = (inbd_hdr_pnp_hv_no_halt) ? {{DWEN_WD{1'b1}},1'b1} : dwen_reg2 ;
 assign  inbd_hdr_pnp_mod_dv   = (inbd_hdr_pnp_hv_no_halt) ? 1'b1 : dv_reg2;

  // EOT delayed 2 cycles for MsgDs,delayed 1 cycle for Msgs
  // The feed to the register needs to be reset
  // 1. when halt is set by msg_hdlr to not take in the value of EOT in the next halted packet at the interface
  // 2. in the case non-translated Msg/MsgDs
 assign s_eot_reg = (s_msg|| inbd_halt_pnp_mod_int || (!inbd_hdr_pnp_hdr_uppr_bytes_valid))? 1'b0 : inbd_hdr_pnp_eot ;
     always@(posedge core_aclk or negedge core_rstn)
  begin: eot1
    if(!core_rstn) begin
        eot_reg1     <= #TP 0;
      end else if (dwn_strm_pkt_halt) begin// holds the value if there is a downstream pkt halt
        eot_reg1     <= #TP eot_reg1;
      end else begin
        eot_reg1     <= #TP s_eot_reg;
      end
  end

 assign s_eot_reg2 = (s_msg && inbd_hdr_pnp_hdr_uppr_bytes_valid && !(inbd_halt_pnp_mod_int))? inbd_hdr_pnp_eot : eot_reg1;
     always@(posedge core_aclk or negedge core_rstn)
  begin: eot2
    if(!core_rstn) begin
        eot_reg2     <= #TP 0;
      end else if (dwn_strm_pkt_halt) begin// holds the value if there is a downstream pkt halt
        eot_reg2     <= #TP eot_reg2;
      end else begin
        eot_reg2     <= #TP s_eot_reg2;
      end
  end
  assign inbd_hdr_pnp_mod_eot = eot_reg2 ;

 // halt reflects the delay in EOT
 assign inbd_halt_pnp_mod_int = eot_reg2 || eot_reg1;


  end else if (`CX_NW == 2) begin: databus64

    // length incremented by 2 DWs
    assign inbd_hdr_pnp_mod_len = inbd_hdr_pnp_len + {8'b0,2'b10};
    // stream order: 1. msg_uppr_bytes as 1st beat 2. rest of data
    // DW enable should also reflect additional data
  reg [DATA_WD:0] data_reg1;
  reg [DWEN_WD:0] dwen_reg1;
    always@(posedge core_aclk or negedge core_rstn)
  begin: data1
    if(!core_rstn) begin
        data_reg1     <= #TP 0;
        dwen_reg1     <= #TP 0;
      end else if (dwn_strm_pkt_halt) begin// holds the value if there is a downstream pkt halt
        data_reg1     <= #TP data_reg1;
        dwen_reg1     <= #TP dwen_reg1;
      end else if (inbd_hdr_pnp_dv) begin
        data_reg1     <= #TP inbd_data_pnp_int;
        dwen_reg1     <= #TP inbd_hdr_pnp_dwen;
      end
  end

 assign  inbd_data_pnp_mod_int = (inbd_hdr_pnp_hv_no_halt) ? s_msg_uppr_bytes : data_reg1 ;
 assign  inbd_hdr_pnp_mod_dwen = (inbd_hdr_pnp_hv_no_halt) ? {{DWEN_WD{1'b1}},1'b1} : dwen_reg1 ;
  // EOT delayed 1 cycle for MsgDs, Not delayed for Msgs
  // The feed to the register needs to be reset
  // 1. When halt is set by msg_hdlr to not take in the value of EOT in the next halted packet at the interface
  // 2. in the case of non-translated TLPs
 assign s_eot_reg = (s_msg|| inbd_halt_pnp_mod_int || (!inbd_hdr_pnp_hdr_uppr_bytes_valid))? 1'b0 : inbd_hdr_pnp_eot ;
     always@(posedge core_aclk or negedge core_rstn)
  begin: eot1
    if(!core_rstn) begin
        eot_reg1     <= #TP 0;
      end else if (dwn_strm_pkt_halt) begin// holds the value if there is a downstream pkt halt
        eot_reg1     <= #TP eot_reg1;
      end else begin
        eot_reg1     <= #TP s_eot_reg;
      end
  end

 assign  inbd_hdr_pnp_mod_eot = (s_msg)? inbd_hdr_pnp_eot : eot_reg1;

  // halt reflects the delay in EOT
 assign inbd_halt_pnp_mod_int = eot_reg1;
  // extend DV when halt is asserted and also when it is a messqage
 assign inbd_hdr_pnp_mod_dv = inbd_hdr_pnp_dv || inbd_halt_pnp_mod_int || s_msg;

  end else if (`CX_NW > 2) begin: databusGreaterThan64
  // length incremented by 2 DWs
    assign inbd_hdr_pnp_mod_len = inbd_hdr_pnp_len + {8'b0,2'b10};

  // halt required? If last beat of data has a hole worth 2DWs then halt is not required. For msgs without data it is explicit that halt is not required
    assign halt_required  = ((|inbd_hdr_pnp_len [(NW_LOG_2-1):0] == 1'b0)? 1'b1 : (`CX_NW - inbd_hdr_pnp_len [(NW_LOG_2-1) : 0] ) < 2 ) && !s_msg;
  // Msg header bytes embedded in the Least significant 64 bits of the first data beat
  reg [DATA_WD:0] data_reg1;
  reg [1:0] dwen_reg1;
  wire [MSG_UPPR_BYTES_HIGH : MSG_UPPR_BYTES_LOW] data_MS2DW; // Most significant 2 DWs of data
  wire [(CORE_REQ_DATA_BUS_WD-1-INBD_MSG_HDR_WD):0] data_LSDW; // Least significant DWs of data
  wire [CORE_REQ_DATA_BUS_WD-1:0] inbd_data_pnp_mod_int1;
  wire [DWEN_WD:0]  inbd_hdr_pnp_mod_dwen1;



  assign data_MS2DW = inbd_data_pnp_int [(CORE_REQ_DATA_BUS_WD-1) : (CORE_REQ_DATA_BUS_WD-1-MSG_UPPR_BYTES_HIGH)];
  assign data_LSDW = inbd_data_pnp_int [(CORE_REQ_DATA_BUS_WD-1-INBD_MSG_HDR_WD) : 0 ];
    always@(posedge core_aclk or negedge core_rstn)
  begin: data1
    if(!core_rstn) begin
        data_reg1     <= #TP 0;
        dwen_reg1     <= #TP 0;
      end else if (dwn_strm_pkt_halt) begin// holds the value if there is a downstream pkt halt
        data_reg1     <= #TP data_reg1;
        dwen_reg1     <= #TP dwen_reg1;
      end else if (inbd_hdr_pnp_dv) begin
        data_reg1     <= #TP data_MS2DW;
        dwen_reg1     <= #TP inbd_hdr_pnp_dwen[DWEN_WD: (DWEN_WD-1) ];
      end
  end

 assign  inbd_data_pnp_mod_int1 = (inbd_hdr_pnp_hv_no_halt) ? {data_LSDW, s_msg_uppr_bytes} : {data_LSDW,data_reg1} ;
 assign  inbd_hdr_pnp_mod_dwen1 = (inbd_hdr_pnp_hv_no_halt) ? {inbd_hdr_pnp_dwen [(DWEN_WD-2):0], 2'b11} : {inbd_hdr_pnp_dwen [(DWEN_WD-2):0],dwen_reg1} ;

 // last extra beat modfication on data and DWEN (case when there is an extra beat due to the additional msg_uppr_bytes in the data payload)
  // depending on odd or even parity mode, generating the rest of the data bus for extra beat due to halt
  wire [CORE_REQ_DATA_BUS_WD-2-MSG_UPPR_BYTES_HIGH : 0] filler;
    assign filler = (`CX_RAS_PARITY_MODE == 1)?  {((CORE_REQ_DATA_BUS_WD-1-MSG_UPPR_BYTES_HIGH)/(`CX_RAS_PROT_RANGE+1)) {{`CX_RAS_PROT_RANGE{1'b0}},1'b1} }     :   {((CORE_REQ_DATA_BUS_WD-1-MSG_UPPR_BYTES_HIGH)/(`CX_RAS_PROT_RANGE+1)) {{`CX_RAS_PROT_RANGE{1'b0}},1'b0} };

    assign  inbd_data_pnp_mod_int = (inbd_hdr_pnp_mod_eot & halt_required) ? {filler,data_reg1} : inbd_data_pnp_mod_int1 ;


 assign  inbd_hdr_pnp_mod_dwen = (inbd_hdr_pnp_mod_eot & halt_required) ? {{(DWEN_WD-1){1'b0}},dwen_reg1} : inbd_hdr_pnp_mod_dwen1;

 // EOT is delayed 1 cycle if halt_required = 1
 assign s_eot_reg = (halt_required && inbd_hdr_pnp_hdr_uppr_bytes_valid && !inbd_halt_pnp_mod_int)? inbd_hdr_pnp_eot : 1'b0 ;
     always@(posedge core_aclk or negedge core_rstn)
  begin: eot1
    if(!core_rstn) begin
        eot_reg1     <= #TP 0;
      end else if (dwn_strm_pkt_halt) begin// holds the value if there is a downstream pkt halt
        eot_reg1     <= #TP eot_reg1;
      end else begin
        eot_reg1     <= #TP s_eot_reg;
      end
  end

 assign inbd_hdr_pnp_mod_eot = (halt_required)? eot_reg1 : inbd_hdr_pnp_eot;
 // halt reflects the delay in EOT
 assign inbd_halt_pnp_mod_int = eot_reg1;
  // extend DV when halt is asserted and also when it is a messqage
 assign inbd_hdr_pnp_mod_dv = inbd_hdr_pnp_dv || inbd_halt_pnp_mod_int || s_msg;


  end
endgenerate

// Outputs

always@(*)
  begin:outputs
   // initial
   inbd_hdr_pnp_mod_int = inbd_hdr_pnp;
   // DV, EOT, DWEN, Length
   inbd_hdr_pnp_mod_int[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW] = inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW] && !inbd_halt_pnp_mod_int;
   inbd_hdr_pnp_mod_int[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW] = inbd_hdr_pnp_mod_dv;
   inbd_hdr_pnp_mod_int[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW] = inbd_hdr_pnp_mod_eot;
   inbd_hdr_pnp_mod_int[`INBD_HDR_PNP_RANGE_DWEN_HIGH : `INBD_HDR_PNP_RANGE_DWEN_LOW] = inbd_hdr_pnp_mod_dwen;
   inbd_hdr_pnp_mod_int[`INBD_HDR_PNP_RANGE_DW_LEN_HIGH:`INBD_HDR_PNP_RANGE_DW_LEN_LOW] =inbd_hdr_pnp_mod_len;
   inbd_hdr_pnp_mod_int[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW] = inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW] && !inbd_halt_pnp_mod_int;
   end
   // Final assign
   // Manipulated data from msg handler used only when TLP is Msg/MsgD and succussfully translated by the iATU
   // otherwise it is bypassed
   assign o_valid = (s_msg || s_msgd) & inbd_hdr_pnp_hdr_uppr_bytes_valid;
   // Header
   assign inbd_hdr_pnp_mod = (o_valid) ? inbd_hdr_pnp_mod_int : inbd_hdr_pnp;
   // Data
   assign inbd_data_pnp_mod =(o_valid) ? inbd_data_pnp_mod_int : inbd_data_pnp;
   // Halt
   assign inbd_halt_pnp_mod = ((o_valid) ? inbd_halt_pnp_mod_int : 1'b0) | dwn_strm_pkt_halt;


function automatic [71:0] add_msg_uppr_bytes_par;
input [63:0]   in_msg_uppr_bytes;
input [7:0]    in_par;
integer i, j;
begin
    add_msg_uppr_bytes_par = 64'h0;
    for (i=0; i<8; i=i+1) begin
       for (j=0; j<`CX_RAS_PROT_RANGE; j=j+1) begin
        add_msg_uppr_bytes_par[i*`CX_RAS_PROT_RANGE +j+i] = in_msg_uppr_bytes[i*`CX_RAS_PROT_RANGE +j];
       end
        add_msg_uppr_bytes_par[(i+1)*`CX_RAS_PROT_RANGE + i] = in_par[i];
    end
end
endfunction // add_msg_uppr_bytes_par

function automatic [`CX_RAS_PROT_RANGE -1:0] get_msg_uppr_bytes;
input [63:0]   vector;
input integer  index;

integer i;
begin
    get_msg_uppr_bytes = 0;
    for (i=`CX_RAS_PROT_RANGE -1; i>=0; i=i-1) begin
        get_msg_uppr_bytes[i] = vector[index*`CX_RAS_PROT_RANGE +i];
    end
end
endfunction // get_msg_uppr_bytes


`ifndef SYNTHESIS

`endif // SYNTHESIS

endmodule
