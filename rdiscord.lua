local rdiscord = {}
local listeners = {}
local callbacks = {}
local classes = {}
local JSONnull = print --// functions become null at the time of encoding, they can't be serialized.
local actualClient;
local socket, connected;

--// Services
local HTTPS = game:GetService("HttpService")
local TS = game:GetService("TestService")

local function socketSend(data)
    socket:Send(HTTPS:JSONEncode(data))
end

local function apiRequest(method, path, data)
    local struc = method == "GET" and {
        Method=method,
        Url="https://discord.com/api/v8" .. path,
        Headers={
            ["Authorization"] = "Bot " .. actualClient.token
        }
    } or {
        Method=method,
        Url="https://discord.com/api/v8" .. path,
        Body=HTTPS:JSONEncode(data),
        Headers={
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bot " .. actualClient.token
        }
    }
    local req = syn.request(struc)
    return HTTPS:JSONDecode(req.Body)
end

local function asyncTrace(f)
    local thread = coroutine.create(f)
	local s, e = coroutine.resume(thread)
	if not s then
		TS:Error(e .. "\n" .. debug.traceback(thread))
    end
end

rdiscord.Client = function(options)
    local client = {}
    client.user = nil

    --// Inner functions
    local function callClientEvent(event, ...)
        if not callbacks[event] then return end
        local args = {...}
        for i,cb in pairs(callbacks[event]) do
            asyncTrace(function()
                cb(unpack(args), "eventCall")
            end)
        end
    end

    local function opHandler(payload)
        if payload.op == 0 then --// Event Dispatch
            local listener = listeners[payload.t]
            if not listener then
                return print("No listener set for " .. payload.t)
            end

            local function client_cb(...)
                callClientEvent(listener.event, ...)
            end

            if listener.callback == true then return client_cb() end
            listener.callback(payload.d, client_cb)
        elseif payload.op == 7 then --// Reconnect
            error("Need reconnection")
        elseif payload.op == 9 then --// Invalid Session
            error("Invalid Session")
        elseif payload.op == 10 then --// Hi
            callClientEvent("connect")
            socketSend({
                op=2,
                d={
                    token=client.token,
                    intents=513,
                    properties={
                        ["$os"] = "win",
                        ["$browser"] = "roblox",
                        ["$device"] = "roblox"
                    },
                    compress=false,
                    shard={0,1}
                }
            })

            connected = true
            spawn(function() --// Keep connection alive
                while wait(35) and connected do
                    socketSend({
                        op=1,
                        d=payload.s or JSONnull
                    })
                end
            end)
        end
    end

    --// Methods
    function client:run(token)
        socket = syn.websocket.connect("ws://localhost:8765")
        self.token = token

        socket.OnMessage:Connect(function(message)
            local payload = HTTPS:JSONDecode(message)
            asyncTrace(function()
                opHandler(payload)
            end)
        end)

        socket.OnClose:Connect(function()
            connected = false
            warn("Connection closed")
        end)
    end

    function client:on(event, callback)
        local event_callbacks = callbacks[event]
        if not event_callbacks then
            callbacks[event] = {}
            event_callbacks = callbacks[event]
        end
        table.insert(event_callbacks, callback)
    end

    actualClient = client
    return client
end

local function addListener(discord_event, client_event, callback)
    listeners[discord_event] = {event=client_event, callback=callback}
end

local function createClass(classname, attrs, constructor)
    classes[classname] = setmetatable(attrs, {
        __call=constructor
    })
end

local function handleClass(classname, class, methods)
    local attrs, values = {}, {}
    for i,v in pairs(class) do
        table.insert(attrs, i .. "=%s")
        table.insert(values, tostring(v))
    end

    class.classname = classname
    local pattern = table.concat(attrs, ", ")
    return setmetatable(class, {
        __index=methods,
        __tostring=function(self)
            return string.format(class.classname .. "(" .. pattern .. ")", unpack(values))
        end
    })
end

local function cast(list, class)
    local items = {}
    for i,v in pairs(list) do
        table.insert(items, class(v))
    end
    return items
end

--// Classes
createClass("AuditLog", {}, function(self, data)
    return "nil"
end)

createClass("Embed", {
    subclasses = {
        Author = function(data)
            return handleClass("EmbedAuthor", {
                name=data.name,
                url=data.url,
                icon_url=data.icon_url
            }, {})
        end,
        Footer = function(data)
            return handleClass("EmbedFooter", {
                text=data.text,
                icon_url=data.icon_url
            }, {})
        end,
        Image = function(data)
            return handleClass("EmbedImage", {
                url=data.url,
                height=data.height,
                width=data.width
            }, {})
        end,
        Thumbnail = function(data)
            return handleClass("EmbedThumbnail", {
                url=data.url,
                height=data.height,
                width=data.width
            }, {})
        end,
        Video = function(data)
            return handleClass("EmbedVideo", {
                url=data.url,
                height=data.height,
                width=data.width
            }, {})
        end,
        Provider = function(data)
            return handleClass("EmbedImage", {
                name=data.name,
                url=data.url
            }, {})
        end,
        Fields = function(data)
            return handleClass("EmbedFields", {
                name=data.name,
                value=data.value,
                inline=data.inline
            }, {})
        end
    }
}, function(self, data)
    local embed = {
        title=data.title,
        type=data.type,
        description=data.description,
        url=data.url,
        timestamp=data.timestamp,
        color=data.color,
        footer=data.footer and self.subclasses.Footer(data.footer),
        image=data.image and self.subclasses.Image(data.image),
        thumbnail=data.thumbnail and self.subclasses.Thumbnail(data.thumbnail),
        video=data.video and self.subclasses.Video(data.video),
        provider=data.provider and self.subclasses.Author(data.author),
        fields=data.fields and self.subclasses.Fields(data.fields)
    }
    local methods = {}

    return handleClass("Embed", embed, methods)
end)

