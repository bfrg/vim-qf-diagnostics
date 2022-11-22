vim9script
# ==============================================================================
# Highlight quickfix errors and show error messages in popup window
# File:         plugin/qfdiagnostics.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-qf-diagnostics
# Last Change:  Nov 22, 2022
# License:      Same as Vim itself (see :h license)
# ==============================================================================

if get(g:, 'loaded_qfdiagnostics')
    finish
endif
g:loaded_qfdiagnostics = 1

import autoload 'qfdiagnostics.vim' as diagnostics

nnoremap <plug>(qf-diagnostics-popup-quickfix) <scriptcmd>diagnostics.Popup(false)<cr>
nnoremap <plug>(qf-diagnostics-popup-loclist)  <scriptcmd>diagnostics.Popup(true)<cr>

command -nargs=? -bar -complete=custom,diagnostics.Complete  DiagnosticsPlace diagnostics.Place(false, <q-args>)
command -nargs=? -bar -complete=custom,diagnostics.Complete LDiagnosticsPlace diagnostics.Place(true,  <q-args>)

command -bar        DiagnosticsClear diagnostics.Cclear()
command -bar -bang LDiagnosticsClear diagnostics.Lclear(<bang>false)

command -nargs=? -bar -complete=custom,diagnostics.Complete  DiagnosticsToggle diagnostics.Toggle(false, <q-args>)
command -nargs=? -bar -complete=custom,diagnostics.Complete LDiagnosticsToggle diagnostics.Toggle(true,  <q-args>)
