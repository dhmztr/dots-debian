-- Runs last in setup (required by init.lua).

-- nvim 0.12 runtime bug: the inlay-hint decoration provider can place a hint
-- past the end of its line (seen with basedpyright in Python), and
-- nvim_buf_set_extmark then throws "Invalid 'col': out of range" on every
-- redraw. Clamp the column for that namespace only; everything else goes to
-- the real function untouched. Remove once upstream fixes it.
do
  local set_extmark = vim.api.nvim_buf_set_extmark
  local inlay_ns
  vim.api.nvim_buf_set_extmark = function(buf, ns, line, col, opts)
    inlay_ns = inlay_ns or vim.api.nvim_get_namespaces()["nvim.lsp.inlayhint"]
    if ns ~= nil and ns == inlay_ns then
      local text = vim.api.nvim_buf_get_lines(buf, line, line + 1, false)[1]
      if text == nil then return 0 end -- line no longer exists: skip the hint
      if col > #text then col = #text end
    end
    return set_extmark(buf, ns, line, col, opts)
  end
end
