KCPStationRegistry = KCPStationRegistry or {}

local STATIONS = {
    autopsy = { id = "autopsy", labelKey = "IGUI_KCP_Station_Autopsy" },
    microscope = { id = "microscope", labelKey = "IGUI_KCP_Station_Microscope" },
    coldStorage = { id = "coldStorage", labelKey = "IGUI_KCP_Station_ColdStorage" },
    centrifuge = { id = "centrifuge", labelKey = "IGUI_KCP_Station_Centrifuge" },
    bioAnalyzer = { id = "bioAnalyzer", labelKey = "IGUI_KCP_Station_BioAnalyzer" },
    synthesizer = { id = "synthesizer", labelKey = "IGUI_KCP_Station_Synthesizer" },
    terminal = { id = "terminal", labelKey = "IGUI_KCP_Station_Terminal" },
}

local AUTOPSY_NAMES = {
    ["Dentist Patient|Chair"] = true,
    ["Patient|Chair"] = true,
    ["Large Medical|Bed"] = true,
    ["Hospital|Bed"] = true,
    ["Morgue|Table"] = true,
    ["Stretcher|Bed"] = true,
}

local function getProperty(properties, key)
    if not properties or not properties:has(key) then
        return nil
    end
    return properties:get(key)
end

local function splitSpriteName(spriteName)
    if not spriteName then
        return nil, nil
    end
    local sheet, index = string.match(spriteName, "^(.*)_(%d+)$")
    return sheet, tonumber(index)
end

function KCPStationRegistry.getStation(worldObject)
    if not worldObject or not worldObject.getSprite then
        return nil
    end

    local sprite = worldObject:getSprite()
    if not sprite then
        return nil
    end

    local spriteName = sprite:getName()
    local sheet, index = splitSpriteName(spriteName)
    local properties = sprite:getProperties()

    if sheet == "kcp_lab_equipment_01" and index then
        if index >= 0 and index <= 3 then
            return STATIONS.centrifuge
        end
        if index >= 8 and index <= 11 then
            return STATIONS.bioAnalyzer
        end
        if index >= 16 and index <= 23 then
            return STATIONS.synthesizer
        end
    end

    if sheet == "appliances_refrigeration_01" then
        return STATIONS.coldStorage
    end

    if sheet == "appliances_com_01" and index and index >= 72 and index <= 75 then
        return STATIONS.terminal
    end

    if sheet == "location_community_medical_01" and index and index >= 136 and index <= 139 then
        return STATIONS.microscope
    end

    local groupName = getProperty(properties, "GroupName")
    local customName = getProperty(properties, "CustomName")
    if AUTOPSY_NAMES[tostring(groupName) .. "|" .. tostring(customName)] then
        return STATIONS.autopsy
    end

    return nil
end

function KCPStationRegistry.getStations()
    return STATIONS
end
