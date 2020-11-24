" ==============================================================================
" Display quickfix errors in popup window and sign column
" File:         autoload/qfdiagnostics.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-diagnostics
" Last Change:  Nov 24, 2020
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

hi def link QfDiagnostics          Pmenu
hi def link QfDiagnosticsBorder    Pmenu
hi def link QfDiagnosticsScrollbar PmenuSbar
hi def link QfDiagnosticsThumb     PmenuThumb
hi def link QfDiagnosticsLineNr    Directory
hi def link QfDiagnosticsError     ErrorMsg
hi def link QfDiagnosticsWarning   WarningMsg
hi def link QfDiagnosticsInfo      MoreMsg
hi def link QfDiagnosticsNote      Todo

let s:winid = 0

" Cache current quickfix list: {'id': 2, 'changedtick': 1, 'items': [...]}
let s:xlist = {}

const s:error_types = {'E': 'error', 'W': 'warning', 'I': 'info', 'N': 'note'}
const s:sign_priorities = {x -> {'E': x + 4, 'W': x + 3, 'I': x + 2, 'N': x + 1, '': x}}

" Look-up table used for both sign names and text-property types
const s:sign_names = {
        \ 'E': 'qf-diagnostics-error',
        \ 'W': 'qf-diagnostics-warning',
        \ 'I': 'qf-diagnostics-info',
        \ 'N': 'qf-diagnostics-note',
        \  '': 'qf-diagnostics-misc'
        \ }

" Place quickfix and location-list errors under different sign groups so that
" they can be toggled separately in the sign column. Quickfix errors are placed
" under the qf-diagnostics-0 group, and location-list errors under
" qf-diagnostics-winid, where 'winid' is the window-ID of the window the
" location-list belongs to.
const s:sign_group = {id -> printf('qf-diagnostics-%d', id)}

const s:id = {loclist -> loclist
        \ ? win_getid()->getwininfo()[0].loclist
        \   ? getloclist(0, {'filewinid': 0}).filewinid
        \   : win_getid()
        \ : 0
        \ }

" Dictionary with (ID, 1) pairs for every placed quickfix/location-list,
" quickfix list has ID=0, for location lists we use window-IDs
let s:sign_placed_ids = {}

" Similar to sign groups we use different text-property IDs so that quickfix and
" location-list errors can be removed individually. For quickfix errors the IDs
" are set to 0, and for location-list errors the IDs are set to the window-ID of
" the window the location-list belongs to.
" Dictionary of (ID, bufnr-items):
" {
"   '0': {
"       bufnr_1: [{'type': 'prop-error', 'lnum': 10, 'col': 19}, {...}, ...],
"       bufnr_2: [{'type': 'prop-info',  'lnum': 13, 'col': 19}, {...}, ...],
"       ...
"   },
"   '1001': {...}
" }
let s:prop_items = {}

const s:props_placed = {id -> has_key(s:prop_items, id)}
const s:signs_placed = {id -> has_key(s:sign_placed_ids, id)}

augroup qf-diagnostics-textprops
augroup END

const s:defaults = {
        \ 'popup_create_cb': {-> 0},
        \ 'popup_scrollup': "\<c-k>",
        \ 'popup_scrolldown': "\<c-j>",
        \ 'popup_border': [0, 0, 0, 0],
        \ 'popup_maxheight': 0,
        \ 'popup_maxwidth': 0,
        \ 'popup_borderchars': [],
        \ 'popup_mapping': v:true,
        \ 'popup_items': 0,
        \ 'popup_attach': v:false,
        \ 'texthl': v:false,
        \ 'highlight_error':   {'highlight': 'SpellBad',   'priority': 14, 'combine': 1},
        \ 'highlight_warning': {'highlight': 'SpellCap',   'priority': 13, 'combine': 1},
        \ 'highlight_info':    {'highlight': 'SpellLocal', 'priority': 12, 'combine': 1},
        \ 'highlight_note':    {'highlight': 'SpellRare',  'priority': 11, 'combine': 1},
        \ 'highlight_misc':    {'highlight': 'Underlined', 'priority': 10, 'combine': 1},
        \ 'signs': v:true,
        \ 'sign_priorities': 10,
        \ 'sign_error':   {'text': 'E>', 'texthl': 'ErrorMsg'},
        \ 'sign_warning': {'text': 'W>', 'texthl': 'WarningMsg'},
        \ 'sign_info':    {'text': 'I>', 'texthl': 'MoreMsg'},
        \ 'sign_note':    {'text': 'N>', 'texthl': 'Todo'},
        \ 'sign_misc':    {'text': '?>', 'texthl': 'Normal'}
        \ }

