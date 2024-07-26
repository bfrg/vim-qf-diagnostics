vim9script
# ==============================================================================
# Highlight quickfix locations and show error messages in popup window
# File:         autoload/qfdiagnostics/config.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-qf-diagnostics
# Last Change:  Jul 27, 2024
# License:      Same as Vim itself (see :h license)
# ==============================================================================

const defaults: dict<any> = {
    popup_scrollup: "\<c-k>",
    popup_scrolldown: "\<c-j>",
    popup_border: [0, 0, 0, 0],
    popup_maxheight: 0,
    popup_maxwidth: 0,
    popup_borderchars: [],
    popup_mapping: true,
    popup_items: 'all',
    popup_attach: true,
    texthl: true,
    text_error:   {highlight: 'SpellBad',   priority: 14},
    text_warning: {highlight: 'SpellCap',   priority: 13},
    text_info:    {highlight: 'SpellLocal', priority: 12},
    text_note:    {highlight: 'SpellRare',  priority: 11},
    text_other:   {highlight: 'Underlined', priority: 10},
    signs: true,
    sign_error:   {text: 'E', priority: 14, texthl: 'ErrorMsg'},
    sign_warning: {text: 'W', priority: 13, texthl: 'WarningMsg'},
    sign_info:    {text: 'I', priority: 12, texthl: 'MoreMsg'},
    sign_note:    {text: 'N', priority: 11, texthl: 'Todo'},
    sign_other:   {text: '?', priority: 10, texthl: 'Normal'},
    virttext: false,
    virt_padding: 2,
    virt_align: 'right',
    virt_error:   {prefix: '', highlight: 'ErrorMsg'},
    virt_warning: {prefix: '', highlight: 'WarningMsg'},
    virt_info:    {prefix: '', highlight: 'MoreMsg'},
    virt_note:    {prefix: '', highlight: 'MoreMsg'},
    virt_other:   {prefix: '', highlight: 'Normal'}
}

export def Getopt(x: string): any
    return get(g:, 'qfdiagnostics', {})->get(x, defaults[x])
enddef
