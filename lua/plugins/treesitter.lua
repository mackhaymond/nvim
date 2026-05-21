return {
    -- treesitter
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        event = { "BufReadPost", "BufNewFile" },

        config = function()
            ---@diagnostic disable: missing-fields
            require 'nvim-treesitter.configs'.setup({
                -- A list of parser names, or "all" (the five listed parsers should always be installed)
                ensure_installed = {
                    "javascript", "typescript", "rust", "c", "lua", "vim", "vimdoc", "query",
                    "python", "json", "yaml", "toml", "markdown", "markdown_inline",
                    "bash", "html", "css", "regex",
                },

                -- Install parsers synchronously (only applied to `ensure_installed`)
                sync_install = false,

                -- Automatically install missing parsers when entering buffer
                -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
                auto_install = true,

                ignore_install = { "latex" },


                ---- If you need to change the installation directory of the parsers (see -> Advanced Setup)
                -- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!

                highlight = {
                    enable = true,

                    -- alker0/chezmoi.vim sets compound filetypes like
                    -- "zsh.chezmoitmpl"; treesitter has no parser for the
                    -- template overlay, so let alker0's vim-regex syntax do
                    -- the work on those files. Plain (non-template) chezmoi
                    -- files keep their normal treesitter highlight.
                    disable = function(_, bufnr)
                        local ft = vim.bo[bufnr].filetype or ""
                        return ft:find("chezmoitmpl") ~= nil
                    end,

                    additional_vim_regex_highlighting = false,
                },
            })
        end
    },

    {
        "IndianBoy42/tree-sitter-just",
        opts = {}
    }
}
