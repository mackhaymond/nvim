local glow_running = false

local function glow_preview()
    if glow_running then return end
    local file = vim.fn.expand("%:p")
    if file == "" or vim.bo.filetype ~= "markdown" then
        vim.notify("Not a markdown file", vim.log.levels.WARN)
        return
    end

    glow_running = true
    local saved = {
        showtabline = vim.o.showtabline,
        laststatus = vim.o.laststatus,
        cmdheight = vim.o.cmdheight,
        ruler = vim.o.ruler,
        showmode = vim.o.showmode,
    }
    vim.o.showtabline = 0
    vim.o.laststatus = 0
    vim.o.cmdheight = 0
    vim.o.ruler = false
    vim.o.showmode = false

    vim.cmd("tabnew")
    local tab = vim.api.nvim_get_current_tabpage()
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
    vim.wo.foldcolumn = "0"
    vim.wo.winbar = ""

    vim.fn.jobstart({ "glow", "-p", file }, {
        term = true,
        on_exit = function()
            vim.schedule(function()
                if vim.api.nvim_tabpage_is_valid(tab) then
                    pcall(vim.cmd, vim.api.nvim_tabpage_get_number(tab) .. "tabclose")
                end
                vim.o.showtabline = saved.showtabline
                vim.o.laststatus = saved.laststatus
                vim.o.cmdheight = saved.cmdheight
                vim.o.ruler = saved.ruler
                vim.o.showmode = saved.showmode
                glow_running = false
            end)
        end,
    })
    vim.cmd("startinsert")
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function(event)
        vim.keymap.set("n", "<leader>mp", glow_preview, {
            buffer = event.buf,
            desc = "Preview markdown in glow (fullscreen)",
        })
    end,
})

return {
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        ft = { "markdown" },
        build = function() vim.fn["mkdp#util#install"]() end,
        keys = {
            { "<leader>mb", "<cmd>MarkdownPreview<cr>", desc = "Markdown Preview in browser", ft = "markdown" }
        }
    },
    {
        'MeanderingProgrammer/render-markdown.nvim',
        ft = { "markdown" },
        opts = { enabled = false },
        dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
        keys = {
            { "<leader>mr", "<cmd>RenderMarkdown buf_toggle<cr>", desc = "Toggle Render Markdown (buffer)", ft = "markdown" }
        }
    }
}
