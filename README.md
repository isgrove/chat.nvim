# chat.nvim
Make requests to LLMs right from Neovim. Here is what you can do:
- Replace the selected text
- Get a completion for the selected text
- Get a completion for the text in the current buffer
- Change or edit the system prompt

## Setup
Install with your package manager:
```lua
{
  '/isgrove/chat.nvim',
  config = function()
    local chat = require 'chat'

    local function set_keymap(mode, key, model, provider, desc)
      vim.keymap.set(mode, key, function()
        chat.completion(model, provider)
      end, { desc = desc, noremap = true, silent = true })
    end

    local function set_replace_keymap(key, model, provider, desc)
      vim.keymap.set('v', key, function()
        chat.selection_replace(model, provider)
      end, { desc = desc, noremap = true, silent = true })
    end

    chat.setup {
      system_prompt = 'There are instructions in the code comments. Only '
        .. "output code based on what you've seen. Mostly copy it, but "
        .. 'attend to the instructions and modulate it according to what the '
        .. 'instructions say. Only output valid code. If you must speak, '
        .. 'make sure it must compile (Only keep it in the code comments). '
        .. 'Filter out from your answer everything that is not code, '
        .. 'including the formatting backticks ```',
      openai_api_key = os.getenv 'OPENAI_API_KEY',
      groq_api_key = os.getenv 'GROQ_API_KEY',
      anthropic_api_key = os.getenv 'ANTHROPIC_API_KEY',
    }

    local claude = 'claude-3-5-sonnet-20240620'
    local llama = 'llama3-70b-8192'
    local gpt = 'gpt-4o'

    for _, mode in ipairs { 'n', 'v' } do
      set_keymap(mode, '<leader>acg', gpt, 'openai', '[A]I [C]ompletion using [G]PT-4o')
      set_keymap(mode, '<leader>acl', llama, 'groq', '[A]I [C]ompletion using [L]lama 3 70B')
      set_keymap(mode, '<leader>aco', claude, 'anthropic', '[A]I [C]ompletion using Claude [O]pus')
    end

    set_replace_keymap('<leader>arg', gpt, 'openai', '[A]I [R]eplacement using [G]PT-4o')
    set_replace_keymap('<leader>arl', llama, 'groq', '[A]I [R]eplacement using [L]lama 3 70B')
    set_replace_keymap('<leader>aro', claude, 'anthropic', '[A]I [R]eplacement using Claude [O]pus')

    vim.keymap.set('n', '<leader>an', function()
      chat.change_system_prompt 'new'
    end, { desc = '[A]I [N]ew system pompt', noremap = true, silent = true })

    vim.keymap.set('n', '<leader>ae', function()
      chat.change_system_prompt 'edit'
    end, { desc = '[A]I [E]dit system prompt', noremap = true, silent = true })
  end,
},
```

## TODO
- [ ] Let users toggle between models instead of having a hotkey for each one
- [ ] Save multiple system prompts and toggle between them
- [ ] Add Google Gemini support
- [x] Add Anthropic calude support
- [ ] Support larger token lengths
- [ ] Add a function to cancel the current stream
- [ ] Make it easier to add new model APIs
- [ ] Make the config file more simple
