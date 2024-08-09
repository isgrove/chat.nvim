local M = {}

function M.get_provider_opts(provider)
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

	local data = provider_data[provider]

	if data == nil then
		print("Unknown API provider: " .. provider)
		return
	end

	if data.api_key == nil then
		print("Please provide an " .. data.name .. " API key in setup to use this model")
		return
	end

	return data.url, data.api_key
end

function M.jobstart(command, on_exit, callback, trim_leading, provider)
	vim.g.chat_jobid = vim.fn.jobstart(command, {
		stdout_buffered = false,
		on_exit = on_exit,
		on_stdout = function(_, data, _)
			for _, line in ipairs(data) do
				local data_start = line:find("data: ")
				if data_start then
					line = line:sub(data_start + 6)

					if line == "" then
						break
					end

					if line == "data: [DONE]" then
						return true
					end

					local json = vim.fn.json_decode(line)

					if provider == "anthropic" and json.type == "message_stop" then
						return
					end

					local chunk

					if provider == "anthropic" then
						if json.delta and json.delta.text then
							chunk = json.delta.text
						end
					else
						if json.choices and json.choices[1] and json.choices[1].delta then
							chunk = json.choices[1].delta.content
						end
					end

					if chunk ~= nil then
						-- Remove leading whitespace
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

function M.get_request_body(content, opts)
	local messages = {
		{ role = "user", content = content },
	}

	if opts.provider == "openai" or opts.provider == "groq" then
		table.insert(messages, 1, { role = "system", content = opts.system_prompt })
	end

	local request_body = {
		model = opts.model,
		messages = messages,
		stream = true,
	}

	if opts.provider == "anthropic" then
		request_body.system = opts.system_prompt
		request_body.max_tokens = opts.max_tokens
	end

	return vim.fn.json_encode(request_body)
end

function M.write_to_path(content, path, method)
	method = method or "w"
	local temp = io.open(path, method)
	if temp ~= nil then
		temp:write(content)
		temp:close()
	end
end

function M.get_chat_command(url, api_key, data_path, provider)
	local command = "curl --no-buffer " .. url .. " -H 'Content-Type: application/json' "

	if provider == "openai" or provider == "groq" then
		command = command .. "-H 'Authorization: Bearer " .. api_key .. "' "
	elseif provider == "anthropic" then
		command = command .. "-H 'x-api-key: " .. api_key .. "' -H 'anthropic-version: 2023-06-01' "
	end

	command = command .. "-d @" .. data_path

	return command
end

-- TODO: Find a way to undo the entire GPT response in one :undo
-- https://neovim.io/doc/user/undo.html
function M.create_response_writer(opts)
	opts = opts or {}
	local bufnum = vim.api.nvim_get_current_buf()
	local line_start = opts.line_no or vim.api.nvim_buf_line_count(bufnum)
	local nsnum = vim.api.nvim_create_namespace("gpt")
	local extmarkid = vim.api.nvim_buf_set_extmark(bufnum, nsnum, line_start, 0, {})

	local response = ""
	return function(chunk)
		local num_lines = #(vim.split(response, "\n", {}))
		vim.api.nvim_buf_set_lines(bufnum, line_start, line_start + num_lines, false, {})

		line_start = vim.api.nvim_buf_get_extmark_by_id(bufnum, nsnum, extmarkid, {})[1]

		response = response .. chunk
		vim.api.nvim_buf_set_lines(bufnum, line_start, line_start, false, vim.split(response, "\n", {}))

		vim.cmd("undojoin")
	end
end

function M.get_visual_selection()
	vim.cmd('noau normal! "vy"')
	vim.cmd("noau normal! gv")
	return vim.fn.getreg("v")
end

function M.get_buffer_content()
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	return table.concat(lines, "\n")
end

function M.send_keys(keys)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "m", false)
end

return M
