-- Prints the plugins lazy.nvim has enabled for this config, one per line (disabled ones stay in
-- lazy-lock.json but are never installed). Used by test/vm/assert.sh.
for name in pairs(require("lazy.core.config").plugins) do print(name) end
