
-- AstroLSP allows you to customize the features in AstroNvim's LSP configuration engine
-- Configuration documentation can be found with `:h astrolsp`

---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    features = {
      codelens = true,
      inlay_hints = true,
      semantic_tokens = true,
    },
    -- no `formatting` block: conform.nvim (community.lua) owns formatting and
    -- format-on-save and disables AstroLSP's with `formatting.disabled = true`.
    -- The old `disabled = {}` here overrode that, so every save ran both.
    -- Language servers are installed by Mason (the community packs add them to
    -- its ensure_installed). rust-analyzer comes from rustup and is set up by
    -- rustaceanvim (astrocommunity.pack.rust) - it must NOT be listed here, or
    -- astrolsp starts a second client. clangd from apt (clangd) or Mason.
    servers = {},
    config = {
      rust_analyzer = {
        settings = {
          ["rust-analyzer"] = {
            -- upstream rust-analyzer bug: term-search for typed-hole
            -- diagnostics panics ("failed to unify type owners") on
            -- every diagnostic request in some codebases
            diagnostics = { disabled = { "typed-hole" } },
            cargo = {
              features = "all",
              buildScripts = { enable = true },
              allTargets = true,
            },
            procMacro = { enable = true },
            checkOnSave = true,
            imports = {
              granularity = { group = "module" },
              prefix = "self",
            },
            inlayHints = {
              typeHints = { enable = true },
              parameterHints = { enable = true },
              chainingHints = { enable = true },
              bindingModeHints = { enable = true },
              closingBraceHints = { enable = true },
              closureReturnTypeHints = { enable = "with_block" },
            },
            lens = {
              enable = true,
              run = { enable = true },
              debug = { enable = true },
              implementations = { enable = true },
              references = {
                adt = { enable = false },
                enumVariant = { enable = false },
                method = { enable = false },
                trait = { enable = false },
              },
            },
          },
        },
      },
    },
    autocmds = {
      lsp_codelens_refresh = {
        cond = "textDocument/codeLens",
        {
          event = { "InsertLeave", "BufEnter" },
          desc = "Refresh codelens (buffer)",
          callback = function(args)
            if require("astrolsp").config.features.codelens then
              vim.lsp.codelens.enable(true, { bufnr = args.buf })
            end
          end,
        },
      },
    },
    mappings = {
      n = {
        gD = {
          function() vim.lsp.buf.declaration() end,
          desc = "Declaration of current symbol",
          cond = "textDocument/declaration",
        },
        ["<Leader>uY"] = {
          function() require("astrolsp.toggles").buffer_semantic_tokens() end,
          desc = "Toggle LSP semantic highlight (buffer)",
          cond = function(client)
            return client:supports_method "textDocument/semanticTokens/full"
              and vim.lsp.semantic_tokens ~= nil
          end,
        },
      },
    },
  },
}
