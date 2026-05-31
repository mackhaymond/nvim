-- Single source of truth for "editing chezmoi-managed files via nvim".
-- Replaces the old zsh nvim() wrapper that lived in dot_zshrc.tmpl.
--
-- Three responsibilities:
--   1. Intercept: opening a managed live path (e.g. ~/.zshrc) swaps the
--      buffer to its chezmoi source (e.g. .../dot_zshrc.tmpl).
--      Encrypted sources open as in-memory decrypted buffers.
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
local encrypted_buffers = {} -- bufnr → decrypted edit session metadata
local encrypted_source_buffers = {} -- source path → decrypted bufnr

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

local function is_encrypted_source(path)
    return path:match("%.age$") ~= nil
end

local function protect_secret_buffer(buf)
    vim.bo[buf].swapfile = false
    vim.bo[buf].undofile = false
    vim.bo[buf].fixendofline = false
end

local function cleanup_encrypted_buffer(buf)
    local info = encrypted_buffers[buf]
    if info then
        encrypted_source_buffers[info.source] = nil
    end
    encrypted_buffers[buf] = nil
end

local function apply_target(target)
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
end

local function apply_target_sync(target)
    local output = vim.fn.system({ "chezmoi", "apply", target })
    local target_short = vim.fn.fnamemodify(target, ":~")
    if vim.v.shell_error == 0 then
        notify("chezmoi: applied " .. target_short, vim.log.levels.INFO)
        return true
    end

    return false, vim.fn.trim(output):sub(-200)
end

local function target_for_source(source)
    local target = vim.fn.trim(vim.fn.system({ "chezmoi", "target-path", source }))
    if vim.v.shell_error ~= 0 or target == "" then return nil end
    return target
end

local function decrypted_buffer_name(source, target)
    local path = target or source:gsub("%.age$", "")
    return "chezmoi-decrypted://" .. path
end

local write_encrypted_buffer

local function configure_decrypted_buffer(buf, source, target)
    encrypted_buffers[buf] = {
        source = source,
        target = target,
    }
    encrypted_source_buffers[source] = buf

    vim.bo[buf].buftype = "acwrite"
    protect_secret_buffer(buf)
    vim.b[buf].chezmoi_decrypted_source = source
    vim.b[buf].chezmoi_decrypted_target = target or ""

    local write_cmd = vim.b[buf].chezmoi_decrypted_write_cmd
    local has_write_cmd = false
    if write_cmd then
        local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { id = write_cmd })
        has_write_cmd = ok and #autocmds > 0
    end

    if not has_write_cmd then
        vim.b[buf].chezmoi_decrypted_write_cmd = vim.api.nvim_create_autocmd("BufWriteCmd", {
            buffer = buf,
            callback = function(args)
                write_encrypted_buffer(args.buf)
            end,
        })
    end
end

local function find_decrypted_buffer(source, target)
    local existing_buf = encrypted_source_buffers[source]
    if existing_buf
        and vim.api.nvim_buf_is_valid(existing_buf)
        and vim.api.nvim_buf_is_loaded(existing_buf)
    then
        configure_decrypted_buffer(existing_buf, source, target)
        return existing_buf
    end
    encrypted_source_buffers[source] = nil

    local name = decrypted_buffer_name(source, target)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf)
            and vim.api.nvim_buf_get_name(buf) == name
        then
            if vim.api.nvim_buf_is_loaded(buf) then
                if encrypted_buffers[buf]
                    or vim.b[buf].chezmoi_decrypted_source == source
                then
                    configure_decrypted_buffer(buf, source, target)
                    return buf
                end

                if vim.bo[buf].modified then
                    notify(string.format(
                            "chezmoi: decrypted buffer name already in use: %s",
                            name),
                        vim.log.levels.ERROR)
                    return nil
                end

                vim.api.nvim_buf_delete(buf, { force = true })
                return nil
            end

            -- An unloaded synthetic buffer can still reserve the unique name.
            -- Drop it so a fresh in-memory decrypted buffer can be created.
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
end

local function split_buffer_lines(text)
    if text == "" then return { "" } end

    local lines = vim.split(text, "\n", { plain = true })
    if text:sub(-1) == "\n" then
        table.remove(lines)
    end
    if #lines == 0 then return { "" } end
    return lines
end

