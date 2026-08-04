require "KCP/Actions/KCPActionService"

KCPActionServer = KCPActionServer or {}

local function reply(playerObj, command, args, ok, messageKey)
    sendServerCommand(playerObj, "KCP", command, {
        ok = ok,
        messageKey = messageKey,
        token = args and args.token,
        actionId = args and args.actionId,
    })
end

local function broadcastSound(command, args, finish)
    local action = args and KCPActionDefinitions.get(args.actionId)
    if not action then return end
    sendServerCommand("KCP", command, {
        token = args.token,
        x = args.x,
        y = args.y,
        z = args.z,
        startSound = command == "stationSoundStart" and action.startSound or nil,
        sound = command == "stationSoundStart" and action.sound or nil,
        finishSound = finish and action.finishSound or nil,
    })
end

function KCPActionServer.onClientCommand(module, command, playerObj, args)
    if module ~= "KCP" or not playerObj then return end
    if command == "beginAction" then
        local ok, messageKey = KCPActionService.begin(playerObj, args)
        if ok then broadcastSound("stationSoundStart", args, false) end
        reply(playerObj, "beginResult", args, ok, messageKey)
    elseif command == "cancelAction" then
        local ok, messageKey = KCPActionService.cancel(playerObj, args)
        if ok then broadcastSound("stationSoundStop", args, false) end
        reply(playerObj, "cancelResult", args, ok, messageKey)
    elseif command == "completeAction" then
        local ok, messageKey = KCPActionService.execute(playerObj, args)
        broadcastSound("stationSoundStop", args, ok)
        reply(playerObj, "actionResult", args, ok, messageKey)
    end
end

local function cleanupExpiredLocks()
    for _, args in ipairs(KCPActionService.cleanupExpiredLocks()) do
        broadcastSound("stationSoundStop", args, false)
    end
end

Events.OnClientCommand.Add(KCPActionServer.onClientCommand)
Events.EveryOneMinute.Add(cleanupExpiredLocks)
Events.OnTick.Add(KCPActionService.resolveCorpsePlacements)
