require("gitsigns").setup({

	signs = {
		add = { text = "+" },
		change = { text = "~" },
		delete = { text = "-" },
		topdelete = { text = "^" },
		changedelete = { text = "%" },
		untracked = { text = "┆" },
	},
	signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
	numhl = true, -- Toggle with `:Gitsigns toggle_numhl`
	linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
	word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
	on_attach = function(bufnr)
		-- Navigation
		vim.keymap.set("n", "]c", function()
			if vim.wo.diff then
				vim.cmd.normal({ "]c", bang = true })
			else
				require("gitsigns").nav_hunk("next")
			end
		end, {
			buffer = bufnr,
			desc = "Gitsigns: next hunk",
		})

		vim.keymap.set("n", "[c", function()
			if vim.wo.diff then
				vim.cmd.normal({ "[c", bang = true })
			else
				require("gitsigns").nav_hunk("prev")
			end
		end, { buffer = bufnr, desc = "Gitsings: prev hunk" })

		-- Actions
		vim.keymap.set(
			"n",
			"<leader>hs",
			require("gitsigns").stage_hunk,
			{ buffer = bufnr, desc = "Gitsings: stage hunk" }
		)
		vim.keymap.set(
			"n",
			"<leader>hr",
			require("gitsigns").reset_hunk,
			{ buffer = bufnr, desc = "Gitsings: reset hunk" }
		)
		vim.keymap.set("v", "<leader>hs", function()
			require("gitsigns").stage_hunk({
				vim.fn.line("."),
				vim.fn.line("v"),
			})
		end, { buffer = bufnr, desc = "Gitsings: stage hunk" })
		vim.keymap.set("v", "<leader>hr", function()
			require("gitsigns").reset_hunk({
				vim.fn.line("."),
				vim.fn.line("v"),
			})
		end, { buffer = bufnr, desc = "Gitsings: reset hunk" })
		vim.keymap.set(
			"n",
			"<leader>hS",
			require("gitsigns").stage_buffer,
			{ buffer = bufnr, desc = "Gitsings: stage buffer" }
		)
		vim.keymap.set(
			"n",
			"<leader>hu",
			require("gitsigns").undo_stage_hunk,
			{ buffer = bufnr, desc = "Gitsings: undo stage buffer" }
		)
		vim.keymap.set(
			"n",
			"<leader>hR",
			require("gitsigns").reset_buffer,
			{ buffer = bufnr, desc = "Gitsings: reset buffer" }
		)
		vim.keymap.set(
			"n",
			"<leader>hp",
			require("gitsigns").preview_hunk,
			{ buffer = bufnr, desc = "Gitsings: preview hunk" }
		)
		vim.keymap.set("n", "<leader>hb", function()
			require("gitsigns").blame_line({ full = true })
		end, { buffer = bufnr, desc = "Gitsings: blame line" })
		vim.keymap.set(
			"n",
			"<leader>tb",
			require("gitsigns").toggle_current_line_blame
		)
		vim.keymap.set(
			"n",
			"<leader>hd",
			require("gitsigns").diffthis,
			{ buffer = bufnr, desc = "Gitsings: diff this" }
		)
		vim.keymap.set("n", "<leader>hD", function()
			require("gitsigns").diffthis("~")
		end, { buffer = bufnr, desc = "Gitsings: diff this ~" })
		vim.keymap.set(
			"n",
			"<leader>htd",
			require("gitsigns").toggle_deleted,
			{ buffer = bufnr, desc = "Gitsings: toggle deleted" }
		)
		vim.keymap.set("n", "<leader>htt", function()
			require("gitsigns").toggle_linehl()
			require("gitsigns").toggle_word_diff()
		end, { buffer = bufnr, desc = "Gitsings: toggle highlight" })

		-- Text object
		vim.keymap.set(
			{
				"o",
				"x",
			},
			"ih",
			":<C-U>Gitsigns select_hunk<CR>",
			{ buffer = bufnr, desc = "Gitsings: select hunk" }
		)
	end,
})
