return {
    'chomosuke/typst-preview.nvim',
    ft = 'typst',
    version = '1.*',
    opts = {}, -- lazy.nvim will implicitly calls `setup {}`
    dependencies_bin = { tinymist = 'tinymist' },
    keys = {
        { '<leader>mp', '<cmd>TypstPreviewToggle<cr>', ft = 'typst', desc = 'Toggle Typst Preview' },
    },
}
