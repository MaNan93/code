#!/usr/bin/env python3
"""fizz -- 从 generalMessage.txt 中提取文件路径，按顺序合并为一个文件。"""

import configparser
import datetime
import fnmatch
import ftplib
import glob
import hashlib
import os
import re
import shutil
import subprocess
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from urllib.parse import urlparse


class FizzApp:
    def __init__(self, root):
        self.root = root
        self.root.title("fizz - 文件合并工具")
        self.root.geometry("885x650")
        self.root.minsize(500, 400)
        self.root.update_idletasks()
        w = self.root.winfo_width()
        h = self.root.winfo_height()
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        x = (sw - w) // 2
        y = (sh - h) // 2
        self.root.geometry(f"+{x}+{y}")

        self.included_files = []   # included file 路径，保持相对顺序
        self.source_files = []     # source file 路径，保持相对顺序
        self.dir_filter_var = tk.StringVar()   # 目录过滤 (通配, 逗号/分号分隔)
        self.file_filter_var = tk.StringVar()  # 文件名过滤 (通配, 逗号/分号分隔)
        self.obf_tool_var = tk.StringVar(value="verible-verilog-obfuscate")
        self.strip_comments = tk.BooleanVar(value=False)  # 第2步开关
        self.protect_var = tk.BooleanVar(value=False)     # protect 开关
        self.top_file_var = tk.StringVar(value="pcie_ctrl_wrapper.sv")  # protect 的 top 文件名
        self.rlskit_cksum = ""
        self._rlskit_src_after_id: str | None = None
        self._raw_included_files: list[str] = []
        self._raw_source_files: list[str] = []
        self.script_dir = os.getcwd()
        self.pref_path = os.path.join(os.path.expanduser("~"), ".fizz.ini")

        # PostSim 分析
        self.postsim_dir_var = tk.StringVar(value=os.getcwd())
        self.postsim_pattern_var = tk.StringVar(value="*.log")
        self.postsim_file_frames = []
        self._postsim_search_id = None

        self._setup_style()
        self._setup_clipboard()
        self._build_menu()
        self._build_ui()
        self._ensure_pref_file()
        self._load_config()
        self._set_defaults()

        # PostSim 搜索绑定 + 初始搜索
        self.postsim_dir_var.trace_add("write", self._postsim_debounce)
        self.postsim_pattern_var.trace_add("write", self._postsim_debounce)
        self.root.after(500, self._postsim_search)

    def _build_menu(self):
        menubar = tk.Menu(self.root)

        file_menu = tk.Menu(menubar, tearoff=0)
        file_menu.add_command(label="preference...", command=self._open_preferences_dialog,
                              accelerator="Ctrl+P")
        file_menu.add_separator()
        file_menu.add_command(label="退出", command=self.root.destroy, accelerator="Alt+F4")
        menubar.add_cascade(label="File", menu=file_menu)

        help_menu = tk.Menu(menubar, tearoff=0)
        help_menu.add_command(label="关于 fizz", command=self._show_about)
        menubar.add_cascade(label="Help", menu=help_menu)

        self.root.config(menu=menubar)
        # 快捷键
        self.root.bind("<Control-p>", lambda e: self._open_preferences_dialog())

    def _open_preferences_dialog(self):
        dlg = tk.Toplevel(self.root)
        dlg.title("preference")
        dlg.geometry("700x480")
        dlg.minsize(600, 480)
        dlg.resizable(True, True)
        dlg.transient(self.root)
        dlg.grab_set()

        frame = ttk.Frame(dlg, padding=8)
        frame.pack(fill=tk.BOTH, expand=True)

        pref_dir_filter = tk.StringVar(value=self.dir_filter_var.get())
        pref_file_filter = tk.StringVar(value=self.file_filter_var.get())
        pref_vcs_key = tk.StringVar(value=self.vcs_key_var.get())
        pref_vcs_opt = tk.StringVar(value=self.vcs_opt_var.get())
        pref_obf_tool = tk.StringVar(value=self.obf_tool_var.get())
        pref_ftp_url = tk.StringVar(value=self.rlskit_ftp_url_var.get())
        pref_ftp_user = tk.StringVar(value=self.rlskit_ftp_user_var.get())
        pref_ftp_pass = tk.StringVar(value=self.rlskit_ftp_pass_var.get())

        def _add_row(r, label, var, browse_cmd=None, show=None):
            ttk.Label(frame, text=label, width=24).grid(row=r, column=0, sticky="w", padx=(0, 6), pady=4)
            entry = ttk.Entry(frame, textvariable=var, show=show if show else "")
            entry.grid(row=r, column=1, sticky="ew", pady=4)
            if browse_cmd is not None:
                ttk.Button(frame, text="浏览...", width=8, command=browse_cmd).grid(row=r, column=2, padx=(6, 0), pady=4)

        def _browse_pref_vcs_key():
            path = filedialog.askopenfilename(
                title="选择密钥文件",
                filetypes=[("Text files", "*.txt"), ("All", "*.*")],
                initialdir=self._dialog_initial_dir(pref_vcs_key.get()),
            )
            if path:
                pref_vcs_key.set(path)

        def _browse_pref_obf_tool():
            path = filedialog.askopenfilename(
                title="选择 verible-verilog-obfuscate 可执行文件",
                filetypes=[("Executable", "*"), ("All", "*.*")],
                initialdir=self._dialog_initial_dir(pref_obf_tool.get()),
            )
            if path:
                pref_obf_tool.set(path)

        _add_row(0, "1. 排除目录", pref_dir_filter)
        _add_row(1, "2. 排除文件", pref_file_filter)
        _add_row(2, "3. 密钥文件", pref_vcs_key, browse_cmd=_browse_pref_vcs_key)
        _add_row(3, "4. VCS Protect 选项", pref_vcs_opt)
        _add_row(4, "5. Obfuscator 路径", pref_obf_tool, browse_cmd=_browse_pref_obf_tool)
        _add_row(5, "6. RLskit URL", pref_ftp_url)
        _add_row(6, "   用户名", pref_ftp_user)
        _add_row(7, "   密码", pref_ftp_pass, show="*")

        frame.columnconfigure(1, weight=1)

        btn_row = ttk.Frame(frame)
        btn_row.grid(row=8, column=0, columnspan=3, sticky="e", pady=(10, 0))

        def _apply_fields():
            self.dir_filter_var.set(pref_dir_filter.get().strip())
            self.file_filter_var.set(pref_file_filter.get().strip())
            self.vcs_key_var.set(pref_vcs_key.get().strip())
            self.vcs_opt_var.set(pref_vcs_opt.get().strip())
            self.obf_tool_var.set(pref_obf_tool.get().strip() or "verible-verilog-obfuscate")
            self.rlskit_ftp_url_var.set(pref_ftp_url.get().strip())
            self.rlskit_ftp_user_var.set(pref_ftp_user.get().strip())
            self.rlskit_ftp_pass_var.set(pref_ftp_pass.get())

        def _apply_and_save():
            _apply_fields()
            self._save_preferences()

        def _open_pref_file():
            _apply_fields()
            self._save_config()
            self.global_status_var.set("配置已保存")
            self._open_config_file()

        ttk.Button(btn_row, text="打开配置", command=_open_pref_file).pack(side=tk.RIGHT, padx=(0, 6))
        ttk.Button(btn_row, text="保存配置", command=_apply_and_save).pack(side=tk.RIGHT, padx=(0, 6))

    def _save_preferences(self):
        try:
            self._save_config()
            self.global_status_var.set("配置已保存")
            messagebox.showinfo("提示", "配置已保存。")
        except Exception as e:
            messagebox.showerror("错误", f"保存配置失败:\n{e}")

    def _open_config_file(self):
        self._ensure_pref_file()
        try:
            subprocess.Popen(["gvim", self.pref_path])
        except FileNotFoundError:
            messagebox.showerror("错误", "未找到 gvim 命令，请确认 gvim 已安装并在 PATH 中。")
        except Exception as e:
            messagebox.showerror("错误", f"打开配置文件失败:\n{e}")

    def _show_about(self):
        self.root.update_idletasks()
        main_w = max(self.root.winfo_width(), 600)
        main_h = max(self.root.winfo_height(), 400)
        dlg_w = int(main_w * 0.7)
        dlg_h = int(main_h * 0.6)

        x = self.root.winfo_rootx() + max((main_w - dlg_w) // 2, 20)
        y = self.root.winfo_rooty() + max((main_h - dlg_h) // 2, 20)

        dlg = tk.Toplevel(self.root)
        dlg.title("about fizz")
        dlg.geometry(f"{dlg_w}x{dlg_h}+{x}+{y}")
        dlg.transient(self.root)
        dlg.grab_set()

        container = ttk.Frame(dlg, padding=8)
        container.pack(fill=tk.BOTH, expand=True)

        about_text = (
            "fizz 工具功能说明\n\n"
            "1. 合并\n"
            "- 从 generalMessage.txt 提取 included/source file 并按顺序合并\n"
            "- 支持过滤目录/文件、注释 include、可选 strip-comments、protect 插桩\n\n"
            "2. VCS Protect\n"
            "- 调用 vcs -ipprotect 对源文件做加密保护\n\n"
            "3. Obfuscator\n"
            "- 调用 verible-verilog-obfuscate 做混淆\n"
            "- 支持 load_map/save_map\n\n"
            "4. RLskit\n"
            "- 目录复制、打包 tar.gz、计算 cksum、可选 FTP 上传\n"
            "- 支持 FTP 目录浏览与 Release Note 编辑"
        )

        text = tk.Text(container, wrap=tk.WORD, font=("Consolas", 10), state=tk.NORMAL,
                       bg="#ffffff", fg="#333333", insertbackground="#333333",
                       selectbackground="#add6ff", selectforeground="#333333")
        v_scroll = ttk.Scrollbar(container, orient=tk.VERTICAL, command=text.yview)
        text.configure(yscrollcommand=v_scroll.set)

        text.grid(row=0, column=0, sticky="nsew")
        v_scroll.grid(row=0, column=1, sticky="ns")
        container.rowconfigure(0, weight=1)
        container.columnconfigure(0, weight=1)

        text.insert("1.0", about_text)
        text.configure(state=tk.DISABLED)

        # 关闭按钮
        btn_frame = ttk.Frame(container)
        btn_frame.grid(row=1, column=0, columnspan=2, pady=(8, 0))
        ttk.Button(btn_frame, text="关闭", command=dlg.destroy).pack()
        dlg.bind("<Escape>", lambda e: dlg.destroy())

    def _get_rlskit_history_rows(self):
        self._ensure_pref_file()
        cfg = configparser.ConfigParser()
        cfg.read(self.pref_path, encoding="utf-8")

        rows = []
        if cfg.has_section("RLskitHistoryTable"):
            sec = cfg["RLskitHistoryTable"]
            prefixes = set()
            for key in sec.keys():
                if key.startswith("row.") and "." in key[4:]:
                    prefixes.add(key.rsplit(".", 1)[0])

            for pref in sorted(prefixes):
                path = sec.get(f"{pref}.path", "")
                if not path:
                    continue
                rows.append({
                    "prefix": pref,
                    "path": path,
                    "version": sec.get(f"{pref}.last_version", ""),
                    "ftp_path": sec.get(f"{pref}.last_ftp_path", ""),
                    "upload_time": sec.get(f"{pref}.last_upload_time", ""),
                    "upload_file": sec.get(f"{pref}.last_upload_file", ""),
                })

        rows.sort(key=lambda r: r.get("upload_time", ""), reverse=True)
        return rows

    def _delete_rlskit_history_rows(self, prefixes):
        if not prefixes:
            return

        self._ensure_pref_file()
        cfg = configparser.ConfigParser()
        cfg.read(self.pref_path, encoding="utf-8")

        if not cfg.has_section("RLskitHistoryTable"):
            return

        sec = cfg["RLskitHistoryTable"]
        all_keys = list(sec.keys())
        for pref in prefixes:
            for key in all_keys:
                if key.startswith(f"{pref}."):
                    cfg.remove_option("RLskitHistoryTable", key)

        if cfg.has_section("RLskitHistoryTable") and not cfg.items("RLskitHistoryTable"):
            cfg.remove_section("RLskitHistoryTable")

        with open(self.pref_path, "w", encoding="utf-8") as f:
            cfg.write(f)

    def _open_history_view(self):
        dlg = tk.Toplevel(self.root)
        dlg.title("RLskit 历史查看")
        dlg.geometry("900x460")
        dlg.transient(self.root)
        dlg.grab_set()

        root_frame = ttk.Frame(dlg, padding=8)
        root_frame.pack(fill=tk.BOTH, expand=True)

        columns = ("path", "version", "upload_time")
        tree = ttk.Treeview(root_frame, columns=columns, show="headings")
        tree.heading("path", text="目录")
        tree.heading("version", text="版本号")
        tree.heading("upload_time", text="上传时间")

        tree.column("path", width=620, anchor="w")
        tree.column("version", width=90, anchor="center")
        tree.column("upload_time", width=150, anchor="center")

        v_scroll = ttk.Scrollbar(root_frame, orient=tk.VERTICAL, command=tree.yview)
        tree.configure(yscrollcommand=v_scroll.set)

        tree.grid(row=0, column=0, sticky="nsew")
        v_scroll.grid(row=0, column=1, sticky="ns")
        root_frame.rowconfigure(0, weight=1)
        root_frame.columnconfigure(0, weight=1)

        status_var = tk.StringVar(value="")
        ttk.Label(root_frame, textvariable=status_var, font=("", 8)).grid(row=1, column=0, columnspan=2, sticky="w", pady=(6, 0))

        btn_row = ttk.Frame(root_frame)
        btn_row.grid(row=2, column=0, columnspan=2, sticky="e", pady=(6, 0))

        row_map = {}
        tip_win: list[tk.Toplevel | None] = [None]
        tip_item: list[str] = [""]

        def _hide_tip():
            if tip_win[0] is not None:
                try:
                    tip_win[0].destroy()
                except tk.TclError:
                    pass
            tip_win[0] = None
            tip_item[0] = ""

        def _show_tip(item, x_root, y_root):
            row = row_map.get(item)
            if not row:
                _hide_tip()
                return

            if tip_item[0] == item and tip_win[0] is not None:
                sw = dlg.winfo_screenwidth()
                sh = dlg.winfo_screenheight()
                tip_win[0].geometry(f"+{min(x_root + 16, sw - 420)}+{min(y_root + 12, sh - 120)}")
                return

            _hide_tip()
            tw = tk.Toplevel(dlg)
            tw.overrideredirect(True)
            tw.attributes("-topmost", True)

            # 估算提示窗口尺寸
            sw = dlg.winfo_screenwidth()
            sh = dlg.winfo_screenheight()
            tip_w, tip_h = 400, 100
            tx = min(x_root + 16, sw - tip_w - 10)
            ty = min(y_root + 12, sh - tip_h - 10)
            tw.geometry(f"+{max(tx, 0)}+{max(ty, 0)}")

            info = (
                f"目录: {row.get('path', '')}\n"
                f"版本号: {row.get('version', '')}\n"
                f"FTP路径: {row.get('ftp_path', '')}\n"
                f"上传时间: {row.get('upload_time', '')}"
            )
            lbl = tk.Label(
                tw,
                text=info,
                justify=tk.LEFT,
                anchor="w",
                bg="#fffbe6",
                fg="#222",
                relief=tk.SOLID,
                borderwidth=1,
                padx=8,
                pady=6,
                font=("Consolas", 9),
            )
            lbl.pack(fill=tk.BOTH, expand=True)

            tip_win[0] = tw
            tip_item[0] = item

        def _on_motion(event):
            item = tree.identify_row(event.y)
            if not item:
                _hide_tip()
                return
            _show_tip(item, event.x_root, event.y_root)

        def _on_leave(_event):
            _hide_tip()

        tree.bind("<Motion>", _on_motion)
        tree.bind("<Leave>", _on_leave)
        dlg.bind("<FocusOut>", _on_leave)

        def _delete_selected():
            selected = tree.selection()
            if not selected:
                messagebox.showwarning("提示", "请先选择要删除的历史记录。")
                return

            if not messagebox.askyesno("确认", f"确认删除选中的 {len(selected)} 条历史记录？"):
                return

            prefixes = []
            for iid in selected:
                row = row_map.get(iid)
                if row and row.get("prefix"):
                    prefixes.append(row["prefix"])

            self._delete_rlskit_history_rows(prefixes)
            _hide_tip()
            _refresh()

        def _refresh():
            for item in tree.get_children():
                tree.delete(item)
            row_map.clear()

            rows = self._get_rlskit_history_rows()
            for row in rows:
                iid = tree.insert(
                    "",
                    tk.END,
                    values=(
                        row.get("path", ""),
                        row.get("version", ""),
                        row.get("upload_time", ""),
                    ),
                )
                row_map[iid] = row
            status_var.set(f"共 {len(rows)} 条目录历史记录")

        ttk.Button(btn_row, text="刷新", command=_refresh).pack(side=tk.RIGHT)
        ttk.Button(btn_row, text="删除选中", command=_delete_selected).pack(side=tk.RIGHT, padx=(0, 6))
        _refresh()

    # ------------------------------------------------------------------
    # 界面样式
    # ------------------------------------------------------------------
    def _setup_style(self):
        style = ttk.Style()
        available = style.theme_names()
        for t in ("clam", "alt", "default"):
            if t in available:
                style.theme_use(t)
                break

        bg_card = "#f0f2f4"
        bg_white = "#ffffff"
        border = "#b0b8c0"
        fg = "#111111"
        fg_dim = "#444444"
        green = "#2da44e"
        sel_bg = "#ddf4ff"

        style.configure(".", background=bg_card, foreground=fg, font=("Segoe UI", 9))
        style.configure("TFrame", background=bg_card)
        style.configure("TLabel", foreground=fg)
        style.configure("TLabelframe", background=bg_card, foreground=fg,
                        relief=tk.GROOVE, bordercolor=border)
        style.configure("TLabelframe.Label", foreground=fg, font=("Segoe UI", 9, "bold"))
        style.configure("TButton", padding=(12, 4), font=("Segoe UI", 9))
        style.map("TButton",
                  background=[("active", "#e2e5e9"), ("!active", bg_white)],
                  foreground=[("active", fg), ("!active", fg)],
                  relief=[("pressed", "sunken"), ("!pressed", "raised")])
        style.configure("TEntry", padding=4, fieldbackground=bg_white, foreground=fg,
                        bordercolor=border, insertcolor=fg, font=("Segoe UI", 9))
        style.configure("TSpinbox", padding=4, fieldbackground=bg_white, foreground=fg)
        style.configure("TNotebook", background=bg_card)
        style.configure("TNotebook.Tab", padding=(16, 5), font=("Segoe UI", 9, "bold"))
        style.map("TNotebook.Tab",
                  background=[("selected", bg_white), ("!selected", bg_card)],
                  foreground=[("selected", fg), ("!selected", fg_dim)],
                  lightcolor=[("selected", "#fd8c73"), ("!selected", border)])

        style.configure("Primary.TButton", padding=(14, 5), font=("Segoe UI", 9, "bold"))
        style.map("Primary.TButton",
                  background=[("active", "#2c974b"), ("!active", green)],
                  foreground=[("active", "white"), ("!active", "white")])

        style.configure("Status.TLabel", background=bg_card, foreground=fg_dim, font=("Segoe UI", 9))

        style.map("TCheckbutton",
                  background=[("active", bg_card), ("!active", bg_card)],
                  foreground=[("active", fg), ("!active", fg)])

        self.root.configure(bg=bg_card)

    # ------------------------------------------------------------------
    # 剪贴板绑定 (确保所有 Entry/Text 支持 Ctrl+C/V/X/A)
    # ------------------------------------------------------------------
    def _setup_clipboard(self):
        def _copy(w):
            try:
                if w.selection_present():
                    self.root.clipboard_clear()
                    self.root.clipboard_append(w.selection_get())
            except tk.TclError:
                pass
            return "break"

        def _cut(w):
            try:
                if w.selection_present():
                    self.root.clipboard_clear()
                    self.root.clipboard_append(w.selection_get())
                    if w.selection_present():
                        w.delete("sel.first", "sel.last")
            except tk.TclError:
                pass
            return "break"

        def _paste(w):
            try:
                text = self.root.clipboard_get()
                if w.selection_present():
                    w.delete("sel.first", "sel.last")
                w.insert(tk.INSERT, text)
            except tk.TclError:
                pass
            return "break"

        def _select_all(w):
            w.selection_range(0, tk.END)
            return "break"

        def _text_copy(w):
            try:
                if w.tag_ranges("sel"):
                    self.root.clipboard_clear()
                    self.root.clipboard_append(w.get("sel.first", "sel.last"))
            except tk.TclError:
                pass
            return "break"

        def _text_cut(w):
            try:
                if w.tag_ranges("sel"):
                    self.root.clipboard_clear()
                    self.root.clipboard_append(w.get("sel.first", "sel.last"))
                    w.delete("sel.first", "sel.last")
            except tk.TclError:
                pass
            return "break"

        def _text_paste(w):
            try:
                text = self.root.clipboard_get()
                if w.tag_ranges("sel"):
                    w.delete("sel.first", "sel.last")
                w.insert(tk.INSERT, text)
            except tk.TclError:
                pass
            return "break"

        def _text_select_all(w):
            w.tag_add("sel", "1.0", "end")
            return "break"

        for cls in ("TEntry", "Entry"):
            self.root.bind_class(cls, "<Control-c>", lambda e, a=_copy: a(e.widget) if isinstance(e.widget, (tk.Entry, ttk.Entry)) else None)
            self.root.bind_class(cls, "<Control-x>", lambda e, a=_cut: a(e.widget) if isinstance(e.widget, (tk.Entry, ttk.Entry)) else None)
            self.root.bind_class(cls, "<Control-v>", lambda e, a=_paste: a(e.widget) if isinstance(e.widget, (tk.Entry, ttk.Entry)) else None)
            self.root.bind_class(cls, "<Control-a>", lambda e, a=_select_all: a(e.widget) if isinstance(e.widget, (tk.Entry, ttk.Entry)) else None)

        self.root.bind_class("Text", "<Control-c>", lambda e, a=_text_copy: a(e.widget) if isinstance(e.widget, tk.Text) else None)
        self.root.bind_class("Text", "<Control-x>", lambda e, a=_text_cut: a(e.widget) if isinstance(e.widget, tk.Text) else None)
        self.root.bind_class("Text", "<Control-v>", lambda e, a=_text_paste: a(e.widget) if isinstance(e.widget, tk.Text) else None)
        self.root.bind_class("Text", "<Control-a>", lambda e, a=_text_select_all: a(e.widget) if isinstance(e.widget, tk.Text) else None)

    # ------------------------------------------------------------------
    # UI 构建
    # ------------------------------------------------------------------
    def _build_ui(self):
        nb = ttk.Notebook(self.root)
        nb.pack(fill=tk.BOTH, expand=True, padx=8, pady=(8, 2))

        # === 选项卡 1: 合并 ===
        merge_tab = ttk.Frame(nb, padding=4)
        nb.add(merge_tab, text="合并")
        self._build_merge_tab(merge_tab)

        # === 选项卡 2: VCS Protect ===
        vcs_tab = ttk.Frame(nb, padding=4)
        nb.add(vcs_tab, text="VCS Protect")
        self._build_vcs_tab(vcs_tab)

        # === 选项卡 3: Obfuscator ===
        obf_tab = ttk.Frame(nb, padding=4)
        nb.add(obf_tab, text="Obfuscator")
        self._build_obf_tab(obf_tab)

        # === 选项卡 4: RLskit ===
        rlskit_tab = ttk.Frame(nb, padding=4)
        nb.add(rlskit_tab, text="RLskit")
        self._build_rlskit_tab(rlskit_tab)

        # === 选项卡 5: 后仿分析 ===
        postsim_tab = ttk.Frame(nb, padding=4)
        nb.add(postsim_tab, text="后仿分析")
        self._build_postsim_tab(postsim_tab)

        # -- 全局状态栏 --
        self.global_status_var = tk.StringVar(value="就绪")
        sf = ttk.Frame(self.root)
        sf.pack(fill=tk.X, side=tk.BOTTOM, padx=8, pady=(0, 4))
        ttk.Separator(sf, orient=tk.HORIZONTAL).pack(fill=tk.X)
        ttk.Label(sf, textvariable=self.global_status_var, style="Status.TLabel").pack(anchor=tk.W, pady=(2, 0))

    def _build_merge_tab(self, parent):
        # -- 消息文件选择 --
        top_frame = ttk.LabelFrame(parent, text="消息文件 (generalMessage.txt)", padding=6)
        top_frame.pack(fill=tk.X, pady=(0, 2))

        self.msg_path_var = tk.StringVar()
        ttk.Entry(top_frame, textvariable=self.msg_path_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))
        ttk.Button(top_frame, text="浏览...", width=7, command=self._browse_msg).pack(side=tk.LEFT, padx=2)
        ttk.Button(top_frame, text="解析", command=self._parse).pack(side=tk.LEFT, padx=2)

        # -- 过滤规则 --
        filter_frame = ttk.LabelFrame(parent, text="过滤规则 (通配, 逗号/分号分隔)", padding=6)
        filter_frame.pack(fill=tk.X, pady=(0, 2))

        dir_row = ttk.Frame(filter_frame)
        dir_row.pack(fill=tk.X, pady=(0, 2))
        ttk.Label(dir_row, text="排除目录:", width=8).pack(side=tk.LEFT)
        ttk.Entry(dir_row, textvariable=self.dir_filter_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)

        file_row = ttk.Frame(filter_frame)
        file_row.pack(fill=tk.X)
        ttk.Label(file_row, text="排除文件:", width=8).pack(side=tk.LEFT)
        ttk.Entry(file_row, textvariable=self.file_filter_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)
        ttk.Button(file_row, text="重新过滤", command=self._apply_filter).pack(side=tk.LEFT)

        # -- 文件列表 --
        list_frame = ttk.LabelFrame(parent, text="文件列表", padding=4)
        list_frame.pack(fill=tk.BOTH, expand=True, pady=4)

        self.file_listbox = tk.Listbox(list_frame, selectmode=tk.EXTENDED, exportselection=False,
                                       bg="#ffffff", fg="#333333",
                                       selectbackground="#add6ff", selectforeground="#333333",
                                       highlightbackground="#e0e0e0")
        scroll = ttk.Scrollbar(list_frame, orient=tk.VERTICAL, command=self.file_listbox.yview)
        self.file_listbox.configure(yscrollcommand=scroll.set)
        self.file_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)

        # -- 文件列表右键菜单 --
        self._file_list_menu = tk.Menu(self.file_listbox, tearoff=0)
        self._file_list_menu.add_command(label="复制路径", command=self._file_list_copy)
        self._file_list_menu.add_separator()
        self._file_list_menu.add_command(label="全选 (Ctrl+A)", command=lambda: self.file_listbox.select_set(0, tk.END))
        self._file_list_menu.add_command(label="取消全选", command=lambda: self.file_listbox.select_clear(0, tk.END))
        self._file_list_menu.add_command(label="反选", command=self._file_list_invert)
        self.file_listbox.bind("<Button-3>", self._file_list_popup)
        self.file_listbox.bind("<Button-2>", self._file_list_popup)  # Linux 中键=右键

        # -- 输出与操作 --
        bottom_frame = ttk.LabelFrame(parent, text="输出", padding=6)
        bottom_frame.pack(fill=tk.X, pady=(2, 0))

        out_row = ttk.Frame(bottom_frame)
        out_row.pack(fill=tk.X)
        ttk.Label(out_row, text="输出文件:").pack(side=tk.LEFT)
        self.out_path_var = tk.StringVar()
        ttk.Entry(out_row, textvariable=self.out_path_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)
        ttk.Button(out_row, text="浏览...", width=7, command=self._browse_out).pack(side=tk.LEFT)

        protect_row = ttk.Frame(bottom_frame)
        protect_row.pack(fill=tk.X, pady=(6, 0))
        ttk.Checkbutton(protect_row, text="protect", variable=self.protect_var).pack(side=tk.LEFT)
        ttk.Label(protect_row, text="top module file:").pack(side=tk.LEFT, padx=(8, 0))
        ttk.Entry(protect_row, textvariable=self.top_file_var, width=24).pack(side=tk.LEFT, padx=2)

        btn_row = ttk.Frame(bottom_frame)
        btn_row.pack(fill=tk.X, pady=(8, 0))
        ttk.Checkbutton(btn_row, text="verible strip-comments", variable=self.strip_comments).pack(side=tk.LEFT)
        self.merge_btn = ttk.Button(btn_row, text="合并", style="Primary.TButton", command=self._merge)
        self.merge_btn.pack(side=tk.RIGHT, padx=2)

        self.progress = ttk.Progressbar(bottom_frame, mode="determinate")
        self.progress.pack(fill=tk.X, pady=(6, 0))
        self.status_var = tk.StringVar(value="就绪")
        ttk.Label(bottom_frame, textvariable=self.status_var, style="Status.TLabel").pack(anchor=tk.W)

    def _build_vcs_tab(self, parent):
        # -- 源文件 --
        src_frame = ttk.LabelFrame(parent, text="源文件", padding=6)
        src_frame.pack(fill=tk.X, pady=(0, 4))

        self.vcs_src_var = tk.StringVar()
        ttk.Entry(src_frame, textvariable=self.vcs_src_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))
        ttk.Button(src_frame, text="浏览...", width=7, command=self._browse_vcs_src).pack(side=tk.LEFT)

        # -- 密钥文件 --
        key_frame = ttk.LabelFrame(parent, text="密钥文件 (-ipprotect)", padding=6)
        key_frame.pack(fill=tk.X, pady=(0, 4))

        self.vcs_key_var = tk.StringVar()
        ttk.Entry(key_frame, textvariable=self.vcs_key_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))
        ttk.Button(key_frame, text="浏览...", width=7, command=self._browse_vcs_key).pack(side=tk.LEFT)

        # -- 选项 --
        opt_frame = ttk.LabelFrame(parent, text="选项", padding=6)
        opt_frame.pack(fill=tk.X, pady=(0, 4))

        self.vcs_opt_var = tk.StringVar(value="-ipopt=partialprotect -ipopt=overwrite")
        ttk.Entry(opt_frame, textvariable=self.vcs_opt_var).pack(fill=tk.X)

        # -- 执行 --
        run_frame = ttk.Frame(parent)
        run_frame.pack(fill=tk.X, pady=(0, 4))
        self.vcs_run_btn = ttk.Button(run_frame, text="执行 VCS Protect", style="Primary.TButton", command=self._run_vcs)
        self.vcs_run_btn.pack(side=tk.RIGHT)
        ttk.Button(run_frame, text="清除日志", width=8,
                   command=lambda: (self.vcs_log.configure(state=tk.NORMAL),
                                    self.vcs_log.delete("1.0", tk.END),
                                    self.vcs_log.configure(state=tk.DISABLED))).pack(side=tk.RIGHT, padx=(0, 4))

        # -- 输出日志 --
        log_frame = ttk.LabelFrame(parent, text="输出日志", padding=4)
        log_frame.pack(fill=tk.BOTH, expand=True)

        self.vcs_log = tk.Text(log_frame, wrap=tk.WORD, state=tk.DISABLED, font=("Consolas", 9),
                               bg="#ffffff", fg="#333333", insertbackground="#333333",
                               selectbackground="#add6ff", selectforeground="#333333")
        v_scroll = ttk.Scrollbar(log_frame, orient=tk.VERTICAL, command=self.vcs_log.yview)
        self.vcs_log.configure(yscrollcommand=v_scroll.set)
        self.vcs_log.grid(row=0, column=0, sticky="nsew")
        v_scroll.grid(row=0, column=1, sticky="ns")
        log_frame.rowconfigure(0, weight=1)
        log_frame.columnconfigure(0, weight=1)

    def _build_obf_tab(self, parent):
        # -- 源文件 --
        src_frame = ttk.LabelFrame(parent, text="源文件", padding=6)
        src_frame.pack(fill=tk.X, pady=(0, 4))

        self.obf_src_var = tk.StringVar()
        self.obf_src_var.trace_add("write", lambda *_: self._update_obf_defaults())
        ttk.Entry(src_frame, textvariable=self.obf_src_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))
        ttk.Button(src_frame, text="浏览...", width=7, command=self._browse_obf_src).pack(side=tk.LEFT)

        # -- 输出文件 --
        out_frame = ttk.LabelFrame(parent, text="输出文件", padding=6)
        out_frame.pack(fill=tk.X, pady=(0, 4))

        self.obf_out_var = tk.StringVar()
        ttk.Entry(out_frame, textvariable=self.obf_out_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))
        ttk.Button(out_frame, text="浏览...", width=7, command=self._browse_obf_out).pack(side=tk.LEFT)

        # -- Map 文件 --
        map_frame = ttk.LabelFrame(parent, text="Map 文件", padding=6)
        map_frame.pack(fill=tk.X, pady=(0, 4))

        m_row1 = ttk.Frame(map_frame)
        m_row1.pack(fill=tk.X, pady=(0, 2))
        ttk.Label(m_row1, text="load_map:").pack(side=tk.LEFT)
        self.obf_load_map_var = tk.StringVar()
        ttk.Entry(m_row1, textvariable=self.obf_load_map_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)
        ttk.Button(m_row1, text="浏览...", width=7, command=self._browse_obf_load_map).pack(side=tk.LEFT)

        m_row2 = ttk.Frame(map_frame)
        m_row2.pack(fill=tk.X)
        ttk.Label(m_row2, text="save_map:").pack(side=tk.LEFT)
        self.obf_save_map_var = tk.StringVar()
        ttk.Entry(m_row2, textvariable=self.obf_save_map_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)
        ttk.Button(m_row2, text="浏览...", width=7, command=self._browse_obf_save_map).pack(side=tk.LEFT)

        # -- 工具 --
        tool_frame = ttk.Frame(parent)
        tool_frame.pack(fill=tk.X, pady=(0, 4))
        ttk.Label(tool_frame, text="混淆器:").pack(side=tk.LEFT)
        self.obf_tool_display = ttk.Entry(tool_frame, textvariable=self.obf_tool_var,
                                          state="readonly", width=40)
        self.obf_tool_display.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)

        # -- 执行 --
        run_frame = ttk.Frame(parent)
        run_frame.pack(fill=tk.X, pady=(0, 4))
        self.obf_run_btn = ttk.Button(run_frame, text="执行 Obfuscate", style="Primary.TButton", command=self._run_obfuscate)
        self.obf_run_btn.pack(side=tk.RIGHT)
        ttk.Button(run_frame, text="清除日志", width=8,
                   command=lambda: (self.obf_log.configure(state=tk.NORMAL),
                                    self.obf_log.delete("1.0", tk.END),
                                    self.obf_log.configure(state=tk.DISABLED))).pack(side=tk.RIGHT, padx=(0, 4))

        # -- 输出日志 --
        log_frame = ttk.LabelFrame(parent, text="输出日志", padding=4)
        log_frame.pack(fill=tk.BOTH, expand=True)

        self.obf_log = tk.Text(log_frame, wrap=tk.WORD, state=tk.DISABLED, font=("Consolas", 9),
                               bg="#ffffff", fg="#333333", insertbackground="#333333",
                               selectbackground="#add6ff", selectforeground="#333333")
        v_scroll = ttk.Scrollbar(log_frame, orient=tk.VERTICAL, command=self.obf_log.yview)
        self.obf_log.configure(yscrollcommand=v_scroll.set)
        self.obf_log.grid(row=0, column=0, sticky="nsew")
        v_scroll.grid(row=0, column=1, sticky="ns")
        log_frame.rowconfigure(0, weight=1)
        log_frame.columnconfigure(0, weight=1)

    def _build_rlskit_tab(self, parent):
        # -- 源目录 --
        src_frame = ttk.LabelFrame(parent, text="源目录", padding=6)
        src_frame.pack(fill=tk.X, pady=(0, 4))

        self.rlskit_src_var = tk.StringVar()
        self.rlskit_src_var.trace_add("write", lambda *_: self._on_rlskit_src_changed())
        ttk.Entry(src_frame, textvariable=self.rlskit_src_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))
        ttk.Button(src_frame, text="浏览...", width=7, command=self._browse_rlskit_src).pack(side=tk.LEFT)

        # -- 版本号 --
        ver_frame = ttk.LabelFrame(parent, text="版本号", padding=6)
        ver_frame.pack(fill=tk.X, pady=(0, 4))

        v_row = ttk.Frame(ver_frame)
        v_row.pack(fill=tk.X)
        ttk.Label(v_row, text="版本号:").pack(side=tk.LEFT)
        self.rlskit_suffix_var = tk.StringVar(value="V1P0")
        self.rlskit_suffix_var.trace_add("write", lambda *_: self._update_rlskit_preview())
        ttk.Entry(v_row, textvariable=self.rlskit_suffix_var, width=30).pack(side=tk.LEFT, padx=4)

        # 文件预览（下一行）
        pv_row = ttk.Frame(ver_frame)
        pv_row.pack(fill=tk.X, pady=(4, 0))
        ttk.Label(pv_row, text="→").pack(side=tk.LEFT, padx=2)
        self.rlskit_dst_var = tk.StringVar()
        ttk.Entry(pv_row, textvariable=self.rlskit_dst_var, state="readonly").pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)

        # -- FTP 配置 --
        ftp_frame = ttk.LabelFrame(parent, text="FTP 上传", padding=6)
        ftp_frame.pack(fill=tk.X, pady=(0, 4))

        f_row1 = ttk.Frame(ftp_frame)
        f_row1.pack(fill=tk.X, pady=(0, 2))
        ttk.Label(f_row1, text="URL:").pack(side=tk.LEFT)
        self.rlskit_ftp_url_var = tk.StringVar()
        ttk.Entry(f_row1, textvariable=self.rlskit_ftp_url_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)
        ttk.Button(f_row1, text="浏览FTP...", width=7, command=self._browse_ftp).pack(side=tk.LEFT)

        f_row2 = ttk.Frame(ftp_frame)
        f_row2.pack(fill=tk.X, pady=(0, 2))
        ttk.Label(f_row2, text="用户:").pack(side=tk.LEFT)
        self.rlskit_ftp_user_var = tk.StringVar()
        ttk.Entry(f_row2, textvariable=self.rlskit_ftp_user_var, width=20).pack(side=tk.LEFT, padx=4)
        ttk.Label(f_row2, text="密码:").pack(side=tk.LEFT, padx=(8, 0))
        self.rlskit_ftp_pass_var = tk.StringVar()
        ttk.Entry(f_row2, textvariable=self.rlskit_ftp_pass_var, width=20, show="*").pack(side=tk.LEFT, padx=4)

        # -- 执行 --
        run_frame = ttk.Frame(parent)
        run_frame.pack(fill=tk.X, pady=(0, 4))
        self.rlskit_copy_btn = ttk.Button(run_frame, text="cksum copy", width=11,
                                          command=self._copy_cksum, state=tk.DISABLED)
        self.rlskit_copy_btn.pack(side=tk.LEFT)
        self.rlskit_run_btn = ttk.Button(run_frame, text="执行打包上传", style="Primary.TButton", command=self._run_rlskit)
        self.rlskit_run_btn.pack(side=tk.RIGHT)
        ttk.Button(run_frame, text="历史", width=6, command=self._open_history_view).pack(side=tk.RIGHT, padx=(0, 4))

        # -- 子选项卡：输出日志 / Release Note --
        sub_nb = ttk.Notebook(parent)
        sub_nb.pack(fill=tk.BOTH, expand=True)

        # 输出日志
        log_tab = ttk.Frame(sub_nb, padding=4)
        sub_nb.add(log_tab, text="输出日志")
        self.rlskit_log = tk.Text(log_tab, wrap=tk.WORD, state=tk.DISABLED, font=("Consolas", 9),
                                  bg="#ffffff", fg="#333333", insertbackground="#333333",
                                  selectbackground="#add6ff", selectforeground="#333333")
        v_scroll = ttk.Scrollbar(log_tab, orient=tk.VERTICAL, command=self.rlskit_log.yview)
        self.rlskit_log.configure(yscrollcommand=v_scroll.set)
        self.rlskit_log.grid(row=0, column=0, sticky="nsew")
        v_scroll.grid(row=0, column=1, sticky="ns")
        log_tab.rowconfigure(0, weight=1)
        log_tab.columnconfigure(0, weight=1)

        # Release Note
        rn_tab = ttk.Frame(sub_nb, padding=4)
        sub_nb.add(rn_tab, text="Release Note")
        rn_btn_frame = ttk.Frame(rn_tab)
        rn_btn_frame.pack(fill=tk.X, pady=(0, 4))
        ttk.Button(rn_btn_frame, text="刷新", width=7, command=self._load_release_note).pack(side=tk.LEFT)
        ttk.Button(rn_btn_frame, text="保存", width=7, command=self._save_release_note).pack(side=tk.LEFT, padx=(4, 0))

        rn_text_frame = ttk.Frame(rn_tab)
        rn_text_frame.pack(fill=tk.BOTH, expand=True)
        self.rn_text = tk.Text(rn_text_frame, wrap=tk.WORD, font=("Consolas", 10), undo=True,
                               bg="#ffffff", fg="#333333", insertbackground="#333333",
                               selectbackground="#add6ff", selectforeground="#333333")
        rn_v_scroll = ttk.Scrollbar(rn_text_frame, orient=tk.VERTICAL, command=self.rn_text.yview)
        self.rn_text.configure(yscrollcommand=rn_v_scroll.set)
        self.rn_text.grid(row=0, column=0, sticky="nsew")
        rn_v_scroll.grid(row=0, column=1, sticky="ns")
        rn_text_frame.rowconfigure(0, weight=1)
        rn_text_frame.columnconfigure(0, weight=1)
        self.rn_text.bind("<Control-s>", lambda e: self._save_release_note())
        self.rn_text.bind("<Control-S>", lambda e: self._save_release_note())

    def _release_note_path(self):
        src = self.rlskit_src_var.get().strip()
        if src and os.path.isdir(src):
            return os.path.join(src, "Release_Note.txt")
        return ""

    def _load_release_note(self):
        if not hasattr(self, "rn_text"):
            return
        path = self._release_note_path()
        if path and os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            self.rn_text.delete("1.0", tk.END)
            self.rn_text.insert("1.0", content)
            self.rn_text.edit_modified(False)
        else:
            self.rn_text.delete("1.0", tk.END)
            if path:
                self.rn_text.insert("1.0", f"; 未找到 Release_Note.txt\n; 路径: {path}\n")

    def _save_release_note(self):
        path = self._release_note_path()
        if not path:
            messagebox.showwarning("提示", "请先在 RLskit 选项卡中选择源目录。")
            return
        content = self.rn_text.get("1.0", "end-1c")
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        self.rn_text.edit_modified(False)
        messagebox.showinfo("提示", f"已保存: {os.path.basename(path)}")

    # ------------------------------------------------------------------
    # ~/.fizz.ini 配置
    # ------------------------------------------------------------------
    def _ensure_pref_file(self):
        if not os.path.isfile(self.pref_path):
            self._create_default_config()

    def _load_config(self):
        self._ensure_pref_file()
        cfg = configparser.ConfigParser()
        cfg.read(self.pref_path, encoding="utf-8")

        # Preference
        if cfg.has_section("Preference"):
            self.dir_filter_var.set(cfg.get("Preference", "exclude_dirs", fallback=""))
            self.file_filter_var.set(cfg.get("Preference", "exclude_files", fallback=""))
            self.vcs_key_var.set(cfg.get("Preference", "vcs_key_file", fallback=self.vcs_key_var.get()))
            self.vcs_opt_var.set(cfg.get("Preference", "vcs_options", fallback=self.vcs_opt_var.get()))
            self.obf_tool_var.set(cfg.get("Preference", "obfuscator_path", fallback="verible-verilog-obfuscate"))

        # RLskit 默认值
        if cfg.has_section("RLskitDefault"):
            self.rlskit_ftp_url_var.set(cfg.get("RLskitDefault", "ftp_url", fallback=self.rlskit_ftp_url_var.get()))
            self.rlskit_ftp_user_var.set(cfg.get("RLskitDefault", "ftp_username", fallback=self.rlskit_ftp_user_var.get()))
            self.rlskit_ftp_pass_var.set(cfg.get("RLskitDefault", "ftp_password", fallback=self.rlskit_ftp_pass_var.get()))

        # 最近版本号
        if cfg.has_section("History"):
            last_ver = cfg.get("History", "last_version", fallback="")
            if last_ver:
                self.rlskit_suffix_var.set(last_ver)

    def _create_default_config(self):
        cfg = configparser.ConfigParser()
        cfg.add_section("Preference")
        cfg.set("Preference", "exclude_dirs", "")
        cfg.set("Preference", "exclude_files", "")
        cfg.set("Preference", "vcs_key_file", "")
        cfg.set("Preference", "vcs_options", "-ipopt=partialprotect -ipopt=overwrite")
        cfg.set("Preference", "obfuscator_path", "verible-verilog-obfuscate")

        cfg.add_section("RLskitDefault")
        cfg.set("RLskitDefault", "ftp_url", "ftp://share.srv/")
        cfg.set("RLskitDefault", "ftp_username", "")
        cfg.set("RLskitDefault", "ftp_password", "")

        cfg.add_section("History")
        cfg.set("History", "last_version", "V1P0")
        cfg.set("History", "last_timestamp", "")
        with open(self.pref_path, "w", encoding="utf-8") as f:
            cfg.write(f)

    def _save_config(self):
        cfg = configparser.ConfigParser()
        if os.path.isfile(self.pref_path):
            cfg.read(self.pref_path, encoding="utf-8")

        # Preference
        if not cfg.has_section("Preference"):
            cfg.add_section("Preference")
        cfg.set("Preference", "exclude_dirs", self.dir_filter_var.get().strip())
        cfg.set("Preference", "exclude_files", self.file_filter_var.get().strip())
        cfg.set("Preference", "vcs_key_file", self.vcs_key_var.get().strip())
        cfg.set("Preference", "vcs_options", self.vcs_opt_var.get().strip())
        cfg.set("Preference", "obfuscator_path", self.obf_tool_var.get().strip() or "verible-verilog-obfuscate")

        # RLskit 默认值
        if not cfg.has_section("RLskitDefault"):
            cfg.add_section("RLskitDefault")
        cfg.set("RLskitDefault", "ftp_url", self.rlskit_ftp_url_var.get().strip())
        cfg.set("RLskitDefault", "ftp_username", self.rlskit_ftp_user_var.get().strip())
        cfg.set("RLskitDefault", "ftp_password", self.rlskit_ftp_pass_var.get())

        # History
        if not cfg.has_section("History"):
            cfg.add_section("History")
        cfg.set("History", "last_version", self.rlskit_suffix_var.get().strip())
        cfg.set("History", "last_timestamp", datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

        with open(self.pref_path, "w", encoding="utf-8") as f:
            cfg.write(f)

    def _canonical_path(self, path):
        return os.path.normcase(os.path.normpath(os.path.abspath(path)))

    def _rlskit_history_row_prefix(self, src_path):
        abs_path = self._canonical_path(src_path)
        key = hashlib.sha1(abs_path.encode("utf-8", errors="replace")).hexdigest()
        return f"row.{key}"

    def _load_rlskit_from_home(self, src_path):
        if not os.path.isfile(self.pref_path):
            self._create_default_config()

        cfg = configparser.ConfigParser()
        cfg.read(self.pref_path, encoding="utf-8")

        if cfg.has_section("RLskitDefault"):
            self.rlskit_ftp_url_var.set(cfg.get("RLskitDefault", "ftp_url", fallback=self.rlskit_ftp_url_var.get()))
            self.rlskit_ftp_user_var.set(cfg.get("RLskitDefault", "ftp_username", fallback=self.rlskit_ftp_user_var.get()))
            self.rlskit_ftp_pass_var.set(cfg.get("RLskitDefault", "ftp_password", fallback=self.rlskit_ftp_pass_var.get()))

        # 新结构: 统一历史表，每个目录一条记录
        if cfg.has_section("RLskitHistoryTable"):
            pref = self._rlskit_history_row_prefix(src_path)
            row_path = cfg.get("RLskitHistoryTable", f"{pref}.path", fallback="")
            if row_path and self._canonical_path(row_path) == self._canonical_path(src_path):
                self.rlskit_ftp_url_var.set(cfg.get("RLskitHistoryTable", f"{pref}.ftp_url", fallback=self.rlskit_ftp_url_var.get()))
                self.rlskit_ftp_user_var.set(cfg.get("RLskitHistoryTable", f"{pref}.ftp_username", fallback=self.rlskit_ftp_user_var.get()))
                self.rlskit_ftp_pass_var.set(cfg.get("RLskitHistoryTable", f"{pref}.ftp_password", fallback=self.rlskit_ftp_pass_var.get()))
                last_ver = cfg.get("RLskitHistoryTable", f"{pref}.last_version", fallback="")
                if last_ver:
                    self.rlskit_suffix_var.set(last_ver)
                return

    def _on_rlskit_src_changed(self):
        if self._rlskit_src_after_id is not None:
            self.root.after_cancel(self._rlskit_src_after_id)
        self._rlskit_src_after_id = self.root.after(500, self._do_rlskit_src_changed)

    def _do_rlskit_src_changed(self):
        self._rlskit_src_after_id = None
        self._update_rlskit_preview()
        self._load_release_note()

        src = self.rlskit_src_var.get().strip()
        if src and os.path.isdir(src):
            self._load_rlskit_from_home(src)

    # ------------------------------------------------------------------
    # 默认值
    # ------------------------------------------------------------------
    def _set_defaults(self):
        default_msg = os.path.join(self.script_dir, "generalMessage.txt")
        self.msg_path_var.set(default_msg)
        self.out_path_var.set(os.path.join(self.script_dir, "one.sv"))

        # RLskit: 源目录默认跟随当前启动目录
        if os.path.isdir(self.script_dir):
            self.rlskit_src_var.set(self.script_dir)

        # VCS Protect: 源文件默认 = 合并输出
        self.vcs_src_var.set(os.path.join(self.script_dir, "one.sv"))

        # VCS Protect: 密钥文件默认 = $PCIEGEN/sim2-key.txt
        pciegen = os.environ.get("PCIEGEN", "")
        if pciegen and not self.vcs_key_var.get().strip():
            self.vcs_key_var.set(os.path.join(pciegen, "sim2-key.txt"))

        if os.path.isfile(default_msg):
            self._parse()

        # Obfuscator: 源文件默认 = 合并输出
        self.obf_src_var.set(os.path.join(self.script_dir, "one.sv"))

    # ------------------------------------------------------------------
    # 文件浏览
    # ------------------------------------------------------------------
    def _browse_msg(self):
        path = filedialog.askopenfilename(
            title="选择消息文件",
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")],
            initialdir=self.script_dir,
        )
        if path:
            self.msg_path_var.set(path)

    def _browse_out(self):
        path = filedialog.asksaveasfilename(
            title="保存合并结果",
            defaultextension=".sv",
            filetypes=[("SystemVerilog", "*.sv"), ("Verilog", "*.v"), ("Text", "*.txt"), ("All", "*.*")],
            initialdir=self.script_dir,
        )
        if path:
            self.out_path_var.set(path)

    def _browse_vcs_src(self):
        path = filedialog.askopenfilename(
            title="选择源文件",
            filetypes=[("SystemVerilog", "*.sv"), ("Verilog", "*.v"), ("All", "*.*")],
            initialdir=self.script_dir,
        )
        if path:
            self.vcs_src_var.set(path)

    def _browse_vcs_key(self):
        path = filedialog.askopenfilename(
            title="选择密钥文件",
            filetypes=[("Text files", "*.txt"), ("All", "*.*")],
            initialdir=self._dialog_initial_dir(self.vcs_key_var.get()),
        )
        if path:
            self.vcs_key_var.set(path)

    # ------------------------------------------------------------------
    # 解析
    # ------------------------------------------------------------------
    def _parse(self):
        msg_path = self.msg_path_var.get().strip()
        if not msg_path:
            messagebox.showwarning("提示", "请先选择消息文件。")
            return
        if not os.path.isfile(msg_path):
            messagebox.showerror("错误", f"文件不存在:\n{msg_path}")
            return

        try:
            with open(msg_path, "r", encoding="utf-8") as f:
                content = f.read()
        except UnicodeDecodeError:
            try:
                with open(msg_path, "r", encoding="gbk") as f:
                    content = f.read()
            except Exception as e:
                messagebox.showerror("错误", f"读取文件失败:\n{e}")
                return
        except Exception as e:
            messagebox.showerror("错误", f"读取文件失败:\n{e}")
            return

        # 按行扫描，分别提取 "included file" / "source file" 关键字后的双引号路径
        inc = []
        src = []
        for line in content.splitlines():
            if "included file" in line.lower():
                m = re.search(r'"([^"]*)"', line)
                if m:
                    inc.append(m.group(1))
            elif "source file" in line.lower():
                m = re.search(r'"([^"]*)"', line)
                if m:
                    src.append(m.group(1))

        self._raw_included_files = list(dict.fromkeys(inc))
        self._raw_source_files = list(dict.fromkeys(src))
        self.included_files = self._raw_included_files[:]
        self.source_files = self._raw_source_files[:]

        # 应用过滤规则
        dir_patterns = [p.strip() for p in re.split(r'[,;，；]+', self.dir_filter_var.get()) if p.strip()]
        file_patterns = [p.strip() for p in re.split(r'[,;，；]+', self.file_filter_var.get()) if p.strip()]

        if dir_patterns or file_patterns:
            ini_before = len(self._raw_included_files)
            src_before = len(self._raw_source_files)
            self.included_files = [p for p in self._raw_included_files if self._match_filter(p, dir_patterns, file_patterns)]
            self.source_files = [p for p in self._raw_source_files if self._match_filter(p, dir_patterns, file_patterns)]
            self._refresh_list()
            self.status_var.set(
                f"解析完成: included {ini_before}->{len(self.included_files)}, "
                f"source {src_before}->{len(self.source_files)}"
            )
        else:
            self._refresh_list()
            self.status_var.set(
                f"解析完成: included={len(inc)}(去重={len(self._raw_included_files)}), "
                f"source={len(src)}(去重={len(self._raw_source_files)})"
            )

    def _match_filter(self, path, dir_patterns, file_patterns):
        """path 是否通过过滤 (True=保留, False=排除)。"""
        basename = os.path.basename(path)
        dirname = os.path.dirname(path)

        for pat in file_patterns:
            if fnmatch.fnmatch(basename, pat):
                return False

        for pat in dir_patterns:
            # 同时对完整目录路径和单级目录名做匹配
            if fnmatch.fnmatch(dirname, pat) or fnmatch.fnmatch(dirname, f"*{os.sep}{pat}*"):
                return False
            # 逐级目录匹配
            parts = dirname.replace("\\", "/").split("/")
            if any(fnmatch.fnmatch(p, pat) for p in parts if p):
                return False

        return True

    def _apply_filter(self):
        """对已解析的原始列表重新应用过滤规则，不重新读文件。"""
        if not self._raw_included_files and not self._raw_source_files:
            # 尚未解析，先执行解析
            self._parse()
            return

        dir_patterns = [p.strip() for p in re.split(r'[,;，；]+', self.dir_filter_var.get()) if p.strip()]
        file_patterns = [p.strip() for p in re.split(r'[,;，；]+', self.file_filter_var.get()) if p.strip()]

        self.included_files = [p for p in self._raw_included_files if self._match_filter(p, dir_patterns, file_patterns)]
        self.source_files = [p for p in self._raw_source_files if self._match_filter(p, dir_patterns, file_patterns)]
        self._refresh_list()
        self.status_var.set(
            f"过滤后: included {len(self._raw_included_files)}->{len(self.included_files)}, "
            f"source {len(self._raw_source_files)}->{len(self.source_files)}"
        )

    def _file_list_popup(self, event):
        try:
            self._file_list_menu.tk_popup(event.x_root, event.y_root)
        finally:
            self._file_list_menu.grab_release()

    def _file_list_copy(self):
        sel = self.file_listbox.curselection()
        if sel:
            paths = [self.file_listbox.get(i) for i in sel]
            self.root.clipboard_clear()
            self.root.clipboard_append("\n".join(paths))
            self.global_status_var.set(f"已复制 {len(paths)} 个路径到剪贴板")

    def _file_list_invert(self):
        all_indices = set(range(self.file_listbox.size()))
        selected = set(self.file_listbox.curselection())
        inverted = list(all_indices - selected)
        self.file_listbox.select_clear(0, tk.END)
        for i in inverted:
            self.file_listbox.select_set(i)

    # ------------------------------------------------------------------
    # 列表刷新
    # ------------------------------------------------------------------
    def _refresh_list(self):
        self.file_listbox.delete(0, tk.END)
        for p in self.included_files:
            self.file_listbox.insert(tk.END, p)
        for p in self.source_files:
            self.file_listbox.insert(tk.END, p)

    # ------------------------------------------------------------------
    # 合并
    # ------------------------------------------------------------------
    def _merge(self):
        all_files = list(self.included_files) + list(self.source_files)
        if not all_files:
            messagebox.showwarning("提示", "没有要合并的文件。")
            return

        out_path = self.out_path_var.get().strip()
        if not out_path:
            messagebox.showwarning("提示", "请指定输出文件路径。")
            return

        protect = self.protect_var.get()
        top_name = self.top_file_var.get().strip()
        msg_dir = os.path.dirname(os.path.abspath(self.msg_path_var.get()))
        strip = self.strip_comments.get()

        total = len(all_files)
        self.progress.configure(maximum=total, value=0)
        self.merge_btn.configure(state=tk.DISABLED)
        self.status_var.set("合并中...")

        def target():
            missing = []
            merged_lines = 0
            written_count = 0
            try:
                os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
                with open(out_path, "w", encoding="utf-8") as out:
                    # protect: 文件头
                    if protect:
                        out.write("`pragma protect begin\n\n")

                    for idx, rel_path in enumerate(all_files):
                        abs_path = self._resolve_path(rel_path, msg_dir)
                        if not abs_path or not os.path.isfile(abs_path):
                            missing.append(rel_path)
                            self.root.after(0, lambda v=idx+1: self.progress.configure(value=v))
                            continue

                        try:
                            with open(abs_path, "r", encoding="utf-8") as f:
                                data = f.read()
                        except UnicodeDecodeError:
                            try:
                                with open(abs_path, "r", encoding="gbk") as f:
                                    data = f.read()
                            except Exception as e:
                                missing.append(f"{rel_path} (编码错误: {e})")
                                self.root.after(0, lambda v=idx+1: self.progress.configure(value=v))
                                continue

                        # 1. 注释掉 `include 开头的行
                        lines = data.splitlines(keepends=True)
                        filtered = []
                        for line in lines:
                            stripped = line.lstrip()
                            if stripped.startswith("`include"):
                                filtered.append("// " + line)
                            else:
                                filtered.append(line)
                        data = "".join(filtered)

                        # 2. verible-verilog-preprocessor strip-comments (开关控制)
                        if strip:
                            result = subprocess.run(
                                ["verible-verilog-preprocessor", "strip-comments", "-"],
                                input=data, capture_output=True, text=True,
                            )
                            if result.returncode != 0:
                                missing.append(f"{rel_path} (verible错误: {result.stderr.strip()})")
                                self.root.after(0, lambda v=idx+1: self.progress.configure(value=v))
                                continue
                            data = result.stdout

                        # protect: 对 top 文件插入 protect pragma
                        is_top = protect and top_name and os.path.basename(rel_path) == top_name
                        if is_top:
                            data = self._insert_protect_pragmas(data)

                        # 3. 文件间分隔符
                        if written_count > 0:
                            out.write("\n// ==============================================\n\n")

                        out.write(data)
                        if data and not data.endswith("\n"):
                            out.write("\n")
                        merged_lines += data.count("\n") + (0 if data.endswith("\n") else 1)
                        written_count += 1

                        self.root.after(0, lambda v=idx+1: self.progress.configure(value=v))

                    # protect: 文件尾
                    if protect:
                        out.write("\n`pragma protect end\n")

            except Exception as e:
                err_msg = str(e)
                self.root.after(0, lambda: messagebox.showerror("错误", f"写入输出文件失败:\n{err_msg}"))
                self.root.after(0, lambda: self.merge_btn.configure(state=tk.NORMAL))
                self.root.after(0, lambda: self.status_var.set("合并失败"))
                return

            # 后处理: 将 ^\s+\ 替换为空（去除行首空白+反斜杠的行）
            try:
                with open(out_path, "r", encoding="utf-8") as f:
                    pp_lines = f.readlines()
                pp_lines = [re.sub(r'^\s+\\', '', line) for line in pp_lines]
                with open(out_path, "w", encoding="utf-8") as f:
                    f.writelines(pp_lines)
            except Exception:
                pass

            def _done():
                self.progress.configure(value=total)
                self.merge_btn.configure(state=tk.NORMAL)
                if missing:
                    self.status_var.set(
                        f"合并完成 (缺 {len(missing)} 个): {total} 个文件, {merged_lines} 行 → {os.path.basename(out_path)}"
                    )
                else:
                    self.status_var.set(f"合并完成: {total} 个文件, {merged_lines} 行 → {os.path.basename(out_path)}")

            self.root.after(0, _done)

        threading.Thread(target=target, daemon=True).start()

    def _insert_protect_pragmas(self, data):
        """在 top 文件的 module 行前插入 `pragma protect end，在第一个 ); 后插入 `pragma protect begin。"""
        lines = data.splitlines(keepends=True)

        # 找 module 关键字行
        module_idx = None
        for i, line in enumerate(lines):
            if re.search(r'\bmodule\b', line):
                module_idx = i
                break

        # 找 module 之后第一个 ); 所在行
        paren_idx = None
        if module_idx is not None:
            for i in range(module_idx, len(lines)):
                if ');' in lines[i]:
                    paren_idx = i
                    break

        result = []
        for i, line in enumerate(lines):
            if i == module_idx:
                result.append("`pragma protect end\n")
            result.append(line)
            if i == paren_idx:
                result.append("`pragma protect begin\n")

        return "".join(result)

    def _resolve_path(self, rel_path, base_dir):
        """解析文件路径：支持绝对路径 / 相对路径 / 仅文件名，含 ~ 展开"""
        rel_path = os.path.expanduser(rel_path)
        if os.path.isabs(rel_path):
            return rel_path if os.path.isfile(rel_path) else None

        cand = os.path.normpath(os.path.join(base_dir, rel_path))
        if os.path.isfile(cand):
            return cand

        cand = os.path.normpath(os.path.join(self.script_dir, rel_path))
        if os.path.isfile(cand):
            return cand

        fname = os.path.basename(rel_path)
        for root, dirs, files in os.walk(base_dir):
            if fname in files:
                return os.path.join(root, fname)
            if root.count(os.sep) - base_dir.count(os.sep) > 3:
                dirs.clear()

        return None

    # ------------------------------------------------------------------
    # Obfuscator
    # ------------------------------------------------------------------
    def _dialog_initial_dir(self, current_value):
        value = os.path.expanduser((current_value or "").strip())
        if not value:
            return self.script_dir
        if os.path.isdir(value):
            return value
        parent = os.path.dirname(value)
        if parent and os.path.isdir(parent):
            return parent
        return self.script_dir

    def _browse_obf_src(self):
        path = filedialog.askopenfilename(
            title="选择源文件",
            filetypes=[("SystemVerilog", "*.sv"), ("Verilog", "*.v"), ("All", "*.*")],
            initialdir=self._dialog_initial_dir(self.obf_src_var.get()),
        )
        if path:
            self.obf_src_var.set(path)

    def _browse_obf_out(self):
        path = filedialog.asksaveasfilename(
            title="保存混淆结果",
            defaultextension=".sv",
            filetypes=[("SystemVerilog", "*.sv"), ("Verilog", "*.v"), ("All", "*.*")],
            initialdir=self._dialog_initial_dir(self.obf_out_var.get() or self.obf_src_var.get()),
        )
        if path:
            self.obf_out_var.set(path)

    def _browse_obf_load_map(self):
        path = filedialog.askopenfilename(
            title="选择 load_map 文件",
            filetypes=[("Map", "*.map"), ("All", "*.*")],
            initialdir=self._dialog_initial_dir(self.obf_load_map_var.get() or self.obf_src_var.get()),
        )
        if path:
            self.obf_load_map_var.set(path)

    def _browse_obf_save_map(self):
        path = filedialog.asksaveasfilename(
            title="保存 save_map 文件",
            defaultextension=".map",
            filetypes=[("Map", "*.map"), ("All", "*.*")],
            initialdir=self._dialog_initial_dir(self.obf_save_map_var.get() or self.obf_src_var.get()),
        )
        if path:
            self.obf_save_map_var.set(path)

    def _update_obf_defaults(self):
        """源文件变化时自动更新输出文件和 map 文件默认值。"""
        src = self.obf_src_var.get().strip()
        if not src:
            return
        d = os.path.dirname(src)
        name, ext = os.path.splitext(os.path.basename(src))
        self.obf_out_var.set(os.path.join(d, f"{name}_obf{ext}"))
        self.obf_save_map_var.set(os.path.join(d, "restore.map"))

    def _log_append(self, widget, text):
        ts = datetime.datetime.now().strftime("%H:%M:%S")

        lines = text.split('\n')
        for i, line in enumerate(lines):
            stripped = line.lstrip()
            if stripped:
                if stripped.startswith('>'):
                    stripped = stripped[1:].lstrip()
                lines[i] = f"{ts} > {stripped}"

        text = '\n'.join(lines)
        
        widget.configure(state=tk.NORMAL)
        widget.insert(tk.END, text)
        widget.see(tk.END)
        widget.configure(state=tk.DISABLED)

    def _run_obfuscate(self):
        src_path = os.path.expanduser(self.obf_src_var.get().strip())
        out_path = self.obf_out_var.get().strip()
        save_map = self.obf_save_map_var.get().strip()
        load_map = self.obf_load_map_var.get().strip()
        tool_bin = self.obf_tool_var.get().strip() or "verible-verilog-obfuscate"

        if not src_path or not os.path.isfile(src_path):
            messagebox.showerror("错误", f"源文件不存在:\n{src_path}")
            return
        if not out_path:
            messagebox.showwarning("提示", "请指定输出文件。")
            return

        cmd_args = [tool_bin]
        if save_map:
            cmd_args += ["--save_map", save_map]
        if load_map:
            cmd_args += ["--load_map", load_map]

        self._log_append(self.obf_log, f"> {tool_bin} < {src_path} {' '.join(cmd_args[1:])}\n\n")
        self.obf_run_btn.configure(state=tk.DISABLED)

        def target():
            try:
                os.makedirs(os.path.dirname(os.path.abspath(out_path)) or ".", exist_ok=True)
                with open(src_path, "rb") as fin, open(out_path, "wb") as fout:
                    proc = subprocess.Popen(
                        cmd_args,
                        stdin=fin,
                        stdout=fout,
                        stderr=subprocess.PIPE,
                        cwd=os.path.dirname(src_path) or ".",
                    )
                if proc.stderr is not None:
                    for line in proc.stderr:
                        self.root.after(0, self._log_append, self.obf_log, line.decode(errors="replace"))
                rc = proc.returncode
                if rc != 0:
                    self.root.after(0, self._log_append, self.obf_log,
                        f"\n[错误] {os.path.basename(tool_bin)} 退出码: {rc}\n")
                else:
                    self.root.after(0, self._log_append, self.obf_log,
                        f"\n--- {os.path.basename(tool_bin)} 完成 ---\n")
            except FileNotFoundError:
                self.root.after(0, self._log_append, self.obf_log,
                    f"\n[错误] 找不到 {tool_bin}，请确认工具路径正确且可执行。\n")
            except Exception as e:
                self.root.after(0, self._log_append, self.obf_log, f"\n[错误] {e}\n")
            finally:
                self.root.after(0, lambda: self.obf_run_btn.configure(state=tk.NORMAL))

        threading.Thread(target=target, daemon=True).start()

    # ------------------------------------------------------------------
    # VCS Protect
    # ------------------------------------------------------------------
    def _run_vcs(self):
        src_path = os.path.expanduser(self.vcs_src_var.get().strip())
        key_path = os.path.expanduser(self.vcs_key_var.get().strip())
        opts = self.vcs_opt_var.get().strip()

        if not src_path:
            messagebox.showwarning("提示", "请选择源文件。")
            return
        if not os.path.isfile(src_path):
            messagebox.showerror("错误", f"源文件不存在:\n{src_path}")
            return
        if not key_path:
            messagebox.showwarning("提示", "请选择密钥文件。")
            return
        if not os.path.isfile(key_path):
            messagebox.showerror("错误", f"密钥文件不存在:\n{key_path}")
            return

        cmd = ["vcs", "-ipprotect", key_path] + opts.split() + [src_path]

        self._log_append(self.vcs_log, f"> {' '.join(cmd)}\n\n")
        self.vcs_run_btn.configure(state=tk.DISABLED)

        def target():
            try:
                proc = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    cwd=os.path.dirname(src_path) or ".",
                )
                if proc.stdout is not None:
                    for line in proc.stdout:
                        self.root.after(0, self._log_append, self.vcs_log, line)
                proc.wait()
                self.root.after(0, self._log_append, self.vcs_log,
                    f"\n--- VCS 退出码: {proc.returncode} ---\n")
            except FileNotFoundError:
                self.root.after(0, self._log_append, self.vcs_log,
                    "\n[错误] 找不到 vcs 命令，请确认 VCS 已安装且在 PATH 中。\n")
            except Exception as e:
                self.root.after(0, self._log_append, self.vcs_log, f"\n[错误] {e}\n")
            finally:
                self.root.after(0, lambda: self.vcs_run_btn.configure(state=tk.NORMAL))

        threading.Thread(target=target, daemon=True).start()

    # ------------------------------------------------------------------
    # RLskit
    # ------------------------------------------------------------------
    def _copy_cksum(self):
        cksum = self.rlskit_cksum
        if not cksum:
            messagebox.showwarning("提示", "暂无 cksum 值，请先执行打包。")
            return
        self.root.clipboard_clear()
        self.root.clipboard_append(cksum)
        self.root.update()
        self.global_status_var.set(f"cksum 已复制: {cksum}")
        self.rlskit_copy_btn.configure(text="Copied")
        self.root.after(800, lambda: self.rlskit_copy_btn.configure(text="cksum copy"))

    def _browse_rlskit_src(self):
        path = filedialog.askdirectory(
            title="选择源目录",
            initialdir=self.script_dir,
        )
        if path:
            self.rlskit_src_var.set(path)

    def _browse_ftp(self):
        url = self.rlskit_ftp_url_var.get().strip()
        user = self.rlskit_ftp_user_var.get().strip()
        passwd = self.rlskit_ftp_pass_var.get()

        parsed = urlparse(url if url else "ftp://share.srv/")
        host = parsed.hostname or "share.srv"
        init_path = parsed.path or "/"

        dlg = tk.Toplevel(self.root)
        dlg.title(f"浏览 FTP — {host}")
        dlg.geometry("520x400")
        dlg.transient(self.root)
        dlg.grab_set()

        current_path = [init_path.rstrip("/") or "/"]
        ftp_conn: dict[str, ftplib.FTP | None] = {"conn": None}
        closed = [False]

        nav_frame = ttk.Frame(dlg, padding=(4, 4, 4, 0))
        nav_frame.pack(fill=tk.X)
        up_btn = ttk.Button(nav_frame, text="↑ 上级", command=lambda: _go_up(), state=tk.DISABLED)
        up_btn.pack(side=tk.LEFT)
        path_var = tk.StringVar(value=init_path)
        ttk.Entry(nav_frame, textvariable=path_var, state="readonly").pack(
            side=tk.LEFT, fill=tk.X, expand=True, padx=4)

        list_frame = ttk.Frame(dlg, padding=4)
        list_frame.pack(fill=tk.BOTH, expand=True)
        lb = tk.Listbox(list_frame, font=("Consolas", 9),
                        bg="#ffffff", fg="#333333",
                        selectbackground="#add6ff", selectforeground="#333333",
                        highlightbackground="#e0e0e0")
        sb = ttk.Scrollbar(list_frame, orient=tk.VERTICAL, command=lb.yview)
        lb.configure(yscrollcommand=sb.set)
        lb.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        sb.pack(side=tk.RIGHT, fill=tk.Y)

        status_var = tk.StringVar(value="正在连接...")
        ttk.Label(dlg, textvariable=status_var, font=("", 8)).pack(fill=tk.X, padx=6, pady=(0, 2))

        btn_frame = ttk.Frame(dlg, padding=(4, 0, 4, 6))
        btn_frame.pack(fill=tk.X)
        ok_btn = ttk.Button(btn_frame, text="选择此目录", command=lambda: _select(), state=tk.DISABLED)
        ok_btn.pack(side=tk.RIGHT)
        ttk.Button(btn_frame, text="取消", command=lambda: _close()).pack(side=tk.RIGHT, padx=4)

        def _after(fn):
            if not closed[0]:
                try:
                    dlg.after(0, fn)
                except tk.TclError:
                    pass

        def _close():
            closed[0] = True
            if ftp_conn["conn"]:
                try:
                    ftp_conn["conn"].quit()
                except Exception:
                    pass
            dlg.destroy()

        dlg.protocol("WM_DELETE_WINDOW", _close)

        def _list_dir_thread(path):
            ftp = ftp_conn["conn"]
            if not ftp or closed[0]:
                return
            _after(lambda: status_var.set("加载中..."))
            try:
                ftp.cwd(path)
                pwd = ftp.pwd()
                current_path[0] = pwd
                entries = []
                def _parse_ftp_line(line):
                    parts = line.split(None, 8)
                    if line.startswith("d") and len(parts) >= 9:
                        name = parts[8]
                        if name not in (".", ".."):
                            entries.append(name)
                ftp.retrlines("LIST", _parse_ftp_line)
                entries.sort()
                def _update():
                    lb.delete(0, tk.END)
                    path_var.set(pwd)
                    for name in entries:
                        lb.insert(tk.END, f"[DIR]  {name}")
                    up_btn.configure(state=tk.NORMAL if pwd != "/" else tk.DISABLED)
                    ok_btn.configure(state=tk.NORMAL)
                    status_var.set(f"{pwd}  ({len(entries)} 个子目录)")
                _after(_update)
            except Exception as e:
                _after(lambda: status_var.set(f"错误: {e}"))

        def _go_into(event=None):
            sel = lb.curselection()
            if not sel:
                return
            name = lb.get(sel[0]).replace("[DIR]  ", "", 1)
            new_path = current_path[0].rstrip("/") + "/" + name
            threading.Thread(target=_list_dir_thread, args=(new_path,), daemon=True).start()

        def _go_up():
            path = current_path[0]
            if path == "/":
                return
            parent = "/".join(path.rstrip("/").split("/")[:-1]) or "/"
            threading.Thread(target=_list_dir_thread, args=(parent,), daemon=True).start()

        def _select():
            path = current_path[0].rstrip("/") + "/"
            self.rlskit_ftp_url_var.set(f"ftp://{host}{path}")
            _close()

        lb.bind("<Double-Button-1>", _go_into)

        def _connect():
            try:
                ftp = ftplib.FTP()
                ftp.connect(host, timeout=10)
                ftp.login(user or "anonymous", passwd or "")
                ftp_conn["conn"] = ftp
                _list_dir_thread(init_path)
            except Exception as e:
                _after(lambda: status_var.set(f"连接失败: {e}"))

        threading.Thread(target=_connect, daemon=True).start()

    def _full_suffix(self):
        """根据版本号生成完整后缀，如 V1P0 -> _V1P0_R20260529"""
        ver = self.rlskit_suffix_var.get().strip()
        if not ver:
            return ""
        date_str = datetime.date.today().strftime("%Y%m%d")
        return f"_{ver}_R{date_str}"

    def _update_rlskit_preview(self):
        src = self.rlskit_src_var.get().strip()
        full = self._full_suffix()
        if src and full:
            parent = os.path.dirname(src)
            name = os.path.basename(src)
            self.rlskit_dst_var.set(os.path.join(parent, name + full))
        else:
            self.rlskit_dst_var.set("")

    def _run_rlskit(self):
        src = self.rlskit_src_var.get().strip()
        suffix = self._full_suffix()
        raw_ver = self.rlskit_suffix_var.get().strip()
        ftp_url = self.rlskit_ftp_url_var.get().strip()
        ftp_user = self.rlskit_ftp_user_var.get().strip()
        ftp_pass = self.rlskit_ftp_pass_var.get()

        if not src or not os.path.isdir(src):
            messagebox.showerror("错误", "请选择有效的源目录。")
            return
        if not suffix:
            messagebox.showwarning("提示", "请填写版本号。")
            return

        parent = os.path.dirname(src)
        src_name = os.path.basename(src)
        dst_dir = os.path.join(parent, src_name + suffix)
        tar_file = dst_dir + ".tar.gz"

        self.rlskit_run_btn.configure(state=tk.DISABLED)
        log = self.rlskit_log

        def target():
            try:
                # 1. 复制目录
                self.root.after(0, self._log_append, log, f"> 复制目录: {src}\n   -> {dst_dir}\n")
                if os.path.exists(dst_dir):
                    self.root.after(0, self._log_append, log, f"  [清理] 已存在的目标目录\n")
                    shutil.rmtree(dst_dir)
                shutil.copytree(src, dst_dir)
                self.root.after(0, self._log_append, log, "  复制完成\n\n")

                # 2. 压缩
                self.root.after(0, self._log_append, log, f"> 压缩: {os.path.basename(dst_dir)} -> {os.path.basename(tar_file)}\n")
                proc = subprocess.Popen(
                    ["tar", "-czf", tar_file, "-C", parent, os.path.basename(dst_dir)],
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                )
                if proc.stdout is not None:
                    for line in proc.stdout:
                        self.root.after(0, self._log_append, log, line)
                proc.wait()
                rc = proc.returncode
                if rc != 0:
                    self.root.after(0, self._log_append, log, f"\n[错误] tar 退出码: {rc}\n")
                    return
                file_size = os.path.getsize(tar_file)
                self.root.after(0, self._log_append, log, f"  压缩完成: {file_size:,} bytes\n\n")

                # 3. cksum
                self.root.after(0, self._log_append, log, f"> 计算 cksum: {os.path.basename(tar_file)}\n")
                proc = subprocess.Popen(
                    ["cksum", tar_file],
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                )
                out, _ = proc.communicate()
                self.rlskit_cksum = (out or "").strip()
                if self.rlskit_cksum:
                    self.root.after(0, self.global_status_var.set, f"cksum: {self.rlskit_cksum}")
                    self.root.after(0, lambda: self.rlskit_copy_btn.configure(state=tk.NORMAL))
                self.root.after(0, self._log_append, log, f"  {self.rlskit_cksum}\n\n")

                # 4. FTP 上传
                upload_ok = False
                target_url = ""
                if ftp_url and ftp_user:
                    target_url = ftp_url.rstrip("/") + "/" + os.path.basename(tar_file)
                    self.root.after(0, self._log_append, log, f"> 检查远端文件: {os.path.basename(tar_file)}\n")

                    chk = subprocess.run(
                        ["curl", "-sI", "--fail", target_url, "-u", f"{ftp_user}:{ftp_pass}"],
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    )
                    if chk.returncode == 0:
                        self.root.after(0, self._log_append, log,
                            f"=== 未上传: 远端文件已存在 ===\n   {target_url}\n本地文件: {tar_file}\n\n")
                    else:
                        self.root.after(0, self._log_append, log, "  远端文件不存在，开始上传。\n")
                        self.root.after(0, self._log_append, log, f"> FTP 上传: {os.path.basename(tar_file)}\n   -> {target_url}\n")

                        proc = subprocess.Popen(
                            ["curl", "-sS", "-T", tar_file, "-u", f"{ftp_user}:{ftp_pass}", target_url],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                        )
                        if proc.stderr is not None:
                            for line in proc.stderr:
                                decoded = line.decode(errors="replace").rstrip("\r\n")
                                if decoded:
                                    self.root.after(0, self._log_append, log, f"  {decoded}\n")
                        proc.wait()
                        self.root.after(0, self._log_append, log,
                            f"\n--- curl 退出码: {proc.returncode} ---\n")
                        if proc.returncode == 0:
                            upload_ok = True
                else:
                    self.root.after(0, self._log_append, log,
                        "=== 未上传: 未填写 FTP URL/用户 ===\n\n")

                self.root.after(0, self._log_append, log,
                    f"\n=== 完成 ===\n最终文件: {tar_file}\n")
                self.root.after(0, self._save_config)
                if upload_ok:
                    self.root.after(0, self._save_rlskit_upload_history, src, tar_file, target_url, raw_ver)

            except FileNotFoundError as e:
                self.root.after(0, self._log_append, log,
                    f"\n[错误] 命令未找到: {e}\n")
            except Exception as e:
                self.root.after(0, self._log_append, log,
                    f"\n[错误] {e}\n")
            finally:
                self.root.after(0, lambda: self.rlskit_run_btn.configure(state=tk.NORMAL))

        threading.Thread(target=target, daemon=True).start()

    def _save_rlskit_upload_history(self, src_path, upload_file, ftp_target, version):
        if not src_path:
            return

        cfg = configparser.ConfigParser()
        if os.path.isfile(self.pref_path):
            cfg.read(self.pref_path, encoding="utf-8")
        else:
            self._create_default_config()
            cfg.read(self.pref_path, encoding="utf-8")

        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        # 统一历史表: 每个路径一条最近记录
        if not cfg.has_section("RLskitHistoryTable"):
            cfg.add_section("RLskitHistoryTable")
        pref = self._rlskit_history_row_prefix(src_path)
        cfg.set("RLskitHistoryTable", f"{pref}.path", self._canonical_path(src_path))
        cfg.set("RLskitHistoryTable", f"{pref}.last_upload_file", upload_file)
        cfg.set("RLskitHistoryTable", f"{pref}.last_ftp_target", ftp_target)
        cfg.set("RLskitHistoryTable", f"{pref}.last_ftp_path", ftp_target.rsplit("/", 1)[0] + "/" if "/" in ftp_target else ftp_target)
        cfg.set("RLskitHistoryTable", f"{pref}.last_version", version)
        cfg.set("RLskitHistoryTable", f"{pref}.last_upload_time", now)
        cfg.set("RLskitHistoryTable", f"{pref}.ftp_url", self.rlskit_ftp_url_var.get().strip())
        cfg.set("RLskitHistoryTable", f"{pref}.ftp_username", self.rlskit_ftp_user_var.get().strip())
        cfg.set("RLskitHistoryTable", f"{pref}.ftp_password", self.rlskit_ftp_pass_var.get())

        if not cfg.has_section("History"):
            cfg.add_section("History")
        cfg.set("History", "last_version", self.rlskit_suffix_var.get().strip())
        cfg.set("History", "last_timestamp", now)

        with open(self.pref_path, "w", encoding="utf-8") as f:
            cfg.write(f)

    # ------------------------------------------------------------------
    # PostSim 分析
    # ------------------------------------------------------------------
    def _build_postsim_tab(self, parent):
        """构建后仿分析选项卡"""
        # -- 目录选择 --
        dir_frame = ttk.LabelFrame(parent, text="搜索目录", padding=6)
        dir_frame.pack(fill=tk.X, pady=(0, 4))
        ttk.Entry(dir_frame, textvariable=self.postsim_dir_var).pack(
            side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))
        ttk.Button(dir_frame, text="浏览...", width=7,
                   command=self._postsim_browse_dir).pack(side=tk.LEFT)

        # -- 搜索规则 --
        pat_frame = ttk.LabelFrame(parent, text="搜索规则", padding=6)
        pat_frame.pack(fill=tk.X, pady=(0, 4))
        ttk.Entry(pat_frame, textvariable=self.postsim_pattern_var).pack(
            side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))
        ttk.Label(pat_frame, text="(*.log, test?.txt 等)").pack(side=tk.LEFT)

        # -- 文件预览 --
        preview_frame = ttk.LabelFrame(parent, text="匹配文件 (双击行分析)", padding=4)
        preview_frame.pack(fill=tk.BOTH, expand=True)

        self._postsim_canvas = tk.Canvas(preview_frame, highlightthickness=0, bg="#ffffff")
        v_scroll = ttk.Scrollbar(preview_frame, orient=tk.VERTICAL,
                                 command=self._postsim_canvas.yview)
        self._postsim_scrollable = ttk.Frame(self._postsim_canvas)

        self._postsim_canvas.bind("<MouseWheel>",
            lambda e: self._postsim_canvas.yview_scroll(-int(e.delta / 120), "units"))
        self._postsim_canvas.bind("<Button-4>",
            lambda e: self._postsim_canvas.yview_scroll(-1, "units"))
        self._postsim_canvas.bind("<Button-5>",
            lambda e: self._postsim_canvas.yview_scroll(1, "units"))

        self._postsim_scrollable.bind("<Configure>",
            lambda e: self._postsim_canvas.configure(
                scrollregion=self._postsim_canvas.bbox("all")))
        self._postsim_canvas.create_window((0, 0), window=self._postsim_scrollable, anchor="nw")
        self._postsim_canvas.configure(yscrollcommand=v_scroll.set)

        self._postsim_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        v_scroll.pack(side=tk.RIGHT, fill=tk.Y)

        # -- 统计信息 --
        self._postsim_stats_var = tk.StringVar(value="匹配文件数：0")
        ttk.Label(parent, textvariable=self._postsim_stats_var,
                  style="Status.TLabel").pack(anchor=tk.W, pady=(4, 0))

    def _postsim_browse_dir(self):
        path = filedialog.askdirectory(title="选择搜索目录")
        if path:
            self.postsim_dir_var.set(path)

    def _postsim_debounce(self, *args):
        if self._postsim_search_id:
            self.root.after_cancel(self._postsim_search_id)
        self._postsim_search_id = self.root.after(300, self._postsim_search)

    def _postsim_search(self):
        """递归搜索文件并实时预览"""
        for f in self.postsim_file_frames:
            f.destroy()
        self.postsim_file_frames.clear()

        dir_path = self.postsim_dir_var.get().strip()
        pattern = self.postsim_pattern_var.get().strip()
        if not dir_path or not os.path.isdir(dir_path):
            self._postsim_stats_var.set("匹配文件数：0 (请选择有效目录)")
            self.global_status_var.set("后仿: 目录无效")
            return

        try:
            search_path = os.path.join(dir_path, "**", pattern)
            matched = sorted(f for f in glob.iglob(search_path, recursive=True) if os.path.isfile(f))
            for fp in matched:
                rel = os.path.relpath(fp, dir_path)
                row = ttk.Frame(self._postsim_scrollable)
                row.pack(fill=tk.X, padx=3, pady=1)
                lbl = ttk.Label(row, text=rel, anchor="w")
                lbl.pack(side=tk.LEFT, fill=tk.X, expand=True)
                lbl.bind("<Double-Button-1>", lambda e, p=fp: self._postsim_analyze(p))
                ttk.Button(row, text="analyze", width=8,
                           command=lambda p=fp: self._postsim_analyze(p)).pack(side=tk.RIGHT, padx=4)
                self.postsim_file_frames.append(row)

            self._postsim_stats_var.set(f"匹配文件数：{len(matched)}")
            self.global_status_var.set(f"后仿: 找到 {len(matched)} 个文件")
        except Exception as e:
            self._postsim_stats_var.set(f"搜索出错: {e}")

    def _postsim_analyze(self, file_path):
        """分析单个文件中的 Timing violation"""
        results = []
        try:
            if not os.path.isfile(file_path) or os.path.getsize(file_path) == 0:
                messagebox.showwarning("提示", f"文件为空或不存在:\n{file_path}")
                return

            for enc in ("utf-8", "gbk", "latin-1"):
                try:
                    with open(file_path, "r", encoding=enc) as f:
                        lines = f.readlines()
                    break
                except (UnicodeDecodeError, UnicodeError):
                    continue
            else:
                messagebox.showerror("错误", f"无法识别文件编码:\n{file_path}")
                return

            i = 0
            while i < len(lines):
                line = lines[i].strip()
                if "Timing violation" in line:
                    path_m = re.search(r'["\']([^"\']+)["\']', line)
                    path_val = path_m.group(1) if path_m else "未提取到"
                    line_m = re.search(r'(\d+):', line)
                    line_num = line_m.group(1) if line_m else ""
                    inst_m = re.search(r'Timing violation in\s+(\w+(\.\w+)+)\b', line, re.IGNORECASE)
                    inst = inst_m.group(1) if inst_m else "未提取到"
                    info = lines[i + 1].strip() if i + 1 < len(lines) else "无后续内容"
                    results.append({
                        "instance": inst, "info": info,
                        "path": path_val, "line_number": line_num
                    })
                    i += 1
                i += 1
        except Exception as e:
            messagebox.showerror("分析失败", str(e))
            return

        self._postsim_show_results(file_path, results)

    def _postsim_show_results(self, file_path, results):
        """展示分析结果弹窗"""
        win = tk.Toplevel(self.root)
        win.title("Timing Violation 分析")
        win.geometry("1050x550")
        win.transient(self.root)
        win.grab_set()

        # 文件路径
        ttk.Label(win, text=f"文件：{file_path}", wraplength=980).pack(
            anchor="w", padx=15, pady=(10, 4))

        # 标题行
        hdr = ttk.Frame(win)
        hdr.pack(fill=tk.X, padx=15, pady=4)
        ttk.Label(hdr, text=f"匹配数：{len(results)}",
                  font=("Segoe UI", 10, "bold")).pack(side=tk.LEFT)
        show_more = tk.BooleanVar(value=False)
        ttk.Checkbutton(hdr, text="show more", variable=show_more).pack(side=tk.RIGHT)

        # 表格
        columns = ["row_num", "instance", "info"]
        tree = ttk.Treeview(win, columns=columns, show="headings",
                            selectmode="extended", height=18)
        tree.heading("row_num", text="No.")
        tree.heading("instance", text="Instance")
        tree.heading("info", text="Info")
        tree.column("row_num", width=50, anchor="center")
        tree.column("instance", width=230, anchor="w")
        tree.column("info", width=580, anchor="w")

        # waived 按钮需等 tree 创建后才能引用
        ttk.Button(hdr, text="waived", width=8,
                   command=self._postsim_make_waive_func(tree, results, win, show_more)
                  ).pack(side=tk.LEFT, padx=(8, 0))

        tree_scroll = ttk.Scrollbar(win, orient=tk.VERTICAL, command=tree.yview)
        tree.configure(yscrollcommand=tree_scroll.set)
        tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(15, 0), pady=4)
        tree_scroll.pack(side=tk.RIGHT, fill=tk.Y, padx=(0, 15), pady=4)

        # 悬停提示
        tip_win = [None]
        tip_id = [None]

        def _kill_tip(_=None):
            if tip_id[0]:
                try: win.after_cancel(tip_id[0])
                except: pass
                tip_id[0] = None
            if tip_win[0] and tip_win[0].winfo_exists():
                try: tip_win[0].destroy()
                except: pass
                tip_win[0] = None

        def _show_tip(event):
            item = tree.identify_row(event.y)
            col = tree.identify_column(event.x)
            if not item or not col:
                _kill_tip(); return
            col_idx = int(col.replace("#", "")) - 1
            vals = tree.item(item, "values")
            if not vals or col_idx >= len(vals):
                _kill_tip(); return
            txt = vals[col_idx]
            if not txt or txt in ("未提取到", "无后续内容", ""):
                _kill_tip(); return
            _kill_tip()
            tw = tk.Toplevel(win)
            tw.wm_overrideredirect(True)
            tw.attributes("-topmost", True)
            ttk.Label(tw, text=txt, wraplength=400, padding=5,
                      background="#FFFFE0").pack()
            tw.geometry(f"+{win.winfo_pointerx() + 10}+{win.winfo_pointery() + 10}")
            tip_win[0] = tw

        def _schedule_tip(event):
            _kill_tip()
            tip_id[0] = win.after(200, lambda: _show_tip(event))

        tree.bind("<Motion>", _schedule_tip)
        tree.bind("<Leave>", lambda e: _kill_tip())
        tree.bind("<Button-1>", lambda e: _kill_tip())
        tree.bind("<MouseWheel>", lambda e: _kill_tip())

        # 双击复制
        def _copy_cell(event):
            _kill_tip()
            item = tree.identify_row(event.y)
            col = tree.identify_column(event.x)
            if not item or not col: return
            col_idx = int(col.replace("#", "")) - 1
            vals = tree.item(item, "values")
            if vals and col_idx < len(vals) and vals[col_idx]:
                win.clipboard_clear()
                win.clipboard_append(str(vals[col_idx]))

        tree.bind("<Double-1>", _copy_cell)

        def _toggle_columns():
            _kill_tip()
            if show_more.get():
                tree["columns"] = ["row_num", "instance", "info", "path", "line_number"]
                tree.heading("path", text="Path")
                tree.heading("line_number", text="Line")
                tree.column("path", width=230, anchor="w")
                tree.column("line_number", width=90, anchor="center")
            else:
                tree["columns"] = ["row_num", "instance", "info"]
                tree.column("instance", width=230, anchor="w")
                tree.column("info", width=580, anchor="w")
            _refresh()

        show_more.trace_add("write", lambda *_: _toggle_columns())

        def _refresh():
            for item in tree.get_children():
                tree.delete(item)
            if not results:
                if show_more.get():
                    tree.insert("", tk.END, values=["-", "未找到 Timing violation", "", "", ""])
                else:
                    tree.insert("", tk.END, values=["-", "未找到 Timing violation", ""])
            else:
                for idx, r in enumerate(results):
                    if show_more.get():
                        tree.insert("", tk.END, values=[
                            idx + 1, r["instance"], r["info"], r["path"], r["line_number"]
                        ])
                    else:
                        tree.insert("", tk.END, values=[
                            idx + 1, r["instance"], r["info"]
                        ])

        _refresh()

    def _postsim_make_waive_func(self, tree, results, win, show_more):
        def _waive():
            sel = tree.selection()
            if not sel:
                messagebox.showinfo("提示", "请先选择需要移除的行")
                return
            instances = set()
            for item in sel:
                vals = tree.item(item, "values")
                if vals and len(vals) > 1:
                    instance = vals[1]
                    if instance and instance not in ("-", "未找到 Timing violation"):
                        instances.add(instance)
            if not instances:
                return
            results[:] = [r for r in results if r["instance"] not in instances]
            try:
                with open("notimingcheck.lst", "a", encoding="utf-8") as f:
                    for ins in instances:
                        f.write(f"instance {{{ins}}} {{noTiming}}\n")
                is_more = show_more.get()
                for item in tree.get_children():
                    tree.delete(item)
                if not results:
                    if is_more:
                        tree.insert("", tk.END, values=["-", "未找到 Timing violation", "", "", ""])
                    else:
                        tree.insert("", tk.END, values=["-", "未找到 Timing violation", ""])
                else:
                    for idx, r in enumerate(results):
                        if is_more:
                            tree.insert("", tk.END, values=[
                                idx + 1, r["instance"], r["info"], r["path"], r["line_number"]
                            ])
                        else:
                            tree.insert("", tk.END, values=[
                                idx + 1, r["instance"], r["info"]
                            ])
                # 更新标题匹配数
                for w in win.winfo_children():
                    if isinstance(w, ttk.Frame):
                        for c in w.winfo_children():
                            if isinstance(c, ttk.Label) and "匹配数" in (c.cget("text") or ""):
                                c.configure(text=f"匹配数：{len(results)}")
                                break
                messagebox.showinfo("成功",
                    f"已移除 {len(instances)} 个 instance，结果已写入 notimingcheck.lst")
            except Exception as e:
                messagebox.showerror("错误", f"写入文件失败:\n{e}")
        return _waive

def main():
    root = tk.Tk()
    app = FizzApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
