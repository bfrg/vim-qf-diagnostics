vim9script
# ==============================================================================
# Highlight quickfix errors and show error messages in popup window
# File:         plugin/qfdiagnostics.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-qf-diagnostics
# Last Change:  Nov 26, 2022
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

command -bar  DiagnosticsPlace highlight.Place(false)
command -bar LDiagnosticsPlace highlight.Place(true)

command -bar        DiagnosticsClear highlight.Clear(false)
command -bar -bang LDiagnosticsClear highlight.Clear(true, <bang>false)

command -bar  DiagnosticsToggle highlight.Toggle(false)
command -bar LDiagnosticsToggle highlight.Toggle(true)
