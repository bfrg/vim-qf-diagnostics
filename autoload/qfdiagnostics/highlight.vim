vim9script
# ==============================================================================
# Highlight quickfix errors and show error messages in popup window
# File:         autoload/qfdiagnostics/highlight.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-qf-diagnostics
# Last Change:  Nov 25, 2022
# License:      Same as Vim itself (see :h license)
# ==============================================================================

import './config.vim'

prop_type_add('qf-text-error',   config.Getopt('text_error'))
prop_type_add('qf-text-warning', config.Getopt('text_warning'))
prop_type_add('qf-text-info',    config.Getopt('text_info'))
prop_type_add('qf-text-note',    config.Getopt('text_note'))
prop_type_add('qf-text-other',   config.Getopt('text_other'))
prop_type_add('qf-virt-error',   config.Getopt('virt_error'))
prop_type_add('qf-virt-warning', config.Getopt('virt_warning'))
prop_type_add('qf-virt-info',    config.Getopt('virt_info'))
prop_type_add('qf-virt-note',    config.Getopt('virt_note'))
prop_type_add('qf-virt-other',   config.Getopt('virt_other'))

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

def Sign_priorities(): dict<number>
    return {
        E: config.Getopt('sign_error')->get('priority', 14),
        W: config.Getopt('sign_warning')->get('priority', 13),
        I: config.Getopt('sign_info')->get('priority', 12),
        N: config.Getopt('sign_note')->get('priority', 11),
       '': config.Getopt('sign_other')->get('priority', 10)
    }
enddef

def Virttext_prefix(): dict<string>
    return {
        E: config.Getopt('virt_error')->get('prefix', ''),
        W: config.Getopt('virt_warning')->get('prefix', ''),
        I: config.Getopt('virt_info')->get('prefix', ''),
        N: config.Getopt('virt_note')->get('prefix', ''),
       '': config.Getopt('virt_other')->get('prefix', '')
    }
enddef

# Group quickfix list 'items' by buffer number
def Group_by_bufnr(items: list<dict<any>>): dict<list<number>>
    final bufgroups: dict<list<number>> = {}
    var idx: number = -1

    for i in items
        ++idx
        if !has_key(bufgroups, i.bufnr)
            bufgroups[i.bufnr] = []
        endif
        add(bufgroups[i.bufnr], idx)
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
        if item.col == 0 || max == 0 || item.lnum > maxlnum
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
    const padding: number = config.Getopt('virt_padding')
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
    if config.Getopt('virttext')
        Virttext_add(bufnr, group, maxlnum)
    endif

    if config.Getopt('texthl')
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

export def Place(loclist: bool)
    if !config.Getopt('signs') && !config.Getopt('texthl') && !config.Getopt('virttext')
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

    if config.Getopt('signs')
        sign_define('qf-error',   config.Getopt('sign_error'))
        sign_define('qf-warning', config.Getopt('sign_warning'))
        sign_define('qf-info',    config.Getopt('sign_info'))
        sign_define('qf-note',    config.Getopt('sign_note'))
        sign_define('qf-other',   config.Getopt('sign_other'))
        Signs_add(group)
    endif

    if !config.Getopt('texthl') && !config.Getopt('virttext')
        return
    endif

    buffers[group] = Group_by_bufnr(xlist.items)
    virttext_align[group] = config.Getopt('virt_align')
    virt_IDs[group] = {}

    for buf in keys(buffers[group])
        virt_IDs[group][buf] = []
    endfor

    # Dictionary with buffers that are displayed in a window
    const displayed: dict<list<number>> = buffers[group]
        ->mapnew((b: string, _): list<number> => b->str2nr()->win_findbuf())
        ->filter((_, i: list<number>): bool => !empty(i))

    if config.Getopt('texthl')
        prop_type_change('qf-text-error',   config.Getopt('text_error'))
        prop_type_change('qf-text-warning', config.Getopt('text_warning'))
        prop_type_change('qf-text-info',    config.Getopt('text_info'))
        prop_type_change('qf-text-note',    config.Getopt('text_note'))
        prop_type_change('qf-text-other',   config.Getopt('text_other'))
        for [buf: string, wins: list<number>] in items(displayed)
            Texthl_add(str2nr(buf), group, line('$', wins[0]))
        endfor
        texthl_added[group] = true
    endif

    if config.Getopt('virttext')
        prop_type_change('qf-virt-error',   config.Getopt('virt_error'))
        prop_type_change('qf-virt-warning', config.Getopt('virt_warning'))
        prop_type_change('qf-virt-info',    config.Getopt('virt_info'))
        prop_type_change('qf-virt-note',    config.Getopt('virt_note'))
        prop_type_change('qf-virt-other',   config.Getopt('virt_other'))
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

export def Toggle(loclist: bool)
    const group: number = Group_id(loclist)

    if !Signs_added(group) && !Texthl_added(group) && !Virttext_added(group)
        Place(loclist)
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

export def Debug(): dict<any>
    return {
        qfs: deepcopy(qfs),
        buffers: deepcopy(buffers),
        signs: deepcopy(signs_added),
        texthl: deepcopy(texthl_added),
        virt_IDs: deepcopy(virt_IDs),
        virttext: deepcopy(virttext_added),
        virt_align: deepcopy(virttext_align)
    }
enddef
