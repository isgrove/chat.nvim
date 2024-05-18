local http = require("socket.http")
local ltn12 = require("ltn12")
local cjson = require("cjson")

local MAX_TOKENS = 1024 / 4
local DEFAULT_MODEL = "gpt-4o"

local M = {}

local OPENAI_API_TOKEN = "secret"

local function streamChat(model, messages)
	model = model or DEFAULT_MODEL

	local url = "https://api.openai.com/v1/chat/completions"

	local request_body = {
		model = model,
		messages = messages,
		stream = true,
	}

	local request_body_json = cjson.encode(request_body)
	local incomplete_buffer = ""
	local content_buffer = ""

	-- Get the current buffer and initialize line number
	local current_buffer = vim.api.nvim_get_current_buf()
	local line_num = vim.api.nvim_buf_line_count(current_buffer) -- Start at the last line

	-- Function to handle each chunk of the response
	local function handle_chunk(chunk)
		if chunk then
			chunk = vim.trim(chunk)

			-- Append the new chunk to the incomplete buffer
			incomplete_buffer = incomplete_buffer .. chunk

			-- Split the buffer on "data: " to process each JSON object
			local parts = vim.split(incomplete_buffer, "data: ", {})

			-- Process each part except the first one (which is before the first "data: " prefix)
			for i = 2, #parts do
				local part = parts[i]

				-- Trim the part to remove any leading/trailing whitespace
				part = vim.trim(part)

				if part == "[DONE]" then
					incomplete_buffer = ""
					return 1
				end

				-- Parse the JSON part
				local ok, parsed = pcall(cjson.decode, part)

				if not ok then
					print("Error parsing JSON:", parsed)
					print("Part:", part)
					return 0
				end

				-- Extract the content from the JSON
				local content = parsed.choices[1].delta.content or ""

				-- Append the content to the content buffer
				content_buffer = content_buffer .. content

				-- Find newline characters in the content buffer
				local lines = vim.split(content_buffer, "\n")

				-- Append each complete line to the current buffer, except the last one
				for j = 1, #lines - 1 do
					vim.api.nvim_buf_set_lines(current_buffer, line_num, line_num, false, { lines[j] })
					line_num = line_num + 1 -- Move to the next line
				end

				-- Keep the last part in the content buffer as it might be incomplete
				content_buffer = lines[#lines]
			end

			-- Keep the last part in the buffer as it might be incomplete
			incomplete_buffer = parts[#parts]
		end
		return 1
	end

	-- Headers for the HTTP request
	local headers = {
		["Content-Type"] = "application/json",
		["Authorization"] = "Bearer " .. OPENAI_API_TOKEN,
		["Content-Length"] = tostring(#request_body_json),
	}

	-- Make the HTTP request
	local _, code, headers, status = http.request({
		url = url,
		method = "POST",
		headers = headers,
		source = ltn12.source.string(request_body_json),
		sink = ltn12.sink.simplify(handle_chunk),
	})

	if code ~= 200 then
		print("Error: " .. (status or "Unknown error"))
	end
end

function M.bufferCompletion(model)
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local content = table.concat(lines, "\n")

	local messages = {
		{ role = "user", content = content },
	}

	streamChat(model, messages)
	-- local num_lines = vim.api.nvim_buf_line_count(bufnr)
end

return M
