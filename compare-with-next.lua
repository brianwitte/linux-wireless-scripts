#!/usr/bin/env lua

-- NOTE This script takes git log output based on a parameter given to
-- fetch_commit_messages function for a given driver from wireless-next
-- and compares them to the git log from a standalone driver repo using
-- using lua tables. It then puts a date ordered set of patches in a
-- patches directory in the standalone driver repo.
--
-- NOTE Again, you set how many commits back for each repo you want to
-- log when you call the fetch_commit_messages function.

-- !!! SET YOUR CONFIG PARAMS IN SECTION BELOW
---------------------------------------------------------------------------------
-- TODO set driver name, E.g. rtw88, rtw89, rtw...
local driver = "drivername"
local config = {
    -- TODO set where wireless-next repo is
    wireless_next_repo = "/abs/path/to/wireless-next",
    -- TODO set the base path where you keep standalone driver repos
    driver_repo = string.format("/abs/path/to/drivers/%s", driver)
}
---------------------------------------------------------------------------------

-- table to store commit messages
local commit_messages = {
    wireless_next_repo = {},
    driver_repo = {}
}

-- function to fetch and store commit messages
function fetch_commit_messages(repo_name, number_of_commits)
    local temp_file = "/tmp/" .. repo_name .. "_commit_messages.txt"
    os.execute(string.format("cd %s && git log --grep=%s --pretty=format:\"%%H %%s\" -n %d > %s",
                             config[repo_name], driver, number_of_commits, temp_file))
    local file = io.open(temp_file, "r")
    local count = 0
    for line in file:lines() do
        local commit_hash, commit_msg = line:match("([^%s]+)%s(.*)")
        count = count + 1
        commit_messages[repo_name][commit_msg] = {hash=commit_hash, order=count}
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
                                 config['wireless_next_repo'], data.hash, patch_file))
    end
end


-- NOTE below is the 'main' logic of this script

fetch_commit_messages('wireless_next_repo', 100)
fetch_commit_messages('driver_repo', 200)

-- table to store commit hashes that need patches
local commits_for_patches = {}

for commit_msg, data in pairs(commit_messages['wireless_next_repo']) do
    if not is_in(commit_msg, commit_messages['driver_repo']) then
        commits_for_patches[commit_msg] = data
    end
end

-- create a patch directory within standalone driver repository
local patch_dir = config['driver_repo'] .. "/patches"
create_patches(commits_for_patches, patch_dir)
