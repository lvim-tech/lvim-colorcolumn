local config = require("lvim-colorcolumn.config")
local NS = vim.api.nvim_create_namespace("virtcolumn")

local M = {}

M.parse_items = function(cc)
	local textwidth = vim.o.textwidth
	local items = {}
	for _, c in ipairs(vim.split(cc, ",")) do
		local item
		if c and c ~= "" then
			if vim.startswith(c, "+") then
				if textwidth ~= 0 then
					item = textwidth + tonumber(c:sub(2))
				end
			elseif vim.startswith(cc, "-") then
				if textwidth ~= 0 then
					item = textwidth - tonumber(c:sub(2))
				end
			else
				item = tonumber(c)
			end
		end
		if item and item > 0 then
			table.insert(items, item)
		end
	end
	table.sort(items, function(a, b)
		return a > b
	end)
	return items
end

M.update = function()
	local curbuf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_loaded(curbuf) then
		return
	end
	local items = vim.b.virtcolumn_items or vim.w.virtcolumn_items
	local local_cc = vim.api.nvim_get_option_value("cc", { scope = "local" })
	if not items or local_cc ~= "" then
		items = M.parse_items(local_cc)
		vim.api.nvim_set_option_value("cc", "", { scope = "local" })
	end
	vim.b.virtcolumn_items = items
	vim.w.virtcolumn_items = items
	local win_width = vim.api.nvim_win_get_width(0)
	items = vim.tbl_filter(function(item)
		return win_width > item
	end, items)
	if #items == 0 then
		vim.api.nvim_buf_clear_namespace(curbuf, NS, 0, -1)
		return
	end
	local debounce = math.floor(vim.api.nvim_win_get_height(0) * 0.6)
	local visible_first, visible_last = vim.fn.line("w0"), vim.fn.line("w$")
	local offset = (visible_first <= debounce and 1 or visible_first - debounce) - 1 -- convert to 0-based
	local lines = vim.api.nvim_buf_get_lines(curbuf, offset, visible_last + debounce, false)
	local rep = string.rep(" ", vim.opt.tabstop:get())
	local line, lnum, strwidth
	for idx = 1, #lines do
		line = lines[idx]:gsub("\t", rep)
		lnum = idx - 1 + offset
		strwidth = vim.api.nvim_strwidth(line)
		vim.api.nvim_buf_clear_namespace(curbuf, NS, lnum, lnum + 1)
		for _, item in ipairs(items) do
			local ok, result = pcall(function()
				return vim.fn.strpart(line, item - 1, 1)
			end)
			if not ok then
				return
			end
			if strwidth < item or result == " " then
				vim.api.nvim_buf_set_extmark(curbuf, NS, lnum, 0, {
					virt_text = { { config.char, "VirtColumn" } },
					hl_mode = "combine",
					virt_text_win_col = item - 1,
					priority = config.priority,
				})
			end
		end
	end
end

M.refresh = function(args)
	M.update()
end

M.set_hl = function()
	local cc_bg = vim.api.nvim_get_hl_by_name("ColorColumn", true).background
	if cc_bg then
		vim.api.nvim_set_hl(0, "VirtColumn", { fg = cc_bg, default = true })
	else
		vim.cmd([[hi default link VirtColumn NonText]])
	end
end

M.set_autocmd = function()
	local group = vim.api.nvim_create_augroup("virtcolumn", {})
	vim.api.nvim_create_autocmd({
		"WinScrolled",
		"TextChanged",
		"TextChangedI",
		"BufWinEnter",
		"InsertLeave",
		"InsertEnter",
		"FileChangedShellPost",
	}, { group = group, callback = M.refresh })
	vim.api.nvim_create_autocmd("OptionSet", {
		group = group,
		callback = function()
			vim.b.virtcolumn_items = nil
			vim.w.virtcolumn_items = nil
			M.update()
		end,
		pattern = "colorcolumn",
	})
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = M.set_hl })
end

return M
