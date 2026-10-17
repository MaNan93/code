import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import glob
import os
import re
import sys

class FileSearcher:
    def __init__(self, root):
        self.root = root
        # 核心修改：主界面标题改为TimingViolation分析
        self.root.title("TimingViolation分析")
        self.root.geometry("900x600")
        self.root.update_idletasks()

        # 初始化变量
        self.selected_dir = tk.StringVar(value=os.getcwd())
        self.search_pattern = tk.StringVar(value="*.log")
        self.file_frames = []
        self._search_after_id = None
        self.ROW_NUM_COL_WIDTH = 50  # 行数列固定宽度
        # 悬停提示配置
        self.HOVER_DELAY = 200  # 悬停触发延迟(ms)：0.2秒
        self.tooltip_id = None  # 悬停定时器ID
        self.tooltip_win = None # 悬停提示窗口
        self.last_item = None   # 记录上一个悬停的单元格，用于检测移开

        # 创建UI
        self.create_widgets()

        # 绑定事件
        self.search_pattern.trace_add("write", self.debounce_search)
        self.selected_dir.trace_add("write", self.debounce_search)

        # 初始搜索
        self.search_files()

    def create_widgets(self):
        """创建主界面UI"""
        # 1. 目录选择区域
        dir_frame = ttk.Frame(self.root, padding="10")
        dir_frame.pack(fill=tk.X, padx=10, pady=5)
        ttk.Label(dir_frame, text="搜索目录:").pack(side=tk.LEFT, padx=5)
        ttk.Entry(dir_frame, textvariable=self.selected_dir, width=50).pack(side=tk.LEFT, padx=5)
        ttk.Button(dir_frame, text="选择目录", command=self.choose_directory).pack(side=tk.LEFT, padx=5)

        # 2. 搜索规则区域
        pattern_frame = ttk.Frame(self.root, padding="10")
        pattern_frame.pack(fill=tk.X, padx=10, pady=5)
        ttk.Label(pattern_frame, text="搜索规则:").pack(side=tk.LEFT, padx=5)
        ttk.Entry(pattern_frame, textvariable=self.search_pattern, width=50).pack(side=tk.LEFT, padx=5)
        ttk.Label(pattern_frame, text="(支持*.log、test?.txt，实时预览匹配文件)").pack(side=tk.LEFT, padx=5)

        # 3. 文件实时预览区域（支持鼠标滚轮）
        preview_container = ttk.Frame(self.root, padding="10")
        preview_container.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)

        self.canvas = tk.Canvas(preview_container, highlightthickness=0)
        self.scrollbar = ttk.Scrollbar(preview_container, orient=tk.VERTICAL, command=self.canvas.yview)
        self.scrollable_frame = ttk.Frame(self.canvas)

        # 绑定Canvas滚轮事件（Windows/Linux兼容）
        self.canvas.bind("<MouseWheel>", self.on_canvas_mouse_wheel)  # Windows
        self.canvas.bind("<Button-4>", self.on_canvas_mouse_wheel)   # Linux上滚
        self.canvas.bind("<Button-5>", self.on_canvas_mouse_wheel)   # Linux下滚

        # 配置滚动区域
        self.scrollable_frame.bind(
            "<Configure>",
            lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all"), width=820)
        )
        self.canvas.create_window((0, 0), window=self.scrollable_frame, anchor="nw")
        self.canvas.configure(yscrollcommand=self.scrollbar.set)

        self.canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # 4. 统计信息区域
        self.stats_label = ttk.Label(self.root, text="匹配文件数：0 (已递归搜索所有子目录，实时预览)")
        self.stats_label.pack(anchor=tk.W, padx=20, pady=5)

        # 跨平台字体适配
        if sys.platform == "win32":
            self.root.option_add("*Font", "SimHei 9")
        else:
            self.root.option_add("*Font", "Monospace 9")

    def on_canvas_mouse_wheel(self, event):
        """主界面Canvas滚轮事件处理"""
        if sys.platform == "win32":
            self.canvas.yview_scroll(-int(event.delta / 120), "units")
        else:
            if event.num == 4:
                self.canvas.yview_scroll(-1, "units")
            elif event.num == 5:
                self.canvas.yview_scroll(1, "units")

    def debounce_search(self, *args):
        """防抖搜索"""
        if self._search_after_id:
            self.root.after_cancel(self._search_after_id)
        self._search_after_id = self.root.after(300, self.search_files)

    def choose_directory(self):
        """选择目录"""
        dir_path = filedialog.askdirectory(title="选择搜索目录")
        if dir_path:
            self.selected_dir.set(dir_path)

    def clear_preview(self):
        """清空文件预览"""
        for frame in self.file_frames:
            frame.destroy()
        self.file_frames = []
        self.canvas.yview_moveto(0)
        self.root.update_idletasks()

    def extract_timing_violation(self, file_path):
        """提取Timing violation信息"""
        results = []
        try:
            if not os.path.isfile(file_path):
                messagebox.showwarning("文件异常", f"[{os.path.basename(file_path)}] 不是有效文件！")
                return results
            if os.path.getsize(file_path) == 0:
                messagebox.showinfo("文件信息", f"[{os.path.basename(file_path)}] 是空白文件，无内容可分析！")
                return results

            # 多编码兼容读取
            encodings = ['utf-8', 'gbk', 'latin-1']
            file_read = False
            for enc in encodings:
                try:
                    with open(file_path, 'r', encoding=enc) as f:
                        for line in f:
                            line = line.strip()
                            if not line or "Timing violation" not in line:
                                continue
                            
                            # 提取Path
                            path_match = re.search(r'["\']([^"\']+)["\']', line)
                            path = path_match.group(1) if path_match else "未提取到"
                            
                            # 提取Line number
                            line_match = re.search(r'(\d+):', line)
                            line_number = line_match.group(1) if line_match else "未提取到"
                            
                            # 提取Instance（核心规则：Timing violation in 后内容）
                            instance_match = re.search(r'Timing violation in\s+(\w+(\.\w+)+)\b', line, re.IGNORECASE)
                            instance = instance_match.group(1) if instance_match else "未提取到"
                            
                            # 提取下一行Info
                            next_line = f.readline().strip() if not f.closed else ""
                            info = next_line if next_line else "无后续内容"
                            
                            # 结果存储
                            results.append({
                                "instance": instance,
                                "info": info,
                                "path": path,
                                "line_number": line_number
                            })
                    file_read = True
                    break
                except:
                    continue
            if not file_read:
                messagebox.showerror("读取失败", f"[{os.path.basename(file_path)}] 无法识别文件编码！")
        except Exception as e:
            messagebox.showerror("提取失败", f"分析文件出错：\n{str(e)}")
        return results

    def cancel_tooltip(self, event=None):
        """强制取消/销毁悬停提示，清理所有资源（添加event=None兼容事件传递）"""
        # 取消定时器
        if self.tooltip_id:
            try:
                self.result_win.after_cancel(self.tooltip_id)
            except:
                pass
            self.tooltip_id = None
        # 销毁提示窗口
        if self.tooltip_win and self.tooltip_win.winfo_exists():
            try:
                self.tooltip_win.destroy()
            except:
                pass
            self.tooltip_win = None
        # 重置上一个悬停的单元格记录
        self.last_item = None

    def show_tooltip(self, event):
        """显示悬停提示（自动换行）"""
        # 获取鼠标所在单元格的内容
        item_id = self.result_table.identify_row(event.y)
        column_id = self.result_table.identify_column(event.x)
        if not item_id or not column_id or self.result_table.item(item_id, "tags")[0] == "-1":
            self.cancel_tooltip()
            return  # 无效区域，直接销毁提示
        
        col_idx = int(column_id.replace("#", "")) - 1
        cell_value = self.result_table.item(item_id, "values")[col_idx]
        if not cell_value or cell_value == "未提取到" or cell_value == "无后续内容":
            self.cancel_tooltip()
            return  # 无有效内容，销毁提示

        # 销毁原有提示窗口，避免重复显示
        if self.tooltip_win and self.tooltip_win.winfo_exists():
            self.tooltip_win.destroy()

        # 创建顶级透明窗口作为提示框
        self.tooltip_win = tk.Toplevel(self.result_win)
        self.tooltip_win.wm_overrideredirect(True)  # 隐藏窗口边框/标题
        self.tooltip_win.wm_attributes("-topmost", True)  # 始终在顶层
        if sys.platform == "win32":
            self.tooltip_win.wm_attributes("-transparentcolor", self.tooltip_win.cget("bg"))
        else:
            self.tooltip_win.wm_attributes("-alpha", 0.95)  # Linux/Mac透明效果

        # 提示框内容：自动换行，适配内容长度
        tooltip_label = ttk.Label(
            self.tooltip_win,
            text=cell_value,
            font=("SimHei 9" if sys.platform == "win32" else "Monospace 9"),
            wraplength=400,  # 最大宽度，超过自动换行
            padding=5,
            background="#FFFFE0"  # 浅黄色背景
        )
        tooltip_label.pack()

        # 提示框跟随鼠标位置（偏移10px，避免遮挡鼠标）
        x = self.result_win.winfo_pointerx() + 10
        y = self.result_win.winfo_pointery() + 10
        self.tooltip_win.geometry(f"+{x}+{y}")

    def schedule_tooltip(self, event):
        """调度悬停提示（0.2秒延迟触发），修复初始last_item=None导致的无显示问题"""
        current_item = (self.result_table.identify_row(event.y), self.result_table.identify_column(event.x))
        # 核心修复：仅当current_item有效 且 last_item不为None 时，才检测是否变化
        # 初始last_item=None时，直接跳过检测，允许触发提示
        if self.last_item is not None and (current_item != self.last_item or (not current_item[0] or not current_item[1])):
            self.cancel_tooltip()
            return
        # 取消之前的定时器，避免重复触发
        if self.tooltip_id:
            try:
                self.result_win.after_cancel(self.tooltip_id)
            except:
                pass
        # 启动新定时器，同时记录当前单元格
        self.last_item = current_item
        self.tooltip_id = self.result_win.after(self.HOVER_DELAY, lambda: self.show_tooltip(event))

    def on_cell_double_click(self, event):
        """单元格双击事件：仅静默复制内容，无任何提示"""
        # 双击时立即销毁提示
        self.cancel_tooltip()
        # 获取双击的行/列信息
        item_id = self.result_table.identify_row(event.y)
        column_id = self.result_table.identify_column(event.x)
        if not item_id or not column_id or self.result_table.item(item_id, "tags")[0] == "-1":
            return  # 跳过无数据行/无效点击
        
        # 转换列ID为列索引，获取单元格内容
        col_idx = int(column_id.replace("#", "")) - 1
        cell_value = self.result_table.item(item_id, "values")[col_idx]
        if not cell_value:
            return  # 无内容则无任何操作
        
        # 仅执行剪贴板复制，失败静默处理
        try:
            self.result_win.clipboard_clear()
            self.result_win.clipboard_append(str(cell_value))
            self.result_win.update()
        except:
            pass

    def toggle_more_columns(self):
        """切换列显隐 - 包含固定宽度的行数列"""
        # 切换列时销毁提示
        self.cancel_tooltip()
        show_more = self.show_more_var.get()
        if show_more:
            self.result_table["columns"] = ["row_num", "instance", "info", "path", "line_number"]
            # 列宽配置
            self.result_table.column("row_num", width=self.ROW_NUM_COL_WIDTH, anchor="center")
            self.result_table.column("instance", width=180, anchor="w")
            self.result_table.column("info", width=280, anchor="w")
            self.result_table.column("path", width=230, anchor="w")
            self.result_table.column("line_number", width=90, anchor="center")
            # 列标题
            self.result_table.heading("row_num", text="No.")
            self.result_table.heading("instance", text="Instance")
            self.result_table.heading("info", text="Info")
            self.result_table.heading("path", text="Path")
            self.result_table.heading("line_number", text="Line Number")
        else:
            self.result_table["columns"] = ["row_num", "instance", "info"]
            # 列宽配置
            self.result_table.column("row_num", width=self.ROW_NUM_COL_WIDTH, anchor="center")
            self.result_table.column("instance", width=230, anchor="w")
            self.result_table.column("info", width=580, anchor="w")
            # 列标题
            self.result_table.heading("row_num", text="No.")
            self.result_table.heading("instance", text="Instance")
            self.result_table.heading("info", text="Info")
        # 刷新表格数据，保留选中状态
        self.refresh_table_data()

    def refresh_table_data(self):
        """刷新表格数据 - 包含行号，保留原生选中状态"""
        # 刷新表格时销毁提示
        self.cancel_tooltip()
        # 记录当前选中的行tag
        selected_tags = []
        for item_id in self.result_table.selection():
            tag = self.result_table.item(item_id, "tags")[0]
            if tag != "-1":
                selected_tags.append(tag)
        
        # 清空表格
        for item in self.result_table.get_children():
            self.result_table.delete(item)
        
        # 重新填充数据
        if not self.current_results:
            if self.show_more_var.get():
                self.result_table.insert("", tk.END, values=["-", "未找到Timing violation", "", "", ""], tags=("-1",))
            else:
                self.result_table.insert("", tk.END, values=["-", "未找到Timing violation", ""], tags=("-1",))
        else:
            for idx, res in enumerate(self.current_results):
                row_num = idx + 1
                if self.show_more_var.get():
                    item_id = self.result_table.insert(
                        "", tk.END,
                        values=[row_num, res["instance"], res["info"], res["path"], res["line_number"]],
                        tags=(str(idx),)
                    )
                else:
                    item_id = self.result_table.insert(
                        "", tk.END,
                        values=[row_num, res["instance"], res["info"]],
                        tags=(str(idx),)
                    )
                # 恢复选中状态
                if str(idx) in selected_tags:
                    self.result_table.selection_add(item_id)

    def waived_selected_rows(self):
        """Waived核心逻辑 - 批量移除同instance所有行"""
        # 执行waived时销毁提示
        self.cancel_tooltip()
        # 提取选中行的instance（去重）
        selected_instances = set()
        selected_tags = [self.result_table.item(item_id, "tags")[0] for item_id in self.result_table.selection()]
        for tag in selected_tags:
            if tag == "-1":
                continue
            idx = int(tag)
            selected_instances.add(self.current_results[idx]["instance"])
        
        # 无选中行提示
        if not selected_instances:
            messagebox.showinfo("提示", "请先通过鼠标左键选中需要移除的行！")
            return
        
        # 过滤保留的行
        remaining_results = [res for res in self.current_results if res["instance"] not in selected_instances]
        removed_count = len(self.current_results) - len(remaining_results)
        
        # 写入notimingcheck.lst文件
        try:
            with open("notimingcheck.lst", "a", encoding="utf-8") as f:
                for ins in selected_instances:
                    f.write(f"instance {{{ins}}} {{noTiming}}\n")
            
            # 更新数据源并刷新表格
            self.current_results = remaining_results
            self.refresh_table_data()
            messagebox.showinfo("成功", f"已移除{len(selected_instances)}个instance共{removed_count}行，结果已写入notimingcheck.lst！")
        except Exception as e:
            messagebox.showerror("错误", f"写入文件失败：\n{str(e)}")

    def show_analysis_result(self, file_path, results):
        """展示分析结果弹窗 - 悬停提示+双击复制"""
        try:
            if hasattr(self, 'result_win') and self.result_win.winfo_exists():
                self.result_win.destroy()
            
            # 数据源初始化
            self.current_results = results.copy()
            self.result_win = tk.Toplevel(self.root)
            self.result_win.title("Timing Violation分析")
            self.result_win.geometry("1050x550")
            self.result_win.transient(self.root)
            self.result_win.grab_set()

            # 1. 文件完整路径展示
            path_frame = ttk.Frame(self.result_win)
            path_frame.pack(fill=tk.X, padx=15, pady=8)
            ttk.Label(
                path_frame, text=f"文件完整路径：{file_path}",
                font=("SimHei 10" if sys.platform == "win32" else "Monospace 10"),
                wraplength=980
            ).pack(anchor="w")

            # 2. 标题+show more勾选框
            title_frame = ttk.Frame(self.result_win)
            title_frame.pack(fill=tk.X, padx=15, pady=5)
            ttk.Label(
                title_frame, text=f"匹配数：{len(results)}",
                font=("SimHei 11 bold" if sys.platform == "win32" else "Monospace 11 bold")
            ).pack(side=tk.LEFT)
            
            self.show_more_var = tk.BooleanVar(value=False)
            ttk.Checkbutton(
                title_frame, text="show more",
                variable=self.show_more_var,
                command=self.toggle_more_columns
            ).pack(side=tk.RIGHT)

            # 3. 表格容器 - 绑定完善的悬停/双击事件
            table_container = ttk.Frame(self.result_win)
            table_container.pack(fill=tk.BOTH, expand=True, padx=15, pady=5)

            # 初始化表格
            self.result_table = ttk.Treeview(
                table_container, columns=["row_num", "instance", "info"],
                show="headings", height=18, selectmode="extended"
            )
            # 初始列配置
            self.result_table.heading("row_num", text="No.")
            self.result_table.heading("instance", text="Instance")
            self.result_table.heading("info", text="Info")
            self.result_table.column("row_num", width=self.ROW_NUM_COL_WIDTH, anchor="center")
            self.result_table.column("instance", width=230, anchor="w")
            self.result_table.column("info", width=580, anchor="w")

            # 完善的事件绑定
            self.result_table.bind("<Motion>", self.schedule_tooltip)  # 鼠标移动：实时检测+调度
            self.result_table.bind("<Leave>", self.cancel_tooltip)     # 离开表格：强制销毁
            self.result_table.bind("<Button-1>", self.cancel_tooltip)  # 点击表格：强制销毁
            self.result_table.bind("<Double-1>", self.on_cell_double_click)  # 双击复制：销毁+复制
            self.result_table.bind("<MouseWheel>", self.cancel_tooltip)# 表格内滚轮：销毁提示

            # 表格滚动条
            table_scroll = ttk.Scrollbar(table_container, orient=tk.VERTICAL, command=self.result_table.yview)
            self.result_table.configure(yscrollcommand=table_scroll.set)
            self.result_table.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
            table_scroll.pack(side=tk.RIGHT, fill=tk.Y)

            # 4. 按钮区域（waived+关闭）
            btn_frame = ttk.Frame(self.result_win)
            btn_frame.pack(fill=tk.X, padx=15, pady=10)
            ttk.Button(btn_frame, text="waived", command=self.waived_selected_rows, width=15).pack(side=tk.LEFT, padx=5)
            ttk.Button(btn_frame, text="关闭", command=lambda: [self.cancel_tooltip(), self.result_win.destroy()], width=15).pack(side=tk.LEFT, padx=5)

            # 初始刷新表格
            self.refresh_table_data()
        except Exception as e:
            messagebox.showerror("弹窗出错", f"展示结果失败：\n{str(e)}")

    def search_files(self):
        """递归搜索文件并实时预览"""
        self.clear_preview()
        dir_path = self.selected_dir.get()
        pattern = self.search_pattern.get()

        if not dir_path or not os.path.isdir(dir_path):
            self.stats_label.config(text="匹配文件数：0 (请选择有效目录，实时预览)")
            return

        try:
            search_path = os.path.join(dir_path, "**", pattern)
            matched_files = [f for f in glob.iglob(search_path, recursive=True) if os.path.isfile(f)]
            matched_files.sort()

            for full_path in matched_files:
                rel_path = os.path.relpath(full_path, dir_path)
                file_row = ttk.Frame(self.scrollable_frame)
                file_row.pack(fill=tk.X, padx=3, pady=1)
                ttk.Label(file_row, text=rel_path, anchor="w", wraplength=700).pack(side=tk.LEFT, fill=tk.X, expand=True)
                ttk.Button(file_row, text="analyze", command=lambda fp=full_path: self.analyze_file(fp)).pack(side=tk.RIGHT, padx=5)
                self.file_frames.append(file_row)

            self.stats_label.config(text=f"匹配数：{len(matched_files)} (已递归搜索所有子目录，实时预览)")
        except Exception as e:
            self.stats_label.config(text=f"搜索出错：\n{str(e)}")

    def analyze_file(self, file_path):
        """分析单个文件"""
        # 打开分析窗口时销毁原有提示
        self.cancel_tooltip()
        results = self.extract_timing_violation(file_path)
        self.show_analysis_result(file_path, results)

if __name__ == "__main__":
    try:
        root = tk.Tk()
        app = FileSearcher(root)
        root.mainloop()
    except Exception as e:
        messagebox.showerror("程序启动失败", f"错误原因：\n{str(e)}")