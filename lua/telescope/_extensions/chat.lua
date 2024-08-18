local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
	error("chat.nvim requires nvim-telescope/telescope.nvim")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local chat = require("chat")

local pick_model = function(opts)
	opts = opts or {}

	local results = chat.get_models()

	pickers
		.new(opts, {
			prompt_title = "Set AI model",
			finder = finders.new_table({
				results = results,
				entry_maker = function(entry)
					return {
						value = entry,
						display = entry,
						ordinal = entry,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					chat.set_model(selection.value)
				end)
				return true
			end,
		})
		:find()
end

return telescope.register_extension({
	exports = {
		pick_model = pick_model,
	},
})