createClass("User", {}, function(self, data)
    if tonumber(data) then
        local user = apiRequest("GET", "/users/" .. data)
        print(HTTPS:JSONEncode(user))
        return classes.User(user)
    end

    local user = {
        id=data.id,
        username=data.username,
        discriminator=data.discriminator,
        bot=data.bot,
        system=data.system,
        verified=data.verified,
        premium_type=data.premium_type,
        public_flags=data.public_flags,
        flags=data.flags,
        email=data.email,
        locale=data.locale
    }
    local methods = {}

    return handleClass("User", user, methods)
end)

createClass("Guild", {}, function(data)
    return "nil"
end)

createClass("Channel", {
    type = {
        [0] = "TextChannel",
        [1] = "DMChannel",
        [2] = "VoiceChannel",
        [3] = "DMGroupChannel",
        [4] = "CategoryChannel",
        [5] = "NewsChannel",
        [6] = "StoreChannel"
    },
    subclasses = {
        TextChannel = function(data, channel, methods)
        end
    }
}, function(self, data)
    if tonumber(data) then
        local channel = apiRequest("GET", "/channels/" .. data)
        return classes.Channel(channel)
    end

    local channel = {
        id=data.id,
        type=data.type,
        guild=data.guild_id and classes.Guild(data.guild_id),
        position=data.position,
        permission_overwrites=data.permission_overwrites,
        name=data.name,
        topic=data.topic,
        nsfw=data.nsfw,
        bitrate=data.bitrate,
        user_limit=data.user_limit,
        rate_limit_per_user=data.rate_limit_per_user,
        recipients=data.recipients and cast(data.recipients, classes.User),
        icon=data.icon,
        owner=data.owner_id and classes.User(data.owner_id),
        application_id=data.application_id,
        last_pin_timestamp=data.last_pin_timestamp
    }
    local methods = {}

    --// Global methods
    function methods:send(msg, embed, tts)
        return classes.Message(apiRequest("POST", "/channels/" .. channel.id .. "/messages", {
            content=msg,
            tts=tts,
            embed=embed
        }))
    end

    local classname = self.type[data.type] or "Channel"
    if self.subclasses[classname] then self.subclasses[classname](data, channel, methods) end
    local class = handleClass(classname, channel, methods)
    
    if data.last_message_id then
        channel.last_message = classes.Message({
            r=true,
            channel=data.id,
            message=data.last_message_id
        }, class)
    end

    return class
end)

createClass("Message", {
    type = {
        [3] = "CallInfoMessage",
        [6] = "PinnedMessage",
        [7] = "MemberJoinMessage",
        [8] = "SubscriptionMessage",
        [9] = "SubscriptionMessage",
        [10] = "SubscriptionMessage",
        [19] = "ReferenceMessage",
        [20] = "ApplicationMessage"
    },
    subclasses = {
        ReferenceMessage = function(data, message, methods)
            if data.fail_if_not_exists == false then
                message.message = data.message_id and classes.Message(data.message_id)
                message.channel = data.channel_id and classes.Channel(data.channel_id)
                message.guild = data.guild_id and classes.Guild(data.guild_id)
            end
        end
    }
}, function(self, data, channel)
    if data.r then
        local message = apiRequest("GET", "/channels/" .. data.channel .. "/messages/" .. data.message)
        return classes.Message(message, channel)
    end

    local message = {
        id=data.guild_id,
        channel=channel or classes.Channel(data.channel_id),
        guild=data.guild_id and classes.Guild(data.guild_id),
        author=classes.User(data.author),
        member=data.member and classes.Member(data.member),
        content=data.content,
        timestamp=data.timestamp,
        edited_timestamp=data.edited_timestamp,
        tts=data.tts,
        mention_everyone=data.mention_everyone,
        mentions=data.mentions and cast(data.mentions, classes.User),
        mention_channels=data.mention_channels and cast(data.mention_channels, classes.Channel),
        attachments=cast(data.attachments, classes.Attachment), --// class needed
        embeds=cast(data.embeds, classes.Embed),
        reactions=data.reactions and cast(data.reactions, classes.Reaction), --// class needed
        pinned=data.pinned,
        webhook_id=data.webhook_id,
        type=data.type,
        activity=data.activity and classes.Activity(data.activity), --// class needed
        application=data.application and classes.Application(data.application), --// class needed
        message_reference=data.message_reference and data.message_reference, --// class needed
        flags=data.flags,
        stickers=data.stickers and data.stickers, --// class needed
        referenced_message=data.referenced_message and classes.Message(data.referenced_message)
    }
    local methods = {}

    local classname = self.type[data.type] or "Message"
    if self.subclasses[classname] then self.subclasses[classname](data, message, methods) end
    return handleClass(classname, message, methods)
end)

createClass("Mention", {}, function(self, data)
    local mention = {
        id=tonumber(data.id),
        member=classes.Member(data.member),
        username=data.username,
        discriminator=data.discriminator
    }
    local methods = {}

    return handleClass("Mention", mention, methods)
end)

createClass("Member", {}, function(self, data)
    local member = data
    local methods = {}

    return handleClass("Member", member, methods)
end)

--// Listeners
addListener("READY", "ready", true)
addListener("MESSAGE_CREATE", "message", function(data, callback)
    callback(classes.Message(data))
end)

return rdiscord
