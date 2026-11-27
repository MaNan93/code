# 创建目录结构
New-Item -ItemType Directory -Force -Path ".vim/plugin", ".vim/ftdetect", ".vim/syntax" | Out-Null

# 1. 生成 .vimrc 入口文件
@'
source ~/.vim/vimrc.vim
'@ | Set-Content -Encoding UTF8 ".vimrc"

# 2. 生成 .vim/vimrc.vim 主配置
@'
" ============================================================
"  vimrc.vim  —  gvim / vim 配置（Rocky Linux 8.10 离线/性能优化版）
" 位置: 放在任意位置，在 ~/.vimrc 里 source 它（或直接改名为 ~/.vimrc）
"
" 配套插件与工具:
"   - ~/.vim/plugin/verible_format.vim                      (F5    格式化 SV/Verilog)
"   - ~/.vim/plugin/comment.vim                             (F3/F4 行注释/取消注释)
"   - ~/.vim/plugin/port2signal.vim                         (F6    端口声明转 logic/wire)
"   - ~/.vim/plugin/copy_path.vim                           (F9    复制当前文件绝对路径)
"   - ~/.vim/plugin/log_filter.vim                          (:filter 大日志/网表快速过滤)
"   - ~/.vim/pack/plugins/start/verilog_systemverilog.vim   (SV 语法/缩进/跳转)
"   - ~/.vim/pack/plugins/start/vim-fugitive                (Git   版本对比与 blame)
"   - ~/.vim/syntax/liberty.vim                             (Liberty .lib 轻量语法高亮)
"   - ~/.vim/syntax/sdc.vim & ~/.vim/syntax/upf.vim         (SDC/DC 与 UPF 轻量语法高亮)
"
" 常用快捷键速查（<leader> = 空格 Space）:
"   [文件/界面] Space+w 保存 | Space+q 关闭窗口 | Space+Q 强制全退 | Space+h 消高亮
"               Space+n 行号 | Space+l 不可见字符 | Space+z 自动换行 | F2 目录树
"               F12 终端粘贴模式 | Ctrl+滚轮 缩放字体(GUI)
"   [RTL工具]   F3 行注释 | F4 取消注释 | F5 Verible格式化 | F6 端口转logic/wire
"               F9 复制绝对路径 | gd 跳子模块定义 | gp 跳端口声明
"               % 匹配 begin/end & module/endmodule
"   [全局搜索]  Space+g 搜光标词 | Space+G 输入关键词搜索
"               Space+cn/cp 下一/上一条结果 | Space+co/cc 打开/关闭结果窗
"               :filter 关键词 -> 新建分屏只读窗口过滤大日志/网表匹配行（回车跳回原行）
"   [Git管理]   Space+gd 左右对比(GitHub风格) | Space+gs Git状态 | Space+gb Git blame
"               (对比视图中: ]c/[c 跳差异 | do 拉取覆盖 | 光标移左窗按 Space+q 退出)
"   [窗口/缓冲] Space+sv 垂直分屏 | Space+sh 水平分屏 | Ctrl+h/j/k/l 切换窗口
"               Space+bn/bp 切buffer | Space+bd 关buffer | Space+t 内置终端
" ============================================================

set nocompatible
syntax on
filetype plugin indent on
set regexpengine=1

set encoding=utf-8
scriptencoding utf-8
set fileencoding=utf-8
set fileencodings=ucs-bom,utf-8,gb18030,gbk,big5,latin1
set fileformats=unix,dos
if has('gui_running')
  set ambiwidth=double
endif

set number
set norelativenumber
set nocursorline
set scrolloff=5
set sidescrolloff=8
set showmatch
set matchtime=2
set laststatus=2
set showtabline=2
set signcolumn=yes
set display=lastline
set ruler
set showcmd

set listchars=tab:>\ ,trail:.,extends:>,precedes:<,nbsp:+
set nolist

set noerrorbells
set visualbell
set t_vb=
if exists('+belloff') | set belloff=all | endif

set wrap
set linebreak
set showbreak=
if exists('+breakindent')
  set breakindent
endif

