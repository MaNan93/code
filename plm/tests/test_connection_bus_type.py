"""Connection port layout, option persistence and generation identity."""

import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from plm.core.gen_flags import GenerationOptions
from plm.core.generator import rtl
from plm.core.service import generate
from plm.core.validation import load_generation_plan_from_payload
from plm.core.workspace import read_gen_flags, save_workspace_content, write_gen_flags
from test_core import valid_payload


class ConnectionBusTypeTests(unittest.TestCase):
    def setUp(self):
        self.payload = valid_payload()
        self.payload['signals'].extend([
            {'signal_name': 'flag', 'signal_type': 'perlane', 'direction': 'mac2phy',
             'width': '1', 'safe_state': '0', 'tie_off': '0'},
            {'signal_name': 'shared_ctl', 'signal_type': 'shared', 'direction': 'mac2phy',
             'width': '3', 'safe_state': '0', 'tie_off': '0'},
        ])
        self.cfg = load_generation_plan_from_payload(self.payload, GenerationOptions()).config

    def test_flat_ports_and_lane_slices_preserve_both_directions_and_shared_inputs(self):
        for pclk_mode in ('pclk_as_phy_output', 'pclk_as_phy_input'):
            for dpr in (False, True):
                with self.subTest(pclk_mode=pclk_mode, dpr=dpr):
                    source = rtl.gen_connection(self.cfg, pclk_mode, dpr, bus_type='flat')
                    ports = source.split(');', 1)[0]
                    self.assertNotRegex(ports, r'\]\s+\w+\s+\[')
                    self.assertIn('output logic [NL * 8 - 1:0] phy_mac_phy_txdata,', ports)
                    self.assertIn('input logic [NL * 8 - 1:0] phy_phy_mac_rxdata,', ports)
                    self.assertIn('input logic [2 * 8 - 1:0] ctrla_mac_phy_txdata,', ports)
                    self.assertIn('output logic [2 * 8 - 1:0] ctrla_phy_mac_rxdata,', ports)
                    self.assertIn('input logic [2:0] ctrla_shared_ctl,', ports)
                    self.assertIn('phy_mac_phy_txdata[1 * 8 +: 8] = w_phy_mac2phy[1].mac_phy_txdata;', source)
                    self.assertIn('phy_mac_rxdata: phy_phy_mac_rxdata[1 * 8 +: 8]', source)
                    self.assertIn('mac_phy_txdata: ctrla_mac_phy_txdata[1 * 8 +: 8]', source)
                    self.assertIn('flag: ctrla_flag[1 * 1 +: 1]', source)
                    self.assertIn('shared_ctl: ctrla_shared_ctl', source)
                    self.assertIn('ctrla_phy_mac_rxdata[1 * 8 +: 8] = w_ctrla_phy2mac[1].phy_mac_rxdata;', source)
                    if dpr:
                        self.assertIn('input logic [NL * 8 - 1:0] dpr_mac_phy_txdata,', ports)
                        self.assertIn('output logic [NL * 8 - 1:0] dpr_phy_mac_rxdata,', ports)
                        self.assertIn('input logic [2:0] dpr_shared_ctl,', ports)
                        self.assertIn('mac_phy_txdata: dpr_mac_phy_txdata[1 * 8 +: 8]', source)
                        self.assertIn('dpr_phy_mac_rxdata[1 * 8 +: 8] = w_dpr_phy2mac[1].phy_mac_rxdata;', source)

    def test_bus_is_default_and_keeps_existing_unpacked_lane_arrays(self):
        source = rtl.gen_connection(self.cfg)
        self.assertEqual(source, rtl.gen_connection(self.cfg, bus_type='bus'))
        self.assertIn('output logic [7:0] phy_mac_phy_txdata [0:NL-1],', source)
        self.assertIn('input logic [7:0] ctrla_mac_phy_txdata [0:1],', source)
        self.assertIn('mac_phy_txdata: ctrla_mac_phy_txdata[1]', source)
        with self.assertRaises(ValueError):
            rtl.gen_connection(self.cfg, bus_type='invalid')

    def test_workspace_defaults_and_flat_flag_round_trip_preserve_line_endings(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'gen_flags.txt'
            self.assertEqual(read_gen_flags(path)['bus-type'], 'bus')
            path.write_bytes(b'arch = original_pipe\r\n')
            self.assertEqual(read_gen_flags(path)['bus-type'], 'bus')
            write_gen_flags(path, {'bus-type': 'flat'})
            self.assertEqual(read_gen_flags(path)['bus-type'], 'flat')
            self.assertNotIn(b'\n', path.read_bytes().replace(b'\r\n', b''))
            path.write_text('bus-type = unknown\n', encoding='utf-8')
            self.assertEqual(read_gen_flags(path)['bus-type'], 'unknown')
            with self.assertRaisesRegex(ValueError, 'bus_type'):
                GenerationOptions(bus_type='unknown').validated()

    @patch('plm.core.verible.find_verible', return_value=None)
    def test_switching_bus_type_regenerates_only_connection_rtl_and_then_skips(self, _formatter):
        with tempfile.TemporaryDirectory() as temporary, contextlib.redirect_stdout(io.StringIO()):
            root = Path(temporary)
            save_workspace_content(root, self.payload)
            bus = generate(root / 'config', root / 'rtl', GenerationOptions(quiet=True))
            before = {path.relative_to(root): path.read_bytes()
                      for kind in ('rtl', 'tb') for path in (root / kind).rglob('*')
                      if path.is_file() and path.name != 'manifest.json'}
            flat_options = GenerationOptions(bus_type='flat', quiet=True)
            flat = generate(root / 'config', root / 'rtl', flat_options)
            self.assertTrue(flat.generated)
            self.assertNotEqual(bus.plan.generation_key, flat.plan.generation_key)
            after = {path.relative_to(root): path.read_bytes()
                     for kind in ('rtl', 'tb') for path in (root / kind).rglob('*')
                     if path.is_file() and path.name != 'manifest.json'}
            changed = {path.as_posix() for path in before if before[path] != after[path]}
            self.assertEqual(changed, {'rtl/src/pipe_lane_mapper_connection.sv'})
            manifest = json.loads((root / 'rtl/manifest.json').read_text())
            self.assertEqual(manifest['options']['bus_type'], 'flat')
            self.assertFalse(generate(root / 'config', root / 'rtl', flat_options).generated)
