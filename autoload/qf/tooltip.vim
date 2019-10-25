" ==============================================================================
" Display quickfix errors in a popup window (like a tooltip)
" File:         autoload/qf/tooltip.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-tooltip
" Last Change:  Oct 25, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

" FIXME currently only one popup window can be shown
function! qf#tooltip#show() abort
    if !getqflist({'size': 0}).size
        return
    endif

    let entries = filter(getqflist(), {_,i -> i.bufnr == bufnr('%') && i.lnum == line('.')})

    if empty(entries)
        return
    endif

    hi def link QfTooltip           Pmenu
    hi def link QfTooltipTitle      Title
    hi def link QfTooltipLineNr     Directory

    " Highlighting for line:column part in popup window
    let prop = prop_type_add('popup_prop_qftooltip', {'highlight': 'QfTooltipLineNr'})

    let text = []
    for item in entries
        let length = len(printf('%d:%d', item.lnum, item.col))
        call add(text, {
                \ 'text': printf('%d:%d %s', item.lnum, item.col, trim(item.text)),
                \ 'props': [{'col': 1, 'length': length, 'type': 'popup_prop_qftooltip'}]
                \ })
    endfor

    return popup_atcursor(text, {
            \ 'border': [1,1,1,1],
            \ 'borderchars': [' '],
            \ 'borderhighlight': ['QfTooltipTitle'],
            \ 'highlight': 'QfTooltip',
            \ 'title': getqflist({'title': 0}).title,
            \ 'callback': {... -> prop_type_delete('popup_prop_qftooltip')}
            \ })
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