const s:get = {x -> get(g:, 'qfdiagnostics', {})->get(x, s:defaults[x])}

silent! call prop_type_add('qf-diagnostics-popup', {})
silent! call prop_type_add('qf-diagnostics-error',   s:get('highlight_error'))
silent! call prop_type_add('qf-diagnostics-warning', s:get('highlight_warning'))
silent! call prop_type_add('qf-diagnostics-info',    s:get('highlight_info'))
silent! call prop_type_add('qf-diagnostics-note',    s:get('highlight_note'))
silent! call prop_type_add('qf-diagnostics-misc',    s:get('highlight_misc'))

function s:popup_filter(winid, key) abort
    if line('$', a:winid) == popup_getpos(a:winid).core_height
        return v:false
    endif
    call popup_setoptions(a:winid, {'minheight': popup_getpos(a:winid).core_height})
    if a:key ==# s:get('popup_scrolldown')
        const line = popup_getoptions(a:winid).firstline
        const newline = line < line('$', a:winid) ? (line + 1) : line('$', a:winid)
        call popup_setoptions(a:winid, {'firstline': newline})
    elseif a:key ==# s:get('popup_scrollup')
        const line = popup_getoptions(a:winid).firstline
        const newline = (line - 1) > 0 ? (line - 1) : 1
        call popup_setoptions(a:winid, {'firstline': newline})
    else
        return v:false
    endif
    return v:true
endfunction

function s:popup_callback(winid, result)
    let s:winid = 0
    call prop_remove({'type': 'qf-diagnostics-popup', 'all': v:true})
endfunction

function s:getxlist(loclist) abort
    const Xgetlist = a:loclist ? function('getloclist', [0]) : function('getqflist')
    const qf = Xgetlist({'changedtick': 0, 'id': 0})

    if get(s:xlist, 'id', -1) == qf.id && get(s:xlist, 'changedtick') == qf.changedtick
        return s:xlist.items
    endif

    let s:xlist = Xgetlist({'changedtick': 0, 'id': 0, 'items': 0})
    return s:xlist.items
endfunction

" 'xlist': quickfix or location list
"
" 'items':
"     Option that specifies which quickfix items to display in the popup window
"     0 - display all items in current line
"     1 - display only item(s) in current line+column (exact match)
"     2 - display item(s) closest to current column
function s:filter_items(xlist, items) abort
    if empty(a:xlist)
        return []
    endif

    if !a:items
        return len(a:xlist)
                \ ->range()
                \ ->filter("a:xlist[v:val].bufnr == bufnr('%')")
                \ ->filter("a:xlist[v:val].lnum == line('.')")
    elseif a:items == 1
        return len(a:xlist)
                \ ->range()
                \ ->filter("a:xlist[v:val].bufnr == bufnr('%')")
                \ ->filter("a:xlist[v:val].lnum == line('.')")
                \ ->filter("a:xlist[v:val].col == col('.') || a:xlist[v:val].col == col('.') + 1 && a:xlist[v:val].col == col('$')")
    elseif a:items == 2
        let idxs = len(a:xlist)
                \ ->range()
                \ ->filter("a:xlist[v:val].bufnr == bufnr('%')")
                \ ->filter("a:xlist[v:val].lnum == line('.')")

        if empty(idxs)
            return []
        endif

        let min = col('$')
        for i in idxs
            let delta = abs(col('.') - a:xlist[i].col)
            if delta <= min
                let min = delta
                let col = a:xlist[i].col
            endif
        endfor

        return filter(idxs, 'a:xlist[v:val].col == col')
    endif
endfunction

function s:add_textprops_on_bufread(bufnr) abort
    for id in keys(s:prop_items)
        for item in get(s:prop_items[id], a:bufnr, [])
            let max = getbufline(a:bufnr, item.lnum)[0]->len()
            call prop_add(item.lnum, item.col >= max ? max : item.col, {
                    \ 'length': 1,
                    \ 'bufnr': a:bufnr,
                    \ 'id': id,
                    \ 'type': item.type
                    \ })
        endfor
    endfor
endfunction

