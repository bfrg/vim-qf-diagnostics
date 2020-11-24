# vim-qf-diagnostics

- Highlight the diagnostics (of a project-build, linter, `grep`) stored in a
  quickfix list in the buffer and sign column.
- Display the error message for the current line in a popup window next to the
  cursor.

![screenshots](https://user-images.githubusercontent.com/6266600/86536450-01328680-bee8-11ea-849f-4e24809515b9.png)

## Usage

### Popup window

* **`<plug>(qf-diagnostics-popup-quickfix)`** - Display a popup window at the
  current cursor position with the error message found for the current line in
  the `quickfix` list. If the line contains several errors, all entries are
  collected and displayed in the same popup window.
* **`<plug>(qf-diagnostics-popup-loclist)`** - Same as above but display the
  error messages from the current `location-list` of the current window.

If not all quickfix errors (for the current line) fit into the popup window, a
scrollbar will appear on the right side. The popup window can then be scrolled
with <kbd>CTRL-J</kbd> and <kbd>CTRL-K</kbd>, or alternatively, using the mouse
wheel. Pressing <kbd>CTRL-C</kbd> or moving the cursor in any direction will
close the popup window.

#### Examples

```vim
nmap gh <plug>(qf-diagnostics-popup-quickfix)
nmap gH <plug>(qf-diagnostics-popup-loclist)
```

### Signs and text highlightings

The items in the quickfix and location list can be highlighted in the sign
column and in the buffer directly. Both highlightings are optional and can be
individually configured in [`g:qfdiagnostics`](#configuration). By default, only
signs are placed.

| Command                 | Description                                                                          |
| ----------------------- | ------------------------------------------------------------------------------------ |
| `:DiagnosticsPlace`     | Highlight the diagnostics from the current quickfix list.                            |
| `:LDiagnosticsPlace`    | Same as `:DiagnosticsPlace` but use the current location list of the current window. |
| `:DiagnosticsClear`     | Remove the highlightings placed by `:DiagnosticsPlace`.                              |
| `:LDiagnosticsClear[!]` | Remove the highlightings placed by `:LDiagnosticsPlace`.                             |
| `:DiagnosticsToggle`    | Toggle the diagnostics from the quickfix list.                                       |
| `:LDiagnosticsToggle`   | Toggle the diagnostics from the location list.                                       |

**Notes:**
* `:DiagnosticsPlace` and `:LDiagnosticsPlace` will first remove any
  highlightings that have been previously placed by the respective command.
* `:LDiagnosticsPlace` can be run in multiple windows to simultaneously
  highlight diagnostics from several location lists.
* `:LDiagnosticsClear` must always be run in the same window where
  `:LDiagnosticsPlace` has been executed to remove the previously placed
  diagnostics.
* To remove the highlightings of all diagnostics from all location lists at
  once, run `:LDiagnosticsClear!`.

#### Examples

1. Toggle the diagnostics of the quickfix and location lists with <kbd>F7</kbd>
   and <kbd>F8</kbd>, respectively:
   ```vim
   nnoremap <F7> <Cmd>DiagnosticsToggle<Cr>
   nnoremap <F8> <Cmd>LDiagnosticsToggle<Cr>
   ```
2. If you want to place the diagnostics automatically after running `:make` or
   `:lmake`, add the following to your `vimrc`:
   ```vim
   augroup qf-diagnostics-user
       autocmd!
       autocmd QuickfixCmdPost  make  DiagnosticsPlace
       autocmd QuickfixCmdPost lmake LDiagnosticsPlace
   augroup END
   ```


## Configuration

The appearance of the popup window, the signs and text highlightings can be
configured through the variable `g:qfdiagnostics`. For all supported entries,
see `:help qf-diagnostics-config`, and `:help qf-diagnostics-examples` for a few
examples.

All highlighting groups used in the popup window are described in `:help
qf-dagnostics-popup-highlight`.


## Installation

```bash
$ cd ~/.vim/pack/git-plugins/start
$ git clone https://github.com/bfrg/vim-qf-diagnostics
$ vim -u NONE -c 'helptags vim-qf-diagnostics/doc | quit'
```
**Note:** The directory name `git-plugins` is arbitrary, you can pick any other
name. For more details see `:help packages`. Alternatively, use your favorite
plugin manager.


## License

Distributed under the same terms as Vim itself. See `:help license`.
