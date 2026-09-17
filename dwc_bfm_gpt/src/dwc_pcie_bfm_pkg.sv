//======================================================================
// dwc_pcie_bfm_pkg.sv
//   Application-side BFM for the DesignWare DWC_pcie native (non-AXI)
//   client interfaces:  XALI0/1/2 (transmit) and TRGT1 (receive).
//
//   Written against the DM Controller Databook section 4.1 (Transmit
//   Interfaces), 4.6 (Receive Request Interface) and appendix U
//   (MultiStream architecture).  It is UVM-free on purpose; wrap the
//   driver/monitor classes in uvm_driver/uvm_monitor if you need it.
//
//   The interface-independent half (dwc_tlp_item, dwc_bfm_util) lives in
//   dwc_pcie_core_pkg so it can be unit tested on its own.
//======================================================================
package dwc_pcie_bfm_pkg;

  import dwc_pcie_cfg_pkg::*;
  import dwc_pcie_core_pkg::*;

  `include "dwc_xali_driver.svh"
  `include "dwc_xali_monitor.svh"
  `include "dwc_trgt1_receiver.svh"
  `include "dwc_app_completer.svh"

endpackage : dwc_pcie_bfm_pkg
