#!/usr/bin/env python3
"""
命令行工具：从Word文档提取表格到CSV
使用pandas的read_excel方法（需先手动转换Word为Excel）
"""

import argparse
import pandas as pd
import os
import sys
import subprocess
from pathlib import Path
import re

def convert_word_to_excel(word_path, excel_path=None):
    """
    将Word文档转换为Excel格式
    注意：此函数需要系统已安装LibreOffice或Microsoft Word
    """
    if excel_path is None:
        excel_path = Path(word_path).with_suffix('.xlsx')
    
    word_path = Path(word_path).resolve()
    excel_path = Path(excel_path).resolve()
    
    # 方法1: 使用LibreOffice（跨平台）
    if sys.platform.startswith('win'):
        libreoffice_paths = [
            r"C:\Program Files\LibreOffice\program\soffice.exe",
            r"C:\Program Files (x86)\LibreOffice\program\soffice.exe"
        ]
        
        for lo_path in libreoffice_paths:
            if os.path.exists(lo_path):
                cmd = [
                    lo_path,
                    '--headless',
                    '--convert-to', 'xlsx',
                    '--outdir', str(excel_path.parent),
                    str(word_path)
                ]
                try:
                    subprocess.run(cmd, check=True, capture_output=True)
                    print(f"✓ 使用LibreOffice转换: {excel_path}")
                    return str(excel_path)
                except subprocess.CalledProcessError as e:
                    print(f"LibreOffice转换失败: {e}")
                break
    
    # 方法2: 使用MS Word（仅Windows）
    elif sys.platform.startswith('win'):
        try:
            import win32com.client as win32
            word = win32.gencache.EnsureDispatch('Word.Application')
            word.Visible = False
            
            doc = word.Documents.Open(str(word_path))
            excel_path = str(word_path).replace('.docx', '.xlsx').replace('.doc', '.xlsx')
            
            # Word没有直接转Excel的方法，这里保存为文本
            txt_path = str(word_path).replace('.docx', '.txt').replace('.doc', '.txt')
            doc.SaveAs(txt_path, FileFormat=7)  # 纯文本格式
            doc.Close(SaveChanges=False)
            word.Quit()
            
            print(f"✓ 转换为文本文件: {txt_path}")
            return txt_path
            
        except Exception as e:
            print(f"Word转换失败: {e}")
    
    # 方法3: 使用unoconv（Linux/Mac）
    elif sys.platform.startswith('linux') or sys.platform.startswith('darwin'):
        try:
            cmd = ['unoconv', '-f', 'xlsx', str(word_path)]
            subprocess.run(cmd, check=True, capture_output=True)
            print(f"✓ 使用unoconv转换: {excel_path}")
            return str(excel_path)
        except (subprocess.CalledProcessError, FileNotFoundError):
            print("未找到unoconv，请安装: sudo apt install unoconv")
    
    print("⚠ 无法自动转换Word文件，请先手动转换为Excel或CSV格式")
    print("   推荐: 在Word中打开文件 -> 另存为 -> 选择'Excel工作簿(*.xlsx)'")
    return None

def extract_from_excel(excel_path, sheet_name=None, skip_rows=0, columns=None):
    """从Excel文件提取表格数据"""
    try:
        # 读取Excel文件
        if sheet_name:
            df = pd.read_excel(excel_path, sheet_name=sheet_name, header=None)
        else:
            # 尝试读取第一个sheet
            xls = pd.ExcelFile(excel_path)
            sheet_name = xls.sheet_names[0]
            df = pd.read_excel(excel_path, sheet_name=sheet_name, header=None)
        
        print(f"读取工作表: {sheet_name}")
        print(f"原始数据形状: {df.shape}")
        
        # 跳过指定行数
        if skip_rows > 0:
            df = df.iloc[skip_rows:]
        
        # 选择指定列
        if columns:
            # 处理列选择字符串，如 "0,1" 或 "A,B"
            col_indices = []
            for col in columns.split(','):
                col = col.strip()
                # 如果是字母列名，转换为索引
                if re.match(r'^[A-Za-z]+$', col):
                    col_index = 0
                    for char in col.upper():
                        col_index = col_index * 26 + (ord(char) - ord('A') + 1)
                    col_indices.append(col_index - 1)  # 转换为0-based索引
                else:
                    col_indices.append(int(col))
            
            # 确保列索引有效
            valid_cols = [col for col in col_indices if col < df.shape[1]]
            if valid_cols:
                df = df.iloc[:, valid_cols]
                print(f"选择列: {valid_cols}")
            else:
                print("⚠ 指定的列不存在，返回所有列")
        
        return df
        
    except Exception as e:
        print(f"读取Excel文件失败: {e}")
        return None

