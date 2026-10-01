vim.loader.enable()

-- import keymaps and general settings
require('keymaps')
require('set')
require('chezmoi_workflow')

-- disable unused language providers (saves ~10-50ms each at startup)
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Lite mode on the SEAS servers (or NVIM_LITE=1; NVIM_LITE=0 forces full):
-- only the plugins that shape editing, see lua/lite.lua. It keeps its own
-- lockfile so the repo's lazy-lock.json isn't rewritten to the subset there.
vim.g.lite = vim.env.NVIM_LITE == "1"
    or (vim.env.NVIM_LITE ~= "0" and (vim.uv.os_gethostname() or ""):find("%.seas%.ucla%.edu$") ~= nil)

require("lazy").setup(vim.g.lite and require("lite").spec or "plugins", {
    lockfile = vim.g.lite and vim.fn.stdpath("data") .. "/lazy-lock-lite.json" or nil,
    dev = {
        path = "~/projects/nvim_dev",
    },
    performance = {
        rtp = {
            disabled_plugins = {
                "gzip",
                "netrwPlugin",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
            },
        },
    },
})

vim.filetype.add({
    extension = {
        r = 'r',
        R = 'r',
    },
})
