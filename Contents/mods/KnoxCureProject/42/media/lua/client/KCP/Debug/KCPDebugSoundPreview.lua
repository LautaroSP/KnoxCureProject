KCPDebugSoundPreview = KCPDebugSoundPreview or {}

KCPDebugSoundPreview.groups = {
    {
        labelKey = "IGUI_KCP_SoundGroup_Autopsy",
        sounds = {
            { name = "ButcheringSkinCorpse", event = "Character/Survival/Farming/Butchering/SkinCorpse", labelKey = "IGUI_KCP_Sound_SkinCorpse" },
            { name = "ButcheringGatherMeatSmall", event = "Character/Survival/Farming/Butchering/GatherMeatSmall", labelKey = "IGUI_KCP_Sound_GatherMeatSmall" },
            { name = "ButcheringGatherMeatLarge", event = "Character/Survival/Farming/Butchering/GatherMeatLarge", labelKey = "IGUI_KCP_Sound_GatherMeatLarge" },
            { name = "ButcheringBleedCorpse", event = "Character/Survival/Farming/Butchering/BleedCorpse", labelKey = "IGUI_KCP_Sound_BleedCorpse" },
            { name = "FirstAidRemoveFromWound", event = "Character/Survival/FirstAid/RemoveFromWound", labelKey = "IGUI_KCP_Sound_RemoveFromWound" },
            { name = "FirstAidApplyStitch", event = "Character/Survival/FirstAid/ApplyStitch", labelKey = "IGUI_KCP_Sound_ApplyStitch" },
            { name = "FirstAidCleanBurn", event = "Character/Survival/FirstAid/CleanBurn", labelKey = "IGUI_KCP_Sound_CleanBurn" },
            { name = "CleanBloodScrub", event = "Character/Foley/CleanBlood/Scrub", labelKey = "IGUI_KCP_Sound_CleanBloodScrub" },
            { name = "CleanBloodBleach", event = "Character/Foley/CleanBlood/Bleach", labelKey = "IGUI_KCP_Sound_CleanBloodBleach" },
        },
    },
    {
        labelKey = "IGUI_KCP_SoundGroup_Machines",
        sounds = {
            { name = "ClothingWasherRunning", event = "Object/ClothingWasher/Running", labelKey = "IGUI_KCP_Sound_WasherRunning" },
            { name = "ClothingWasherFinished", event = "Object/ClothingWasher/Finished", labelKey = "IGUI_KCP_Sound_WasherFinished" },
            { name = "ControlStationAmbiance", event = "World/Object/ControlStation", labelKey = "IGUI_KCP_Sound_ControlStation" },
            { name = "CarBatteryChargerRunning", event = "Object/CarBatteryCharger/Running", labelKey = "IGUI_KCP_Sound_BatteryCharger" },
            { name = "FactoryMachineAmbiance", event = "World/Object/FactoryMachine", labelKey = "IGUI_KCP_Sound_FactoryMachine" },
            { name = "MicrowaveRunning", event = "Object/Microwave/Running", labelKey = "IGUI_KCP_Sound_MicrowaveRunning" },
            { name = "MicrowaveTimerExpired", event = "Object/Microwave/Finished", labelKey = "IGUI_KCP_Sound_MicrowaveFinished" },
        },
    },
    {
        labelKey = "IGUI_KCP_SoundGroup_Support",
        sounds = {
            { name = "TransferLiquid", event = "Character/Survival/Liquid/TransferLiquid", labelKey = "IGUI_KCP_Sound_TransferLiquid" },
            { name = "Dismantle", event = "Character/Survival/Electrical/Dismantle", labelKey = "IGUI_KCP_Sound_Dismantle" },
            { name = "RepairWithWrench", event = "Character/Survival/Mechanics/RepairWithWrench", labelKey = "IGUI_KCP_Sound_Wrench" },
            { name = "Screwdriver", event = "Character/Survival/Carpentry/Screwing", labelKey = "IGUI_KCP_Sound_Screwdriver" },
            { name = "MapAddNote", event = "Character/Survival/Map/AddNote", labelKey = "IGUI_KCP_Sound_MapAddNote" },
            { name = "PageFlipBook", event = "Character/Survival/Literature/Book/PageFlip", labelKey = "IGUI_KCP_Sound_PageFlip" },
            { name = "RadioButton", event = "Object/Radio/Toggle", labelKey = "IGUI_KCP_Sound_RadioButton" },
            { name = "LightSwitch", event = "Object/Light/FlipSwitch", labelKey = "IGUI_KCP_Sound_LightSwitch" },
            { name = "FirstAidCleanRag", event = "Character/Survival/FirstAid/CleanRag", labelKey = "IGUI_KCP_Sound_CleanRag" },
        },
    },
    {
        labelKey = "IGUI_KCP_SoundGroup_CustomCandidates",
        sounds = {
            { name = "KCP_KeyboardTyping", custom = true, labelKey = "IGUI_KCP_Sound_CustomKeyboard" },
            { name = "KCP_SynthesizerRotor", custom = true, labelKey = "IGUI_KCP_Sound_CustomSynthRotor" },
        },
    },
}

local debugPlayer = nil
local activeCustomSound = nil
local eventPathCache = {}

