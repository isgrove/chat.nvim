local utils = require("chat.utils")

local DEFAULT_MODEL = "gpt-4o"
local DEFAULT_PROVIDER = "openai" -- or groq
local MAX_TOKENS = 1024

local M = {}

function M.setup(opts)
	local openai_api_key = opts.openai_api_key
	local groq_api_key = opts.groq_api_key

	if not openai_api_key and not groq_api_key then
		print("Please provide an API key for OpenAI, or Groq")
		return
	end
	vim.g.openai_api_key = openai_api_key
	vim.g.groq_api_key = groq_api_key
	vim.g.chat_system_prompt = opts.system_prompt or "You are a helpful assistant."
end

local function stream_chat(content, opts)
	local identity1 = function(chunk)
		return chunk
	end

	local identity = function() end

	opts = opts or {}
	opts.max_tokens = opts.max_tokens or MAX_TOKENS
	opts.provider = opts.provider or DEFAULT_PROVIDER
	opts.model = opts.model or DEFAULT_MODEL

	local callback = opts.on_chunk or identity1
	local on_exit = opts.on_exit or identity
	local trim_leading = opts.trim_leading or true
	local url, api_key = utils.get_provider_opts(opts.provider)

	local request_body_json = utils.get_request_body(content, opts)
	local request_body_path = os.getenv("HOME") .. "/.local/share/nvim/chat_query.json"

	-- NOTE: This is not ideal as we need to read/write from the disk, but this is the best way
	-- I found to avoid new lines, quotes, backticks and etc. causing errors. From the curl man:
	-- "When -d, --data is told to read from a file like that, carriage returns and newlines are stripped out"
	-- TODO: Find a better method of doing this that avoids IO
	utils.write_to_path(request_body_json, request_body_path)

	local command = utils.get_chat_command(url, api_key, request_body_path, opts.provider)
	utils.jobstart_openai(command, on_exit, callback, trim_leading)
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

	local content = utils.get_visual_selection()
	local system_prompt = vim.g.chat_system_prompt

	utils.send_keys("d")

	if mode == "V" then
		utils.send_keys("O")
	end

	stream_chat(content, {
		system_prompt = system_prompt,
		model = model,
		provider = provider,
		trim_leading = false,
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
		content = utils.get_visual_selection()
	else
		local bufnum = vim.api.nvim_get_current_buf()
		opts.line_no = vim.api.nvim_buf_line_count(bufnum)
		content = utils.get_buffer_content()
	end

	stream_chat(content, {
		system_prompt = system_prompt,
		model = model,
		provider = provider,
		trim_leading = false,
		on_chunk = utils.create_response_writer(opts),
	})
end

return M
