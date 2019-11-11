" ==============================================================================
" Display quickfix errors in a popup window (like a tooltip)
" File:         autoload/qf/tooltip.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-tooltip
" Last Change:  Nov 9, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:type = {'e': 'error', 'w': 'warning', 'i': 'info'}

function! s:error(msg) abort
    echohl ErrorMsg | echomsg a:msg | echohl None
    return 0
endfunction

function! qf#tooltip#show(dict) abort
    if !has_key(a:dict, 'title') || !has_key(a:dict, 'items')
        return s:error('qftooltip: dict requires "title" and "items" keys.')
    endif

    if empty(a:dict.items)
        return
    endif

    let entries = filter(a:dict.items, {_,i -> i.bufnr == bufnr('%') && i.lnum == line('.')})

    if empty(entries)
        return
    endif

    hi def link QfTooltip           Pmenu
    hi def link QfTooltipTitle      Title
    hi def link QfTooltipLineNr     Directory
    hi def link QfTooltipScrollbar  PmenuSbar
    hi def link QfTooltipThumb      PmenuThumb

    let text = []
    for item in entries
        if empty(item.type)
            call add(text, printf('%d:%d %s', item.lnum, item.col, trim(item.text)))
        else
            if item.nr == -1
                let type = printf('%s', s:type[tolower(item.type)])
            else
                let type = printf('%s %d', s:type[tolower(item.type)], item.nr)
            endif
            call add(text, printf('%d:%d %s %s', item.lnum, item.col, type, trim(item.text)))
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
