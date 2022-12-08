vim9script
# ==============================================================================
# Highlight quickfix errors and show error messages in popup window
# File:         autoload/qfdiagnostics/highlight.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-qf-diagnostics
# Last Change:  Dec 8, 2022
# License:      Same as Vim itself (see :h license)
# ==============================================================================

import './config.vim'

# Look-up table used for sign names
const signname: dict<string> = {
    E: 'qf-error',
    W: 'qf-warning',
    I: 'qf-info',
    N: 'qf-note',
   '': 'qf-other'
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

# Buffers in which text-properties have been added
#
#   {
#       0: {
#           bufnr_1: true,
#           bufnr_2: true,
#           bufnr_3: false,
#           …
#       },
#       1001: {…}
#   }
#
var buffers_added: dict<dict<bool>> = {}

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

def Prop_types_add(group: number, type: string)
    prop_type_add($'qf-{group}-{type}-error',   config.Getopt($'{type}_error'))
    prop_type_add($'qf-{group}-{type}-warning', config.Getopt($'{type}_warning'))
    prop_type_add($'qf-{group}-{type}-info',    config.Getopt($'{type}_info'))
    prop_type_add($'qf-{group}-{type}-note',    config.Getopt($'{type}_note'))
    prop_type_add($'qf-{group}-{type}-other',   config.Getopt($'{type}_other'))
enddef

def Prop_types_delete(group: number, type: string)
    prop_type_delete($'qf-{group}-{type}-error')
    prop_type_delete($'qf-{group}-{type}-warning')
    prop_type_delete($'qf-{group}-{type}-info')
    prop_type_delete($'qf-{group}-{type}-note')
    prop_type_delete($'qf-{group}-{type}-other')
enddef

def Get_prop_type(group: number, type: string, errortype: string): string
    const map: dict<string> = {
        E: $'qf-{group}-{type}-error',
        W: $'qf-{group}-{type}-warning',
        I: $'qf-{group}-{type}-info',
        N: $'qf-{group}-{type}-note',
       '': $'qf-{group}-{type}-other',
    }
    return get(map, toupper(errortype), map[''])
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
            type: Get_prop_type(group, 'text', item.type),
            bufnr: bufnr,
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

    for idx in buffers[group][bufnr]
        const item: dict<any> = items[idx]

        # Sanity checks (should we call prop_add() inside a try/catch? block)
        if item.lnum > maxlnum
            continue
        endif

        prop_add(item.lnum, 0, {
            type: Get_prop_type(group, 'virt', item.type),
            bufnr: bufnr,
            text: get(prefix, toupper(item.type), prefix['']) .. item.text->split('\n')[0]->trim(),
            text_align: text_align,
            text_padding_left: text_align == 'below' || text_align == 'above' ? indent(item.lnum) : padding,
        })
    endfor
enddef

# Add text-properties to 'bufnr' using the items stored in 'group'
def Props_add(bufnr: number, group: number, maxlnum: number)
    if config.Getopt('virttext') || config.Getopt('texthl')
        buffers_added[group][bufnr] = true
    endif

    if config.Getopt('virttext')
        Virttext_add(bufnr, group, maxlnum)
    endif

    if config.Getopt('texthl')
        Texthl_add(bufnr, group, maxlnum)
    endif
enddef

def Props_remove_list(group: number, type: string)
    for bufnr in keys(buffers[group])
        if bufnr->str2nr()->bufexists()
            prop_remove({
                bufnr: str2nr(bufnr),
                types: [
                    $'qf-{group}-{type}-error',
                    $'qf-{group}-{type}-warning',
                    $'qf-{group}-{type}-info',
                    $'qf-{group}-{type}-note',
                    $'qf-{group}-{type}-other'
                ],
                all: true
            })
        endif
    endfor
    Prop_types_delete(group, type)
enddef

def Props_remove(group: number)
    if !has_key(qfs, group)
        return
    endif

    if Virttext_added(group)
        Props_remove_list(group, 'virt')
        remove(virttext_added, group)
        remove(virttext_align, group)
    endif

    if Texthl_added(group)
        Props_remove_list(group, 'text')
        remove(texthl_added, group)
    endif

    # Remove cached data for 'group'
    remove(qfs, group)
    remove(buffers, group)
    remove(buffers_added, group)

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

    for group in keys(buffers)
        if has_key(buffers[group], bufnr)
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
    for group in keys(buffers)
        if has_key(buffers[group], bufnr) && !get(buffers_added[group], bufnr, false)
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
    buffers_added[group] = {}

    for buf in keys(buffers[group])
        buffers_added[group][buf] = false
    endfor

    # Dictionary with buffers that are displayed in a window
    const displayed: dict<list<number>> = buffers[group]
        ->mapnew((b: string, _): list<number> => b->str2nr()->win_findbuf())
        ->filter((_, i: list<number>): bool => !empty(i))

    if config.Getopt('texthl')
        Prop_types_add(group, 'text')
        for [buf: string, wins: list<number>] in items(displayed)
            Texthl_add(str2nr(buf), group, line('$', wins[0]))
            buffers_added[group][buf] = true
        endfor
        texthl_added[group] = true
    endif

    if config.Getopt('virttext')
        Prop_types_add(group, 'virt')
        for [buf: string, wins: list<number>] in items(displayed)
            Virttext_add(str2nr(buf), group, line('$', wins[0]))
            buffers_added[group][buf] = true
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

export def Clear(loclist: bool, bang: bool = false)
    if loclist
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
    else
        Signs_remove(0)
        Props_remove(0)
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
        buffers_added: deepcopy(buffers_added),
        virttext: deepcopy(virttext_added),
        virt_align: deepcopy(virttext_align)
    }
enddef
