"""Test PCIe capability linked list traversal and base address extraction."""

import contextlib
import io
import os
from pathlib import Path
import sys
import unittest

if os.environ.get("GETAXIINFO_TEST_INSTALLED") != "1":
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from getaxiinfo import get_pcie_capabilities, getaxiinfo_cli
from getaxiinfo.capabilities import parse_capability_chains
from getaxiinfo.report import build_analysis

REPO_ROOT = Path(__file__).resolve().parents[3]
EXAMPLE_600 = REPO_ROOT / "pciegen" / "examples" / "pcie_6_00a_mpw" / "rtl" / "src" / "VF600F_DWC_pcie_ctl_cc_constants.svh"
EXAMPLE_650 = REPO_ROOT / "pciegen" / "examples" / "pcie_6_50a_mpw" / "rtl" / "src" / "VF650F_DWC_pcie_ctl_cc_constants.svh"
FIXTURE = Path(__file__).parent / "fixtures" / "src" / "demo_pcie_ctl_cc_constants.svh"


class CapabilityTests(unittest.TestCase):
    def test_600a_capabilities(self):
        if not EXAMPLE_600.exists():
            self.skipTest("pciegen example 6.00a not found on local machine")

        caps = get_pcie_capabilities([str(EXAMPLE_600)])
        self.assertTrue(len(caps) > 15)

        # Standard PCI caps for PF0
        pf0_std = [c for c in caps if c["scope"] == "PF0" and c["type"] == "PCI Standard"]
        self.assertEqual(
            [(c["base_address_hex"], c["next_offset_hex"], c["name"]) for c in pf0_std],
            [
                ("0x40", "0x50", "PM"),
                ("0x50", "0x70", "MSI"),
                ("0x70", "0xB0", "PCIE"),
                ("0xB0", "0x00", "MSIX"),
            ]
        )

        # PCIe Extended caps for PF0
        pf0_ext = [c for c in caps if c["scope"] == "PF0" and c["type"] == "PCIe Extended"]
        ext_order = [c["name"] for c in pf0_ext]
        self.assertIn("AER", ext_order)
        self.assertIn("VC", ext_order)
        self.assertIn("ARI", ext_order)
        self.assertIn("SRIOV", ext_order)
        self.assertIn("PTM", ext_order)
        self.assertIn("PTM_VSEC", ext_order)
        self.assertIn("VSECDMA", ext_order)

        # Verify specific base addresses in 6.00a
        by_name = {c["name"]: c for c in pf0_ext}
        self.assertEqual(by_name["AER"]["base_address"], 0x100)
        self.assertEqual(by_name["AER"]["cap_id"], 0x0001)
        self.assertEqual(by_name["VC"]["base_address"], 0x148)
        self.assertEqual(by_name["ARI"]["base_address"], 0x170)
        self.assertEqual(by_name["SPCIE"]["base_address"], 0x180)
        self.assertEqual(by_name["SRIOV"]["base_address"], 0x200)
        self.assertEqual(by_name["VSECDMA"]["base_address"], 0x2F8)
        self.assertEqual(by_name["VSECDMA"]["next_offset"], 0x000)

        # VF caps
        vf_std = [c for c in caps if c["scope"] == "VF" and c["type"] == "PCI Standard"]
        self.assertEqual([c["name"] for c in vf_std], ["MSI", "PCIE", "MSIX"])
        self.assertEqual(vf_std[0]["base_address_hex"], "0x50")

    def test_650a_prefixed_capabilities(self):
        if not EXAMPLE_650.exists():
            self.skipTest("pciegen example 6.50a not found on local machine")

        caps = get_pcie_capabilities([str(EXAMPLE_650)])
        pf0_ext = [c for c in caps if c["scope"] == "PF0" and c["type"] == "PCIe Extended"]
        by_name = {c["name"]: c for c in pf0_ext}
        # In 6.50a, VSECDMA is at 0x2F0
        self.assertEqual(by_name["VSECDMA"]["base_address"], 0x2F0)
        self.assertEqual(by_name["PTM_VSEC"]["base_address"], 0x288)

    def test_vf_gated_by_sriov(self):
        # When SRIOV is enabled (e.g. 6.00a), VF caps should be parsed
        if EXAMPLE_600.exists():
            caps_enabled = get_pcie_capabilities([str(EXAMPLE_600)])
            vf_caps = [c for c in caps_enabled if c["scope"] == "VF"]
            self.assertTrue(len(vf_caps) > 0)

        # When SRIOV is disabled (sriov_enabled=0), VF caps must NOT be parsed
        raw_defs = {
            "CFG_NEXT_PTR_0": "12'h40",
            "VF_CFG_NEXT_PTR": "12'h50",
            "PM_PTR": "12'h40",
            "PM_NEXT_PTR": "12'h0",
            "MSI_PTR": "12'h50",
            "MSI_NEXT_PTR": "12'h0",
        }
        fields, rows, notes = parse_capability_chains(raw_defs, sriov_enabled=0)
        self.assertEqual([r[0] for r in rows], ["PF0"])
        self.assertNotIn("VF", [r[0] for r in rows])
        self.assertEqual(dict(fields)["Standard Capabilities"], "1 (PF0)")

    def test_synthetic_constants_fallback(self):
        caps = get_pcie_capabilities([str(FIXTURE)])
        self.assertEqual(caps, [])


if __name__ == "__main__":
    unittest.main()
