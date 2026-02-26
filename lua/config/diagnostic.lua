local icons = require("config.icons")

local function diagnostic_prefix(diagnostic)
	local severity = vim.diagnostic.severity
	local map = {
		[severity.ERROR] = icons.diagnostics.Error,
		[severity.WARN] = icons.diagnostics.Warning,
		[severity.HINT] = icons.diagnostics.Hint,
		[severity.INFO] = icons.diagnostics.Information,
	}
	return (map[diagnostic.severity] or "") .. " "
end

vim.diagnostic.config({
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = icons.diagnostics.Error,
			[vim.diagnostic.severity.WARN] = icons.diagnostics.Warning,
			[vim.diagnostic.severity.HINT] = icons.diagnostics.Hint,
			[vim.diagnostic.severity.INFO] = icons.diagnostics.Information,
		},
		numhl = {
			[vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
			[vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
			[vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
			[vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
		},
	},
	virtual_text = {
		severity = { max = vim.diagnostic.severity.WARN },
		prefix = diagnostic_prefix,
	},
	virtual_lines = {
		severity = { min = vim.diagnostic.severity.ERROR },
		prefix = diagnostic_prefix,
	},
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	float = {
		focusable = true,
		style = "minimal",
		border = "rounded",
		source = "always",
		header = "",
		prefix = "",
	},
})

local diagnostics_enabled = true

vim.keymap.set("n", "<leader>Td", function()
	diagnostics_enabled = not diagnostics_enabled

	if diagnostics_enabled then
		vim.diagnostic.config({
			virtual_text = {
				severity = { max = vim.diagnostic.severity.WARN },
				prefix = diagnostic_prefix,
			},
			virtual_lines = {
				severity = { min = vim.diagnostic.severity.ERROR },
				prefix = diagnostic_prefix,
			},
		})
		vim.notify("Diagnostics ON", vim.log.levels.INFO)
	else
		vim.diagnostic.config({
			virtual_text = false,
			virtual_lines = false,
		})
		vim.notify("Diagnostics OFF", vim.log.levels.INFO)
	end
end, { desc = "Toggle diagnostics" })
