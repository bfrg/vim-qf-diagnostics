vim9script
# ==============================================================================
# Highlight quickfix errors and show error messages in popup window
# File:         autoload/qfdiagnostics.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-qf-diagnostics
# Last Change:  Nov 22, 2022
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

# Look-up table used for text-property types for virtual text
const virttype: dict<string> = {
    E: 'qf-virt-error',
    W: 'qf-virt-warning',
    I: 'qf-virt-info',
    N: 'qf-virt-note',
   '': 'qf-virt-other'
}

# Cached quickfix and location lists (for each window), accessed by 0 (quickfix)
# and window ID (location-list)
#
#   {
#       0: {
#           id: 2,
#           changedtick: 4,
#           items: [ getqflist()->filter() … ]
#       },
#       1001: {…}
#   }
#
var qfs: dict<dict<any>> = {}

# Quickfix and location-lists grouped by buffer numbers. Each list stores the
# indexes in the original list, like qfs[0].items
#
#   {
#       0: {
#           bufnr_1: [0, 1, 2],
#           bufnr_2: [3],
#           bufnr_3: [4, 5],
#           …
#       },
#       1001: {…}
#   }
#
var buffers: dict<dict<list<number>>> = {}

# Boolean indicating whether signs have been placed for a quickfix and/or
# location list
#
#   {
#       0: true,
#       1001: false,
#   }
#
var signs_added: dict<bool> = {}

# Boolean indicating whether text-highlighting has been added for a list
#
#   {
#       0: true,
#       1001: false,
#   }
#
var texthl_added: dict<bool> = {}

# Cached virtual-text IDs for each list
#
#   {
#       0: {
#           bufnr_1: [-1, -2, -3],
#           bufnr_2: [-1],
#           bufnr_3: [-1, -2],
#           …
#       },
#       1001: {…}
#   }
var virt_IDs: dict<dict<list<number>>> = {}

# Boolean indicating whether virtual text has been added for a list
#
#   {
#       0: true,
#       1001: false,
#   }
#
var virttext_added: dict<bool> = {}

# virtual-text 'align' option for each list, i.e. it is possible to have
# different 'align' for quickfix and each location list
#
#   {
#       0: 'right',
#       1001: 'below',
#   }
#
var virttext_align: dict<string> = {}

def Getopt(x: string): any
    return get(g:, 'qfdiagnostics', {})->get(x, defaults[x])
enddef

prop_type_add('qf-popup', {})
prop_type_add('qf-text-error',   Getopt('text_error'))
prop_type_add('qf-text-warning', Getopt('text_warning'))
prop_type_add('qf-text-info',    Getopt('text_info'))
prop_type_add('qf-text-note',    Getopt('text_note'))
prop_type_add('qf-text-other',   Getopt('text_other'))
prop_type_add('qf-virt-error',   Getopt('virt_error'))
prop_type_add('qf-virt-warning', Getopt('virt_warning'))
prop_type_add('qf-virt-info',    Getopt('virt_info'))
prop_type_add('qf-virt-note',    Getopt('virt_note'))
prop_type_add('qf-virt-other',   Getopt('virt_other'))

def Sign_priorities(): dict<number>
    return {
        E: Getopt('sign_error')->get('priority', 14),
        W: Getopt('sign_warning')->get('priority', 13),
        I: Getopt('sign_info')->get('priority', 12),
        N: Getopt('sign_note')->get('priority', 11),
       '': Getopt('sign_other')->get('priority', 10)
    }
enddef

def Virttext_prefix(): dict<string>
    return {
        E: Getopt('virt_error')->get('prefix', ''),
        W: Getopt('virt_warning')->get('prefix', ''),
        I: Getopt('virt_info')->get('prefix', ''),
        N: Getopt('virt_note')->get('prefix', ''),
       '': Getopt('virt_other')->get('prefix', '')
    }
enddef

# Group quickfix list 'items' by buffer number
def Group_by_bufnr(items: list<dict<any>>): dict<list<number>>
    final bufgroups: dict<list<number>> = {}

    for [idx: number, item: dict<any>] in items(items)
        if !has_key(bufgroups, item.bufnr)
            bufgroups[item.bufnr] = []
        endif
        add(bufgroups[item.bufnr], idx)
    endfor

    return bufgroups
