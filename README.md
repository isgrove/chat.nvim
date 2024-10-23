# chat.nvim
Integrate AI-assisted coding into your Neovim workflow. This plugin leverages Large Language Models (LLMs) to provide users with features like code completion and editing.

Use the following commands to interact with the plugin:
- `[A]I [C]ompletion`: Stream model completion for the current cursor position or selected text.
- `[A]I [R]eplace`: Replace the current cursor position or selected text with the model completion result.
- `[A]I [N]ew system prompt`: Change the system prompt for the AI model.
- `[A]I [E]dit system prompt`: Edit the current system prompt for the AI model.
- `[A]I Pick current [M]odel`: Select the current AI model using Telescope.

## Setup
Install with your package manager:
```lua
{
  '/isgrove/chat.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  config = function()
    local chat = require 'chat'

    local function set_keymap(mode, key, func, desc)
      vim.keymap.set(mode, key, func, { desc = desc, noremap = true, silent = true })
    end

    chat.setup {
      system_prompt = 'You should replace the code that you are sent, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them. Other comments should left alone. Do not output backticks',
      openai_api_key = os.getenv 'OPENAI_API_KEY',
      groq_api_key = os.getenv 'GROQ_API_KEY',
      anthropic_api_key = os.getenv 'ANTHROPIC_API_KEY',
      default_provider = 'anthropic',
      default_model = 'claude-3-5-sonnet-latest',
      model_provider = {
        ['claude-3-5-sonnet-latest'] = 'anthropic',
        ['llama-3.1-70b-versatile'] = 'groq',
        ['gpt-4o'] = 'openai',
      },
      max_tokens = 4096,
    }

    set_keymap({ 'n', 'v' }, '<leader>ac', function()
      chat.stream_model_completion()
    end, '[A]I [C]ompletion')

    set_keymap('v', '<leader>ar', function()
      chat.stream_model_completion { replace = true }
    end, '[A]I [R]eplace')

    set_keymap('n', '<leader>an', function()
      chat.change_system_prompt 'new'
    end, '[A]I [N]ew system pompt')

    set_keymap('n', '<leader>ae', function()
      chat.change_system_prompt 'edit'
    end, '[A]I [E]dit system prompt')

    set_keymap('n', '<leader>as', function()
      chat.cancel()
    end, '[S]top AI completion')
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
- [x] Add Anthropic Claude support
- [x] Let users configure the max tokens
- [x] Add a function to cancel the current stream
- [ ] Make it easier to add new model provider APIs
- [ ] Change configuration to be less complex and more extensible
- [x] Prevent creating a new completion while another is in progress
- [ ] Cancel the stream if the buffer changes (or prevent changing buffers during stream)

