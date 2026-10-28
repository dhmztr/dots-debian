-- Mason installs the formatters conform.nvim uses (plugins/conform.lua) on
-- top of what the community packs already ask for.

---@type LazySpec
return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  opts = function(_, opts)
    opts.ensure_installed = require("astrocore").list_insert_unique(
      opts.ensure_installed or {},
      { "stylua", "shfmt", "prettier", "ruff", "fourmolu" }
    )
  end,
}
