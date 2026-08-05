return {
	"saghen/blink.cmp",
	dependencies = {
		"saghen/blink.lib",
		"rafamadriz/friendly-snippets",
		-- Snippets adicionales de Java (complementa, no sustituye del todo)
		{ "ChristianChiarulli/java-snippets", name = "java-snippets" },
	},
	build = function()
		require("blink.cmp").build():pwait()
	end,

	---@module 'blink.cmp'
	---@type blink.cmp.Config
	opts = {
		keymap = {
			preset = "none",
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<C-e>"] = { "hide" },
			["<CR>"] = { "accept", "fallback" },
			["<C-j>"] = { "select_next", "fallback" },
			["<C-k>"] = { "select_prev", "fallback" },
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
			["<Tab>"] = { "snippet_forward", "fallback" },
			["<S-Tab>"] = { "snippet_backward", "fallback" },
		},

		completion = {
			list = {
				selection = {
					preselect = false,
					auto_insert = true,
				},
			},
			menu = {
				border = "rounded",
				-- Muestra el tipo de fuente (LSP, Snippet, Path, Buffer...) para que sepas
				-- de dónde viene cada sugerencia y puedas filtrar mentalmente
				draw = {
					columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "kind" } },
				},
			},
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 200,
				window = { border = "rounded" },
			},
			-- Reduce ruido: no completes con solo 1 carácter escrito, evita sugerencias basura
			trigger = {
				show_on_keyword = true,
			},
		},

		-- === AJUSTE FINO DEL FUZZY MATCHER ===
		fuzzy = {
			implementation = "rust",
			-- Prioriza coincidencias exactas primero, luego el score de fuzzy match,
			-- y por último el sort_text que manda el LSP (útil para Angular/vtsls)
			sorts = { "exact", "score", "sort_text" },
			frecency = { enabled = true },
			use_proximity = true,
		},

		-- === FUENTES: control por filetype ===
		sources = {
			default = { "lsp", "path", "snippets", "buffer" },

			-- Para Java: el LSP (jdtls) es muy completo, así que bajamos el peso del buffer
			-- (evita que te sugiera basura de texto plano del propio archivo)
			per_filetype = {
				java = { "lsp", "snippets", "path" },
				html = { "lsp", "snippets", "path", "buffer" },
				css = { "lsp", "snippets", "path", "buffer" },
				typescript = { "lsp", "snippets", "path", "buffer" },
				typescriptreact = { "lsp", "snippets", "path", "buffer" },
				javascript = { "lsp", "snippets", "path", "buffer" },
				javascriptreact = { "lsp", "snippets", "path", "buffer" },
			},

			providers = {
				lsp = {
					-- Prioriza siempre lo que diga el LSP por encima de snippets/buffer
					score_offset = 3,
				},
				snippets = {
					score_offset = 1,
					opts = {
						friendly_snippets = true,

						-- Frameworks extra de friendly-snippets para tu stack frontend
						-- (lista completa de frameworks disponibles en:
						-- https://github.com/rafamadriz/friendly-snippets/tree/main/snippets/frameworks)
						extended_filetypes = {
							typescriptreact = { "react" },
							javascriptreact = { "react" },
							vue = { "vue" },
							html = { "html-css" },
						},

						-- Añade tu carpeta de snippets propios + la del repo de java-snippets
						search_paths = {
							vim.fn.stdpath("config") .. "/snippets", -- tus sdocclass, sdocv, sdoct, etc.
							vim.fn.stdpath("data") .. "/lazy/java-snippets",
						},
					},
				},
				buffer = {
					score_offset = -3, -- el buffer es el que menos fiabilidad tiene, que aparezca el último
					min_keyword_length = 4, -- evita sugerencias de 1-3 letras sacadas del propio texto
				},
				path = {
					score_offset = 2,
				},
			},
		},
	},
}
