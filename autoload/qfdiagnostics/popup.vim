vim9script
# ==============================================================================
# Highlight quickfix locations and show error messages in popup window
# File:         autoload/qfdiagnostics/popup.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-qf-diagnostics
# Last Change:  Dec 8, 2022
# License:      Same as Vim itself (see :h license)
# ==============================================================================

import './config.vim'

hlset([
    {name: 'QfDiagnostics',          linksto: 'Pmenu',      default: true},
    {name: 'QfDiagnosticsBorder',    linksto: 'Pmenu',      default: true},
    {name: 'QfDiagnosticsScrollbar', linksto: 'PmenuSbar',  default: true},
    {name: 'QfDiagnosticsThumb',     linksto: 'PmenuThumb', default: true},
    {name: 'QfDiagnosticsItemNr',    linksto: 'Title',      default: true},
    {name: 'QfDiagnosticsLineNr',    linksto: 'Directory',  default: true},
    {name: 'QfDiagnosticsError',     linksto: 'ErrorMsg',   default: true},
    {name: 'QfDiagnosticsWarning',   linksto: 'WarningMsg', default: true},
    {name: 'QfDiagnosticsInfo',      linksto: 'MoreMsg',    default: true},
    {name: 'QfDiagnosticsNote',      linksto: 'MoreMsg',    default: true},
])

prop_type_add('qf-popup', {})

var popup_id: number = 0

# Look-up table used for popup window to display nice text instead of error
# character
const typename: dict<string> = {E: 'error', W: 'warning', I: 'info', N: 'note'}

def Popup_filter(winid: number, key: string): bool
    if line('$', winid) == popup_getpos(winid).core_height
        return false
    endif
    popup_setoptions(winid, {minheight: popup_getpos(winid).core_height})

    if key == config.Getopt('popup_scrolldown')
        const line: number = popup_getoptions(winid).firstline
        const newline: number = line < line('$', winid) ? (line + 1) : line('$', winid)
        popup_setoptions(winid, {firstline: newline})
    elseif key == config.Getopt('popup_scrollup')
        const line: number = popup_getoptions(winid).firstline
        const newline: number = (line - 1) > 0 ? (line - 1) : 1
        popup_setoptions(winid, {firstline: newline})
    else
        return false
    endif
    return true
enddef

def Popup_callback(winid: number, result: number)
    popup_id = 0
    prop_remove({type: 'qf-popup', all: true})
enddef

# 'xlist': quickfix or location list
#
# 'items': which quickfix items to display in popup window
#     'all'     - display all items in current line
#     'current' - display only item(s) in current line+column (exact match)
#     'closest' - display item(s) closest to current column
def Filter_items(xlist: list<any>, items: string): list<number>
    if empty(xlist)
        return []
    endif

    if items == 'all'
        return xlist
            ->len()
            ->range()
            ->filter((_, i: number): bool => xlist[i].bufnr == bufnr())
            ->filter((_, i: number): bool => xlist[i].lnum == line('.'))
    elseif items == 'current'
        return xlist
            ->len()
            ->range()
            ->filter((_, i: number): bool => xlist[i].bufnr == bufnr())
            ->filter((_, i: number): bool => xlist[i].lnum == line('.'))
            ->filter((_, i: number): bool => xlist[i].col == col('.') || xlist[i].col == col('.') + 1 && xlist[i].col == col('$'))
    elseif items == 'closest'
        var idxs: list<number> = xlist
            ->len()
            ->range()
            ->filter((_, i: number): bool => xlist[i].bufnr == bufnr())
            ->filter((_, i: number): bool => xlist[i].lnum == line('.'))

        if empty(idxs)
            return []
        endif

        var min: number = col('$')
        var delta: number
        var col: number

        for i in idxs
            delta = abs(col('.') - xlist[i].col)
            if delta <= min
                min = delta
                col = xlist[i].col
            endif
        endfor

        return filter(idxs, (_, i: number): bool => xlist[i].col == col)
    endif
    return []
enddef

