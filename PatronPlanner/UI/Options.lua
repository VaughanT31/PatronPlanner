-- Patron Planner - the options page (Esc > Options > AddOns, or /pp options).
-- Every change redraws the cards straight away.

local ADDON_NAME, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end

local category = Settings.RegisterVerticalLayoutCategory(L.ADDON_TITLE)

local function Changed()
    local board = ns.Board
    local page = board and board.page
    if page and page:IsVisible() then board:Decide(page:GetBrowseType()) end
end

local function Proxy(field, varType, name, default)
    return Settings.RegisterProxySetting(category, "PatronPlanner_" .. field, varType, name, default,
        function()
            local value = ns.db and ns.db.settings[field]
            if value == nil then return default end
            return value
        end,
        function(value)
            ns.db.settings[field] = value
            Changed()
        end)
end

local function Header(text)
    if CreateSettingsListSectionHeaderInitializer and SettingsPanel then
        local layout = SettingsPanel:GetLayout(category)
        if layout then layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text)) end
    end
end

local function Checkbox(field, name, tooltip, default)
    Settings.CreateCheckbox(category, Proxy(field, Settings.VarType.Boolean, name, default), tooltip)
end

local function Slider(field, name, tooltip, default, min, max, step, label)
    local options = Settings.CreateSliderOptions(min, max, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, label)
    Settings.CreateSlider(category, Proxy(field, Settings.VarType.Number, name, default), options, tooltip)
end

local function Dropdown(field, name, tooltip, default, choices)
    if not (Settings.CreateDropdown and Settings.CreateControlTextContainer) then return end
    local function Choices()
        local container = Settings.CreateControlTextContainer()
        for _, choice in ipairs(choices()) do container:Add(choice[1], choice[2]) end
        return container:GetData()
    end
    Settings.CreateDropdown(category, Proxy(field, Settings.VarType.String, name, default), Choices, tooltip)
end

-- Price sources, marking the ones that aren't installed.
local function SourceChoices()
    local list = { { "auto", L.OPT_SOURCE_AUTO } }
    for _, source in ipairs(ns.Pricing.Sources()) do
        local label = source.available() and source.name or L.OPT_NOT_INSTALLED:format(source.name)
        list[#list + 1] = { source.key, label }
    end
    return list
end

Header(L.OPT_PRICES)
Dropdown("priceSource", L.OPT_SOURCE, L.OPT_SOURCE_TIP, "auto", SourceChoices)
Checkbox("ownedFree", L.OPT_OWNED_FREE, L.OPT_OWNED_FREE_TIP, false)
Checkbox("showCopper", L.OPT_COPPER, L.OPT_COPPER_TIP, false)

Header(L.OPT_VIEW)
Checkbox("classic", L.OPT_CLASSIC, L.OPT_CLASSIC_TIP, false)
Slider("soonHours", L.OPT_SOON, L.OPT_SOON_TIP, 6, 2, 24, 1, function(hours) return L.OPT_HOURS:format(hours) end)

Settings.RegisterAddOnCategory(category)
Options.category = category

function Options.Open()
    Settings.OpenToCategory(category:GetID())
end
