vim9script
# ==============================================================================
# Display quickfix errors in popup window and sign column
# File:         autoload/qfdiagnostics.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-qf-diagnostics
# Last Change:  Nov 20, 2022
# License:      Same as Vim itself (see :h license)
# ==============================================================================

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

var popup_id: number = 0

const defaults: dict<any> = {
    popup_create_cb: (_, _, _) => 0,
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
    sign_other:   {text: '?', priority: 10, texthl: 'Normal'}
}

# Cache current quickfix list: {'id': 2, 'changedtick': 1, 'items': [...]}
var curlist: dict<any> = {}

# Look-up table used for popup window to display nice text instead of error
# character
const typename: dict<string> = {E: 'error', W: 'warning', I: 'info', N: 'note'}

# Look-up table used for sign names
const signname: dict<string> = {
    E: 'qf-error',
    W: 'qf-warning',
    I: 'qf-info',
    N: 'qf-note',
   '': 'qf-other'
}

# Look-up table used for text-property types for text-highlightings
const texttype: dict<string> = {
    E: 'qf-text-error',
    W: 'qf-text-warning',
    I: 'qf-text-info',
    N: 'qf-text-note',
   '': 'qf-text-other'
}

# Dictionary with (ID, 1) pairs for every placed quickfix/location-list,
# quickfix list has ID=0, for location lists we use window-IDs
var sign_placed_ids: dict<number> = {}

# Similar to sign groups we use different text-property IDs so that quickfix and
# location-list errors can be removed individually. For quickfix errors the IDs
# are set to 0, and for location-list errors the IDs are set to the window-ID of
# the window the location-list belongs to.
# Dictionary of (ID, bufnr-items):
# {
#   '0': {
#       bufnr_1: [{'type': 'qf-text-error', 'lnum': 10, 'col': 19}, {...}, ...],
#       bufnr_2: [{'type': 'qf-text-info',  'lnum': 13, 'col': 19}, {...}, ...],
#       ...
#   },
#   '1001': {...}
# }
var prop_items: dict<dict<list<any>>> = {}

def Getopt(x: string): any
    return get(g:, 'qfdiagnostics', {})->get(x, defaults[x])
enddef

prop_type_add('qf-popup', {})
prop_type_add('qf-text-error',   Getopt('text_error'))
prop_type_add('qf-text-warning', Getopt('text_warning'))
prop_type_add('qf-text-info',    Getopt('text_info'))
prop_type_add('qf-text-note',    Getopt('text_note'))
prop_type_add('qf-text-other',   Getopt('text_other'))

def Sign_priorities(): dict<number>
    return {
        E: Getopt('sign_error')->get('priority', 14),
        W: Getopt('sign_warning')->get('priority', 13),
        I: Getopt('sign_info')->get('priority', 12),
        N: Getopt('sign_note')->get('priority', 11),
       '': Getopt('sign_other')->get('priority', 10)
    }
enddef

# Place quickfix and location-list errors under different sign groups so that
# they can be toggled separately in the sign column. Quickfix errors are placed
# under the qf-0 group, and location-list errors under qf-WINID, where WINID is
# the window-ID of the window the location-list belongs to.
def Sign_group(group_id: number): string
    return $'qf-{group_id}'
enddef

def Group_id(loclist: bool): number
    if loclist
        return win_getid()->getwininfo()[0].loclist
            ? getloclist(0, {filewinid: 0}).filewinid
            : win_getid()
    endif
    return 0
enddef

def Props_placed(group_id: number): bool
    return has_key(prop_items, group_id)
enddef

def Signs_placed(group_id: number): bool
    return has_key(sign_placed_ids, group_id)
enddef

def Popup_filter(winid: number, key: string): bool
    if line('$', winid) == popup_getpos(winid).core_height
        return false
    endif
    popup_setoptions(winid, {minheight: popup_getpos(winid).core_height})

    if key == Getopt('popup_scrolldown')
        const line: number = popup_getoptions(winid).firstline
        const newline: number = line < line('$', winid) ? (line + 1) : line('$', winid)
        popup_setoptions(winid, {firstline: newline})
    elseif key == Getopt('popup_scrollup')
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

