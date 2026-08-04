require "KCP/Actions/KCPActionDefinitions"
require "KCP/Actions/KCPActionUtils"
require "KCP/Stations/KCPStationVisuals"

KCPActionService = KCPActionService or {}
KCPActionService.activeStations = KCPActionService.activeStations or {}
KCPActionService.activeInventoryActions = KCPActionService.activeInventoryActions or {}

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
    local action = args and KCPActionDefinitions.get(args.actionId)
    if not action or not args.token then
        return false, "IGUI_KCP_Result_InvalidRequest"
    end

    if action.inventoryAction then
        local ok = KCPActionUtils.validate(playerObj, nil, action.id, args.token, {
            notebookId = args.notebookId,
        })
        if not ok then return false, "IGUI_KCP_Result_RequirementsChanged" end
        KCPActionService.activeInventoryActions[args.token] = {
            actionId = action.id,
            playerId = playerObj:getOnlineID(),
            busyUntil = getGameTime():getWorldAgeHours() + KCPActionDefinitions.lockTimeoutHours,
            x = args.x, y = args.y, z = args.z,
        }
        return true, "IGUI_KCP_Result_ActionStarted"
    end

    local worldObject = KCPActionUtils.getTarget(args)
    if not worldObject then return false, "IGUI_KCP_Result_InvalidRequest" end

    local ok = KCPActionUtils.validate(playerObj, worldObject, action.id, args.token, {
        corpseId = args.corpseId,
    })
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
    for token, actionData in pairs(KCPActionService.activeInventoryActions) do
        if not actionData.busyUntil or now >= actionData.busyUntil then
            table.insert(expired, {
                token = token,
                actionId = actionData.actionId,
                x = actionData.x, y = actionData.y, z = actionData.z,
            })
            KCPActionService.activeInventoryActions[token] = nil
        end
    end
    return expired
end

function KCPActionService.cancel(playerObj, args)
    local action = args and KCPActionDefinitions.get(args.actionId)
    if action and action.inventoryAction then
        local active = KCPActionService.activeInventoryActions[args.token]
        if active and active.playerId == playerObj:getOnlineID() then
            KCPActionService.activeInventoryActions[args.token] = nil
            return true, "IGUI_KCP_Result_ActionCancelled"
        end
        return false, "IGUI_KCP_Result_LockMismatch"
    end
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

EXECUTORS.placeCorpseOnGurney = function(_, worldObject, args)
    local x, y, z = KCPActionUtils.getGurneyPlacement(worldObject)
    local corpse = KCPActionUtils.getCorpseByObjectId(worldObject, args.corpseId)
    local data = KCPActionUtils.getStationData(worldObject)
    local key = KCPActionUtils.getGurneyKey(worldObject)
    local oldSquare = corpse:getSquare()
    local targetSquare = getCell():getGridSquare(math.floor(x), math.floor(y), z)
    oldSquare:removeCorpse(corpse, false)
    corpse:setPosition(x, y, z)
    targetSquare:addCorpse(corpse, false)
    corpse:setRenderYOffset(0)
    corpse:setZ(KCPActionUtils.getGurneyWorldZ(worldObject))
    local corpseData = KCPActionUtils.getCorpseData(corpse)
    corpseData.gurneyKey = key
    corpseData.schemaVersion = KCPActionDefinitions.schemaVersion
    if corpse.transmitModData then corpse:transmitModData() end
    data.corpseLinked = true
end

EXECUTORS.removeCorpseFromGurney = function(playerObj, worldObject)
    local corpse = KCPActionUtils.getLinkedCorpse(worldObject)
    local corpseData = KCPActionUtils.getCorpseData(corpse)
    corpseData.gurneyKey = nil
    if corpse.transmitModData then corpse:transmitModData() end
    local data = KCPActionUtils.getStationData(worldObject)
    data.corpseLinked = nil
    corpse:setRenderYOffset(0)
    local oldSquare = corpse:getSquare()
    local playerSquare = playerObj:getSquare()
    if oldSquare and playerSquare then
        oldSquare:removeCorpse(corpse, false)
        corpse:setPosition(playerObj:getX(), playerObj:getY(), playerObj:getZ())
        playerSquare:addCorpse(corpse, false)
        corpse:setZ(playerObj:getZ())
    end
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

EXECUTORS.writeScientificRecord = function(playerObj, _, args)
    local notebook = KCPActionUtils.getNotebookById(playerObj, args.notebookId)
    KCPActionUtils.removeSpecificItem(playerObj, notebook)
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
    local action = args and KCPActionDefinitions.get(args.actionId)
    if not action or not args.token then
        return false, "IGUI_KCP_Result_InvalidRequest"
    end


    if action.inventoryAction then
        local active = KCPActionService.activeInventoryActions[args.token]
        if not active or active.playerId ~= playerObj:getOnlineID() or active.actionId ~= action.id then
            return false, "IGUI_KCP_Result_LockMismatch"
        end
        local ok = KCPActionUtils.validate(playerObj, nil, action.id, args.token, {
            notebookId = args.notebookId,
        })
        KCPActionService.activeInventoryActions[args.token] = nil
        if not ok then return false, "IGUI_KCP_Result_RequirementsChanged" end
        local executor = EXECUTORS[action.id]
        if not executor then return false, "IGUI_KCP_Result_InvalidRequest" end
        executor(playerObj, nil, args)
        return true, "IGUI_KCP_Result_ActionCompleted"
    end

    local worldObject = KCPActionUtils.getTarget(args)
    if not worldObject then return false, "IGUI_KCP_Result_InvalidRequest" end

    local data = KCPActionUtils.getStationData(worldObject)
    if data.busyToken ~= args.token or data.busyPlayer ~= playerObj:getOnlineID() then
        return false, "IGUI_KCP_Result_LockMismatch"
    end

    local ok = KCPActionUtils.validate(playerObj, worldObject, action.id, args.token, {
        corpseId = args.corpseId,
    })
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

    executor(playerObj, worldObject, args)
    clearLock(worldObject, args.token)
    KCPActionUtils.transmitModData(worldObject)
    setMachineState(worldObject, "ready")
    return true, "IGUI_KCP_Result_ActionCompleted"
end