local function getDebugPlayer()
    if not debugPlayer then
        debugPlayer = FMODDebugEventPlayer.new()
        debugPlayer:setFollowPlayer(true)
        debugPlayer:setVolume(1.0)
    end
    return debugPlayer
end

local function resolveEventPath(eventName)
    if eventPathCache[eventName] then
        return eventPathCache[eventName]
    end

    local paths = getFMODEventPathList()
    for i = 0, paths:size() - 1 do
        local path = paths:get(i)
        if path == eventName or path == "event:/" .. eventName or string.sub(path, -string.len(eventName)) == eventName then
            eventPathCache[eventName] = path
            return path
        end
    end
    return nil
end

local function stopForPlayer(playerObj)
    if debugPlayer then
        debugPlayer:stop()
    end
    if activeCustomSound and activeCustomSound.emitter and activeCustomSound.id then
        activeCustomSound.emitter:stopSound(activeCustomSound.id)
    end
    activeCustomSound = nil
end

function KCPDebugSoundPreview.stop(playerObj)
    stopForPlayer(playerObj)
    HaloTextHelper.addText(
        playerObj,
        getText("IGUI_KCP_SoundPreview_Stopped"),
        "[br/]",
        HaloTextHelper.getGoodColor()
    )
end

function KCPDebugSoundPreview.play(playerObj, sound)
    if not playerObj or not sound then
        return
    end

    stopForPlayer(playerObj)
    if sound.custom then
        local gameSound = getScriptManager():getGameSound(sound.name)
        if not gameSound then
            print("[Knox Cure] Custom GameSound is not registered: " .. sound.name)
            HaloTextHelper.addText(
                playerObj,
                getText("IGUI_KCP_SoundPreview_Failed") .. ": " .. sound.name,
                "[br/]",
                HaloTextHelper.getBadColor()
            )
            return
        end

        local ok, emitter, soundId = pcall(function()
            local worldEmitter = getWorld():getFreeEmitter()
            worldEmitter:setPos(playerObj:getX(), playerObj:getY(), playerObj:getZ())
            local id = worldEmitter:playSoundImpl(sound.name, false, nil)
            return worldEmitter, id
        end)
        if not ok then
            print("[Knox Cure] Custom sound preview failed for " .. sound.name .. ": " .. tostring(emitter))
            HaloTextHelper.addText(
                playerObj,
                getText("IGUI_KCP_SoundPreview_Failed") .. ": " .. sound.name,
                "[br/]",
                HaloTextHelper.getBadColor()
            )
            return
        end

        activeCustomSound = {
            emitter = emitter,
            id = soundId,
        }
        HaloTextHelper.addText(
            playerObj,
            getText("IGUI_KCP_SoundPreview_Playing") .. ": " .. sound.name,
            "[br/]",
            HaloTextHelper.getGoodColor()
        )
        print("[Knox Cure] Previewing custom sound: " .. sound.name .. " id=" .. tostring(soundId))
        return
    end

    local eventPath = resolveEventPath(sound.event)
    if not eventPath then
        print("[Knox Cure] FMOD event not found for " .. sound.name .. ": " .. sound.event)
        HaloTextHelper.addText(
            playerObj,
            getText("IGUI_KCP_SoundPreview_Failed") .. ": " .. sound.name,
            "[br/]",
            HaloTextHelper.getBadColor()
        )
        return
    end

    HaloTextHelper.addText(
        playerObj,
        getText("IGUI_KCP_SoundPreview_Playing") .. ": " .. sound.name,
        "[br/]",
        HaloTextHelper.getGoodColor()
    )

    local ok, errorMessage = pcall(function()
        getDebugPlayer():play(eventPath)
    end)
    if not ok then
        print("[Knox Cure] Sound preview failed for " .. sound.name .. ": " .. tostring(errorMessage))
        HaloTextHelper.addText(
            playerObj,
            getText("IGUI_KCP_SoundPreview_Failed") .. ": " .. sound.name,
            "[br/]",
            HaloTextHelper.getBadColor()
        )
        return
    end
    print("[Knox Cure] Previewing FMOD event: " .. eventPath)
end

local function updateDebugPlayer()
    if debugPlayer then
        debugPlayer:update()
    end
end

Events.OnTick.Add(updateDebugPlayer)

function KCPDebugSoundPreview.addMenu(parentMenu, playerObj)
    local previewOption = parentMenu:addOption(getText("IGUI_KCP_Context_SoundPreview"), playerObj, nil)
    local previewMenu = ISContextMenu:getNew(parentMenu)
    parentMenu:addSubMenu(previewOption, previewMenu)

    previewMenu:addOption(getText("IGUI_KCP_SoundPreview_Stop"), playerObj, KCPDebugSoundPreview.stop)

    for _, group in ipairs(KCPDebugSoundPreview.groups) do
        local groupOption = previewMenu:addOption(getText(group.labelKey), playerObj, nil)
        local groupMenu = ISContextMenu:getNew(previewMenu)
        previewMenu:addSubMenu(groupOption, groupMenu)

        for _, sound in ipairs(group.sounds) do
            local label = getText(sound.labelKey) .. " [" .. sound.name .. "]"
            groupMenu:addOption(label, playerObj, KCPDebugSoundPreview.play, sound)
        end
    end
end
