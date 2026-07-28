return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local conform = require("conform")

		conform.setup({
			formatters_by_ft = {
				lua = { "stylua" },
				nix = { "nixfmt" },
				javascript = { "biome" },
				typescript = { "biome" },
				javascriptreact = { "biome" },
				typescriptreact = { "biome" },
				html = { "prettier" },
				css = { "prettier" },
				scss = { "prettier" },
				vue = { "prettier" },
				angular = { "prettier" },
				json = { "biome" },
				jsonc = { "biome" },
				yaml = { "prettier" },
				java = { "google-java-format" },
				python = { "ruff_format" },
				rust = { "rustfmt" },
			},
			format_on_save = {
				lsp_fallback = true,
				async = false,
				timeout_ms = 500,
			},
		})

		vim.keymap.set({ "n", "v" }, "<leader>cf", function()
			conform.format({
				lsp_fallback = true,
				async = false,
				timeout_ms = 500,
			})
		end, { desc = "[C]ode [F]ormat" })
	end,
}
