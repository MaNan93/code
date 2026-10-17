//======================================================================
// dwc_pcie_cfg_pkg.sv
//   Shared constants / types for the DWC_pcie native application BFM.
//   Both the interfaces and the BFM classes import this package, so the
//   virtual interfaces stay un-parameterised (no type-mismatch pain).
//======================================================================
package dwc_pcie_cfg_pkg;

  `include "dwc_pcie_bfm_defines.svh"

  parameter int DW       = `DWC_BFM_DW;     // datapath width (bits)
  parameter int NDW      = DW/32;           // DWORDs per beat
  parameter int NBYTES   = DW/8;            // bytes per beat
  parameter int LUT_ID_W = `DWC_BFM_LUT_ID_W;
  parameter int PRFX_W   = `DWC_BFM_PRFX_W;
  parameter int HDR_CYC  = `DWC_BFM_HDR_CYCLES;

  //--------------------------------------------------------------------
  // clienti_tlp_type / radm_trgt1_tlp_type
  //
  // !! The numeric encoding is configuration dependent and lives in the
  // !! "Signal Descriptions" chapter of the DWC_pcie Reference Manual.
  // !! The *names* below are the ones the Databook uses (MEM / MSG /
  // !! MSGD / CPL ...). Re-map the values against your RTL before use --
  // !! everything else in this BFM is encoding agnostic.
  //--------------------------------------------------------------------
  typedef enum bit [4:0] {
    DWC_TLP_MEM      = 5'h00,  // MRd / MWr        (fmt picks Rd vs Wr)
    DWC_TLP_MEMLK    = 5'h01,  // MRdLk
    DWC_TLP_IO       = 5'h02,  // IORd / IOWr
    DWC_TLP_CFG0     = 5'h04,  // CfgRd0 / CfgWr0
    DWC_TLP_CFG1     = 5'h05,  // CfgRd1 / CfgWr1
    DWC_TLP_MSG      = 5'h10,  // Msg   (fmt[1:0]=01, byte_len==0)
    DWC_TLP_MSGD     = 5'h11,  // MsgD  (fmt[1:0]=11, byte_len!=0)
    DWC_TLP_CPL      = 5'h0A,  // Cpl
    DWC_TLP_CPLD     = 5'h0B,  // CplD
    DWC_TLP_CPLLK    = 5'h0C,
    DWC_TLP_CPLDLK   = 5'h0D,
    DWC_TLP_FETCHADD = 5'h18,
    DWC_TLP_SWAP     = 5'h19,
    DWC_TLP_CAS      = 5'h1A
  } dwc_tlp_type_e;

  // Bit position inside radm_grant_tlp_type[2:0] / trgt1_radm_pkt_halt[2:0]
  // (DM Databook Figure 4-15: 0=P, 1=NP, 2=CPL)
  typedef enum int unsigned { FC_P = 0, FC_NP = 1, FC_CPL = 2 } dwc_fc_e;

  function automatic dwc_fc_e dwc_fc_of(dwc_tlp_type_e t, bit is_write);
    case (t)
      DWC_TLP_CPL, DWC_TLP_CPLD,
      DWC_TLP_CPLLK, DWC_TLP_CPLDLK : return FC_CPL;
      DWC_TLP_MSG,  DWC_TLP_MSGD    : return FC_P;
      DWC_TLP_MEM, DWC_TLP_IO,
      DWC_TLP_CFG0, DWC_TLP_CFG1    : return is_write ? FC_P : FC_NP;
      DWC_TLP_MEMLK                 : return FC_NP;
      default                       : return FC_NP;  // atomics are NP
    endcase
  endfunction

  //--------------------------------------------------------------------
  // XALI header-signal bundle (one "struct view" of all clienti_* inputs
  // that must be stable for the whole TLP).
  //--------------------------------------------------------------------
  typedef struct packed {
    bit [4:0]           tlp_type;
    bit [2:0]           tlp_fmt;
    bit [63:0]          tlp_addr;
    bit [7:0]           tlp_byte_en;     // {LBE[3:0], FBE[3:0]}
    bit [12:0]          tlp_byte_len;
    bit [2:0]           tlp_tc;
    bit [2:0]           tlp_attr;
    bit                 tlp_td;
    bit                 tlp_ep;
    bit [1:0]           tlp_at;
    bit [9:0]           tlp_tid;
    bit [15:0]          remote_req_id;
    bit [4:0]           tlp_func_num;
    bit [7:0]           tlp_vfunc_num;
    bit                 tlp_vfunc_active;
    bit [2:0]           cpl_status;
    bit [12:0]          cpl_byte_cnt;
    bit [PRFX_W-1:0]    tlp_prfx;
    bit [LUT_ID_W-1:0]  cpl_lookup_id;
    bit                 addr_align_en;
    bit [2:0]           tlp_order_seqnum;   // MultiStream only
    bit [1:0]           tlp_segment;        // Flit mode only
    bit [1:0]           tlp_dst_segment;    // Flit mode only
  } dwc_xali_hdr_t;

  //--------------------------------------------------------------------
  // One clock cycle on XALI.  The driver is a pure beat pump: it pops one
  // of these per *non-halted* cycle, which is exactly the DWC handshake.
  //--------------------------------------------------------------------
  typedef struct {
    bit             idle;      // drive nothing this cycle (only legal between TLPs)
    bit             hv;
    bit             dv;
    bit             eot;
    bit             bad_eot;
    bit [DW-1:0]    data;
    dwc_xali_hdr_t  hdr;
  } dwc_xali_beat_t;

endpackage : dwc_pcie_cfg_pkg
