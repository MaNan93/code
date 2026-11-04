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
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/products/pcie_pkg.svh#14 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------

`ifndef __GUARD__PCIE_PKG__SVH__
`define __GUARD__PCIE_PKG__SVH__

`include "include/pcie_defs.svh"

package pcie_pkg;
    // -----------------------------------------------------------------------------
    // 1. Imports from other packages
    // -----------------------------------------------------------------------------

    // -----------------------------------------------------------------------------
    // 2. Parameter Declarations
    // -----------------------------------------------------------------------------
    localparam TLP_LOCAL_PRFX_MRIOV       = {`TLP_PRFX_FMT, 1'b0, `TLP_LP_MRIOV};
    localparam TLP_LOCAL_PRFX_FMPRFX      = {`TLP_PRFX_FMT, 1'b0, `TLP_LP_FMPRFX};
    localparam TLP_LOCAL_PRFX_VENDPRFXL0  = {`TLP_PRFX_FMT, 1'b0, `TLP_LP_VENDPRFXL0};
    localparam TLP_LOCAL_PRFX_VENDPRFXL1  = {`TLP_PRFX_FMT, 1'b0, `TLP_LP_VENDPRFXL1};
    localparam TLP_E2E_PRFX_TPH           = {`TLP_PRFX_FMT, 1'b1, `TLP_E2E_TPH};
    localparam TLP_E2E_PRFX_PASID         = {`TLP_PRFX_FMT, 1'b1, `TLP_E2E_PASID};
    localparam TLP_E2E_PRFX_IDE           = {`TLP_PRFX_FMT, 1'b1, `TLP_E2E_IDE};
    localparam TLP_E2E_PRFX_VENDPRFXE0    = {`TLP_PRFX_FMT, 1'b1, `TLP_E2E_VENDPRFXE0};
    localparam TLP_E2E_PRFX_VENDPRFXE1    = {`TLP_PRFX_FMT, 1'b1, `TLP_E2E_VENDPRFXE1};

    // -----------------------------------------------------------------------------
    // 3. Enumerated Declarations
    // -----------------------------------------------------------------------------
    typedef enum logic[1:0]{
      E_P          = 0,                                                 // Posted FC Type
      E_NP         = 1,                                                 // Non-Posted FC Type
      E_CPL        = 2,                                                 // Completion FC Type
      E_FC_NONE    = 3
    } fc_type_e;

    typedef enum logic {
      E_NFM        = 0,                                                 // Non-Flit Mode
      E_FM         = 1                                                  // Flit Mode
    } mode_e;

    typedef enum logic {
      E_ADDR32     = 0,                                                 // 32 Bit Addressing
      E_ADDR64     = 1                                                  // 64 Bit Addressing
    } addr_size_e;

    typedef enum logic [3:0] {
      E_TRANSNONE  = 0,                                                 // None
      E_MRD        = 1,                                                 // Memory Read
      E_MWR        = 2,                                                 // Memory Write
      E_DMWR       = 3,                                                 // Deferred Memory Read
      E_IORD       = 4,                                                 // IO Read
      E_IOWR       = 5,                                                 // IO Write
      E_CFGRD      = 6,                                                 // CFG Read
      E_CFGWR      = 7,                                                 // CFG Write
      E_MSG        = 8,                                                 // Message
      E_FETCHADD   = 9,                                                 // Fetch and Add AtomicOp Request
      E_SWAP       = 10,                                                // Unconditional Swap AtomicOp Request
      E_CAS        = 11                                                 // Compare and Swap AtomicOp Request
    } trans_type_e;

    typedef enum logic [1:0] {
      E_AT_UNTRANS                     = `DC_AT_UNTRANS,                // May be Virtual/Physical
      E_AT_TRANSREQ                    = `DC_AT_TRANS_REQ,              // Address is to be translated
      E_AT_TRANS                       = `DC_AT_TRANS,                  // Address has been translated
      E_AT_RSVD                        = `DC_AT_RSVRD
    } addr_type_e;

    typedef enum logic [2:0] {
      E_CPL_STATUS_SUCCESS             = 0,                             // Completion Successful
      E_CPL_STATUS_UNSUPPORTED_REQ     = 1,                             // Unsupported Request
      E_CPL_STATUS_RRS                 = 2,                             // Value not supported, malformed TLP
      E_CPL_STATUS_COMPLETER_ABORT     = 4,                             // Completer Abort
      E_CPL_STATUS_RESERVED                                             // All Others reserved
    } cpl_status_e;

    typedef enum logic [7:0] {
      E_TLP_LOCAL_PRFX_MRIOV           = TLP_LOCAL_PRFX_MRIOV,          // Local Prefix MR-IOV
      E_TLP_LOCAL_PRFX_FMPRFX          = TLP_LOCAL_PRFX_FMPRFX,         // Flit Mode Local Prefix
      E_TLP_LOCAL_PRFX_VENDPRFXL0      = TLP_LOCAL_PRFX_VENDPRFXL0,     // Vendor Defined Local TLP Prefix
      E_TLP_LOCAL_PRFX_VENDPRFXL1      = TLP_LOCAL_PRFX_VENDPRFXL1,     // Vendor Defined Local TLP Prefix
      E_TLP_E2E_PRFX_TPH               = TLP_E2E_PRFX_TPH,              // TPH End to End TLP Prefix
      E_TLP_E2E_PRFX_PASID             = TLP_E2E_PRFX_PASID,            // PASID End to End TLP Prefix
      E_TLP_E2E_PRFX_IDE               = TLP_E2E_PRFX_IDE,              // Identifies an IDE TLP
      E_TLP_E2E_PRFX_VENDPRFXE0        = TLP_E2E_PRFX_VENDPRFXE0,       // Vendor Defined End to End TLP Prefix
      E_TLP_E2E_PRFX_VENDPRFXE1        = TLP_E2E_PRFX_VENDPRFXE1,       // Vendor Defined End to End TLP Prefix
      E_TLP_PRFX_RESERVED                                               // All Others reserved
    } prfx_type_e;

    typedef enum logic [7:0] {
      E_MC_ASSERT_INTA                 = `ASSERT_INTA,                  // Assert Interrupt A
      E_MC_ASSERT_INTB                 = `ASSERT_INTB,                  // Assert Interrupt B
      E_MC_ASSERT_INTC                 = `ASSERT_INTC,                  // Assert Interrupt C
      E_MC_ASSERT_INTD                 = `ASSERT_INTD,                  // Assert Interrupt D
      E_MC_DEASSERT_INTA               = `DEASSERT_INTA,                // De-Assert Interrupt A
      E_MC_DEASSERT_INTB               = `DEASSERT_INTB,                // De-Assert Interrupt B
      E_MC_DEASSERT_INTC               = `DEASSERT_INTC,                // De-Assert Interrupt C
      E_MC_DEASSERT_INTD               = `DEASSERT_INTD,                // De-Assert Interrupt D
      E_MC_LTR_MSG_CODE                = `LTR_MSG_CODE,
      E_MC_PM_ACTIVE_STATE_NAK         = `PM_ACTIVE_STATE_NAK,
      E_MC_PM_PME                      = `PM_PME,
      E_MC_PME_TURN_OFF                = `PME_TURN_OFF,
      E_MC_PME_TO_ACK                  = `PME_TO_ACK,
      E_MC_OBFF                        = `OBFF,
      E_MC_ERR_COR                     = `ERR_COR,
      E_MC_ERR_NF                      = `ERR_NF,
      E_MC_ERR_F                       = `ERR_F,
      E_MC_UNLOCK                      = `UNLOCK,
      E_MC_SET_SLOT_PWR_LIMIT          = `SET_SLOT_PWR_LIMIT,
      E_MC_ATTENTION_INDICATOR_ON      = `ATTENTION_INDICATOR_ON,
      E_MC_ATTENTION_INDICATOR_BLINK   = `ATTENTION_INDICATOR_BLINK,
      E_MC_ATTENTION_INDICATOR_OFF     = `ATTENTION_INDICATOR_OFF,
      E_MC_POWER_INDICATOR_ON          = `POWER_INDICATOR_ON,
      E_MC_POWER_INDICATOR_BLINK       = `POWER_INDICATOR_BLINK,
      E_MC_POWER_INDICATOR_OFF         = `POWER_INDICATOR_OFF,
      E_MC_ATTENTION_BUTTON_PRESSED    = `ATTENTION_BUTTON_PRESSED,
      //E_MC_LATENCY_TOLERANCE_REPORTING = `LATENCY_TOLERANCE_REPORTING,
      E_MC_INVALIDATE_REQUEST          = `INVALIDATE_REQUEST,
      E_MC_INVALIDATE_COMPLETION       = `INVALIDATE_COMPLETION,
      E_MC_VENDOR_TYPE0                = `VENDOR_TYPE0,
      E_MC_VENDOR_TYPE1                = `VENDOR_TYPE1,
      E_MC_PTM_REQ_TYPE                = `PTM_REQ_TYPE,
      E_MC_PTM_RES_TYPE                = `PTM_RES_TYPE,
      E_MC_PRS_REQ_TYPE                = `PRS_REQ_TYPE,
      E_MC_PRG_RES_TYPE                = `PRG_RES_TYPE,
      E_MC_IDE_FAIL_MSG_TYPE           = `IDE_FAIL_MSG_TYPE,
      E_MC_IDE_SYNC_MSG_TYPE           = `IDE_SYNC_MSG_TYPE
    } msg_code_e;

    typedef enum logic [2:0] {
      E_MR_TO_RC                       = `MSG_ROUT_TO_RC,               // Routed to Root Complex
      E_MR_BY_ADDR                     = `MSG_ROUT_BY_ADDR,             // Routed by Address
      E_MR_BY_ID                       = `MSG_ROUT_BY_ID,               // Routed by ID
      E_MR_FROM_RC                     = `MSG_ROUT_FROM_RC,             // Broadcast from Root Complex
      E_MR_LOCAL                       = `MST_ROUT_LOCAL,               // Local - Terminate at Receiver
      E_MR_GATHERED                    = `MSG_ROUT_GATHER_TO_RC,        // Gathered and routed to Root Complex
      E_MR_RSVD_TERMINATE            //= `MSG_ROUT_RESERVED
    } msg_route_e;

    typedef enum {
      E_OHC_A1,
      E_OHC_A2,
      E_OHC_A3,
      E_OHC_A4,
      E_OHC_A5,
      E_OHC_A,                                                          // Amalgamated OHC_A
      E_OHC_B,
      E_OHC_C,
      E_OHC_E1,
      E_OHC_E2,
      E_OHC_E4,
      E_OHC_E                                                           // Amalgamated OHC_E
    } ohc_type_e;

    
    // -----------------------------------------------------------------------------
    // 4. Structure Declarations
    // -----------------------------------------------------------------------------

    // -----------------------------------------------------------------------------
    // Transaction Layer Structs
    // -----------------------------------------------------------------------------
    typedef struct packed {
      logic          [2:0] tlp_fmt;          // Format
      logic          [4:0] tlp_type;         // Type
      logic          [2:0] tlp_tc;           // Traffic Class
      logic                tlp_ln;           // Lightweight Notification
      logic                tlp_th;           // TLP Hints
      logic          [1:0] tlp_ph;           // Processing Hints 
      logic          [2:0] tlp_attr;         // Attributes
      logic                tlp_td;           // Digest
      logic                tlp_ep;           // Error Poisoned
      logic          [9:0] tlp_len;          // Length
      logic          [4:0] tlp_ohc;          // OHC Field
      logic          [2:0] tlp_ts;           // Trailer Size
      logic         [15:0] tlp_req_id;       // Requested ID
      logic         [15:0] tlp_cpl_id;       // Completer ID 
      logic         [13:0] tlp_tag;          // Tag
      logic          [3:0] tlp_fdw_be;       // First DW BE
      logic          [3:0] tlp_ldw_be;       // Last DW BE
      logic          [7:0] tlp_bn;           // Bus Number
      logic          [4:0] tlp_dn;           // Device Number
      logic          [7:0] tlp_fn;           // Function Number
      logic         [63:0] tlp_addr;         // Address
      logic          [1:0] tlp_at;           // Address Type
      logic         [15:0] tlp_dst_id;       // Destination ID
      logic          [1:0] tlp_ecs;          // Error Correctable Subclass
      logic          [3:0] tlp_ext_reg_num;  // External Register Number
      logic          [5:0] tlp_reg_num;      // Register Number
      logic          [2:0] tlp_cpl_status;   // Completion Status
      logic         [11:0] tlp_byte_count;   // Byte Count
      logic                tlp_bcm;          // Byte Count Modified
      logic         [15:0] tlp_vend_id;      // Vendor ID
      logic          [7:0] tlp_subtype;      // Subtype
      logic         [38:0] tlp_vend_def;     // Vendor Definition
      logic          [3:0] tlp_frs_rsn;      // Function Readiness Status Reason Indication
      logic         [15:0] tlp_hier_id;      // Hierarchy ID
      logic          [7:0] tlp_guid_auth_id; // GUID Authority ID
      logic         [15:0] tlp_system_guid;  // System GUID
      logic         [15:0] no_snoop_latency; // No-Snoop Latency
      logic         [15:0] snoop_latency;    // Snoop Latency
      logic          [3:0] tlp_obff_code;    // Optimized Buffer Flush/Fill Code
      logic         [63:0] ptm_master_time;  // Precision Time Measurement Master Time
//    logic         [31:0] ptm_prop_delay;   // Precision Time Measurement Propogation Delay - outside 4DW Header range
      logic         [63:0] tlp_page_address; // Page Request Message Address
      logic          [3:0] tlp_response_code;// Response type of Page Request Group 
      logic          [8:0] tlp_prg_index;    // Page Request Group Function supplied index to which the RC is responding
      logic          [2:0] tlp_cc;           // Completion Count
      logic          [4:0] tlp_itag;         // Invalidate Request Tag
      logic         [31:0] tlp_itag_vector;  // ITag Vector field to indicate which Invalidate Request has been completed
      logic          [7:0] tlp_msg_code;     // Message Code
      logic                tlp_nw;           // No Write
      logic                tlp_cxlsrc;       // Src CXL
      logic                tlp_pv;           // PASID Valid
      logic                tlp_pmr;          // Privileged Mode Request
      logic                tlp_er;           // Execute Requested
      logic         [19:0] tlp_pasid;        // PASID
      logic          [7:0] tlp_dst_seg;      // Destination Segment
      logic                tlp_dsv;          // Destination Segment Valid
      logic          [7:0] tlp_cpl_seg;      // Completer Segment
      logic         [15:0] tlp_st;           // Steering Tag
      logic          [1:0] tlp_hv;           // Hints Valid
      logic          [2:0] tlp_ama;          // ATS Memory Attributes
      logic                tlp_av;           // AMA Valid
      logic          [7:0] tlp_req_seg;      // Requester Segment
      logic          [7:0] tlp_pr_sent_cnt;  // PR Sent Counter
      logic          [7:0] tlp_pr_sent_counter_cpl; // Count of Posted Requests Transmitted since the last Completion or IDE Sync Message was Transmitted
      logic          [7:0] tlp_pr_sent_counter_npr; // Count of Posted Requests Transmitted since the last Non-Posted Request or IDE Sync Message was Transmitted
      logic         [15:0] tlp_destination_rid;     // IDE Destination RID 
      logic          [7:0] tlp_ide_stream_id;// The Stream ID associated with this Link IDE Stream
      logic          [7:0] tlp_stream_id;    // Stream ID
      logic          [3:0] tlp_sub_stream;   // Sub Stream
      logic                tlp_p;            // PCRC present
      logic                tlp_m;            // MAC present
      logic                tlp_k;            // Key Set
      logic                tlp_t;            // Trusted
      logic                tlp_rsv;          // Requester Segment Valid
      logic    [3:0][31:0] tlp_ohc_e;        // OHC-E
      logic         [31:0] data_pyld_32;     // generic data payload field for some message types 
      // reserved hdr fields
    } tlp_hdr_pkt_s;

    typedef struct packed {
      mode_e               mode;
      fc_type_e            fc_type;
      addr_size_e          addr_size;
      trans_type_e         trans_type;
      msg_code_e           msg_code;
      logic                payload;
    } tlp_hdr_decode_s;

    // -----------------------------------------------------------------------------
    // Data Link Layer Structs
    // -----------------------------------------------------------------------------

    // -----------------------------------------------------------------------------
    // Physical Layer Structs
    // -----------------------------------------------------------------------------
     
    // -----------------------------------------------------------------------------
    // 5. Function Declarations
    // -----------------------------------------------------------------------------

    // -----------------------------------------------------------------------------
    // Decode TLP type
    // -----------------------------------------------------------------------------
    
    // Flit Mode Token (NOP, Prefix, Header or Suffix) extracted from type field
    typedef enum logic [1:0] {
        NOP_TKN, // No Operation
        PFX_TKN, // Prefix
        HDR_TKN  // First base Header DW
//      SFX_TKN  // Suffix - Reserved in basespec
    } fm_tkn_t;

    // Decoded TLP type Struct
    typedef struct packed {
        reg  [2:0]  hdr_base_len;
        reg         payload;
        fc_type_e fc_type;
        fm_tkn_t tkn;
    } decoded_tlp_type_s;
    
    function automatic decoded_tlp_type_s f_decode_tlp_type (
        input [7:0] f_type,    // type field in Flit Mode, fmt&type fields in Non Flit Mode
        input       flit_mode  // 0: Non Flit Mode, 1: Flit Mode Enabled
    );
    begin
        decoded_tlp_type_s o;
        o.hdr_base_len = 0;
        o.payload = 0;
        o.fc_type = E_FC_NONE;
        o.tkn = NOP_TKN;
        if (flit_mode) begin
            // Flit mode Header encoding
            unique casez(f_type)
                // Aligned with NCB-PCI Express Base 6.0r0.9 Draft Spec. 28-09-2021
                // Number    Type               Name            FC Type Pyld  hdr_base_len
                // 0         0 0 0 0 0 0 0 0    NOP             none    0     1
                8'b00000000 : begin o.tkn = NOP_TKN; o.hdr_base_len = 1; o.payload = 0;  o.fc_type = E_FC_NONE ; end
         
                // 1         0 0 0 0 0 0 0 1    MRdLk           NPR     0     3
                8'b00000001 : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 0;  o.fc_type = E_NP ; end
        
                // 2          0 0 0 0 0 0 1 0   IORd            NPR     0     3
                // 3          0 0 0 0 0 0 1 1   MRd             NPR     0     3
                8'b0000001? : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 0;  o.fc_type = E_NP ; end
        
                // 4          0 0 0 0 0 1 0 0   CfgRd0          NPR     0     3
                // 5          0 0 0 0 0 1 0 1   CfgRd1          NPR     0     3
                8'b0000010? : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 0;  o.fc_type = E_NP ; end
        
                // 6          0 0 0 0 0 1 1 0                   E_CPL     1     4
                // 7          0 0 0 0 0 1 1 1                   E_CPL     1     4
                8'b0000011? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 1;  o.fc_type = E_CPL ; end
                
                // 8          0 0 0 0 1 0 0 0                   PR      0     3
                // 9          0 0 0 0 1 0 0 1                   PR      0     3
                8'b0000100? : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 0;  o.fc_type = E_P ; end
                
                // 10         0 0 0 0 1 0 1 0   Cpl             E_CPL     0     3
                // 11         0 0 0 0 1 0 1 1   CplLk           E_CPL     0     3
                8'b0000101? : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 0;  o.fc_type = E_CPL ; end
                
                // 12-15      0 0 0 0 1 1 X X                   E_CPL     0     3
                8'b000011?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 0;  o.fc_type = E_CPL ; end
                
                // 16-19      0 0 0 1 0 0 X X                   NPR     1     5
                8'b000100?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 5; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 20-21      0 0 0 1 0 1 0 X                   NPR     1     5
                8'b0001010? : begin o.tkn = HDR_TKN; o.hdr_base_len = 5; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 22-23      0 0 0 1 0 1 1 X                   NPR     1     7
                8'b0001011? : begin o.tkn = HDR_TKN; o.hdr_base_len = 7; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 24         0 0 0 1 1 0 0 0                   E_CPL     0     7
                // 25         0 0 0 1 1 0 0 1                   E_CPL     0     7
                8'b0001100? : begin o.tkn = HDR_TKN; o.hdr_base_len = 7; o.payload = 0;  o.fc_type = E_CPL ; end
                
                // 26         0 0 0 1 1 0 1 0                   E_CPL     1     7
                // 27         0 0 0 1 1 0 1 1                   E_CPL     1     7
                8'b0001101? : begin o.tkn = HDR_TKN; o.hdr_base_len = 7; o.payload = 1;  o.fc_type = E_CPL ; end
                
                // 28-29      0 0 0 1 1 1 0 X                   NPR     0     3
                8'b0001110? : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 0;  o.fc_type = E_NP ; end
                
                // 30-31      0 0 0 1 1 1 1 X                   NPR     0     6
                8'b0001111? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 0;  o.fc_type = E_NP ; end
                
                // 32         0 0 1 0 0 0 0 0   MRd             NPR     0     4
                // 33         0 0 1 0 0 0 0 1   MRdLk           NPR     0     4
                // 34-35      0 0 1 0 0 0 1 X                   NPR     0     4
                8'b001000?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 0;  o.fc_type = E_NP ; end
                
                // 36-39      0 0 1 0 0 1 X X                   NPR     0     4
                8'b001001?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 0;  o.fc_type = E_NP ; end
                
                // 40-43      0 0 1 0 1 0 X X                   E_CPL     0     4
                8'b001010?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 0;  o.fc_type = E_CPL ; end
                
                // 44-45      0 0 1 0 1 1 0 X                   PR      0     4
                8'b0010110? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 0;  o.fc_type = E_P ; end
                
                // 46-47      0 0 1 0 1 1 1 X                   PR      0     5
                8'b0010111? : begin o.tkn = HDR_TKN; o.hdr_base_len = 5; o.payload = 0;  o.fc_type = E_P ; end
                
                // 48         0 0 1 1 0 0 0 0   Msg             PR      0     4
                // 49         0 0 1 1 0 0 0 1   Msg             PR      0     4
                // 50         0 0 1 1 0 0 1 0   Msg             PR      0     4
                // 51         0 0 1 1 0 0 1 1   Msg             PR      0     4
                // 52         0 0 1 1 0 1 0 0   Msg             PR      0     4
                // 53         0 0 1 1 0 1 0 1   Msg             PR      0     4
                // 54         0 0 1 1 0 1 1 0   Msg             PR      0     4
                // 55         0 0 1 1 0 1 1 1   Msg             PR      0     4
                8'b00110??? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 0;  o.fc_type = E_P ; end
                
                // 56-59      0 0 1 1 1 0 X X                   NPR     0     4
                8'b001110?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 0;  o.fc_type = E_NP ; end
                
                // 60-61      0 0 1 1 1 1 0 X                   NPR     0     4
                8'b0011110? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 0;  o.fc_type = E_NP ; end
                
                // 62-63      0 0 1 1 1 1 1 X                   NPR     0     5
                8'b0011111? : begin o.tkn = HDR_TKN; o.hdr_base_len = 5; o.payload = 0;  o.fc_type = E_NP ; end
                
                // 64         0 1 0 0 0 0 0 0   MWr             PR      1     3
                8'b01000000 : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 1;  o.fc_type = E_P ; end
                
                // 65         0 1 0 0 0 0 0 1                   PR      1     6
                8'b01000001 : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 1;  o.fc_type = E_P ; end
                
                // 66         0 1 0 0 0 0 1 0   IOWr            NPR     1     3
                8'b01000010 : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 67         0 1 0 0 0 0 1 1                   PR      1     6
                8'b01000011 : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 1;  o.fc_type = E_P ; end
                
                // 68         0 1 0 0 0 1 0 0   CfgWr0          NPR     1     3
                // 69         0 1 0 0 0 1 0 1   CfgWr1          NPR     1     3
                // 70         0 1 0 0 0 1 1 0                   NPR     1     3
                // 71         0 1 0 0 0 1 1 1                   NPR     1     3
                8'b010001?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 72         0 1 0 0 1 0 0 0                   E_CPL     1     3
                // 73         0 1 0 0 1 0 0 1                   E_CPL     1     3
                // 74         0 1 0 0 1 0 1 0   CplD            E_CPL     1     3
                // 75         0 1 0 0 1 0 1 1   CplDLk          E_CPL     1     3
                8'b010010?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 1;  o.fc_type = E_CPL ; end
                
                // 76         0 1 0 0 1 1 0 0   FetchAdd        NPR     1     3
                // 77         0 1 0 0 1 1 0 1   Swap            NPR     1     3
                8'b0100110? : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 78         0 1 0 0 1 1 1 0   CAS             NPR     1     3
                8'b01001110 : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 79         0 1 0 0 1 1 1 1                   PR      0     4
                8'b01001111 : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 0;  o.fc_type = E_P ; end
                
                // 80-83      0 1 0 1 0 0 X X                   NPR     1     6
                8'b010100?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 84-85      0 1 0 1 0 1 0 X                   NPR     1     6
                8'b0101010? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 86-87      0 1 0 1 0 1 1 X                   NPR     1     7
                8'b0101011? : begin o.tkn = HDR_TKN; o.hdr_base_len = 7; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 88-89      0 1 0 1 1 0 0 X                   PR      1     3
                8'b0101100? : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 1;  o.fc_type = E_P ; end
                
                // 90         0 1 0 1 1 0 1 0                   PR      1     4
                8'b01011010 : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 1;  o.fc_type = E_P ; end
                
                // 91         0 1 0 1 1 0 1 1   DMWr            NPR     1     3
                8'b01011011 : begin o.tkn = HDR_TKN; o.hdr_base_len = 3; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 92-93      0 1 0 1 1 1 0 X                   PR      1     4
                8'b0101110? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 1;  o.fc_type = E_P ; end
                
                // 94-95      0 1 0 1 1 1 1 X                   PR      1     5
                8'b0101111? : begin o.tkn = HDR_TKN; o.hdr_base_len = 5; o.payload = 1;  o.fc_type = E_P ; end
                
                // 96         0 1 1 0 0 0 0 0   MWr             PR      1     4
                // 97         0 1 1 0 0 0 0 1                   PR      1     4
                // 98-99      0 1 1 0 0 0 1 X                   PR      1     4
                // 100-103    0 1 1 0 0 1 X X                   PR      1     4
                8'b01100??? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 1;  o.fc_type = E_P ; end
                
                // 104-107    0 1 1 0 1 0 X X                   PR      1     4
                8'b011010?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 1;  o.fc_type = E_P ; end
                
                // 108        0 1 1 0 1 1 0 0   FetchAdd        NPR     1     4
                // 109        0 1 1 0 1 1 0 1   Swap            NPR     1     4
                // 110        0 1 1 0 1 1 1 0   CAS             NPR     1     4
                // 111        0 1 1 0 1 1 1 1                   NPR     1     4
                8'b011011?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 112        0 1 1 1 0 0 0 0   MsgD            PR      1     4
                // 113        0 1 1 1 0 0 0 1   MsgD            PR      1     4
                // 114        0 1 1 1 0 0 1 0   MsgD            PR      1     4
                // 115        0 1 1 1 0 0 1 1   MsgD            PR      1     4
                // 116        0 1 1 1 0 1 0 0   MsgD            PR      1     4
                // 117        0 1 1 1 0 1 0 1   MsgD            PR      1     4
                // 118        0 1 1 1 0 1 1 0   MsgD            PR      1     4
                // 119        0 1 1 1 0 1 1 1   MsgD            PR      1     4
                8'b01110??? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 1;  o.fc_type = E_P ; end
                
                // 120        0 1 1 1 1 0 0 0                   NPR     1     4
                // 121        0 1 1 1 1 0 0 1                   NPR     1     4
                // 122        0 1 1 1 1 0 1 0                   NPR     1     4
                // 123        0 1 1 1 1 0 1 1   DMWr            NPR     1     4
                // 124-127    0 1 1 1 1 1 X X                   NPR     1     4
                8'b01111??? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 128-135    1 0 0 0 0 X X X                   none    0     1
                8'b10000??? : begin o.tkn = PFX_TKN; o.hdr_base_len = 1; o.payload = 0;  o.fc_type = E_FC_NONE ; end
                
                // 136-139    1 0 0 0 1 0 X X                   none    0     1
                8'b100010?? : begin o.tkn = PFX_TKN; o.hdr_base_len = 1; o.payload = 0;  o.fc_type = E_FC_NONE ; end
                
                // 140        1 0 0 0 1 1 0 0                   none    0     1
                8'b10001100 : begin o.tkn = PFX_TKN; o.hdr_base_len = 1; o.payload = 0;  o.fc_type = E_FC_NONE ; end
                
                // 141        1 0 0 0 1 1 0 1   FlitModePrefix  none    0     1
                8'b10001101 : begin o.tkn = PFX_TKN; o.hdr_base_len = 1; o.payload = 0;  o.fc_type = E_FC_NONE ; end
                
                // 142        1 0 0 0 1 1 1 0   VendPrefixL0    none    0     1
                // 143        1 0 0 0 1 1 1 1   VendPrefixL1    none    0     1
                8'b1000111? : begin o.tkn = PFX_TKN; o.hdr_base_len = 1; o.payload = 0;  o.fc_type = E_FC_NONE ; end
                
                // 144-147    1 0 0 1 0 0 X X                   PR      0     4
                8'b100100?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 0;  o.fc_type = E_P ; end
                
                // 148-151    1 0 0 1 0 1 X X                   PR      0     5
                8'b100101?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 5; o.payload = 0;  o.fc_type = E_P ; end
                
                // 152-155    1 0 0 1 1 0 X X                   PR      0     6
                8'b100110?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 0;  o.fc_type = E_P ; end
                
                // 156-159    1 0 0 1 1 1 X X                   PR      0     7
                8'b100111?? : begin o.tkn = HDR_TKN; o.hdr_base_len = 7; o.payload = 0;  o.fc_type = E_P ; end
                
                // 160-167    1 0 1 0 0 X X X                   NPR     0     5
                8'b10100??? : begin o.tkn = HDR_TKN; o.hdr_base_len = 5; o.payload = 0;  o.fc_type = E_NP ; end
                
                // 168-169    1 0 1 0 1 0 0 X                   PR      0     6
                8'b1010100? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 0;  o.fc_type = E_P ; end
                
                // 170-171    1 0 1 0 1 0 1 X                   PR      0     7
                8'b1010101? : begin o.tkn = HDR_TKN; o.hdr_base_len = 7; o.payload = 0;  o.fc_type = E_P ; end
                
                // 172-173    1 0 1 0 1 1 0 X                   E_CPL     0     5
                8'b1010110? : begin o.tkn = HDR_TKN; o.hdr_base_len = 5; o.payload = 0;  o.fc_type = E_CPL ; end
                
                // 174-175    1 0 1 0 1 1 1 X                   E_CPL     0     6
                8'b1010111? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 0;  o.fc_type = E_CPL ; end
                
                // 176-183    1 0 1 1 0 X X X                   PR      1     5
                // 184-191    1 0 1 1 1 X X X                   PR      1     5
                8'b1011???? : begin o.tkn = HDR_TKN; o.hdr_base_len = 5; o.payload = 1;  o.fc_type = E_P ; end
                
                // 192-199    1 1 0 0 0 X X X                   NPR     0     6
                8'b11000??? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 0;  o.fc_type = E_NP ; end
                
                // 200-201    1 1 0 0 1 0 0 X                   NPR     0     7
                8'b1100100? : begin o.tkn = HDR_TKN; o.hdr_base_len = 7; o.payload = 0;  o.fc_type = E_NP ; end
                
                // 202-203    1 1 0 0 1 0 1 X                   E_CPL     1     5
                8'b1100101? : begin o.tkn = HDR_TKN; o.hdr_base_len = 5; o.payload = 1;  o.fc_type = E_CPL ; end
                
                // 204-205    1 1 0 0 1 1 0 X                   E_CPL     1     6
                8'b1100110? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 1;  o.fc_type = E_CPL ; end
                
                // 206-207    1 1 0 0 1 1 1 X                   PR      1     7
                8'b1100111? : begin o.tkn = HDR_TKN; o.hdr_base_len = 7; o.payload = 1;  o.fc_type = E_P ; end
                
                // 208-215    1 1 0 1 0 X X X                   PR      1     6
                // 216-223    1 1 0 1 1 X X X                   PR      1     6
                8'b1101???? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 1;  o.fc_type = E_P ; end
                
                // 224-225    1 1 1 0 0 0 0 X                   none    0     4
                8'b1110000? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 0;  o.fc_type = E_FC_NONE ; end
                
                // 226-227    1 1 1 0 0 0 1 X                   none    0     6
                8'b1110001? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 0;  o.fc_type = E_FC_NONE ; end
                
                // 228-229    1 1 1 0 0 1 0 X                   none    1     4
                8'b1110010? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 1;  o.fc_type = E_FC_NONE ; end
                
                // 230-231    1 1 1 0 0 1 1 X                   none    1     6
                8'b1110011? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 1;  o.fc_type = E_FC_NONE ; end
                
                // 232-239    1 1 1 0 1 X X X                   NPR     0     7
                8'b11101??? : begin o.tkn = HDR_TKN; o.hdr_base_len = 7; o.payload = 0;  o.fc_type = E_NP ; end
                
                // 240-241    1 1 1 1 0 0 0 X                   NPR     1     4
                8'b1111000? : begin o.tkn = HDR_TKN; o.hdr_base_len = 4; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 242-243    1 1 1 1 0 0 1 X                   NPR     1     5
                8'b1111001? : begin o.tkn = HDR_TKN; o.hdr_base_len = 5; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 244-245    1 1 1 1 0 1 0 X                   NPR     1     6
                8'b1111010? : begin o.tkn = HDR_TKN; o.hdr_base_len = 6; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 246-247    1 1 1 1 0 1 1 X                   NPR     1     7
                8'b1111011? : begin o.tkn = HDR_TKN; o.hdr_base_len = 7; o.payload = 1;  o.fc_type = E_NP ; end
                
                // 248-255    1 1 1 1 1 X X X                   PR      1     7
                8'b11111??? : begin o.tkn = HDR_TKN; o.hdr_base_len = 7; o.payload = 1;  o.fc_type = E_P ; end
        
            default : begin
                end
            endcase
        end else begin // !flit_mode
            // Legacy PCIe Header Encoding
            if (f_type[7]) begin
                if (f_type[6:5]==2'b00) // fmt=100 is prefix any other 1?? encoding is reserved
                    o.tkn = PFX_TKN;
            end else begin
                o.tkn = HDR_TKN;
                o.payload = f_type[6];
                o.hdr_base_len = (f_type[5])? 4 : 3;
                unique casez(f_type[6:0])
                    `IOWR,
                    `DMWR32,
                    `DMWR64,
                    `CFGWR1,
                    `CFGWR0,
                    `IORD,
                    `MRD32,
                    `MRD64,
                    `MRDLK32,
                    `MRDLK64,
                    `CFGRD1,
                    `CFGRD0,
                    `FETCHADD32,
                    `FETCHADD64,
                    `SWAP32,
                    `SWAP64,
                    `CAS32,
                    `CAS64           : o.fc_type = E_NP;
                    `CPL ,
                    `CPLD,
                    `CPLLK,
                    `CPLDLK          : o.fc_type = E_CPL;
                    `MWR32,
                    `MWR64,
                   {`MSG_4 ,3'b???},
                   {`MSGD_4,3'b???}  : o.fc_type = E_P;
                    default          : o.fc_type = E_FC_NONE; 
                endcase
            end
        end // flit_mode
        return o;
    end
    endfunction

    function automatic  f_decode_prfx_type (
        input [7:0] f_type,    // type field in Flit Mode, fmt&type fields in Non Flit Mode
        input       flit_mode  // 0: Non Flit Mode, 1: Flit Mode Enabled
    );
    begin
        f_decode_prfx_type = 1'b0;
        if (flit_mode) begin
            // Flit mode Header encoding
            unique casez(f_type)
                // Aligned with NCB-PCI Express Base 6.0r0.9 Draft Spec. 28-09-2021
                // Number    Type               Name            FC Type Pyld  hdr_base_len
                // 128-135    1 0 0 0 0 X X X                   none    0     1
                8'b10000??? : begin f_decode_prfx_type = 1'b1; end
                
                // 136-139    1 0 0 0 1 0 X X                   none    0     1
                8'b100010?? : begin f_decode_prfx_type = 1'b1; end
                
                // 140        1 0 0 0 1 1 0 0                   none    0     1
                8'b10001100 : begin f_decode_prfx_type = 1'b1; end
                
                // 141        1 0 0 0 1 1 0 1   FlitModePrefix  none    0     1
                8'b10001101 : begin f_decode_prfx_type = 1'b1; end
                
                // 142        1 0 0 0 1 1 1 0   VendPrefixL0    none    0     1
                // 143        1 0 0 0 1 1 1 1   VendPrefixL1    none    0     1
                8'b1000111? : begin f_decode_prfx_type = 1'b1; end
        
            default : begin
                end
            endcase
        end else begin // !flit_mode
            // Legacy PCIe Header Encoding
            if (f_type[7]) begin
                if (f_type[6:5]==2'b00) // fmt=100 is prefix any other 1?? encoding is reserved
                    f_decode_prfx_type = 1'b1;
            end
        end // flit_mode
        //return f_decode_prfx_type;
    end
    endfunction

    function automatic [2:0] f_decode_ohc_len (
        input [4:0] f_ohc  // OHC type
    );
        f_decode_ohc_len = f_ohc[0]           + // OHC-A    +1
                         f_ohc[1]           + // OHC-B    +1
                         f_ohc[2]           + // OHC-C    +1
                         f_ohc[3]           + // OHC-E1   +1
                         {f_ohc[4],1'b0}    + // OHC-E2   +2
                         (f_ohc[4:3]==2'b11); // OHC-E4   +1
    endfunction
    


    // -----------------------------------------------------------------------------
    // Transaction Layer Functions
    // -----------------------------------------------------------------------------

    ///////////////////////////////////////////////
    // Functions to determine FC Type (P/NP/CPL)
    ///////////////////////////////////////////////
    function automatic logic f_tlp_is_p (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      if (mode == E_NFM) begin
        f_tlp_is_p         = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type[4:3]} == `MSG_4  |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type[4:3]} == `MSGD_4 |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MWR32       |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MWR64);
      end else begin
        casez ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type})
          8'b0000100?  : f_tlp_is_p = 1'b1; // #8-9
          8'b001011??  : f_tlp_is_p = 1'b1; // #44-47
          8'b00110???  : f_tlp_is_p = 1'b1; // #48-55
          8'b0100000?  : f_tlp_is_p = 1'b1; // #64-65
          8'b01000011  : f_tlp_is_p = 1'b1; // #67
          8'b01001111  : f_tlp_is_p = 1'b1; // #79
          8'b0101100?  : f_tlp_is_p = 1'b1; // #88-89
          8'b01011010  : f_tlp_is_p = 1'b1; // #90
          8'b010111??  : f_tlp_is_p = 1'b1; // #92-95
          8'b01100???  : f_tlp_is_p = 1'b1; // #96-103
          8'b011010??  : f_tlp_is_p = 1'b1; // #104-107
          8'b01110???  : f_tlp_is_p = 1'b1; // #112-119
          8'b1001????  : f_tlp_is_p = 1'b1; // #144-159
          8'b101010??  : f_tlp_is_p = 1'b1; // #168-171
          8'b1011????  : f_tlp_is_p = 1'b1; // #176-191
          8'b1100111?  : f_tlp_is_p = 1'b1; // #206-207
          8'b1101????  : f_tlp_is_p = 1'b1; // #208-223
          8'b11111???  : f_tlp_is_p = 1'b1; // #248-255
          default      : f_tlp_is_p = 1'b0;
        endcase
      end
    endfunction // f_tlp_is_p

    function automatic logic f_tlp_is_np (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      if (mode == E_NFM) begin
        f_tlp_is_np        = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MRD32       |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MRD64       |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `DMWR32      |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `DMWR64      |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MRDLK32     |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MRDLK64     |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `IORD        |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `IOWR        |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGRD0      |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGWR0      |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGRD1      |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGWR1      |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `FETCHADD64  |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `FETCHADD32  |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `SWAP64      |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `SWAP32      |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CAS32       |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CAS64);
      end else begin
        casez ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type})
          8'b00000001  : f_tlp_is_np = 1'b1; // #1
          8'b0000001?  : f_tlp_is_np = 1'b1; // #2-3
          8'b0000010?  : f_tlp_is_np = 1'b1; // #4-5
          8'b00010???  : f_tlp_is_np = 1'b1; // #16-23
          8'b000111??  : f_tlp_is_np = 1'b1; // #28-31
          8'b00100???  : f_tlp_is_np = 1'b1; // #32-39
          8'b00111???  : f_tlp_is_np = 1'b1; // #56-63
          8'b01000010  : f_tlp_is_np = 1'b1; // #66
          8'b010001??  : f_tlp_is_np = 1'b1; // #68-71
          8'b0100110?  : f_tlp_is_np = 1'b1; // #76-77
          8'b01001110  : f_tlp_is_np = 1'b1; // #78
          8'b01010???  : f_tlp_is_np = 1'b1; // #80-87
          8'b01011011  : f_tlp_is_np = 1'b1; // #91
          8'b011011??  : f_tlp_is_np = 1'b1; // #108-111
          8'b01111???  : f_tlp_is_np = 1'b1; // #120-127
          8'b10100???  : f_tlp_is_np = 1'b1; // #160-167
          8'b11000???  : f_tlp_is_np = 1'b1; // #192-199
          8'b1100100?  : f_tlp_is_np = 1'b1; // #200-201
          8'b11101???  : f_tlp_is_np = 1'b1; // #232-239
          8'b11110???  : f_tlp_is_np = 1'b1; // #240-247
          default      : f_tlp_is_np = 1'b0;
        endcase
      end
    endfunction // f_tlp_is_np

    function automatic logic f_tlp_is_cpl (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      if (mode == E_NFM) begin
        f_tlp_is_cpl       = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CPLLK       |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CPLDLK      |
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CPL         | 
                              {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CPLD);
      end else begin
        casez ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type})
          8'b0000011?  : f_tlp_is_cpl = 1'b1; // #6-7
          8'b0000101?  : f_tlp_is_cpl = 1'b1; // #10-11
          8'b000011??  : f_tlp_is_cpl = 1'b1; // #12-15
          8'b000110??  : f_tlp_is_cpl = 1'b1; // #24-27
          8'b001010??  : f_tlp_is_cpl = 1'b1; // #40-43
          8'b010010??  : f_tlp_is_cpl = 1'b1; // #72-75
          8'b101011??  : f_tlp_is_cpl = 1'b1; // #172-175
          8'b1100101?  : f_tlp_is_cpl = 1'b1; // #202-203
          8'b1100110?  : f_tlp_is_cpl = 1'b1; // #204-205
          default      : f_tlp_is_cpl = 1'b0;
        endcase
      end
    endfunction // f_tlp_is_cpl

    function automatic logic f_tlp_is_cpld (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_cpld      = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CPLDLK      |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CPLD);
    endfunction // f_tlp_is_cpld

    ///////////////////////////////////////////////
    // Functions to determine Transaction Types
    ///////////////////////////////////////////////
    function automatic logic f_tlp_is_nop (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_nop       = ((mode == E_FM) & ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `FLIT_NOP));
    endfunction // f_tlp_is_nop

    function automatic logic f_tlp_is_memrd (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_memrd     = (((mode == E_FM)  & ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `FLIT_MRD32)) |
                            ((mode == E_NFM) & ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MRD32))      |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MRD64                            |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MRDLK32                          |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MRDLK64);
    endfunction // f_tlp_is_memrd

    function automatic logic f_tlp_is_memwr (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_memwr     = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MWR32       |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `MWR64);
    endfunction // f_tlp_is_memwr

    function automatic logic f_tlp_is_defmemwr (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_defmemwr  = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `DMWR32      |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `DMWR64);
    endfunction // f_tlp_is_defmemwr

    function automatic logic f_tlp_is_mem (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_mem       = f_tlp_is_memrd(mode, tlp_hdr_pkt)                            |
                           f_tlp_is_memwr(mode, tlp_hdr_pkt)                            |
                           f_tlp_is_defmemwr(mode, tlp_hdr_pkt);
    endfunction // f_tlp_is_mem

    function automatic logic f_tlp_is_iord (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_iord      = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `IORD);
    endfunction // f_tlp_is_iord

    function automatic logic f_tlp_is_iowr (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_iowr      = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `IOWR);
    endfunction // f_tlp_is_iowr

    function automatic logic f_tlp_is_io (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_io        = f_tlp_is_iowr (mode, tlp_hdr_pkt)                            |
                           f_tlp_is_iord (mode, tlp_hdr_pkt);
    endfunction // f_tlp_is_io

    function automatic logic f_tlp_is_cfgrd (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_cfgrd     = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGRD1      |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGRD0);
    endfunction // f_tlp_is_cfgrd
    
    function automatic logic f_tlp_is_cfgwr (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_cfgwr     = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGWR1      |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGWR0);
    endfunction // f_tlp_is_cfgwr

    function automatic logic f_tlp_is_cfg0 (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_cfg0      = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGWR0      |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGRD0);
    endfunction // f_tlp_is_cfg0

    function automatic logic f_tlp_is_cfg1 (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_cfg1      = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGWR1      |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CFGRD1);
    endfunction // f_tlp_is_cfg1

    function automatic logic f_tlp_is_cfg (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_cfg       = f_tlp_is_cfg0( mode, tlp_hdr_pkt )                           |
                           f_tlp_is_cfg1( mode, tlp_hdr_pkt );
    endfunction // f_tlp_is_cfg

    function automatic logic f_tlp_is_msg (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_msg       = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type[4:3]} == `MSG_4  |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type[4:3]} == `MSGD_4);
    endfunction // f_tlp_is_msg

    function automatic logic f_tlp_is_msgd (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_msgd      = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type[4:3]} == `MSGD_4);
    endfunction // f_tlp_is_msgd

    function automatic logic f_tlp_is_fetchaddr (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_fetchaddr = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `FETCHADD64  |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `FETCHADD32);
    endfunction // f_tlp_is_fetchaddr

    function automatic logic f_tlp_is_swap (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_swap      = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `SWAP64      |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `SWAP32);
    endfunction // f_tlp_is_swap

    function automatic logic f_tlp_is_cas (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_cas       = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CAS64       |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CAS32);
    endfunction // f_tlp_is_cas

    function automatic logic f_tlp_is_atomic (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_atomic    = ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `FETCHADD32  |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `FETCHADD64  |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `SWAP32      |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `SWAP64      |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CAS64       |
                            {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type} == `CAS32);
    endfunction // f_tlp_is_atomic
 
    function automatic logic f_tlp_is_known (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_is_known     = f_tlp_is_np(mode, tlp_hdr_pkt)  |
                           f_tlp_is_p(mode, tlp_hdr_pkt)   |
                           f_tlp_is_cpl(mode, tlp_hdr_pkt) |
                           f_tlp_is_mem(mode, tlp_hdr_pkt) | 
                           f_tlp_is_io (mode, tlp_hdr_pkt) |
                           f_tlp_is_cfg(mode, tlp_hdr_pkt) |
                           f_tlp_is_msg(mode, tlp_hdr_pkt) |
                           f_tlp_is_atomic(mode, tlp_hdr_pkt); 
    endfunction // f_tlp_is_known

    //////////////////////////////////////////////////
    // Function to Determine TLP Address Size
    // Input : mode (mode_e), tlp_hdr_pkt (tlp_hdr_pkt_s)
    // Output: Size (addr_size_e)
    //////////////////////////////////////////////////
    function automatic addr_size_e f_tlp_addr_size (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      logic AddrSize;
      f_tlp_addr_size = addr_size_e'(tlp_hdr_pkt.tlp_fmt[0]);
    endfunction // f_tlp_addr_size

    //////////////////////////////////////////////////
    // Function to Determine if a TLP has a payload
    // Input : mode (mode_e), tlp_hdr_pkt (tlp_hdr_pkt_s)
    // Output: Yes/No (logic)
    //////////////////////////////////////////////////
    function automatic logic f_tlp_has_pyld (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      logic [2:0] tlp_fm_p_rsvd;
      logic [2:0] tlp_fm_np_rsvd;
      logic [1:0] tlp_fm_cpl_rsvd;
      if (mode == E_FM) begin
        if (f_tlp_is_p(mode, tlp_hdr_pkt)) begin
            // it's a posted TLP
            tlp_fm_p_rsvd = f_tlp_is_fm_p_rsvd(mode, tlp_hdr_pkt);
            if (tlp_fm_p_rsvd[1]) begin
                // it's a reserved posted TLP
                f_tlp_has_pyld = tlp_fm_p_rsvd[0];
            end else begin
                // it's not a reserved posted TLP
                f_tlp_has_pyld = tlp_hdr_pkt.tlp_fmt[1];
            end
        end else if (f_tlp_is_np(mode, tlp_hdr_pkt)) begin
            // it's a non-posted TLP
            tlp_fm_np_rsvd = f_tlp_is_fm_np_rsvd(mode, tlp_hdr_pkt);
            if (tlp_fm_np_rsvd[1]) begin
                // it's a reserved non-posted TLP
                f_tlp_has_pyld = tlp_fm_np_rsvd[0];
            end else begin
                // it's not a reserved non-posted TLP
                f_tlp_has_pyld = tlp_hdr_pkt.tlp_fmt[1];
            end
        end else if (f_tlp_is_cpl(mode, tlp_hdr_pkt)) begin
            // it's a completion TLP
            tlp_fm_cpl_rsvd = f_tlp_is_fm_cpl_rsvd(mode, tlp_hdr_pkt);
            if (tlp_fm_cpl_rsvd[1]) begin
                // it's a reserved completion TLP
                f_tlp_has_pyld = tlp_fm_cpl_rsvd[0];
            end else begin
                // it's not a reserved completion TLP
                f_tlp_has_pyld = tlp_hdr_pkt.tlp_fmt[1];
            end
        end else begin
            // FC type is NONE: all TLPs with FC=None are local (either reserved or not) prefixes or NOP
            f_tlp_has_pyld = 1'b0;
        end
      end else begin
          // Reserved not support for NFM
          f_tlp_has_pyld = tlp_hdr_pkt.tlp_fmt[1];
      end
       
    endfunction // f_tlp_has_pyld

    //////////////////////////////////////////////////
    // Function to Determine Message Code Type
    //////////////////////////////////////////////////
    function automatic msg_code_e f_tlp_msg_code (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      f_tlp_msg_code     = msg_code_e'(tlp_hdr_pkt.tlp_msg_code);
    endfunction // f_tlp_msg_code

    //////////////////////////////////////////////////
    // Function to Determine Message Routing Type
    //////////////////////////////////////////////////
    function automatic msg_route_e f_tlp_msg_routing (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      if ( f_tlp_is_msg (mode, tlp_hdr_pkt ) ) begin
        f_tlp_msg_routing = msg_route_e'(tlp_hdr_pkt.tlp_type[2:0]);
      end else begin
        f_tlp_msg_routing = E_MR_RSVD_TERMINATE;
      end
    endfunction // f_tlp_msg_routing

    //////////////////////////////////////////////////
    // Function to Decode an incoming TLP Packet
    // Input : mode (mode_e), tlp_hdr_pkt (tlp_hdr_pkt_s)
    // Output: tlp_hdr_decode (tlp_hdr_decode_s)
    //////////////////////////////////////////////////
    function automatic tlp_hdr_decode_s f_tlp_hdr_decode (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt
    );
      begin
        // 1. Mode
        f_tlp_hdr_decode.mode = mode;
        // 2. FC Type
        f_tlp_hdr_decode.fc_type = E_FC_NONE;
        if ( f_tlp_is_p  (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.fc_type = E_P;
        if ( f_tlp_is_np (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.fc_type = E_NP;
        if ( f_tlp_is_cpl(mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.fc_type = E_CPL;
        // 3. Address Size
        f_tlp_hdr_decode.addr_size = f_tlp_addr_size(mode, tlp_hdr_pkt);
        // 4. Tranaction Type
        f_tlp_hdr_decode.trans_type = E_TRANSNONE;
        if ( f_tlp_is_memrd    (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.trans_type = E_MRD;
        if ( f_tlp_is_memwr    (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.trans_type = E_MWR;
        if ( f_tlp_is_defmemwr (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.trans_type = E_DMWR;
        if ( f_tlp_is_iord     (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.trans_type = E_IORD;
        if ( f_tlp_is_iowr     (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.trans_type = E_IOWR;
        if ( f_tlp_is_cfgrd    (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.trans_type = E_CFGRD;
        if ( f_tlp_is_cfgwr    (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.trans_type = E_CFGWR;
        if ( f_tlp_is_msg      (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.trans_type = E_MSG;
        if ( f_tlp_is_fetchaddr(mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.trans_type = E_FETCHADD;
        if ( f_tlp_is_swap     (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.trans_type = E_SWAP;
        if ( f_tlp_is_cas      (mode, tlp_hdr_pkt) ) f_tlp_hdr_decode.trans_type = E_CAS;
        // 5. Message Code
        f_tlp_hdr_decode.msg_code = f_tlp_msg_code(mode, tlp_hdr_pkt);
        // 6. Payload
        f_tlp_hdr_decode.payload = f_tlp_has_pyld(mode, tlp_hdr_pkt);
      end
    endfunction // f_tlp_hdr_decode

    //////////////////////////////////////////////////
    // Function to Find OHC Locations
    // Input : tlp_hdr_pkt (tlp_hdr_pkt_s), ohc (ohc_type_e)
    // Output: location (int)
    //////////////////////////////////////////////////
    function automatic logic [3:0] f_locate_ohc (    
      input tlp_hdr_pkt_s tlp_hdr_pkt,
      input ohc_type_e    ohc_type
    );
      begin
        logic [3:0] ohc_a_loc;
        logic [3:0] ohc_b_loc;
        logic [3:0] ohc_c_loc;
        logic [3:0] ohc_e_loc;
        logic [2:0] useless_co;
        decoded_tlp_type_s decoded_tlp_type;
        decoded_tlp_type = f_decode_tlp_type({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type}, 1'b1);
        
                        ohc_a_loc  = {1'b0, decoded_tlp_type.hdr_base_len};
        {useless_co[0], ohc_b_loc} = {1'b0, ohc_a_loc} + {4'b0000, tlp_hdr_pkt.tlp_ohc[0]};
        {useless_co[1], ohc_c_loc} = {1'b0, ohc_b_loc} + {4'b0000, tlp_hdr_pkt.tlp_ohc[1]};
        {useless_co[2], ohc_e_loc} = {1'b0, ohc_c_loc} + {4'b0000, tlp_hdr_pkt.tlp_ohc[2]};

        f_locate_ohc = '0;
        if ((ohc_type == E_OHC_A1) | (ohc_type == E_OHC_A2) | (ohc_type == E_OHC_A3) | (ohc_type == E_OHC_A4) | (ohc_type == E_OHC_A5) | (ohc_type == E_OHC_A))
          f_locate_ohc = ohc_a_loc;
        if (ohc_type == E_OHC_B)
          f_locate_ohc = ohc_b_loc;
        if (ohc_type == E_OHC_C)
          f_locate_ohc = ohc_c_loc;
        if ((ohc_type == E_OHC_E1) | (ohc_type == E_OHC_E2) | (ohc_type == E_OHC_E4) | (ohc_type == E_OHC_E))
          f_locate_ohc = ohc_e_loc;
      end
    endfunction // f_locate_ohc

    //////////////////////////////////////////////////
    // Function to Extract an incoming TLP Packet
    // Input : mode (mode_e), tlp_prfx_dw, tlp hdr dw
    // Output: tlp_hdr_pkt (tlp_hdr_pkt_s)
    //////////////////////////////////////////////////
    function automatic tlp_hdr_pkt_s f_tlp_hdr_extract (
      input mode_e        mode,
      input  [7:0] [31:0] tlp_prfx_dw,
      input [15:0] [31:0] tlp_hdr_dw
    );
      begin
        tlp_hdr_pkt_s    tlp_hdr_pkt_int;
        tlp_hdr_decode_s tlp_hdr_decode_int;
        msg_route_e      msg_route;
        logic [3:0]      OHC_A;
        logic [3:0]      OHC_B;
        logic [3:0]      OHC_C;
        logic [3:0]      OHC_E;
        
        // Initialise to 0
        tlp_hdr_pkt_int    = '0;
        tlp_hdr_decode_int = '0;

        // Decode Fmt/Type
        {tlp_hdr_pkt_int.tlp_fmt, tlp_hdr_pkt_int.tlp_type} = tlp_hdr_dw[0][7:0];
         
        // Decode TLP Type
        tlp_hdr_decode_int = f_tlp_hdr_decode ( mode, tlp_hdr_pkt_int );

        // Decode Message Routing
        msg_route          = f_tlp_msg_routing( mode, tlp_hdr_pkt_int );

        // Decode Attr
        if ( mode == E_NFM) begin
          tlp_hdr_pkt_int.tlp_attr = {tlp_hdr_dw[0][10],tlp_hdr_dw[0][21:20]};
        end else begin
          tlp_hdr_pkt_int.tlp_attr = tlp_hdr_dw[0][20:18];
        end

        // Decode Traffic Class/TLP Hints
        if ( mode == E_NFM) begin
          tlp_hdr_pkt_int.tlp_tc   = tlp_hdr_dw[0][14:12];
          tlp_hdr_pkt_int.tlp_th   = tlp_hdr_dw[0][8];
        end else begin
          tlp_hdr_pkt_int.tlp_tc   = tlp_hdr_dw[0][15:13];
        end

        // Decode Trailer Size/OHC
        if ( mode == E_FM ) begin
          tlp_hdr_pkt_int.tlp_ts   = tlp_hdr_dw[0][23:21];
          tlp_hdr_pkt_int.tlp_ohc  = tlp_hdr_dw[0][12:8];
        end

        // Decode Length
        tlp_hdr_pkt_int.tlp_len[9:0] = {tlp_hdr_dw[0][17:16],tlp_hdr_dw[0][31:24]};

        // Decode AT
        if ( mode == E_NFM) begin
          tlp_hdr_pkt_int.tlp_at   = tlp_hdr_dw[0][19:18];
        end else begin
           if ((tlp_hdr_decode_int.trans_type == E_MRD) | (tlp_hdr_decode_int.trans_type == E_MWR) | (tlp_hdr_decode_int.trans_type == E_DMWR) |
            (tlp_hdr_decode_int.trans_type == E_FETCHADD) | (tlp_hdr_decode_int.trans_type == E_SWAP) | (tlp_hdr_decode_int.trans_type == E_CAS)) begin
             if (tlp_hdr_decode_int.addr_size == E_ADDR64) begin
               tlp_hdr_pkt_int.tlp_at   = tlp_hdr_dw[3][25:24];
             end else begin
               tlp_hdr_pkt_int.tlp_at   = tlp_hdr_dw[2][25:24];
             end
           end
        end
 
        // Decode EP
        if ( mode == E_NFM) begin
          tlp_hdr_pkt_int.tlp_ep   = tlp_hdr_dw[0][22];
        end else begin
          tlp_hdr_pkt_int.tlp_ep   = tlp_hdr_dw[1][23];
        end

        // Decode TLP Digest
        if ( mode == E_NFM) begin
          tlp_hdr_pkt_int.tlp_td   = tlp_hdr_dw[0][23];
        end else begin
          tlp_hdr_pkt_int.tlp_td   = tlp_hdr_pkt_int.tlp_ts[0]; // in case of FM so this value could be used in compressed hdr
        end

        // decode LN
        if (mode == E_NFM) begin
          tlp_hdr_pkt_int.tlp_ln   = tlp_hdr_dw[0][9];
        end

        // Decode TLP Address
        // if ((tlp_hdr_decode_int.trans_type == E_MRD)  | (tlp_hdr_decode_int.trans_type == E_MWR) | (tlp_hdr_decode_int.trans_type == E_DMWR) |
        //     (tlp_hdr_decode_int.trans_type == E_IORD) | (tlp_hdr_decode_int.trans_type == E_IOWR)) begin
        // we don't need condition on transaction type also there are messing transacrion types in this condition if used (E_FETCHADD | E_SWAP | E_CAS | E_CFGWR) 
        // we need to extract the whole address as it is to set upper hdr bytes
          if (tlp_hdr_decode_int.addr_size == E_ADDR64) begin
            tlp_hdr_pkt_int.tlp_addr[63:0] = {tlp_hdr_dw[2][7:0], tlp_hdr_dw[2][15:8], tlp_hdr_dw[2][23:16], tlp_hdr_dw[2][31:24], tlp_hdr_dw[3][7:0], tlp_hdr_dw[3][15:8], tlp_hdr_dw[3][23:16], tlp_hdr_dw[3][31:24]};
          end else if (tlp_hdr_decode_int.addr_size == E_ADDR32) begin
            tlp_hdr_pkt_int.tlp_addr[31:0] = {tlp_hdr_dw[2][7:0], tlp_hdr_dw[2][15:8], tlp_hdr_dw[2][23:16], tlp_hdr_dw[2][31:24]};
          end
        // end

        // Decode tlp_ph
        if (mode == E_NFM) begin
          if ((tlp_hdr_decode_int.trans_type == E_MRD)  | (tlp_hdr_decode_int.trans_type == E_MWR) | (tlp_hdr_decode_int.trans_type == E_DMWR)
               | (tlp_hdr_decode_int.trans_type == E_FETCHADD) | (tlp_hdr_decode_int.trans_type == E_SWAP) | (tlp_hdr_decode_int.trans_type == E_CAS)) begin
            if (tlp_hdr_pkt_int.tlp_th) begin
              if (tlp_hdr_decode_int.addr_size == E_ADDR64) begin
                tlp_hdr_pkt_int.tlp_ph = tlp_hdr_dw[3][25:24];
              end else if (tlp_hdr_decode_int.addr_size == E_ADDR32) begin
                tlp_hdr_pkt_int.tlp_ph = tlp_hdr_dw[2][25:24];
              end
            end
          end
        end

        // Decode BDF
        if ((tlp_hdr_decode_int.trans_type == E_CFGRD) | (tlp_hdr_decode_int.trans_type == E_CFGWR) | (tlp_hdr_decode_int.fc_type == E_CPL) |
           ((tlp_hdr_decode_int.trans_type == E_MSG) & (msg_route == E_MR_BY_ID))) begin
          tlp_hdr_pkt_int.tlp_bn = tlp_hdr_dw[2][7:0];
          tlp_hdr_pkt_int.tlp_dn = tlp_hdr_dw[2][15:11];  // Non-ARI ID Routing
          tlp_hdr_pkt_int.tlp_fn[2:0] = tlp_hdr_dw[2][10:8];
        end

        // Decode Requester ID
        if (tlp_hdr_decode_int.fc_type == E_CPL) begin
            tlp_hdr_pkt_int.tlp_req_id = {tlp_hdr_dw[2][7:0], tlp_hdr_dw[2][15:8]};
        end else begin
            tlp_hdr_pkt_int.tlp_req_id = {tlp_hdr_dw[1][7:0], tlp_hdr_dw[1][15:8]};
        end

        // Decode Completer ID
        if (tlp_hdr_decode_int.fc_type == E_CPL) begin
          tlp_hdr_pkt_int.tlp_cpl_id = {tlp_hdr_dw[1][7:0], tlp_hdr_dw[1][15:8]};
        end

        // Decode Destination ID
      //  if (mode == E_NFM) begin
          if ((tlp_hdr_decode_int.trans_type == E_CFGRD) | (tlp_hdr_decode_int.trans_type == E_CFGWR)) begin
            tlp_hdr_pkt_int.tlp_dst_id = {tlp_hdr_dw[2][7:0], tlp_hdr_dw[2][15:8]};
            tlp_hdr_pkt_int.tlp_ext_reg_num = tlp_hdr_dw[2][19:16];
            tlp_hdr_pkt_int.tlp_reg_num = tlp_hdr_dw[2][31:26];
     //     end
        end
        
        // Decode Tag
        if (tlp_hdr_decode_int.trans_type == E_MSG) begin // extract tag fields from messages
          if (mode == E_FM) begin
            tlp_hdr_pkt_int.tlp_tag = {7'b0, tlp_hdr_dw[1][22:16]};
          end else
            tlp_hdr_pkt_int.tlp_tag = {4'd0, {tlp_hdr_dw[0][15], tlp_hdr_dw[0][11], tlp_hdr_dw[1][23:16]}};
        end else if (tlp_hdr_decode_int.fc_type == E_CPL) begin // extract tag fields from CPL TLPs
          if (mode == E_NFM) begin
            tlp_hdr_pkt_int.tlp_tag = {4'd0, {tlp_hdr_dw[0][15], tlp_hdr_dw[0][11], tlp_hdr_dw[2][23:16]}};
          end else begin
            tlp_hdr_pkt_int.tlp_tag = {tlp_hdr_dw[1][21:16], tlp_hdr_dw[1][31:24]};
          end
        end else begin // extract tag fields from other requests
          if (mode == E_NFM) 
            tlp_hdr_pkt_int.tlp_tag = {4'd0, {tlp_hdr_dw[0][15], tlp_hdr_dw[0][11], tlp_hdr_dw[1][23:16]}};
          else 
            tlp_hdr_pkt_int.tlp_tag = {tlp_hdr_dw[1][21:16], tlp_hdr_dw[1][31:24]};
        end

        // decode byte count
        // synced with sw branch
        if (tlp_hdr_decode_int.fc_type == E_CPL) begin
          if (mode == E_FM) begin
            tlp_hdr_pkt_int.tlp_byte_count = {tlp_hdr_dw[2][19:16], tlp_hdr_dw[2][31:24]};
          end else begin
            tlp_hdr_pkt_int.tlp_byte_count = {tlp_hdr_dw[1][19:16], tlp_hdr_dw[1][31:24]};
          end
        end
         
        // decode BCM
        if (tlp_hdr_decode_int.fc_type == E_CPL) begin
          if (mode == E_NFM) begin
            tlp_hdr_pkt_int.tlp_bcm = tlp_hdr_dw[1][20];
          end
        end

        // Decode Message Code
        if (tlp_hdr_decode_int.trans_type == E_MSG) begin
          tlp_hdr_pkt_int.tlp_msg_code = tlp_hdr_dw[1][31:24];
        end

        // Locate OHCs
        OHC_A = f_locate_ohc(tlp_hdr_pkt_int, E_OHC_A);
        OHC_B = f_locate_ohc(tlp_hdr_pkt_int, E_OHC_B);
        OHC_C = f_locate_ohc(tlp_hdr_pkt_int, E_OHC_C);
        OHC_E = f_locate_ohc(tlp_hdr_pkt_int, E_OHC_E);

        // Decode Byte-Enables
        // For AtomicOp Requests and DMWr Requests the values for the DW BE fields are Reserved
        if ((tlp_hdr_decode_int.trans_type == E_FETCHADD) | (tlp_hdr_decode_int.trans_type == E_SWAP) | (tlp_hdr_decode_int.trans_type == E_CAS)) begin
            tlp_hdr_pkt_int.tlp_fdw_be = 4'h0;
            tlp_hdr_pkt_int.tlp_ldw_be = 4'h0;
        end else if ((tlp_hdr_decode_int.trans_type == E_MRD)  | (tlp_hdr_decode_int.trans_type == E_MWR) | (tlp_hdr_decode_int.trans_type == E_DMWR) |
            (tlp_hdr_decode_int.trans_type == E_IORD) | (tlp_hdr_decode_int.trans_type == E_IOWR) |
            (tlp_hdr_decode_int.trans_type == E_CFGRD) | (tlp_hdr_decode_int.trans_type == E_CFGWR)) begin
          if (mode == E_NFM) begin
            if (((tlp_hdr_decode_int.trans_type == E_MRD) | (tlp_hdr_decode_int.trans_type == E_DMWR)) & tlp_hdr_pkt_int.tlp_th) begin   // Inferred Values
              tlp_hdr_pkt_int.tlp_fdw_be = 4'b1111;
              tlp_hdr_pkt_int.tlp_ldw_be = (tlp_hdr_pkt_int.tlp_len == 9'd1) ? 4'b0000 : 4'b1111;
            end else begin
              tlp_hdr_pkt_int.tlp_ldw_be = tlp_hdr_dw[1][31:28];
              tlp_hdr_pkt_int.tlp_fdw_be = tlp_hdr_dw[1][27:24];
            end
          end
          if (mode == E_FM) begin
            if ( tlp_hdr_pkt_int.tlp_ohc[0]) begin
              tlp_hdr_pkt_int.tlp_ldw_be = tlp_hdr_dw[OHC_A][31:28];
              tlp_hdr_pkt_int.tlp_fdw_be = tlp_hdr_dw[OHC_A][27:24];
            end else begin
              tlp_hdr_pkt_int.tlp_fdw_be = 4'b1111;
              tlp_hdr_pkt_int.tlp_ldw_be = (tlp_hdr_pkt_int.tlp_len == 9'd1) ? 4'b0000 : 4'b1111;
            end
          end // E_FM
        end else if (tlp_hdr_decode_int.trans_type == E_MSG) begin // as message code is mapped to same fields of fdw and ldw byte enables to be send in compressed hdr
            tlp_hdr_pkt_int.tlp_ldw_be = tlp_hdr_dw[1][31:28];
            tlp_hdr_pkt_int.tlp_fdw_be = tlp_hdr_dw[1][27:24];
        end

        // Decode PASID
        if (mode == E_FM) begin
          if ( tlp_hdr_pkt_int.tlp_ohc[0]) begin
            if ((tlp_hdr_decode_int.trans_type == E_MRD)  | (tlp_hdr_decode_int.trans_type == E_MWR) | (tlp_hdr_decode_int.trans_type == E_DMWR) | (tlp_hdr_decode_int.trans_type == E_FETCHADD) | (tlp_hdr_decode_int.trans_type == E_SWAP) | (tlp_hdr_decode_int.trans_type == E_CAS) | ((tlp_hdr_decode_int.trans_type == E_MSG) & ((msg_route == E_MR_TO_RC) | (msg_route == E_MR_BY_ADDR)))) begin  // OHC-A1
              tlp_hdr_pkt_int.tlp_pasid = {tlp_hdr_dw[OHC_A][3:0], tlp_hdr_dw[OHC_A][15:8], tlp_hdr_dw[OHC_A][23:16]};
              tlp_hdr_pkt_int.tlp_pv    = tlp_hdr_dw[OHC_A][6];
              tlp_hdr_pkt_int.tlp_pmr   = tlp_hdr_dw[OHC_A][5];
              tlp_hdr_pkt_int.tlp_er    = tlp_hdr_dw[OHC_A][4]; 
            // adding routed by id messages for correct extraction of OHC-A4
            end else if ((tlp_hdr_decode_int.trans_type == E_MSG) & (msg_route == E_MR_BY_ID)) begin  // OHC-A4
              tlp_hdr_pkt_int.tlp_pasid = {tlp_hdr_dw[OHC_A][19:16], tlp_hdr_dw[OHC_A][15:8],tlp_hdr_dw[OHC_A][31:24]};
              tlp_hdr_pkt_int.tlp_pv    = tlp_hdr_dw[OHC_A][22];
              tlp_hdr_pkt_int.tlp_pmr   = tlp_hdr_dw[OHC_A][21];
            end
          end
        end

        // Decode Destination Segment
        if (mode == E_FM) begin
          if ( tlp_hdr_pkt_int.tlp_ohc[0]) begin
            if ((tlp_hdr_decode_int.trans_type == E_CFGRD)  | (tlp_hdr_decode_int.trans_type == E_CFGWR) |
                ((tlp_hdr_decode_int.trans_type == E_MSG) & (msg_route == E_MR_BY_ID))|  // extracting Destination Segment for routed by ID messages 
                (tlp_hdr_decode_int.fc_type == E_CPL)) begin
              tlp_hdr_pkt_int.tlp_dst_seg = tlp_hdr_dw[OHC_A][7:0];
              tlp_hdr_pkt_int.tlp_dsv     = tlp_hdr_dw[OHC_A][23];
            end
          end
        end

        // Decode NW
        if (mode == E_FM) begin
          if (tlp_hdr_decode_int.trans_type == E_MRD && (tlp_hdr_pkt_int.tlp_at == 2'b01) && (`CX_ATS_ENABLE_VALUE==1 || `CC_DEVICE_TYPE==3)) begin
            if ( tlp_hdr_pkt_int.tlp_ohc[0]) begin
              tlp_hdr_pkt_int.tlp_nw = tlp_hdr_dw[OHC_A][7];
            end
          end
        end else begin // NFM
          if (tlp_hdr_decode_int.trans_type == E_MRD && (tlp_hdr_pkt_int.tlp_at == 2'b01) && (`CX_ATS_ENABLE_VALUE==1 || `CC_DEVICE_TYPE==3)) begin 
            tlp_hdr_pkt_int.tlp_nw = (tlp_hdr_decode_int.addr_size == E_ADDR64) ? tlp_hdr_dw[3][24] : tlp_hdr_dw[2][24];
          end
        end

        // Decode CXLSrc
        if (tlp_hdr_decode_int.trans_type == E_MRD && (tlp_hdr_pkt_int.tlp_at == 2'b01) && (`CX_ATS_ENABLE_VALUE==1 || `CC_DEVICE_TYPE==3)) begin
          if (tlp_hdr_decode_int.addr_size == E_ADDR64)
            tlp_hdr_pkt_int.tlp_cxlsrc = tlp_hdr_dw[3][27];
          else
            tlp_hdr_pkt_int.tlp_cxlsrc = tlp_hdr_dw[2][27];
        end

        // Decode Completer Segment
        if (mode == E_FM) begin
          if ( tlp_hdr_pkt_int.tlp_ohc[0]) begin
            if (tlp_hdr_decode_int.fc_type == E_CPL) begin
              tlp_hdr_pkt_int.tlp_cpl_seg    = tlp_hdr_dw[OHC_A][15:8];
            end
          end
        end

        // Decode Completion Status
        if (tlp_hdr_decode_int.fc_type == E_CPL) begin
          if (mode == E_FM) begin
            if (tlp_hdr_pkt_int.tlp_ohc[0]) begin
              tlp_hdr_pkt_int.tlp_cpl_status = tlp_hdr_dw[OHC_A][26:24];
            end
          end else begin
            tlp_hdr_pkt_int.tlp_cpl_status = tlp_hdr_dw[1][23:21];
          end
        end

        // synced from sw branch
        // Decode TLP Lower Address (mapped on tlp_addr for CPL!)
        if (tlp_hdr_decode_int.fc_type == E_CPL) begin
          tlp_hdr_pkt_int.tlp_addr[6:0] = '0;
          if (mode == E_NFM) begin
            tlp_hdr_pkt_int.tlp_addr[6:0] = tlp_hdr_dw[2][30:24];
          end else begin
            tlp_hdr_pkt_int.tlp_addr[6] = tlp_hdr_dw[1][22];
            tlp_hdr_pkt_int.tlp_addr[5:2] = tlp_hdr_dw[2][23:20];
            if (tlp_hdr_pkt_int.tlp_ohc[0]) begin
              tlp_hdr_pkt_int.tlp_addr[1:0] = tlp_hdr_dw[OHC_A][28:27];
            end
          end
        end

        // Decode TPH
        if (mode == E_NFM) begin
          if (tlp_hdr_pkt_int.tlp_th) begin
            if (tlp_hdr_decode_int.trans_type == E_MWR) begin
              tlp_hdr_pkt_int.tlp_st[7:0] = tlp_hdr_dw[1][23:16];
            end else if ((tlp_hdr_decode_int.trans_type == E_MRD) | (tlp_hdr_decode_int.trans_type == E_DMWR) | 
                         (tlp_hdr_decode_int.trans_type == E_FETCHADD) | (tlp_hdr_decode_int.trans_type == E_SWAP) | (tlp_hdr_decode_int.trans_type == E_CAS)) begin
              tlp_hdr_pkt_int.tlp_st[7:0] = tlp_hdr_dw[1][31:24];
            end
          end
        end else begin
          if (tlp_hdr_pkt_int.tlp_ohc[1]) begin
            tlp_hdr_pkt_int.tlp_st  = {tlp_hdr_dw[OHC_B][15:8], tlp_hdr_dw[OHC_B][23:16]};
            tlp_hdr_pkt_int.tlp_ph  = tlp_hdr_dw[OHC_B][31:30];
            tlp_hdr_pkt_int.tlp_hv  = tlp_hdr_dw[OHC_B][29:28];
            tlp_hdr_pkt_int.tlp_ama = tlp_hdr_dw[OHC_B][27:25];
            tlp_hdr_pkt_int.tlp_av  = tlp_hdr_dw[OHC_B][24];
          end
        end

        // for TH extraction from ohc-b for FM
        if (mode == E_FM) begin
          tlp_hdr_pkt_int.tlp_th   = tlp_hdr_pkt_int.tlp_hv[0];
        end

        // Decode Requester Segment
        if (mode == E_FM) begin
          if (tlp_hdr_pkt_int.tlp_ohc[2]) begin
            tlp_hdr_pkt_int.tlp_req_seg = tlp_hdr_dw[OHC_C][7:0];
            tlp_hdr_pkt_int.tlp_rsv     = tlp_hdr_dw[OHC_C][27];
          end
        end

        // Decode IDE Info
        if (mode == E_FM) begin
          if (tlp_hdr_pkt_int.tlp_ohc[2]) begin
            tlp_hdr_pkt_int.tlp_sub_stream  = tlp_hdr_dw[OHC_C][31:28];
            if(tlp_hdr_pkt_int.tlp_sub_stream[2:0] != 7)begin
              tlp_hdr_pkt_int.tlp_pr_sent_cnt = tlp_hdr_dw[OHC_C][15:8];
              tlp_hdr_pkt_int.tlp_stream_id   = tlp_hdr_dw[OHC_C][23:16];
              tlp_hdr_pkt_int.tlp_k           = tlp_hdr_dw[OHC_C][25];
              tlp_hdr_pkt_int.tlp_t           = tlp_hdr_dw[OHC_C][24];
              tlp_hdr_pkt_int.tlp_m           = tlp_hdr_pkt_int.tlp_ts == 3'b110 || tlp_hdr_pkt_int.tlp_ts == 3'b101;
              tlp_hdr_pkt_int.tlp_p           = tlp_hdr_pkt_int.tlp_ts == 3'b110;
            end
          end
        end 
        if (mode == E_NFM) begin
          for (int i = 7; i >= 0; i--)begin
            if(tlp_prfx_dw[i][7:0] == TLP_E2E_PRFX_IDE)begin
              tlp_hdr_pkt_int.tlp_sub_stream    = tlp_prfx_dw[i][31:28];
              tlp_hdr_pkt_int.tlp_pr_sent_cnt   = tlp_prfx_dw[i][15:8];
              tlp_hdr_pkt_int.tlp_stream_id     = tlp_prfx_dw[i][23:16];
              tlp_hdr_pkt_int.tlp_k             = tlp_prfx_dw[i][25];
              tlp_hdr_pkt_int.tlp_t             = tlp_prfx_dw[i][24];
              tlp_hdr_pkt_int.tlp_m             = tlp_prfx_dw[i][26];
              tlp_hdr_pkt_int.tlp_p             = tlp_prfx_dw[i][27];
            end
          end
        end

    // spyglass disable_block ImproperRangeIndex-ML
    // SMD: INDEX larger than the bit width required for variable.
    // SJ: The index width is fixed to 4 and independent to the variable 
        // Decode OHC-E
        if (mode == E_FM) begin
            if (tlp_hdr_pkt_int.tlp_ohc[4:3] == 2'b11) begin //OHC-E4
                tlp_hdr_pkt_int.tlp_ohc_e[0] = tlp_hdr_dw[OHC_E];
                tlp_hdr_pkt_int.tlp_ohc_e[1] = tlp_hdr_dw[(OHC_E+1)];
                tlp_hdr_pkt_int.tlp_ohc_e[2] = tlp_hdr_dw[(OHC_E+2)];
                tlp_hdr_pkt_int.tlp_ohc_e[3] = tlp_hdr_dw[(OHC_E+3)];
            end else if (tlp_hdr_pkt_int.tlp_ohc[4:3] == 2'b10) begin //OHC-E2
                tlp_hdr_pkt_int.tlp_ohc_e[0] = tlp_hdr_dw[OHC_E];
                tlp_hdr_pkt_int.tlp_ohc_e[1] = tlp_hdr_dw[(OHC_E+1)];
            end else if (tlp_hdr_pkt_int.tlp_ohc[4:3] == 2'b01) begin //OHC-E1
                tlp_hdr_pkt_int.tlp_ohc_e[0] = tlp_hdr_dw[OHC_E];
            end             
        end
    // spyglass enable_block ImproperRangeIndex-ML

        
       // Decode ERR_COR Message - ERR_NONFATAL and ERR_FATAL do not have the ECS field
       if (tlp_hdr_pkt_int.tlp_msg_code[7:0] == 8'b00110000) begin
         tlp_hdr_pkt_int.tlp_ecs = {tlp_hdr_dw[2][7:6]};
       end

        
       // Decode Vendor ID (incl PCI SIG)
       if (tlp_hdr_pkt_int.tlp_msg_code[7:1] == 7'b0111111) begin
        tlp_hdr_pkt_int.tlp_dst_id = {tlp_hdr_dw[2][7:0], tlp_hdr_dw[2][15:8]};
        tlp_hdr_pkt_int.tlp_vend_id = {tlp_hdr_dw[2][23:16], tlp_hdr_dw[2][31:24]};
        tlp_hdr_pkt_int.tlp_subtype = {tlp_hdr_dw[3][7:0]};
        tlp_hdr_pkt_int.tlp_vend_def = {tlp_hdr_dw[1][22:16], tlp_hdr_dw[3][7:0], tlp_hdr_dw[3][15:8], tlp_hdr_dw[3][23:16], tlp_hdr_dw[3][31:24]};
       end
       
       // Decode LTR Message
       if (tlp_hdr_pkt_int.tlp_msg_code[7:0] == 8'b00010000) begin
        tlp_hdr_pkt_int.snoop_latency = {tlp_hdr_dw[3][23:16], tlp_hdr_dw[3][31:24]};
        tlp_hdr_pkt_int.no_snoop_latency = {tlp_hdr_dw[3][7:0], tlp_hdr_dw[3][15:8]};
       end
       
       // Decode OBFF Message
       if (tlp_hdr_pkt_int.tlp_msg_code[7:0] == 8'b00010010) begin
         tlp_hdr_pkt_int.tlp_obff_code = {tlp_hdr_dw[3][27:24]};
       end
       
       // Decode PTM ResponseD Message
       if (tlp_hdr_pkt_int.tlp_msg_code[7:0] == 8'b01010011) begin
        tlp_hdr_pkt_int.ptm_master_time = {tlp_hdr_dw[2][7:0], tlp_hdr_dw[2][15:8], tlp_hdr_dw[2][23:16], tlp_hdr_dw[2][31:24], tlp_hdr_dw[3][7:0], tlp_hdr_dw[3][15:8], tlp_hdr_dw[3][23:16], tlp_hdr_dw[3][31:24]};
//        tlp_hdr_pkt_int.ptm_prop_delay = {tlp_hdr_dw[4][7:0], tlp_hdr_dw[4][15:8], tlp_hdr_dw[4][23:16], tlp_hdr_dw[4][31:24]}; //outside 4DW Header range - straight swap, so not required
       end
       
       // Decode DRS, FRS, Heirarchy ID Message
       if (tlp_hdr_pkt_int.tlp_msg_code[7:0] == 8'b01111111) begin
         tlp_hdr_pkt_int.tlp_vend_id =  {tlp_hdr_dw[2][23:16], tlp_hdr_dw[2][31:24]};
       // FRS only
         tlp_hdr_pkt_int.tlp_frs_rsn = {tlp_hdr_dw[3][27:24]};
       // Hierarchy ID only
         tlp_hdr_pkt_int.tlp_hier_id =  {tlp_hdr_dw[2][7:0], tlp_hdr_dw[2][15:8]};
         tlp_hdr_pkt_int.tlp_guid_auth_id = {tlp_hdr_dw[3][15:8]};
         tlp_hdr_pkt_int.tlp_system_guid = {tlp_hdr_dw[3][23:16], tlp_hdr_dw[3][31:24]};
       end

        // Decode Invalidate Request Messages
       if (tlp_hdr_pkt_int.tlp_msg_code[7:0] == 8'b00000001) begin
         tlp_hdr_pkt_int.tlp_itag = {tlp_hdr_dw[1][20:16]};
       end

        // Decode Invalidate Completions Message
       if (tlp_hdr_pkt_int.tlp_msg_code[7:0] == 8'b00000010) begin
         tlp_hdr_pkt_int.tlp_cc = {tlp_hdr_dw[2][26:24]};
         tlp_hdr_pkt_int.tlp_itag_vector = {tlp_hdr_dw[3][7:0], tlp_hdr_dw[3][15:8], tlp_hdr_dw[3][23:16], tlp_hdr_dw[3][31:24]};
       end

       // Decode PRS Message
       if (tlp_hdr_pkt_int.tlp_msg_code[7:0] == 8'b00000100) begin
         tlp_hdr_pkt_int.tlp_page_address = {tlp_hdr_dw[2][7:0], tlp_hdr_dw[2][15:8], tlp_hdr_dw[2][23:16], tlp_hdr_dw[2][31:24], tlp_hdr_dw[3][7:0], tlp_hdr_dw[3][15:8], tlp_hdr_dw[3][23:16], tlp_hdr_dw[3][31:24]};
       end
       
       // Decode PRG Response Message
       if (tlp_hdr_pkt_int.tlp_msg_code[7:0] == 8'b00000101) begin
         tlp_hdr_pkt_int.tlp_dst_id = {tlp_hdr_dw[2][7:0], tlp_hdr_dw[2][15:8]};
         tlp_hdr_pkt_int.tlp_response_code = {tlp_hdr_dw[2][23:20]};
         tlp_hdr_pkt_int.tlp_prg_index = {tlp_hdr_dw[2][16], tlp_hdr_dw[2][31:24]};
       end
       
       // Decode Sync message (Link and Selective) IDE Stream
       if (tlp_hdr_pkt_int.tlp_msg_code[7:0] == 8'b01010100) begin
         tlp_hdr_pkt_int.tlp_pr_sent_counter_cpl = {tlp_hdr_dw[3][15:8]};
         tlp_hdr_pkt_int.tlp_pr_sent_counter_npr = {tlp_hdr_dw[3][31:24]};
       end
       
       // Decode IDE Fail Message (Link and Selective) IDE Stream
       if (tlp_hdr_pkt_int.tlp_msg_code[7:0] == 8'b01010101) begin
         tlp_hdr_pkt_int.tlp_ide_stream_id = {tlp_hdr_dw[2][31:24]};
       end
       
       // Decode IDE Selective IDE Stream
       if (tlp_hdr_pkt_int.tlp_msg_code[7:1] == 7'b0101010) begin
         tlp_hdr_pkt_int.tlp_destination_rid = {tlp_hdr_dw[2][7:0], tlp_hdr_dw[2][15:8]};
       end
        // extract reserved fields

// Assign Output
        f_tlp_hdr_extract = tlp_hdr_pkt_int;

      end
    endfunction // f_tlp_hdr_extract


    //////////////////////////////////////////////////
    // Functions to Decode incoming TLP Prefixes
    //////////////////////////////////////////////////
    function automatic logic f_tlp_prfx_is_local (
      input logic [7:0] prfx_type
    );
      f_tlp_prfx_is_local = (prfx_type[7:4] == 4'b1000);
    endfunction // f_tlp_prfx_is_local

    function automatic logic f_tlp_prfx_is_e2e (
      input logic [7:0] prfx_type
    );
      f_tlp_prfx_is_e2e   = (prfx_type[7:4] == 4'b1001);
    endfunction // f_tlp_prfx_is_e2e

    function automatic prfx_type_e f_tlp_prfx_decode (
      input logic [7:0] prfx_type
    );
      f_tlp_prfx_decode = prfx_type_e'(prfx_type);
    endfunction // f_tlp_prfx_decode


        //////////////////////////////////////////////////
        // Functions to Decode  reserved TLP per FC in FLIT mode 
        //////////////////////////////////////////////////

    // 0: P Request with Payload
    // 1: Reserved P
    // 2: Routed by Address (1), Routed by ID (0)
    function automatic logic [2:0] f_tlp_is_fm_p_rsvd ;
      input mode_e        mode;
      input tlp_hdr_pkt_s tlp_hdr_pkt;
      logic [2:0] tlp_fm_p_rsvd;
    
    begin
       casez ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type})
       8'b0000100?  : tlp_fm_p_rsvd = 3'b010; // 8-9       // Posted
       8'b0010110?  : tlp_fm_p_rsvd = 3'b010; // 44-45
       8'b0010111?  : tlp_fm_p_rsvd = 3'b010; // 46-47
       8'b0011011?  : tlp_fm_p_rsvd = 3'b010; // 54-55
       8'b01000001  : tlp_fm_p_rsvd = 3'b011; // 65
       8'b01000011  : tlp_fm_p_rsvd = 3'b011; // 67
       8'b01001111  : tlp_fm_p_rsvd = 3'b110; // 79
       8'b0101100?  : tlp_fm_p_rsvd = 3'b011; // 88-89
       8'b01011010  : tlp_fm_p_rsvd = 3'b111; // 90
       8'b0101110?  : tlp_fm_p_rsvd = 3'b011; // 92-93
       8'b0101111?  : tlp_fm_p_rsvd = 3'b011; // 94-95
       8'b01100001  : tlp_fm_p_rsvd = 3'b111; // 97
       8'b0110001?  : tlp_fm_p_rsvd = 3'b111; // 98-99
       8'b011001??  : tlp_fm_p_rsvd = 3'b111; // 100-103
       8'b011010??  : tlp_fm_p_rsvd = 3'b111; // 104-107
       8'b100100??  : tlp_fm_p_rsvd = 3'b110; // 144-147
       8'b100101??  : tlp_fm_p_rsvd = 3'b110; // 148-151
       8'b100110??  : tlp_fm_p_rsvd = 3'b110; // 152-155
       8'b100111??  : tlp_fm_p_rsvd = 3'b110; // 156-159
       8'b1010100?  : tlp_fm_p_rsvd = 3'b010; // 168-169
       8'b1010101?  : tlp_fm_p_rsvd = 3'b010; // 170-171
       8'b10110???  : tlp_fm_p_rsvd = 3'b111; // 176-183
       8'b10111???  : tlp_fm_p_rsvd = 3'b111; // 184-191
       8'b1100111?  : tlp_fm_p_rsvd = 3'b011; // 206-207
       8'b11010???  : tlp_fm_p_rsvd = 3'b111; // 208-215
       8'b11011???  : tlp_fm_p_rsvd = 3'b111; // 216-223
       8'b11111???  : tlp_fm_p_rsvd = 3'b111; // 248-255
       default: tlp_fm_p_rsvd = '0;
      endcase
       f_tlp_is_fm_p_rsvd = (mode == E_FM) ? tlp_fm_p_rsvd : '0;
     end
    endfunction // f_tlp_is_fm_p_reserved

    // 0: NP Request with Payload
    // 1: Reserved NP
    // 2: Routed by Address (1), Routed by ID (0)
    function automatic logic [2:0] f_tlp_is_fm_np_rsvd; 
      input mode_e        mode;
      input tlp_hdr_pkt_s tlp_hdr_pkt;
      logic [2:0] tlp_fm_np_rsvd;
    
      begin
         casez ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type})  
            8'b000100?? : tlp_fm_np_rsvd = 3'b111;  // 16-19     // Non-Posted
            8'b0001010? : tlp_fm_np_rsvd = 3'b111;  // 20-21
            8'b0001011? : tlp_fm_np_rsvd = 3'b111;  // 22-23
            8'b0001110? : tlp_fm_np_rsvd = 3'b010;  // 28-29
            8'b0001111? : tlp_fm_np_rsvd = 3'b010;  // 30-31
            8'b0010001? : tlp_fm_np_rsvd = 3'b110;  // 34-35
            8'b001001?? : tlp_fm_np_rsvd = 3'b110;  // 36-39
            8'b001110?? : tlp_fm_np_rsvd = 3'b110;  // 56-59
            8'b0011110? : tlp_fm_np_rsvd = 3'b010;  // 60-61
            8'b0011111? : tlp_fm_np_rsvd = 3'b010;  // 62-63
            8'b0100011? : tlp_fm_np_rsvd = 3'b011;  // 70-71
            8'b010100?? : tlp_fm_np_rsvd = 3'b111;  // 80-83
            8'b0101010? : tlp_fm_np_rsvd = 3'b111;  // 84-85
            8'b0101011? : tlp_fm_np_rsvd = 3'b111;  // 86-87
            8'b01101111 : tlp_fm_np_rsvd = 3'b111;  // 111
            8'b01111000 : tlp_fm_np_rsvd = 3'b111;  // 120
            8'b01111001 : tlp_fm_np_rsvd = 3'b111;  // 121
            8'b01111010 : tlp_fm_np_rsvd = 3'b111;  // 122
            8'b011111?? : tlp_fm_np_rsvd = 3'b111;  // 124-127
            8'b10100??? : tlp_fm_np_rsvd = 3'b110;  // 160-167
            8'b11000??? : tlp_fm_np_rsvd = 3'b110;  // 192-199
            8'b1100100? : tlp_fm_np_rsvd = 3'b010;  // 200-201
            8'b11101??? : tlp_fm_np_rsvd = 3'b110;  // 232-239
            8'b1111000? : tlp_fm_np_rsvd = 3'b011;  // 240-241
            8'b1111001? : tlp_fm_np_rsvd = 3'b011;  // 242-243
            8'b1111010? : tlp_fm_np_rsvd = 3'b011;  // 244-245
            8'b1111011? : tlp_fm_np_rsvd = 3'b011;  // 246-247
          default: tlp_fm_np_rsvd = '0;
         endcase
        f_tlp_is_fm_np_rsvd = (mode == E_FM) ? tlp_fm_np_rsvd : '0;
      end
    endfunction // f_tlp_is_fm_np_reserved

    // 0: Completion with Payload
    // 1: Reserved Completion
    function automatic logic [1:0] f_tlp_is_fm_cpl_rsvd; 
      input mode_e        mode;
      input tlp_hdr_pkt_s tlp_hdr_pkt;
      logic [1:0] tlp_fm_cpl_rsvd;
    begin
       casez ({tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type})  
          8'b0000011? : tlp_fm_cpl_rsvd = 2'b11;  // 6-7     
          8'b000011?? : tlp_fm_cpl_rsvd = 2'b10;  // 12-15    
          8'b00011000 : tlp_fm_cpl_rsvd = 2'b10;  // 24
          8'b00011001 : tlp_fm_cpl_rsvd = 2'b10;  // 25
          8'b00011010 : tlp_fm_cpl_rsvd = 2'b11;  // 26
          8'b00011011 : tlp_fm_cpl_rsvd = 2'b11;  // 27
          8'b001010?? : tlp_fm_cpl_rsvd = 2'b10;  // 40-43
          8'b01001000 : tlp_fm_cpl_rsvd = 2'b11;  // 72
          8'b01001001 : tlp_fm_cpl_rsvd = 2'b11;  // 73
          8'b1010110? : tlp_fm_cpl_rsvd = 2'b10;  // 172-173
          8'b1010111? : tlp_fm_cpl_rsvd = 2'b10;  // 174-175
          8'b1100101? : tlp_fm_cpl_rsvd = 2'b11;  // 202-203
          8'b1100110? : tlp_fm_cpl_rsvd = 2'b11;  // 204-205
          default : tlp_fm_cpl_rsvd = 2'b00;      
        endcase
       f_tlp_is_fm_cpl_rsvd = (mode == E_FM) ? tlp_fm_cpl_rsvd : 2'b00;
     end
    endfunction // f_tlp_is_fm_cpl_reserved

    function automatic logic f_tlp_is_ide;
      input mode_e        mode;
      input  [7:0] [31:0] tlp_prfx_dw;
      input tlp_hdr_pkt_s tlp_hdr_pkt;
    begin
      f_tlp_is_ide = 1'b0;
      if(mode == E_NFM)begin
        for(int i = 7; i >= 0; i--)begin
          if(tlp_prfx_dw[i][7:0] == TLP_E2E_PRFX_IDE)begin
            f_tlp_is_ide = 1'b1;
          end
        end
      end
      if(mode == E_FM)begin
        if(tlp_hdr_pkt.tlp_ohc[2] && tlp_hdr_pkt.tlp_sub_stream[2:0] != 3'd7)begin
          f_tlp_is_ide = 1'b1;
        end
      end
    end
    endfunction




    // -----------------------------------------------------------------------------
    // Data Link Layer Functions
    // -----------------------------------------------------------------------------

    // -----------------------------------------------------------------------------
    // Physical Layer Functions
    // -----------------------------------------------------------------------------
endpackage : pcie_pkg

`endif //__GUARD__PCIE_PKG__SVH__
