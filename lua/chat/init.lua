local cjson = require("cjson")

local MAX_TOKENS = 1024 / 4
local DEFAULT_MODEL = "gpt-4o"

local M = {}


local function streamChat(messages, opts)
	local url = "https://api.openai.com/v1/chat/completions"

	local identity1 = function(chunk)
		return chunk
	end

	local identity = function() end

	opts = opts or {}
	local model = opts.model or DEFAULT_MODEL
	local callback = opts.on_chunk or identity1
	local on_exit = opts.on_exit or identity
	local trim_leading = opts.trim_leading or true

	local request_body = {
		model = model,
		messages = messages,
		stream = true,
	}

	local request_body_json = cjson.encode(request_body)

	local command = "curl --no-buffer "
		.. url
		.. " "
		.. "-H 'Content-Type: application/json' -H 'Authorization: Bearer "
		.. OPENAI_API_TOKEN
		.. "' "
		.. "-d '"
		.. request_body_json
		.. "'"

	vim.g.chat_jobid = vim.fn.jobstart(command, {
		stdout_buffered = false,
		on_exit = on_exit,
		on_stdout = function(_, data, _)
			for _, line in ipairs(data) do
				if line ~= "" then
					-- Strip token to get down to the JSON
					line = line:gsub("^data: ", "")
					if line == "" then
						break
					end
					local json = vim.fn.json_decode(line)
					local chunk = json.choices[1].delta.content

					if chunk ~= nil then
						if trim_leading then
							chunk = chunk:gsub("^%s+", "")
							if chunk ~= "" then
								trim_leading = false
							end
						end
						callback(chunk)
					end
				end
			end
		end,
	})
end

-- TODO: Find a way to undo the entire GPT response in one :undo
local function create_response_writer(opts)
	opts = opts or {}
	local bufnum = vim.api.nvim_get_current_buf()
	-- local line_start = opts.line_no or vim.fn.line(".")
	local line_start = opts.line_no or vim.api.nvim_buf_line_count(bufnum)
	local nsnum = vim.api.nvim_create_namespace("gpt")
	local extmarkid = vim.api.nvim_buf_set_extmark(bufnum, nsnum, line_start, 0, {})

	local response = ""
	return function(chunk)
		-- Delete the currently written response
		local num_lines = #(vim.split(response, "\n", {}))
		vim.api.nvim_buf_set_lines(bufnum, line_start, line_start + num_lines, false, {})

		-- Update the line start to wherever the extmark is now
		line_start = vim.api.nvim_buf_get_extmark_by_id(bufnum, nsnum, extmarkid, {})[1]

		-- Write out the latest
		response = response .. chunk
		vim.api.nvim_buf_set_lines(bufnum, line_start, line_start, false, vim.split(response, "\n", {}))

		vim.cmd("undojoin")
	end
end

function M.bufferCompletion()
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local content = table.concat(lines, "\n")

	local messages = {
		{ role = "user", content = content },
	}

	streamChat(messages, {
		trim_leading = true,
		on_chunk = create_response_writer(),
	})
end

return M
