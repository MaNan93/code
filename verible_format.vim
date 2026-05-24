" ============================================================================
" Verible formatter mapping for gVim
" F5: format current .v/.vh/.sv/.svh file using verible-verilog-format
" ============================================================================

function! FormatWithVerible() abort
    let l:ext = tolower(expand('%:e'))
    if index(['v', 'vh', 'sv', 'svh'], l:ext) < 0
        echohl ErrorMsg
        echom 'F5 formatter only supports .v .vh .sv .svh files'
        echohl None
        return
    endif

    if executable('verible-verilog-format') == 0
        echohl ErrorMsg
        echom 'verible-verilog-format not found in PATH'
        echohl None
        return
    endif

    let l:filepath = expand('%:p')
    if empty(l:filepath)
        echohl ErrorMsg
        echom 'current buffer has no file path'
        echohl None
        return
    endif

    let l:view = winsaveview()
    silent write

    let l:cmd = 'verible-verilog-format --inplace ' . shellescape(l:filepath)
    let l:save_shelltemp = &shelltemp
    set noshelltemp
    call system(l:cmd)
    let &shelltemp = l:save_shelltemp

    if v:shell_error != 0
        echohl ErrorMsg
        echom 'verible-verilog-format failed (exit code: ' . v:shell_error . ')'
        echohl None
        return
    endif

    edit!
    call winrestview(l:view)
    echom 'Formatted with verible-verilog-format'
endfunction

augroup VeribleFormatKeymap
    autocmd!
    autocmd BufRead,BufNewFile *.v,*.vh,*.sv,*.svh nnoremap <buffer> <F5> :call FormatWithVerible()<CR>
    autocmd BufRead,BufNewFile *.v,*.vh,*.sv,*.svh vnoremap <buffer> <F5> <Esc>:call FormatWithVerible()<CR>
augroup END
