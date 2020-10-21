" ==============================================================================
" Display quickfix errors in a popup window (like a tooltip)
" File:         autoload/qftooltip.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-tooltip
" Last Change:  Oct 21, 2020
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

hi def link QfTooltip           Pmenu
hi def link QfTooltipBorder     Pmenu
hi def link QfTooltipScrollbar  PmenuSbar
hi def link QfTooltipThumb      PmenuThumb

let s:winid = 0

const s:type = {'e': 'error', 'w': 'warning', 'i': 'info', 'n': 'note'}

const s:sign_table = {
        \ 'E': 'qferror',
        \ 'W': 'qfwarning',
        \ 'I': 'qfinfo',
        \ 'N': 'qfnote',
        \  '': 'qfnormal'
        \ }

const s:group = 'qfsigns'

if prop_type_get('qf-tooltip-popup')->empty()
    call prop_type_add('qf-tooltip-popup', {})
endif

const s:defaults = {
        \ 'scrollup': "\<c-k>",
        \ 'scrolldown': "\<c-j>",
        \ 'padding': [0, 1, 0, 1],
        \ 'border': [0, 0, 0, 0],
        \ 'maxheight': 0,
        \ 'maxwidth': 0,
        \ 'borderchars': [],
        \ 'mapping': v:true,
        \ 'items': 2,
        \ 'textprop': v:false
        \ }

const s:sign_properties = {
        \ 'error':   {'text': 'E>', 'texthl': 'ErrorMsg'},
        \ 'warning': {'text': 'W>', 'texthl': 'WarningMsg'},
        \ 'info':    {'text': 'I>', 'texthl': 'MoreMsg'},
        \ 'note':    {'text': 'N>', 'texthl': 'Todo'},
        \ 'normal':  {'text': '?>', 'texthl': 'Search'}
        \ }

" Cache current quickfix list: { 'id': 2, 'changedtick': 1, 'items': [...] }
let s:xlist = {}

const s:get = {x -> get(g:, 'qf_diagnostics', {})->get(x, s:defaults[x])}

const s:popup = {x ->
        \ get(g:, 'qf_diagnostics', {})
        \ ->get('popup', s:defaults)
        \ ->get(x, s:defaults[x])
        \ }

const s:sign = {x ->
        \ get(g:, 'qf_diagnostics', {})
        \ ->get('sign_properties', s:sign_properties)
        \ ->get(x, s:sign_properties[x])
        \ }

function s:error(msg)
    echohl ErrorMsg | echomsg a:msg | echohl None
endfunction

function s:popup_filter(winid, key) abort
    if line('$', a:winid) == popup_getpos(a:winid).core_height
        return v:false
    endif
    call popup_setoptions(a:winid, {'minheight': popup_getpos(a:winid).core_height})
    if a:key ==# s:popup('scrolldown')
        const line = popup_getoptions(a:winid).firstline
        const newline = line < line('$', a:winid) ? (line + 1) : line('$', a:winid)
        call popup_setoptions(a:winid, {'firstline': newline})
    elseif a:key ==# s:popup('scrollup')
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
    call prop_remove({'type': 'qf-tooltip-popup', 'all': v:true})
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

" 'xlist':
"     quickfix or location list
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

function qftooltip#place(loclist, priority) abort
    const xlist = s:getxlist(a:loclist)

    if empty(xlist)
        return
    endif

    call sign_define('qferror', s:sign('error'))
    call sign_define('qfwarning', s:sign('warning'))
    call sign_define('qfinfo', s:sign('info'))
    call sign_define('qfnote', s:sign('note'))
    call sign_define('qfnormal', s:sign('normal'))

    call copy(xlist)
            \ ->filter('v:val.bufnr && v:val.valid && v:val.lnum')
            \ ->map({_,item -> {
            \   'lnum': item.lnum,
            \   'buffer': item.bufnr,
            \   'group': s:group,
            \   'priority': a:priority,
            \   'name': get(s:sign_table, toupper(item.type), s:sign_table[''])
            \   }
            \ })
            \ ->sign_placelist()
endfunction

function qftooltip#clear()
    return sign_unplace(s:group)
endfunction

function qftooltip#show(loclist) abort
    const xlist = s:getxlist(a:loclist)

    if empty(xlist)
        return
    endif

    const items = s:popup('items')
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
                    \ get(s:type, tolower(xlist[i].type), xlist[i].type) .. (xlist[i].nr == -1 ? '' : ' ' .. xlist[i].nr),
                    \ trim(xlist[i].text))->split('\n')
                    \ )
        endif
    endfor

    " Maximum width for popup window
    const max = s:popup('maxwidth')
    const textwidth = max > 0
            \ ? max
            \ : len(text)->range()->map('strdisplaywidth(text[v:val])')->max()

    const padding = s:popup('padding')
    const border = s:popup('border')
    const pad = get(padding, 1, 1) + get(padding, 3, 1) + get(border, 1, 1) + get(border, 3, 1) + 1
    const width = textwidth + pad > &columns ? &columns - pad : textwidth

    " Column position for popup window
    const pos = screenpos(win_getid(), line('.'), items == 2 ? xlist[idxs[0]].col : col('.'))
    const col = &columns - pos.curscol <= width ? &columns - width - 1 : pos.curscol

    let opts = {
            \ 'moved': 'any',
            \ 'col': col,
            \ 'minwidth': width,
            \ 'maxwidth': width,
            \ 'maxheight': s:popup('maxheight'),
            \ 'padding': padding,
            \ 'border': border,
            \ 'borderchars': s:popup('borderchars'),
            \ 'borderhighlight': ['QfTooltipBorder'],
            \ 'highlight': 'QfTooltip',
            \ 'scrollbarhighlight': 'QfTooltipScrollbar',
            \ 'thumbhighlight': 'QfTooltipThumb',
            \ 'firstline': 1,
            \ 'mapping': s:popup('mapping'),
            \ 'filtermode': 'n',
            \ 'filter': funcref('s:popup_filter'),
            \ 'callback': funcref('s:popup_callback')
            \ }

    call popup_close(s:winid)

    if s:popup('textprop')
        call prop_remove({'type': 'qf-tooltip-popup', 'all': v:true})
        call prop_add(line('.'), items == 2 ? xlist[idxs[0]].col : col('.'), {'type': 'qf-tooltip-popup'})
        call extend(opts, {
                \ 'textprop': 'qf-tooltip-popup',
                \ 'pos': 'botleft',
                \ 'line': 0,
                \ 'col': col - pos.curscol,
                \ })
    endif

    let s:winid = popup_atcursor(text, opts)
    call setbufvar(winbufnr(s:winid), '&syntax', 'qftooltip')
    call setwinvar(s:winid, '&breakindent', 1)
    call setwinvar(s:winid, '&tabstop', &g:tabstop)

    return s:winid
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
