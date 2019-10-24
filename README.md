# vim-qf-tooltip

Display the `quickfix` error in the current line in a popup window (like a
tooltip).

The plugin checks if the current `quickfix` list contains any errors for the
current line and displays them in a popup window at the current cursor position.

## Usage

`<plug>(qf-tooltip-show)` will popup a small tooltip at the current cursor
position. If the line contains several errors, all errors will be listed in the
same popup window.

Example:
```vim
" Mnemonic: Echo Error
nmap <leader>ee <plug>(qf-tooltip-show)
```

#### Popup highlightings

The appearance of the popup window can be configured through the following
highlight groups:

| Highlight group   | Description                             | Default     |
| ----------------- | --------------------------------------- | ----------- |
| `QfTooltip`       | Popup window background and error text. | `Pmenu`     |
| `QfTooltipTitle`  | Title of popup window.                  | `Title`     |
| `QfTooltipLineNr` | Line and column number.                 | `Directory` |

The title of the popup window is set to the title of the current quickfix list.


## Installation

#### Manual Installation

```bash
$ cd ~/.vim/pack/git-plugins/start
$ git clone https://github.com/bfrg/vim-qf-tooltip
$ vim -u NONE -c "helptags vim-qf-tooltip/doc" -c q
```
**Note:** The directory name `git-plugins` is arbitrary, you can pick any other
name. For more details see `:help packages`.

#### Plugin Managers

Assuming [vim-plug][plug] is your favorite plugin manager, add the following to
your `.vimrc`:
```vim
Plug 'bfrg/vim-qf-tooltip'
```


## Related plugins

[vim-qf-preview][qf-preview]


## License

Distributed under the same terms as Vim itself. See `:help license`.

[plug]: https://github.com/junegunn/vim-plug
[qf-preview]: https://github.com/bfrg/vim-qf-preview
