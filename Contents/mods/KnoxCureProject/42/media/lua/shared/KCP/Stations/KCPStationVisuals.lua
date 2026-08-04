require "Moveables/ISMoveableSpriteProps"

KCPStationVisuals = KCPStationVisuals or {}

local STATE_START_INDEX = {
    ready = { centrifuge = 0, bioAnalyzer = 12, synthesizer = 24 },
    working = { centrifuge = 4, bioAnalyzer = 16, synthesizer = 32 },
    broken = { centrifuge = 8, bioAnalyzer = 20, synthesizer = 40 },
}

local BASE_START_INDEX = { centrifuge = 0, bioAnalyzer = 8, synthesizer = 16 }

function KCPStationVisuals.getOverlayName(worldObject, stationId, state)
    if state == "off" then return nil end
    local sprite = worldObject and worldObject:getSprite()
    local spriteName = sprite and sprite:getName()
    local baseIndex = spriteName and tonumber(string.match(spriteName, "_(%d+)$"))
    local stateStart = STATE_START_INDEX[state] and STATE_START_INDEX[state][stationId]
    local baseStart = BASE_START_INDEX[stationId]
    if not baseIndex or not stateStart or not baseStart then return nil end
    return "kcp_lab_equipment_leds_01_" .. tostring(stateStart + baseIndex - baseStart)
end

local function setObjectState(worldObject, stationId, state)
    local overlay = KCPStationVisuals.getOverlayName(worldObject, stationId, state)
    worldObject:setOverlaySprite(overlay, 1.0, 1.0, 1.0, 1.0)
    if isServer() and worldObject.transmitUpdatedSpriteToClients then
        worldObject:transmitUpdatedSpriteToClients()
    end
end

function KCPStationVisuals.setState(worldObject, stationId, state)
    if not worldObject then return end
    local props = ISMoveableSpriteProps.new(worldObject:getSprite())
    if props.isMultiSprite then
        local grid = props:getSpriteGridInfo(worldObject:getSquare(), true)
        if grid then
            for _, member in ipairs(grid) do
                setObjectState(member.object, stationId, state)
            end
            return
        end
    end
    setObjectState(worldObject, stationId, state)
end