set background=dark
colorscheme desert
if !has('gui_running') && has('termguicolors')
      \ && ($COLORTERM ==# 'truecolor' || $COLORTERM ==# '24bit')
  silent! set termguicolors
endif

function! s:HiTweaks() abort
  highlight clear SignColumn
  highlight CursorLineNr term=bold cterm=bold gui=bold
  highlight ColorColumn ctermbg=238 guibg=#2f2f2f
  highlight DiffAdd    ctermfg=NONE ctermbg=22  guifg=NONE guibg=#1b3826
  highlight DiffDelete ctermfg=242  ctermbg=52  guifg=#6e4042 guibg=#3c1e20
  highlight DiffChange ctermfg=NONE ctermbg=235 guifg=NONE guibg=#1f2937
  highlight DiffText   ctermfg=NONE ctermbg=29  guifg=NONE guibg=#236e3b gui=bold
endfunction
augroup user_hl
  autocmd!
  autocmd ColorScheme * call s:HiTweaks()
augroup END
call s:HiTweaks()

set diffopt=filler,vertical,internal,algorithm:patience,indent-heuristic

function! Statusline() abort
  let l:names = {'n':'NORMAL','i':'INSERT','v':'VISUAL','V':'V-LINE',
        \ "\<C-v>":'V-BLOCK','R':'REPLACE','c':'COMMAND','t':'TERM'}
  let l:mode = get(l:names, mode(), mode())
  let l:ft   = &filetype !=# '' ? &filetype : 'noft'
  let l:enc  = &fileencoding !=# '' ? &fileencoding : &encoding
  let l:fast = get(b:, 'is_large_file', 0) ? '[FAST] ' : ''
  return printf(' %s | %s%%f%%m%%r | %s | %s/%s | %%3l:%%-3c %%3p%%%% ',
        \ l:mode, l:fast, l:ft, &fileformat, l:enc)
endfunction
set statusline=%!Statusline()

set backspace=indent,eol,start
set whichwrap+=<,>,h,l
set autoindent
set nosmartindent
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set shiftround
set nojoinspaces
set nrformats-=octal
set foldmethod=indent
set foldlevel=99
set foldcolumn=0

set incsearch
set hlsearch
set ignorecase
set smartcase
set wrapscan

set wildmenu
set wildmode=longest:full,full
set wildignore=*.o,*.a,*.so,*.pyc,*.class
set wildignore+=*.fsdb,*.vpd,*.vcd,*.shm,*.ddc,*.svf,*.sdf
set wildignore+=*/simv.daidir/*,*/csrc/*,*/INCA_libs/*
set completeopt=menuone,noinsert,noselect
set pumheight=12

set splitright
set splitbelow
set hidden
set equalalways
set winminheight=0

set nobackup
set nowritebackup
set swapfile
set updatetime=300
set autoread
set confirm

if has('persistent_undo')
  set undofile
  set undolevels=2000
endif

let s:cfgdir = expand('~/.vim')
for s:d in ['swap', 'undo', 'backup']
  if !isdirectory(s:cfgdir . '/' . s:d)
    call mkdir(s:cfgdir . '/' . s:d, 'p')
  endif
endfor
execute 'set directory^=' . fnameescape(s:cfgdir . '/swap//')
execute 'set backupdir^=' . fnameescape(s:cfgdir . '/backup//')
if has('persistent_undo')
  execute 'set undodir^=' . fnameescape(s:cfgdir . '/undo//')
  for s:f in glob(s:cfgdir . '/undo/*', 0, 1)
    if getftime(s:f) < localtime() - 30 * 86400
      call delete(s:f)
    endif
  endfor
endif
unlet s:d s:cfgdir
if exists('s:f') | unlet s:f | endif

augroup user_autoread
  autocmd!
  autocmd FocusGained,BufEnter * silent! checktime
augroup END

augroup user_lastpos
  autocmd!
  autocmd BufReadPost *
        \ if line("'\"") > 1 && line("'\"") <= line('$') |
        \   execute 'normal! g`"' |
        \ endif
augroup END

let mapleader = ' '
let maplocalleader = '\'
set timeoutlen=600
set ttimeout
set ttimeoutlen=20

nnoremap <expr> j v:count == 0 ? 'gj' : 'j'
nnoremap <expr> k v:count == 0 ? 'gk' : 'k'
xnoremap <expr> j v:count == 0 ? 'gj' : 'j'
xnoremap <expr> k v:count == 0 ? 'gk' : 'k'

nnoremap <silent> <leader>w :write<CR>
nnoremap <silent> <leader>q :quit<CR>
nnoremap <silent> <leader>h :nohlsearch<CR>
nnoremap <silent> <leader>Q :qa!<CR>

nnoremap <silent> <leader>n :set number!<CR>
nnoremap <silent> <leader>l :set list!<CR>
nnoremap <silent> <leader>z :set wrap!<CR>

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
nnoremap <silent> <leader>sv :vsplit<CR>
nnoremap <silent> <leader>sh :split<CR>

nnoremap <silent> <leader>bn :bnext<CR>
nnoremap <silent> <leader>bp :bprevious<CR>
nnoremap <silent> <leader>bd :bdelete<CR>

nnoremap <silent> <leader>cn :cnext<CR>zz
nnoremap <silent> <leader>cp :cprevious<CR>zz
nnoremap <silent> <leader>co :copen<CR>
nnoremap <silent> <leader>cc :cclose<CR>

nnoremap <silent> <F2> :Lexplore 30<CR>
set pastetoggle=<F12>
nnoremap <silent> <leader>t :terminal ++curwin<CR>

set path=.,
if executable('rg')
  let &grepprg = 'rg --vimgrep --no-heading --smart-case --glob "!*.{log,fsdb,vcd,vpd,shm}"'
  set grepformat=%f:%l:%c:%m
  nnoremap <leader>g :grep! <C-R>=expand('<cword>')<CR><CR>:copen<CR>
else
  set grepprg=grep\ -rnI\ --exclude-dir=.git\ --exclude=*.log\ --exclude=*.fsdb\ --exclude=*.vcd
  set grepformat=%f:%l:%m
  nnoremap <leader>g :grep! -w <C-R>=expand('<cword>')<CR> .<CR>:copen<CR>
endif
nnoremap <leader>G :grep! <C-R>=input('grep: ')<CR><CR>:copen<CR>

if has('cscope') && filereadable('cscope.out')
  set cscopetag cscopeverbose
  silent! cs add cscope.out
endif

runtime macros/matchit.vim
let g:LargeFile = 1024 * 1024 * 1
let s:sv_match_words = '\<begin\>:\<end\>,\<module\>:\<endmodule\>,\<macromodule\>:\<endmodule\>,\<case[xz]\?\>:\<endcase\>,\<generate\>:\<endgenerate\>,\<function\>:\<endfunction\>,\<task\>:\<endtask\>,\<class\>:\<endclass\>,\<interface\>:\<endinterface\>,\<package\>:\<endpackage\>,\<fork\>:\<join\%(_any\|_none\)\?\>,`ifdef:`elsif:`else:`endif'

function! s:sv_setup() abort
  setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab
  setlocal commentstring=//\ %s
  setlocal iskeyword+=$
  setlocal foldmethod=indent
  setlocal foldlevel=99
  setlocal synmaxcol=500
  syntax sync minlines=1500
  if !exists('b:match_words')
    let b:match_ignorecase = 0
    let b:match_words = s:sv_match_words
  endif
  nnoremap <buffer> <silent> gd :VerilogFollowInstance<CR>
  nnoremap <buffer> <silent> gp :VerilogFollowPort<CR>
endfunction

augroup LargeFileMode
  autocmd!
  autocmd BufReadPre *
        \ let b:fsize = getfsize(expand('<afile>')) |
        \ if b:fsize > g:LargeFile || b:fsize == -2 |
        \   let b:is_large_file = 1 |
        \   setlocal noswapfile bufhidden=unload undolevels=-1 |
        \   setlocal foldmethod=manual nofoldenable |
        \   setlocal synmaxcol=200 |
        \   setlocal nocursorline nocursorcolumn |
        \ endif
  autocmd BufReadPost *
        \ if get(b:, 'is_large_file', 0) && &filetype !=# 'liberty' |
        \   syntax clear |
        \   syntax keyword svFastKw module endmodule input output inout wire reg logic bit int integer parameter localparam genvar generate endgenerate assign always always_ff always_comb always_latch initial begin end case endcase if else for |
        \   syntax match svFastComment "//.*$" |
        \   highlight link svFastKw Statement |
        \   highlight link svFastComment Comment |
        \   let b:match_ignorecase = 0 |
        \   let b:match_words = s:sv_match_words |
        \ endif
augroup END

augroup user_ft
  autocmd!
  autocmd BufRead,BufNewFile *.sv,*.svh,*.svi if empty(&l:filetype) | setfiletype systemverilog | endif
  autocmd BufRead,BufNewFile *.v,*.vh        if empty(&l:filetype) | setfiletype verilog | endif
  autocmd BufRead,BufNewFile *.lib           set filetype=liberty
  autocmd BufRead,BufNewFile *.sdc,*.dc      set filetype=sdc
  autocmd BufRead,BufNewFile *.upf           set filetype=upf
  autocmd FileType systemverilog,verilog,verilog_systemverilog
        \ if !get(b:, 'is_large_file', 0) | call s:sv_setup() | endif
  autocmd FileType tcl,sdc,upf,liberty setlocal tabstop=4 shiftwidth=4 softtabstop=4 expandtab
  autocmd FileType markdown setlocal spell spelllang=en,cjk
  autocmd FileType * setlocal formatoptions-=o
augroup END

if has('gui_running')
  winpos 442 63
  set columns=203
  set lines=47
endif

set linespace=0
set guioptions+=m
set guioptions+=T
set guioptions+=a
set guioptions+=r
set guioptions+=L

silent! set guifont=DejaVu\ Sans\ Mono\ 13
if &guifont ==# ''
  silent! set guifont=Monospace\ 13
endif
silent! set guifontwide=Noto\ Sans\ CJK\ SC\ 13

function! s:BumpFont(font, delta) abort
  if a:font =~# '\s\d\+$'
    let l:n = str2nr(matchstr(a:font, '\d\+$'))
    let l:n = max([6, min([40, l:n + a:delta])])
    return substitute(a:font, '\d\+$', l:n, '')
  endif
  return a:font
endfunction

function! s:FontSize(delta) abort
  let l:main = s:BumpFont(&guifont, a:delta)
  if l:main ==# &guifont
    return
  endif
  let &guifont = l:main
  if &guifontwide !=# ''
    let &guifontwide = s:BumpFont(&guifontwide, a:delta)
  endif
endfunction

if has('gui_running')
  nnoremap <silent> <C-ScrollWheelUp>   :call <SID>FontSize(1)<CR>
  nnoremap <silent> <C-ScrollWheelDown> :call <SID>FontSize(-1)<CR>
endif

set mouse=a
silent! set shortmess+=c
set report=0
set history=500
set viminfo='100,<100,s20,h

if has('clipboard')
  set clipboard=unnamedplus
endif

nnoremap <silent> <leader>gs :Git<CR>
nnoremap <silent> <leader>gd :Gvdiffsplit<CR>
nnoremap <silent> <leader>gb :Git blame<CR>
'@ | Set-Content -Encoding UTF8 ".vim/vimrc.vim"

# 3. 生成端口转 logic/wire 插件 (F6)
@'
if exists('g:loaded_port2signal') | finish | endif
let g:loaded_port2signal = 1

function! s:ConvertPortLine(line) abort
  let l:comment = ''
  let l:code = a:line
  let l:cidx = match(l:code, '//')
  if l:cidx != -1
    let l:comment = strpart(l:code, l:cidx)
    let l:code = strpart(l:code, 0, l:cidx)
  endif
  let l:m = matchlist(l:code, '^\(\s*\)\<\(input\|output\|inout\|ref\)\>\s\+\(.\{-}\)\([,;]\?\)\(\s*\)$')
  if empty(l:m) | return a:line | endif
  let l:target_type = (l:m[2] ==# 'inout') ? 'wire ' : 'logic'
  let l:body = substitute(l:m[3], '^\<\(wire\|logic\|reg\|bit\)\>\s*', '', '')
  let l:end_char = (l:m[4] ==# ',' || l:m[4] ==# '') ? ';' : l:m[4]
  return l:m[1] . l:target_type . ' ' . l:body . l:end_char . l:m[5] . l:comment
endfunction

function! PortToSignal() range abort
  for l:lnum in range(a:firstline, a:lastline)
    let l:old = getline(l:lnum)
    let l:new = s:ConvertPortLine(l:old)
    if l:new !=# l:old | call setline(l:lnum, l:new) | endif
  endfor
endfunction

command! -range Port2Signal <line1>,<line2>call PortToSignal()
xnoremap <silent> <F6> :Port2Signal<CR>
nnoremap <silent> <F6> :Port2Signal<CR>
'@ | Set-Content -Encoding UTF8 ".vim/plugin/port2signal.vim"

# 4. 生成日志快速过滤插件 (:filter)
@'
if exists('g:loaded_log_filter') | finish | endif
let g:loaded_log_filter = 1

function! s:JumpToSourceLine() abort
  let l:lnum = str2nr(matchstr(getline('.'), '^\s*\zs\d\+\ze:'))
  let l:src_buf = get(b:, 'filter_src_buf', -1)
  if l:lnum <= 0 || !bufexists(l:src_buf) | return | endif
  let l:winid = bufwinid(l:src_buf)
  if l:winid != -1 | call win_gotoid(l:winid) | else | execute 'buffer ' . l:src_buf | endif
  execute l:lnum
  normal! zz
endfunction

function! s:FilterLines(pat) abort
  let l:src_buf = bufnr('%')
  let l:matches = []
  execute 'silent! global/' . escape(a:pat, '/') . '/call add(l:matches, printf("%6d: %s", line("."), getline(".")))'
  if empty(l:matches)
    echohl WarningMsg | echo 'No matches for: ' . a:pat | echohl None
    return
  endif
  vnew
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
  let b:filter_src_buf = l:src_buf
  call setline(1, l:matches)
  setlocal nomodifiable
  nnoremap <buffer> <silent> <CR> :call <SID>JumpToSourceLine()<CR>
endfunction

command! -nargs=1 Filter call s:FilterLines(<q-args>)
cnoreabbrev <expr> filter (getcmdtype() ==# ':' && getcmdline() =~# '^filter$') ? 'Filter' : 'filter'
'@ | Set-Content -Encoding UTF8 ".vim/plugin/log_filter.vim"

# 5. 生成 Liberty / SDC / UPF 识别与高亮文件
'autocmd BufRead,BufNewFile *.lib set filetype=liberty' | Set-Content -Encoding UTF8 ".vim/ftdetect/liberty.vim"
'autocmd BufRead,BufNewFile *.sdc,*.dc set filetype=sdc' | Set-Content -Encoding UTF8 ".vim/ftdetect/sdc.vim"
'autocmd BufRead,BufNewFile *.upf set filetype=upf' | Set-Content -Encoding UTF8 ".vim/ftdetect/upf.vim"

@'
if exists("b:current_syntax") | finish | endif
syntax case match
syntax region libertyComment start="/\*" end="\*/" contains=@Spell
syntax match  libertyComment "//.*$"
syntax region libertyString start=+"+ skip=+\\"+ end=+"+
syntax match libertyPreProc "^\s*`\(include\|define\|ifdef\|ifndef\|else\|endif\).*$"
syntax match libertyEscape  "\\$"
syntax keyword libertyGroup library cell pin bus bundle ff latch statetable timing internal_power leakage_power power_lut_template lu_table_template cell_rise cell_fall rise_transition fall_transition rise_constraint fall_constraint retaining_rise retaining_fall output_current_rise output_current_fall receiver_capacitance operating_conditions wire_load wire_load_selection type pg_pin test_cell memory memory_read memory_write
syntax keyword libertyAttr direction function three_state next_state clocked_on clear preset related_pin related_pg_pin timing_type timing_sense when sdf_cond area capacitance rise_capacitance fall_capacitance max_capacitance min_capacitance max_transition min_transition fanout_load max_fanout delay_model time_unit voltage_unit current_unit pulling_resistance_unit leakage_power_unit capacitive_load_unit nom_process nom_temperature nom_voltage default_fanout_load default_inout_pin_cap default_input_pin_cap default_output_pin_cap dont_touch dont_use pad_cell is_macro_cell clock_gating_integrated_cell pg_type voltage_name values index_1 index_2 index_3 variable_1 variable_2 variable_3
syntax keyword libertyConst true false input output inout internal combinational rising_edge falling_edge preset clear positive_unate negative_unate non_unate setup_rising setup_falling hold_rising hold_falling recovery_rising recovery_falling removal_rising removal_falling primary_power primary_ground backup_power internal_power
syntax match libertyNumber "\<\d\+\(\.\d\+\)\?\([eE][+-]\?\d\+\)\?\>"
syntax match libertyNumber "[-+]\d\+\(\.\d\+\)\?\([eE][+-]\?\d\+\)\?\>"
highlight default link libertyComment Comment
highlight default link libertyString  String
highlight default link libertyPreProc PreProc
highlight default link libertyEscape  Special
highlight default link libertyGroup   Statement
highlight default link libertyAttr    Type
highlight default link libertyConst   Constant
highlight default link libertyNumber  Number
let b:current_syntax = "liberty"
'@ | Set-Content -Encoding UTF8 ".vim/syntax/liberty.vim"

@'
if exists("b:current_syntax") | finish | endif
runtime! syntax/tcl.vim
unlet! b:current_syntax
syntax keyword sdcClockCmd create_clock create_generated_clock set_clock_groups set_clock_latency set_clock_uncertainty set_clock_transition set_propagated_clock set_ideal_network set_ideal_latency set_ideal_transition set_clock_gating_check set_sense set_clock_sense
syntax keyword sdcIoCmd set_input_delay set_output_delay set_driving_cell set_drive set_load set_port_fanout_number set_fanout_load set_input_transition
syntax keyword sdcExceptionCmd set_false_path set_multicycle_path set_max_delay set_min_delay group_path set_path_margin
syntax keyword sdcEnvCmd set_max_transition set_max_capacitance set_min_capacitance set_max_fanout set_max_area set_case_analysis set_disable_timing set_operating_conditions set_wire_load_model set_wire_load_mode set_wire_load_selection_group set_units set_hierarchy_separator set_dont_touch set_dont_use set_size_only
syntax keyword sdcQueryCmd get_clocks get_ports get_pins get_cells get_nets get_libs get_lib_cells get_lib_pins all_clocks all_inputs all_outputs all_registers all_fanin all_fanout current_design current_instance get_attribute set_attribute sizeof_collection filter_collection add_to_collection remove_from_collection
syntax keyword sdcDcCmd set_app_var define_design_lib analyze elaborate link uniquify check_design check_timing compile compile_ultra optimize_registers set_fix_multiple_port_nets set_boundary_optimization set_ungroup set_clock_gating_style insert_clock_gating report_timing report_area report_power report_qor report_constraint write_file write_sdc
syntax match sdcOption "\s-\a[a-zA-Z0-9_]*\>"
highlight default link sdcClockCmd     Statement
highlight default link sdcIoCmd        Type
highlight default link sdcExceptionCmd Special
highlight default link sdcEnvCmd       PreProc
highlight default link sdcQueryCmd     Function
highlight default link sdcDcCmd        Function
highlight default link sdcOption       Constant
let b:current_syntax = "sdc"
'@ | Set-Content -Encoding UTF8 ".vim/syntax/sdc.vim"

@'
if exists("b:current_syntax") | finish | endif
runtime! syntax/tcl.vim
unlet! b:current_syntax
syntax keyword upfDomainCmd create_power_domain set_scope upf_version load_upf save_upf
syntax keyword upfSupplyCmd create_supply_port create_supply_net create_supply_set connect_supply_net connect_supply_set set_domain_supply_net associate_supply_set set_equivalent add_port_state add_power_state
syntax keyword upfSwitchCmd create_power_switch map_power_switch
syntax keyword upfIsoCmd set_isolation set_isolation_control map_isolation_cell
syntax keyword upfLsCmd set_level_shifter map_level_shifter_cell
syntax keyword upfRetCmd set_retention set_retention_control map_retention_cell set_repeater map_repeater_cell
syntax keyword upfPstCmd create_pst add_pst_state set_sim_corruption_mode set_design_attributes set_port_attributes query_upf find_objects
syntax match upfOption "\s-\a[a-zA-Z0-9_]*\>"
highlight default link upfDomainCmd Statement
highlight default link upfSupplyCmd Type
highlight default link upfSwitchCmd PreProc
highlight default link upfIsoCmd    Special
highlight default link upfLsCmd     Special
highlight default link upfRetCmd    Identifier
highlight default link upfPstCmd    Function
highlight default link upfOption    Constant
let b:current_syntax = "upf"
'@ | Set-Content -Encoding UTF8 ".vim/syntax/upf.vim"

Write-Host "所有配置文件与插件已生成完毕！" -ForegroundColor Green
# 追加到 build_vim.ps1 末尾运行即可
@'
if exists('g:loaded_simple_comment') | finish | endif
let g:loaded_simple_comment = 1
function! s:GetCommentPrefix() abort
  let l:ft = &filetype
  if l:ft =~# '^\(systemverilog\|verilog\|verilog_systemverilog\|c\|cpp\|java\|javascript\)$' | return '//'
  elseif l:ft =~# '^\(tcl\|sdc\|upf\|python\|sh\|bash\|zsh\|yaml\|toml\|make\|cmake\)$' | return '#'
  elseif l:ft ==# 'vim' | return '"'
  elseif !empty(&commentstring) | return substitute(&commentstring, '\s*%s.*$', '', '')
  endif
  return '//'
endfunction
function! s:CommentLines() range abort
  let l:esc_prefix = escape(s:GetCommentPrefix(), '/\')
  for l:lnum in range(a:firstline, a:lastline)
    let l:line = getline(l:lnum)
    if l:line !~# '^\s*$'
      call setline(l:lnum, substitute(l:line, '^\(\s*\)', '\1' . l:esc_prefix . ' ', ''))
    endif
  endfor
endfunction
function! s:UncommentLines() range abort
  let l:esc_prefix = escape(s:GetCommentPrefix(), '/\.*[]^$~')
  for l:lnum in range(a:firstline, a:lastline)
    let l:line = getline(l:lnum)
    let l:new_line = substitute(l:line, '^\(\s*\)' . l:esc_prefix . '\s\?', '\1', '')
    if l:new_line !=# l:line | call setline(l:lnum, l:new_line) | endif
  endfor
endfunction
command! -range CommentLines   <line1>,<line2>call s:CommentLines()
command! -range UncommentLines <line1>,<line2>call s:UncommentLines()
nnoremap <silent> <F3> :CommentLines<CR>
xnoremap <silent> <F3> :CommentLines<CR>
nnoremap <silent> <F4> :UncommentLines<CR>
xnoremap <silent> <F4> :UncommentLines<CR>
'@ | Set-Content -Encoding UTF8 ".vim/plugin/comment.vim"

@'
if exists('g:loaded_verible_format') | finish | endif
let g:loaded_verible_format = 1
function! s:VeribleFormat() abort
  if !executable('verible-verilog-format')
    echohl ErrorMsg | echo '未找到 verible-verilog-format' | echohl None | return
  endif
  if &filetype !~# '^\(systemverilog\|verilog\|verilog_systemverilog\)$'
    echohl WarningMsg | echo '非 SV/Verilog 文件: ' . &filetype | echohl None | return
  endif
  let l:view = winsaveview()
  let l:formatted = systemlist('verible-verilog-format --indentation_spaces=4 -', getline(1, '$'))
  if v:shell_error != 0
    echohl ErrorMsg | echo 'Verible 格式化失败（请检查语法错误）' | echohl None | return
  endif
  silent! undojoin
  call setline(1, l:formatted)
  if len(l:formatted) < line('$') | execute (len(l:formatted) + 1) . ',$delete _' | endif
  call winrestview(l:view)
  echo 'Verible 格式化完成'
endfunction
command! VeribleFormat call s:VeribleFormat()
nnoremap <silent> <F5> :VeribleFormat<CR>
'@ | Set-Content -Encoding UTF8 ".vim/plugin/verible_format.vim"

@'
if exists('g:loaded_copy_path') | finish | endif
let g:loaded_copy_path = 1
function! s:CopyFullPath() abort
  let l:path = expand('%:p')
  if empty(l:path)
    echohl WarningMsg | echo '当前缓冲区尚未保存为文件' | echohl None | return
  endif
  let @" = l:path
  silent! let @+ = l:path
  silent! let @* = l:path
  echo '已复制路径: ' . l:path
endfunction
command! CopyPath call s:CopyFullPath()
nnoremap <silent> <F9> :CopyPath<CR>
'@ | Set-Content -Encoding UTF8 ".vim/plugin/copy_path.vim"