" ==============================================================================
" Display quickfix errors in popup window and sign column
" File:         plugin/qfdiagnostics.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-diagnostics
" Last Change:  Nov 20, 2020
" License:      Same as Vim itself (see :h license)
" ==============================================================================

if get(g:, 'loaded_qfdiagnostics')
    finish
endif
let g:loaded_qfdiagnostics = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

nnoremap <silent> <plug>(qf-diagnostics-popup-quickfix) :<c-u>call qfdiagnostics#popup(v:false)<cr>
nnoremap <silent> <plug>(qf-diagnostics-popup-loclist)  :<c-u>call qfdiagnostics#popup(v:true)<cr>

command -bar  DiagnosticsPlace call qfdiagnostics#place(v:false)
command -bar LDiagnosticsPlace call qfdiagnostics#place(v:true)

command -bar        DiagnosticsClear call qfdiagnostics#cclear()
command -bar -bang LDiagnosticsClear call qfdiagnostics#lclear(<bang>v:false)

command -bar  DiagnosticsToggle call qfdiagnostics#toggle(v:false)
command -bar LDiagnosticsToggle call qfdiagnostics#toggle(v:true)

let &cpoptions = s:save_cpo
unlet s:save_cpo
