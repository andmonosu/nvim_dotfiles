return {
	"mfussenegger/nvim-lint",
	event = {
		"BufReadPre",
		"BufNewFile",
	},
	config = function()
		local lint = require("lint")

		lint.linters_by_ft = {
			lua = { "luacheck" },
			nix = { "statix" },
			javascript = { "biomejs" },
			typescript = { "biomejs" },
			javascriptreact = { "biomejs" },
			typescriptreact = { "biomejs" },
			css = { "stylelint" },
			scss = { "stylelint" },
			vue = { "eslint" },
			dockerfile = { "hadolint" },
			json = { "biomejs" },
			jsonc = { "biomejs" },
			yaml = { "yamllint" },
			java = { "checkstyle" },
			python = { "ruff" },
			rust = { "clippy" },
		}

		lint.linters.luacheck.args = {
			"--globals",
			"vim",
			"hl",
			"--formatter",
			"plain",
			"--codes",
			"--ranges",
			"-",
		}

		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = lint_augroup,
			callback = function()
				lint.try_lint()
			end,
		})

		vim.keymap.set("n", "<leader>cl", function()
			lint.try_lint()
		end, { desc = "[C]ode [L]int" })
	end,
}
