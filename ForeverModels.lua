local ADDON = ...
local frame = CreateFrame("Frame")
local ready, applying, pending = false, false, false
local panel, refresh
local characterSettings
local characterKey
local storageSource = "Not initialized"
local lastResult = "Waiting for login."

local function say(text)
    print("|cff80c0ffForever Models:|r " .. text)
end

local function initializeCharacter()
    if characterKey then return true end
    local guid = UnitGUID("player")
    if not guid then
        say("Character identity unavailable; saved choices have not been changed.")
        return false
    end
    characterKey = guid
    local characters = ForeverModelsAccountDB.characters
    local saved = characters[guid]
    if type(saved) ~= "table" then
        -- Keep the old per-character variable as a migration source and backup.
        saved = ForeverModelsDB
        characters[guid] = saved
        storageSource = (saved.mode == "0" or saved.mode == "1")
            and "Migrated character file" or "New character"
    else
        storageSource = "Account character record"
    end
    if saved.mode == 0 or saved.mode == 1 then saved.mode = tostring(saved.mode) end
    if saved.enabled == nil then saved.enabled = true end
    characterSettings = saved
    ForeverModelsDB = saved
    local name, realm = UnitFullName("player")
    saved.name = name
    saved.realm = realm or GetRealmName()
    return true
end

local function read()
    if not C_GameRules or not C_GameRules.IsSDHDToggleEnabled
        or not C_GameRules.AccountHasSDEnabled or not C_GameRules.SetSDHDToggleValue then
        return nil
    end
    local ok, enabled = pcall(C_GameRules.IsSDHDToggleEnabled)
    if not ok or not enabled then return nil end
    local success, isSD = pcall(C_GameRules.AccountHasSDEnabled)
    if success and type(isSD) == "boolean" then return isSD and "0" or "1" end
    return nil
end

local function label(value)
    if value == "1" then return "HD" end
    if value == "0" then return "SD" end
    return "Unavailable"
end

local function update(text)
    lastResult = text
    if refresh then refresh() end
end

local function reportApplied(announce)
    update(label(read()) .. " models applied for " .. (characterSettings.name or "this character")
        .. (characterSettings.realm and "-" .. characterSettings.realm or "") .. ".")
    if announce then say(lastResult) end
end

local function apply(announce)
    if not initializeCharacter() then return end
    pending = false
    if not characterSettings.enabled then
        update("Automatic switching is off for this character.")
        return
    end
    local current = read()
    if not current then
        update("Model setting unavailable in this client. Run /models status.")
        say(lastResult)
        return
    end
    local wanted = characterSettings.mode
    if wanted ~= "0" and wanted ~= "1" then
        characterSettings.mode = current
        update("Remembered your current " .. label(current) .. " setting.")
        say(lastResult)
        return
    end
    if current == wanted then
        reportApplied(announce)
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        pending = true
        update("Saved " .. label(wanted) .. "; waiting until combat ends to apply.")
        say(lastResult)
        return
    end
    applying = true
    local usageLocation = Enum and Enum.SdToggleUsageLocationUI
        and Enum.SdToggleUsageLocationUI.OptionsMenu
    local ok, err
    if usageLocation then
        -- Match Blizzard's in-game graphics setting on clients requiring a source.
        ok, err = pcall(C_GameRules.SetSDHDToggleValue, wanted == "0", usageLocation)
    else
        -- Older Forever clients expose only the one-argument setter.
        ok, err = pcall(C_GameRules.SetSDHDToggleValue, wanted == "0")
    end
    applying = false
    if not ok or read() ~= wanted then
        update("Could not apply " .. label(wanted) .. ". Your preference is still saved.")
        say(lastResult .. (not ok and " " .. tostring(err) or ""))
        return
    end
    reportApplied(true)
end

local function choose(mode)
    if not initializeCharacter() then return end
    characterSettings.mode = mode
    characterSettings.enabled = true
    apply(true)
end

