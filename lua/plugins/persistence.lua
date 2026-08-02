return {
    -- Lua
    {
        "folke/persistence.nvim",
        event = "BufReadPre", -- this will only start session saving when an actual file was opened
        config = function()
            local persistence = require("persistence")

            persistence.setup({
                -- Key sessions on the cwd alone. Upstream defaults to
                -- branch = true, which appends `%<branch>` to the session
                -- filename for any git branch that isn't main/master. That
                -- breaks restore: tmux-resurrect's nvim strategy looks the
                -- session up by directory only, so anything saved on a feature
                -- branch would never be found and nvim would come back empty.
                -- Directory-keyed is also the more correct choice here, since
                -- the branch checked out at restore time isn't necessarily the
                -- one that was checked out at save time.
                branch = false,
            })

            -- persistence.nvim only writes the session on VimLeavePre, so a
            -- hard reboot or `tmux kill-server` leaves no session file at all
            -- and tmux-resurrect restores a bare nvim. Re-save on layout
            -- changes so there is always a recent session on disk.
            --
            -- Deliberately NOT in the "persistence" augroup: persistence.start()
            -- does nvim_create_augroup("persistence", { clear = true }), which
            -- would delete these autocmds on every session start.
            local group = vim.api.nvim_create_augroup("persistence_autosave", { clear = true })
            local debounce_ms = 2000
            local timer = nil

            local function save()
                -- active() is false before a session is tracked and after
                -- persistence.stop(); saving then would write a stray session.
                if not persistence.active() then
                    return
                end
                -- Mirror persistence's own VimLeavePre guard (need = 1): don't
                -- clobber a good session with one holding no real files.
                local has_file = false
                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "" then
                        has_file = true
                        break
                    end
                end
                if has_file then
                    pcall(persistence.save)
                end
            end

            vim.api.nvim_create_autocmd(
                { "BufWritePost", "BufEnter", "BufDelete", "WinEnter", "WinClose", "TabEnter", "TabClosed" },
                {
                    group = group,
                    callback = function()
                        if timer then
                            timer:stop()
                            timer:close()
                        end
                        timer = vim.uv.new_timer()
                        timer:start(debounce_ms, 0, function()
                            timer:stop()
                            timer:close()
                            timer = nil
                            vim.schedule(save)
                        end)
                    end,
                }
            )
        end,
        init = function()
            -- restore the session for the current directory
            vim.keymap.set("n", "<leader>qs", function()
                require("persistence").load()
            end, { desc = "Session: restore current directory" })
            vim.keymap.set("n", "<leader>sl", function()
                require("persistence").load({ last = true })
            end, { desc = "Session: restore last" })
        end
    }
}
