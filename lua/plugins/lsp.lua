return {
    {
        'neovim/nvim-lspconfig',
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require('lsp_setup').setup()
        end,
    }, -- Required
    {
        'mason-org/mason.nvim',
        cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonLog", "MasonUninstall", "MasonUninstallAll" },
        opts = {},
    },
    { 'williamboman/mason-lspconfig.nvim' }, -- Optional

    -- Snippets engine (loaded by blink via dependency)
    {
        "L3MON4D3/LuaSnip",
        version = "v2.*",
        build = "make install_jsregexp",
        dependencies = {
            "rafamadriz/friendly-snippets",
        },
        config = function()
            require("luasnip.loaders.from_vscode").lazy_load()
        end,
    },

    -- Compat shim for nvim-cmp sources without native blink support (e.g. cmp-conjure)
    {
        'saghen/blink.compat',
        version = '2.*',
        lazy = true,
        opts = {},
    },

    -- Autocompletion
    {
        'saghen/blink.cmp',
        version = '1.*',
        event = "InsertEnter",
        dependencies = {
            'L3MON4D3/LuaSnip',
            'folke/lazydev.nvim',
            'fang2hou/blink-copilot',
            'saghen/blink.compat',
        },
        ---@module 'blink.cmp'
        ---@type blink.cmp.Config
        opts = {
            keymap = {
                preset = 'super-tab',
                ['<C-e>'] = { 'hide', 'fallback' },
                ['<C-y>'] = { 'select_and_accept', 'fallback' },
                ['<C-l>'] = { 'accept', 'fallback' },
                ['<CR>']  = { 'fallback' },
            },

            appearance = {
                nerd_font_variant = 'mono',
            },

            completion = {
                menu = {
                    border = 'single',
                },
                documentation = {
                    auto_show = true,
                    window = { border = 'single' },
                },
            },

            snippets = { preset = 'luasnip' },

            sources = {
                default = { 'lsp', 'path', 'snippets', 'buffer', 'lazydev', 'conjure', 'copilot' },
                per_filetype = {
                    lua = { inherit_defaults = true, 'lazydev' },
                },
                providers = {
                    lazydev = {
                        name = 'LazyDev',
                        module = 'lazydev.integrations.blink',
                        score_offset = 100,
                    },
                    conjure = {
                        name = 'conjure',
                        module = 'blink.compat.source',
                    },
                    copilot = {
                        name = 'copilot',
                        module = 'blink-copilot',
                        score_offset = 100,
                        async = true,
                        opts = {
                            max_completions = 3,
                        },
                    },
                    buffer = {
                        min_keyword_length = 3,
                    },
                    snippets = {
                        min_keyword_length = 2,
                    },
                },
            },

            fuzzy = { implementation = 'prefer_rust_with_warning' },
        },
    },

    -- null-ls yay still alive!
    {
        "nvimtools/none-ls.nvim",
        event = { "BufReadPre", "BufNewFile" },
    },
    {
        "jay-babu/mason-null-ls.nvim",
        event = { "BufReadPre", "BufNewFile" },
    },

    { "rcarriga/nvim-dap-ui",                  dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" } },

    -- neovim API setup
    {
        "folke/lazydev.nvim",
        ft = "lua", -- only load on lua files
        opts = {
            library = {
                -- See the configuration section for more details
                -- Load luvit types when the `vim.uv` word is found
                { path = "luvit-meta/library", words = { "vim%.uv" } },
            },
        },
    },
    { "Bilal2453/luvit-meta",                  lazy = true }, -- optional `vim.uv` typings

    -- better renaming
    {
        "smjonas/inc-rename.nvim",
        opts = {},
    },

    -- better code actions window
    {
        "aznhe21/actions-preview.nvim",
        event = "LspAttach"
    },
}
