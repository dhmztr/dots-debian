-- Customize None-ls sources

---@type LazySpec
return {
  "nvimtools/none-ls.nvim",
  opts = function(_, opts)
    local null_ls = require "null-ls"
    -- formatter binaries are installed by Mason (mason-tool-installer)
    opts.sources = require("astrocore").list_insert_unique(opts.sources, {
      null_ls.builtins.formatting.stylua,
      null_ls.builtins.formatting.shfmt,
      null_ls.builtins.formatting.prettier.with {
        filetypes = { "javascript", "typescript", "json", "yaml", "markdown" },
      },
    })
  end,
}
