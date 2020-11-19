# vim-qf-diagnostics

- Highlight the diagnostics (of a project-build, linter, grep) stored in a
  quickfix list in the buffer and sign column.
- Display the error message for the current line in a popup window next to the
  cursor.

![screenshots](https://user-images.githubusercontent.com/6266600/86536450-01328680-bee8-11ea-849f-4e24809515b9.png)

## Usage

### Popup window

* **`<plug>(qf-diagnostics-popup-quickfix)`** Display a popup window at the
  current cursor position with the error message found for the current line in
  the `quickfix` list. If the line contains several errors, all entries are
  collected and displayed in the same popup window.
* **`<plug>(qf-diagnostics-popup-loclist)`** Same as above but display the error
  messages from the current `location-list` of the current window.

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

### Diagnostics highlights

The diagnostics from the quickfix and location list can be displayed in the sign
column as well as highlighted directly in the buffer.

| Command                 | Description                                                                          |
| ----------------------- | ------------------------------------------------------------------------------------ |
| `:DiagnosticsPlace`     | Highlight the diagnostics from the current quickfix list.                            |
| `:LDiagnosticsPlace`    | Same as `:DiagnosticsPlace` but use the current location list of the current window. |
| `:DiagnosticsClear`     | Remove the highlights placed by `:DiagnosticsPlace`.                                 |
| `:LDiagnosticsClear[!]` | Remove the highlights placed by `:LDiagnosticsPlace`.                                |
| `:DiagnosticsToggle`    | Toggle the highlighting of the diagnostics from the quickfix list.                   |
| `:LDiagnosticsToggle`   | Toggle the highlighting of the diagnostics from the location list.                   |

**Notes:**
* `:DiagnosticsPlace` and `:LDiagnosticsPlace` will first remove the highlights
  if any have been previously placed by the same command.
* `:LDiagnosticsPlace` can be run in multiple window to simultaneously highlight
  diagnostics from several location lists.
* `:LDiagnosticsClear` must always be run in the same windows where
  `:LDiagnosticsPlace` has been executed to remove the previously placed
  highlights.
* To remove the highlightings of all diagnostics from all location lists at
  once, run `:LDiagnosticsClear!`.
* For convenience the following mappings are provided for toggling the
  diagnostics:
  - **`<plug>(qf-diagnostics-toggle-quickfix)`** Toggle the diagnostics from the
    quickfix list.
  - **`<plug>(qf-diagnostics-toggle-loclist)`** Toggle the diagnostics from the
    location list of the current window.

#### Examples

1. Toggle the diagnostics of the quickfix and location lists with <kbd>F7</kbd>
   and <kbd>F8</kbd>, respectively:
   ```vim
   nmap <F7> <plug>(qf-diagnostics-toggle-quickfix)
   nmap <F8> <plug>(qf-diagnostics-toggle-loclist)
   ```
2. If you want to place the diagnostics automatically after running `:make` or
   `:lmake`, add the following to your `vimrc`:
   ```vim
   augroup qf-make-signs
       autocmd!
       autocmd QuickfixCmdPost  make  DiagnosticsPlace
       autocmd QuickfixCmdPost lmake LDiagnosticsPlace
   augroup END
   ```


## Configuration

The appearance of the popup window, the signs and text highlights can be
configured through the variable `g:qfdiagnostics`. For all supported entries,
see `:help qf-diagnostics-config`, and `:help qf-diagnostics-examples` for a few
examples.

All highlighting groups used in the popup window are described in `:help
qf-dagnostics-popup-highlight`.


## Installation

```bash
$ cd ~/.vim/pack/git-plugins/start
$ git clone https://github.com/bfrg/vim-qf-diagnostics
$ vim -u NONE -c 'helptags ALL' -c q
```
**Note:** The directory name `git-plugins` is arbitrary, you can pick any other
name. For more details see `:help packages`. Alternatively use your favorite
plugin manager.


## License

Distributed under the same terms as Vim itself. See `:help license`.

[plug]: https://github.com/junegunn/vim-plug