function s:add_textprops(xlist, id) abort
    let s:prop_items[a:id] = {}
    let bufs = s:prop_items[a:id]

    for i in a:xlist
        if i.bufnr > 0 && bufexists(i.bufnr) && i.valid && i.lnum > 0 && i.col > 0
            call extend(bufs, {i.bufnr: []}, 'keep')
            let type = get(s:sign_names, toupper(i.type), s:sign_names[''])
            call add(bufs[i.bufnr], {'type': type, 'lnum': i.lnum, 'col': i.col})

            if bufloaded(i.bufnr)
                let max = getbufline(i.bufnr, i.lnum)[0]->len()
                call prop_add(i.lnum, i.col >= max ? max : i.col, {
                        \ 'length': 1,
                        \ 'bufnr': i.bufnr,
                        \ 'id': a:id,
                        \ 'type': type
                        \ })
            endif
            execute printf('autocmd! qf-diagnostics-textprops BufReadPost <buffer=%d> call s:add_textprops_on_bufread(%d)', i.bufnr, i.bufnr)
        endif
    endfor
endfunction

function s:remove_textprops(id) abort
    if !has_key(s:prop_items, a:id)
        return
    endif

    for i in get(s:prop_items, a:id)->keys()
        let bufnr = str2nr(i)
        if bufexists(bufnr)
            call prop_remove({'id': a:id, 'type': 'qf-diagnostics-error',   'bufnr': bufnr, 'both': 1, 'all': 1})
            call prop_remove({'id': a:id, 'type': 'qf-diagnostics-warning', 'bufnr': bufnr, 'both': 1, 'all': 1})
            call prop_remove({'id': a:id, 'type': 'qf-diagnostics-info',    'bufnr': bufnr, 'both': 1, 'all': 1})
            call prop_remove({'id': a:id, 'type': 'qf-diagnostics-note',    'bufnr': bufnr, 'both': 1, 'all': 1})
            call prop_remove({'id': a:id, 'type': 'qf-diagnostics-misc',    'bufnr': bufnr, 'both': 1, 'all': 1})
        endif
    endfor

    call remove(s:prop_items, a:id)
    if empty(s:prop_items)
        autocmd! qf-diagnostics-textprops
    endif
endfunction

function s:remove_signs(groupid) abort
    if !has_key(s:sign_placed_ids, a:groupid)
        return
    endif
    call s:sign_group(a:groupid)->sign_unplace()
    call remove(s:sign_placed_ids, a:groupid)
endfunction

function s:add_signs(xlist, id) abort
    const priorities = s:get('sign_priorities')->s:sign_priorities()
    const group = s:sign_group(a:id)
    call extend(s:sign_placed_ids, {a:id: 1})
    call copy(a:xlist)
            \ ->filter('v:val.bufnr && v:val.valid && v:val.lnum')
            \ ->map({_,item -> {
            \   'lnum': item.lnum,
            \   'buffer': item.bufnr,
            \   'group': group,
            \   'priority': get(priorities, toupper(item.type), priorities['']),
            \   'name': get(s:sign_names, toupper(item.type), s:sign_names[''])
            \   }
            \ })
            \ ->sign_placelist()
endfunction

function qfdiagnostics#place(loclist) abort
    if !s:get('signs') && !s:get('texthl')
        return
    endif

    const xlist = s:getxlist(a:loclist)
    const id = s:id(a:loclist)
    call s:remove_textprops(id)
    call s:remove_signs(id)

    if empty(xlist)
        return
    endif

    if s:get('texthl')
        call prop_type_change('qf-diagnostics-error',   s:get('highlight_error'))
        call prop_type_change('qf-diagnostics-warning', s:get('highlight_warning'))
        call prop_type_change('qf-diagnostics-info',    s:get('highlight_info'))
        call prop_type_change('qf-diagnostics-note',    s:get('highlight_note'))
        call prop_type_change('qf-diagnostics-misc',    s:get('highlight_misc'))
        call s:add_textprops(xlist, id)
    endif

    if s:get('signs')
        call sign_define('qf-diagnostics-error',   s:get('sign_error'))
        call sign_define('qf-diagnostics-warning', s:get('sign_warning'))
        call sign_define('qf-diagnostics-info',    s:get('sign_info'))
        call sign_define('qf-diagnostics-note',    s:get('sign_note'))
        call sign_define('qf-diagnostics-misc',    s:get('sign_misc'))
        call s:add_signs(xlist, id)
    endif
endfunction

function qfdiagnostics#cclear() abort
    call s:remove_signs(0)
    call s:remove_textprops(0)
endfunction

function qfdiagnostics#lclear(bang) abort
    if a:bang
        call keys(s:sign_placed_ids)
                \ ->filter('v:val != 0')
                \ ->map({_,i -> s:remove_signs(i)})
        call keys(s:prop_items)
                \ ->filter('v:val != 0')
                \ ->map({_,i -> s:remove_textprops(i)})
    else
        const id = s:id(v:true)
        call s:remove_signs(id)
        call s:remove_textprops(id)
    endif
