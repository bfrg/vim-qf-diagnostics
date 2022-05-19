vim9script
# ==============================================================================
# Display quickfix errors in popup window and sign column
# File:         plugin/qfdiagnostics.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-qf-diagnostics
# Last Change:  May 19, 2022
# License:      Same as Vim itself (see :h license)
# ==============================================================================

if get(g:, 'loaded_qfdiagnostics')
    finish
endif
g:loaded_qfdiagnostics = 1

import autoload 'qfdiagnostics.vim' as diagnostics

nnoremap <plug>(qf-diagnostics-popup-quickfix) <scriptcmd>diagnostics.Popup(false)<cr>
nnoremap <plug>(qf-diagnostics-popup-loclist)  <scriptcmd>diagnostics.Popup(true)<cr>

command -bar  DiagnosticsPlace diagnostics.Place(false)
command -bar LDiagnosticsPlace diagnostics.Place(true)

command -bar        DiagnosticsClear diagnostics.Cclear()
command -bar -bang LDiagnosticsClear diagnostics.Lclear(<bang>false)

command -bar  DiagnosticsToggle diagnostics.Toggle(false)
command -bar LDiagnosticsToggle diagnostics.Toggle(true)
