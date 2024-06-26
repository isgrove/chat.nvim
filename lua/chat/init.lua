local MAX_TOKENS = 1024 / 4
local DEFAULT_MODEL = "gpt-4o"
local DEFAULT_PROVIDER = "openai" -- or groq

local M = {}

function M.setup(opts)
	local system_prompt = opts.system_prompt or "You are a helpful assistant."
	local openai_api_key = opts.openai_api_key
	local groq_api_key = opts.groq_api_key

	if openai_api_key == nil and groq_api_key == nil then
		print("Please provide either an OpenAI or Groq API key")
		return
	end

	if openai_api_key ~= nil then
		vim.g.openai_api_key = openai_api_key
	end

	if groq_api_key ~= nil then
		vim.g.groq_api_key = groq_api_key
	end

	vim.g.chat_system_prompt = system_prompt
end

local function get_provider_opts(provider)
	if provider == "openai" then
		if vim.g.openai_api_key == nil then
			print("Please provide an OpenAI API key in setup to use this model")
			return
		end

		return "https://api.openai.com/v1/chat/completions", vim.g.openai_api_key
	elseif provider == "groq" then
		if vim.g.groq_api_key == nil then
			print("Please provide an Groq API key in setup to use this model")
			return
		end

		return "https://api.groq.com/openai/v1/chat/completions", vim.g.groq_api_key
	else
		print("Uknown API provider: " .. provider)
		return
	end
end

local function stream_chat(messages, opts)
	local identity1 = function(chunk)
		return chunk
	end

	local identity = function() end

	opts = opts or {}
	local model = opts.model or DEFAULT_MODEL
	local provider = opts.provider or DEFAULT_PROVIDER
	local callback = opts.on_chunk or identity1
	local on_exit = opts.on_exit or identity
	local trim_leading = opts.trim_leading or true
	local url, api_key = get_provider_opts(provider)

	local request_body = {
		model = model,
		messages = messages,
		stream = true,
	}

	local request_body_json = vim.fn.json_encode(request_body)

	-- NOTE: This is not ideal as we need to read/write from the disk, but this is the best way
	-- I found to avoid new lines, quotes, backticks and etc. causing errors. From the curl man:
	-- "When -d, --data is told to read from a file like that, carriage returns and newlines are stripped out"
	-- TODO: Find a better method of doing this that avoids IO
	local request_body_path = os.getenv("HOME") .. "/.local/share/nvim/chat_query.json"
	local temp = io.open(request_body_path, "w")
	if temp ~= nil then
		temp:write(request_body_json)
		temp:close()
	end

	local command = "curl --no-buffer "
		.. url
		.. " "
		.. "-H 'Content-Type: application/json' -H 'Authorization: Bearer "
		.. api_key
		.. "' "
		.. "-d @"
		.. request_body_path

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
-- https://neovim.io/doc/user/undo.html
local function create_response_writer(opts)
	opts = opts or {}
	local bufnum = vim.api.nvim_get_current_buf()
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

local function get_visual_selection()
	vim.cmd('noau normal! "vy"')
	vim.cmd("noau normal! gv")
	return vim.fn.getreg("v")
end

local function get_buffer_content()
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	return table.concat(lines, "\n")
end

local function send_keys(keys)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "m", false)
end

function M.change_system_prompt(method)
	local system_prompt = vim.g.chat_system_prompt
	local opts = { prompt = "[Prompt]: ", cancelreturn = "__CANCEL__" }

	if method == "edit" then
		opts.default = system_prompt
	end

	system_prompt = vim.fn.input(opts)

	if system_prompt == "__CANCEL__" then
		return
	end

	vim.g.chat_system_prompt = system_prompt
end

function M.selection_replace(model, provider)
	local mode = vim.api.nvim_get_mode().mode
	if mode ~= "v" and mode ~= "V" then
		print("Please select some text")
		return
	end

	local content = get_visual_selection()
	local system_prompt = vim.g.chat_system_prompt
	local messages = {
		{ role = "system", content = system_prompt },
		{ role = "user", content = content },
	}

	send_keys("d")

	if mode == "V" then
		send_keys("O")
	end

	stream_chat(messages, {
		model = model,
		provider = provider,
		trim_leading = true,
		on_chunk = function(chunk)
			chunk = vim.split(chunk, "\n", {})
			vim.api.nvim_put(chunk, "c", mode == "V", true)
			vim.cmd("undojoin")
		end,
	})
end

function M.completion(model, provider)
	local system_prompt = vim.g.chat_system_prompt
	local mode = vim.api.nvim_get_mode().mode
	local content
	local opts = {}

	if mode == "v" or mode == "V" then
		opts.line_no = vim.fn.line(".")
		content = get_visual_selection()
	else
		local bufnum = vim.api.nvim_get_current_buf()
		opts.line_no = vim.api.nvim_buf_line_count(bufnum)
		content = get_buffer_content()
	end

	local messages = {
		{ role = "system", content = system_prompt },
		{ role = "user", content = content },
	}

	stream_chat(messages, {
		model = model,
		provider = provider,
		trim_leading = true,
		on_chunk = create_response_writer(opts),
	})
end

return M