endfunction

function qfdiagnostics#toggle(loclist) abort
    const id = s:id(a:loclist)

    if !s:signs_placed(id) && !s:props_placed(id)
        call qfdiagnostics#place(a:loclist)
        return
    endif

    call s:remove_signs(id)
    call s:remove_textprops(id)
endfunction

function qfdiagnostics#popup(loclist) abort
    const xlist = s:getxlist(a:loclist)

    if empty(xlist)
        return
    endif

    const items = s:get('popup_items')
    const idxs = s:filter_items(xlist, items)

    if empty(idxs)
        return
    endif

    let text = []
    for i in idxs
        if empty(xlist[i].type)
            call extend(text, printf('%d:%d %s', xlist[i].lnum, xlist[i].col, trim(xlist[i].text))->split('\n'))
        else
            call extend(text, printf('%d:%d %s: %s',
                    \ xlist[i].lnum,
                    \ xlist[i].col,
                    \ get(s:error_types, toupper(xlist[i].type), xlist[i].type) .. (xlist[i].nr == -1 ? '' : ' ' .. xlist[i].nr),
                    \ trim(xlist[i].text))->split('\n')
                    \ )
        endif
    endfor

    " Maximum width for popup window
    const max = s:get('popup_maxwidth')
    const textwidth = max > 0
            \ ? max
            \ : len(text)->range()->map('strdisplaywidth(text[v:val])')->max()

    const border = s:get('popup_border')
    const pad = + get(border, 1, 1) + get(border, 3, 1) + 3
    const width = textwidth + pad > &columns ? &columns - pad : textwidth

    " Column position for popup window
    const pos = screenpos(win_getid(), line('.'), items == 2 ? xlist[idxs[0]].col : col('.'))
    const col = &columns - pos.curscol <= width ? &columns - width - 1 : pos.curscol

    let opts = {
            \ 'moved': 'any',
            \ 'col': col,
            \ 'minwidth': width,
            \ 'maxwidth': width,
            \ 'maxheight': s:get('popup_maxheight'),
            \ 'padding': [0, 1, 0, 1],
            \ 'border': border,
            \ 'borderchars': s:get('popup_borderchars'),
            \ 'borderhighlight': ['QfDiagnosticsBorder'],
            \ 'highlight': 'QfDiagnostics',
            \ 'scrollbarhighlight': 'QfDiagnosticsScrollbar',
            \ 'thumbhighlight': 'QfDiagnosticsThumb',
            \ 'firstline': 1,
            \ 'mapping': s:get('popup_mapping'),
            \ 'filtermode': 'n',
            \ 'filter': funcref('s:popup_filter'),
            \ 'callback': funcref('s:popup_callback')
            \ }

    call popup_close(s:winid)

    if s:get('popup_attach')
        call prop_remove({'type': 'qf-diagnostics-popup', 'all': v:true})
        call prop_add(line('.'), items == 2 ? xlist[idxs[0]].col : col('.'), {'type': 'qf-diagnostics-popup'})
        call extend(opts, {
                \ 'textprop': 'qf-diagnostics-popup',
                \ 'pos': 'botleft',
                \ 'line': 0,
                \ 'col': col - pos.curscol,
                \ })
    endif

    let s:winid = popup_atcursor(text, opts)
    call setwinvar(s:winid, '&breakindent', 1)
    call setwinvar(s:winid, '&tabstop', &g:tabstop)

    call matchadd('QfDiagnosticsLineNr',  '^\d\+\%(:\d\+\)\?',                              10, -1, {'window': s:winid})
    call matchadd('QfDiagnosticsError',   '^\d\+\%(:\d\+\)\? \zs\<error\>\%(:\| \d\+:\)',   10, -1, {'window': s:winid})
    call matchadd('QfDiagnosticsWarning', '^\d\+\%(:\d\+\)\? \zs\<warning\>\%(:\| \d\+:\)', 10, -1, {'window': s:winid})
    call matchadd('QfDiagnosticsInfo',    '^\d\+\%(:\d\+\)\? \zs\<info\>\%(:\| \d\+:\)',    10, -1, {'window': s:winid})
    call matchadd('QfDiagnosticsNote',    '^\d\+\%(:\d\+\)\? \zs\<note\>\%(:\| \d\+:\)',    10, -1, {'window': s:winid})
    call s:get('popup_create_cb')(s:winid, s:xlist.id, a:loclist)

    return s:winid
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
