-- User plugins
-- crates.nvim comes from astrocommunity.pack.rust (community.lua)

---@type LazySpec
return {
{
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },            -- if you use the mini.nvim suite
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.icons' },        -- if you use standalone mini plugins
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      -- Debian compiles parsers on the first start (nvim-treesitter); until
      -- markdown/markdown_inline exist, attaching would error on every .md
      ignore = function()
        for _, lang in ipairs { "markdown", "markdown_inline" } do
          local ok, added = pcall(vim.treesitter.language.add, lang)
          if not ok or not added then return true end
        end
        return false
      end,
    },
}
}
