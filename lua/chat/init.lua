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

function M.stream_model_completion(opts)
	opts = opts or {}
	opts.max_tokens = opts.max_tokens or vim.g.max_tokens
	opts.provider = opts.provider or vim.g.current_provider
	opts.model = opts.model or vim.g.current_model
	opts.system_prompt = opts.system_prompt or vim.g.chat_system_prompt

	opts.callback_fn = utils.create_response_writer(opts)

	utils.set_content_opts(opts)

	if opts.replace then
		utils.send_keys("d")
		opts.line_no = opts.line_no - 1
	end

	utils.set_provider_opts(opts)
	utils.set_body_opts(opts)
	utils.set_stdout_fn_opts(opts)

	local args = utils.get_curl_args(opts)

	utils.start_job(opts, args)
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

function M.cancel()
	utils.cancel_job()
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
