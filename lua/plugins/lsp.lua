return {
	"neovim/nvim-lspconfig",
	dependencies = { "saghen/blink.cmp" },
	config = function()
		local capabilities = require("blink.cmp").get_lsp_capabilities()
		vim.lsp.config("lua_ls", {
			capabilities = capabilities,
			settings = {
				Lua = {
					diagnostics = { globals = { "vim", "hl" } },
					telemetry = { enable = false },
				},
			},
		})
		vim.lsp.enable("lua_ls")

		vim.lsp.config("vtsls", {
			capabilities = capabilities,
			settings = {
				typescript = {
					inlayHints = {
						parameterNames = { enabled = "literals" },
						variableTypes = { enabled = true },
						propertyDeclarationTypes = { enabled = true },
						functionLikeReturnTypes = { enabled = true },
					},
					updateImportsOnFileMove = { enabled = "always" },
					suggest = { completeFunctionCalls = true },
				},
				vtsls = {
					experimental = {
						completion = { enableServerSideFuzzyMatch = true },
					},
				},
			},
		})
		vim.lsp.enable("vtsls")

		vim.lsp.config("lemminx", {
			capabilities = capabilities,
			cmd = { "lemminx" },
			settings = {
				xml = {
					server = {
						workDir = vim.fn.stdpath("cache") .. "/lemminx",
					},
					validation = {
						enabled = true,
						schema = true,
					},
				},
			},
		})
		vim.lsp.enable("lemminx")

		local servers = {
			"nixd",
			"html",
			"cssls",
			"angularls",
			"vue_ls",
			"dockerls",
			"docker_compose_language_service",
			"jsonls",
			"yamlls",
			"qmlls",
			"pyright",
			"rust_analyzer",
		}

		for _, server in ipairs(servers) do
			vim.lsp.config(server, {
				capabilities = capabilities,
			})
			vim.lsp.enable(server)
		end

		vim.filetype.add({
			extension = {
				qml = "qml",
			},
			filename = {
				["docker-compose.yaml"] = "yaml.docker-compose",
				["docker-compose.yml"] = "yaml.docker-compose",
				["compose.yaml"] = "yaml.docker-compose",
				["compose.yml"] = "yaml.docker-compose",
				[".gitlab-ci.yml"] = "yaml.gitlab",
				[".gitlab-ci.yaml"] = "yaml.gitlab",
			},
			pattern = {
				[".*/docker-compose%.y[a]?ml"] = "yaml.docker-compose",
				[".*/compose%.y[a]?ml"] = "yaml.docker-compose",
				[".*/values%.yaml"] = "yaml.helm-values",
				[".*/values%.yml"] = "yaml.helm-values",
				["charts/.*/templates/.*%.yaml"] = "yaml.helm-values",
				["charts/.*/templates/.*%.yml"] = "yaml.helm-values",
			},
		})

		-- [KEMAPS DE LSP UNIFICADOS]
		-- Documentación y Definiciones
		vim.keymap.set("n", "<leader>ch", vim.lsp.buf.hover, { desc = "Mostrar Documentación (Hover)" })
		vim.keymap.set("n", "<leader>cd", vim.lsp.buf.definition, { desc = "Ir a Definición" })
		vim.keymap.set("n", "<leader>cD", vim.lsp.buf.declaration, { desc = "Ir a Declaración" })
		vim.keymap.set("n", "<leader>ce", vim.diagnostic.open_float, {
			desc = "Código: Ver diagnóstico de la línea (LSP)",
		})
		vim.keymap.set("n", "<leader>cn", vim.diagnostic.goto_next, { desc = "Código: Siguiente diagnóstico" })
		vim.keymap.set("n", "<leader>cp", vim.diagnostic.goto_prev, { desc = "Código: Anterior diagnóstico" })

		-- Acciones y Refactorización
		vim.keymap.set(
			{ "n", "v" },
			"<leader>ca",
			vim.lsp.buf.code_action,
			{ desc = "Acciones de Código (Code Actions)" }
		)
		vim.keymap.set("n", "<leader>cR", vim.lsp.buf.rename, { desc = "Renombrar Símbolo" })

		-- Búsquedas con Telescope
		vim.keymap.set("n", "<leader>cr", require("telescope.builtin").lsp_references, { desc = "Buscar Referencias" })
		vim.keymap.set(
			"n",
			"<leader>ci",
			require("telescope.builtin").lsp_implementations,
			{ desc = "Buscar Implementaciones" }
		)
	end,
}
