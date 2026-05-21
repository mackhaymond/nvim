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
require("lazy").setup("plugins", {
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
