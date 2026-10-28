-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.rust" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.pack.bash" },
  { import = "astrocommunity.pack.typescript" },
  { import = "astrocommunity.editing-support.conform-nvim" },
  { import = "astrocommunity.pack.haskell" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.toml" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.fish" },
  -- notes: vault(s) read from Obsidian's own config, see plugins/obsidian.lua
  { import = "astrocommunity.note-taking.obsidian-nvim" },
  { import = "astrocommunity.markdown-and-latex.render-markdown-nvim" },
  -- navigation: s = flash jump, <Leader>- yazi, <Leader>O oil
  { import = "astrocommunity.motion.flash-nvim" },
  { import = "astrocommunity.file-explorer.yazi-nvim" },
  { import = "astrocommunity.file-explorer.oil-nvim" },
  -- git / code: diffview, trouble (<Leader>x), TODOs, project-wide replace
  { import = "astrocommunity.git.diffview-nvim" },
  { import = "astrocommunity.diagnostics.trouble-nvim" },
  { import = "astrocommunity.editing-support.todo-comments-nvim" },
  { import = "astrocommunity.search.grug-far-nvim" },
  -- import/override with your plugins folder
}
