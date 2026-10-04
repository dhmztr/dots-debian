-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 },
      autopairs = true,
      cmp = true,
      diagnostics = { virtual_text = true, virtual_lines = false },
      highlighturl = true,
      notifications = true,
    },
    diagnostics = {
      virtual_text = true,
      underline = true,
    },
    options = {
      opt = {
        relativenumber = true,
        number = true,
        spell = false,
        signcolumn = "yes",
        wrap = false,
        scrolloff = 8,
        sidescrolloff = 8,
        tabstop = 2,
        shiftwidth = 2,
        expandtab = true,
        colorcolumn = "100",
        autoindent = true,
        smartindent = true,
      },
      g = {},
    },
    autocmds = {
      luasnip_unlink = {
        {
          event = "InsertLeave",
          desc = "Forget stale luasnip session so Tab stops jumping to old placeholders",
          callback = function()
            local ok, luasnip = pcall(require, "luasnip")
            if
              ok
              and luasnip.session
              and luasnip.session.current_nodes[vim.api.nvim_get_current_buf()]
              and not luasnip.session.jump_active
            then
              luasnip.unlink_current()
            end
          end,
        },
      },
    },
    mappings = {
      n = {
        ["]b"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["[b"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },
        ["<Leader>bd"] = {
          function()
            require("astroui.status.heirline").buffer_picker(
              function(bufnr) require("astrocore.buffer").close(bufnr) end
            )
          end,
          desc = "Close buffer from tabline",
        },
        -- force-close the current buffer (prevents <Space>bD falling through to
        -- the `b` + `D` motions, which used to delete to end of line)
        ["<Leader>bD"] = {
          function() require("astrocore.buffer").close(0, true) end,
          desc = "Force close buffer",
        },
        ["<Leader>w"] = { "<Cmd>w<CR>", desc = "Save file" },
        ["<Leader>uI"] = {
          function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end,
          desc = "Toggle inlay hints",
        },
        -- screenshot mode: strip the visual noise (inlay hints, inline diagnostics,
        -- colorcolumn, fold column, relative numbers) for clean rice shots, and
        -- restore everything on the second press
        ["<Leader>uS"] = {
          function()
            local on = not vim.g.screenshot_mode
            vim.g.screenshot_mode = on
            vim.lsp.inlay_hint.enable(not on)
            vim.diagnostic.config { virtual_text = not on }
            for _, win in ipairs(vim.api.nvim_list_wins()) do
              vim.wo[win].colorcolumn = on and "" or "100"
              vim.wo[win].foldcolumn = on and "0" or "1"
              vim.wo[win].relativenumber = not on
            end
            vim.notify("Screenshot mode " .. (on and "on" or "off"))
          end,
          desc = "Toggle screenshot mode",
        },
      },
    },
  },
}
