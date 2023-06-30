local uv = vim.loop
local async = require("plenary.async")

local M = {}

function M.log_error(msg)
	vim.notify(msg, vim.log.levels.ERROR)
end

---@param path string
---@param callback fun(data: string|nil)
function M.read_file(path, callback)
	uv.fs_open(path, "r", 438, function(err, fd)
		if err then
			return callback()
		end
		uv.fs_fstat(fd, function(err, stat)
			assert(not err, err)
			uv.fs_read(fd, stat.size, 0, function(err, data)
				assert(not err, err)
				uv.fs_close(fd, function(err)
					assert(not err, err)
					return callback(data)
				end)
			end)
		end)
	end)
end

---@async
---@param path string
---@return string|nil, string|nil
function M.read_file_async(path)
	local err, fd = async.uv.fs_open(path, "r", 438)
	assert(not err, err)
	if err then
		return nil, err
	end

	local err, stat = async.uv.fs_fstat(fd)
	if err then
		return nil, err
	end

	local err, data = async.uv.fs_read(fd, stat.size, 0)
	if err then
		return nil, err
	end

	local err = async.uv.fs_close(fd)
	if err then
		return nil, err
	end

	return data, nil
end

--- @diagnostic disable
function M.write_file(path, data, callback)
	uv.fs_open(path, "w", 438, function(err, fd)
		assert(not err, err)
		uv.fs_write(fd, data, 0, function(err)
			assert(not err, err)
			uv.fs_close(fd, function(err)
				assert(not err, err)
				return callback()
			end)
		end)
	end)
end

---Execute `callback` when path changes.
---If callback return `false` the watch is stopped
---@param path string
---@param callback fun(err, filename, event)
function M.watch_file(path, callback)
	local w = uv.new_fs_event()
	path = uv.fs_realpath(path)
	w:start(path, {}, function(...)
		if callback(...) ~= true then
			w:stop()
		end
	end)
end

---@param path string
---@param parse fun(string): any
---@return async fun(): string|nil
function M.memoize_file(path, parse)
	path = async.uv.fs_realpath(path)

	local cache = nil
	return function()
		if cache then
			return cache
		end

		if path == nil then
			return nil
		end

		local data, err = M.read_file_async(path)

		M.watch_file(path, function()
			cache = nil
		end)

		local value = parse(data)

		cache = value
		return value
	end
end

---@generic T
---@param reader async fun(path: string): string|nil
---@param on_change fun(path: string)
---@return fun(path: string, parse: fun(data: string|nil, path: string|nil): T): T, boolean
function M.memoize_files(reader, on_change)
	local cache = {}
	local reader = reader or M.read_file_async

	---@async
	return function(path, parse)
		async.util.scheduler()
		local path = vim.loop.fs_realpath(path)
		-- local path = async.wrap(function(cb)
		-- 	vim.loop.fs_realpath(path, cb)
		-- end, 1)()

		local cached = cache[path]
		if cached then
			return cached, false
		end

		if path == nil then
			return parse(), true
		end

		-- Load and parse the file

		local data, _ = reader(path)

		M.watch_file(path, function()
			if on_change then
				on_change(path)
			end

			cache[path] = nil
		end)

		async.util.scheduler()
		local value = parse(data, path)

		cache[path] = value
		return value, true
	end
end

---@class Item
---@field name string
---@field type string
---@field path string
---@field modified number
---@field mode number
---@field size number

--- Loads a directory into file items
---@param dir string
---@return Item[]|nil
function M.readdir(dir)
	local err, real = async.uv.fs_realpath(dir)
	if not real then
		vim.notify("No such directory: " .. dir, vim.log.levels.ERROR)
		return nil
	end

	real = real:gsub("/$", "")
	local err, dirent = async.wrap(function(cb)
		uv.fs_opendir(real, cb, 4)
	end, 1)()

	assert(dirent, err, "Failed to open dir")

	local t = {}
	while true do
		local _, entries = async.uv.fs_readdir(dirent)

		if not entries then
			break
		end

		for _, v in ipairs(entries) do
			local path = real .. "/" .. v.name
			local err, stat = async.uv.fs_stat(path)
			if not stat then
				M.log_error("Failed to stat: " .. path .. ". " .. err)
			end

			local item = {
				name = v.name,
				type = v.type,
				path = path,
				modified = stat.mtime.sec,
				mode = stat.mode,
				size = stat.size,
			}
			table.insert(t, item)
		end
	end

	return t
end

return M
