local function file_in_cwd(name)
    return vim.fn.findfile(name, vim.fn.getcwd() .. ";") ~= ""
end

local function exe_in_cwd(rel)
    local p = vim.fn.fnamemodify(rel, ":p")
    return vim.fn.executable(p) == 1
end

return {
    {
        "mackhaymond/run.nvim",
        event = "VeryLazy",
        keys = {
            { "<leader>rr", "<cmd>Run<cr>",     desc = "Run" },
            { "<leader>rt", "<cmd>RunProj<cr>", desc = "Run project command" },
        },
        opts = {
            terminal = {
                backend = "fterm",
                position = "float",
            },
            filetype = {
                scala = function()
                    vim.notify("Execute 'sbt run' in a separate tmux window!")
                end,

                python = function()
                    if file_in_cwd("uv.lock") then return "uv run python3 %f" end
                    if file_in_cwd("poetry.lock") then return "poetry run python3 %f" end
                    if file_in_cwd("pyproject.toml") then return "uv run python3 %f" end
                    return "python3 %f"
                end,

                cpp = ":CMakeRun",
                rust = "cargo run",

                -- Vim cmd: no shell spawn, works without lua on PATH, fast.
                lua = ":luafile %",

                markdown = ":MarkdownPreview",

                java = function()
                    if file_in_cwd("build.gradle") or file_in_cwd("build.gradle.kts") then
                        return "./gradlew run"
                    end
                    if file_in_cwd("pom.xml") then return "mvn -q exec:java" end
                    return "java %f"
                end,

                r = "Rscript %f",

                ocaml = function()
                    -- Prefer the project-local opam switch (consistent with vigenere/run.nvim.lua),
                    -- otherwise rely on PATH (typically set by `nix develop` or `eval $(opam env)`).
                    local dune = exe_in_cwd("./_opam/bin/dune") and "./_opam/bin/dune" or "dune"

                    -- Find the executable name from the nearest dune file's `(name foo)`/`(names a b ...)` stanza.
                    local fn = vim.fn
                    local file = fn.expand("%:p")
                    local dir = fn.fnamemodify(file, ":h")
                    local stem = fn.expand("%:t:r")
                    local exe = stem
                    local dune_file = dir .. "/dune"
                    if fn.filereadable(dune_file) == 1 then
                        for _, line in ipairs(fn.readfile(dune_file)) do
                            local single = line:match("%(name%s+([%w%-_]+)%)")
                            if single then
                                exe = single
                                break
                            end
                            local list = line:match("%(names%s+([%w%-%s_]+)%)")
                            if list then
                                for n in list:gmatch("[%w_%-%d]+") do
                                    if n == stem then
                                        exe = n
                                        break
                                    end
                                end
                                break
                            end
                        end
                    end

                    -- Build path relative to the dune project root so `dune exec` resolves.
                    local matches = vim.fs.find(
                        function(name) return name == "dune-project" or name == "dune-workspace" end,
                        { upward = true, type = "file", path = dir }
                    )
                    local root = matches[1] and vim.fs.dirname(matches[1]) or dir
                    local rel = (dir == root) and "." or dir:sub(#root + 2)
                    local exe_path = (rel == ".") and ("./" .. exe .. ".exe") or ("./" .. rel .. "/" .. exe .. ".exe")

                    return dune .. " exec " .. exe_path .. " --"
                end,
            },
        },
    },
}