def Getxlist(loclist: bool): list<any>
    const Xgetlist: func = loclist ? function('getloclist', [0]) : function('getqflist')
    const qf: dict<number> = Xgetlist({changedtick: 0, id: 0})

    # Note: 'changedtick' of a quickfix list is not incremented when a buffer
    # referenced in the list is wiped out
    if get(curlist, 'id', -1) == qf.id && get(curlist, 'changedtick') == qf.changedtick
        return curlist.items
    endif

    curlist = Xgetlist({changedtick: 0, id: 0, items: 0})
    return curlist.items
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

def Add_textprops_on_bufread()
    const bufnr: number = expand('<abuf>')->str2nr()
    var max: number
    var col: number
    var end_max: number
    var end_col: number

    for id in keys(prop_items)
        for item in get(prop_items[id], bufnr, [])
            max = getbufline(bufnr, item.lnum)[0]->strlen()

            # Sanity check if bufline is empty
            if max == 0
                continue
            endif

            col = item.col >= max ? max : item.col
            end_col = item.end_col >= max ? max : item.end_col
            if item.end_col > 0
                end_max = item.end_lnum > 0 && item.end_lnum != item.lnum
                    ? getbufline(bufnr, item.end_lnum)[0]->strlen() + 1
                    : max + 1
                end_col = item.end_col >= end_max ? end_max : item.end_col
            else
                end_col = col + 1
            endif

            prop_add(item.lnum, col, {
                end_lnum: item.end_lnum > 0 ? item.end_lnum : item.lnum,
                end_col: item.end_col > 0 ? item.end_col : item.col + 1,
                bufnr: bufnr,
                id: str2nr(id),
                type: item.type
            })
        endfor
    endfor
enddef

def Add_textprops(xlist: list<any>, group_id: number)
    prop_items[group_id] = {}
    final bufs: dict<list<any>> = prop_items[group_id]
    var prop_type: string
    var max: number
    var col: number
    var end_max: number
    var end_col: number

    for i in xlist
        if i.bufnr < 1 || i.lnum < 1 || i.col < 1 || !i.valid || !bufexists(i.bufnr)
            continue
        endif

        if !has_key(bufs, i.bufnr)
            bufs[i.bufnr] = []
        endif

        prop_type = get(texttype, toupper(i.type), texttype[''])
        add(bufs[i.bufnr], {
            type: prop_type,
            lnum: i.lnum,
            col: i.col,
            end_lnum: i.end_lnum,
            end_col: i.end_col
        })

        if bufloaded(i.bufnr)
            max = getbufline(i.bufnr, i.lnum)[0]->strlen()

            # Sanity check if bufline is empty
            if max == 0
                continue
            endif

            col = i.col >= max ? max : i.col
            end_col = i.end_col >= max ? max : i.end_col
            if i.end_col > 0
                end_max = i.end_lnum > 0 && i.end_lnum != i.lnum
                    ? getbufline(i.bufnr, i.end_lnum)[0]->strlen() + 1
                    : max + 1
                end_col = i.end_col >= end_max ? end_max : i.end_col
            else
                end_col = col + 1
            endif

            prop_add(i.lnum, col, {
                end_lnum: i.end_lnum > 0 ? i.end_lnum : i.lnum,
                end_col: end_col,
                bufnr: i.bufnr,
                id: group_id,
                type: prop_type
            })
        endif
    endfor

    autocmd_add([{
        group: 'qf-diagnostics',
        event: 'BufReadPost',
        pattern: '*',
        replace: true,
        cmd: 'Add_textprops_on_bufread()'
    }])
enddef

def Remove_textprops(group_id: number)
    if !Props_placed(group_id)
        return
    endif

    var bufnr: number
    for i in prop_items->get(group_id)->keys()
        bufnr = str2nr(i)
        if bufexists(bufnr)
            prop_remove({
                id: group_id,
                types: ['qf-text-error', 'qf-text-warning', 'qf-text-info', 'qf-text-note', 'qf-text-other'],
                bufnr: bufnr,
                both: true,
                all: true
            })
        endif
    endfor

    remove(prop_items, group_id)
    if empty(prop_items)
        autocmd_delete([{group: 'qf-diagnostics', event: 'BufReadPost'}])
    endif
enddef

def Add_signs(xlist: list<any>, group_id: number)
    const priorities: dict<number> = Sign_priorities()
    const group: string = Sign_group(group_id)
    sign_placed_ids[group_id] = 1

    xlist
        ->copy()
        ->filter((_, i: dict<any>) => i.bufnr > 0 && bufexists(i.bufnr) && i.valid && i.lnum > 0)
        ->map((_, i: dict<any>) => ({
            lnum: i.lnum,
            buffer: i.bufnr,
            group: group,
            priority: get(priorities, toupper(i.type), priorities['']),
            name: get(signname, toupper(i.type), signname[''])
        }))
        ->sign_placelist()
