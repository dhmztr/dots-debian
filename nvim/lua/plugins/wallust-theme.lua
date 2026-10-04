return {
  -- 1. install the neopywal plugin
  {
    "RedsXDD/neopywal.nvim",
    name = "neopywal",
    lazy = false, -- theme must load immediately at startup
    priority = 1000, -- very high priority so it loads before the UI
    opts = {
      -- optional: transparent background (true) if the terminal is transparent
      transparent_background = false,
    },
    config = function(_, opts)
      require("neopywal").setup(opts)
      vim.cmd.colorscheme("neopywal")

      -- Live reload: wallust rewrites this file on every wallpaper change, but a
      -- running nvim only reads it at startup - watch it and re-apply the theme.
      local wal = vim.fn.expand("~/.cache/wal/colors-wal.vim")
      local fse = vim.uv.new_fs_event()
      local function watch()
        fse:start(wal, {}, vim.schedule_wrap(function()
          pcall(function()
            package.loaded["neopywal.core"] = nil
            require("neopywal").setup(opts)
            vim.cmd.colorscheme("neopywal")
          end)
          -- editors replace the file (rename), so re-arm the watch on the new inode
          fse:stop()
          vim.defer_fn(watch, 100)
        end))
      end
      if vim.uv.fs_stat(wal) then watch() end
    end,
  },

  -- 2. tell AstroNvim to use this theme as the default
  {
    "AstroNvim/astroui",
    ---@type AstroUIOpts
    opts = {
      colorscheme = "neopywal",
    },
  },
}
