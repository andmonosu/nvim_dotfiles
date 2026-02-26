vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Remove search highlights" })

vim.keymap.set("v", "<", "<gv", { desc = "Indent left in visual mode" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right in visual mode" })

local diagnostics_enabled = true

vim.keymap.set("n", "<leader>Td", function()
    diagnostics_enabled = not diagnostics_enabled

    if diagnostics_enabled then
        vim.diagnostic.config({
            virtual_text = {
                severity = { max = vim.diagnostic.severity.WARN },
            },
            virtual_lines = {
                severity = { min = vim.diagnostic.severity.ERROR },
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
