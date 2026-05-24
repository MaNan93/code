#!/usr/bin/env python3
"""Test script to verify instance port formatting"""

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "modeditor" / "src"))

def test_inst_port_formatting():
    """Test that instance ports don't stick to )."""
    from modeditor.utils import add_inst_port
    
    source = """module wrapper;
    my_module u_inst (
        .clk(clk),
        .reset(reset)
    );
endmodule
"""
    
    try:
        # Add a new connection
        result = add_inst_port(
            source,
            module_name=None,
            instname="u_inst",
            port="data_in",
            wire="sig_a"
        )
        
        print("Generated code:")
        print("=" * 60)
        print(result)
        print("=" * 60)
        
        lines = result.split('\n')
        
        # Find the instance block
        inst_start = next(i for i, l in enumerate(lines) if 'u_inst' in l)
        closing_idx = next(i for i, l in enumerate(lines) if i > inst_start and ')' in l and ';' in l)
        
        print(f"\nInstance at line {inst_start}")
        print(f"Closing ); at line {closing_idx}")
        print(f"\nInstance block (lines {inst_start} to {closing_idx}):")
        for i in range(inst_start, closing_idx + 1):
            print(f"  {i:3d}: {repr(lines[i])}")
        
        # Check that ); is on its own line
        closing_line = lines[closing_idx].strip()
        assert closing_line == ");", \
            f"Closing line should only be '); ', got: {repr(lines[closing_idx])}"
        
        # Check that ); is not preceded by a connection on the same line
        if closing_idx > 0:
            prev_line = lines[closing_idx - 1].strip()
            # The line before ); should be a .port() connection, not empty
            assert prev_line.startswith('.'), \
                f"Line before ); should start with '.', got: {repr(prev_line)}"
            assert not prev_line.endswith(');'), \
                f"Previous line should not end with ); on same line: {repr(prev_line)}"
        
        print("\n✓ Instance port formatting test PASSED")
        print("  - Each connection is on its own line")
        print("  - ); is on a separate line")
        return True
        
    except Exception as e:
        print(f"✗ Test FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = test_inst_port_formatting()
    sys.exit(0 if success else 1)
