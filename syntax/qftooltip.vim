" ==============================================================================
" Show quickfix errors in a popup window (like a tooltip)
" File:         syntax/qftooltip.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-tooltip
" Last Change:  Nov 9, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

if exists('b:current_syntax')
    finish
endif

syntax match QfTooltipLineNr    "^\d\+\(:\d\+\)\?" nextgroup=QfTooltipError,QfTooltipWarning,QfTooltipInfo skipwhite
syntax match QfTooltipError     "\<error\>\( \d\+\)\?" contained
syntax match QfTooltipWarning   "\<warning\>\( \d\+\)\?" contained
syntax match QfTooltipInfo      "\<info\>\( \d\+\)\?" contained

hi def link QfTooltipLineNr     LineNr
hi def link QfTooltipError      ErrorMsg
hi def link QfTooltipWarning    WarningMsg
hi def link QfTooltipInfo       MoreMsg

let b:current_syntax = 'qftooltip'
