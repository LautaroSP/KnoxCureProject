require "KCP/Actions/KCPActionDefinitions"
require "KCP/Stations/KCPStationRegistry"
require "Moveables/ISMoveableSpriteProps"

KCPActionUtils = KCPActionUtils or {}

local function requirement(ok, key, a, b)
    return { ok = ok == true, key = key, a = a, b = b }
end

function KCPActionUtils.getCanonicalObject(worldObject)
    if not worldObject or not worldObject:getSprite() then return worldObject end
    local props = ISMoveableSpriteProps.new(worldObject:getSprite())
    if not props.isMultiSprite then return worldObject end
    local grid = props:getSpriteGridInfo(worldObject:getSquare(), true)
    if not grid then return worldObject end
    for _, member in ipairs(grid) do
        if member.x == 0 and member.y == 0 and member.object then
            return member.object
        end
    end
    return worldObject
end

function KCPActionUtils.getStationObjects(worldObject)
    if not worldObject or not worldObject:getSprite() then return {} end
    local props = ISMoveableSpriteProps.new(worldObject:getSprite())
    if props.isMultiSprite then
        local grid = props:getSpriteGridInfo(worldObject:getSquare(), true)
        if grid then
            local result = {}
            for _, member in ipairs(grid) do
                if member.object then table.insert(result, member.object) end
            end
            if #result > 0 then return result end
        end
    end
    return { worldObject }
end

local function addRequirement(list, ok, key, a, b)
    table.insert(list, requirement(ok, key, a, b))
end

function KCPActionUtils.getTarget(args)
    if not args then return nil end
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square then return nil end
    local objects = square:getObjects()
    local index = tonumber(args.objectIndex)
    if not objects or not index or index < 0 or index >= objects:size() then
        return nil
    end
    return KCPActionUtils.getCanonicalObject(objects:get(index))
end

function KCPActionUtils.makeTargetArgs(worldObject, actionId, token)
    worldObject = KCPActionUtils.getCanonicalObject(worldObject)
    local square = worldObject and worldObject:getSquare()
    if not square then return nil end
    return {
        actionId = actionId,
        token = token,
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = square:getObjects():indexOf(worldObject),
    }
end

function KCPActionUtils.isPlayerNear(playerObj, worldObject)
    if not playerObj or not worldObject or not worldObject:getSquare() then return false end
    for _, member in ipairs(KCPActionUtils.getStationObjects(worldObject)) do
        local square = member:getSquare()
        if playerObj:getZ() == square:getZ()
            and math.abs(playerObj:getX() - (square:getX() + 0.5)) <= 2.5
            and math.abs(playerObj:getY() - (square:getY() + 0.5)) <= 2.5 then
            return true
        end
    end
    return false
end

function KCPActionUtils.getItem(playerObj, fullType)
    if not playerObj or not fullType then return nil end
    return playerObj:getInventory():getFirstTypeRecurse(fullType)
end

function KCPActionUtils.hasItem(playerObj, fullType)
    return KCPActionUtils.getItem(playerObj, fullType) ~= nil
end

function KCPActionUtils.getUsableItem(playerObj, fullType)
    local item = KCPActionUtils.getItem(playerObj, fullType)
    if not item then return nil end
    if item.isBroken and item:isBroken() then return nil end
    return item
end

function KCPActionUtils.getAnyItem(playerObj, fullTypes)
    for _, fullType in ipairs(fullTypes or {}) do
        local item = KCPActionUtils.getItem(playerObj, fullType)
        if item then return item end
    end
    return nil
end

function KCPActionUtils.isWearing(playerObj, fullType)
    if not playerObj then return false end
    local worn = playerObj:getWornItems()
    for i = 0, worn:size() - 1 do
        local entry = worn:get(i)
        local item = entry and entry:getItem()
        if item and item:getFullType() == fullType then
            return true
        end
    end
    return false
end

local function getPrimaryFluidName(item)
    if not item or not item.getFluidContainer then return nil, 0 end
    local container = item:getFluidContainer()
    if not container then return nil, 0 end
    local fluid = container:getPrimaryFluid()
    return fluid and fluid:getFluidTypeString() or nil, container:getAmount()
