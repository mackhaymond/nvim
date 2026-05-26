return {
    {
        "3rd/image.nvim",
        build = false,
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        ft = { "markdown", "typst" },
        config = function(_, opts)
            require("image").setup(opts)
        end,
        opts = {
            backend = "kitty",
            processor = "magick_cli",
            editor_only_render_when_focused = true,
            window_overlap_clear_enabled = true,
            integrations = {
                markdown = {
                    enabled = true,
                    clear_in_insert_mode = false,
                    download_remote_images = false,
                    only_render_image_at_cursor = true,
                    only_render_image_at_cursor_mode = "popup",
                    floating_windows = false,
                    filetypes = { "markdown" },
                },
                typst = {
                    enabled = true,
                    filetypes = { "typst" },
                },
            },
            tmux_show_only_in_active_window = true,
        },
    },
}
