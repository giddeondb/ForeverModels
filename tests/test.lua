local function session(db, value, options)
    options = options or {}
    local env = setmetatable({}, { __index = _G })
    local handler, writes, messages = nil, {}, {}
    local combat = options.combat
    env.ForeverModelsDB = db
    env.ForeverModelsAccountDB = options.account
    env.UnitGUID = function() return options.guid or "Player-test-undead" end
    env.UnitFullName = function() return "Test", "Realm" end
    env.GetRealmName = function() return "Realm" end
    env.SlashCmdList = {}
    env.Enum = options.legacyAPI and {} or {
        SdToggleUsageLocationUI = { OptionsMenu = 3 },
    }
    if options.noEnum then env.Enum = false end
    env.C_AddOns = { GetAddOnMetadata = function(addon, key)
        assert(addon == "ForeverModels" and key == "Version")
        return options.version or "9.42.0"
    end }
    env.print = function(text) messages[#messages + 1] = text end
    local widgets = {}
    local function widget(name)
        local w = { scripts = {}, shown = true, enabled = true }
        function w:SetScript(kind, fn) self.scripts[kind] = fn end
        function w:SetText(text) self.text = text end
        function w:SetEnabled(value) self.enabled = not not value end
        function w:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
        function w:Hide() self.shown = false end
        function w:IsShown() return self.shown end
        function w:SetShown(v) if v then self:Show() else self:Hide() end end
        function w:CreateFontString() return widget() end
        function w:Click()
            if self.enabled and self.scripts.OnClick then self.scripts.OnClick(self) end
        end
        for _, method in ipairs({ "SetSize", "SetPoint", "SetWidth", "SetJustifyH",
            "SetMovable", "EnableMouse", "RegisterForDrag", "SetClampedToScreen",
            "SetFrameStrata", "StartMoving", "StopMovingOrSizing", "RegisterEvent" }) do
            w[method] = function() end
        end
        if name then widgets[name] = w; env[name] = w end
        return w
    end
    env.CreateFrame = function(_, name)
        local w = widget(name)
        w.TitleText = widget()
        if not handler then
            w.SetScript = function(self, kind, fn)
                self.scripts[kind] = fn
                if kind == "OnEvent" then handler = fn end
            end
        end
        return w
    end
    env.GetBuildInfo = function() return "1.60.1", "69977", "", 16001 end
    env.InCombatLockdown = function() return combat end
    env.StaticPopupDialogs = {}
    local popupCount = 0
    env.StaticPopup_Show = function() popupCount = popupCount + 1 end
    env.StaticPopup_Hide = function() end
    env.ReloadUI = function() error("Must never reload without user action") end
    env.hooksecurefunc = function(t, key, hook)
        local original = t[key]
        t[key] = function(...)
            original(...)
            hook(...)
        end
    end
    env.C_GameRules = {
        IsSDHDToggleEnabled = function() return value ~= nil end,
        AccountHasSDEnabled = function() return value == "0" end,
        SetSDHDToggleValue = function(isSD, ...)
            assert(type(isSD) == "boolean")
            if options.legacyAPI then
                assert(select("#", ...) == 0, "Legacy setter expects only the model choice")
            else
                assert(select("#", ...) == 1 and (...) == env.Enum.SdToggleUsageLocationUI.OptionsMenu,
                    "bad argument #2: expected OptionsMenu usageLocation")
            end
            if options.throw then error("restricted") end
            local wanted = isSD and "0" or "1"
            writes[#writes + 1] = wanted
            if not options.reject then value = wanted end
        end,
    }
    local chunk = assert(loadfile("ForeverModels.lua"))
    setfenv(chunk, env)
    chunk("ForeverModels")
    handler(nil, "ADDON_LOADED", "ForeverModels")
    return {
        env = env, writes = writes, messages = messages, widgets = widgets,
        event = function(event, arg) handler(nil, event, arg) end,
        command = function(msg) env.SlashCmdList.FOREVERMODELS(msg) end,
        live = function() return value end,
        popups = function() return popupCount end,
        external = function(v)
            if options.legacyAPI then
                env.C_GameRules.SetSDHDToggleValue(v == "0")
            else
                env.C_GameRules.SetSDHDToggleValue(v == "0", env.Enum.SdToggleUsageLocationUI.OptionsMenu)
            end
        end,
        endCombat = function()
            combat = false
            handler(nil, "PLAYER_REGEN_ENABLED")
        end,
    }
end

local count = 0
local function test(name, fn)
    fn()
    count = count + 1
    print("PASS " .. name)
end

test("first login captures without a write", function()
    local s = session(nil, "0")
    s.event("PLAYER_ENTERING_WORLD")
    assert(s.env.ForeverModelsDB.mode == "0" and #s.writes == 0)
end)

test("login restores HD and SD with the required usage location", function()
    for _, mode in ipairs({ "0", "1" }) do
        local s = session({ mode = mode }, mode == "0" and "1" or "0")
        s.event("PLAYER_ENTERING_WORLD")
        assert(s.live() == mode and #s.writes == 1)
        assert(not table.concat(s.messages):find("Could not apply", 1, true))
    end
end)

test("older clients without the usage location enum still switch models", function()
    for _, noEnum in ipairs({ false, true }) do
        local s = session({ mode = "1" }, "0", { legacyAPI = true, noEnum = noEnum })
        s.event("PLAYER_ENTERING_WORLD")
        assert(s.live() == "1" and #s.writes == 1)
        s.command("sd")
        assert(s.live() == "0" and #s.writes == 2)
        s.external("1")
        assert(s.env.ForeverModelsDB.mode == "1")
    end
end)

test("two characters restore independent preferences across sessions", function()
    local undead, human = {}, {}
    local s = session(undead, "0")
    s.event("PLAYER_ENTERING_WORLD")
    s.command("hd")
    assert(undead.mode == "1" and s.live() == "1")
    s = session(human, s.live())
    s.event("PLAYER_ENTERING_WORLD")
    s.command("sd")
    assert(human.mode == "0")
    s = session(undead, s.live())
    s.external("0") -- Startup event must not replace the saved preference.
    s.event("PLAYER_ENTERING_WORLD")
    assert(s.live() == "1" and undead.mode == "1")
    s = session(human, s.live())
    s.event("PLAYER_ENTERING_WORLD")
    assert(s.live() == "0" and human.mode == "0")
end)

test("manual settings are learned only while enabled and in world", function()
    local s = session({ mode = "1" }, "1")
    s.event("PLAYER_ENTERING_WORLD")
    s.external("0")
    assert(s.env.ForeverModelsDB.mode == "0")
    s.command("off")
    s.external("1")
    assert(s.env.ForeverModelsDB.mode == "0")
    s.command("on")
    assert(s.live() == "0")
    s.event("PLAYER_LEAVING_WORLD")
    s.external("1")
    assert(s.env.ForeverModelsDB.mode == "0")
end)

test("unavailable API causes no writes and preserves requested preference", function()
    local s = session(nil, nil)
    s.event("PLAYER_ENTERING_WORLD")
    s.command("hd")
    s.command("status")
    assert(#s.writes == 0 and s.env.ForeverModelsDB.mode == "1")
    assert(table.concat(s.messages):find("unavailable"))
end)

test("rejected and throwing writes preserve preference", function()
    for _, options in ipairs({ { reject = true }, { throw = true } }) do
        local s = session({ mode = "1" }, "0", options)
        s.event("PLAYER_ENTERING_WORLD")
        s.command("hd")
        assert(s.env.ForeverModelsDB.mode == "1" and s.live() == "0")
        assert(table.concat(s.messages):find("Could not apply"))
    end
end)

test("combat defers and disabling cancels pending switch", function()
    local s = session({ mode = "1" }, "0", { combat = true })
    s.event("PLAYER_ENTERING_WORLD")
    assert(#s.writes == 0)
    s.external("0")
    assert(s.env.ForeverModelsDB.mode == "1")
    assert(not table.concat(s.messages):find("models applied", 1, true))
    s.endCombat()
    assert(s.live() == "1" and s.popups() == 0)
    assert(s.messages[#s.messages]:find("HD models applied for Test-Realm.", 1, true))
    s = session({ mode = "1" }, "0", { combat = true })
    s.event("PLAYER_ENTERING_WORLD")
    s.command("off")
    s.endCombat()
    assert(#s.writes == 0)
end)

test("reload and repeated world entry do not write an unchanged setting", function()
    local s = session({ mode = "1" }, "1")
    s.event("PLAYER_ENTERING_WORLD")
    s.event("PLAYER_LEAVING_WORLD")
    s.event("PLAYER_ENTERING_WORLD")
    assert(#s.writes == 0)
end)

test("login changes notify the current character without a reload prompt", function()
    local db = { mode = "1", helpShown = true }
    local s = session(db, "0")
    s.event("PLAYER_ENTERING_WORLD")
    assert(s.popups() == 0 and s.live() == "1")
    assert(#s.messages == 1)
    assert(s.messages[1]:find("HD models applied for Test-Realm.", 1, true))
    s.event("PLAYER_ENTERING_WORLD")
    assert(#s.messages == 1 and #s.writes == 1)
    s = session(db, "1")
    s.event("PLAYER_ENTERING_WORLD")
    assert(s.popups() == 0 and #s.writes == 0 and #s.messages == 0)
end)

test("slash changes confirm both modes without reload state", function()
    local s = session({ mode = "1" }, "1")
    s.event("PLAYER_ENTERING_WORLD")
    for _, mode in ipairs({ "sd", "hd" }) do
        s.command(mode)
        assert(s.messages[#s.messages]:find(mode:upper() .. " models applied for Test-Realm.", 1, true))
    end
    s.command("status")
    assert(s.popups() == 0)
    assert(not table.concat(s.messages):lower():find("reload"))
end)


local function roundTrip(value)
    local function serialize(v)
        if type(v) == "table" then
            local parts = {}
            for k, child in pairs(v) do
                parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(child)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        if type(v) == "string" then return string.format("%q", v) end
        return tostring(v)
    end
    return assert(loadstring("return " .. serialize(value)))()
end

test("account records survive fresh loads when character files are missing", function()
    local account = {}
    local s = session(nil, "0", { account = account, guid = "Player-undead" })
    s.event("PLAYER_LOGIN")
    s.event("PLAYER_ENTERING_WORLD")
    s.command("hd")
    account = roundTrip(account)
    s = session(nil, "1", { account = account, guid = "Player-human" })
    s.event("PLAYER_LOGIN")
    s.event("PLAYER_ENTERING_WORLD")
    s.command("sd")
    account = roundTrip(account)
    s = session(nil, "0", { account = account, guid = "Player-undead" })
    s.event("PLAYER_LOGIN")
    s.event("PLAYER_ENTERING_WORLD")
    assert(s.live() == "1" and s.env.ForeverModelsDB.mode == "1")
    assert(not table.concat(s.messages):find("Remembered your current"))
    assert(account.characters["Player-human"].mode == "0")
    account = roundTrip(account)
    s = session(nil, "1", { account = account, guid = "Player-human" })
    s.event("PLAYER_LOGIN")
    s.event("PLAYER_ENTERING_WORLD")
    assert(s.live() == "0")
end)

test("existing account choice wins over stale per-character data", function()
    local account = { characters = { ["Player-test-undead"] = { mode = "1" } } }
    local s = session({ mode = "0" }, "0", { account = account })
    s.event("PLAYER_ENTERING_WORLD")
    assert(s.live() == "1")
end)

test("legacy choice migrates and numeric values are normalized", function()
    local s = session({ mode = 1, enabled = false }, "0")
    s.event("PLAYER_LOGIN")
    assert(s.env.ForeverModelsAccountDB.characters["Player-test-undead"].mode == "1")
    s.event("PLAYER_ENTERING_WORLD")
    assert(#s.writes == 0 and s.env.ForeverModelsDB.enabled == false)
end)

test("only hd and sd are accepted as model arguments", function()
    local s = session(nil, "0")
    s.event("PLAYER_ENTERING_WORLD")
    s.command(" HD ")
    assert(s.live() == "1")
    s.command("standard")
    assert(s.live() == "1")
    s.command(" SD ")
    assert(s.live() == "0")
end)


test("roster edits another character without changing current client or prompting", function()
    local account = { characters = {
        ["Player-test-undead"] = { name = "Undead", realm = "Realm", mode = "1" },
        ["Player-human"] = { name = "Human", realm = "Realm", mode = "0" },
    } }
    local s = session(nil, "1", { account = account })
    s.event("PLAYER_ENTERING_WORLD")
    s.command("")
    local rows = s.widgets.ForeverModelsPanel.rows
    assert(rows[1].guid == "Player-test-undead")
    assert(rows[2].guid == "Player-human")
    rows[2].hd:Click()
    assert(account.characters["Player-human"].mode == "1")
    assert(s.live() == "1" and #s.writes == 0 and s.popups() == 0)
    rows[2].sd:Click()
    assert(account.characters["Player-human"].mode == "0")
    rows[1].sd:Click()
    assert(s.live() == "0" and s.popups() == 0)
    assert(s.messages[#s.messages]:find("SD models applied for Test-Realm.", 1, true))
    assert(rows[1].sd.enabled == false)
    assert(s.widgets.ForeverModelsReloadButton == nil)
end)

test("roster pages select the correct character and survive reopening", function()
    local account = { characters = {} }
    for i = 1, 13 do
        account.characters["Player-" .. i] = { name = string.format("Alt%02d", i), mode = "0" }
    end
    local s = session({ mode = "1" }, "1", { account = account })
    s.event("PLAYER_ENTERING_WORLD")
    s.command("")
    assert(not s.widgets.ForeverModelsPreviousPage.enabled)
    s.widgets.ForeverModelsNextPage:Click()
    local row = s.widgets.ForeverModelsPanel.rows[1]
    local key = row.guid
    assert(key ~= "Player-test-undead")
    row.hd:Click()
    assert(account.characters[key].mode == "1" and #s.writes == 0)
    s.widgets.ForeverModelsNextPage:Click()
    assert(not s.widgets.ForeverModelsNextPage.enabled)
    assert(not s.widgets.ForeverModelsPanel.rows[3].shown)
    s.command("")
    assert(not s.widgets.ForeverModelsPanel:IsShown())
    s.command("")
    assert(s.widgets.ForeverModelsPanel:IsShown())
end)

test("choosing an offline character's saved mode resumes its disabled preference", function()
    local account = { characters = {
        ["Player-human"] = { name = "Human", mode = "0", enabled = false },
    } }
    local s = session({ mode = "1" }, "1", { account = account })
    s.event("PLAYER_ENTERING_WORLD")
    s.command("")
    local row = s.widgets.ForeverModelsPanel.rows[2]
    assert(row.sd.enabled)
    row.sd:Click()
    assert(account.characters["Player-human"].enabled)
    assert(#s.writes == 0 and s.popups() == 0)
end)

test("restoration uses the account record if the legacy global is replaced after login", function()
    local account = { characters = {
        ["Player-test-undead"] = { name = "Undead", mode = "1" },
    } }
    local s = session(nil, "0", { account = account })
    s.event("PLAYER_LOGIN")
    s.env.ForeverModelsDB = {}
    s.event("PLAYER_ENTERING_WORLD")
    assert(s.live() == "1", "Lost account HD choice after legacy global replacement")
    assert(account.characters["Player-test-undead"].mode == "1")
    s.command("sd")
    assert(account.characters["Player-test-undead"].mode == "0")
end)

test("status reads the installed TOC version", function()
    local s = session(nil, "1", { version = "0.27.0" })
    s.event("PLAYER_ENTERING_WORLD")
    s.command("status")
    assert(table.concat(s.messages):find("v0.27.0", 1, true))
end)

print(count .. " tests passed")