enddef

# Quickfix and location-list errors are placed under different sign groups so
# that signs can be toggled separately in the sign column. Quickfix errors are
# placed under the qf-0 group, and location-list errors under qf-WINID, where
# WINID is the window-ID of the window the location-list belongs to.
def Sign_group(group: number): string
    return $'qf-{group}'
enddef

def Group_id(loclist: bool): number
    if loclist
        return win_getid()->getwininfo()[0].loclist
            ? getloclist(0, {filewinid: 0}).filewinid
            : win_getid()
    endif
    return 0
enddef

def Signs_added(group: number): bool
    return get(signs_added, group, false)
enddef

def Texthl_added(group: number): bool
    return get(texthl_added, group, false)
enddef

def Virttext_added(group: number): bool
    return get(virttext_added, group, false)
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

def Texthl_add(bufnr: number, group: number, maxlnum: number)
    const items: list<dict<any>> = qfs[group].items
    var max: number
    var end_max: number
    var col: number
    var end_col: number

    for idx in buffers[group][bufnr]
        const item: dict<any> = items[idx]
        max = bufnr->getbufline(item.lnum)[0]->strlen()

        # Sanity checks (should we call prop_add() inside a try/catch? block)
        if max == 0 || item.lnum > maxlnum
            continue
        endif

        col = item.col < max ? item.col : max
        if item.end_col > 0
            end_max = item.end_lnum > 0 && item.end_lnum != item.lnum
                ? bufnr->getbufline(item.end_lnum)[0]->strlen() + 1
                : max + 1
            end_col = item.end_col < end_max ? item.end_col : end_max
        else
            end_col = col + 1
        endif

        prop_add(item.lnum, col, {
            type: get(texttype, toupper(item.type), texttype['']),
            bufnr: bufnr,
            id: group,
            end_lnum: item.end_lnum > 0 ? item.end_lnum : item.lnum,
            end_col: end_col
        })
    endfor
enddef

def Virttext_add(bufnr: number, group: number, maxlnum: number)
    const items: list<dict<any>> = qfs[group].items
    const text_align: string = virttext_align[group]
    const prefix: dict<string> = Virttext_prefix()
    const padding: number = Getopt('virt_padding')
    var virtid: number

    # We need to reset virtual-text IDs here because when a buffer is unloaded,
    # for example, after :edit, the buffer is freed and text-properties are
    # removed, The old cached virtual-text IDs are not valid anymore.
    virt_IDs[group][bufnr] = []

    for idx in buffers[group][bufnr]
        const item: dict<any> = items[idx]

        # Sanity checks (should we call prop_add() inside a try/catch? block)
        if item.lnum > maxlnum
            continue
        endif

        virtid = prop_add(item.lnum, 0, {
            type: get(virttype, toupper(item.type), virttype['']),
            bufnr: bufnr,
            text: prefix[toupper(item.type)] .. item.text->split('\n')[0]->trim(),
            text_align: text_align,
            text_padding_left: text_align == 'below' || text_align == 'above' ? indent(item.lnum) : padding,
        })

        # Save the text-prop ID for later when removing virtual text
        add(virt_IDs[group][bufnr], virtid)
    endfor
enddef

# Add text-properties to 'bufnr' using the items stored in 'group'
def Props_add(bufnr: number, group: number, maxlnum: number)
    if Getopt('virttext')
        Virttext_add(bufnr, group, maxlnum)
    endif

    if Getopt('texthl')
        Texthl_add(bufnr, group, maxlnum)
    endif
enddef

def Texthl_remove(group: number)
    for bufnr in keys(buffers[group])
        if bufnr->str2nr()->bufexists()
            prop_remove({
                id: group,
                bufnr: str2nr(bufnr),
                types: ['qf-text-error', 'qf-text-warning', 'qf-text-info', 'qf-text-note', 'qf-text-other'],
                both: true,
                all: true
            })
        endif
    endfor
    remove(texthl_added, group)
enddef