export def Show(loclist: bool): number
    const qf: dict<any> = loclist
        ? getloclist(0, {id: 0, items: 0})
        : getqflist({id: 0, items: 0})
    const xlist: list<any> = qf.items

    if empty(xlist)
        return 0
    endif

    const items: string = config.Getopt('popup_items')
    const idxs: list<number> = Filter_items(xlist, items)

    if empty(idxs)
        return 0
    endif

    var text: list<string> = []
    var longtype: string

    for i in idxs
        if empty(xlist[i].type)
            extend(text, $'({i + 1}/{len(xlist)}) {xlist[i].lnum}:{xlist[i].col} {trim(xlist[i].text)}'->split('\n'))
        else
            longtype = get(typename, toupper(xlist[i].type), xlist[i].type)
            if xlist[i].nr < 1
                extend(text, $'({i + 1}/{len(xlist)}) {xlist[i].lnum}:{xlist[i].col} {longtype}: {trim(xlist[i].text)}'->split('\n'))
            else
                extend(text, $'({i + 1}/{len(xlist)}) {xlist[i].lnum}:{xlist[i].col} {longtype} {xlist[i].nr}: {trim(xlist[i].text)}'->split('\n'))
            endif
        endif
    endfor

    # Maximum width for popup window
    const max: number = config.Getopt('popup_maxwidth')
    const textwidth: number = max > 0
        ? max
        : text
            ->len()
            ->range()
            ->map((_, i: number): number => strdisplaywidth(text[i]))
            ->max()

    const border: list<number> = config.Getopt('popup_border')
    const pad: number = get(border, 1, 1) + get(border, 3, 1) + 3
    const width: number = textwidth + pad > &columns ? &columns - pad : textwidth

    # Column position for popup window
    const pos: dict<number> = screenpos(win_getid(), line('.'), items == 'closest' ? xlist[idxs[0]].col : col('.'))
    const col: number = &columns - pos.curscol <= width ? &columns - width - 1 : pos.curscol

    var opts: dict<any> = {
        moved: 'any',
        col: col,
        minwidth: width,
        maxwidth: width,
        maxheight: config.Getopt('popup_maxheight'),
        padding: [0, 1, 0, 1],
        border: border,
        borderchars: config.Getopt('popup_borderchars'),
        borderhighlight: ['QfDiagnosticsBorder'],
        highlight: 'QfDiagnostics',
        scrollbarhighlight: 'QfDiagnosticsScrollbar',
        thumbhighlight: 'QfDiagnosticsThumb',
        firstline: 1,
        mapping: config.Getopt('popup_mapping'),
        filtermode: 'n',
        filter: Popup_filter,
        callback: Popup_callback
    }

    popup_close(popup_id)

    if config.Getopt('popup_attach')
        prop_remove({type: 'qf-popup', all: true})
        prop_add(line('.'),
            items == 'closest' ? (xlist[idxs[0]].col > 0 ? xlist[idxs[0]].col : col('.')) : col('.'),
            {type: 'qf-popup'}
        )
        extend(opts, {
            textprop: 'qf-popup',
            pos: 'botleft',
            line: 0,
            col: col - pos.curscol,
        })
    endif

    popup_id = popup_atcursor(text, opts)
    setwinvar(popup_id, '&breakindent', 1)
    setwinvar(popup_id, '&tabstop', &g:tabstop)

    matchadd('QfDiagnosticsItemNr',  '^(\d\+/\d\+)',                                               10, -1, {window: popup_id})
    matchadd('QfDiagnosticsLineNr',  '^(\d\+/\d\+) \zs\d\+\%(:\d\+\)\?',                           10, -1, {window: popup_id})
    matchadd('QfDiagnosticsError',   '^(\d\+/\d\+) \d\+\%(:\d\+\)\? \zs\<error\>\%(:\| \d\+:\)',   10, -1, {window: popup_id})
    matchadd('QfDiagnosticsWarning', '^(\d\+/\d\+) \d\+\%(:\d\+\)\? \zs\<warning\>\%(:\| \d\+:\)', 10, -1, {window: popup_id})
    matchadd('QfDiagnosticsInfo',    '^(\d\+/\d\+) \d\+\%(:\d\+\)\? \zs\<info\>\%(:\| \d\+:\)',    10, -1, {window: popup_id})
    matchadd('QfDiagnosticsNote',    '^(\d\+/\d\+) \d\+\%(:\d\+\)\? \zs\<note\>\%(:\| \d\+:\)',    10, -1, {window: popup_id})
    config.Getopt('popup_create_cb')(popup_id, qf.id, loclist)

    return popup_id
enddef