def find_table_by_pattern(df, pattern):
    """在DataFrame中查找包含特定模式的表格"""
    pattern = str(pattern).lower()
    
    # 查找包含模式的行和列
    matches = df.applymap(lambda x: bool(re.search(pattern, str(x).lower())))
    
    if matches.any().any():
        # 找到匹配的位置
        rows, cols = matches.values.nonzero()
        start_row = rows.min() if len(rows) > 0 else 0
        
        # 查找表格边界（连续非空行）
        table_data = []
        for i in range(start_row, len(df)):
            row = df.iloc[i]
            if row.notna().any():  # 行中有非空值
                table_data.append(row.tolist())
            elif table_data:  # 遇到空行且已有数据，结束表格
                break
        
        if table_data:
            return pd.DataFrame(table_data)
    
    return None

def main():
    parser = argparse.ArgumentParser(
        description='从Word/Excel文档提取表格数据',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用示例:
  # 基本使用 - 从Word提取（需先转换）
  python extract_tables.py document.docx -o output.csv
  
  # 从Excel文件提取
  python extract_tables.py data.xlsx -o output.csv
  
  # 提取特定表格（通过搜索文本）
  python extract_tables.py document.xlsx -p "表2-11" -o table_2_11.csv
  
  # 跳过前2行，提取A、B列
  python extract_tables.py data.xlsx -s 2 -c "A,B" -o columns.csv
  
  # 批量处理目录下所有文件
  python extract_tables.py ./documents/ -b -o ./output/
        """
    )
    
    # 输入文件/目录
    parser.add_argument('input_path', help='Word/Excel文件路径或目录')
    
    # 输出选项
    parser.add_argument('-o', '--output', default='extracted_data.csv',
                       help='输出文件或目录 (默认: extracted_data.csv)')
    
    # 数据提取选项
    parser.add_argument('-p', '--pattern', 
                       help='搜索表格的文本模式（如"表2-11"）')
    parser.add_argument('-s', '--skip-rows', type=int, default=0,
                       help='跳过的行数 (默认: 0)')
    parser.add_argument('-c', '--columns', 
                       help='要提取的列（支持A,B或0,1格式）')
    parser.add_argument('--sheet', 
                       help='Excel工作表名称（默认第一个工作表）')
    parser.add_argument('-b', '--batch', action='store_true',
                       help='批量处理目录下所有文件')
    
    args = parser.parse_args()
    
    input_path = Path(args.input_path)
    output_path = Path(args.output)
    
    if not input_path.exists():
        print(f"错误: 路径不存在 - {input_path}")
        sys.exit(1)
    
    # 批量处理模式
    if args.batch and input_path.is_dir():
        print(f"批量处理目录: {input_path}")
        
        # 支持的文件扩展名
        extensions = ['.docx', '.doc', '.xlsx', '.xls']
        files = []
        for ext in extensions:
            files.extend(input_path.glob(f'*{ext}'))
        
        if not files:
            print("未找到支持的文档文件")
            sys.exit(1)
        
        # 创建输出目录
        if output_path.suffix:  # 如果是文件路径，改为目录
            output_path = output_path.parent / output_path.stem
        output_path.mkdir(parents=True, exist_ok=True)
        
        success_count = 0
        for file in files:
            print(f"\n处理文件: {file.name}")
            
            output_file = output_path / f"{file.stem}_extracted.csv"
            try:
                # 根据文件类型处理
                if file.suffix.lower() in ['.xlsx', '.xls']:
                    df = extract_from_excel(
                        str(file), 
                        sheet_name=args.sheet,
                        skip_rows=args.skip_rows,
                        columns=args.columns
                    )
                else:
                    # Word文件需要转换
                    print("检测到Word文件，正在转换...")
                    excel_file = convert_word_to_excel(str(file))
                    if excel_file and os.path.exists(excel_file):
                        df = extract_from_excel(
                            excel_file,
                            sheet_name=args.sheet,
                            skip_rows=args.skip_rows,
                            columns=args.columns
                        )
                        # 清理临时文件
                        if excel_file.endswith('.xlsx'):
                            os.remove(excel_file)
                    else:
                        print(f"跳过 {file.name} - 转换失败")
                        continue
                
                if df is not None and not df.empty:
                    # 如果指定了模式，搜索特定表格
                    if args.pattern:
                        table_df = find_table_by_pattern(df, args.pattern)
                        if table_df is not None:
                            table_df.to_csv(output_file, index=False, header=False, encoding='utf-8-sig')
                            print(f"  ✓ 已保存: {output_file} ({len(table_df)} 行)")
                            success_count += 1
                        else:
                            print(f"  ✗ 未找到匹配 '{args.pattern}' 的表格")
                    else:
                        df.to_csv(output_file, index=False, header=False, encoding='utf-8-sig')
                        print(f"  ✓ 已保存: {output_file} ({len(df)} 行)")
                        success_count += 1
                else:
                    print(f"  ✗ 未提取到数据")
                    
            except Exception as e:
                print(f"  ✗ 处理失败: {e}")
        
        print(f"\n批量处理完成: {success_count}/{len(files)} 个文件成功")
    
    else:
        # 单个文件处理模式
        file_path = str(input_path)
        
        if input_path.suffix.lower() in ['.xlsx', '.xls']:
            print(f"读取Excel文件: {file_path}")
            df = extract_from_excel(
                file_path, 
                sheet_name=args.sheet,
                skip_rows=args.skip_rows,
                columns=args.columns
            )
        else:
            print(f"检测到Word文件: {file_path}")
            print("正在转换为中间格式...")
            excel_file = convert_word_to_excel(file_path)
            
            if not excel_file or not os.path.exists(excel_file):
                print("请先手动将Word文件转换为Excel格式")
                print("或安装LibreOffice并确保'soffice'命令可用")
                sys.exit(1)
            
            df = extract_from_excel(
                excel_file,
                sheet_name=args.sheet,
                skip_rows=args.skip_rows,
                columns=args.columns
            )
            
            # 清理临时文件
            if excel_file.endswith('.xlsx') and os.path.exists(excel_file):
                os.remove(excel_file)
        
        if df is not None and not df.empty:
            # 搜索特定表格
            if args.pattern:
                print(f"搜索表格模式: '{args.pattern}'")
                table_df = find_table_by_pattern(df, args.pattern)
                
                if table_df is not None:
                    print(f"找到表格，形状: {table_df.shape}")
                    table_df.to_csv(output_path, index=False, header=False, encoding='utf-8-sig')
                    print(f"✓ 表格数据已保存到: {output_path}")
                else:
                    print(f"✗ 未找到匹配 '{args.pattern}' 的表格")
                    # 保存整个数据
                    df.to_csv(output_path, index=False, header=False, encoding='utf-8-sig')
                    print(f"✓ 所有数据已保存到: {output_path}")
            else:
                df.to_csv(output_path, index=False, header=False, encoding='utf-8-sig')
                print(f"✓ 数据已保存到: {output_path}")
                print(f"  行数: {len(df)}, 列数: {len(df.columns)}")
        else:
            print("✗ 未提取到任何数据")

if __name__ == '__main__':
    main()