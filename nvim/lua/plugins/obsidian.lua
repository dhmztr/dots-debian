-- obsidian.nvim (astrocommunity.note-taking.obsidian-nvim): use the vaults the
-- Obsidian app already knows, read from its own config, instead of the
-- community default ~/obsidian-vault. No vault there -> plugin stays off.

local function obsidian_vaults()
  -- .deb / AppImage, else the flatpak (md.obsidian.Obsidian)
  local f = io.open(vim.env.HOME .. "/.config/obsidian/obsidian.json", "r")
    or io.open(vim.env.HOME .. "/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json", "r")
  if not f then return {} end
  local ok, data = pcall(vim.json.decode, f:read "*a")
  f:close()
  local vaults = {}
  if ok and type(data) == "table" and type(data.vaults) == "table" then
    for _, v in pairs(data.vaults) do
      if type(v) == "table" and v.path and vim.fn.isdirectory(v.path) == 1 then
        table.insert(vaults, { name = vim.fn.fnamemodify(v.path, ":t"), path = v.path })
      end
    end
  end
  return vaults
end

local vaults = obsidian_vaults()
local events = {}
for _, v in ipairs(vaults) do
  local pattern = v.path:gsub(" ", "\\ ") .. "/*.md" -- autocmd patterns need escaped spaces
  table.insert(events, "BufReadPre " .. pattern)
  table.insert(events, "BufNewFile " .. pattern)
end

---@type LazySpec
return {
  "obsidian-nvim/obsidian.nvim",
  cond = #vaults > 0,
  event = events,
  opts = function(_, opts)
    opts.workspaces = vaults
    -- plain `obsidian://open` links; advanced-uri needs a community plugin
    opts.open = vim.tbl_extend("force", opts.open or {}, { use_advanced_uri = false })
    return opts
  end,
}
