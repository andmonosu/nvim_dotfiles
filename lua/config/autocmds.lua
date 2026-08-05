vim.cmd.colorscheme("melange")
vim.deprecate = function() end
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client and client.name == "angularls" then
			client.server_capabilities.renameProvider = false
		end
	end,
})
