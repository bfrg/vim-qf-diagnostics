# vim-qf-diagnostics

- Populate the sign column with quickfix or location list errors
- Display the error message for the current line in a popup window (like a
  tooltip).

The plugin checks if the current `quickfix` list (or `location-list`) contains
any errors for the current line and displays them in a popup window at the
current cursor position.

![screenshots](https://user-images.githubusercontent.com/6266600/86536450-01328680-bee8-11ea-849f-4e24809515b9.png)

## Usage

### `<Plug>` mappings

* <kbd>\<plug>(qf-diagnostics-popup-quickfix)</kbd> will popup a small tooltip
  at the current cursor position with the error message found in the _current_
  `quickfix` list. If the line contains several errors, all entries are
  collected and displayed in the same popup window.
* <kbd>\<plug>(qf-diagnostics-popup-loclist)</kbd> same as above but displays
  error messages from the current `location-list`.

Example:
```vim
nmap gh <plug>(qf-diagnostics-popup-quickfix)
nmap gH <plug>(qf-diagnostics-popup-loclist)
```

#### Popup window mappings

If not all quickfix errors (for the current line) fit into the popup window, a
scrollbar will appear on the right side. The popup window can either be scrolled
with the mouse wheel, or with <kbd>CTRL-J</kbd> and <kbd>CTRL-K</kbd>.

Pressing <kbd>CTRL-C</kbd> or moving the cursor in any direction will close the
popup window.

### Commands

| Command              | Description                                                                          |
| -------------------- | ------------------------------------------------------------------------------------ |
| `:DiagnosticsPlace`  | Place signs in the sign column for the current quickfix list.                        |
| `:DiagnosticsClear`  | Remove the signs placed by `:DiagnosticsPlace`.                                      |
| `:LDiagnosticsPlace` | Same as `:DiagnosticsPlace` but use the current location list of the current window. |
| `:LDiagnosticsClear` | Remove the signs placed by `:LDiagnosticsPlace`.                                     |

**Notes:**
* `:DiagnosticsPlace` and `:LDiagnosticsPlace` automatically remove any signs
  previously placed by the same command.
* `:LDiagnosticsClear` must be called in the same window where
  `:LDiagnosticsPlace` has been called. To remove all location-list signs (all
  windows) run `:LDiagnosticsClear!`.

#### Example

If you want to place the signs automatically after running `:make` or `:lmake`,
add the following to your `vimrc`:
```vim
augroup qf-make-signs
    autocmd!
    autocmd QuickfixCmdPost  make  DiagnosticsPlace
    autocmd QuickfixCmdPost lmake LDiagnosticsPlace
augroup END
```


## Configuration

### `g:qfdiagnostics`

The appearance of the popup window and the signs can be configured through the
dictionary variable `g:qfdiagnostics`. The following entries are supported:

| Entry               | Description                                                         | Default                                    |
| ------------------- | ------------------------------------------------------------------- | ------------------------------------------ |
| `popup_scrollup`    | Key for scrolling popup window up one text line.                    | `"\<C-k>"`                                 |
| `popup_scrolldown`  | Key for scrolling popup window down one text line.                  | `"\<C-j>"`                                 |
| `popup_maxheight`   | Maximum height of popup window. Set to `0` for maximum available.   | `0`                                        |
| `popup_maxwidth`    | Maximum width of popup window. Set to `0` for maximum available.    | `0`                                        |
| `popup_padding`     | List with numbers defining the padding inside the popup window.     | `[0, 1, 0, 1]`                             |
| `popup_border`      | List with numbers (`0` or `1`) specifying whether to draw a border. | `[0, 0, 0, 0]`                             |
| `popup_borderchars` | List with characters used for drawing the window border.            | `['═', '║', '═', '║', '╔', '╗', '╝', '╚']` |
| `sign_error`        | Sign attributes for quickfix items of type error.                   | `{'text': 'E>', 'texthl': 'ErrorMsg'}`     |
| `sign_warning`      | Sign attributes for quickfix items of type warning.                 | `{'text': 'W>', 'texthl': 'WarningMsg'}`   |
| `sign_info`         | Sign attributes for quickfix items of type info.                    | `{'text': 'I>', 'texthl': 'MoreMsg'}`      |
| `sign_note`         | Sign attributes for quickfix items of type note.                    | `{'text': 'N>', 'texthl': 'Todo'}`         |
| `sign_normal`       | Sign attributes for quickfix items of type normal.                  | `{'text': '?>', 'texthl': 'Search'}`       |

For more details on sign attributes, see `:help sign_define()`.

#### Examples

```vim
" Use a border with round corners
let g:qfdiagnostics = {
        \ 'popup_border': [],
        \ 'popup_borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰']
        \ }

" Don't draw a border around the popup window, set padding to 1 on each side
let g:qfdiagnostics = {
        \ 'popup_padding': [],
        \ 'popup_border': [0, 0, 0, 0]
        \ }
```

### Highlighting

The highlighting of the popup window can be changed through the following
highlight groups:

| Highlight group          | Description                              | Default      |
| ------------------------ | ---------------------------------------- | ------------ |
| `QfDiagnostics`          | Popup window background and normal text. | `Pmenu`      |
| `QfDiagnosticsBorder`    | Border of popup window.                  | `Pmenu`      |
| `QfDiagnosticsScrollbar` | Scrollbar of popup window.               | `PmenuSbar`  |
| `QfDiagnosticsThumb`     | Thumb of scrollbar.                      | `PmenuThumb` |
| `QfDiagnosticsLineNr`    | Line and column number in popup window.  | `Directory`  |
| `QfDiagnosticsError`     | Error text and number.                   | `ErrorMsg`   |
| `QfDiagnosticsWarning`   | Warning text and number.                 | `WarningMsg` |
| `QfDiagnosticsInfo`      | Info text and number.                    | `MoreMsg`    |
| `QfDiagnosticsNote`      | Note text and number.                    | `Todo`       |


## Installation

### Manual Installation

```bash
$ cd ~/.vim/pack/git-plugins/start
$ git clone https://github.com/bfrg/vim-qf-diagnostics
$ vim -u NONE -c "helptags vim-qf-diagnostics/doc" -c q
```
**Note:** The directory name `git-plugins` is arbitrary, you can pick any other
name. For more details see <kbd>:help packages</kbd>.

### Plugin Managers

Assuming [vim-plug][plug] is your favorite plugin manager, add the following to
your `vimrc`:
```vim
Plug 'bfrg/vim-qf-diagnostics'
```


## Related plugins

[vim-qf-preview][qf-preview]: A plugin for the quickfix and location list
windows to quickly preview the file with the quickfix item under the cursor in a
popup window.


## License

Distributed under the same terms as Vim itself. See <kbd>:help license</kbd>.

[plug]: https://github.com/junegunn/vim-plug
[qf-preview]: https://github.com/bfrg/vim-qf-preview
