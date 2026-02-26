return {
    'folke/which-key.nvim',
    event = 'VimEnter',
    config = function()
        -- gain access to the which key plugin
        local which_key = require('which-key')

        local icons = require("config.icons") -- ajusta la ruta a tu archivo de iconos

        which_key.setup({
            preset = "modern",
            delay = 300,

            -- Posición: esquina inferior derecha
            win = {
                border = "rounded",
                padding = { 1, 2 },
                title = true,
                title_pos = "center",
                wo = {
                    winblend = 10,
                },
                width = 80
            },

            layout = {
                width = { min = 30, max = 70 },
                spacing = 3,
                align = "right"
            },

            icons = {
                breadcrumb = icons.ui.DoubleChevronRight,
                separator  = icons.ui.ChevronRight,
                group      = icons.ui.Plus,
                mappings   = true,
            },
        })

        -- Register prefixes for the different key mappings we have setup previously
        which_key.add({
            { '<leader>/',  group = 'Comments',   icon = { icon = icons.ui.Comment,      color = 'grey'   } },
            { '<leader>c',  group = '[C]ode',     icon = { icon = icons.ui.Code,         color = 'orange' } },
            { '<leader>d',  group = '[D]ebug',    icon = { icon = icons.ui.Bug,          color = 'red'    } },
            { '<leader>e',  group = '[E]xplorer', icon = { icon = icons.ui.FolderOpen,   color = 'blue'   } },
            { '<leader>f',  group = '[F]ind',     icon = { icon = icons.ui.Telescope,    color = 'cyan'   } },
            { '<leader>g',  group = '[G]it',      icon = { icon = icons.git.Git,        color = 'red'  } },
            { '<leader>J',  group = '[J]ava',     icon = { icon = icons.misc.CircuitBoard, color = 'azure'} },
            { '<leader>w',  group = '[W]indow',   icon = { icon = icons.ui.List,         color = 'purple' } },
            { '<leader>t',  group = '[T]rouble',  icon = { icon = icons.diagnostics.Warning, color = 'yellow' } },
            { '<leader>T',  group = '[T]oggle',   icon = { icon = icons.ui.Gear,         color = 'grey'   } },
        })

    end
}