enddef

def Remove_signs(group_id: number)
    if !Signs_placed(group_id)
        return
    endif
    group_id->Sign_group()->sign_unplace()
    remove(sign_placed_ids, group_id)
enddef

def Remove_on_winclosed()
    const winid: number = expand('<amatch>')->str2nr()
    Remove_signs(winid)
    Remove_textprops(winid)
enddef

export def Place(loclist: bool)
    if !Getopt('signs') && !Getopt('texthl')
        return
    endif

    const xlist: list<any> = Getxlist(loclist)
    const group_id: number = Group_id(loclist)
    Remove_textprops(group_id)
    Remove_signs(group_id)

    if empty(xlist)
        return
    endif

    if Getopt('texthl')
        prop_type_change('qf-text-error',   Getopt('text_error'))
        prop_type_change('qf-text-warning', Getopt('text_warning'))
        prop_type_change('qf-text-info',    Getopt('text_info'))
        prop_type_change('qf-text-note',    Getopt('text_note'))
        prop_type_change('qf-text-other',   Getopt('text_other'))
        Add_textprops(xlist, group_id)
    endif

    if Getopt('signs')
        sign_define('qf-error',   Getopt('sign_error'))
        sign_define('qf-warning', Getopt('sign_warning'))
        sign_define('qf-info',    Getopt('sign_info'))
        sign_define('qf-note',    Getopt('sign_note'))
        sign_define('qf-other',   Getopt('sign_other'))
        Add_signs(xlist, group_id)
    endif

    if loclist
        autocmd_add([{
            group: 'qf-diagnostics',
            event: 'WinClosed',
            pattern: string(group_id),
            replace: true,
            once: true,
            cmd: 'Remove_on_winclosed()'
        }])
    endif
enddef

export def Cclear()
    Remove_signs(0)
    Remove_textprops(0)
enddef

export def Lclear(bang: bool)
    if bang
        var id: number
        for i in keys(sign_placed_ids)
            id = str2nr(i)
            if id != 0
                Remove_signs(id)
            endif
        endfor
        for i in keys(prop_items)
            id = str2nr(i)
            if id != 0
                Remove_textprops(id)
            endif
        endfor
        autocmd_delete([{group: 'qf-diagnostics', event: 'WinClosed'}])
    else
        const group_id: number = Group_id(true)
        Remove_signs(group_id)
        Remove_textprops(group_id)
        autocmd_delete([{
            group: 'qf-diagnostics',
            event: 'WinClosed',
            pattern: string(group_id)
        }])
    endif
enddef

export def Toggle(loclist: bool)
    const group_id: number = Group_id(loclist)
    if !Signs_placed(group_id) && !Props_placed(group_id)
        Place(loclist)
        return
    endif
    Remove_signs(group_id)
    Remove_textprops(group_id)
    if loclist
        autocmd_delete([{
            group: 'qf-diagnostics',
            event: 'WinClosed',
            pattern: string(group_id)
        }])
    endif
enddef

export def Popup(loclist: bool): number
    const xlist: list<any> = Getxlist(loclist)

    if empty(xlist)
        return 0
    endif

    const items: string = Getopt('popup_items')
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
    const max: number = Getopt('popup_maxwidth')
    const textwidth: number = max > 0
        ? max
        : text
            ->len()
            ->range()
            ->map((_, i: number): number => strdisplaywidth(text[i]))
            ->max()

    const border: list<number> = Getopt('popup_border')
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
        maxheight: Getopt('popup_maxheight'),
        padding: [0, 1, 0, 1],
        border: border,
        borderchars: Getopt('popup_borderchars'),
        borderhighlight: ['QfDiagnosticsBorder'],
        highlight: 'QfDiagnostics',
        scrollbarhighlight: 'QfDiagnosticsScrollbar',
        thumbhighlight: 'QfDiagnosticsThumb',
        firstline: 1,
        mapping: Getopt('popup_mapping'),
        filtermode: 'n',
        filter: Popup_filter,
        callback: Popup_callback
    }

    popup_close(popup_id)

    if Getopt('popup_attach')
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
    Getopt('popup_create_cb')(popup_id, curlist.id, loclist)

    return popup_id
enddef
