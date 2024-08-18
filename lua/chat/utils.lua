local M = {}
local Job = require("plenary.job")

local active_job = nil

function M.set_provider_opts(opts)
	local provider_data = {
		openai = {
			api_key = vim.g.openai_api_key,
			name = "OpenAI",
			url = "https://api.openai.com/v1/chat/completions",
		},
		groq = {
			api_key = vim.g.groq_api_key,
			name = "Groq",
			url = "https://api.groq.com/openai/v1/chat/completions",
		},
		anthropic = {
			api_key = vim.g.anthropic_api_key,
			name = "Anthropic",
			url = "https://api.anthropic.com/v1/messages",
		},
	}

	local data = provider_data[opts.provider]

	if data == nil then
		print("Unknown API provider: " .. opts.provider)
		return
	end

	if data.api_key == nil then
		print("Please provide an " .. data.name .. " API key in setup to use this model")
		return
	end

	opts.url = data.url
	opts.api_key = data.api_key
end

function M.handle_openai_stdout(callback, data)
	if not data:match('"delta":') then
		return
	end

	local json = vim.json.decode(data)

	if json.choices and json.choices[1] and json.choices[1].delta then
		local content = json.choices[1].delta.content
		if content then
			callback(content)
		end
	end
end

function M.handle_anthropic_stdout(callback, data, event_state)
	if event_state ~= "content_block_delta" then
		return
	end

	local json = vim.json.decode(data)

	if json.delta and json.delta.text then
		callback(json.delta.text)
	end
end

function M.set_stdout_fn_opts(opts)
	if opts.provider == "openai" or opts.provider == "groq" then
		opts.stdout_fn = function(data)
			M.handle_openai_stdout(opts.callback_fn, data)
		end
	else
		opts.stdout_fn = function(data, event_state)
			M.handle_anthropic_stdout(opts.callback_fn, data, event_state)
		end
	end
end

function M.start_job(opts, args)
	if active_job then
		print("AI completion already in progress")
		return active_job
	end

	local current_event_state = nil

	local function parse_and_call(line)
		local event = line:match("^event: (.+)$")
		if event then
			current_event_state = event
			return
		end
		local data = line:match("^data: (.+)$")
		if data then
			opts.stdout_fn(data, current_event_state)
		end
	end

	active_job = Job:new({
		command = "curl",
		args = args,
		on_stdout = function(_, data)
			parse_and_call(data)
		end,
		on_exit = function()
			active_job = nil
		end,
	})

	active_job:start()

	return active_job
end

function M.cancel_job()
	if not active_job then
		return
	end

	active_job:shutdown()
	active_job = nil

	print("Canceled AI completion")
end

function M.set_body_opts(opts)
	local messages = {
		{ role = "user", content = opts.content },
	}

	if opts.provider == "openai" or opts.provider == "groq" then
		table.insert(messages, 1, { role = "system", content = opts.system_prompt })
	end

	local body = {
		model = opts.model,
		messages = messages,
		stream = true,
		max_tokens = opts.max_tokens,
	}

	if opts.provider == "anthropic" then
		body.system = opts.system_prompt
	end

	opts.body = body
end

function M.get_curl_args(opts)
	local args = { "--no-buffer", opts.url, "-H", "Content-Type: application/json", "-d", vim.json.encode(opts.body) }

	if opts.provider == "openai" or opts.provider == "groq" then
		table.insert(args, "-H")
		table.insert(args, "Authorization: Bearer " .. opts.api_key)
	elseif opts.provider == "anthropic" then
		table.insert(args, "-H")
		table.insert(args, "x-api-key: " .. opts.api_key)
		table.insert(args, "-H")
		table.insert(args, "anthropic-version: 2023-06-01")
	end

	return args
end

-- TODO: Find a way to undo the entire GPT response in one :undo
-- https://neovim.io/doc/user/undo.html
-- what does this do?
function M.create_response_writer(opts)
	opts = opts or {}
	local bufnum = vim.api.nvim_get_current_buf()
	local line_start = opts.line_no or vim.api.nvim_buf_line_count(bufnum)
	local nsnum = vim.api.nvim_create_namespace("gpt")
	local extmarkid = vim.api.nvim_buf_set_extmark(bufnum, nsnum, line_start, 0, {})

	local response = ""
	return function(chunk)
		vim.schedule(function()
			local num_lines = #(vim.split(response, "\n", {}))
			vim.api.nvim_buf_set_lines(bufnum, line_start, line_start + num_lines, false, {})

			line_start = vim.api.nvim_buf_get_extmark_by_id(bufnum, nsnum, extmarkid, {})[1]

			response = response .. chunk
			vim.api.nvim_buf_set_lines(bufnum, line_start, line_start, false, vim.split(response, "\n", {}))

			vim.cmd("undojoin")
		end)
	end
end

function M.send_keys(keys)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "m", false)
end

function M.set_content_opts(opts)
	local mode = vim.api.nvim_get_mode().mode

	if mode == "v" or mode == "V" then
		vim.cmd('noau normal! "vy"')
		vim.cmd("noau normal! gv")

		opts.content = vim.fn.getreg("v")
		opts.line_no = vim.fn.line(".")
	else
		local bufnr = vim.api.nvim_get_current_buf()
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local bufnum = vim.api.nvim_get_current_buf()

		opts.content = table.concat(lines, "\n")
		opts.line_no = vim.api.nvim_buf_line_count(bufnum)
	end
end

return M