end

function KCPActionUtils.getCleaningAgent(playerObj)
    for _, fullType in ipairs({ "Base.Disinfectant", "Base.CleaningLiquid2" }) do
        local item = KCPActionUtils.getItem(playerObj, fullType)
        local fluidName, amount = getPrimaryFluidName(item)
        if item and amount >= KCPActionDefinitions.cleaningFluidAmount
            and (fluidName == "RubbingAlcohol" or fluidName == "CleaningLiquid") then
            return item
        end
    end
    return nil
end

function KCPActionUtils.getCleaningTool(playerObj)
    return KCPActionUtils.getAnyItem(playerObj, { "Base.RippedSheets", "Base.Sponge" })
end

function KCPActionUtils.getWritingTool(playerObj)
    for _, fullType in ipairs({ "Base.Pen", "Base.Pencil", "Base.BluePen", "Base.RedPen", "Base.GreenPen" }) do
        local item = KCPActionUtils.getUsableItem(playerObj, fullType)
        if item then return item end
    end
    return nil
end

function KCPActionUtils.getStationData(worldObject)
    local modData = worldObject:getModData()
    modData.KCPPhase3 = modData.KCPPhase3 or { schemaVersion = KCPActionDefinitions.schemaVersion }
    local data = modData.KCPPhase3
    if data.schemaVersion == nil then data.schemaVersion = KCPActionDefinitions.schemaVersion end
    return data
end

function KCPActionUtils.clearExpiredLock(data)
    if not data or not data.busyToken then return end
    local now = getGameTime():getWorldAgeHours()
    if not data.busyUntil or now >= data.busyUntil then
        data.busyToken = nil
        data.busyAction = nil
        data.busyPlayer = nil
        data.busyUntil = nil
    end
end

function KCPActionUtils.findZombieCorpse(worldObject, mode)
    if not worldObject then return nil end
    local visited = {}
    for _, member in ipairs(KCPActionUtils.getStationObjects(worldObject)) do
        local origin = member:getSquare()
        for dx = -1, 1 do
            for dy = -1, 1 do
                local key = tostring(origin:getX() + dx) .. ":" .. tostring(origin:getY() + dy)
                if not visited[key] then
                    visited[key] = true
                    local square = getCell():getGridSquare(origin:getX() + dx, origin:getY() + dy, origin:getZ())
                    local bodies = square and square:getDeadBodys()
                    if bodies then
                        for i = 0, bodies:size() - 1 do
                            local body = bodies:get(i)
                            if not body:isAnimal() and body:isZombie() then
                                local data = KCPActionUtils.getCorpseData(body)
                                if not mode
                                    or (mode == "unautopsied" and data.autopsied ~= true)
                                    or (mode == "sample" and data.autopsied == true and (data.samplesRemaining or 0) > 0) then
                                    return body
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

function KCPActionUtils.getCorpseData(corpse)
    if not corpse then return nil end
    local modData = corpse:getModData()
    modData.KCPPhase3 = modData.KCPPhase3 or { schemaVersion = KCPActionDefinitions.schemaVersion }
    return modData.KCPPhase3
end

local function hasWrittenResearchDrive(playerObj)
    local drive = KCPActionUtils.getItem(playerObj, "KCP.ResearchDrive")
    return drive and drive:getModData().KCPPhase3HasData == true
end

