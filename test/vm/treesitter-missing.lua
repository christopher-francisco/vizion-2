-- Prints LazyVim's treesitter parsers (nvim-treesitter's ensure_installed) that aren't installed,
-- one per line. Parsers nvim-treesitter no longer has can't be installed: printed as "unavailable: x".
-- Used by test/vm/assert.sh.
require("lazy").load({ plugins = { "nvim-treesitter" } })
local opts = require("lazy.core.plugin").values(require("lazy.core.config").plugins["nvim-treesitter"], "opts", false)
local available = require("nvim-treesitter.parsers")
local installed = {}
for _, lang in ipairs(require("nvim-treesitter.config").get_installed()) do installed[lang] = true end
for _, lang in ipairs(opts.ensure_installed or {}) do
  if not available[lang] then print("unavailable: " .. lang)
  elseif not installed[lang] then print(lang) end
end
