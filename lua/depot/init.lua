local M = {}

local logger = require("depot.logger")

---@class DepotConfig
---@field patterns string[]
local default_opts = {
	patterns = { ".nvim-settings.json" },
}

M.opts = default_opts
M.subscribers = {}

local memo = nil

function M.setup(opts)
	M.opts = vim.tbl_extend("force", default_opts, opts or {})

	local util = require("depot.util")

	memo = util.memoize_files(vim.secure.read, function(path)
		logger.fmt_info("Config %q changed", path)

		M.load()
	end)

	M.load()
end

local function parse(data, path)
	local logger = require("depot.logger")
	local util = require("depot.util")
	logger.fmt_info("Loading config from %s", path)

	local ok, result = pcall(vim.fn.json_decode, data)

	if not ok then
		util.log_error(string.format("Failed to decode %q\n%s", path, result))
		return {}
	end

	logger.fmt_info("Loaded config from %s\n\n%s", path, vim.inspect(result))
	return result
end

--- Returns the stored configuration for the cwd
local logger = require("depot.logger")

-- The last loaded settings
M.loaded = nil

--- Loads the local settings in the background
--- The subscribers will be invoked with the result when done
function M.load(dir)
	local async = require("plenary.async")

	async.run(function()
		local util = require("depot.util")

		async.util.scheduler()
		local dir = dir or vim.fn.getcwd()

		local files = util.readdir(dir)

		print("Files in %s\n%s", dir, vim.inspect(files))

		local file
		for _, pat in ipairs(M.opts.patterns) do
			for _, f in ipairs(files or {}) do
				if f.name == pat then
					logger.fmt_info("Found config file %s", f)
					file = f
					break
				end
			end

			if file then
				break
			end
		end

		if not file then
			util.log_error("No config file found")
			M.settings = {}

			M.publish({})
		else
			local settings, changed = M.read(file.path)

			M.settings = {}

			-- Make settings available to subscribers
			M.publish(settings)
		end
	end)
end

---Loads settings from the provided path directly
---@param path string
---@return table, boolean
function M.read(path)
	local res, loaded = memo(path, parse)

	return res, loaded
end

--- Publish a config to all the subscribers
---@param settings table
function M.publish(settings)
	logger.fmt_info("Publishing settings to %d subscribers", #M.subscribers)

	for _, sub in ipairs(M.subscribers) do
		vim.schedule(function()
			sub(settings)
		end)
	end
end

---Subscribes to the loaded config when it is loaded or changed
---@fun handler fun(config: table)
function M.subscribe(handler)
	--- Don't miss existing state
	if M.loaded then
		vim.schedule(function()
			handler(M.loaded)
		end)
	end

	table.insert(M.subscribers, handler)
end

M.test = function()
	M.get_async()
end

return M
