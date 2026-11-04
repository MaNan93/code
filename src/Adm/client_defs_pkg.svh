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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/client_defs_pkg.svh#10 $
// -------------------------------------------------------------------------

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

`ifndef __GUARD__CLIENT_DEFS_PKG__SVH__
`define __GUARD__CLIENT_DEFS_PKG__SVH__


// -----------------------------------------------------------------------------
// --- Package Description: structure used on Xadm Client interface
// -----------------------------------------------------------------------------

package client_defs_pkg;

// -- LocalParam ------------------------------------------
localparam ATTR_WD      = `SF_HDR_TLP_ATTR;
localparam TAG_SIZE     = `CX_TAG_SIZE;
localparam LOOKUPID_WD  = `CX_REMOTE_LOOKUPID_WD;
localparam NW           = `CX_NW;
localparam DW           = (32*NW) + `TRGT_DATA_PROT_WD;   
localparam PF_WD        = `CX_NFUNC_WD;
localparam NF           = `CX_NFUNC;         // Number of functions
localparam NVC             = `CX_NVC;
localparam NW_PRFX      = `CX_NPRFX;
localparam PRFX_PAR_WD  = `CX_PRFX_PAR_WD;
localparam PRFX_DW      = (32*NW_PRFX)+ PRFX_PAR_WD;
localparam ATU_OUT_REGIONS = `CX_ATU_NUM_OUTBOUND_REGIONS;
localparam ATU_IN_REGIONS  = `CX_ATU_NUM_INBOUND_REGIONS;
localparam ATU_BASE_WD     = `CX_ATU_BASE_WIDTH;
localparam ATU_REG_WD      = `CX_ATU_REGION_WIDTH;
localparam ATU_UPR_LMT_WD  = `CX_ATU_MAX_REGION_SIZE;        // Width of Upper Limit Address register
localparam ATU_OUT_MIN1    = ATU_OUT_REGIONS > 0 ? ATU_OUT_REGIONS : 1;
localparam HDR_PROT_WD      = `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD; // XADM Common Header ecc/parity protection width

// -------------------------------------------------------

//TLP Header Fields --------------------------------------
typedef struct packed{
logic                  addr_align_en;        // 1-XADM will does address alignment, prempting ; 0-use client0_tlp_byte_en
logic [7:0]            tlp_byte_en;          // first/last byte enables per pcie spec, used only if client0_addr_align_en=0;
logic [15:0]           cpl_req_id;           // Completion's Requester's ID
logic [2:0]            cpl_status;           // Completion status
logic                  cpl_bcm;              // BCM bit (for Bridge only), tie LOW for EP
logic [11:0]           cpl_byte_cnt;         // Completion byte count
logic [15:0]           req_id;               // Curnt PCIE port's id

logic [TAG_SIZE-1:0]   tlp_tid;              // TLP Header TAG ID
logic [12:0]           tlp_byte_len;         // TLP Header Byte Length, 13'h0 for 0 byte, 13'h1000 for 4K bytes
logic [ATTR_WD-1:0]    tlp_attr;             // TLP Header Attibutes
logic                  tlp_ep;               // TLP Header EP
logic                  tlp_td;               // TLP Header digest
logic [2:0]            tlp_tc;               // TLP Header TC
logic [4:0]            tlp_type;             // TLP Header Type field
logic [1:0]            tlp_fmt;              // TLP Header Format
logic [63:0]           tlp_addr;             // TLP Header address
} hdr_struct;
//------------------------------------------------------------

// Client TLP sctructure ---------------------------------
typedef struct packed{

logic                  tlp_hv;               // Header valid
logic                  tlp_dv;               // TLP data valid
logic                  tlp_eot;              // end of TLP
logic                  tlp_bad_eot;          // BAD EOT

hdr_struct             hdr;

// RASDP Protect
logic [HDR_PROT_WD-1:0] hdr_prot;

// TLP Data ------------------------------------------------
logic [DW -1 :0]       tlp_data;             // TLP Data Payload

//TLP Others signals ---------------------------------------
logic                  tlp_is_msg_gen;
logic [1:0]            tlp_ats;
logic                  tlp_nw;
logic                  tlp_th;
logic [1:0]            tlp_ph;
logic [7:0]            tlp_st;
logic [2:0]            tlp_dma;
logic [2:0]            tlp_dma_channel;
logic [LOOKUPID_WD-1:0] cpl_lookup_id;        // This is the virtural ID designed for protocol between core and application to accomplish the target completion look up

logic [PRFX_DW-1:0]    tlp_prfx;
logic                  tlp_atu_bypass;         // Bypass the ATU for this TLP

logic [6:0]            client;             // identify External Clients:
                                           // bit0 - MSG GEN (Posted)
                                           // bit1 - CPL LBC (Completion)
                                           // bit2 - CLIENT0 
                                           // bit3 - CLIENT1 
                                           // bit4 - CLIENT2 
                                           // bit5 - Posted DMA
                                           // bit6 - Non-Posted DMA

} client_tlp; 
//----------------------------------------------------------------------------
// XADM Clients sctructure ---------------------------------
typedef struct {
logic                  rstctl_core_flush_req;
logic [23:0]           cfg_tc_vc_map;
logic [NF-1:0]         cfg_atomic_req_en;
logic [NF-1:0]         cfg_atomic_egress_block;
logic [NF-1:0]         cfg_dmwr_req_en;            // Deferrable Memory Write (DMWr) Requester Enable

logic [2:0]            cfg_max_payload_size;
logic                  rdlh_link_down;
} xadm_clients_cdts_upd_cfg_type;

