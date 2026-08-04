require "KCP/Actions/KCPActionDefinitions"
require "KCP/Actions/KCPActionUtils"
require "KCP/Stations/KCPStationVisuals"

KCPActionService = KCPActionService or {}
KCPActionService.activeStations = KCPActionService.activeStations or {}
KCPActionService.pendingCorpsePlacements = KCPActionService.pendingCorpsePlacements or {}

local function clearLock(worldObject, token)
    local data = KCPActionUtils.getStationData(worldObject)
    if not data.busyToken or not token or data.busyToken == token then
        data.busyToken = nil
        data.busyAction = nil
        data.busyPlayer = nil
        data.busyUntil = nil
        if token then KCPActionService.activeStations[token] = nil end
        KCPActionUtils.transmitModData(worldObject)
    end
end

local function setMachineState(worldObject, state)
    local station = KCPStationRegistry.getStation(worldObject)
    if station and (station.id == "centrifuge" or station.id == "bioAnalyzer" or station.id == "synthesizer") then
        KCPStationVisuals.setState(worldObject, station.id, state)
    end
end

local function syncItem(item)
    if not item then return end
    if item.syncItemFields then item:syncItemFields() end
    if isServer() then sendItemStats(item) end
end

local function degradeScalpel(playerObj)
    local scalpel = KCPActionUtils.getUsableItem(playerObj, "Base.Scalpel")
    if not scalpel then return end
    scalpel:setCondition(math.max(0, scalpel:getCondition() - 1))
    syncItem(scalpel)
end

local function consumeCleaningSupplies(playerObj)
    local agent = KCPActionUtils.getCleaningAgent(playerObj)
    local tool = KCPActionUtils.getCleaningTool(playerObj)
    local fluid = agent and agent:getFluidContainer()
    if fluid then
        fluid:adjustAmount(math.max(0, fluid:getAmount() - KCPActionDefinitions.cleaningFluidAmount))
        syncItem(agent)
    end
    if tool and tool:getFullType() == "Base.RippedSheets" then
        KCPActionUtils.removeItem(playerObj, "Base.RippedSheets")
        KCPActionUtils.addItem(playerObj, "Base.RippedSheetsDirty")
    end
end

local function transformItem(playerObj, inputType, outputType)
    if not KCPActionUtils.removeItem(playerObj, inputType) then return false end
    KCPActionUtils.addItem(playerObj, outputType)
    return true
end

function KCPActionService.begin(playerObj, args)
    local worldObject = KCPActionUtils.getTarget(args)
    local action = args and KCPActionDefinitions.get(args.actionId)
    if not worldObject or not action or not args.token then
        return false, "IGUI_KCP_Result_InvalidRequest"
    end

    local ok = KCPActionUtils.validate(playerObj, worldObject, action.id, args.token)
    if not ok then return false, "IGUI_KCP_Result_RequirementsChanged" end

    local data = KCPActionUtils.getStationData(worldObject)
    data.busyToken = args.token
    data.busyAction = action.id
    data.busyPlayer = playerObj:getOnlineID()
    data.busyUntil = getGameTime():getWorldAgeHours() + KCPActionDefinitions.lockTimeoutHours
    KCPActionService.activeStations[args.token] = worldObject
    KCPActionUtils.transmitModData(worldObject)
    setMachineState(worldObject, "working")
    return true, "IGUI_KCP_Result_ActionStarted"
end

function KCPActionService.cleanupExpiredLocks()
    local now = getGameTime():getWorldAgeHours()
    local expired = {}
    for token, worldObject in pairs(KCPActionService.activeStations) do
        local data = worldObject and KCPActionUtils.getStationData(worldObject)
        if not data or data.busyToken ~= token or not data.busyUntil or now >= data.busyUntil then
            if data and data.busyToken == token then
                local square = worldObject:getSquare()
                table.insert(expired, {
                    token = token,
                    actionId = data.busyAction,
                    x = square:getX(), y = square:getY(), z = square:getZ(),
                })
                clearLock(worldObject, token)
                setMachineState(worldObject, "ready")
            else
                KCPActionService.activeStations[token] = nil
            end
        end
    end
    return expired
end

function KCPActionService.cancel(playerObj, args)
    local worldObject = KCPActionUtils.getTarget(args)
    if not worldObject then return false, "IGUI_KCP_Result_InvalidRequest" end
    local data = KCPActionUtils.getStationData(worldObject)
    if data.busyToken == args.token and data.busyPlayer == playerObj:getOnlineID() then
        clearLock(worldObject, args.token)
        setMachineState(worldObject, "ready")
        return true, "IGUI_KCP_Result_ActionCancelled"
    end
    return false, "IGUI_KCP_Result_LockMismatch"
end

local EXECUTORS = {}

