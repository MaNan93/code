" ============================================================================
" Line comment / uncomment functions - multi-filetype support
" F3: comment line(s),  F4: uncomment line(s)
" ============================================================================

" Return the comment symbol for the current filetype
function! GetCommentSymbol()
    let filetype = &filetype
    
    if filetype == 'python'
        return '#'
    elseif filetype == 'vim'
        return '"'
    elseif filetype == 'verilog' || filetype == 'systemverilog'
        return '//'
    elseif filetype == 'c' || filetype == 'cpp'
        return '//'
    elseif filetype == 'javascript' || filetype == 'typescript'
        return '//'
    elseif filetype == 'java'
        return '//'
    elseif filetype == 'rust'
        return '//'
    elseif filetype == 'go'
        return '//'
    elseif filetype == 'sh' || filetype == 'bash'
        return '#'
    elseif filetype == 'ruby'
        return '#'
    elseif filetype == 'perl'
        return '#'
    elseif filetype == 'lua'
        return '--'
    elseif filetype == 'sql'
        return '--'
    elseif filetype == 'tcl'
        return '#'
    elseif filetype == 'make'
        return '#'
    elseif filetype == 'dosini'
        return '#'
    elseif filetype == 'yaml'
        return '#'
    elseif filetype == 'toml'
        return '#'
    elseif filetype == 'ps1'
        return '#'
    elseif filetype == 'r'
        return '#'
    elseif filetype == 'vhdl'
        return '--'
    else
        " Check special filenames
        let filename = expand('%:t')
        
        if filename == 'cshrc' || filename == '.cshrc'
            return '#'
        elseif filename == 'tcshrc' || filename == '.tcshrc'
            return '#'
        elseif filename == 'zshrc' || filename == '.zshrc'
            return '#'
        elseif filename =~ '\.f$' || filename =~ '\.lst$' || filename =~ '\.list$'
            return '//'
        elseif filename == 'Makefile' || filename == 'makefile' || filename == 'GNUmakefile'
            return '#'
        elseif filename =~ '\.mk$'
            return '#'
        elseif filename =~ '\.conf$' || filename =~ '\.cfg$' || filename =~ '\.ini$'
            return '#'
        elseif filename =~ '\.yaml$' || filename =~ '\.yml$'
            return '#'
        elseif filename =~ '\.toml$'
            return '#'
        elseif filename =~ '\.ps1$' || filename =~ '\.r$'
            return '#'
        elseif filename =~ '\.h$' || filename =~ '\.hpp$' || filename =~ '\.cc$' || filename =~ '\.cxx$'
            return '//'
        elseif filename =~ '\.proto$' || filename =~ '\.scala$' || filename =~ '\.kt$' || filename =~ '\.kts$'
            return '//'
        elseif filename =~ '\.vhd$' || filename =~ '\.vhdl$'
            return '--'
        elseif filename =~ '\.sdc$'
            return '#'
        endif
        
        " Default
        return '#'
    endif
endfunction

" Return 1 if a line is already commented using current comment symbol
function! IsLineCommented(line_text, comment)
    let comment_pattern = '^\s*' . escape(a:comment, '/') . '\s\?'
    return a:line_text =~ comment_pattern
endfunction

" Add line comment
function! CommentLine()
    let comment = GetCommentSymbol()
    let current_line = getline('.')
    
    " Skip if already commented
    if IsLineCommented(current_line, comment)
        return
    endif
    
    " Insert comment symbol at column 0
    call setline('.', comment . ' ' . current_line)
endfunction

" Remove line comment
function! UncommentLine()
    let comment = GetCommentSymbol()
    let current_line = getline('.')
    
    " Build pattern to match comment prefix (with optional leading whitespace)
    let comment_pattern = '^\(\s*\)' . escape(comment, '/') . '\s\?'
    
    " Strip comment symbol if found, preserve indentation
    if current_line =~ comment_pattern
        call setline('.', substitute(current_line, comment_pattern, '\1', ''))
    endif
endfunction

" Toggle comment on current line
function! ToggleLineComment()
    let comment = GetCommentSymbol()
    let current_line = getline('.')

    if IsLineCommented(current_line, comment)
        call UncommentLine()
    else
        call CommentLine()
    endif
endfunction

" Key mappings
nnoremap <F3> :call ToggleLineComment()<CR>

" Legacy mappings (kept for future use)
" nnoremap <F3> :call CommentLine()<CR>
" nnoremap <F4> :call UncommentLine()<CR>

" Visual mode mappings (comment/uncomment multiple lines)
vnoremap <F3> :call VisualToggleLine()<CR>

" Legacy visual mappings (kept for future use)
" vnoremap <F3> :call VisualCommentLine()<CR>
" vnoremap <F4> :call VisualUncommentLine()<CR>

" Comment selected lines in visual mode
function! VisualCommentLine()
    let comment = GetCommentSymbol()
    " Get selected line range
    let start_line = line("'<")
    let end_line = line("'>")
    
    for line_num in range(start_line, end_line)
        let current_line = getline(line_num)
        
        " Preserve indentation
        let indent = matchstr(current_line, '^\s*')
        let content = substitute(current_line, '^\s*', '', '')
        
        " Skip empty lines
        if empty(content)
            continue
        endif
        
        " Skip if already commented
        if current_line !~ '^' . escape(comment, '/') . '\s'
            call setline(line_num, comment . ' ' . current_line)
        endif
    endfor
endfunction

" Uncomment selected lines in visual mode
function! VisualUncommentLine()
    let comment = GetCommentSymbol()
    let start_line = line("'<")
    let end_line = line("'>")
    
    let comment_pattern = '^\(\s*\)' . escape(comment, '/') . '\s\?'
    
    for line_num in range(start_line, end_line)
        let current_line = getline(line_num)
        
        if current_line =~ comment_pattern
            call setline(line_num, substitute(current_line, comment_pattern, '\1', ''))
        endif
    endfor
endfunction

" Toggle comment on selected lines in visual mode
function! VisualToggleLine()
    let comment = GetCommentSymbol()
    let start_line = line("'<")
    let end_line = line("'>")

    for line_num in range(start_line, end_line)
        let current_line = getline(line_num)
        let content = substitute(current_line, '^\s*', '', '')

        " Skip empty lines
        if empty(content)
            continue
        endif

        if IsLineCommented(current_line, comment)
            let comment_pattern = '^\(\s*\)' . escape(comment, '/') . '\s\?'
            call setline(line_num, substitute(current_line, comment_pattern, '\1', ''))
        else
            call setline(line_num, comment . ' ' . current_line)
        endif
    endfor
endfunction

" ============================================================================
" Usage:
" - Source this file from your gvimrc:  source /path/to/comment_toggle.vim
" - F3: toggle comment/uncomment for current line or visual selection
" - Legacy F3/F4 mappings are kept as commented lines in this file
" - Supported filetypes: python, vim, verilog, systemverilog, c, cpp,
"                         javascript, typescript, java, rust, go, sh, bash,
"                         ruby, perl, lua, sql, tcl, make, dosini, yaml,
"                         toml, ps1, r, vhdl, cshrc, tcshrc, zshrc,
"                         Makefile/makefile/GNUmakefile, .mk,
"                         .conf/.cfg/.ini, .yaml/.yml, .toml, .ps1, .r,
"                         .h/.hpp/.cc/.cxx (use //),
"                         .proto/.scala/.kt/.kts (use //),
"                         .vhd/.vhdl (use --), .f/.lst/.list (use //),
"                         .sdc files
" ============================================================================
