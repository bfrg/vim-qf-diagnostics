vim9script
# ==============================================================================
# Display quickfix errors in popup window and sign column
# File:         autoload/qfdiagnostics.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-qf-diagnostics
# Last Change:  June 05, 2022
# License:      Same as Vim itself (see :h license)
# ==============================================================================

highlight default link QfDiagnostics          Pmenu
highlight default link QfDiagnosticsBorder    Pmenu
highlight default link QfDiagnosticsScrollbar PmenuSbar
highlight default link QfDiagnosticsThumb     PmenuThumb
highlight default link QfDiagnosticsLineNr    Directory
highlight default link QfDiagnosticsError     ErrorMsg
highlight default link QfDiagnosticsWarning   WarningMsg
highlight default link QfDiagnosticsInfo      MoreMsg
highlight default link QfDiagnosticsNote      Todo

augroup qf-diagnostics
augroup END

var popup_winid: number = 0

const defaults: dict<any> = {
    popup_create_cb: () => 0,
    popup_scrollup: "\<c-k>",
    popup_scrolldown: "\<c-j>",
    popup_border: [0, 0, 0, 0],
    popup_maxheight: 0,
    popup_maxwidth: 0,
    popup_borderchars: [],
    popup_mapping: true,
    popup_items: 0,
    popup_attach: false,
    texthl: false,
    highlight_error:   {highlight: 'SpellBad',   priority: 14, combine: true},
    highlight_warning: {highlight: 'SpellCap',   priority: 13, combine: true},
    highlight_info:    {highlight: 'SpellLocal', priority: 12, combine: true},
    highlight_note:    {highlight: 'SpellRare',  priority: 11, combine: true},
    highlight_misc:    {highlight: 'Underlined', priority: 10, combine: true},
    signs: true,
    sign_error:   {text: 'E>', priority: 14, texthl: 'ErrorMsg'},
    sign_warning: {text: 'W>', priority: 13, texthl: 'WarningMsg'},
    sign_info:    {text: 'I>', priority: 12, texthl: 'MoreMsg'},
    sign_note:    {text: 'N>', priority: 11, texthl: 'Todo'},
    sign_misc:    {text: '?>', priority: 10, texthl: 'Normal'}
}

# Cache current quickfix list: {'id': 2, 'changedtick': 1, 'items': [...]}
var curlist: dict<any> = {}

const error_types: dict<string> = {E: 'error', W: 'warning', I: 'info', N: 'note'}

