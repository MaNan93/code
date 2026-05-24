#!/usr/bin/env python3
"""Test script to verify bug fixes in pciegen and modeditor."""

import sys
from pathlib import Path

# Add modeditor to path for import
sys.path.insert(0, str(Path(__file__).parent / "modeditor" / "src"))
sys.path.insert(0, str(Path(__file__).parent / "pciegen"))

def test_analyze_ports_format():
    """Test that analyze_ports returns module_name key instead of module."""
    from modeditor.utils import analyze_ports
    
    # Create a minimal test file
    test_sv = Path(__file__).parent / "test_module.sv"
    test_sv.write_text("""
module test_mod (
    input clk,
    output [7:0] data
);
endmodule
""")
    
    try:
        rows = analyze_ports(test_sv)
        assert len(rows) > 0, "analyze_ports returned empty list"
        
        row = rows[0]
        assert "module_name" in row, f"Row missing 'module_name' key. Keys: {row.keys()}"
        assert "module" not in row, f"Row still has 'module' key (should be renamed to 'module_name')"
        assert row["module_name"] == "test_mod", f"Module name is '{row['module_name']}', expected 'test_mod'"
        
        print("✓ analyze_ports format test PASSED")
        return True
    except Exception as e:
        print(f"✗ analyze_ports format test FAILED: {e}")
        return False
    finally:
        test_sv.unlink(missing_ok=True)


def test_dict_access_safety():
    """Test that pciegen can safely access module_name with .get()."""
    test_sv = Path(__file__).parent / "test_module.sv"
    test_sv.write_text("""
module test_mod (
    input clk
);
endmodule
""")
    
    try:
        from modeditor.utils import analyze_ports
        
        rows = analyze_ports(test_sv)
        
        # Simulate pciegen's access pattern (using .get() for safety)
        module_name = rows[0].get("module_name", "")
        assert module_name == "test_mod", f"Got '{module_name}' instead of 'test_mod'"
        
        print("✓ Safe dict access test PASSED")
        return True
    except Exception as e:
        print(f"✗ Safe dict access test FAILED: {e}")
        return False
    finally:
        test_sv.unlink(missing_ok=True)


def test_non_ansi_port_insertion():
    """Test that non-ANSI port insertion happens at module body start."""
    from modeditor.utils import append_ports
    from pathlib import Path
    import tempfile
    
    # Non-ANSI style module with function before body
    source = """module test_mod (clk, reset, data_out);
    input clk, reset;
    output [7:0] data_out;
    
    function automatic void my_func(input int x);
        // function body
    endfunction
    
    always @(posedge clk) begin
        // sequential logic
    end
endmodule
"""
    
    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            test_file = Path(tmpdir) / "test.sv"
            test_file.write_text(source)
            
            # Append new signals
            new_signals = [
                {"name": "new_sig1", "direction": "input", "type": "[15:0]"},
                {"name": "new_sig2", "direction": "output", "type": "[7:0]"},
            ]
            
            result = append_ports(test_file, new_signals, c_like=False)
            
            # Read the modified file
            result_text = test_file.read_text()
            
            # Check that new declarations are inserted
            assert "new_sig1" in result_text, "new_sig1 not found in result"
            assert "new_sig2" in result_text, "new_sig2 not found in result"
            
            # Verify they appear at module body start (after );), not after function
            lines = result_text.split('\n')
            func_line = next((i for i, l in enumerate(lines) if 'function' in l), None)
            new_sig_line = next((i for i, l in enumerate(lines) if 'new_sig1' in l), None)
            
            if func_line is not None and new_sig_line is not None:
                assert new_sig_line < func_line, \
                    f"new_sig1 (line {new_sig_line}) appears after function (line {func_line})"
            
            print("✓ Non-ANSI port insertion test PASSED")
            return True
    except Exception as e:
        print(f"✗ Non-ANSI port insertion test FAILED: {e}")
        return False


def main():
    print("=" * 60)
    print("Testing Bug Fixes")
    print("=" * 60)
    
    tests = [
        test_analyze_ports_format,
        test_dict_access_safety,
        test_non_ansi_port_insertion,
    ]
    
    results = []
    for test_func in tests:
        try:
            result = test_func()
            results.append(result)
        except Exception as e:
            print(f"✗ Test {test_func.__name__} crashed: {e}")
            results.append(False)
        print()
    
    print("=" * 60)
    print(f"Results: {sum(results)}/{len(results)} tests passed")
    print("=" * 60)
    
    return all(results)


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
