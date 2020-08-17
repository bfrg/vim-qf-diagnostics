" ==============================================================================
" Display quickfix errors in a popup window (like a tooltip)
" File:         autoload/qftooltip.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-qf-tooltip
" Last Change:  Aug 17, 2020
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

function s:error(msg)
    echohl ErrorMsg | echomsg a:msg | echohl None
endfunction

function s:popup_filter(winid, key) abort
    if line('$', a:winid) == popup_getpos(a:winid).core_height
        return v:false
    endif
    call popup_setoptions(a:winid, {'minheight': popup_getpos(a:winid).core_height})
    if a:key ==# get(g:, 'qftooltip', {})->get('scrollup', "\<c-j>")
        const line = popup_getoptions(a:winid).firstline
        const newline = line < line('$', a:winid) ? (line + 1) : line('$', a:winid)
        call popup_setoptions(a:winid, {'firstline': newline})
    elseif a:key ==# get(g:, 'qftooltip', {})->get('scrollup', "\<c-k>")
        const line = popup_getoptions(a:winid).firstline
        const newline = (line - 1) > 0 ? (line - 1) : 1
        call popup_setoptions(a:winid, {'firstline': newline})
    else
        return v:false
    endif
    return v:true
endfunction

function qftooltip#show(loclist) abort
    let entries = a:loclist ? getloclist(0) : getqflist()

    if empty(entries)
        return
    endif

    call filter(entries, "v:val.bufnr == bufnr('%') && v:val.lnum == line('.')")

    if empty(entries)
        return
    endif

    let text = []
    for item in entries
        if empty(item.type)
            call extend(text, printf('%d:%d %s', item.lnum, item.col, trim(item.text))->split('\n'))
        else
            call extend(text, printf('%d:%d %s: %s',
                    \ item.lnum,
                    \ item.col,
                    \ get(s:type, tolower(item.type), item.type) .. (item.nr == -1 ? '' : ' ' .. item.nr),
                    \ trim(item.text))->split('\n')
                    \ )
        endif
    endfor

    const textwidth = len(text)
            \ ->range()
            \ ->map({_, i -> strdisplaywidth(text[i])})
            \ ->max()

    " Maximum width for popup window
    const padding = get(g:, 'qftooltip', {})->get('padding', [0, 1, 0, 1])
    const border = get(g:, 'qftooltip', {})->get('border', [0, 0, 0, 0])
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
            \ 'borderchars': get(g:, 'qftooltip', {})->get('borderchars', []),
            \ 'borderhighlight': ['QfTooltipBorder'],
            \ 'highlight': 'QfTooltip',
            \ 'scrollbarhighlight': 'QfTooltipScrollbar',
            \ 'thumbhighlight': 'QfTooltipThumb',
            \ 'firstline': 1,
            \ 'mapping': get(g:, 'qftooltip', {})->get('mapping', v:true),
            \ 'filtermode': 'n',
            \ 'filter': funcref('s:popup_filter'),
            \ 'callback': {-> execute('let s:winid = 0')}
            \ })

    call setbufvar(winbufnr(s:winid), '&syntax', 'qftooltip')
    call setwinvar(s:winid, '&breakindent', 1)

    return s:winid
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
