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

    local function set_keymap(mode, key, func, desc)
      vim.keymap.set(mode, key, func, { desc = desc, noremap = true, silent = true })
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
      default_provider = 'anthropic',
      default_model = 'claude-3-5-sonnet-20240620',
      model_provider = {
        ['claude-3-5-sonnet-20240620'] = 'anthropic',
        ['llama-3.1-70b-versatile'] = 'groq',
        ['gpt-4o'] = 'openai',
      },
    }

    set_keymap('n', '<leader>ac', function()
      chat.completion()
    end, '[A]I [C]ompletion')

    set_keymap('v', '<leader>ac', function()
      chat.completion()
    end, '[A]I [C]ompletion')

    set_keymap('v', '<leader>ar', function()
      chat.selection_replace()
    end, '[A]I [C]ompletion')

    set_keymap('n', '<leader>an', function()
      chat.change_system_prompt 'new'
    end, '[A]I [N]ew system pompt')

    set_keymap('n', '<leader>ae', function()
      chat.change_system_prompt 'edit'
    end, '[A]I [E]dit system prompt')
  end,
},
```

## Telescope Extension

First, register chat.nvim as a Telescope extension
```lua
pcall(require('telescope').load_extension, 'chat')
```

Then you can set a keymap to pick the current model:
```lua
vim.keymap.set('n', '<leader>am', function()
  require('telescope').extensions.chat.pick_model()
end, { desc = '[A]I Pick current [M]odel' })
```

Or you can use it as a command:
```
:Telescope chat pick_model
```

## TODO
- [x] Let users toggle between models instead of having a hotkey for each one
- [ ] Save multiple system prompts and toggle between them
- [ ] Add Google Gemini support
- [x] Add Anthropic calude support
- [ ] Let users configure the max tokens
- [ ] Add a function to cancel the current stream
- [ ] Make it easier to add new model provider APIs
- [x] Make the config file more simple

