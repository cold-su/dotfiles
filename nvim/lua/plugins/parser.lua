local M = {
	ts_langs = {
		-- https://github.com/nvim-treesitter/nvim-treesitter#supported-languages
		"bash",
		"c",
		"cmake",
		"comment",
		"cpp",
		"css",
		"dart",
		"diff",
		"dockerfile",
		"fish",
		"git_rebase",
		"gitattributes",
		"gitcommit",
		"gitignore",
		"go",
		"gomod",
		"gosum",
		"gowork",
		"graphql",
		"html",
		"ini",
		"java",
		"javascript",
		"json",
		"json5",
		"jsonc",
		"kdl",
		"latex",
		"lua",
		"luap",
		"make",
		"markdown",
		"markdown_inline",
		"nix",
		"php",
		"pug",
		"python",
		"regex",
		"ruby",
		"ron",
		"rust",
		"scss",
		"smali",
		"sql",
		"svelte",
		"swift",
		"toml",
		"tsx",
		"typescript",
		"vim",
		"vue",
		"yaml",
		"zig",
	},
}

return {
	{
		"HiPhish/rainbow-delimiters.nvim",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		event = { "BufReadPost", "BufNewFile" },
		config = function()
			local rainbow = require("rainbow-delimiters")

			vim.g.rainbow_delimiters = {
				query = {
					[""] = "rainbow-delimiters",
					lua = "rainbow-blocks",
					html = "rainbow-tags",
					javascript = "rainbow-delimiters-react",
				},
				strategy = {
					[""] = rainbow.strategy["global"],
					vim = rainbow.strategy["local"],
				},
			}
		end,
	},
}