def Virttext_remove(group: number)
    for bufnr in keys(virt_IDs[group])
        if !bufnr->str2nr()->bufexists()
            continue
        endif
        for id in virt_IDs[group][bufnr]
            prop_remove({
                id: id,
                bufnr: str2nr(bufnr),
                types: ['qf-virt-error', 'qf-virt-warning', 'qf-virt-info', 'qf-virt-note', 'qf-virt-other'],
                both: true,
                all: true
            })
        endfor
    endfor
    remove(virttext_added, group)
    remove(virttext_align, group)
    remove(virt_IDs, group)
enddef

def Props_remove(group: number)
    if !has_key(qfs, group)
        return
    endif

    if Virttext_added(group)
        Virttext_remove(group)
    endif

    if Texthl_added(group)
        Texthl_remove(group)
    endif

    # Remove cached data for 'group'
    remove(qfs, group)
    remove(buffers, group)

    if empty(qfs)
        autocmd_delete([
            {group: 'qf-diagnostics', event: 'BufWinEnter'},
            {group: 'qf-diagnostics', event: 'BufReadPost'}
        ])
    endif
enddef

def Signs_add(group: number)
    const priorities: dict<number> = Sign_priorities()
    const signgroup: string = Sign_group(group)

    qfs[group].items
        ->mapnew((_, i: dict<any>): dict<any> => ({
            lnum: i.lnum,
            buffer: i.bufnr,
            group: signgroup,
            priority: get(priorities, toupper(i.type), priorities['']),
            name: get(signname, toupper(i.type), signname[''])
        }))
        ->sign_placelist()

    signs_added[group] = true
enddef

def Signs_remove(group: number)
    if !Signs_added(group)
        return
    endif
    group->Sign_group()->sign_unplace()
    remove(signs_added, group)
enddef

# Re-apply text-properties to a buffer that was reloaded with ':edit'. Since we
# are postponing adding text-properties until the buffer is displayed in a
# window, we return when the buffer isn't displayed in a window. For example,
# when we call bufload(bufnr), BufRead is triggered but we don't want to add
# text-properties until BufWinEnter is triggered. Is this good?
def On_bufread()
    const bufnr: number = expand('<abuf>')->str2nr()
    const wins: list<number> = win_findbuf(bufnr)

    if empty(wins)
        return
    endif

    for group in keys(virt_IDs)
        if has_key(virt_IDs[group], bufnr)
            Props_add(bufnr, str2nr(group), line('$', wins[0]))
        endif
    endfor
enddef

# We add text-properties to the buffer only after it's displayed in a window
#
# TODO:
# - Should we check quickfix's 'changedtick', and if it changed, get new
#   quickfix list, re-group items, and delete old text-properties before adding
#   new ones?
# - Check if quickfix list with given quickfix-ID still exists, if it doesn't,
#   we need to remove ALL text-properties, and don't add new ones
#
def On_bufwinenter()
    const bufnr: number = expand('<abuf>')->str2nr()
    const wins: list<number> = win_findbuf(bufnr)
    for group in keys(virt_IDs)
        # If no text-property IDs saved for a buffer, virtual text hasn't been
        # added yet
        if has_key(virt_IDs[group], bufnr) && empty(virt_IDs[group][bufnr])
            Props_add(bufnr, str2nr(group), line('$', wins[0]))
        endif
    endfor
enddef

# When a window is closed, remove all text-properties and signs that were added
# from a location list, and delete all data stored for that window
def On_winclosed()
    const winid: number = expand('<amatch>')->str2nr()
    Signs_remove(winid)
    Props_remove(winid)
enddef

export def Complete(arglead: string, cmdline: string, curpos: number): string
    return join(['after', 'right', 'below', 'above'], "\n")
enddef

