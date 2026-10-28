-- Override the astrocommunity haskell pack (mrcjkb/haskell-tools.nvim).
-- Some HLS code-lens plugins run a "rule" that needs the module to type-check;
-- on non-compiling modules they surface noisy -32803 errors, e.g.
--   importLens: Rule Failed: ImportActions        (hls-explicit-imports-plugin)
--   explicit-fields: Rule Failed: CollectRecords  (hls-explicit-record-fields-plugin)
-- Disable those plugins; the rest of HLS (diagnostics, hover, completion, other
-- code actions) is untouched.

-- Those two plugins were also the only HLS inlay-hint providers, so disabling
-- them makes an inlay-hint request fail with
--   -32601: No plugins are available to handle this ...InlayHint request.
-- Stop asking HLS for inlay hints on Haskell buffers so nothing requests them.

---@type LazySpec
return {
  "mrcjkb/haskell-tools.nvim",
  init = function()
    local ht = vim.g.haskell_tools or {}
    ht.hls = ht.hls or {}
    ht.hls.default_settings = vim.tbl_deep_extend("force", ht.hls.default_settings or {}, {
      haskell = {
        plugin = {
          importLens = { globalOn = false },
          ["explicit-fields"] = { globalOn = false },
        },
      },
    })
    vim.g.haskell_tools = ht

    vim.api.nvim_create_autocmd("LspAttach", {
      desc = "Hide inlay-hint capability on Haskell buffers (no HLS provider once the noisy plugins are off)",
      callback = function(args)
        if vim.bo[args.buf].filetype ~= "haskell" then
          return
        end
        -- Synchronous, not scheduled: astrolsp's own on_attach (features.inlay_hints)
        -- also runs on LspAttach and calls inlay_hint.enable(true, ...); a scheduled
        -- disable here can lose that race and leave one real request in flight that
        -- HLS then fails ("-32601: No plugins are available to handle ... InlayHint").
        -- Clearing the capability means nothing ever asks this client for hints.
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client then client.server_capabilities.inlayHintProvider = nil end
      end,
    })
  end,
}
