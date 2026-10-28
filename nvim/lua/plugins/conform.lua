-- Formatters for conform.nvim (astrocommunity.editing-support.conform-nvim).
-- conform runs format-on-save; a filetype without an entry here falls back to
-- its LSP (rust-analyzer, taplo, ...). The binaries come from Mason
-- (plugins/mason.lua) or rustup.
-- Replaces the old none-ls sources, which ran on every save next to AstroLSP.

---@type LazySpec
return {
  "stevearc/conform.nvim",
  opts = function(_, opts)
    local prettier = { "prettier" }
    -- force: overrides pack defaults such as black/isort
    opts.formatters_by_ft = vim.tbl_extend("force", opts.formatters_by_ft or {}, {
      lua = { "stylua" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      python = { "ruff_organize_imports", "ruff_format" },
      javascript = prettier,
      typescript = prettier,
      javascriptreact = prettier,
      typescriptreact = prettier,
      json = prettier,
      yaml = prettier,
      markdown = prettier,
    })
  end,
}
