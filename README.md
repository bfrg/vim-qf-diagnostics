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

### Popup window mappings

If not all quickfix errors (for the current line) fit into the popup window, a
scrollbar will appear on the right side. The popup window can then be scrolled
with the mouse wheel, or alternatively, with <kbd>CTRL-J</kbd> and
<kbd>CTRL-K</kbd>.

Press <kbd>CTRL-C</kbd> or move the cursor in any direction to close the popup
window.


## Configuration

### `g:qfdiagnostics`

The appearance of the popup window can be configured through the dictionary
variable `g:qfdiagnostics`. The following entries are supported:

| Entry         | Description                                                         | Default                                    |
| ------------- | ------------------------------------------------------------------- | ------------------------------------------ |
| `scrollup`    | Key for scrolling popup window up one text line.                    | `"\<C-k>"`                                 |
| `scrolldown`  | Key for scrolling popup window down one text line.                  | `"\<C-j>"`                                 |
| `maxheight`   | Maximum height of popup window. Set to `0` for maximum available.   | `0`                                        |
| `maxwidth`    | Maximum width of popup window. Set to `0` for maximum available.    | `0`                                        |
| `padding`     | List with numbers defining the padding inside the popup window.     | `[0, 1, 0, 1]`                             |
| `border`      | List with numbers (`0` or `1`) specifying whether to draw a border. | `[0, 0, 0, 0]`                             |
| `borderchars` | List with characters used for drawing the window border.            | `['═', '║', '═', '║', '╔', '╗', '╝', '╚']` |

Examples:
```vim
" Use a fancy border with round corners
let g:qfdiagnostics = {
        \ 'border': [],
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰']
        \ }

" Don't draw a border around the popup window, set padding to 1 on each side
let g:qfdiagnostics = {'padding': [], 'border': [0,0,0,0]}
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
