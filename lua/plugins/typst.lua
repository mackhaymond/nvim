return {
    'chomosuke/typst-preview.nvim',
    ft = 'typst',
    version = '1.*',
    opts = {}, -- lazy.nvim will implicitly calls `setup {}`
    dependencies_bin = { tinymist = 'tinymist' },
    -- set leader + m + p to preview the current file
    keys = {
        { '<leader>mp', '<cmd>TypstPreviewToggle<cr>', desc = 'Toggle Typst Preview' },
    },
}
