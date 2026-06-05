return {
    -- better netrw
    {
        'stevearc/oil.nvim',
        -- load at startup so oil can hijack directory buffers (e.g. `nvim some/folder`)
        lazy = false,
        keys = {
            { "<leader>pv", "<cmd>Oil --float .<cr>", desc = "Oil (float)" },
        },
        opts = {
            default_file_explorer = true,
            keymaps = {
                ["<C-a>"] = "actions.select_vsplit"
            }
        },
        -- Optional dependencies
        dependencies = { "nvim-tree/nvim-web-devicons" },
    },
}
