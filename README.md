# chat.nvim
Create a new buffer in nvim and make requests to LLMs

Inspo:
- https://x.com/yacineMTB/status/1788398761892274271
- https://x.com/yacineMTB/status/1789699312902922474

Try using: https://github.com/leafo/lua-openai

# Notes

In Lua, thread calls, such as HTTP requests, are blocking operations, the whole program blocks until the operation completes.

To allow streaming of the output from the API, you will need to circumvent this.

Maybe libev could be used?

See: https://www.lua.org/pil/9.4.html

The OpenAI API streams the response to you using "server-sent events". - Need to check this

See: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events

# TODO
- [ ] stream the output from the API
- [ ] play around with the system prompt to optimise it for coding
- [ ] swap between groq and openai
