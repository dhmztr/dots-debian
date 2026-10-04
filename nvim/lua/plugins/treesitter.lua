-- Customize Treesitter
-- Parsers are compiled locally by nvim-treesitter: needs a C compiler
-- (build-essential) and the tree-sitter CLI (see the README).

-- Compatibility shim: astrocore calls nvim-treesitter.get_installed() which was removed
-- in newer nvim-treesitter. Patch it to use the current API.
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyLoad",
  once = true,
  callback = function()
    local ok, ts = pcall(require, "nvim-treesitter")
    if ok and ts and not ts.get_installed then
      ts.get_installed = function()
        local ok2, parsers = pcall(require, "nvim-treesitter.parsers")
        if ok2 then return parsers.available_parsers() end
        return {}
      end
    end
  end,
})

---@type LazySpec
return {
  "AstroNvim/astrocore",
  opts = function(_, opts)
    opts.treesitter = opts.treesitter or {}
    opts.treesitter.highlight = true
    opts.treesitter.indent = true
    -- the community packs add their languages; these cover the rest of the config
    opts.treesitter.ensure_installed = require("astrocore").list_insert_unique(
      opts.treesitter.ensure_installed or {},
      { "vim", "vimdoc", "lua", "bash", "fish", "json", "yaml", "toml", "markdown", "markdown_inline", "regex" }
    )
  end,
}