export def Place(loclist: bool, align: string)
    if !Getopt('signs') && !Getopt('texthl') && !Getopt('virttext')
        return
    endif

    const group: number = Group_id(loclist)
    final xlist: dict<any> = loclist
        ? getloclist(0, {items: 0, id: 0, changedtick: 0})
        : getqflist({items: 0, id: 0, changedtick: 0})

    # Remove previously placed text-properties and signs
    Signs_remove(group)
    Props_remove(group)

    # Remove invalid quickfix items
    filter(xlist.items, (_, i: dict<any>): bool => !(i.lnum < 1 || !i.valid || i.bufnr < 1 || !bufexists(i.bufnr)))

    if empty(xlist.items)
        return
    endif

    qfs[group] = xlist

    if Getopt('signs')
        sign_define('qf-error',   Getopt('sign_error'))
        sign_define('qf-warning', Getopt('sign_warning'))
        sign_define('qf-info',    Getopt('sign_info'))
        sign_define('qf-note',    Getopt('sign_note'))
        sign_define('qf-other',   Getopt('sign_other'))
        Signs_add(group)
    endif

    if !Getopt('texthl') && !Getopt('virttext')
        return
    endif

    buffers[group] = Group_by_bufnr(xlist.items)
    virttext_align[group] = align ?? Getopt('virt_align')
    virt_IDs[group] = {}

    for buf in keys(buffers[group])
        virt_IDs[group][buf] = []
    endfor

    # Dictionary with buffers that are displayed in a window
    const displayed: dict<list<number>> = buffers[group]
        ->mapnew((b: string, _): list<number> => b->str2nr()->win_findbuf())
        ->filter((_, i: list<number>): bool => !empty(i))

    if Getopt('texthl')
        prop_type_change('qf-text-error',   Getopt('text_error'))
        prop_type_change('qf-text-warning', Getopt('text_warning'))
        prop_type_change('qf-text-info',    Getopt('text_info'))
        prop_type_change('qf-text-note',    Getopt('text_note'))
        prop_type_change('qf-text-other',   Getopt('text_other'))
        for [buf: string, wins: list<number>] in items(displayed)
            Texthl_add(str2nr(buf), group, line('$', wins[0]))
        endfor
        texthl_added[group] = true
    endif

    if Getopt('virttext')
        prop_type_change('qf-virt-error',   Getopt('virt_error'))
        prop_type_change('qf-virt-warning', Getopt('virt_warning'))
        prop_type_change('qf-virt-info',    Getopt('virt_info'))
        prop_type_change('qf-virt-note',    Getopt('virt_note'))
        prop_type_change('qf-virt-other',   Getopt('virt_other'))
        for [buf: string, wins: list<number>] in items(displayed)
            Virttext_add(str2nr(buf), group, line('$', wins[0]))
        endfor
        virttext_added[group] = true
    endif

    autocmd_add([
        {
            group: 'qf-diagnostics',
            event: 'BufWinEnter',
            pattern: '*',
            replace: true,
            cmd: "On_bufwinenter()"
        },
        {
            group: 'qf-diagnostics',
            event: 'BufReadPost',
            replace: true,
            pattern: '*',
            cmd: "On_bufread()"
        }
    ])

    if loclist
        autocmd_add([{
            group: 'qf-diagnostics',
            event: 'WinClosed',
            pattern: string(group),
            replace: true,
            once: true,
            cmd: 'On_winclosed()'
        }])
    endif
enddef

export def Cclear()
    Signs_remove(0)
    Props_remove(0)
enddef

export def Lclear(bang: bool)
    if bang
        var id: number
        for i in keys(qfs)
            id = str2nr(i)
            if id != 0
                Signs_remove(id)
            endif
        endfor
        for i in keys(qfs)
            id = str2nr(i)
            if id != 0
                Props_remove(id)
            endif
        endfor
        autocmd_delete([{group: 'qf-diagnostics', event: 'WinClosed'}])
    else
        const group: number = Group_id(true)
        Signs_remove(group)
        Props_remove(group)
        autocmd_delete([{
            group: 'qf-diagnostics',
            event: 'WinClosed',
            pattern: string(group)
        }])
    endif
enddef

export def Toggle(loclist: bool, align: string)
    const group: number = Group_id(loclist)

    if !Signs_added(group) && !Texthl_added(group) && !Virttext_added(group)
        Place(loclist, align)
        return
    endif

    Signs_remove(group)
    Props_remove(group)

    if loclist
        autocmd_delete([{
            group: 'qf-diagnostics',
            event: 'WinClosed',
            pattern: string(group)
        }])
    endif
enddef

export def Popup(loclist: bool): number
    const qf: dict<any> = loclist
        ? getloclist(0, {id: 0, items: 0})
        : getqflist({id: 0, items: 0})
    const xlist: list<any> = qf.items

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
    Getopt('popup_create_cb')(popup_id, qf.id, loclist)

    return popup_id
enddef