EXECUTORS.placeCorpseOnGurney = function(playerObj, worldObject)
    local x, y, z = KCPActionUtils.getGurneyPlacement(worldObject)
    local data = KCPActionUtils.getStationData(worldObject)
    local key = KCPActionUtils.getGurneyKey(worldObject)
    local draggedCorpse = playerObj:getGrapplingTarget()
    if draggedCorpse then
        local draggedData = KCPActionUtils.getCorpseData(draggedCorpse)
        draggedData.gurneyKey = nil
        draggedData.pendingGurneyKey = key
    end
    data.corpsePlacementPending = true
    data.corpsePlacementPlayer = KCPActionUtils.getCorpseCarrierId(playerObj)
    data.corpsePlacementStarted = getGameTime():getWorldAgeHours()
    KCPActionService.pendingCorpsePlacements[key] = worldObject

    -- Build 42 keeps human corpses in the grappling system rather than inventory.
    -- Releasing at the station position preserves the original corpse instance.
    playerObj:setTargetGrapplePos(x, y, z)
    playerObj:setDoGrappleLetGo()
end

EXECUTORS.removeCorpseFromGurney = function(playerObj, worldObject)
    local corpse = KCPActionUtils.getLinkedCorpse(worldObject)
    local corpseData = KCPActionUtils.getCorpseData(corpse)
    corpseData.gurneyKey = nil
    if corpse.transmitModData then corpse:transmitModData() end
    local data = KCPActionUtils.getStationData(worldObject)
    data.corpseLinked = nil
    data.corpsePlacementPending = nil
    playerObj:pickUpCorpse(corpse, "BwdDrag")
end

EXECUTORS.cleanGurney = function(playerObj, worldObject)
    consumeCleaningSupplies(playerObj)
    local data = KCPActionUtils.getStationData(worldObject)
    data.clean = true
end

EXECUTORS.autopsy = function(playerObj, worldObject)
    local corpse = KCPActionUtils.getLinkedCorpse(worldObject)
    local corpseData = KCPActionUtils.getCorpseData(corpse)
    corpseData.autopsied = true
    corpseData.samplesRemaining = 1
    corpseData.schemaVersion = KCPActionDefinitions.schemaVersion
    if corpse.transmitModData then corpse:transmitModData() end
    KCPActionUtils.getStationData(worldObject).clean = false
    degradeScalpel(playerObj)
end

EXECUTORS.extractSample = function(playerObj, worldObject)
    local corpse = KCPActionUtils.getLinkedCorpse(worldObject)
    local corpseData = KCPActionUtils.getCorpseData(corpse)
    KCPActionUtils.removeItem(playerObj, "KCP.ProvisionalSampleContainer")
    KCPActionUtils.addItem(playerObj, "KCP.RawTissueSample")
    corpseData.samplesRemaining = math.max(0, (corpseData.samplesRemaining or 0) - 1)
    if corpse.transmitModData then corpse:transmitModData() end
end

local function findPlacedCorpse(worldObject, playerId)
    local best, bestDistance = nil, nil
    local targetX, targetY, targetZ = KCPActionUtils.getGurneyPlacement(worldObject)
    if not targetX then return nil end
    for dx = -3, 3 do
        for dy = -3, 3 do
            local square = getCell():getGridSquare(math.floor(targetX) + dx, math.floor(targetY) + dy, targetZ)
            local bodies = square and square:getDeadBodys()
            if bodies then
                for i = 0, bodies:size() - 1 do
                    local corpse = bodies:get(i)
                    local grabbedBy = corpse:getModData()["lastPlayerGrabbed"]
                    local corpseData = KCPActionUtils.getCorpseData(corpse)
                    local matchesPlacement = corpseData.pendingGurneyKey == KCPActionUtils.getGurneyKey(worldObject)
                        or tonumber(grabbedBy) == tonumber(playerId)
                    if not corpse:isAnimal() and corpse:isZombie() and corpseData.gurneyKey == nil
                        and matchesPlacement then
                        local distance = (corpse:getX() - targetX) ^ 2 + (corpse:getY() - targetY) ^ 2
                        if not bestDistance or distance < bestDistance then
                            best, bestDistance = corpse, distance
                        end
                    end
                end
            end
        end
    end
    return best
end

