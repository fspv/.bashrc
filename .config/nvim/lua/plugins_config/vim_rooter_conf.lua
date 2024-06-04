-- Doc: https://github.com/airblade/vim-rooter
vim.g.rooter_manual_only = 0
vim.g.rooter_patterns = {
  '.git',
  '_darcs',
  '.hg',
  '.bzr',
  '.svn',
  'Makefile',
  'package.json',
  -- To cd for files residing in /tmp
  -- this may break something else, so worth revisiting later
  '>tmp',
  'go[1-9].*'
}