local function chooseCharacter(guid, mode)
    if guid == characterKey then
        choose(mode)
        return
    end
    local saved = ForeverModelsAccountDB.characters[guid]
    if type(saved) ~= "table" then return end
    saved.mode = mode
    saved.enabled = true
    if refresh then refresh() end
end

local function roster()
    local list = {}
    for guid, saved in pairs(ForeverModelsAccountDB.characters) do
        if type(saved) == "table" then
            list[#list + 1] = { guid = guid, saved = saved }
        end
    end
    table.sort(list, function(a, b)
        if a.guid == characterKey then return b.guid ~= characterKey end
        if b.guid == characterKey then return false end
        local an = (a.saved.name or a.guid) .. " " .. (a.saved.realm or "")
        local bn = (b.saved.name or b.guid) .. " " .. (b.saved.realm or "")
        if an == bn then return a.guid < b.guid end
        return an < bn
    end)
    return list
end

local function status()
    local version, build, _, interface = GetBuildInfo()
    local addonVersion = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "unknown"
    say("v" .. addonVersion .. " | client " .. tostring(version) .. " build " .. tostring(build)
        .. " interface " .. tostring(interface))
    say("Remember: " .. (characterSettings.enabled and "on" or "off")
        .. " | saved: " .. label(characterSettings.mode)
        .. " | client setting: " .. label(read()))
    say("Character: " .. tostring(characterSettings.name) .. "-" .. tostring(characterSettings.realm)
        .. " | ID: " .. tostring(characterKey) .. " | storage: " .. storageSource)
    say("Persistence: Standard SavedVariables loader")
    say(lastResult)
end

local function createPanel()
    local PAGE_SIZE = 6
    local page = 1
    panel = CreateFrame("Frame", "ForeverModelsPanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(640, 510)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true)
    panel:SetFrameStrata("DIALOG")
    panel.TitleText:SetText("Forever Models")
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverModelsPanel") end

    local function text(parent, font, x, y, width)
        local t = parent:CreateFontString(nil, "OVERLAY", font)
        t:SetPoint("TOPLEFT", x, y)
        t:SetWidth(width)
        t:SetJustifyH("LEFT")
        return t
    end
    local function button(parent, name, caption, x, y, width, click)
        local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
        b:SetSize(width, 26)
        b:SetPoint("TOPLEFT", x, y)
        b:SetText(caption)
        b:SetScript("OnClick", click)
        return b
    end

    local state = text(panel, "GameFontHighlight", 20, -42, 598)
    local note = text(panel, "GameFontHighlightSmall", 20, -94, 595)
    note:SetText("Click HD or SD to save. Other characters use that choice on their next login.")
    text(panel, "GameFontNormal", 20, -124, 360):SetText("Character / realm")
    text(panel, "GameFontNormal", 410, -124, 200):SetText("Saved preference")

    panel.rows = {}
    for i = 1, PAGE_SIZE do
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(598, 42)
        row:SetPoint("TOPLEFT", 20, -147 - (i - 1) * 44)
        row.nameText = text(row, "GameFontHighlight", 4, -2, 374)
        row.realmText = text(row, "GameFontHighlightSmall", 4, -22, 374)
        row.hd = button(row, "ForeverModelsRow" .. i .. "HD", "HD", 390, -7, 94,
            function() chooseCharacter(row.guid, "1") end)
        row.sd = button(row, "ForeverModelsRow" .. i .. "SD", "SD", 492, -7, 94,
            function() chooseCharacter(row.guid, "0") end)
        panel.rows[i] = row
    end

    local pageLabel = text(panel, "GameFontHighlightSmall", 255, -422, 140)
    local previous = button(panel, "ForeverModelsPreviousPage", "Previous", 20, -415, 108,
        function() page = page - 1; refresh() end)
    local nextPage = button(panel, "ForeverModelsNextPage", "Next", 510, -415, 108,
        function() page = page + 1; refresh() end)
    text(panel, "GameFontHighlightSmall", 20, -458, 598):SetText(
        "Missing a character? Log into it once with this add-on enabled.\nChoices save automatically. WoW writes them to disk on logout or UI reload.")

    refresh = function()
        state:SetText("This character: saved " .. label(characterSettings.mode)
            .. "  |  Client setting: " .. label(read())
            .. "\n" .. lastResult
            .. (pending and "  |  Waiting for combat to end" or "")
            .. (characterSettings.enabled and "" or "  |  Automatic switching off"))
        local list = roster()
        local pages = math.max(1, math.ceil(#list / PAGE_SIZE))
        page = math.max(1, math.min(page, pages))
        for i, row in ipairs(panel.rows) do
            local entry = list[(page - 1) * PAGE_SIZE + i]
            if entry then
                local saved = entry.saved
                row.guid = entry.guid
                local current = entry.guid == characterKey
                row.nameText:SetText((current and "|cffffd100" or "")
                    .. (saved.name or entry.guid) .. (current and " (current)|r" or ""))
                row.realmText:SetText((saved.realm or "Unknown realm")
                    .. (saved.enabled == false and "  |  Automatic switching off" or ""))
                row.hd:SetText(saved.mode == "1" and "HD (saved)" or "HD")
                row.sd:SetText(saved.mode == "0" and "SD (saved)" or "SD")
                row.hd:SetEnabled(saved.mode ~= "1" or saved.enabled == false)
                row.sd:SetEnabled(saved.mode ~= "0" or saved.enabled == false)
                row:Show()
            else
                row.guid = nil
                row:Hide()
            end
        end
        pageLabel:SetText("Page " .. page .. " of " .. pages)
        previous:SetEnabled(page > 1)
        nextPage:SetEnabled(page < pages)
    end
    panel:SetScript("OnShow", refresh)
    refresh()
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        if type(ForeverModelsAccountDB) ~= "table" then ForeverModelsAccountDB = {} end
        if type(ForeverModelsAccountDB.characters) ~= "table" then
            ForeverModelsAccountDB.characters = {}
        end
        if type(ForeverModelsDB) ~= "table" then ForeverModelsDB = {} end
        if ForeverModelsDB.enabled == nil then ForeverModelsDB.enabled = true end
        if C_GameRules and C_GameRules.SetSDHDToggleValue then
            hooksecurefunc(C_GameRules, "SetSDHDToggleValue", function(isSD)
                if not ready or applying or pending or not characterSettings.enabled then return end
                if type(isSD) ~= "boolean" then return end
                local current = read()
                local wanted = isSD and "0" or "1"
                if current == wanted then
                    characterSettings.mode = current
                    reportApplied(false)
                end
            end)
        end
    elseif event == "PLAYER_LOGOUT" then
        if characterSettings then ForeverModelsDB = characterSettings end
    elseif event == "PLAYER_LOGIN" then
        initializeCharacter()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Ignore startup setter calls; preserve the preference loaded from disk.
        apply(false)
        ready = characterKey ~= nil
        if ready and not characterSettings.helpShown then
            say("Type /models to choose HD or SD models for your characters.")
            characterSettings.helpShown = true
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        ready = false
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then apply(false) end
        if refresh then refresh() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if refresh then refresh() end

    end
end)

SLASH_FOREVERMODELS1 = "/models"
SLASH_FOREVERMODELS2 = "/fmodels"
SlashCmdList.FOREVERMODELS = function(msg)
    if not initializeCharacter() then return end
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "hd" then choose("1")
    elseif msg == "sd" then choose("0")
    elseif msg == "status" then status()
    elseif msg == "off" then
        characterSettings.enabled = false
        pending = false
        update("Automatic switching is off for this character.")
        say(lastResult)
    elseif msg == "on" then
        characterSettings.enabled = true
        apply(true)
    elseif msg == "" then
        if not panel then createPanel() else panel:SetShown(not panel:IsShown()) end
    else say("/models [hd | sd | status | on | off]") end
end
