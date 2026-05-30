return {
    -- treesitter
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        event = { "BufReadPost", "BufNewFile" },

        config = function()
            -- nvim-treesitter's frozen master branch still provides the old
            -- `set-lang-from-info-string!` directive used by markdown
            -- injections. On newer Neovim nightlies the directive can receive
            -- a non-node capture and crash inside `vim.treesitter.get_node_text`
            -- while drawing markdown buffers. Keep markdown usable by making
            -- the directive defensive until this config can move to
            -- nvim-treesitter's rewritten main branch.
            local ts_query = require("vim.treesitter.query")
            ts_query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
                local node = match[pred[2]]
                if not node or type(node.range) ~= "function" then
                    return
                end

                local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
                if not ok or not text then
                    return
                end

                local injection_alias = text:lower()
                local lang = vim.filetype.match({ filename = "a." .. injection_alias })
                    or ({ ex = "elixir", pl = "perl", sh = "bash", uxn = "uxntal", ts = "typescript" })[injection_alias]
                    or injection_alias
                metadata["injection.language"] = lang
            end, { force = true, all = false })

            ---@diagnostic disable: missing-fields
            require 'nvim-treesitter.configs'.setup({
                -- A list of parser names, or "all" (the five listed parsers should always be installed)
                ensure_installed = {
                    "javascript", "typescript", "rust", "c", "lua", "vim", "vimdoc", "query",
                    "python", "json", "yaml", "toml", "typst", "markdown", "markdown_inline",
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
