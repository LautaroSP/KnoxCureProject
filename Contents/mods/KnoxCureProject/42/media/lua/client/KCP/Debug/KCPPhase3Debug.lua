KCPPhase3Debug = KCPPhase3Debug or {}

local TEST_ITEMS = {
    ["Base.CleaningLiquid2"] = 1,
    ["Base.RippedSheets"] = 3,
    ["Base.Sponge"] = 1,
    ["Base.Scalpel"] = 2,
    ["Base.Gloves_Surgical"] = 1,
    ["Base.Hat_SurgicalMask"] = 1,
    ["Base.Screwdriver"] = 1,
    ["Base.Notebook"] = 2,
    ["Base.Pen"] = 1,
    ["KCP.ProvisionalSampleContainer"] = 4,
    ["KCP.RawTissueSample"] = 1,
    ["KCP.ClassifiedTissueSample"] = 1,
    ["KCP.CentrifugeBalanceTube"] = 4,
    ["KCP.ViralFraction"] = 1,
    ["KCP.StabilizedViralFraction"] = 1,
    ["KCP.ResearchDrive"] = 1,
    ["KCP.SynthesisReagentKit"] = 2,
    ["KCP.EmptyInjector"] = 2,
}

local function addTestKit(playerObj)
    local inventory = playerObj:getInventory()
    for fullType, count in pairs(TEST_ITEMS) do
        for _ = 1, count do inventory:AddItem(fullType) end
    end
    HaloTextHelper.addText(playerObj, getText("IGUI_KCP_Debug_TestKitAdded"), "[br/]", HaloTextHelper.getGoodColor())
end

local function setTestSkills(playerObj)
    playerObj:setPerkLevelDebug(Perks.Doctor, 7)
    playerObj:getXp():setXPToLevel(Perks.Doctor, 7)
    playerObj:setPerkLevelDebug(Perks.Electricity, 3)
    playerObj:getXp():setXPToLevel(Perks.Electricity, 3)
    HaloTextHelper.addText(playerObj, getText("IGUI_KCP_Debug_TestSkillsSet"), "[br/]", HaloTextHelper.getGoodColor())
end

function KCPPhase3Debug.addMenu(parentMenu, playerObj)
    local option = parentMenu:addOption(getText("IGUI_KCP_Debug_Phase3"), playerObj, nil)
    local menu = ISContextMenu:getNew(parentMenu)
    parentMenu:addSubMenu(option, menu)
    menu:addOption(getText("IGUI_KCP_Debug_AddTestKit"), playerObj, addTestKit)
    menu:addOption(getText("IGUI_KCP_Debug_SetTestSkills"), playerObj, setTestSkills)
end
