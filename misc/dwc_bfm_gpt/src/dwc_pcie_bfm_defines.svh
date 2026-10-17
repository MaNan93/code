//======================================================================
// dwc_pcie_bfm_defines.svh
//   Compile-time knobs for the DWC_pcie XALI / TRGT1 BFM.
//   Override from the command line, e.g.  +define+DWC_BFM_DW=512
//======================================================================
`ifndef DWC_PCIE_BFM_DEFINES_SVH
`define DWC_PCIE_BFM_DEFINES_SVH

// Controller datapath width in bits (64/128/256/512/1024).
`ifndef DWC_BFM_DW
  `define DWC_BFM_DW 256
`endif

// Width of trgt_lookup_id / clienti_cpl_lookup_id.
// = $clog2(CX_REMOTE_MAX_TAG) in the generated RTL.
`ifndef DWC_BFM_LUT_ID_W
  `define DWC_BFM_LUT_ID_W 8
`endif

// Width of clienti_tlp_prfx / radm_trgt1_tlp_prfx (E2E prefix bus).
`ifndef DWC_BFM_PRFX_W
  `define DWC_BFM_PRFX_W 32
`endif

// Set to 1 when CX_APP_VEC_EXTD_HDR_EN = 1 (header presented over 2 cycles,
// still consuming a single header token).  The BFM only supports 1 today;
// the knob exists so the assertions can be relaxed.
`ifndef DWC_BFM_HDR_CYCLES
  `define DWC_BFM_HDR_CYCLES 1
`endif

// Comment out / +define+DWC_BFM_NO_SVA to strip the embedded protocol checkers.
//`define DWC_BFM_NO_SVA

`endif // DWC_PCIE_BFM_DEFINES_SVH
