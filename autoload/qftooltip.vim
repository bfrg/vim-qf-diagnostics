" ==============================================================================
" Display quickfix errors in a popup window (like a tooltip)
" File:         autoload/qftooltip.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-tooltip
" Last Change:  Aug 19, 2020
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

const s:defaults = {
        \ 'scrollup': "\<c-k>",
        \ 'scrolldown': "\<c-j>",
        \ 'padding': [0, 1, 0, 1],
        \ 'border': [0, 0, 0, 0],
        \ 'borderchars': [],
        \ 'mapping': v:true,
        \ 'items': 2
        \ }

const s:get = {x -> get(g:, 'qftooltip', {})->get(x, s:defaults[x])}

function s:error(msg)
    echohl ErrorMsg | echomsg a:msg | echohl None
endfunction

function s:popup_filter(winid, key) abort
    if line('$', a:winid) == popup_getpos(a:winid).core_height
        return v:false
    endif
    call popup_setoptions(a:winid, {'minheight': popup_getpos(a:winid).core_height})
    if a:key ==# s:get('scrolldown')
        const line = popup_getoptions(a:winid).firstline
        const newline = line < line('$', a:winid) ? (line + 1) : line('$', a:winid)
        call popup_setoptions(a:winid, {'firstline': newline})
    elseif a:key ==# s:get('scrollup')
        const line = popup_getoptions(a:winid).firstline
        const newline = (line - 1) > 0 ? (line - 1) : 1
        call popup_setoptions(a:winid, {'firstline': newline})
    else
        return v:false
    endif
    return v:true
endfunction

function qftooltip#show(loclist) abort
    let xlist = a:loclist ? getloclist(0) : getqflist()

    if empty(xlist)
        return
    endif

    let idxs = s:filter_items(xlist, s:get('items'))

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

    const textwidth = len(text)
            \ ->range()
            \ ->map({_, i -> strdisplaywidth(text[i])})
            \ ->max()

    " Maximum width for popup window
    const padding = s:get('padding')
    const border = s:get('border')
    const pad = get(padding, 1, 1) + get(padding, 3, 1) + get(border, 1, 1) + get(border, 3, 1) + 1
    const width = textwidth + pad > &columns ? &columns - pad : textwidth

    " Column position for popup window
    const pos = screenpos(win_getid(), line('.'), col('.'))
    const col = &columns - pos.curscol < width ? &columns - width - 1 : pos.curscol

    call popup_close(s:winid)
    let s:winid = popup_atcursor(text, {
            \ 'moved': 'any',
            \ 'col': col,
            \ 'minwidth': width,
            \ 'maxwidth': width,
            \ 'padding': padding,
            \ 'border': border,
            \ 'borderchars': s:get('borderchars'),
            \ 'borderhighlight': ['QfTooltipBorder'],
            \ 'highlight': 'QfTooltip',
            \ 'scrollbarhighlight': 'QfTooltipScrollbar',
            \ 'thumbhighlight': 'QfTooltipThumb',
            \ 'firstline': 1,
            \ 'mapping': s:get('mapping'),
            \ 'filtermode': 'n',
            \ 'filter': funcref('s:popup_filter'),
            \ 'callback': {-> execute('let s:winid = 0')}
            \ })

    call setbufvar(winbufnr(s:winid), '&syntax', 'qftooltip')
    call setwinvar(s:winid, '&breakindent', 1)
    call setwinvar(s:winid, '&tabstop', &g:tabstop)

    return s:winid
endfunction

" 'xlist':
"     quickfix or location list
"
" 'items':
"     Option that specifies which quickfix items to display in the popup window
"     0 - display all items in current line
"     1 - display only item(s) in current line+column (exact match)
"     2 - display item(s) closest to current column
"
" Note: When the cursor is at the very end of a line but the quickfix item is
" one character past end-of-line that item will still be displayed. This can
" happen for some Clang warnings, for example:
"
" 18:29 warning: statement should be inside braces [hicpp-braces-around-statements]
"         for (int i = 0; i < N; ++i)
"                                    ^
"                                     {
"
function s:filter_items(xlist, items) abort
    if empty(a:xlist)
        return []
    endif

    if !a:items
        " Find all quickfix items in current line
        return len(a:xlist)
                \ ->range()
                \ ->filter("a:xlist[v:val].bufnr == bufnr('%')")
                \ ->filter("a:xlist[v:val].lnum == line('.')")
    elseif a:items == 1
        " Find quickfix item(s) only in current line+column (exact match)
        return len(a:xlist)
                \ ->range()
                \ ->filter("a:xlist[v:val].bufnr == bufnr('%')")
                \ ->filter("a:xlist[v:val].lnum == line('.')")
                \ ->filter("a:xlist[v:val].col == col('.') || a:xlist[v:val].col == col('.') + 1 && a:xlist[v:val].col == col('$')")
    elseif a:items == 2
        " First find all quickfix items in current line
        let idxs = len(a:xlist)
                \ ->range()
                \ ->filter({_,i ->
                \   a:xlist[i].bufnr == bufnr('%') && a:xlist[i].lnum == line('.')
                \ })

        if empty(idxs)
            return []
        endif

        " Find item(s) closest to current column
        let min = col('$')

        for i in idxs
            let delta = abs(col('.') - a:xlist[i].col)
            if delta <= min
                let min = delta
                let col = a:xlist[i].col
            endif
        endfor

        return filter(idxs, {_,i -> a:xlist[i].col == col})
    endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
