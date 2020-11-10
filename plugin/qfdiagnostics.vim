" ==============================================================================
" Display quickfix errors in popup window and sign column
" File:         plugin/qfdiagnostics.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-diagnostics
" Last Change:  Nov 10, 2020
" License:      Same as Vim itself (see :h license)
" ==============================================================================

if exists('g:loaded_qfdiagnostics')
    finish
endif
let g:loaded_qfdiagnostics = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

nnoremap <silent> <plug>(qf-diagnostics-popup-quickfix)  :<c-u>call qfdiagnostics#popup(0)<cr>
nnoremap <silent> <plug>(qf-diagnostics-popup-loclist)   :<c-u>call qfdiagnostics#popup(1)<cr>
nnoremap <silent> <plug>(qf-diagnostics-toggle-quickfix) :<c-u>call qfdiagnostics#toggle(0)<cr>
nnoremap <silent> <plug>(qf-diagnostics-toggle-loclist)  :<c-u>call qfdiagnostics#toggle(1)<cr>

command -bar  DiagnosticsPlace call qfdiagnostics#place(0)
command -bar LDiagnosticsPlace call qfdiagnostics#place(1)

command -bar        DiagnosticsClear call qfdiagnostics#cclear()
command -bar -bang LDiagnosticsClear call qfdiagnostics#lclear(<bang>0)

command -bar  DiagnosticsToggle call qfdiagnostics#toggle(0)
command -bar LDiagnosticsToggle call qfdiagnostics#toggle(1)

let &cpoptions = s:save_cpo
unlet s:save_cpo
