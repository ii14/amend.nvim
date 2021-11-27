# amend.nvim

`g.` or `:Amend` to amend and rerun last normal mode command

For example, if you messed up a count for delete command and deleted too much, like `d7w`,
you can `u` to undo and then `g.` to put that last command on the command line, where it
can be edited to for example `d6w`.

### TODO

- `c/C/s/S` commands
- `f/F/t/T` motions
- Extensions for vim-surround, vim-commentary, targets.vim etc.
- A quick way of rerunning the command with count incremented/decremented.

### BUGS

- targets.vim messes up `i/p` commands, like `diw` or `dap`.
- Something's wrong with the lookup table. Sometimes some nodes are randomly not
  constructed properly, and as a result some commands are not saved.
