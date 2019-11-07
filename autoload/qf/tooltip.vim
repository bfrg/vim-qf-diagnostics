" ==============================================================================
" Display quickfix errors in a popup window (like a tooltip)
" File:         autoload/qf/tooltip.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-tooltip
" Last Change:  Nov 7, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:type = {'e': 'error', 'w': 'warning', 'i': 'info'}
let s:props = {
        \ 'num': 'prop_qftooltip',
        \ 'e': 'prop_qftooltip_error',
        \ 'w': 'prop_qftooltip_warning',
        \ 'i': 'prop_qftooltip_info'
        \ }

function! s:error(msg) abort
    echohl ErrorMsg | echomsg a:msg | echohl None
    return 0
endfunction

function! s:popup_cb(winid, result) abort
    call prop_type_delete(s:props.num)
    call prop_type_delete(s:props.w)
    call prop_type_delete(s:props.e)
    call prop_type_delete(s:props.i)
endfunction

" FIXME currently only one popup window can be shown
function! qf#tooltip#show(dict) abort
    if !has_key(a:dict, 'title') || !has_key(a:dict, 'items')
        s:error('qftooltip: dict requires "title" and "items" keys.')
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
    hi def link QfTooltipError      ErrorMsg
    hi def link QfTooltipWarning    WarningMsg
    hi def link QfTooltipInfo       MoreMsg
    hi def link QfTooltipScrollbar  PmenuSbar
    hi def link QfTooltipThumb      PmenuThumb

    call prop_type_add(s:props.num, {'highlight': 'QfTooltipLineNr'})
    call prop_type_add(s:props.e, {'highlight': 'QfTooltipError'})
    call prop_type_add(s:props.w, {'highlight': 'QfTooltipWarning'})
    call prop_type_add(s:props.i, {'highlight': 'QfTooltipInfo'})

    let text = []
    for item in entries
        let loc_len = len(printf('%d:%d', item.lnum, item.col))
        let props = [{'col': 1, 'length': loc_len, 'type': s:props.num}]
        if empty(item.type)
            let line = printf('%d:%d %s', item.lnum, item.col, trim(item.text))
        else
            if item.nr == -1
                let type = printf('%s', s:type[tolower(item.type)])
                let type_len = len(type)
            else
                let type = printf('%s %d', s:type[tolower(item.type)], item.nr)
                let type_len = len(type)
            endif
            call add(props, {
                    \ 'col': loc_len + 1,
                    \ 'length': type_len + 1,
                    \ 'type': s:props[tolower(item.type)]
                    \ })
            let line = printf('%d:%d %s %s', item.lnum, item.col, type, trim(item.text))
        endif
        call add(text, {'text': line, 'props': props})
    endfor

    return popup_atcursor(text, {
            \ 'border': [1,1,1,1],
            \ 'borderchars': [' '],
            \ 'borderhighlight': ['QfTooltipTitle'],
            \ 'highlight': 'QfTooltip',
            \ 'title': a:dict.title,
            \ 'scrollbar': v:true,
            \ 'scrollbarhighlight': 'QfTooltipScrollbar',
            \ 'thumbhighlight': 'QfTooltipThumb',
            \ 'callback': funcref('s:popup_cb')
            \ })
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