function KCPActionService.resolveCorpsePlacements()
    local now = getGameTime():getWorldAgeHours()
    for key, worldObject in pairs(KCPActionService.pendingCorpsePlacements) do
        local data = worldObject and KCPActionUtils.getStationData(worldObject)
        local corpse = data and findPlacedCorpse(worldObject, data.corpsePlacementPlayer)
        if corpse then
            local x, y, z = KCPActionUtils.getGurneyPlacement(worldObject)
            corpse:setPosition(x, y, z)
            corpse:setCurrentSquareFromPosition()
            local corpseData = KCPActionUtils.getCorpseData(corpse)
            corpseData.gurneyKey = key
            corpseData.pendingGurneyKey = nil
            corpseData.schemaVersion = KCPActionDefinitions.schemaVersion
            if corpse.transmitModData then corpse:transmitModData() end
            data.corpseLinked = true
            data.corpsePlacementPending = nil
            data.corpsePlacementPlayer = nil
            data.corpsePlacementStarted = nil
            KCPActionUtils.transmitModData(worldObject)
            KCPActionService.pendingCorpsePlacements[key] = nil
        elseif not data or now - (data.corpsePlacementStarted or now) > 0.01 then
            if data then
                data.corpsePlacementPending = nil
                data.corpsePlacementPlayer = nil
                data.corpsePlacementStarted = nil
                KCPActionUtils.transmitModData(worldObject)
            end
            KCPActionService.pendingCorpsePlacements[key] = nil
        end
    end
end

EXECUTORS.examineMicroscope = function(playerObj)
    transformItem(playerObj, "KCP.RawTissueSample", "KCP.ClassifiedTissueSample")
end

EXECUTORS.runCentrifuge = function(playerObj)
    KCPActionUtils.removeItem(playerObj, "KCP.ClassifiedTissueSample")
    KCPActionUtils.removeItem(playerObj, "KCP.CentrifugeBalanceTube")
    KCPActionUtils.addItem(playerObj, "KCP.ViralFraction")
end

EXECUTORS.calibrateAnalyzer = function(_, worldObject)
    local data = KCPActionUtils.getStationData(worldObject)
    data.calibrated = true
    data.calibrationSchemaVersion = KCPActionDefinitions.schemaVersion
end

EXECUTORS.analyzeViralFraction = function(playerObj, worldObject)
    transformItem(playerObj, "KCP.ViralFraction", "KCP.StabilizedViralFraction")
    local data = KCPActionUtils.getStationData(worldObject)
    data.experimentalAnalyses = (data.experimentalAnalyses or 0) + 1
end

EXECUTORS.writeScientificRecord = function(playerObj)
    KCPActionUtils.removeItem(playerObj, "Base.Notebook")
    local record = KCPActionUtils.addItem(playerObj, "KCP.ScientificRecord")
    record:getModData().KCPPhase3Record = true
    record:getModData().schemaVersion = KCPActionDefinitions.schemaVersion
    syncItem(record)
end

EXECUTORS.exportData = function(playerObj, worldObject)
    local drive = KCPActionUtils.getItem(playerObj, "KCP.ResearchDrive")
    local modData = drive:getModData()
    modData.KCPPhase3HasData = true
    modData.schemaVersion = KCPActionDefinitions.schemaVersion
    modData.experimentalAnalyses = KCPActionUtils.getStationData(worldObject).experimentalAnalyses or 0
    syncItem(drive)
end

EXECUTORS.importData = function(playerObj, worldObject)
    local drive = KCPActionUtils.getItem(playerObj, "KCP.ResearchDrive")
    local driveData = drive:getModData()
    local stationData = KCPActionUtils.getStationData(worldObject)
    stationData.phase3Imported = true
    stationData.experimentalAnalyses = math.max(
        stationData.experimentalAnalyses or 0,
        driveData.experimentalAnalyses or 0
    )
end

EXECUTORS.runSynthesizer = function(playerObj)
    KCPActionUtils.removeItem(playerObj, "KCP.StabilizedViralFraction")
    KCPActionUtils.removeItem(playerObj, "KCP.SynthesisReagentKit")
    KCPActionUtils.removeItem(playerObj, "KCP.EmptyInjector")
    KCPActionUtils.addItem(playerObj, "KCP.ExperimentalSynthesisBatch")
end

function KCPActionService.execute(playerObj, args)
    local worldObject = KCPActionUtils.getTarget(args)
    local action = args and KCPActionDefinitions.get(args.actionId)
    if not worldObject or not action or not args.token then
        return false, "IGUI_KCP_Result_InvalidRequest"
    end

    local data = KCPActionUtils.getStationData(worldObject)
    if data.busyToken ~= args.token or data.busyPlayer ~= playerObj:getOnlineID() then
        return false, "IGUI_KCP_Result_LockMismatch"
    end

    local ok = KCPActionUtils.validate(playerObj, worldObject, action.id, args.token)
    if not ok then
        clearLock(worldObject, args.token)
        setMachineState(worldObject, "ready")
        return false, "IGUI_KCP_Result_RequirementsChanged"
    end

    local executor = EXECUTORS[action.id]
    if not executor then
        clearLock(worldObject, args.token)
        return false, "IGUI_KCP_Result_InvalidRequest"
    end

    executor(playerObj, worldObject)
    clearLock(worldObject, args.token)
    KCPActionUtils.transmitModData(worldObject)
    setMachineState(worldObject, "ready")
    return true, "IGUI_KCP_Result_ActionCompleted"
end
