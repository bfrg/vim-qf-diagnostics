# vim-qf-tooltip

Display the error message for the current line in a popup window (like a
tooltip).

The plugin checks if the current `quickfix` list (or `location-list`) contains
any errors for the current line and displays them in a popup window at the
current cursor position.

<dl>
  <p align="center">
  <img src="https://user-images.githubusercontent.com/6266600/75208558-58775c00-577c-11ea-9ffc-9d8e587b39b0.png" width="480"/>
  </p>
</dl>


## Usage

### `<Plug>` mappings

* <kbd>\<plug>(qf-tooltip-qflist)</kbd> will popup a small tooltip at the
  current cursor position with the error message found in the _current_
  `quickfix` list. If the line contains several errors, all will be collected
  and displayed in the same popup window.
* <kbd>\<plug>(qf-tooltip-loclist)</kbd> same as above but uses the current
  `location-list`.

 Examples:
  ```vim
  " mnemonic: popup quickfix error
  nmap <leader>pq <plug>(qf-tooltip-qflist)

  " mnemonic: popup location-list error
  nmap <leader>pl <plug>(qf-tooltip-loclist)
  ```

### Popup highlightings

The appearance of the popup window can be configured through the following
highlight groups:

| Highlight group     | Description                             | Default     |
| ------------------- | --------------------------------------- | ----------- |
| `QfTooltip`         | Popup window background and error text. | `Pmenu`     |
| `QfTooltipTitle`    | Title of popup window.                  | `Title`     |
| `QfTooltipLineNr`   | Line and column number.                 | `Directory` |
| `QfTooltipError`    | Error text and number.                  | `ErrorMsg`  |
| `QfTooltipWarning`  | Warning text and number.                | `WarningMsg`|
| `QfTooltipInfo`     | Info text and number.                   | `MoreMsg`   |
| `QfTooltipScrollbar`| Scrollbar of popup window.              | `PmenuSbar` |
| `QfTooltipThumb`    | Thumb of scrollbar.                     | `PmenuThumb`|

The title of the popup window is set to the title of the current quickfix (or
location) list.


## Installation

#### Manual Installation

```bash
$ cd ~/.vim/pack/git-plugins/start
$ git clone https://github.com/bfrg/vim-qf-tooltip
$ vim -u NONE -c "helptags vim-qf-tooltip/doc" -c q
```
**Note:** The directory name `git-plugins` is arbitrary, you can pick any other
name. For more details see <kbd>:help packages</kbd>.

#### Plugin Managers

Assuming [vim-plug][plug] is your favorite plugin manager, add the following to
your `vimrc`:
```vim
Plug 'bfrg/vim-qf-tooltip'
```


## Related plugins

[vim-qf-preview][qf-preview]: A plugin for the quickfix and location list
windows to quickly preview the file with the quickfix item under the cursor in a
popup window.


## License

Distributed under the same terms as Vim itself. See <kbd>:help license</kbd>.

[plug]: https://github.com/junegunn/vim-plug
[qf-preview]: https://github.com/bfrg/vim-qf-preview
