-- Prints the Mason packages LazyVim should have installed, one per line: its own ensure_installed
-- plus a package for every enabled LSP server that Mason can install. Used by test/vm/assert.sh.
require("lazy").load({ plugins = { "mason.nvim", "mason-lspconfig.nvim", "nvim-lspconfig" } })
local want = {}
for _, n in ipairs(require("lazy.core.config").plugins["mason.nvim"] and require("lazy.core.plugin").values(require("lazy.core.config").plugins["mason.nvim"], "opts", false).ensure_installed or {}) do want[#want+1] = n end
local lsp = require("lazy.core.plugin").values(require("lazy.core.config").plugins["nvim-lspconfig"], "opts", false)
local map = require("mason-lspconfig").get_mappings().lspconfig_to_package
for server, o in pairs(lsp.servers or {}) do
  if server ~= "*" and o ~= false and (type(o) ~= "table" or (o.enabled ~= false and o.mason ~= false)) and map[server] then want[#want+1] = map[server] end
end
table.sort(want); print(table.concat(want, "\n"))