function KCPActionUtils.validate(playerObj, worldObject, actionId, token, options)
    options = options or {}
    worldObject = KCPActionUtils.getCanonicalObject(worldObject)
    local action = KCPActionDefinitions.get(actionId)
    local requirements = {}
    if not action or not playerObj or not worldObject then
        addRequirement(requirements, false, "IGUI_KCP_Requirement_InvalidTarget")
        return false, requirements
    end

    local station = KCPStationRegistry.getStation(worldObject)
    addRequirement(requirements, station and station.id == action.station, "IGUI_KCP_Requirement_CorrectStation")
    if not options.ignoreDistance then
        addRequirement(requirements, KCPActionUtils.isPlayerNear(playerObj, worldObject), "IGUI_KCP_Requirement_Adjacent")
    end

    local data = KCPActionUtils.getStationData(worldObject)
    KCPActionUtils.clearExpiredLock(data)
    addRequirement(requirements, not data.busyToken or data.busyToken == token, "IGUI_KCP_Requirement_StationAvailable")

    if action.requiredFirstAid then
        local current = playerObj:getPerkLevel(Perks.Doctor)
        addRequirement(requirements, current >= action.requiredFirstAid,
            "IGUI_KCP_Requirement_FirstAid", action.requiredFirstAid, current)
    end
    if action.requiredElectricity then
        local current = playerObj:getPerkLevel(Perks.Electricity)
        addRequirement(requirements, current >= action.requiredElectricity,
            "IGUI_KCP_Requirement_Electricity", action.requiredElectricity, current)
    end
    if action.requiresPower then
        addRequirement(requirements, worldObject:getSquare():haveElectricity(), "IGUI_KCP_Requirement_Power")
    end

    local corpse = nil
    local actionCorpse = nil
    local actionCorpseData = nil
    if action.station == "autopsy" then
        corpse = KCPActionUtils.findZombieCorpse(worldObject)
        if actionId == "autopsy" then
            actionCorpse = KCPActionUtils.findZombieCorpse(worldObject, "unautopsied")
        elseif actionId == "extractSample" then
            actionCorpse = KCPActionUtils.findZombieCorpse(worldObject, "sample")
        end
        actionCorpseData = KCPActionUtils.getCorpseData(actionCorpse)
    end

    if actionId == "cleanGurney" then
        addRequirement(requirements, data.clean ~= true, "IGUI_KCP_Requirement_GurneyDirty")
        addRequirement(requirements, corpse == nil, "IGUI_KCP_Requirement_GurneyEmpty")
        addRequirement(requirements, KCPActionUtils.getCleaningAgent(playerObj) ~= nil, "IGUI_KCP_Requirement_CleaningAgent")
        addRequirement(requirements, KCPActionUtils.getCleaningTool(playerObj) ~= nil, "IGUI_KCP_Requirement_CleaningTool")
    elseif actionId == "autopsy" then
        addRequirement(requirements, corpse ~= nil, "IGUI_KCP_Requirement_ZombieCorpse")
        addRequirement(requirements, data.clean == true, "IGUI_KCP_Requirement_GurneyClean")
        addRequirement(requirements, actionCorpseData and actionCorpseData.autopsied ~= true, "IGUI_KCP_Requirement_NotAutopsied")
        addRequirement(requirements, KCPActionUtils.getUsableItem(playerObj, "Base.Scalpel") ~= nil, "IGUI_KCP_Requirement_Scalpel")
        addRequirement(requirements, KCPActionUtils.isWearing(playerObj, "Base.Gloves_Surgical"), "IGUI_KCP_Requirement_SurgicalGloves")
        addRequirement(requirements, KCPActionUtils.isWearing(playerObj, "Base.Hat_SurgicalMask"), "IGUI_KCP_Requirement_SurgicalMask")
    elseif actionId == "extractSample" then
        addRequirement(requirements, corpse ~= nil, "IGUI_KCP_Requirement_ZombieCorpse")
        addRequirement(requirements, actionCorpseData and actionCorpseData.autopsied == true, "IGUI_KCP_Requirement_AutopsiedCorpse")
        addRequirement(requirements, actionCorpseData and (actionCorpseData.samplesRemaining or 0) > 0, "IGUI_KCP_Requirement_SamplesRemaining")
        addRequirement(requirements, KCPActionUtils.getUsableItem(playerObj, "Base.Scalpel") ~= nil, "IGUI_KCP_Requirement_Scalpel")
        addRequirement(requirements, KCPActionUtils.isWearing(playerObj, "Base.Gloves_Surgical"), "IGUI_KCP_Requirement_SurgicalGloves")
        addRequirement(requirements, KCPActionUtils.isWearing(playerObj, "Base.Hat_SurgicalMask"), "IGUI_KCP_Requirement_SurgicalMask")
        addRequirement(requirements, KCPActionUtils.hasItem(playerObj, "KCP.ProvisionalSampleContainer"), "IGUI_KCP_Requirement_SampleContainer")
    elseif actionId == "examineMicroscope" then
        addRequirement(requirements, KCPActionUtils.hasItem(playerObj, "KCP.RawTissueSample"), "IGUI_KCP_Requirement_RawSample")
    elseif actionId == "runCentrifuge" then
        addRequirement(requirements, KCPActionUtils.hasItem(playerObj, "KCP.ClassifiedTissueSample"), "IGUI_KCP_Requirement_ClassifiedSample")
        addRequirement(requirements, KCPActionUtils.hasItem(playerObj, "KCP.CentrifugeBalanceTube"), "IGUI_KCP_Requirement_BalanceTube")
    elseif actionId == "calibrateAnalyzer" then
        addRequirement(requirements, data.calibrated ~= true, "IGUI_KCP_Requirement_AnalyzerUncalibrated")
        addRequirement(requirements, KCPActionUtils.getUsableItem(playerObj, "Base.Screwdriver") ~= nil, "IGUI_KCP_Requirement_Screwdriver")
    elseif actionId == "analyzeViralFraction" then
        addRequirement(requirements, data.calibrated == true, "IGUI_KCP_Requirement_AnalyzerCalibrated")
        addRequirement(requirements, KCPActionUtils.hasItem(playerObj, "KCP.ViralFraction"), "IGUI_KCP_Requirement_ViralFraction")
    elseif actionId == "writeScientificRecord" then
        addRequirement(requirements, KCPActionUtils.hasItem(playerObj, "Base.Notebook"), "IGUI_KCP_Requirement_Notebook")
        addRequirement(requirements, KCPActionUtils.getWritingTool(playerObj) ~= nil, "IGUI_KCP_Requirement_WritingTool")
    elseif actionId == "exportData" then
        addRequirement(requirements, KCPActionUtils.hasItem(playerObj, "KCP.ResearchDrive"), "IGUI_KCP_Requirement_ResearchDrive")
    elseif actionId == "importData" then
        addRequirement(requirements, hasWrittenResearchDrive(playerObj), "IGUI_KCP_Requirement_WrittenResearchDrive")
    elseif actionId == "runSynthesizer" then
        addRequirement(requirements, KCPActionUtils.hasItem(playerObj, "KCP.StabilizedViralFraction"), "IGUI_KCP_Requirement_StabilizedFraction")
        addRequirement(requirements, KCPActionUtils.hasItem(playerObj, "KCP.SynthesisReagentKit"), "IGUI_KCP_Requirement_ReagentKit")
        addRequirement(requirements, KCPActionUtils.hasItem(playerObj, "KCP.EmptyInjector"), "IGUI_KCP_Requirement_EmptyInjector")
    end

    local ok = true
    for _, item in ipairs(requirements) do
        if not item.ok then ok = false break end
    end
    return ok, requirements
end

function KCPActionUtils.removeItem(playerObj, fullType)
    local item = KCPActionUtils.getItem(playerObj, fullType)
    if not item then return nil end
    local container = item:getContainer()
    playerObj:removeFromHands(item)
    if container then
        container:Remove(item)
        if isServer() then sendRemoveItemFromContainer(container, item) end
    else
        container = playerObj:getInventory()
        container:Remove(item)
        if isServer() then sendRemoveItemFromContainer(container, item) end
    end
    return item
end

function KCPActionUtils.addItem(playerObj, fullType)
    local inventory = playerObj:getInventory()
    local item = inventory:AddItem(fullType)
    if isServer() and item then sendAddItemToContainer(inventory, item) end
    return item
end

function KCPActionUtils.transmitModData(worldObject)
    if worldObject and worldObject.transmitModData then worldObject:transmitModData() end
end
