require "KCP/Stations/KCPStationRegistry"
require "KCP/Debug/KCPDebugSoundPreview"
require "KCP/Debug/KCPPhase3Debug"
require "KCP/Actions/KCPActionMenu"
require "Moveables/ISMoveableSpriteProps"

KCPStationContextMenu = KCPStationContextMenu or {}

local function inspectStation(worldObject, playerObj, station)
    if not playerObj or not station then
        return
    end

    local message = getText("IGUI_KCP_Station_Valid") .. ": " .. getText(station.labelKey)
    HaloTextHelper.addText(playerObj, message, "[br/]", HaloTextHelper.getGoodColor())
end

local STATE_START_INDEX = {
    ready = { centrifuge = 0, bioAnalyzer = 12, synthesizer = 24 },
    working = { centrifuge = 4, bioAnalyzer = 16, synthesizer = 32 },
    broken = { centrifuge = 8, bioAnalyzer = 20, synthesizer = 40 },
}

local BASE_START_INDEX = {
    centrifuge = 0,
    bioAnalyzer = 8,
    synthesizer = 16,
}

local function overlayNameForObject(worldObject, station, state)
    if state == "off" then
        return nil
    end

    local sprite = worldObject and worldObject:getSprite()
    local spriteName = sprite and sprite:getName()
    local baseIndex = spriteName and tonumber(string.match(spriteName, "_(%d+)$"))
    local stateStarts = STATE_START_INDEX[state]
    local stateStart = stateStarts and stateStarts[station.id]
    local baseStart = BASE_START_INDEX[station.id]
    if not baseIndex or not stateStart or not baseStart then
        return nil
    end
    return "kcp_lab_equipment_leds_01_" .. tostring(stateStart + baseIndex - baseStart)
end

local function setObjectStateOverlay(worldObject, station, state)
    local overlayName = overlayNameForObject(worldObject, station, state)
    worldObject:setOverlaySprite(overlayName, 1.0, 1.0, 1.0, 1.0)
end

local function previewStationState(worldObject, playerObj, station, state)
    local moveableProps = ISMoveableSpriteProps.new(worldObject:getSprite())
    if moveableProps.isMultiSprite then
        local grid = moveableProps:getSpriteGridInfo(worldObject:getSquare(), true)
        if grid then
            for _, member in ipairs(grid) do
                setObjectStateOverlay(member.object, station, state)
            end
        end
    else
        setObjectStateOverlay(worldObject, station, state)
    end

    local message = getText("IGUI_KCP_Preview_State") .. ": " .. getText("IGUI_KCP_State_" .. state)
    HaloTextHelper.addText(playerObj, message, "[br/]", HaloTextHelper.getGoodColor())
end

local function addStatePreviewMenu(parentMenu, entry, playerObj)
    local stateOption = parentMenu:addOption(getText("IGUI_KCP_Context_PreviewState"), entry.object, nil)
    local stateMenu = ISContextMenu:getNew(parentMenu)
    parentMenu:addSubMenu(stateOption, stateMenu)
    for _, state in ipairs({ "off", "ready", "working", "broken" }) do
        stateMenu:addOption(
            getText("IGUI_KCP_State_" .. state),
            entry.object,
            previewStationState,
            playerObj,
            entry.station,
            state
        )
    end
end

function KCPStationContextMenu.onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test and ISWorldObjectContextMenu.Test then
        return true
    end

    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then
        return
    end

    local found = {}
    local ordered = {}
    for _, worldObject in ipairs(worldObjects) do
        local station = KCPStationRegistry.getStation(worldObject)
        if station and not found[station.id] then
            found[station.id] = true
            table.insert(ordered, { object = worldObject, station = station })
        end
    end

    if #ordered == 0 then
        return
    end

    local rootOption = context:addOptionOnTop(getText("IGUI_KCP_Context_Root"), worldObjects, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(rootOption, subMenu)

    for _, entry in ipairs(ordered) do
        local optionText = getText("IGUI_KCP_Context_Inspect")
        if #ordered > 1 then
            optionText = optionText .. " - " .. getText(entry.station.labelKey)
        end
        subMenu:addOption(optionText, entry.object, inspectStation, playerObj, entry.station)
        KCPActionMenu.addActions(subMenu, playerObj, entry.object, entry.station)
        if getCore():getDebug() and not isClient() and BASE_START_INDEX[entry.station.id] then
            addStatePreviewMenu(subMenu, entry, playerObj)
        end
    end

    if getCore():getDebug() and not isClient() then
        KCPDebugSoundPreview.addMenu(subMenu, playerObj)
        KCPPhase3Debug.addMenu(subMenu, playerObj)
    end
end

Events.OnFillWorldObjectContextMenu.Add(KCPStationContextMenu.onFillWorldObjectContextMenu)
