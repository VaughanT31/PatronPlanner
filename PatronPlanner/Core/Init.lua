-- Patron Planner - bootstrap: SavedVariables and the slash command.
--
--   PatronPlannerDB = {
--     version  = DB_VERSION,
--     settings = { ... },        see DEFAULTS
--     queues   = { ["Name-Realm"] = { ... } },   Data/Queue.lua
--     knowledge = { child, chars },               Data/Knowledge.lua
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
        -- Values panel: gold per concentration point (0 = not counted), and
        -- gold per point of a currency reward such as Moxie, by currency ID.
        concValue = 0,
        currencyValues = {},
        -- Gold per unpriced reward item (knowledge, payout bags), by item ID.
        itemValues = {},
        -- Minimap button.
        minimapHidden = false,
        minimapAngle = 200,
        -- Queue panel closed with its X (it shows with Crafting Orders).
        queueHidden = false,
        -- Queue all options.
        queueSkipConc = false,
        queueSkipBuy = false,
        queueConcLimit = true,
        -- Knowledge window: professions folded away, by base skill line.
        -- (kpPinned, kpHideDone and kpPos are set as the player uses it.)
        kpCollapsed = {},
        debug = false,
    },
    queues = {},
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
    if ns.MinimapButton then ns.MinimapButton.Refresh() end
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
    elseif command == "queue" then
        if ns.QueuePanel then ns.QueuePanel:Toggle() end
    elseif command == "shop" or command == "shopping" then
        if ns.ShoppingList then ns.ShoppingList:Toggle() end
    elseif command == "knowledge" or command == "kp" then
        if ns.KnowledgeWindow then ns.KnowledgeWindow:Toggle() end
    elseif command == "kpscan" then
        -- Not in the help: finds the hidden weekly knowledge quests in game.
        if ns.KnowledgeWindow then ns.KnowledgeWindow:ShowScan() end
    elseif command == "minimap" then
        if ns.MinimapButton then ns.MinimapButton.Toggle() end
    elseif command == "debug" then
        settings.debug = not settings.debug
        Say(L.SET_DEBUG:format(settings.debug and "on" or "off"))
    else
        Say(L.HELP:format(C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"))
    end
end
