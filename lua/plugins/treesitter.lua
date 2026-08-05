return {
	"nvim-treesitter/nvim-treesitter",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		local treesitter = require("nvim-treesitter")

		treesitter.setup({
			ensure_installed = {
				"vim",
				"vimdoc",
				"rust",
				"regex",
				"c",
				"cpp",
				"go",
				"html",
				"css",
				"javascript",
				"json",
				"lua",
				"markdown",
				"python",
				"typescript",
				"vue",
				"svelte",
				"bash",
				"java",
				"xml",
				"javadoc",
				"angular",
			},

			highlight = {
				enable = true,
				additional_vim_regex_highlighting = false,
			},

			indent = {
				enable = true,
			},
		})
	end,
}
