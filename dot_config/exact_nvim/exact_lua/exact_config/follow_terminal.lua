-- Follow the colour scheme and light/dark of the iTerm window Neovim is shown in.
-- docs/requirements/0.3.0_COLOUR_SCHEME_SYNC.md
--
-- Inside tmux, tmux decides (tmux/theme.sh, the window in use: attached, focused, appearance
-- changed) and calls apply() here; at startup Neovim reads tmux's choice (@theme). Asking the terminal
-- through tmux would get the first attached window's colours, not the one in use.
-- Outside tmux, ask iTerm for its background (OSC 11) at startup and on every focus and load the
-- scheme whose iTerm background is nearest (config.theme); light/dark is Neovim's own: it sets
-- 'background' from the same answer and from iTerm's light/dark notifications.
-- No config may set 'background' at startup, or Neovim stops following the terminal's light/dark.
local M = {}

-- A background further than this from every scheme's (0-255 per channel) belongs to another
-- terminal: keep the scheme. Close enough for colours iTerm converts between colour spaces.
local max_distance = 40

local function hex_rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

--- The scheme whose background is nearest an OSC 11 answer, or nil.
--- @param sequence string e.g. "\27]11;rgb:1a1a/1b1b/2626"
--- @return string|nil
function M.scheme_for(sequence)
  local channels = { sequence:match("^\27%]11;rgba?:(%x+)/(%x+)/(%x+)") }
  if #channels ~= 3 then
    return nil
  end
  local rgb = vim.tbl_map(function(h) -- 1 to 4 hex digits per channel
    return tonumber(h, 16) / (16 ^ #h - 1) * 255
  end, channels)
  local best, best_distance
  for scheme, backgrounds in pairs(require("config.theme").backgrounds) do
    for _, hex in ipairs(backgrounds) do
      local r, g, b = hex_rgb(hex)
      local distance = math.sqrt((rgb[1] - r) ^ 2 + (rgb[2] - g) ^ 2 + (rgb[3] - b) ^ 2)
      if not best_distance or distance < best_distance then
        best, best_distance = scheme, distance
      end
    end
  end
  return best_distance and best_distance <= max_distance and best or nil
end

--- Loads a scheme unless it's loaded already ("tokyonight-night"/"tokyonight-day", "everforest").
local function load(scheme)
  if not vim.startswith(vim.g.colors_name or "", scheme) then
    vim.cmd.colorscheme(scheme)
  end
end

--- Called by tmux/theme.sh (through `nvim --server`): the scheme and light/dark of the window in use.
--- @param scheme string e.g. "everforest"
--- @param appearance "dark"|"light"
function M.apply(scheme, appearance)
  vim.schedule(function() -- not inside the remote call's expression evaluation
    if vim.o.background ~= appearance then
      vim.o.background = appearance -- reloads the loaded scheme in that variant
    end
    load(scheme)
  end)
  return ""
end

local function in_tmux()
  local group = vim.api.nvim_create_augroup("follow_terminal", {})
  local pane = vim.env.TMUX_PANE
  local function tmux(args)
    return vim.system(vim.list_extend({ "tmux" }, args), { text = true }):wait()
  end
  -- Neovim's own light/dark following would take the first attached window's: tmux says instead.
  local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { group = "nvim.tty", event = "TermResponse" })
  for _, autocmd in ipairs(ok and autocmds or {}) do
    if (autocmd.desc or ""):find("'background'") then
      vim.api.nvim_del_autocmd(autocmd.id)
    end
  end
  -- So tmux/theme.sh can reach this Neovim.
  if pane and vim.v.servername ~= "" then
    tmux({ "set", "-p", "-t", pane, "@nvim_server", vim.v.servername })
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = group,
      callback = function()
        tmux({ "set", "-p", "-u", "-t", pane, "@nvim_server" })
      end,
    })
  end
  local scheme, appearance = vim.trim(tmux({ "show", "-gv", "@theme" }).stdout or ""):match("^(.+)%-(%a+)$")
  if scheme then
    vim.o.background = appearance
    -- after the startup colour scheme (LazyVim loads its default later than this runs)
    vim.api.nvim_create_autocmd("UIEnter", {
      group = group,
      once = true,
      callback = function()
        M.apply(scheme, appearance)
      end,
    })
  end
end

local function outside_tmux()
  local group = vim.api.nvim_create_augroup("follow_terminal", {})
  vim.api.nvim_create_autocmd("TermResponse", {
    group = group,
    callback = function(ev)
      local scheme = M.scheme_for(ev.data.sequence)
      if scheme then
        vim.schedule(function()
          load(scheme)
        end)
      end
    end,
  })
  -- Neovim's own query at startup runs before the config, so ask again once the UI is up.
  vim.api.nvim_create_autocmd({ "UIEnter", "FocusGained" }, {
    group = group,
    callback = function()
      vim.api.nvim_ui_send("\27]11;?\7")
    end,
  })
end

function M.setup()
  -- `nvim --headless` (chezmoi's plugin sync, scripts) has no window to colour. Neovide and VS Code
  -- have no terminal to ask: Neovide sets light/dark from macOS, VS Code draws its own theme.
  if vim.list_contains(vim.v.argv, "--headless") or vim.g.neovide or vim.g.vscode then
    return
  end
  if vim.env.TMUX then
    in_tmux()
  else
    outside_tmux()
  end
end

return M
