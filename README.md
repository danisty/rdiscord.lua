# rdiscord.lua 0.2
Discord API Wrapper for Roblox Lua (Synapse X)

Currently being worked on. <br>
For now you can only receive and send messages.

### Important
Since most exploits don't support wss websockets, you will need to use a helper python script in order to make it work. **This version only supports Synapse X as for now**. Support for other/custom exploits will be added soon. Steps to follow:
1. Download and install [Python](https://www.python.org/downloads/) if you haven't already.
2. Install the package `websockets` through `pip` > `pip install websockets` via cmd or powershell.
3. Clone [helper.py](https://raw.githubusercontent.com/danisty/rdiscord.lua/main/helper.py) to your Desktop or any other location.
4. Run the helper script via cmd or powershell `py helper.py`. Now you are free to load the lua library and experiment with it!

### Working Example
```lua
local rdiscord = loadstring(game:HttpGet("https://raw.githubusercontent.com/danisty/rdiscord.lua/main/rdiscord.lua", true))()
local client = rdiscord.Client()

client:on("connect", function()
    warn("Connected")
end)

client:on("ready", function()
    warn("Bot Ready!")
end)

client:on("message", function(msg)
    print(string.format("%s said %s", msg.author.username .. "#" .. msg.author.discriminator, msg.content))
    if msg.content:match("!ping") and not msg.author.bot then
        msg.channel:send("pong!")
    end
end)

client:run("your_bot_token_here")
```