# Look-up table used for both sign names and text-property types
const sign_names: dict<string> = {
    E: 'qf-diagnostics-error',
    W: 'qf-diagnostics-warning',
    I: 'qf-diagnostics-info',
    N: 'qf-diagnostics-note',
   '': 'qf-diagnostics-misc'
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
#       bufnr_1: [{'type': 'prop-error', 'lnum': 10, 'col': 19}, {...}, ...],
#       bufnr_2: [{'type': 'prop-info',  'lnum': 13, 'col': 19}, {...}, ...],
#       ...
#   },
#   '1001': {...}
# }
var prop_items: dict<dict<list<any>>> = {}

def Get(x: string): any
    return get(g:, 'qfdiagnostics', {})->get(x, defaults[x])
enddef

silent! prop_type_add('qf-diagnostics-popup', {})
silent! prop_type_add('qf-diagnostics-error',   Get('highlight_error'))
silent! prop_type_add('qf-diagnostics-warning', Get('highlight_warning'))
silent! prop_type_add('qf-diagnostics-info',    Get('highlight_info'))
silent! prop_type_add('qf-diagnostics-note',    Get('highlight_note'))
silent! prop_type_add('qf-diagnostics-misc',    Get('highlight_misc'))

def Sign_priorities(): dict<number>
    return {
        E: Get('sign_error')->get('priority', 14),
        W: Get('sign_warning')->get('priority', 13),
        I: Get('sign_info')->get('priority', 12),
        N: Get('sign_note')->get('priority', 11),
       '': Get('sign_misc')->get('priority', 10)
    }
enddef

# Place quickfix and location-list errors under different sign groups so that
# they can be toggled separately in the sign column. Quickfix errors are placed
# under the qf-diagnostics-0 group, and location-list errors under
# qf-diagnostics-winid, where 'winid' is the window-ID of the window the
# location-list belongs to.
def Sign_group(id: number): string
    return $'qf-diagnostics-{id}'
enddef

def Id(loclist: bool): number
    if loclist
        return win_getid()->getwininfo()[0].loclist
            ? getloclist(0, {filewinid: 0}).filewinid
            : win_getid()
    endif
    return 0
enddef

def Props_placed(id: number): number
    return has_key(prop_items, id)
enddef

def Signs_placed(id: number): number
    return has_key(sign_placed_ids, id)
enddef

def Popup_filter(wid: number, key: string): bool
    if line('$', wid) == popup_getpos(wid).core_height
        return false
    endif
    popup_setoptions(wid, {minheight: popup_getpos(wid).core_height})

    if key == Get('popup_scrolldown')
        const line: number = popup_getoptions(wid).firstline
        const newline: number = line < line('$', wid) ? (line + 1) : line('$', wid)
        popup_setoptions(wid, {firstline: newline})
    elseif key == Get('popup_scrollup')
        const line: number = popup_getoptions(wid).firstline
        const newline: number = (line - 1) > 0 ? (line - 1) : 1
        popup_setoptions(wid, {firstline: newline})
    else
        return false
    endif
    return true
enddef

def Popup_callback(wid: number, result: number)
    popup_winid = 0
    prop_remove({type: 'qf-diagnostics-popup', all: true})
enddef

def Getxlist(loclist: bool): list<any>
    const Xgetlist = loclist ? function('getloclist', [0]) : function('getqflist')
    const qf: dict<number> = Xgetlist({changedtick: 0, id: 0})

    # NOTE changedtick of a quickfix list is not incremented when a buffer
    # referenced in the list is wiped out
    if get(curlist, 'id', -1) == qf.id && get(curlist, 'changedtick') == qf.changedtick
        return curlist.items
    endif

    curlist = Xgetlist({changedtick: 0, id: 0, items: 0})
    return curlist.items
enddef

# 'xlist': quickfix or location list
#
# 'items':
#     Option that specifies which quickfix items to display in the popup window
#     0 - display all items in current line
#     1 - display only item(s) in current line+column (exact match)
#     2 - display item(s) closest to current column
def Filter_items(xlist: list<any>, items: number): list<number>
    if empty(xlist)
        return []
    endif

    if !items
        return len(xlist)
            ->range()
            ->filter((_, i: number): bool => xlist[i].bufnr == bufnr())
            ->filter((_, i: number): bool => xlist[i].lnum == line('.'))
    elseif items == 1
        return len(xlist)
            ->range()
            ->filter((_, i: number): bool => xlist[i].bufnr == bufnr())
            ->filter((_, i: number): bool => xlist[i].lnum == line('.'))
            ->filter((_, i: number): bool => xlist[i].col == col('.') || xlist[i].col == col('.') + 1 && xlist[i].col == col('$'))
    elseif items == 2
        var idxs: list<number> = len(xlist)
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
    var end_col: number

    for id in keys(prop_items)
        for item in get(prop_items[id], bufnr, [])
            max = getbufline(bufnr, item.lnum)[0]->len()
            col = item.col >= max ? max : item.col
            end_col = item.end_col >= max ? max : item.end_col
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

def Add_textprops(xlist: list<any>, id: number)
    prop_items[id] = {}
    final bufs: dict<list<any>> = prop_items[id]
    var prop_type: string
    var max: number
    var col: number
    var end_col: number

    for i in xlist
        if i.bufnr > 0 && bufexists(i.bufnr) && i.valid && i.lnum > 0 && i.col > 0
            if !has_key(bufs, i.bufnr)
                bufs[i.bufnr] = []
            endif
            prop_type = get(sign_names, toupper(i.type), sign_names[''])
            add(bufs[i.bufnr], {
                type: prop_type,
                lnum: i.lnum,
                col: i.col,
                end_lnum: get(i, 'end_lnum'),
                end_col: get(i, 'end_col')
            })

            if bufloaded(i.bufnr)
                max = getbufline(i.bufnr, i.lnum)[0]->len()
                col = i.col >= max ? max : i.col
                end_col = i.end_col >= max ? max : i.end_col
                prop_add(i.lnum, col, {
                    end_lnum: i.end_lnum > 0 ? i.end_lnum : i.lnum,
                    end_col: i.end_col > 0 ? i.end_col : i.col + 1,
                    bufnr: i.bufnr,
                    id: id,
                    type: prop_type
                })
            endif
        endif
    endfor
    autocmd! qf-diagnostics BufReadPost * Add_textprops_on_bufread()
enddef

def Remove_textprops(id: number)
    if !has_key(prop_items, id)
        return
    endif

    var bufnr: number
    for i in get(prop_items, id)->keys()
        bufnr = str2nr(i)
        if bufexists(bufnr)
            prop_remove({id: id, type: 'qf-diagnostics-error',   bufnr: bufnr, both: true, all: true})
            prop_remove({id: id, type: 'qf-diagnostics-warning', bufnr: bufnr, both: true, all: true})
            prop_remove({id: id, type: 'qf-diagnostics-info',    bufnr: bufnr, both: true, all: true})
            prop_remove({id: id, type: 'qf-diagnostics-note',    bufnr: bufnr, both: true, all: true})
            prop_remove({id: id, type: 'qf-diagnostics-misc',    bufnr: bufnr, both: true, all: true})
        endif
    endfor

    remove(prop_items, id)
    if empty(prop_items)
        autocmd! qf-diagnostics BufReadPost
    endif
enddef

def Add_signs(xlist: list<any>, id: number)
    const priorities: dict<number> = Sign_priorities()
    const group: string = Sign_group(id)
    sign_placed_ids[id] = 1

    copy(xlist)
        ->filter((_, i: dict<any>) => i.bufnr > 0 && bufexists(i.bufnr) && i.valid && i.lnum > 0)
        ->map((_, i: dict<any>) => ({
          lnum: i.lnum,
          buffer: i.bufnr,
          group: group,
          priority: get(priorities, toupper(i.type), priorities['']),
          name: get(sign_names, toupper(i.type), sign_names[''])
        }))
        ->sign_placelist()
enddef

def Remove_signs(groupid: number)
    if !has_key(sign_placed_ids, groupid)
        return
    endif
    Sign_group(groupid)->sign_unplace()
    remove(sign_placed_ids, groupid)
enddef

def Remove_on_winclosed()
    const winid: number = expand('<amatch>')->str2nr()
    Remove_signs(winid)
    Remove_textprops(winid)
enddef

export def Place(loclist: bool)
    if !Get('signs') && !Get('texthl')
        return
    endif

    const xlist: list<any> = Getxlist(loclist)
    const id = Id(loclist)
    Remove_textprops(id)
    Remove_signs(id)

    if empty(xlist)
        return
    endif

    if Get('texthl')
        prop_type_change('qf-diagnostics-error',   Get('highlight_error'))
        prop_type_change('qf-diagnostics-warning', Get('highlight_warning'))
        prop_type_change('qf-diagnostics-info',    Get('highlight_info'))
        prop_type_change('qf-diagnostics-note',    Get('highlight_note'))
        prop_type_change('qf-diagnostics-misc',    Get('highlight_misc'))
        Add_textprops(xlist, id)
    endif

    if Get('signs')
        sign_define('qf-diagnostics-error',   Get('sign_error'))
        sign_define('qf-diagnostics-warning', Get('sign_warning'))
        sign_define('qf-diagnostics-info',    Get('sign_info'))
        sign_define('qf-diagnostics-note',    Get('sign_note'))
        sign_define('qf-diagnostics-misc',    Get('sign_misc'))
        Add_signs(xlist, id)
    endif

    if loclist
        execute $'autocmd qf-diagnostics WinClosed {id} ++once Remove_on_winclosed()'
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
        autocmd! qf-diagnostics WinClosed
    else
        const xid: number = Id(true)
        Remove_signs(xid)
        Remove_textprops(xid)
        execute $'autocmd! qf-diagnostics WinClosed {xid}'
    endif
enddef

export def Toggle(loclist: bool)
    const xid: number = Id(loclist)
    if !Signs_placed(xid) && !Props_placed(xid)
        Place(loclist)
        return
    endif
    Remove_signs(xid)
    Remove_textprops(xid)
    execute $'autocmd! qf-diagnostics WinClosed {xid}'
enddef

export def Popup(loclist: bool): number
    const xlist: list<any> = Getxlist(loclist)

    if empty(xlist)
        return 0
    endif

    const items: number = Get('popup_items')
    const idxs: list<number> = Filter_items(xlist, items)

    if empty(idxs)
        return 0
    endif

    var text: list<string> = []
    for i in idxs
        if empty(xlist[i].type)
            extend(text, printf('%d:%d %s', xlist[i].lnum, xlist[i].col, trim(xlist[i].text))->split('\n'))
        else
            extend(text, printf('%d:%d %s: %s',
                xlist[i].lnum,
                xlist[i].col,
                get(error_types, toupper(xlist[i].type), xlist[i].type) .. (xlist[i].nr < 1 ? '' : ' ' .. xlist[i].nr),
                trim(xlist[i].text))->split('\n')
            )
        endif
    endfor

    # Maximum width for popup window
    const max: number = Get('popup_maxwidth')
    const textwidth: number = max > 0
        ? max
        : len(text)
            ->range()
            ->map((_, i: number): number => strdisplaywidth(text[i]))
            ->max()

    const border: list<number> = Get('popup_border')
    const pad: number = get(border, 1, 1) + get(border, 3, 1) + 3
    const width: number = textwidth + pad > &columns ? &columns - pad : textwidth

    # Column position for popup window
    const pos: dict<number> = win_getid()
        ->screenpos(line('.'), items == 2 ? xlist[idxs[0]].col : col('.'))

    const col: number = &columns - pos.curscol <= width ? &columns - width - 1 : pos.curscol

    var opts: dict<any> = {
        moved: 'any',
        col: col,
        minwidth: width,
        maxwidth: width,
        maxheight: Get('popup_maxheight'),
        padding: [0, 1, 0, 1],
        border: border,
        borderchars: Get('popup_borderchars'),
        borderhighlight: ['QfDiagnosticsBorder'],
        highlight: 'QfDiagnostics',
        scrollbarhighlight: 'QfDiagnosticsScrollbar',
        thumbhighlight: 'QfDiagnosticsThumb',
        firstline: 1,
        mapping: Get('popup_mapping'),
        filtermode: 'n',
        filter: Popup_filter,
        callback: Popup_callback
    }

    popup_close(popup_winid)

    if Get('popup_attach')
        prop_remove({type: 'qf-diagnostics-popup', all: true})
        prop_add(line('.'),
            items == 2 ? (xlist[idxs[0]].col > 0 ? xlist[idxs[0]].col : col('.')) : col('.'),
            {type: 'qf-diagnostics-popup'}
        )
        extend(opts, {
            textprop: 'qf-diagnostics-popup',
            pos: 'botleft',
            line: 0,
            col: col - pos.curscol,
        })
    endif

    popup_winid = popup_atcursor(text, opts)
    setwinvar(popup_winid, '&breakindent', 1)
    setwinvar(popup_winid, '&tabstop', &g:tabstop)

    matchadd('QfDiagnosticsLineNr',  '^\d\+\%(:\d\+\)\?',                              10, -1, {window: popup_winid})
    matchadd('QfDiagnosticsError',   '^\d\+\%(:\d\+\)\? \zs\<error\>\%(:\| \d\+:\)',   10, -1, {window: popup_winid})
    matchadd('QfDiagnosticsWarning', '^\d\+\%(:\d\+\)\? \zs\<warning\>\%(:\| \d\+:\)', 10, -1, {window: popup_winid})
    matchadd('QfDiagnosticsInfo',    '^\d\+\%(:\d\+\)\? \zs\<info\>\%(:\| \d\+:\)',    10, -1, {window: popup_winid})
    matchadd('QfDiagnosticsNote',    '^\d\+\%(:\d\+\)\? \zs\<note\>\%(:\| \d\+:\)',    10, -1, {window: popup_winid})
    Get('popup_create_cb')(popup_winid, curlist.id, loclist)

    return popup_winid
enddef