local function encrypted_buffer_text(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if #lines == 1 and lines[1] == "" and not vim.bo[buf].endofline then
        return ""
    end

    local text = table.concat(lines, "\n")
    if vim.bo[buf].endofline then text = text .. "\n" end
    return text
end

local function encrypted_write_error(buf, msg)
    vim.bo[buf].modified = true
    notify(msg, vim.log.levels.ERROR)
    error(msg, 0)
end

write_encrypted_buffer = function(buf)
    local info = encrypted_buffers[buf]
    if not info then return end

    local output = vim.fn.system({
        "chezmoi", "encrypt",
        "--output", info.source,
    }, encrypted_buffer_text(buf))
    if vim.v.shell_error ~= 0 then
        encrypted_write_error(buf, string.format(
            "chezmoi: encrypt failed for %s\n%s",
                vim.fn.fnamemodify(info.source, ":~"),
                vim.fn.trim(output):sub(-200)))
    end

    if info.target then
        local ok, apply_err = apply_target_sync(info.target)
        if ok then
            vim.bo[buf].modified = false
        else
            encrypted_write_error(buf, string.format(
                "chezmoi: apply failed for %s\n%s",
                vim.fn.fnamemodify(info.target, ":~"),
                apply_err or ""))
        end
    else
        vim.bo[buf].modified = false
        notify(string.format("chezmoi: encrypted %s, but no target resolved",
                vim.fn.fnamemodify(info.source, ":~")),
            vim.log.levels.WARN)
    end
end

local function open_decrypted_source(source, target, old_buf, from_short)
    target = target or target_for_source(source)

    local existing_buf = find_decrypted_buffer(source, target)
    if existing_buf then
        vim.api.nvim_set_current_buf(existing_buf)
        if old_buf and vim.api.nvim_buf_is_valid(old_buf) and old_buf ~= existing_buf then
            vim.cmd("bwipeout! " .. old_buf)
        end

        local label = target or source
        if from_short then
            notify(string.format("chezmoi: intercepted %s -> editing decrypted %s",
                    from_short, vim.fn.fnamemodify(label, ":~")),
                vim.log.levels.INFO)
        else
            notify(string.format("chezmoi: editing decrypted %s",
                    vim.fn.fnamemodify(label, ":~")),
                vim.log.levels.INFO)
        end
        return
    end

    local output = vim.fn.system({
        "chezmoi", "decrypt",
        source,
    })
    if vim.v.shell_error ~= 0 then
        notify(string.format("chezmoi: decrypt failed for %s\n%s",
                vim.fn.fnamemodify(source, ":~"),
                vim.fn.trim(output):sub(-200)),
            vim.log.levels.ERROR)
        return
    end

    local buf = vim.api.nvim_create_buf(true, false)
    -- Keep decrypted secrets in memory, not in persistent editor side files.
    configure_decrypted_buffer(buf, source, target)

    local ok, err = pcall(vim.api.nvim_buf_set_name, buf,
        decrypted_buffer_name(source, target))
    if not ok then
        vim.api.nvim_buf_delete(buf, { force = true })
        notify(string.format("chezmoi: failed to name decrypted buffer\n%s", err),
            vim.log.levels.ERROR)
        return
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, split_buffer_lines(output))
    vim.api.nvim_set_current_buf(buf)

    vim.bo[buf].endofline = output:sub(-1) == "\n"
    if target and vim.filetype and vim.filetype.match then
        local ft = vim.filetype.match({ filename = target })
        if ft then vim.bo[buf].filetype = ft end
    end
    vim.bo[buf].modified = false

    if old_buf and vim.api.nvim_buf_is_valid(old_buf) and old_buf ~= buf then
        vim.cmd("bwipeout! " .. old_buf)
    end

    local label = target or source
    if from_short then
        notify(string.format("chezmoi: intercepted %s -> editing decrypted %s",
                from_short, vim.fn.fnamemodify(label, ":~")),
            vim.log.levels.INFO)
    else
        notify(string.format("chezmoi: editing decrypted %s",
                vim.fn.fnamemodify(label, ":~")),
            vim.log.levels.INFO)
    end
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
vim.api.nvim_create_autocmd("BufReadPre", {
    pattern = "*",
    callback = function(args)
        local path = vim.fn.fnamemodify(args.match, ":p")
        if path:sub(1, #source_dir) == source_dir then return end
        if not managed[path] then return end

        local source = vim.fn.trim(vim.fn.system({ "chezmoi", "source-path", path }))
        if vim.v.shell_error ~= 0 or source == "" then return end
        if not is_encrypted_source(source) then return end

        protect_secret_buffer(args.buf)
        vim.b[args.buf].chezmoi_encrypted_live_source = source
    end,
})

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
            if is_encrypted_source(path) then
                if vim.bo[args.buf].readonly then
                    notify(string.format(
                        "chezmoi: -R / readonly - viewing encrypted source %s",
                        vim.fn.fnamemodify(path, ":~")), vim.log.levels.WARN)
                    return
                end
                vim.schedule(function()
                    open_decrypted_source(path, nil, args.buf, nil)
                end)
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
            if is_encrypted_source(source) then
                if vim.api.nvim_buf_is_valid(live_buf) then
                    protect_secret_buffer(live_buf)
                end
                open_decrypted_source(source, path, live_buf, live_short)
                return
            end

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
    callback = function(args)
        notified_source[args.buf] = nil
        cleanup_encrypted_buffer(args.buf)
    end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
    pattern = "*",
    callback = function()
        for buf, _ in pairs(encrypted_buffers) do
            cleanup_encrypted_buffer(buf)
        end
    end,
})

-- AUTO-APPLY
vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = source_dir .. "/*",
    callback = function(args)
        local source = vim.fn.fnamemodify(args.match, ":p")
        local target = target_for_source(source)
        if not target then
            notify(string.format("chezmoi: no target resolved for %s",
                    vim.fs.basename(source)),
                vim.log.levels.WARN)
            return
        end

        apply_target(target)
    end,
})

return M
