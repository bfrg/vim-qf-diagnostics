" ==============================================================================
" Display quickfix errors in popup window and sign column
" File:         plugin/qfdiagnostics.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-diagnostics
" Last Change:  Nov 19, 2021
" License:      Same as Vim itself (see :h license)
" ==============================================================================

if !has('patch-8.2.3591') || get(g:, 'loaded_qfdiagnostics')
    finish
endif
let g:loaded_qfdiagnostics = 1

nnoremap <plug>(qf-diagnostics-popup-quickfix) <cmd>call qfdiagnostics#popup(v:false)<cr>
nnoremap <plug>(qf-diagnostics-popup-loclist)  <cmd>call qfdiagnostics#popup(v:true)<cr>

command -bar  DiagnosticsPlace call qfdiagnostics#place(v:false)
command -bar LDiagnosticsPlace call qfdiagnostics#place(v:true)

command -bar        DiagnosticsClear call qfdiagnostics#cclear()
command -bar -bang LDiagnosticsClear call qfdiagnostics#lclear(<bang>v:false)

command -bar  DiagnosticsToggle call qfdiagnostics#toggle(v:false)
command -bar LDiagnosticsToggle call qfdiagnostics#toggle(v:true)
