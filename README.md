# chat.nvim
Create a new buffer in nvim and make requests to LLMs

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

    chat.setup {
      system_prompt = "There are instructions in the code comments. Only output code based on what you've seen. Mostly copy it, but attend to the instructions and modulate it according to what the instructions say. Only output valid code. If you must speak, make sure it must compile (Only keep it in the code comments).",
      openai_api_key = os.getenv 'OPENAI_API_KEY',
      groq_api_key = os.getenv 'GROQ_API_KEY',
    }

    vim.keymap.set('n', '<leader>acg', function()
      chat.completion('gpt-4o', 'openai')
    end, { desc = '[A]I [C]ompletion using [G]PT-4o', noremap = true, silent = true })

    vim.keymap.set('n', '<leader>acl', function()
      chat.completion('llama3-70b-8192', 'groq')
    end, { desc = '[A]I [C]ompletion using [L]lama 3 70B', noremap = true, silent = true })

    vim.keymap.set('v', '<leader>acg', function()
      chat.completion('gpt-4o', 'openai')
    end, { desc = '[A]I [C]ompletion using [G]PT-4o', noremap = true, silent = true })

    vim.keymap.set('v', '<leader>acl', function()
      chat.completion('llama3-70b-8192', 'groq')
    end, { desc = '[A]I [C]ompletion using [L]lama 3 70B', noremap = true, silent = true })

    vim.keymap.set('v', '<leader>arg', function()
      chat.selection_replace('gpt-4o', 'openai')
    end, { desc = '[A]I [R]eplacement using [G]PT-4o', noremap = true, silent = true })

    vim.keymap.set('v', '<leader>arl', function()
      chat.selection_replace('llama3-70b-8192', 'groq')
    end, { desc = '[A]I [R]eplacement using [L]lama 3 70B', noremap = true, silent = true })

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
- [ ] Save multiple system prompts and toggle between them
- [ ] Add google gemini support
- [ ] Add anthropic calude support

