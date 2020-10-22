" ==============================================================================
" Display quickfix errors in popup window and sign column
" File:         plugin/qfdiagnostics.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-diagnostics
" Last Change:  Oct 22, 2020
" License:      Same as Vim itself (see :h license)
" ==============================================================================

if exists('g:loaded_qfdiagnostics')
    finish
endif
let g:loaded_qfdiagnostics = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

nnoremap <silent> <plug>(qf-diagnostics-popup-quickfix) :<c-u>call qfdiagnostics#popup(0)<cr>
nnoremap <silent> <plug>(qf-diagnostics-popup-loclist)  :<c-u>call qfdiagnostics#popup(1)<cr>

command -bar  DiagnosticsPlace call qfdiagnostics#place(0, 100)
command -bar  DiagnosticsClear call qfdiagnostics#clear()
command -bar LDiagnosticsPlace call qfdiagnostics#place(1, 101)
command -bar LDiagnosticsClear call qfdiagnostics#clear()

let &cpoptions = s:save_cpo
unlet s:save_cpo
