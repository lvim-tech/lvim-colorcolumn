local config = require("lvim-colorcolumn.config")
local utils = require("lvim-colorcolumn.utils")
local funcs = require("lvim-colorcolumn.funcs")

local M = {}

M.setup = function(user_config)
	if user_config ~= nil then
		utils.merge(config, user_config)
	end
	vim.schedule(function()
		vim.api.nvim_set_option("colorcolumn", config.size)
		M.init()
	end)
end

M.init = function()
	funcs.set_autocmd()
	funcs.set_hl()
	funcs.update()
end

return M
