#!/usr/bin/env python3
"""Test script to verify instance port formatting - edge case with no existing connections"""

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "modeditor" / "src"))

def test_inst_port_no_existing():
    """Test adding port when instance has no existing connections."""
    from modeditor.utils import add_inst_port
    
    source = """module wrapper;
    my_module u_inst ();
endmodule
"""
    
    try:
        # Add a new connection
        result = add_inst_port(
            source,
            module_name=None,
            instname="u_inst",
            port="clk",
            wire="sys_clk"
        )
        
        print("Generated code (no existing connections case):")
        print("=" * 60)
        print(result)
        print("=" * 60)
        
        lines = result.split('\n')
        
        # Check formatting
        for i, line in enumerate(lines):
            print(f"{i:3d}: {repr(line)}")
        
        # Find the closing );
        closing_line = next((i for i, l in enumerate(lines) if ');' in l), None)
        if closing_line is not None:
            print(f"\nClosing line {closing_line}: {repr(lines[closing_line])}")
            # Check if ) is on its own line
            line_content = lines[closing_line].strip()
            if line_content != ");":
                print(f"⚠ Warning: ) is not on a separate line")
                print(f"  Expected: ');'")
                print(f"  Got: {repr(line_content)}")
        
        return True
        
    except Exception as e:
        print(f"✗ Test FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = test_inst_port_no_existing()
    sys.exit(0 if success else 1)
