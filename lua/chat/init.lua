local utils = require("chat.utils")

local M = {}

function M.setup(opts)
	local openai_api_key = opts.openai_api_key
	local groq_api_key = opts.groq_api_key
	local anthropic_api_key = opts.anthropic_api_key

	local default_provider = opts.default_provider
	local default_model = opts.default_model

	local model_provider = opts.model_provider

	if not openai_api_key and not groq_api_key and not anthropic_api_key then
		error("chat.nvim required an API key for a least one provider (OpenAI, Groq or Anthropic).")
	end

	if not default_model or not default_provider then
		error("chat.nvim required a default_provider and a default_model")
	end

	vim.g.openai_api_key = openai_api_key
	vim.g.groq_api_key = groq_api_key
	vim.g.anthropic_api_key = anthropic_api_key

	vim.g.chat_system_prompt = opts.system_prompt or "You are a helpful assistant."

	vim.g.current_provider = default_provider
	vim.g.current_model = default_model

	vim.g.model_provider = model_provider

	vim.g.max_tokens = opts.max_tokens or 4096
end

local function stream_chat(content, opts)
	local identity1 = function(chunk)
		return chunk
	end

	local identity = function() end

	opts = opts or {}
	opts.max_tokens = opts.max_tokens or vim.g.max_tokens
	opts.provider = opts.provider or vim.g.current_provider
	opts.model = opts.model or vim.g.current_model

	local on_chunk = opts.on_chunk or identity1
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

	utils.jobstart(command, on_exit, on_chunk, trim_leading, opts.provider)
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

local function get_model_provider()
	return vim.g.model_provider
end

function M.set_model(model)
	local provider = get_model_provider()[model]
	vim.g.current_provider = provider
	vim.g.current_model = model
end

function M.get_models()
	local model_list = {}
	local model_provider = get_model_provider()
	for model, _ in pairs(model_provider) do
		table.insert(model_list, model)
	end
	return model_list
end

return M
