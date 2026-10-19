-- Neovide (the GUI): window settings, macOS shortcuts and scratch windows.
-- docs/requirements/0.6.0_GUI_EDITORS.md
--
-- A Neovide window started without files is a scratch window: its empty buffer has 'buftype'
-- nofile, so it is never written and never asks to be saved, and closing the window throws it away.
-- :Keep (or Cmd+S, or <leader>ww) saves it to a file and makes it an ordinary buffer.
local M = {}

--- Whether this Neovim runs a Neovide scratch window. Also read by plugins/ui.lua (no dashboard).
function M.is_scratch()
  return vim.g.neovide ~= nil and vim.fn.argc() == 0
end

--- Saves the current buffer: a scratch buffer to `path` (asked for when nil), any other with :write.
--- @param path string|nil
local function keep(path)
  local buf = vim.api.nvim_get_current_buf()
  if not vim.b[buf].scratch then
    vim.cmd("confirm write")
    return
  end
  local function save(name)
    if not name or name == "" then
      return
    end
    vim.bo[buf].buftype = ""
    local ok, err = pcall(vim.cmd, "confirm saveas " .. vim.fn.fnameescape(name))
    if ok and vim.api.nvim_buf_get_name(buf) ~= "" then
      vim.b[buf].scratch = nil
      pcall(vim.keymap.del, "n", "<leader>ww", { buffer = buf })
    else
      vim.bo[buf].buftype = "nofile"
      if not ok then
        vim.notify(err, vim.log.levels.ERROR)
      end
    end
  end
  if path then
    save(path)
  else
    vim.ui.input({ prompt = "Save as: ", completion = "file" }, save)
  end
end

local function scratch(buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.b[buf].scratch = true
  vim.keymap.set("n", "<leader>ww", keep, { buffer = buf, desc = "Keep Scratch (Save As)" })
end

function M.setup()
  vim.o.guifont = "IntoneMono NF:h16"
  vim.o.linespace = 8 -- close to the iTerm profiles' 1.5 vertical spacing
  vim.g.neovide_input_macos_option_key_is_meta = "both" -- as iTerm's Option (word jumps, <A-j>/<A-k>)
  vim.g.neovide_cursor_animation_length = 0.05

  -- The Cmd shortcuts every macOS app has
  local map = vim.keymap.set
  map("n", "<D-s>", keep, { desc = "Save (Keep Scratch)" })
  map("i", "<D-s>", function()
    vim.cmd.stopinsert()
    keep()
  end, { desc = "Save (Keep Scratch)" })
  map("n", "<D-w>", "<cmd>confirm qa<cr>", { desc = "Close Window" })
  map("x", "<D-c>", '"+y', { desc = "Copy" })
  map({ "n", "x" }, "<D-v>", '"+P', { desc = "Paste" })
  map("i", "<D-v>", "<C-r><C-o>+", { desc = "Paste" })
  map("c", "<D-v>", "<C-r>+", { desc = "Paste" })
  map("t", "<D-v>", [[<C-\><C-n>"+pi]], { desc = "Paste" })

  vim.api.nvim_create_user_command("Keep", function(args)
    keep(args.args ~= "" and args.args or nil)
  end, { nargs = "?", complete = "file", desc = "Save a scratch buffer to a file" })

  if M.is_scratch() then
    scratch(vim.api.nvim_get_current_buf())
  end
end

return M
