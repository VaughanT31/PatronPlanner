-- Patron Planner - bootstrap: SavedVariables and the slash command.
--
--   PatronPlannerDB = {
--     version  = DB_VERSION,
--     settings = { ... },        see DEFAULTS
--   }

local ADDON_NAME, ns = ...
local L = ns.L

local DB_VERSION = 1

local DEFAULTS = {
    version = DB_VERSION,
    settings = {
        -- "auto" picks the first installed source (Pricing/Pricing.lua).
        priceSource = "auto",
        -- true shows Blizzard's list instead of the cards.
        classic = false,
        filter = "all",
        sort = "best",
        showCopper = false,
        -- Count materials you own as free instead of at market value.
        ownedFree = false,
        -- Time left turns amber under this many hours.
        soonHours = 6,
        debug = false,
    },
}

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                ApplyDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            ApplyDefaults(target[key], value)
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, name)
    if name ~= ADDON_NAME then return end
    frame:UnregisterEvent("ADDON_LOADED")
    PatronPlannerDB = PatronPlannerDB or {}
    ApplyDefaults(PatronPlannerDB, DEFAULTS)
    ns.db = PatronPlannerDB
end)

local function Say(text)
    print("|cff7fbfffPatron Planner|r " .. text)
end

SLASH_PATRONPLANNER1 = "/pp"
SLASH_PATRONPLANNER2 = "/patronplanner"
SlashCmdList.PATRONPLANNER = function(input)
    local command = (input or ""):lower():match("^%s*(%S*)")
    local settings = ns.db.settings
    if command == "cards" or command == "classic" then
        settings.classic = command == "classic"
        Say(settings.classic and L.SET_CLASSIC or L.SET_CARDS)
        local page = ns.Board and ns.Board.page
        if page and page:IsVisible() then ns.Board:Decide(page:GetBrowseType()) end
    elseif command == "options" or command == "config" then
        if ns.Options and ns.Options.Open then ns.Options.Open() end
    elseif command == "debug" then
        settings.debug = not settings.debug
        Say(L.SET_DEBUG:format(settings.debug and "on" or "off"))
    else
        Say(L.HELP:format(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"))
    end
end
