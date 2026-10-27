---@type LazySpec
return {
  -- conform: prettierd for web filetypes
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        javascript = { "prettierd" },
        typescript = { "prettierd" },
        javascriptreact = { "prettierd" },
        typescriptreact = { "prettierd" },
        css = { "prettierd" },
        html = { "prettierd" },
        json = { "prettierd" },
        yaml = { "prettierd" },
        -- keep the lang.markdown extra's fixers; lists replace rather than merge
        markdown = { "prettierd", "markdownlint-cli2", "markdown-toc" },
        graphql = { "prettierd" },
      },
    },
    -- <leader>cf is already provided by LazyVim via LazyVim.format()
  },

  -- render-markdown: the lang.markdown extra sets heading.icons = {}, which
  -- leaves the raw # showing; restore the plugin's icons and nvim-legacy's setting
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      anti_conceal = { enabled = false },
      heading = {
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
    },
  },

  -- blink.cmp: like nvim-legacy's nvim-cmp, select nothing until <C-n>/<C-p>,
  -- insert the selection as you move, and let <CR> fall through when nothing is selected
  {
    "saghen/blink.cmp",
    opts = {
      completion = {
        list = { selection = { preselect = false, auto_insert = true } },
      },
    },
  },

  -- LuaSnip: restore jump keymaps (friendly-snippets loaded by extra)
  {
    "L3MON4D3/LuaSnip",
    keys = {
      { "<c-j>", function() require("luasnip").jump(1) end, mode = { "i", "s" }, desc = "Next Snippet" },
      { "<c-k>", function() require("luasnip").jump(-1) end, mode = { "i", "s" }, desc = "Prev Snippet" },
    },
  },

  -- nvim-lint: no active linters (eslint handled by lang.typescript extra)
  {
    "mfussenegger/nvim-lint",
    opts = { linters_by_ft = {} },
  },
}
