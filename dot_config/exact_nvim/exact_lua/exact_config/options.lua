-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.cmdheight = 0
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 0 -- follow tabstop
vim.opt.virtualedit = "block"
vim.opt.fillchars:append({ eob = " " })
vim.opt.grepprg = "rg --vimgrep --hidden"
vim.opt.spelloptions:append("noplainbuffer")
vim.opt.statuscolumn = "%=%{v:relnum?v:relnum:v:lnum} %s%C"
vim.opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
vim.opt.wildmode = "longest,full"

-- Colour scheme and light/dark from the terminal window (config/follow_terminal.lua)
require("config.follow_terminal").setup()

-- Neovide: GUI settings and scratch windows (config/neovide.lua)
if vim.g.neovide then
  require("config.neovide").setup()
end
