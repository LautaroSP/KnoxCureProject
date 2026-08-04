KCPActionDefinitions = KCPActionDefinitions or {}

KCPActionDefinitions.schemaVersion = 1
KCPActionDefinitions.cleaningFluidAmount = 0.10
KCPActionDefinitions.lockTimeoutHours = 1.0

local ACTIONS = {
    placeCorpseOnGurney = {
        id = "placeCorpseOnGurney",
        station = "autopsy",
        labelKey = "IGUI_KCP_Action_PlaceCorpseOnGurney",
        duration = 10,
        allowedWhileDraggingCorpses = true,
    },
    removeCorpseFromGurney = {
        id = "removeCorpseFromGurney",
        station = "autopsy",
        labelKey = "IGUI_KCP_Action_RemoveCorpseFromGurney",
        duration = 10,
    },
    cleanGurney = {
        id = "cleanGurney",
        station = "autopsy",
        labelKey = "IGUI_KCP_Action_CleanGurney",
        duration = 150,
        sound = "FirstAidCleanBurn",
    },
    autopsy = {
        id = "autopsy",
        station = "autopsy",
        labelKey = "IGUI_KCP_Action_Autopsy",
        duration = 500,
        sound = "ButcheringGatherMeatLarge",
    },
    extractSample = {
        id = "extractSample",
        station = "autopsy",
        labelKey = "IGUI_KCP_Action_ExtractSample",
        duration = 250,
        sound = "FirstAidRemoveFromWound",
    },
    examineMicroscope = {
        id = "examineMicroscope",
        station = "microscope",
        labelKey = "IGUI_KCP_Action_ExamineMicroscope",
        duration = 200,
        requiredFirstAid = 3,
    },
    runCentrifuge = {
        id = "runCentrifuge",
        station = "centrifuge",
        labelKey = "IGUI_KCP_Action_RunCentrifuge",
        duration = 400,
        requiredFirstAid = 4,
        requiresPower = true,
        startSound = "LightSwitch",
        sound = "ClothingWasherRunning",
        finishSound = "ClothingWasherFinished",
    },
    calibrateAnalyzer = {
        id = "calibrateAnalyzer",
        station = "bioAnalyzer",
        labelKey = "IGUI_KCP_Action_CalibrateAnalyzer",
        duration = 300,
        requiredElectricity = 3,
        requiresPower = true,
        sound = "Dismantle",
    },
    analyzeViralFraction = {
        id = "analyzeViralFraction",
        station = "bioAnalyzer",
        labelKey = "IGUI_KCP_Action_AnalyzeViralFraction",
        duration = 400,
        requiredFirstAid = 5,
        requiresPower = true,
        sound = "CarBatteryChargerRunning",
    },
    writeScientificRecord = {
        id = "writeScientificRecord",
        station = "terminal",
        labelKey = "IGUI_KCP_Action_WriteScientificRecord",
        duration = 300,
        sound = "MapAddNote",
    },
    exportData = {
        id = "exportData",
        station = "terminal",
        labelKey = "IGUI_KCP_Action_ExportData",
        duration = 300,
        requiresPower = true,
        sound = "KCP_KeyboardTyping",
    },
    importData = {
        id = "importData",
        station = "terminal",
        labelKey = "IGUI_KCP_Action_ImportData",
        duration = 200,
        requiresPower = true,
        sound = "KCP_KeyboardTyping",
    },
    runSynthesizer = {
        id = "runSynthesizer",
        station = "synthesizer",
        labelKey = "IGUI_KCP_Action_RunSynthesizer",
        duration = 600,
        requiredFirstAid = 7,
        requiresPower = true,
        startSound = "TransferLiquid",
        sound = "KCP_SynthesizerRotor",
    },
}

local BY_STATION = {}
for _, action in pairs(ACTIONS) do
    BY_STATION[action.station] = BY_STATION[action.station] or {}
    table.insert(BY_STATION[action.station], action)
end

local ORDER = {
    autopsy = {
        "placeCorpseOnGurney",
        "removeCorpseFromGurney",
        "cleanGurney",
        "autopsy",
        "extractSample",
    },
    microscope = { "examineMicroscope" },
    centrifuge = { "runCentrifuge" },
    bioAnalyzer = { "calibrateAnalyzer", "analyzeViralFraction" },
    terminal = { "writeScientificRecord", "exportData", "importData" },
    synthesizer = { "runSynthesizer" },
}

function KCPActionDefinitions.get(actionId)
    return ACTIONS[actionId]
end

function KCPActionDefinitions.getForStation(stationId)
    local result = {}
    for _, actionId in ipairs(ORDER[stationId] or {}) do
        table.insert(result, ACTIONS[actionId])
    end
    return result
end

function KCPActionDefinitions.getAll()
    return ACTIONS
end
