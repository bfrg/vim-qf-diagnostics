" ==============================================================================
" Display quickfix errors in a popup window (like a tooltip)
" File:         plugin/qftooltip.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-tooltip
" Last Change:  Jun 25, 2020
" License:      Same as Vim itself (see :h license)
" ==============================================================================

if exists('g:loaded_qftooltip')
    finish
endif
let g:loaded_qftooltip = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

" Display quickfix errors for current line in a popup window
nnoremap <silent> <plug>(qf-tooltip-qflist) :<c-u>call qftooltip#show(0)<cr>

" Display location-list errors for current line in a popup window
nnoremap <silent> <plug>(qf-tooltip-loclist) :<c-u>call qftooltip#show(1)<cr>

let &cpoptions = s:save_cpo
unlet s:save_cpo
