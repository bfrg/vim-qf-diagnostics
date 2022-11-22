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

import autoload '../autoload/qfdiagnostics/popup.vim'
import autoload '../autoload/qfdiagnostics/highlight.vim'

nnoremap <plug>(qf-diagnostics-popup-quickfix) <scriptcmd>popup.Show(false)<cr>
nnoremap <plug>(qf-diagnostics-popup-loclist)  <scriptcmd>popup.Show(true)<cr>

command -nargs=? -bar -complete=custom,highlight.Complete  DiagnosticsPlace highlight.Place(false, <q-args>)
command -nargs=? -bar -complete=custom,highlight.Complete LDiagnosticsPlace highlight.Place(true,  <q-args>)

command -bar        DiagnosticsClear highlight.Cclear()
command -bar -bang LDiagnosticsClear highlight.Lclear(<bang>false)

command -nargs=? -bar -complete=custom,highlight.Complete  DiagnosticsToggle highlight.Toggle(false, <q-args>)
command -nargs=? -bar -complete=custom,highlight.Complete LDiagnosticsToggle highlight.Toggle(true,  <q-args>)
