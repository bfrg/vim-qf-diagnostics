" ==============================================================================
" Display quickfix errors in a popup window (like a tooltip)
" File:         autoload/qftooltip.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-tooltip
" Last Change:  Feb 25, 2020
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

hi def link QfTooltip           Pmenu
hi def link QfTooltipTitle      Title
hi def link QfTooltipLineNr     Directory
hi def link QfTooltipScrollbar  PmenuSbar
hi def link QfTooltipThumb      PmenuThumb

let s:type = {
        \ 'e': 'error',
        \ 'w': 'warning',
        \ 'i': 'info',
        \ 'n': 'note',
        \ 'h': 'hint'
        \ }

function! s:error(msg) abort
    echohl ErrorMsg | echomsg a:msg | echohl None
endfunction

function! qftooltip#show(dict) abort
    if !has_key(a:dict, 'title') || !has_key(a:dict, 'items')
        return s:error('qftooltip: dict requires "title" and "items" keys.')
    endif

    if empty(a:dict.items)
        return
    endif

    let entries = filter(a:dict.items, "v:val.bufnr == bufnr('%') && v:val.lnum == line('.')")

    if empty(entries)
        return
    endif

    let text = []
    for item in entries
        if empty(item.type)
            call extend(text, split(printf('%d:%d %s', item.lnum, item.col, trim(item.text)), '\n'))
        else
            if item.nr == -1
                let type = printf('%s', get(s:type, tolower(item.type), ''))
            else
                let type = printf('%s %d', get(s:type, tolower(item.type), ''), item.nr)
            endif
            call extend(text, split(printf('%d:%d %s %s', item.lnum, item.col, type, trim(item.text)), '\n'))
        endif
    endfor

    let winid = popup_atcursor(text, {
            \ 'border': [1,1,0,1],
            \ 'borderchars': [' '],
            \ 'borderhighlight': ['QfTooltipTitle'],
            \ 'highlight': 'QfTooltip',
            \ 'title': a:dict.title,
            \ 'scrollbar': v:true,
            \ 'scrollbarhighlight': 'QfTooltipScrollbar',
            \ 'thumbhighlight': 'QfTooltipThumb'
            \ })

    call setbufvar(winbufnr(winid), '&filetype', 'qftooltip')
    return winid
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
