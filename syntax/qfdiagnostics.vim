" ==============================================================================
" Display quickfix errors in popup window and sign column
" File:         syntax/qfdiagnostics.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-diagnostics
" Last Change:  Nov 10, 2020
" License:      Same as Vim itself (see :h license)
" ==============================================================================

if exists('b:current_syntax')
    finish
endif

syntax match QfDiagnosticsLineNr    "^\d\+\%(:\d\+\)\?" nextgroup=QfDiagnosticsError,QfDiagnosticsWarning,QfDiagnosticsInfo skipwhite
syntax match QfDiagnosticsError     "\<error\>\%(:\| \d\+:\)" contained
syntax match QfDiagnosticsWarning   "\<warning\>\%(:\| \d\+:\)" contained
syntax match QfDiagnosticsInfo      "\<info\>\%(:\| \d\+:\)" contained
syntax match QfDiagnosticsNote      "\<note\>\%(:\| \d\+:\)" contained

hi def link QfDiagnosticsLineNr     Directory
hi def link QfDiagnosticsError      ErrorMsg
hi def link QfDiagnosticsWarning    WarningMsg
hi def link QfDiagnosticsInfo       MoreMsg
hi def link QfDiagnosticsNote       Todo

let b:current_syntax = 'qfdiagnostics'