typedef struct {
logic [ATU_BASE_WD*ATU_OUT_MIN1-1:0] atu_reg_out_upr_base;
logic [ATU_OUT_MIN1-1:0]             atu_reg_out_en;
logic [5*ATU_OUT_MIN1-1:0]           atu_reg_out_type;
logic [ATU_OUT_MIN1-1:0]             atu_reg_out_inhibit_payload;
logic [3*ATU_OUT_MIN1-1:0]           atu_reg_out_tc;
logic [ATU_REG_WD*ATU_OUT_MIN1-1:0]  atu_reg_out_base;
logic [ATU_REG_WD*ATU_OUT_MIN1-1:0]  atu_reg_out_limit;
logic [ATU_UPR_LMT_WD*ATU_OUT_MIN1-1:0] atu_reg_out_uppr_limit;
logic  [ATU_OUT_MIN1-1:0]            atu_reg_out_incr_rgn_size;    // Maximum region size control bit
logic [ATU_OUT_MIN1-1:0]             atu_reg_out_hdr_flds_bypass;  // TLP Header fields bypass control bit
logic [ATU_OUT_MIN1-1:0]             atu_reg_out_invert;
logic [ATU_OUT_MIN1-1:0]             atu_reg_out_dma_bypass;
} xadm_clients_atu_cfg_type;

typedef struct {
logic  [23:0]                                cfg_tc_struc_vc_map;
logic  [(3*NF)-1:0]                          cfg_max_rd_req_size;
logic  [(NVC*3*`CX_RADM_SBUF_HDRQ_PW)-1:0]   cfg_hq_depths;
logic  [(NVC*3*`CX_RADM_SBUF_DATAQ_PW)-1:0]  cfg_dq_depths;
logic                                        cfg_cplq_mng_en;
} xadm_clients_cplq_mng_cfg_type;

typedef struct {
logic         rdlh_link_down;
logic         rstctl_core_flush_req;
logic  [2:0]  cfg_max_payload_size;
} xadm_clients_credits_checker_cfg_type;

typedef struct {
logic [1:0]   xtlh_xadm_restore_ctrl;
logic         xtlh_xadm_restore_enable;
logic         xtlh_xadm_restore_capture;
logic [2:0]   xtlh_xadm_restore_tc;
logic [6:0]   xtlh_xadm_restore_type;
logic [9:0]   xtlh_xadm_restore_word_len;
} xadm_clients_restore_cdts_type;


typedef struct {
logic                      radm_trgt1_hv;
logic                      radm_trgt1_eot;
logic                      radm_trgt1_tlp_abort;
logic                      radm_trgt1_dllp_abort;
logic [1:0]                radm_trgt1_fmt;
logic [4:0]                radm_trgt1_type;
logic [9:0]                radm_trgt1_dw_len;
logic [6:0]                radm_trgt1_addr;
logic                      radm_trgt1_cpl_last;
logic [2:0]                radm_trgt1_cpl_status;
logic [11:0]               radm_trgt1_byte_cnt;

logic [2:0]                radm_trgt1_tc;
logic [TAG_SIZE-1:0]       radm_trgt1_tag;
logic                      trgt1_radm_halt;
} xadm_clients_cplq_mng_radm_trgt1_type;

typedef struct {
logic                      radm_cpl_timeout;
logic [11:0]               radm_timeout_cpl_byte_len;
logic [2:0]                radm_timeout_cpl_tc;
logic [TAG_SIZE-1:0]       radm_timeout_cpl_tag;
} xadm_clients_cplq_mng_cpl_timeout_type;




endpackage : client_defs_pkg

`endif // __GUARD__CLIENT_DEFS_PKG__SVH__
