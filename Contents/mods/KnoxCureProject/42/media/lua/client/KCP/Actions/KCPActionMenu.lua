require "KCP/Actions/KCPActionDefinitions"
require "KCP/Actions/KCPActionUtils"
require "KCP/Actions/KCPTimedAction"
require "TimedActions/ISTimedActionQueue"
require "luautils"

KCPActionMenu = KCPActionMenu or {}

local function translateRequirement(item)
    if item.a ~= nil and item.b ~= nil then
        return getText(item.key, tostring(item.a), tostring(item.b))
    elseif item.a ~= nil then
        return getText(item.key, tostring(item.a))
    end
    return getText(item.key)
end

local function setRequirementTooltip(option, requirements)
    local lines = { getText("IGUI_KCP_Requirements_Header") }
    for _, item in ipairs(requirements) do
        local color = item.ok and "<RGB:0.3,1,0.3> " or "<RGB:1,0.2,0.2> "
        local marker = item.ok and "[+] " or "[-] "
        table.insert(lines, color .. marker .. translateRequirement(item))
    end
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip.description = table.concat(lines, " <LINE> ")
    option.toolTip = tooltip
end

local function createToken(playerObj, actionId)
    return tostring(playerObj:getOnlineID()) .. ":" .. actionId .. ":"
        .. tostring(getGameTime():getWorldAgeHours()) .. ":" .. tostring(ZombRand(1000000000))
end

function KCPActionMenu.start(playerObj, worldObject, actionId, extraArgs)
    local definition = KCPActionDefinitions.get(actionId)
    if not playerObj or not worldObject or not definition then return end
    local validationOptions = { ignoreDistance = true }
    for key, value in pairs(extraArgs or {}) do validationOptions[key] = value end
    local ok = KCPActionUtils.validate(playerObj, worldObject, actionId, nil, validationOptions)
    if not ok then return end
    if not luautils.walkAdj(playerObj, worldObject:getSquare(), false) then
        HaloTextHelper.addText(playerObj, getText("IGUI_KCP_Result_NoPath"), "[br/]", HaloTextHelper.getBadColor())
        return
    end
    local token = createToken(playerObj, actionId)
    ISTimedActionQueue.add(KCPTimedAction:new(playerObj, worldObject, definition, token, extraArgs))
end

function KCPActionMenu.addCorpsePlacement(parentMenu, playerObj, worldObject, corpse)
    local corpseId = tostring(corpse:getObjectIDAsLong())
    local options = { ignoreDistance = true, corpseId = corpseId }
    local ok, requirements = KCPActionUtils.validate(
        playerObj, worldObject, "placeCorpseOnGurney", nil, options
    )
    local option = parentMenu:addOption(
        getText("IGUI_KCP_Action_PlaceCorpseOnGurney"),
        playerObj,
        KCPActionMenu.start,
        worldObject,
        "placeCorpseOnGurney",
        { corpseId = corpseId }
    )
    setRequirementTooltip(option, requirements)
    if not ok then option.notAvailable = true end
end

function KCPActionMenu.addActions(parentMenu, playerObj, worldObject, station)
    for _, definition in ipairs(KCPActionDefinitions.getForStation(station.id)) do
        local ok, requirements = KCPActionUtils.validate(
            playerObj,
            worldObject,
            definition.id,
            nil,
            { ignoreDistance = true }
        )
        local option = parentMenu:addOption(
            getText(definition.labelKey),
            playerObj,
            KCPActionMenu.start,
            worldObject,
            definition.id
        )
        setRequirementTooltip(option, requirements)
        if not ok then option.notAvailable = true end
    end
end

local function getSelectedNotebook(items)
    for _, entry in ipairs(items or {}) do
        if instanceof(entry, "InventoryItem") then
            if entry:getFullType() == "Base.Notebook" then return entry end
        elseif entry.items then
            for _, item in ipairs(entry.items) do
                if item:getFullType() == "Base.Notebook" then return item end
            end
        end
    end
    return nil
end

function KCPActionMenu.startScientificRecord(playerObj, notebook)
    local definition = KCPActionDefinitions.get("writeScientificRecord")
    if not playerObj or not notebook or not definition then return end
    local extraArgs = { notebookId = tostring(notebook:getID()) }
    local ok = KCPActionUtils.validate(playerObj, nil, definition.id, nil, extraArgs)
    if not ok then return end
    local token = createToken(playerObj, definition.id)
    ISTimedActionQueue.add(KCPTimedAction:new(playerObj, nil, definition, token, extraArgs))
end

function KCPActionMenu.onFillInventoryObjectContextMenu(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    local notebook = getSelectedNotebook(items)
    if not playerObj or not notebook then return end

    local options = { notebookId = tostring(notebook:getID()) }
    local ok, requirements = KCPActionUtils.validate(
        playerObj, nil, "writeScientificRecord", nil, options
    )
    local option = context:addOption(
        getText("IGUI_KCP_Action_WriteScientificRecord"),
        playerObj,
        KCPActionMenu.startScientificRecord,
        notebook
    )
    setRequirementTooltip(option, requirements)
    if not ok then option.notAvailable = true end
end

Events.OnFillInventoryObjectContextMenu.Add(KCPActionMenu.onFillInventoryObjectContextMenu)
