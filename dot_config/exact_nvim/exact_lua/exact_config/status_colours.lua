-- Colours for the statusline parts that copy the tmux status bar (plugins/ui.lua): the tmux-status.nvim
-- components and the active tab. Read from the tmux theme of the loaded colour scheme and 'background'
-- (~/.config/tmux/themes/<scheme>-<dark|light>.tmux.conf, the file tmux sources), so both bars use the
-- same colours, in and outside tmux. Without one (another colour scheme) the parts keep their section's.
local M = {}

--- The tmux theme's options, resolved: { text_selected = "#f7768e", ... }
--- @return table<string, string>
function M.options()
  local scheme = (vim.g.colors_name or ""):match("^[^-]+") -- "tokyonight-night" → "tokyonight"
  local path = ("%s/.config/tmux/themes/%s-%s.tmux.conf"):format(vim.env.HOME, scheme, vim.o.background)
  local ok, lines = pcall(vim.fn.readfile, path)
  local vars, options = {}, {}
  for _, line in ipairs(ok and lines or {}) do
    local name, hex = line:match("^([%w_]+)=[\"']?(#%x+)")
    if name then
      vars[name] = hex
    end
    local option, value = line:match("^set %-g @([%w_]+) [\"']?([^\"'%s]+)")
    if option then
      options[option] = value:match("^#%x+$") or vars[value:match("^%$([%w_]+)$") or ""]
    end
  end
  return options
end

--- tmux-status.nvim's `colors`: see-through, like tmux's `status-style bg=default`.
function M.tmux_status()
  local options = M.options()
  local function colour(option)
    return { fg = options[option], bg = "NONE" }
  end
  return {
    window_active = colour("text_selected"),
    window_inactive = colour("text_unselected"),
    window_inactive_recent = colour("text_unselected_recent"),
    session = colour("text_active"),
    datetime = colour("text_secondary"),
    battery = colour("text_main"), -- no colour in tmux: the terminal's foreground
  }
end

--- Now and after every colour scheme change: the `VizionTabActive` highlight (the tabline's active tab)
--- and a see-through `StatusLine` (Neovim fills in what statusline highlights leave unset, such as the
--- vizion lualine theme's backgrounds, from `StatusLine`).
function M.setup()
  local function set()
    vim.api.nvim_set_hl(0, "VizionTabActive", { fg = M.options().text_selected })
    local statusline = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
    vim.api.nvim_set_hl(0, "StatusLine", vim.tbl_extend("force", statusline, { bg = "NONE" }))
  end
  set()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("status_colours", {}),
    callback = set,
  })
end

return M
