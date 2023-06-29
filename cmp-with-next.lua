#!/usr/bin/env lua

--------------------------------------------------------------
-- Script Summary:
-- This script compares git log output between wireless-next
-- and a standalone driver repo. It takes a parameter for the
-- number of commits to fetch using the fetch_commit_messages
-- function. The git log messages are stored in Lua tables
-- and used to generate patches in the patches directory.

-- You can specify the number of commits to fetch by passing
-- it as a parameter to fetch_commit_messages function. This
-- determines how far back in the git log it will go for each
-- repository.
--------------------------------------------------------------

-- gets the directory of the current script
local script_dir = debug.getinfo(1).source:match("@?(.*/)")

-- sets the path to the configuration file
local config_file = script_dir .. 'config.ini'

-- checks if the config file exists, and throws error if it doesn't
if not os.execute("test -f " .. config_file) then
    error("\27[31m" .. [[

The configuration file does not exist.
Please copy config.ini.example to config.ini and modify it with the proper paths:
1. Path to the wireless-next repository
2. Base directory containing standalone drivers.
        ]] .. "\27[0m")
end

-- adds the script directory to the package search path
package.path = package.path .. ";" .. script_dir .. "/lib/?.lua"

-- load the inifile library and parse the config file
local ini = require('inifile')
local config = ini.parse(config_file)

-- default driver and debug values
local driver = "rtw89"
local debug = nil

-- parse command line arguments for debug mode and driver selection
if arg[1] == "--debug" then
    debug = arg[1]
elseif arg[1] ~= nil then
    driver = arg[1]
    debug = arg[2]
end

-- load repository paths from the configuration file
local repos = {
    wireless_next_repo = config.repositories.wireless_next_repo,
    driver_repo = config.repositories.driver_repo_base .. "/" .. driver
}

-- initialize commit messages tables
local commit_messages = {
    wireless_next_repo = {},
    driver_repo = {}
}

-- initialize commit order tables.
-- NOTE tables in lua are not ordered, so we need to maintain order separately.
local commit_order = {
    wireless_next_repo = {},
    driver_repo = {},
    patches = {}
}

-- the function 'fetch_commit_messages' collects a certain number of commit
-- messages from a specified git repository and stores them in an
-- order-preserving manner. the collected commit messages are filtered to
-- exclude 'Merge' commits.
function fetch_commit_messages(repo_name, number_of_commits)
    -- create a temporary file to hold the git log command's output
    local temp_file = "/tmp/" .. repo_name .. "_commit_messages.txt"
    -- command to execute in the shell: move to the repo's
    -- directory and get the commit log
    os.execute(string.format("cd %s && git log --grep=\"wifi: ".. driver .."\" --pretty=format:\"%%H %%s\" -n %d > %s",
                             repos[repo_name], number_of_commits, temp_file))
    -- open the temporary file for reading
    local file = io.open(temp_file, "r")
    -- start a counter for the commit order
    local count = 0
    -- iterate over each line in the file
    for line in file:lines() do
        -- parse the commit hash and message from each line
        local commit_hash, commit_msg = line:match("([^%s]+)%s(.*)")
        -- check if the commit message starts with 'Merge'
        -- if not, increment the counter and store the commit
        -- message and hash in the commit_messages table
        -- also, store the commit message in the commit_order
        -- table to maintain order
        if not commit_msg:match("^Merge") then
            count = count + 1
            commit_messages[repo_name][commit_msg] = {hash=commit_hash, order=count}
            table.insert(commit_order[repo_name], commit_msg)
        end
    end
    -- close the temporary file
    file:close()
end

-- the function 'is_in' checks whether a particular commit message exists
-- in a commit table.
function is_in(commit_msg, commit_table)
    return commit_table[commit_msg] ~= nil
end

-- the function 'sanitize_commit_message' processes commit messages
-- to be suitable for usage in filenames.
-- it removes special characters and trims the length of the message.
function sanitize_commit_message(commit_msg)
    -- replace all spaces in the commit message with hyphens
    local sanitized_msg = commit_msg:gsub(" ", "-")
    -- replace any character that is not alphanumeric or a hyphen with nothing
    -- in regex, '%w' matches any alphanumeric character and the underscore
    -- the caret '^' in the square brackets negates the character class,
    -- meaning it matches any character not in the class
    sanitized_msg = sanitized_msg:gsub("[^%w%-]", "")
    -- truncate the commit message to the first 30 characters
    sanitized_msg = sanitized_msg:sub(1, 30)

    return sanitized_msg
end

-- the function 'create_patches' generates patch files based on commit messages.
-- it iterates over the commit_order table, checks if each commit is in
-- the commits_for_patches table, and if so, creates a patch file for that commit.
function create_patches(commits_for_patches, patch_dir)
    -- create the patch directory if it doesn't exist
    os.execute(string.format("mkdir -p %s", patch_dir))
    -- iterate over each commit message in the commit_order table
    for i, commit_msg in ipairs(commit_order['wireless_next_repo']) do
        -- check if the commit message is in the commits_for_patches table
        -- if so, retrieve its associated data, sanitize the commit message
        -- for the filename, and generate a patch file using the git
        -- format-patch command
        if commits_for_patches[commit_msg] then
            local data = commits_for_patches[commit_msg]
            local sanitized_msg = sanitize_commit_message(commit_msg)
            local patch_file = string.format("%s/%04d-%s-%s.patch",
                                             patch_dir, data.order, sanitized_msg, data.hash)
            os.execute(string.format("cd %s && git format-patch -1 %s --stdout > %s",
                                     repos['wireless_next_repo'], data.hash, patch_file))
        end
    end
end


-- prints the commit messages in the order they were added
function print_table_in_order(commit_order_table, commit_messages_table, indent)
    indent = indent or ""
    for i, commit_msg in ipairs(commit_order_table) do
        print(indent .. commit_msg .. ":")
        local nested_table = commit_messages_table[commit_msg]
        for k, v in pairs(nested_table) do
            print(indent .. "  " .. tostring(k) .. ": " .. tostring(v))
        end
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

-- fetch commit messages
fetch_commit_messages("wireless_next_repo", 100)
fetch_commit_messages("driver_repo", 200)

-- initialize table for commits that need patches
local commits_for_patches = {}

-- determine commits needing patches and populate commits_for_patches table
for i, commit_msg in ipairs(commit_order['wireless_next_repo']) do
    if is_in(commit_msg, commit_messages['driver_repo']) then
        break
    end
    commits_for_patches[commit_msg] = commit_messages['wireless_next_repo'][commit_msg]
    table.insert(commit_order['patches'], commit_msg)
end

-- debug printouts
if debug == "--debug" then
    print("Commit messages for wireless_next_repo:")
    print_table_in_order(commit_order['wireless_next_repo'], commit_messages['wireless_next_repo'])

    print("\nCommit messages for driver_repo:")
    print_table_in_order(commit_order['driver_repo'], commit_messages['driver_repo'])
end

-- create patch directory and generate patches
local patch_dir = repos['driver_repo'] .. "/patches"
create_patches(commits_for_patches, patch_dir)

if next(commits_for_patches) == nil then
    -- no commits to apply
    print("\27[31m")
    print("Standalone driver repo appears to be up-to-date.")
    print("No commits to apply")
    print("\27[0m")
else
    -- output commits that generated patches
    print("\27[32m\nCommits for patches:\n\27[0m")
    print_table_in_order(commit_order['patches'], commits_for_patches)
end
