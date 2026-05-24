import os
import glob
import re
import argparse
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from VerilogParser import VerilogPortAnalyzer


class RamParser:
    """RAM folder parser - analyze module information of all Verilog files in a folder"""
    
    def __init__(self, folder_path: str):
        """
        Initialize RamParser
        
        Args:
            folder_path: Path to folder to analyze
        """
        self.folder_path = folder_path
        self.verilog_files = []
        self.module_results = []
    
    def find_verilog_files(self) -> List[str]:
        """
        Find all Verilog files (.v or .sv) in the folder
        
        Returns:
            List of Verilog file paths
        """
        if not os.path.isdir(self.folder_path):
            raise ValueError(f"Folder does not exist: {self.folder_path}")
        
        # Find all .v and .sv files
        v_files = glob.glob(os.path.join(self.folder_path, "*.v"))
        sv_files = glob.glob(os.path.join(self.folder_path, "*.sv"))
        
        self.verilog_files = sorted(v_files + sv_files)
        return self.verilog_files
    
    def analyze_folder(self) -> List[Dict]:
        """
        Analyze module information of all Verilog files in the folder
        
        Returns:
            List containing analysis results for each module
        """
        files = self.find_verilog_files()
        self.module_results = []
        
        for file_path in files:
            try:
                # Create analyzer and parse module
                analyzer = VerilogPortAnalyzer(file_path)
                result = analyzer.parse_target_module()
                
                if result:
                    self.module_results.append({
                        'file': file_path,
                        'module': result['module_name'],
                        'style': 'ANSI' if result['is_ansi_style'] else 'Non-ANSI',
                        'ports': result['ports'],
                        'statistics': result['statistics'],
                        'macros': result['macros'],
                        'parameters': result['parameters'],
                        'defined_flags': result['defined_flags']
                    })
            except Exception as e:
                print(f"Warning: Failed to analyze {file_path} - {str(e)}")
        
        return self.module_results
    
    def print_summary(self):
        """Print analysis summary"""
        if not self.module_results:
            print("No modules found")
            return
        
        print("\n" + "=" * 100)
        print(f"Folder Analysis Summary: {self.folder_path}")
        print("=" * 100)
        print(f"Total Files: {len(self.verilog_files)}")
        print(f"Total Modules: {len(self.module_results)}")
        print()
        
        print(f"{'File':<50} {'Module':<20} {'Style':<10} {'Ports':<6} {'Bits':<8}")
        print("-" * 100)
        
        for result in self.module_results:
            file_name = os.path.basename(result['file'])
            module = result['module']
            style = result['style']
            ports = result['statistics']['total_ports']
            bits = result['statistics']['total_bits']
            
            print(f"{file_name:<50} {module:<20} {style:<10} {ports:<6} {bits:<8}")
        
        print("=" * 100)
    
    def get_modules_list(self) -> List[Dict]:
        """
        Get simplified module list (containing only basic information)
        
        Returns:
            List containing module name, file, port count and other basic information
        """
        simplified = []
        for result in self.module_results:
            simplified.append({
                'module_name': result['module'],
                'file': result['file'],
                'style': result['style'],
                'total_ports': result['statistics']['total_ports'],
                'input_ports': result['statistics']['input_ports'],
                'output_ports': result['statistics']['output_ports'],
                'inout_ports': result['statistics']['inout_ports'],
                'total_bits': result['statistics']['total_bits'],
                'ports': result['ports']
            })
        return simplified


# Usage example
if __name__ == '__main__':
    # Parse command-line arguments
    parser_args = argparse.ArgumentParser(
        description='Analyze Verilog RAM modules and extract depth/width from headers and ports',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  python RamParser.py .                    # Analyze current folder
  python RamParser.py /path/to/verilog    # Analyze specified folder
  python RamParser.py . --validation       # Show validation report
        '''
    )
    parser_args.add_argument(
        'folder',
        nargs='?',
        default='.',
        help='Path to folder containing Verilog files (default: current folder)'
    )
    parser_args.add_argument(
        '--summary-only',
        action='store_true',
        help='Only show summary without detailed module information'
    )
    
    args = parser_args.parse_args()
    
    # Validate folder path
    if not os.path.isdir(args.folder):
        print(f"Error: Folder '{args.folder}' does not exist")
        exit(1)
    
    # Analyze folder
    print(f"Analyzing folder: {os.path.abspath(args.folder)}\n")
    parser = RamParser(args.folder)
    
    # Analyze all modules
    results = parser.analyze_folder()
    
    if not results:
        print("No Verilog modules found in the specified folder")
        exit(0)
    
    # Print summary
    parser.print_summary()
    
    # Print detailed module information if not summary-only mode
    if not args.summary_only:
        # Get simplified list and display module information
        modules = parser.get_modules_list()
        print("\nModule Details:")
        print("=" * 120)
        
        for mod in modules:
            print(f"\nModule: {mod['module_name']}")
            print(f"File: {os.path.abspath(mod['file'])}")
            print(f"  Style: {mod['style']}")
            print(f"  Ports: {mod['total_ports']} ({mod['input_ports']}in, {mod['output_ports']}out, {mod['inout_ports']}inout)")
            print(f"  Total Bits: {mod['total_bits']}")
            print(f"  Port List:")
            for port in mod['ports']:
                direction = port['direction']
                bits = port['bits']
                name = port['name']
                print(f"    {direction:<6} {name:<20} [{bits} bits]")
