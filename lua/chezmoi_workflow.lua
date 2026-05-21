-- Single source of truth for "editing chezmoi-managed files via nvim".
-- Replaces the old zsh nvim() wrapper that lived in dot_zshrc.tmpl.
--
-- Three responsibilities:
--   1. Intercept: opening a managed live path (e.g. ~/.zshrc) swaps the
--      buffer to its chezmoi source (e.g. .../dot_zshrc.tmpl).
--   2. Auto-apply: saving a source file runs `chezmoi apply <target>`.
--   3. Notify: every chezmoi-relevant action is announced via vim.notify.
--
-- Bypasses for the intercept:
--   - Buffer is readonly (`nvim -R`, `:setl ro`) → show rendered file.
--   - Path is already inside the chezmoi source dir → no swap needed.
--   - Path is unmanaged → silent fall-through.
--
-- Manual escape if this file breaks:
--   nvim --clean $(chezmoi source-path ~/.zshrc)
--
-- Diagnostic commands:
--   :ChezmoiRehook       - reload the managed-paths cache
--   :ChezmoiNotifyTest   - fire one notify at each level (verifies plumbing)

local M = {}

local source_dir = vim.fn.expand("~/.local/share/chezmoi")
local managed = {}         -- set of absolute live paths managed by chezmoi
local notified_source = {} -- bufnr → true; one "editing source" notify per buf

-- Startup-time notify queue.
--
-- chezmoi_workflow loads from init.lua (parsed during nvim startup).
-- noice.nvim — which hooks vim.notify and routes it to nvim-notify —
-- loads on lazy.nvim's `User VeryLazy` event, AFTER VimEnter. A
-- BufReadPost autocmd firing from `nvim ~/.zshrc` runs during startup,
-- so a synchronous vim.notify here hits the default (unhooked)
-- implementation → lands in :messages only, never renders as a toast.
--
-- Solution: queue calls until lazy.nvim fires `User LazyLoad` with
-- event.data == "noice.nvim" — that event is emitted AFTER noice's
-- config() callback returns, i.e. after vim.notify has been hooked.
-- Then flush. Subsequent notify() calls hit the hooked vim.notify.
--
-- Fallback: if noice never loads (uninstalled, renamed, etc.), flush
-- after 2s so queued calls don't strand forever. They'll hit whatever
-- vim.notify resolves to at that point.
local startup_complete = false
local startup_queue = {}

local function flush_queue()
    if startup_complete then return end
    startup_complete = true
    for _, item in ipairs(startup_queue) do
        vim.notify(item[1], item[2])
    end
    startup_queue = {}
end

local function notify(msg, level)
    if startup_complete then
        vim.notify(msg, level)
    else
        table.insert(startup_queue, { msg, level })
    end
end

vim.api.nvim_create_autocmd("User", {
    pattern = "LazyLoad",
    callback = function(event)
        if event.data == "noice.nvim" then
            flush_queue()
        end
    end,
})

vim.defer_fn(flush_queue, 2000)

-- Re-entrancy flag: when our intercept calls `:edit <source>`, that fires
-- a recursive BufReadPost for the source buffer, which would otherwise
-- emit a spurious "editing source directly" notify on top of the
-- "intercepted" notify. Set before the recursive :edit, cleared after.
local intercepting = false

local function load_managed()
    managed = {}
    local lines = vim.fn.systemlist({
        "chezmoi", "managed",
        "--path-style=absolute",
        "--include=files,symlinks",
    })
    if vim.v.shell_error == 0 then
        for _, p in ipairs(lines) do managed[p] = true end
    end
    return vim.tbl_count(managed)
end

load_managed()

vim.api.nvim_create_user_command("ChezmoiRehook", function()
    local n = load_managed()
    notify(string.format("chezmoi: %d managed paths cached", n),
        vim.log.levels.INFO)
end, { desc = "Reload chezmoi managed-paths cache" })

vim.api.nvim_create_user_command("ChezmoiNotifyTest", function()
    notify("chezmoi: INFO test", vim.log.levels.INFO)
    notify("chezmoi: WARN test", vim.log.levels.WARN)
    notify("chezmoi: ERROR test", vim.log.levels.ERROR)
end, { desc = "Fire one notify at each level (diagnostic)" })

-- INTERCEPT
vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*",
    callback = function(args)
        local path = vim.fn.fnamemodify(args.match, ":p")

        -- Already in source dir → notify once, do nothing else.
        -- Suppressed during an active intercept: the user is already getting
        -- a single "intercepted X → editing Y" notify; this one would be
        -- duplicate noise.
        if path:sub(1, #source_dir) == source_dir then
            if intercepting then
                notified_source[args.buf] = true
                return
            end
            if not notified_source[args.buf] then
                notified_source[args.buf] = true
                notify("chezmoi: editing source directly — saves auto-apply",
                    vim.log.levels.INFO)
            end
            return
        end

        if not managed[path] then return end -- unmanaged: silent

        -- Readonly bypass: user explicitly wants the rendered output.
        if vim.bo[args.buf].readonly then
            notify(string.format(
                "chezmoi: -R / readonly — viewing rendered %s, not source",
                vim.fn.fnamemodify(path, ":~")), vim.log.levels.WARN)
            return
        end

        local source = vim.fn.trim(vim.fn.system({ "chezmoi", "source-path", path }))
        if vim.v.shell_error ~= 0 or source == "" then
            notify(string.format(
                "chezmoi: source-path failed for %s, not intercepting",
                vim.fn.fnamemodify(path, ":~")), vim.log.levels.WARN)
            return
        end

        local live_buf = args.buf
        local live_short = vim.fn.fnamemodify(path, ":~")
        local source_short = vim.fn.fnamemodify(source, ":~")

        vim.schedule(function()
            intercepting = true
            vim.cmd("edit " .. vim.fn.fnameescape(source))
            intercepting = false
            if vim.api.nvim_buf_is_valid(live_buf) then
                vim.cmd("bwipeout! " .. live_buf)
            end
            notify(string.format("chezmoi: intercepted %s → editing %s",
                    live_short, source_short),
                vim.log.levels.INFO)
        end)
    end,
})

-- Cleanup notified-source marker when the source buffer is wiped.
vim.api.nvim_create_autocmd("BufWipeout", {
    pattern = "*",
    callback = function(args) notified_source[args.buf] = nil end,
})

-- AUTO-APPLY
vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = source_dir .. "/*",
    callback = function(args)
        local source = vim.fn.fnamemodify(args.match, ":p")
        local target = vim.fn.trim(vim.fn.system({ "chezmoi", "target-path", source }))
        if vim.v.shell_error ~= 0 or target == "" then
            notify(string.format("chezmoi: no target resolved for %s",
                    vim.fs.basename(source)),
                vim.log.levels.WARN)
            return
        end

        local stderr_buf = {}
        vim.fn.jobstart({ "chezmoi", "apply", target }, {
            stderr_buffered = true,
            on_stderr = function(_, data) stderr_buf = data or {} end,
            on_exit = function(_, code)
                local target_short = vim.fn.fnamemodify(target, ":~")
                if code == 0 then
                    notify("chezmoi: applied " .. target_short, vim.log.levels.INFO)
                else
                    local err = table.concat(stderr_buf, "\n"):sub(-200)
                    notify(string.format("chezmoi: apply failed for %s\n%s",
                            target_short, err),
                        vim.log.levels.ERROR)
                end
            end,
        })
    end,
})

return M
