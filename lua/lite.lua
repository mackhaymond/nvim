-- Lite plugin set for remote boxes (seasnet / lnxsrv, or NVIM_LITE=1).
--
-- Keeps how editing FEELS — colors, treesitter, completion keys, pairs,
-- surround, statusline, cmdline, motions, file nav — and drops everything
-- heavy or integration-y (LSP + Mason, copilot, codesnap, dap, git, …). The
-- remote has a disk quota; copilot.lua alone is ~400MB and Mason ~300MB.
--
-- Selected from the same lua/plugins/*.lua files the Mac loads, so a tweak to
-- any kept plugin applies on both machines. Plugins pulled in by a kept file
-- that don't belong in lite are switched off below with enabled = false.
local M = {}

M.spec = {
    { import = "plugins.colorscheme" },
    { import = "plugins.treesitter" },
    { import = "plugins.lsp" }, -- for blink.cmp + LuaSnip; the LSP half is disabled below
    { import = "plugins.autopairs" },
    { import = "plugins.surround" },
    { import = "plugins.repeat" },
    { import = "plugins.lualine" },
    { import = "plugins.noice" },
    { import = "plugins.hardtime" },
    { import = "plugins.oil" },
    { import = "plugins.telescope" },
    { import = "plugins.grapple" },   -- telescope's config loads its extension
    { import = "plugins.undotree" },
    { import = "plugins.tmux" },
    { import = "plugins.wrapping" },  -- after/ftplugin/{markdown,tex}.lua require it

    { "nvim-lua/plenary.nvim", lazy = true }, -- telescope needs it; the Mac gets it via other files

    -- plugins/lsp.lua, minus the language-server half
    { "neovim/nvim-lspconfig",          enabled = false },
    { "mason-org/mason.nvim",           enabled = false },
    { "williamboman/mason-lspconfig.nvim", enabled = false },
    { "nvimtools/none-ls.nvim",         enabled = false },
    { "jay-babu/mason-null-ls.nvim",    enabled = false },
    { "rcarriga/nvim-dap-ui",           enabled = false },
    { "folke/lazydev.nvim",             enabled = false },
    { "Bilal2453/luvit-meta",           enabled = false },
    { "smjonas/inc-rename.nvim",        enabled = false },
    { "aznhe21/actions-preview.nvim",   enabled = false },
    { "saghen/blink.compat",            enabled = false },
    { "fang2hou/blink-copilot",         enabled = false },
}

return M
