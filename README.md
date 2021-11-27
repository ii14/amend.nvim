# amend.nvim

Work in progress.

`g.` or `:Amend` to edit and rerun last normal mode command.

For example, if you messed up a count for delete command and deleted too much, like `d7w`,
you can `u` to undo and then `g.` to put that last command on the command line, where it
can be edited to for example `d6w`.

A count after `:Amend` can be given to rerun the last command with incremented or
decremented count, for example `:Amend+`, `:Amend-`, `:Amend+3`, `:Amend-2`.

`:Amend?` prints the last normal command.

### TODO

- `c/C/s/S` commands
- Extensions for vim-surround, vim-commentary, targets.vim etc.

### BUGS

- targets.vim messes up `i/p` commands, like `diw` or `dap`.
