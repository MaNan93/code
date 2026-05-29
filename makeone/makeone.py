#!/usr/bin/env python3
"""makeone -- 从 generalMessage.txt 中提取文件路径，按顺序合并为一个文件。"""

import configparser
import datetime
import fnmatch
import os
import re
import shutil
import subprocess
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk


class MakeOneApp:
    def __init__(self, root):
        self.root = root
        self.root.title("makeone - 文件合并工具")
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
        self.strip_comments = tk.BooleanVar(value=False)  # 第2步开关
        self.protect_var = tk.BooleanVar(value=False)     # protect 开关
        self.top_file_var = tk.StringVar(value="pcie_ctrl_wrapper.sv")  # protect 的 top 文件名
        self.script_dir = os.getcwd()

        self._setup_clipboard()
        self._build_ui()
        self.config_path = os.path.join(self.script_dir, "config.ini")
        self._load_config()
        self._set_defaults()

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

        # 退出按钮 (全局)
        ttk.Button(self.root, text="退出", command=self.root.destroy).pack(pady=(2, 8))

    def _build_merge_tab(self, parent):
        # -- 消息文件选择 --
        top_frame = ttk.LabelFrame(parent, text="消息文件 (generalMessage.txt)", padding=6)
        top_frame.pack(fill=tk.X, pady=(0, 2))

        self.msg_path_var = tk.StringVar()
        ttk.Entry(top_frame, textvariable=self.msg_path_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 4))
        ttk.Button(top_frame, text="浏览...", width=7, command=self._browse_msg).pack(side=tk.LEFT, padx=2)
        ttk.Button(top_frame, text="解析", command=self._parse).pack(side=tk.LEFT, padx=2)

        # -- 过滤规则 --
        filter_frame = ttk.LabelFrame(parent, text="过滤规则 (通配, 逗号/分号分隔)", padding=4)
        filter_frame.pack(fill=tk.X, pady=(0, 2))

        f_row = ttk.Frame(filter_frame)
        f_row.pack(fill=tk.X)
        ttk.Label(f_row, text="排除目录:").pack(side=tk.LEFT)
        ttk.Entry(f_row, textvariable=self.dir_filter_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=4)
        ttk.Label(f_row, text="排除文件:").pack(side=tk.LEFT)
        ttk.Entry(f_row, textvariable=self.file_filter_var).pack(side=tk.LEFT, fill=tk.X, expand=True)
        ttk.Button(f_row, text="重新过滤", command=self._parse).pack(side=tk.LEFT, padx=(4, 0))

        # -- 文件列表 --
        list_frame = ttk.LabelFrame(parent, text="文件列表", padding=4)
        list_frame.pack(fill=tk.BOTH, expand=True, pady=4)

        self.file_listbox = tk.Listbox(list_frame, selectmode=tk.EXTENDED, exportselection=False)
        scroll = ttk.Scrollbar(list_frame, orient=tk.VERTICAL, command=self.file_listbox.yview)
        self.file_listbox.configure(yscrollcommand=scroll.set)
        self.file_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)

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
        self.merge_btn = ttk.Button(btn_row, text="合并", command=self._merge)
        self.merge_btn.pack(side=tk.RIGHT, padx=2)

        self.progress = ttk.Progressbar(bottom_frame, mode="determinate")
        self.progress.pack(fill=tk.X, pady=(6, 0))
        self.status_var = tk.StringVar(value="就绪")
        ttk.Label(bottom_frame, textvariable=self.status_var, font=("", 8)).pack(anchor=tk.W)

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
        self.vcs_run_btn = ttk.Button(run_frame, text="执行 VCS Protect", command=self._run_vcs)
        self.vcs_run_btn.pack(side=tk.RIGHT)

        # -- 输出日志 --
        log_frame = ttk.LabelFrame(parent, text="输出日志", padding=4)
        log_frame.pack(fill=tk.BOTH, expand=True)

        self.vcs_log = tk.Text(log_frame, wrap=tk.NONE, state=tk.DISABLED, font=("Consolas", 9))
        v_scroll = ttk.Scrollbar(log_frame, orient=tk.VERTICAL, command=self.vcs_log.yview)
        h_scroll = ttk.Scrollbar(log_frame, orient=tk.HORIZONTAL, command=self.vcs_log.xview)
        self.vcs_log.configure(yscrollcommand=v_scroll.set, xscrollcommand=h_scroll.set)
        self.vcs_log.grid(row=0, column=0, sticky="nsew")
        v_scroll.grid(row=0, column=1, sticky="ns")
        h_scroll.grid(row=1, column=0, sticky="ew")
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

        # -- 执行 --
        run_frame = ttk.Frame(parent)
        run_frame.pack(fill=tk.X, pady=(0, 4))
        self.obf_run_btn = ttk.Button(run_frame, text="执行 Obfuscate", command=self._run_obfuscate)
        self.obf_run_btn.pack(side=tk.RIGHT)

        # -- 输出日志 --
        log_frame = ttk.LabelFrame(parent, text="输出日志", padding=4)
        log_frame.pack(fill=tk.BOTH, expand=True)

        self.obf_log = tk.Text(log_frame, wrap=tk.NONE, state=tk.DISABLED, font=("Consolas", 9))
        v_scroll = ttk.Scrollbar(log_frame, orient=tk.VERTICAL, command=self.obf_log.yview)
        h_scroll = ttk.Scrollbar(log_frame, orient=tk.HORIZONTAL, command=self.obf_log.xview)
        self.obf_log.configure(yscrollcommand=v_scroll.set, xscrollcommand=h_scroll.set)
        self.obf_log.grid(row=0, column=0, sticky="nsew")
        v_scroll.grid(row=0, column=1, sticky="ns")
        h_scroll.grid(row=1, column=0, sticky="ew")
        log_frame.rowconfigure(0, weight=1)
        log_frame.columnconfigure(0, weight=1)

    def _build_rlskit_tab(self, parent):
        # -- 源目录 --
        src_frame = ttk.LabelFrame(parent, text="源目录", padding=6)
        src_frame.pack(fill=tk.X, pady=(0, 4))

        self.rlskit_src_var = tk.StringVar()
        self.rlskit_src_var.trace_add("write", lambda *_: (self._update_rlskit_preview(), self._load_release_note()))
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
        self.rlskit_copy_btn = ttk.Button(run_frame, text="cksum copy", width=11, command=self._copy_cksum)
        self.rlskit_copy_btn.pack(side=tk.LEFT)
        self.rlskit_run_btn = ttk.Button(run_frame, text="执行打包上传", command=self._run_rlskit)
        self.rlskit_run_btn.pack(side=tk.RIGHT)

        # -- 子选项卡：输出日志 / Release Note --
        sub_nb = ttk.Notebook(parent)
        sub_nb.pack(fill=tk.BOTH, expand=True)

        # 输出日志
        log_tab = ttk.Frame(sub_nb, padding=4)
        sub_nb.add(log_tab, text="输出日志")
        self.rlskit_log = tk.Text(log_tab, wrap=tk.WORD, state=tk.DISABLED, font=("Consolas", 9))
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
        self.rn_text = tk.Text(rn_text_frame, wrap=tk.WORD, font=("Consolas", 10), undo=True)
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
    # config.ini
    # ------------------------------------------------------------------
    def _load_config(self):
        if not os.path.isfile(self.config_path):
            self._create_default_config()
            return
        cfg = configparser.ConfigParser()
        cfg.read(self.config_path, encoding="utf-8")

        # FTP
        if cfg.has_section("FTP"):
            server = cfg.get("FTP", "server", fallback="")
            remote_path = cfg.get("FTP", "remote_path", fallback="")
            username = cfg.get("FTP", "username", fallback="")
            password = cfg.get("FTP", "password", fallback="")
            if server:
                url = server.rstrip("/") + "/" + remote_path.strip("/") + "/"
                self.rlskit_ftp_url_var.set(url)
            self.rlskit_ftp_user_var.set(username)
            self.rlskit_ftp_pass_var.set(password)

        # History
        if cfg.has_section("History"):
            self.rlskit_src_var.set(cfg.get("History", "last_folder", fallback=""))
            last_ver = cfg.get("History", "last_version", fallback="")
            if last_ver:
                self.rlskit_suffix_var.set(last_ver)

    def _create_default_config(self):
        cfg = configparser.ConfigParser()
        cfg.add_section("FTP")
        cfg.set("FTP", "server", "http://ftp.example.com")
        cfg.set("FTP", "remote_path", "/upload")
        cfg.set("FTP", "username", "")
        cfg.set("FTP", "password", "")
        cfg.add_section("History")
        cfg.set("History", "last_folder", "")
        cfg.set("History", "last_version", "V1P0")
        cfg.set("History", "last_timestamp", "")
        with open(self.config_path, "w", encoding="utf-8") as f:
            cfg.write(f)

    def _save_config(self):
        cfg = configparser.ConfigParser()

        # FTP
        cfg.add_section("FTP")
        parts = self.rlskit_ftp_url_var.get().strip().rstrip("/").split("/")
        # server = protocol://host, remote_path = remaining parts after host
        if len(parts) >= 3:
            cfg.set("FTP", "server", "/".join(parts[:3]))
            cfg.set("FTP", "remote_path", "/".join(parts[3:]) + "/" if len(parts) > 3 else "")
        else:
            cfg.set("FTP", "server", self.rlskit_ftp_url_var.get().strip())
            cfg.set("FTP", "remote_path", "")
        cfg.set("FTP", "username", self.rlskit_ftp_user_var.get().strip())
        cfg.set("FTP", "password", self.rlskit_ftp_pass_var.get())

        # History
        cfg.add_section("History")
        cfg.set("History", "last_folder", self.rlskit_src_var.get().strip())
        cfg.set("History", "last_version", self.rlskit_suffix_var.get().strip())
        cfg.set("History", "last_timestamp", datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

        with open(self.config_path, "w", encoding="utf-8") as f:
            cfg.write(f)

    # ------------------------------------------------------------------
    # 默认值
    # ------------------------------------------------------------------
    def _set_defaults(self):
        default_msg = os.path.join(self.script_dir, "generalMessage.txt")
        self.msg_path_var.set(default_msg)
        self.out_path_var.set(os.path.join(self.script_dir, "one.sv"))

        # VCS Protect: 源文件默认 = 合并输出
        self.vcs_src_var.set(os.path.join(self.script_dir, "one.sv"))

        # VCS Protect: 密钥文件默认 = $PCIEGEN/sim2-key.txt
        pciegen = os.environ.get("PCIEGEN", "")
        if pciegen:
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

        self.included_files = list(dict.fromkeys(inc))
        self.source_files = list(dict.fromkeys(src))

        # 应用过滤规则
        dir_patterns = [p.strip() for p in re.split(r'[,;，；]+', self.dir_filter_var.get()) if p.strip()]
        file_patterns = [p.strip() for p in re.split(r'[,;，；]+', self.file_filter_var.get()) if p.strip()]

        if dir_patterns or file_patterns:
            ini_before = len(self.included_files)
            src_before = len(self.source_files)
            self.included_files = [p for p in self.included_files if self._match_filter(p, dir_patterns, file_patterns)]
            self.source_files = [p for p in self.source_files if self._match_filter(p, dir_patterns, file_patterns)]
            self._refresh_list()
            self.status_var.set(
                f"解析完成: included {ini_before}->{len(self.included_files)}, "
                f"source {src_before}->{len(self.source_files)}"
            )
        else:
            self._refresh_list()
            self.status_var.set(
                f"解析完成: included={len(inc)}(去重={len(self.included_files)}), "
                f"source={len(src)}(去重={len(self.source_files)})"
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

        total = len(all_files)
        self.progress.configure(maximum=total)
        self.merge_btn.configure(state=tk.DISABLED)
        self.status_var.set("合并中...")
        self.root.update_idletasks()

        missing = []
        merged_lines = 0
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
                        self.progress["value"] = idx + 1
                        self.root.update_idletasks()
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
                            self.progress["value"] = idx + 1
                            self.root.update_idletasks()
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
                    if self.strip_comments.get():
                        result = subprocess.run(
                            ["verible-verilog-preprocessor", "strip-comments", "-"],
                            input=data, capture_output=True, text=True,
                        )
                        if result.returncode != 0:
                            missing.append(f"{rel_path} (verible错误: {result.stderr.strip()})")
                            self.progress["value"] = idx + 1
                            self.root.update_idletasks()
                            continue
                        data = result.stdout

                    # protect: 对 top 文件插入 protect pragma
                    is_top = protect and top_name and os.path.basename(rel_path) == top_name
                    if is_top:
                        data = self._insert_protect_pragmas(data)

                    # 3. 文件间分隔符
                    if idx > 0:
                        out.write("\n// ==============================================\n\n")

                    out.write(data)
                    if data and not data.endswith("\n"):
                        out.write("\n")
                    merged_lines += data.count("\n") + (0 if data.endswith("\n") else 1)

                    self.progress["value"] = idx + 1
                    self.root.update_idletasks()

                # protect: 文件尾
                if protect:
                    out.write("\n`pragma protect end\n")

        except Exception as e:
            messagebox.showerror("错误", f"写入输出文件失败:\n{e}")
            self.merge_btn.configure(state=tk.NORMAL)
            self.status_var.set("合并失败")
            return

        self.progress["value"] = total
        self.merge_btn.configure(state=tk.NORMAL)

        if missing:
            self.status_var.set(
                f"合并完成 (缺 {len(missing)} 个): {total} 个文件, {merged_lines} 行 → {os.path.basename(out_path)}"
            )
        else:
            self.status_var.set(f"合并完成: {total} 个文件, {merged_lines} 行 → {os.path.basename(out_path)}")

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
    def _browse_obf_src(self):
        path = filedialog.askopenfilename(
            title="选择源文件",
            filetypes=[("SystemVerilog", "*.sv"), ("Verilog", "*.v"), ("All", "*.*")],
            initialdir=self.script_dir,
        )
        if path:
            self.obf_src_var.set(path)

    def _browse_obf_out(self):
        path = filedialog.asksaveasfilename(
            title="保存混淆结果",
            defaultextension=".sv",
            filetypes=[("SystemVerilog", "*.sv"), ("Verilog", "*.v"), ("All", "*.*")],
        )
        if path:
            self.obf_out_var.set(path)

    def _browse_obf_load_map(self):
        path = filedialog.askopenfilename(
            title="选择 load_map 文件",
            filetypes=[("Map", "*.map"), ("All", "*.*")],
            initialdir=self.script_dir,
        )
        if path:
            self.obf_load_map_var.set(path)

    def _browse_obf_save_map(self):
        path = filedialog.asksaveasfilename(
            title="保存 save_map 文件",
            defaultextension=".map",
            filetypes=[("Map", "*.map"), ("All", "*.*")],
            initialdir=self.script_dir,
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
        widget.configure(state=tk.NORMAL)
        widget.insert(tk.END, text)
        widget.see(tk.END)
        widget.configure(state=tk.DISABLED)

    def _run_obfuscate(self):
        src_path = os.path.expanduser(self.obf_src_var.get().strip())
        out_path = self.obf_out_var.get().strip()
        save_map = self.obf_save_map_var.get().strip()
        load_map = self.obf_load_map_var.get().strip()

        if not src_path or not os.path.isfile(src_path):
            messagebox.showerror("错误", f"源文件不存在:\n{src_path}")
            return
        if not out_path:
            messagebox.showwarning("提示", "请指定输出文件。")
            return

        cmd_args = ["verible-verilog-obfuscate"]
        if save_map:
            cmd_args += ["--save_map", save_map]
        if load_map:
            cmd_args += ["--load_map", load_map]
        cmd_args.append(out_path)

        self._log_append(self.obf_log, f"> verible-verilog-obfuscate < {src_path} {' '.join(cmd_args[1:])}\n\n")
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
                for line in proc.stderr:
                    self.root.after(0, self._log_append, self.obf_log, line.decode(errors="replace"))
                proc.wait()
                self.root.after(0, self._log_append, self.obf_log,
                    f"\n--- verible-verilog-obfuscate 退出码: {proc.returncode} ---\n")
            except FileNotFoundError:
                self.root.after(0, self._log_append, self.obf_log,
                    "\n[错误] 找不到 verible-verilog-obfuscate，请确认 Verible 已安装且在 PATH 中。\n")
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
                    cwd=os.path.dirname(src_path),
                )
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
        cksum = getattr(self, "rlskit_cksum", "")
        if not cksum:
            messagebox.showwarning("提示", "暂无 cksum 值，请先执行打包。")
            return
        self.root.clipboard_clear()
        self.root.clipboard_append(cksum)
        self.root.update()
        self.rlskit_copy_btn.configure(text="Copied")
        self.root.after(800, lambda: self.rlskit_copy_btn.configure(text="cksum copy"))

    def _browse_rlskit_src(self):
        path = filedialog.askdirectory(
            title="选择源目录",
            initialdir=self.script_dir,
        )
        if path:
            self.rlskit_src_var.set(path)

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
                self.rlskit_cksum = out.strip()
                self.root.after(0, self._log_append, log, f"  {self.rlskit_cksum}\n\n")

                # 4. FTP 上传
                if ftp_url and ftp_user:
                    target_url = ftp_url.rstrip("/") + "/" + os.path.basename(tar_file)
                    self.root.after(0, self._log_append, log, f"> 检查远端文件: {os.path.basename(tar_file)}\n")

                    # 检查远端是否已存在
                    chk = subprocess.run(
                        ["curl", "-sI", target_url, "-u", f"{ftp_user}:{ftp_pass}"],
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    )
                    if chk.returncode == 0:
                        self.root.after(0, self._log_append, log,
                            f"=== 未上传: 远端文件已存在 ===\n   {target_url}\n本地文件: {tar_file}\n\n")
                        self.root.after(0, lambda: self.rlskit_run_btn.configure(state=tk.NORMAL))
                        return

                    self.root.after(0, self._log_append, log, "  远端文件不存在，开始上传。\n")
                    self.root.after(0, self._log_append, log, f"> FTP 上传: {os.path.basename(tar_file)}\n   -> {target_url}\n")

                    proc = subprocess.Popen(
                        ["curl", "-sS", "-T", tar_file, "-u", f"{ftp_user}:{ftp_pass}", target_url],
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    )
                    # 读取 stderr (curl 进度/错误信息)
                    for line in proc.stderr:
                        decoded = line.decode(errors="replace").rstrip("\r\n")
                        if decoded:
                            self.root.after(0, self._log_append, log, f"  {decoded}\n")
                    proc.wait()
                    self.root.after(0, self._log_append, log,
                        f"\n--- curl 退出码: {proc.returncode} ---\n")
                else:
                    self.root.after(0, self._log_append, log,
                        "=== 未上传: 未填写 FTP URL/用户 ===\n\n")
                    return

                self.root.after(0, self._log_append, log,
                    f"\n=== 完成 ===\n最终文件: {tar_file}\n")
                self.root.after(0, self._save_config)

            except FileNotFoundError as e:
                self.root.after(0, self._log_append, log,
                    f"\n[错误] 命令未找到: {e}\n")
            except Exception as e:
                self.root.after(0, self._log_append, log,
                    f"\n[错误] {e}\n")
            finally:
                self.root.after(0, lambda: self.rlskit_run_btn.configure(state=tk.NORMAL))

        threading.Thread(target=target, daemon=True).start()

def main():
    root = tk.Tk()
    app = MakeOneApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
