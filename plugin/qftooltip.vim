" ==============================================================================
" Display quickfix errors in a popup window (like a tooltip)
" File:         plugin/qftooltip.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-tooltip
" Last Change:  Oct 24, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

" Display quickfix errors in current line in a popup window
nnoremap <silent> <plug>(qf-tooltip-show) :<c-u>call qf#tooltip#show()<cr>

let &cpoptions = s:save_cpo
unlet s:save_cpo
