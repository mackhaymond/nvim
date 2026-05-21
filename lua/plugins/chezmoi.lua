return {
    -- Syntax: dot_-prefix resolution + go-template overlay on host language.
    -- Must load early (sets filetype before nvim's builtin detection runs);
    -- use_tmp_buffer = 1 lets it work despite lazy.nvim's ordering.
    {
        "alker0/chezmoi.vim",
        lazy = false,
        init = function()
            vim.g["chezmoi#use_tmp_buffer"] = 1 -- required for lazy.nvim load order
            vim.g["chezmoi#use_external"] = 1   -- respect chezmoi's source-dir config
        end,
    },
}
