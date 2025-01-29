--[[
Copyright (c) 2023 Mariusz Libera <mariusz.libera@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]


-- to debug run mpv with arg: --msg-level=chapters=debug
-- to test options run mpv with arg: --script-opts=chapters-OPTION=VALUE


local utils = require 'mp.utils'
local msg = require 'mp.msg'
local opts = require 'mp.options'
local input = require 'mp.input'

-- can't pass the chapter number to the callback, so let's pass it through a global var
local edited_chapter = 0
local chapters_modified = false


local options = {
    -- ask for title or leave it empty
    ask_for_title = true,
    -- placeholder when asking for title of a new chapter
    placeholder_title = "Chapter ",
    -- pause the playback when asking for chapter title
    pause_on_input = false,
    autoload = true,
    autosave = false,
    autoexportFormats = '',
    -- save all chapter files in a single global directory or next to the playback file
    global_chapters = false,
    chapters_dir = mp.command_native({"expand-path", "~~home/chapters"}),
    -- hash works only with global_chapters enabled
    hash = true
}
opts.read_options(options)

msg.debug("options:", utils.to_string(options))


-- CHAPTER MANIPULATION --------------------------------------------------------


local function change_title_callback(user_input)
    local chapter_index = edited_chapter
    input.terminate()
    if user_input == nil then
        msg.warn("no chapter title provided:")
        return
    end

    local chapter_list = mp.get_property_native("chapter-list")

    if chapter_index > mp.get_property_number("chapter-list/count") then
        msg.warn("can't set chapter title")
        return
    end

    chapter_list[chapter_index].title = user_input

    mp.set_property_native("chapter-list", chapter_list)
    chapters_modified = true
end


local function edit_chapter()
    local mpv_chapter_index = mp.get_property_number("chapter")
    local chapter_list = mp.get_property_native("chapter-list")

    if mpv_chapter_index == nil or mpv_chapter_index == -1 then
        msg.verbose("no chapter selected, nothing to edit")
        return
    end

    input.get({
        prompt = "title of the chapter:",
        submit = change_title_callback,
        default_text = chapter_list[mpv_chapter_index + 1].title,
        cursor_position = #(chapter_list[mpv_chapter_index + 1].title) + 1,
    })

    edited_chapter = mpv_chapter_index + 1

    if options.pause_on_input then
        mp.set_property_bool("pause", true)
    end
end


local function add_chapter()
    local time_pos = mp.get_property_number("time-pos")
    local chapter_list = mp.get_property_native("chapter-list")

    -- mpv sets 'chapter' var to -1 before the 'first' chapter, and indexes
    -- chapters from 0, but lua tables start indexing from 1 and we want
    -- to insert one after that, so that's +2
    -- if there are no chapters mpv sets it to nil, so correct it to -1
    local chapter_index = (mp.get_property_number("chapter") or -1) + 2

    -- show user the timestamp of the chapter we're adding
    mp.osd_message(mp.get_property_osd("time-pos/full"), 1)

    table.insert(chapter_list, chapter_index, {title = "", time = time_pos})

    msg.debug("inserting new chapter at ", chapter_index, " chapter_", " time: ", time_pos)

    mp.set_property_native("chapter-list", chapter_list)
    chapters_modified = true

    if options.ask_for_title then
        input.get({
            prompt = "title of the chapter:",
            submit = change_title_callback,
            default_text = options.placeholder_title .. chapter_index,
            cursor_position = #(options.placeholder_title .. chapter_index) + 1,
        })

        edited_chapter = chapter_index

        if options.pause_on_input then
            mp.set_property_bool("pause", true)
        end
    end
end


local function remove_chapter()
    local chapter_count = mp.get_property_number("chapter-list/count")

    if chapter_count < 1 then
        msg.verbose("no chapters to remove")
        return
    end

    local chapter_list = mp.get_property_native("chapter-list")
    -- +1 because mpv indexes from 0, lua from 1
    local current_chapter = mp.get_property_number("chapter") + 1

    table.remove(chapter_list, current_chapter)
    msg.debug("removing chapter", current_chapter)

    mp.set_property_native("chapter-list", chapter_list)
    chapters_modified = true
end


-- UTILITY FUNCTIONS -----------------------------------------------------------


-- youtube requirements:
-- 1. first chapter starts at 0:00
-- 2. at least 3 chapters
-- 3. minimum chapter length is 10s
local function validate_for_youtube()
    local chapter_count = mp.get_property_number("chapter-list/count")
    local all_chapters = mp.get_property_native("chapter-list")
    local pass = "OK"
    local fail = "FAIL"

    local val = "YouTube validation:\n1. Chapter at 00:00:\t"
    if chapter_count > 0 and math.floor(all_chapters[1].time) == 0 then
        val = val .. pass .. "\n"
    else
        val = val .. fail .. "\n"
    end

    if chapter_count >= 3 then
        val = val .. "2. At least 3 chapters:\t" .. pass .. "\n"
    else
        val = val .. "2. At least 3 chapters:\t" .. fail .. "\n"
    end

    val = val .. "3. Minimum chapter length is 10s:\t"
    if chapter_count > 0 then
        local chapter_length = true
        for i, c in ipairs(all_chapters) do
            local c_start = c.time
            local c_end
            if i < chapter_count then
                c_end = all_chapters[i+1].time
            else
                c_end = (mp.get_property_number("duration") or c.time)
            end
            local length = math.floor(c_end) - math.floor(c_start)
            if length < 10 then
                chapter_length = false
                val = val .. "\n\t" .. fail .. " chapter: ".. i .. " is " .. length .. "sec"
            end
        end
        if chapter_length then
            val = val .. pass .. "\n"
        end
    else
        val = val .. fail .. "\n"
    end

    mp.osd_message(val, 20)
end


local function detect_os()
    -- The first line is the directory separator string.
    -- Default is '\' for Windows and '/' for all other systems.
    -- http://www.lua.org/manual/5.2/manual.html#pdf-package.config
    if package.config:sub(1,1) == "/" then
        return "unix"
    else
        return "windows"
    end
end


-- for unix use only
-- returns a table of command path and varargs, or nil if command was not found
local function command_exists(command, ...)
    msg.debug("looking for command:", command)
    local process = mp.command_native({
        name = "subprocess",
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
        args = {"sh", "-c", "command -v -- " .. command}
    })

    if process.status == 0 then
        local command_path = process.stdout:gsub("\n", "")
        msg.debug("command found:", command_path)
        return {command_path, ...}
    else
        msg.debug("command not found:", command)
        return nil
    end
end


-- full path of the current media file
local function full_path()
    local path = mp.get_property("path")
    msg.debug("full_path, mpv:", path)

    if detect_os() == "windows" then
        local args = {"powershell", "-NoProfile", "-Command", "Resolve-Path -Path \"" .. path .. "\" | Select-Object -ExpandProperty Path"}
        local process = mp.command_native({
            name = "subprocess",
            capture_stdout = true,
            capture_stderr = true,
            playback_only = false,
            args = args
        })

        if process.status == 0 then
            local full_path = process.stdout:gsub("\n", "")
            msg.debug("windows, full path:", full_path)
            return full_path
        else
            msg.warn("windows, full path resolution failed, fallback to guesswork based on mpv provided path")
            if path:find(":\\") or path:find("\\") == 1 or path:find("://") then
                return path
            else
                return utils.join_path(mp.get_property("working-directory"), path)
            end
        end
    else -- unix
        local command = command_exists("realpath", "--") or command_exists("readlink", "-f", "--") or command_exists("perl", "-MCwd", "-e", "print Cwd::realpath shift", "--")

        msg.debug("command:", utils.to_string(command))

        if command then
            table.insert(command, path)
            msg.debug("command2:", utils.to_string(command))

            local process = mp.command_native({
                name = "subprocess",
                capture_stdout = true,
                capture_stderr = true,
                playback_only = false,
                args = command
            })

            if process.status == 0 then
                local full_path = process.stdout:gsub("\n", "")
                msg.debug("unix, full path:", full_path)
                return full_path
            end
        end

        msg.warn("unix, full path resolution failed, fallback to guesswork based on mpv provided path")
        if path:find("/") == 1 or path:find("://") then
            return path
        else
            return utils.join_path(mp.get_property("working-directory"), path)
        end
    end
end


local function mkdir(path)
    local args = nil

    if detect_os() == "unix" then
        args = {"mkdir", "-p", "--", path}
    else
        args = {"powershell", "-NoProfile", "-Command", "mkdir", path}
    end

    local process = mp.command_native({
        name = 'subprocess',
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args,
    })

    if process.status == 0 then
        msg.debug("mkdir success:", path)
        return true
    else
        msg.error("mkdir failure:", path)
        return false
    end
end


local function rm(path)
    local args = nil

    if detect_os() == "unix" then
        args = {"rm", path}
    else
        path = "\"" .. path .. "\""
        args = {"powershell", "-NoProfile", "-Command", "rm", path}
    end

    local process = mp.command_native({
        name = 'subprocess',
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args,
    })

    if process.status == 0 then
        msg.debug("rm success:", path)
        return true
    else
        msg.error("rm failure:", process.stderr)
        return false
    end
end


-- returns md5 hash of the full path of the current media file
local function hash()
    local path = full_path()
    if path == nil then
        msg.debug("something is wrong with the path, can't get full_path, can't hash it")
        return
    end

    msg.debug("hashing:", path)

    local cmd = {
        name = 'subprocess',
        capture_stdout = true,
        playback_only = false,
    }
    local args = nil

    if detect_os() == "unix" then
        local md5 = command_exists("md5sum") or command_exists("md5") or command_exists("openssl", "md5 | cut -d ' ' -f 2")
        if md5 == nil then
            msg.warn("no md5 command found, can't generate hash")
            return
        end
        md5 = table.concat(md5, " ")
        cmd["stdin_data"] = path
        args = {"sh", "-c", md5 .. " | cut -d ' ' -f 1 | tr '[:lower:]' '[:upper:]'" }
    else --windows
        -- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash?view=powershell-7.3
        local hash_command ="$s = [System.IO.MemoryStream]::new(); $w = [System.IO.StreamWriter]::new($s); $w.write(\"" .. path .. "\"); $w.Flush(); $s.Position = 0; Get-FileHash -Algorithm MD5 -InputStream $s | Select-Object -ExpandProperty Hash"
        args = {"powershell", "-NoProfile", "-Command", hash_command}
    end
    cmd["args"] = args
    msg.debug("hash cmd:", utils.to_string(cmd))
    local process = mp.command_native(cmd)

    if process.status == 0 then
        local hash = process.stdout:gsub("%s+", "")
        msg.debug("hash:", hash)
        return hash
    else
        msg.warn("hash function failed")
        return
    end
end


local function seconds_to_hhmmss(sec, precision)
    local hours = math.floor(sec / 3600)
    local minutes = math.floor(sec % 3600 / 60)
    local seconds = sec % 60

    local time = string.format("%02d:%02d:%02d", hours, minutes, seconds)

    if precision then
        time = time .. string.format(".%0" .. precision .. "d", (sec - math.floor(sec)) * 10 ^ precision)
    end

    return time
end


local function construct_xml()
    local chapter_count = mp.get_property_number("chapter-list/count")
    local all_chapters = mp.get_property_native("chapter-list")

    local xml = [[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Chapters SYSTEM "matroskachapters.dtd">]] .. "\n<!-- " .. full_path() .. " -->\n<Chapters>\n\t<EditionEntry>"

    for i, c in ipairs(all_chapters) do
        local c_title = c.title
        local c_start = c.time
        local c_end

        if i < chapter_count then
            c_end = all_chapters[i+1].time
        else
            c_end = (mp.get_property_number("duration") or c.time)
        end

        msg.debug(i, "c_title", c_title, "c_start:", c_start, "c_end", c_end)

        xml = xml .. "\n" ..
        "\t\t<ChapterAtom>\n" ..
        "\t\t\t<ChapterTimeStart>" .. seconds_to_hhmmss(c_start, 3) .. "</ChapterTimeStart>\n" ..
        "\t\t\t<ChapterTimeEnd>" .. seconds_to_hhmmss(c_end, 3) .. "</ChapterTimeEnd>\n" ..
        "\t\t\t<ChapterDisplay>\n" ..
        "\t\t\t\t<ChapterString>" .. c_title .. "</ChapterString>\n" ..
        "\t\t\t</ChapterDisplay>\n" ..
        "\t\t</ChapterAtom>"
    end

    xml = xml .. "\n\t</EditionEntry>\n</Chapters>\n"

    return xml
end


local function construct_txt(timestamp)
    local all_chapters = mp.get_property_native("chapter-list")
    local txt = ""

    for i, c in ipairs(all_chapters) do
        if timestamp then
            txt = txt .. seconds_to_hhmmss(c.time) .. " " .. c.title .. "\n"
        else
            txt = txt .. c.title .. "\n"
        end
    end

    return txt
end


--[[
format that we need

;FFMETADATA1
;file=/path/to/file.mvk
[CHAPTER]
TIMEBASE=1/1000
START=219580
END=514170
title=Chapter 1
[CHAPTER]
TIMEBASE=1/1000
START=514170
END=855000
title=Chapter 2

documented here: https://ffmpeg.org/ffmpeg-formats.html#metadata
]]
local function construct_ffmetadata(chapter_zero)
    -- chapter_zero = chapter_zero or false
    local chapter_count = mp.get_property_number("chapter-list/count")
    local all_chapters = mp.get_property_native("chapter-list")

    local ffmetadata = ";FFMETADATA1\n;file=" .. full_path()

    -- add a dummy chapter at 0:00 only if necessary
    if chapter_zero and all_chapters[1].time ~= 0 then
        ffmetadata = ffmetadata .. "\n[CHAPTER]\nTIMEBASE=1/1000\nSTART=0\nEND=" .. all_chapters[1].time * 1000 .. "\ntitle=0"
    end

    for i, c in ipairs(all_chapters) do
        local c_title = c.title
        local c_start = c.time * 1000
        local c_end

        if i < chapter_count then
            c_end = all_chapters[i+1].time * 1000
        else
            c_end = (mp.get_property_number("duration") or c.time) * 1000
        end

        msg.debug(i, "c_title", c_title, "c_start:", c_start, "c_end", c_end)

        ffmetadata = ffmetadata .. "\n[CHAPTER]\nTIMEBASE=1/1000\nSTART=" .. c_start .. "\nEND=" .. c_end .. "\ntitle=" .. c_title
    end

    return ffmetadata
end


-- FILE IO ---------------------------------------------------------------------


-- args:
--      format - string for file extension and content
--      osd - if true, display an osd message
--      store - if true store chapters according to the config file
--      manual_save - if true force a save even without chapter modifications
--      chapter_zero - if true generate a chapter at 0:00 if one doesn't exists
-- on success returns path of the chapters file, nil on failure
local function write(...)
    local format, osd, store, manual_save, chapter_zero = ...
    if not chapters_modified and not manual_save then
        msg.debug("nothing to write")
        return
    end

    -- figure out the directory
    local chapters_dir
    if store and options.global_chapters then
        local dir = utils.file_info(options.chapters_dir)
        if dir then
            if dir.is_dir then
                msg.debug("options.chapters_dir exists:", options.chapters_dir)
                chapters_dir = options.chapters_dir
            else
                msg.error("options.chapters_dir is not a directory")
                return
            end
        else
            msg.verbose("options.chapters_dir doesn't exists:", options.chapters_dir)
            if mkdir(options.chapters_dir) then
                chapters_dir = options.chapters_dir
            else
                return
            end
        end
    else
        chapters_dir = utils.split_path(mp.get_property("path"))
    end

    -- and the name
    local name = mp.get_property("filename")
    if store and options.global_chapters and options.hash then
        name = hash()
        if name == nil then
            msg.warn("hash function failed, fallback to filename")
            name = mp.get_property("filename")
        end
    end

    local chapters_file_path
    if store then -- this is what load chapter expects
        chapters_file_path = utils.join_path(chapters_dir, name .. ".ffmetadata")
    else -- this is export name
        chapters_file_path = utils.join_path(chapters_dir, name .. ".chapters." .. format)
    end

    msg.debug("opening for writing:", chapters_file_path)

    local chapters_file = io.open(chapters_file_path, "w")
    if chapters_file == nil then
        msg.error("could not open chapter file for writing")
        return
    end

    local success, error
    if format == "xml" then
        success, error = chapters_file:write(construct_xml())
    elseif format == "txt" then
        success, error = chapters_file:write(construct_txt(true))
    elseif format == "list.txt" then
        success, error = chapters_file:write(construct_txt())
    elseif format == "ffmetadata" then
        success, error = chapters_file:write(construct_ffmetadata())
    elseif format == "ffmetadata.tmp" then
        success, error = chapters_file:write(construct_ffmetadata(chapter_zero))
    end

    chapters_file:close()

    if success then
        if osd then
            mp.osd_message("Chapters written to:" .. chapters_file_path, 3)
        end
        return chapters_file_path
    else
        msg.error("error writing chapters file:", error)
        return
    end
end


-- priority:
-- 1. chapters file in the same directory as the playing file
-- 2. hashed version of the chapters file in the global directory
-- 3. path based version of the chapters file in the global directory
local function load_chapters()
    local path = mp.get_property("path")
    local expected_chapters_file = utils.join_path(utils.split_path(path), mp.get_property("filename") .. ".ffmetadata")

    msg.debug("looking for:", expected_chapters_file)

    local file = utils.file_info(expected_chapters_file)

    if file then
        msg.debug("found in the local directory, loading..")
        mp.set_property("file-local-options/chapters-file", expected_chapters_file)
        return
    end

    if not options.global_chapters then
        msg.debug("not in local, global chapters not enabled, aborting search")
        return
    end

    msg.debug("looking in the global directory")

    if options.hash then
        local hashed_path = hash()
        if hashed_path then
            expected_chapters_file = utils.join_path(options.chapters_dir, hashed_path .. ".ffmetadata")
        else
            msg.debug("hash function failed, fallback to path")
            expected_chapters_file = utils.join_path(options.chapters_dir, mp.get_property("filename") .. ".ffmetadata")
        end
    else
        expected_chapters_file = utils.join_path(options.chapters_dir, mp.get_property("filename") .. ".ffmetadata")
    end

    msg.debug("looking for:", expected_chapters_file)

    file = utils.file_info(expected_chapters_file)

    if file then
        msg.debug("found in the global directory, loading..")
        mp.set_property("file-local-options/chapters-file", expected_chapters_file)
        return
    end

    msg.debug("chapters file not found")
end


local function bake_chapters()
    local ext
    local filename = mp.get_property("filename")
    local output_name

    if mp.get_property_number("chapter-list/count") == 0 then
        msg.verbose("no chapters present")
        return
    end

    -- extract file extension
    local reverse_dot_index = filename:reverse():find(".", 1, true)
    if reverse_dot_index == nil then
        msg.warning("file has no extension, fallback to .mkv")
        output_name = filename .. ".chapters.mkv"
    else
        local dot_index = #filename + 1 - reverse_dot_index
        ext = filename:sub(dot_index + 1)
        msg.debug("ext:", ext)
        if ext ~= "mkv" and ext ~= "mp4" and ext ~= "webm" then
            msg.debug("fallback to .mkv")
            ext = "mkv"
        end
        output_name = filename:sub(1, dot_index) .. "chapters." .. ext
    end


    --ffmpeg wants a chapter starting at 0:00 when using mp4 container
    --see: https://forum.videohelp.com/threads/403564-MP4-File-with-no-Chapter-at-00-00-00-000-Breaks-FFMPEG-Conversion
    local require_chapter_zero = ext == "mp4"

    local chapters_file_path = write("ffmetadata.tmp", false, false, true, require_chapter_zero)
    if not chapters_file_path then
        msg.error("no chapters file")
        return
    end

    local file_path = mp.get_property("path")
    local output_path = utils.join_path(utils.split_path(file_path), output_name)

    local args = {"ffmpeg", "-y", "-i", file_path, "-i", chapters_file_path, "-map", "0", "-map_chapters", "1", "-codec", "copy", output_path}

    msg.debug("args:", utils.to_string(args))

    local process = mp.command_native({
        name = 'subprocess',
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args
    })

    if process.status == 0 then
        mp.osd_message("file written to " .. output_path, 3)
    else
        msg.error("failed to write file:\n", process.stderr)
    end

    -- remove temporary chapters file
    rm(chapters_file_path)
end


-- edit mkv file in place
local function mkvpropedit()
    local ext
    local filename = mp.get_property("filename")
    local file_path = mp.get_property("path")

    if mp.get_property_number("chapter-list/count") == 0 then
        msg.verbose("no chapters present")
        return
    end

    -- check the extension
    local reverse_dot_index = filename:reverse():find(".", 1, true)
    if reverse_dot_index == nil then
        msg.warning("file has no extension, are you sure it's mkv?")
    else
        local dot_index = #filename + 1 - reverse_dot_index
        ext = filename:sub(dot_index + 1)
        if ext ~= "mkv" then
            msg.warning("file does not have mkv extension, are you sure it's mkv?")
        end
    end
    local chapters_file_path = write("ffmetadata.tmp", false, false, true, false)
    if not chapters_file_path then
        msg.error("no chapters file")
        return
    end

    local args = {"mkvpropedit", file_path, "--chapters", chapters_file_path}

    msg.debug("args:", utils.to_string(args))

    local process = mp.command_native({
        name = 'subprocess',
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args
    })

    if process.status == 0 then
        mp.osd_message("chapters embedded", 3)
    else
        msg.error("failed to embed chapters", process.stderr)
    end

    -- remove temporary chapters file
    rm(chapters_file_path)
end



-- HOOKS -----------------------------------------------------------------------


if options.autoload then
    mp.add_hook("on_load", 10, load_chapters)
end

if options.autosave then
    mp.add_hook("on_unload", 10, function () write("ffmetadata", false, true) end)
end

if not (options.autoexportFormats == '') then
    local formats = {}
    for format in string.gmatch(options.autoexportFormats, '[^,]+') do
        if (format == 'list.txt'
            or format == 'txt'
            or format == 'xml') then
                table.insert(formats,format)
        end
    end

    if #formats == 0 then
        msg.warn('autoexportFormats was set, but no valid formats were found')
        return
    end

    for _,format in pairs(formats) do
        mp.add_hook("on_unload", 10, function () write(format, false, false) end)
    end
end

mp.add_hook("on_unload", 10, function () input.terminate() end)


-- BINDINGS --------------------------------------------------------------------


mp.add_key_binding(nil, "add_chapter", add_chapter)
mp.add_key_binding(nil, "remove_chapter", remove_chapter)
mp.add_key_binding(nil, "edit_chapter", edit_chapter)
mp.add_key_binding(nil, "write_chapters", function () write("ffmetadata",true, true, true) end)
mp.add_key_binding(nil, "write_xml", function () write("xml", true, false, true) end)
mp.add_key_binding(nil, "write_txt", function () write("txt", true, false, true) end)
mp.add_key_binding(nil, "write_list", function () write("list.txt", true, false, true) end)
mp.add_key_binding(nil, "write_ffmetadata", function () write("ffmetadata", true, false, true) end)
mp.add_key_binding(nil, "bake_chapters", bake_chapters)
mp.add_key_binding(nil, "mkvpropedit", mkvpropedit)
mp.add_key_binding(nil, "validate_for_youtube", validate_for_youtube)
