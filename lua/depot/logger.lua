local log = require("plenary.log")

return log.new({
	plugin = "depot",
	highlights = false,
	use_console = vim.env.DEPOT_LOG_CONSOLE or false,
	use_file = vim.env.DEPOT_LOG_FILE or false,
	level = vim.env.DEPOT_LOG_LEVEL or "info",
})
