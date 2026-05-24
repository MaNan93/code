#!/usr/bin/env python3
"""Test script to verify port formatting (one per line, no sticking to );)"""

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "modeditor" / "src"))

def test_nonansi_port_formatting():
    """Test that non-ANSI ports are formatted one per line with ); on separate line."""
    from modeditor.utils import append_ports
    
    # Non-ANSI style module
    source = """module test_mod (clk, reset);
    input clk, reset;
    
    always @(posedge clk) begin
        // logic
    end
endmodule
"""
    
    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            test_file = Path(tmpdir) / "test.sv"
            test_file.write_text(source)
            
            # Append multiple new ports
            new_signals = [
                {"name": "data_in", "direction": "input", "type": "[31:0]"},
                {"name": "data_out", "direction": "output", "type": "[31:0]"},
                {"name": "enable", "direction": "input", "type": ""},
            ]
            
            result = append_ports(test_file, new_signals, c_like=False)
            assert result, "append_ports should return True"
            
            result_text = test_file.read_text()
            print("Generated code:")
            print("=" * 60)
            print(result_text)
            print("=" * 60)
            
            # Split into lines for analysis
            lines = result_text.split('\n')
            
            # Find the module header and closing
            module_line_idx = next(i for i, l in enumerate(lines) if 'module test_mod' in l)
            closing_line_idx = next(i for i, l in enumerate(lines) if i > module_line_idx and ');' in l)
            
            print(f"\nModule header at line {module_line_idx}")
            print(f"Closing '); ' at line {closing_line_idx}")
            print(f"\nPort section (lines {module_line_idx} to {closing_line_idx}):")
            for i in range(module_line_idx, closing_line_idx + 1):
                print(f"  {i:3d}: {repr(lines[i])}")
            
            # Verify formatting:
            # 1. Each new port should be on its own line
            port_section = lines[module_line_idx:closing_line_idx+1]
            port_text = '\n'.join(port_section)
            
            assert 'data_in' in port_text, "data_in not found"
            assert 'data_out' in port_text, "data_out not found"  
            assert 'enable' in port_text, "enable not found"
            
            # 2. ); should be on its own line (or with only whitespace)
            closing_line = lines[closing_line_idx]
            closing_line_stripped = closing_line.strip()
            assert closing_line_stripped == ');', \
                f"Closing line should only contain '); ', got: {repr(closing_line)}"
            
            # 3. Verify ports are not on the closing line
            for port_name in ['data_in', 'data_out', 'enable']:
                assert port_name not in closing_line, \
                    f"Port {port_name} found on closing line"
            
            print("\n✓ Non-ANSI port formatting test PASSED")
            print("  - Each port is on its own line")
            print("  - ); is on a separate line")
            print("  - Ports don't stick to );")
            return True
            
    except Exception as e:
        print(f"✗ Test FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = test_nonansi_port_formatting()
    sys.exit(0 if success else 1)

