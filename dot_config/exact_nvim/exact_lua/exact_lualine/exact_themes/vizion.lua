-- Lualine theme in the look of the tmux status bar (tmux/themes/minimal.tmux.conf): the loaded colour
-- scheme's own lualine theme without backgrounds (tmux: `status-style bg=default`) and with the mode as
-- coloured text instead of a block. Lualine runs this file again on every colour scheme and 'background'
-- change, so it follows config/follow_terminal.lua.
local theme = require("lualine.utils.loader").load_theme("auto") -- a fresh table on every load
local everforest = vim.startswith(vim.g.colors_name or "", "everforest")

for name, mode in pairs(theme) do
  if mode.a and name ~= "inactive" then -- inactive (the tabline's other tabs): its bg is a background
    mode.a.fg, mode.a.gui = mode.a.bg, ""
  end
  if everforest and mode.b and mode.c then
    mode.c.fg = mode.b.fg -- as nvim-legacy
  end
  for _, section in pairs(mode) do
    section.bg = nil
  end
end

return theme
