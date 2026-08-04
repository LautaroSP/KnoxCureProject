require "TimedActions/ISBaseTimedAction"
require "KCP/Actions/KCPActionDefinitions"
require "KCP/Actions/KCPActionService"

KCPTimedAction = ISBaseTimedAction:derive("KCPTimedAction")
KCPTimedAction.active = KCPTimedAction.active or {}
KCPTimedAction.networkSounds = KCPTimedAction.networkSounds or {}

local function showResult(playerObj, ok, messageKey)
    if not playerObj or not messageKey then return end
    HaloTextHelper.addText(
        playerObj,
        getText(messageKey),
        "[br/]",
        ok and HaloTextHelper.getGoodColor() or HaloTextHelper.getBadColor()
    )
end

local function playAtStation(worldObject, soundName)
    if not worldObject or not soundName then return nil end
    local square = worldObject:getSquare()
    local emitter = getWorld():getFreeEmitter()
    emitter:setPos(square:getX() + 0.5, square:getY() + 0.5, square:getZ())
    local soundId = emitter:playSoundImpl(soundName, false, nil)
    return { emitter = emitter, id = soundId }
end

local function playAtCoordinates(x, y, z, soundName)
    if not soundName then return nil end
    local emitter = getWorld():getFreeEmitter()
    emitter:setPos(x + 0.5, y + 0.5, z)
    local soundId = emitter:playSoundImpl(soundName, false, nil)
    return { emitter = emitter, id = soundId }
end

local function stopSound(handle)
    if handle and handle.emitter and handle.id then
        handle.emitter:stopSound(handle.id)
    end
end

function KCPTimedAction:isValid()
    if not self.worldObject or not self.worldObject:getSquare() then return false end
    if self.character:getBodyDamage():getOverallBodyHealth() < self.startHealth then return false end
    local ok = KCPActionUtils.validate(self.character, self.worldObject, self.definition.id, self.token)
    return ok
end

function KCPTimedAction:waitToStart()
    self.character:faceThisObject(self.worldObject)
    return self.character:shouldBeTurning()
end

function KCPTimedAction:update()
    self.character:faceThisObject(self.worldObject)
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function KCPTimedAction:start()
    KCPTimedAction.active[self.token] = self
    if isClient() then
        sendClientCommand(self.character, "KCP", "beginAction", self.args)
    else
        local ok, messageKey = KCPActionService.begin(self.character, self.args)
        if not ok then
            showResult(self.character, false, messageKey)
            self:forceStop()
            return
        end
    end

    if not isClient() then
        self.startSoundHandle = playAtStation(self.worldObject, self.definition.startSound)
        self.soundHandle = playAtStation(self.worldObject, self.definition.sound)
    end
end

function KCPTimedAction:stop()
    stopSound(self.startSoundHandle)
    stopSound(self.soundHandle)
    KCPTimedAction.active[self.token] = nil
    if isClient() then
        sendClientCommand(self.character, "KCP", "cancelAction", self.args)
    else
        KCPActionService.cancel(self.character, self.args)
    end
    ISBaseTimedAction.stop(self)
end

function KCPTimedAction:perform()
    stopSound(self.startSoundHandle)
    stopSound(self.soundHandle)
    if not isClient() then
        playAtStation(self.worldObject, self.definition.finishSound)
    end
    KCPTimedAction.active[self.token] = nil

    if isClient() then
        sendClientCommand(self.character, "KCP", "completeAction", self.args)
    else
        local ok, messageKey = KCPActionService.execute(self.character, self.args)
        showResult(self.character, ok, messageKey)
    end
    ISBaseTimedAction.perform(self)
end

function KCPTimedAction:new(character, worldObject, definition, token)
    local o = ISBaseTimedAction.new(self, character)
    o.worldObject = worldObject
    o.definition = definition
    o.token = token
    o.args = KCPActionUtils.makeTargetArgs(worldObject, definition.id, token)
    o.startHealth = character:getBodyDamage():getOverallBodyHealth()
    o.maxTime = character:isTimedActionInstant() and 1 or definition.duration
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    return o
end

local function onServerCommand(module, command, args)
    if module ~= "KCP" or not args then return end
    local playerObj = getPlayer()
    if command == "stationSoundStart" then
        local existing = KCPTimedAction.networkSounds[args.token]
        if existing then
            stopSound(existing.startSound)
            stopSound(existing.sound)
        end
        KCPTimedAction.networkSounds[args.token] = {
            startSound = playAtCoordinates(args.x, args.y, args.z, args.startSound),
            sound = playAtCoordinates(args.x, args.y, args.z, args.sound),
        }
    elseif command == "stationSoundStop" then
        local handles = KCPTimedAction.networkSounds[args.token]
        if handles then
            stopSound(handles.startSound)
            stopSound(handles.sound)
            KCPTimedAction.networkSounds[args.token] = nil
        end
        playAtCoordinates(args.x, args.y, args.z, args.finishSound)
    elseif command == "beginResult" and not args.ok then
        local action = KCPTimedAction.active[args.token]
        if action then action:forceStop() end
        showResult(playerObj, false, args.messageKey)
    elseif command == "actionResult" then
        showResult(playerObj, args.ok == true, args.messageKey)
    end
end

Events.OnServerCommand.Add(onServerCommand)
