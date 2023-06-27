#!/usr/bin/env lua

-- NOTE This script takes git log output based on a parameter given to
-- fetch_commit_messages function for a given driver from wireless-next
-- and compares them to the git log from a standalone driver repo using
-- using lua tables. It then puts a date ordered set of patches in a
-- patches directory in the standalone driver repo.
--
-- NOTE Again, you set how many commits back for each repo you want to
-- log when you call the fetch_commit_messages function.
---------------------------------------------------------------------------------

local script_dir = debug.getinfo(1).source:match("@?(.*/)")
local config_file = script_dir .. 'config.ini'

if not os.execute("test -f " .. config_file) then
    error("\27[31m" .. [[

The configuration file does not exist.
Please copy config.ini.example to config.ini and modify it with the proper paths:
1. Path to the wireless-next repository
2. Base directory containing standalone drivers.
        ]] .. "\27[0m")
end

package.path = package.path .. ";" .. script_dir .. "/lib/?.lua"

local ini = require('inifile')
local config = ini.parse(config_file)

local driver = arg[1] or "rtw89"

local repos = {
    wireless_next_repo = config.repositories.wireless_next_repo,
    driver_repo = config.repositories.driver_repo_base .. "/" .. driver
}

-- table to store commit messages
local commit_messages = {
    wireless_next_repo = {},
    driver_repo = {}
}

-- function to fetch and store commit messages
function fetch_commit_messages(repo_name, number_of_commits)
    local temp_file = "/tmp/" .. repo_name .. "_commit_messages.txt"
    os.execute(string.format("cd %s && git log --grep=\"wifi: ".. driver .."\" --pretty=format:\"%%H %%s\" -n %d > %s",
                             repos[repo_name], number_of_commits, temp_file))
    local file = io.open(temp_file, "r")
    local count = 0
    for line in file:lines() do
        local commit_hash, commit_msg = line:match("([^%s]+)%s(.*)")

        -- ensures "Merge" is not the first word in commit_msg
        if not commit_msg:match("^Merge") then
            --
            -- our --grep=\"wifi: ".. driver .." logic above is matching
            -- on strings in the Merge commit body, thus it is not able
            -- to filter out merge commits that we don't need
            --
            count = count + 1
            commit_messages[repo_name][commit_msg] = {hash=commit_hash, order=count}
        end
    end
    file:close()
end


function is_in(commit_msg, commit_table)
    return commit_table[commit_msg] ~= nil
end

-- function to sanitize the commit message
function sanitize_commit_message(commit_msg)
    -- replace spaces with hyphens
    local sanitized_msg = commit_msg:gsub(" ", "-")

    -- replace all characters that are not alphanumeric or a hyphen with an empty string
    sanitized_msg = sanitized_msg:gsub("[^%w%-]", "")

    -- limit the length to 30 characters
    sanitized_msg = sanitized_msg:sub(1, 30)

    return sanitized_msg
end

-- function to create patches for specific commits
function create_patches(commit_msg_hash_table, patch_dir)
    os.execute(string.format("mkdir -p %s", patch_dir))
    local ordered_patches = {}
    for commit_msg, data in pairs(commit_msg_hash_table) do
        local sanitized_msg = sanitize_commit_message(commit_msg)
        local patch_file = string.format("%s/%04d-%s-%s.patch",
                                         patch_dir, data.order, sanitized_msg, data.hash)
        os.execute(string.format("cd %s && git format-patch -1 %s --stdout > %s",
                                 repos['wireless_next_repo'], data.hash, patch_file))
    end
end

--
--                              ███
--                             ░░░
--   █████████████    ██████   ████  ████████
--  ░░███░░███░░███  ░░░░░███ ░░███ ░░███░░███
--   ░███ ░███ ░███   ███████  ░███  ░███ ░███
--   ░███ ░███ ░███  ███░░███  ░███  ░███ ░███
--   █████░███ █████░░████████ █████ ████ █████
--  ░░░░░ ░░░ ░░░░░  ░░░░░░░░ ░░░░░ ░░░░ ░░░░░
--
--  functions, helpers, imports, config, etc. defined above this
--
--  main program logic below
--

fetch_commit_messages("wireless_next_repo", 100)
fetch_commit_messages("driver_repo", 200)

-- table to store commit hashes that need patches
local commits_for_patches = {}

for commit_msg, data in pairs(commit_messages['wireless_next_repo']) do
    if not is_in(commit_msg, commit_messages['driver_repo']) then
        commits_for_patches[commit_msg] = data
    end
end

-- create a patch directory within standalone driver repository
local patch_dir = repos['driver_repo'] .. "/patches"
create_patches(commits_for_patches, patch_dir)
