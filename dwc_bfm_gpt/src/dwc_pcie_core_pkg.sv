//======================================================================
// dwc_pcie_core_pkg.sv
//   Interface-independent half of the BFM: the TLP transaction object and
//   the pack/unpack helpers that implement Databook 4.1.3 (transmit
//   address alignment).  Kept separate from dwc_pcie_bfm_pkg so it can be
//   compiled -- and unit tested -- without any virtual interfaces.
//======================================================================
package dwc_pcie_core_pkg;

  import dwc_pcie_cfg_pkg::*;

  `include "dwc_tlp_item.svh"
  `include "dwc_bfm_util.svh"

endpackage : dwc_pcie_core_pkg
