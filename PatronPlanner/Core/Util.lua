-- Patron Planner - small helpers: money and time text, colours, quality
-- icons, and a guard for Midnight's secret values.

local _, ns = ...
local L = ns.L

local Util = {}
ns.Util = Util

-- Midnight can hand addons "secret" values that error when compared or
-- printed. Anything read from the game goes through here first.
function Util.Clean(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

Util.COLOR = {
    green = { 0.35, 0.85, 0.45 },
    amber = { 1.00, 0.70, 0.20 },
    red = { 1.00, 0.32, 0.32 },
    grey = { 0.55, 0.55, 0.55 },
    gold = { 1.00, 0.82, 0.00 },
    white = { 0.95, 0.95, 0.95 },
    blue = { 0.40, 0.75, 1.00 },
}

function Util.Paint(colorName, text)
    local c = Util.COLOR[colorName] or Util.COLOR.white
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), text)
end

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"

-- 1,286g in the list (gold only, rounded); full gold, silver and copper
-- when asked or when it's under 1 gold.
function Util.Money(copper, full)
    if not copper then return "?" end
    local negative = copper < 0
    copper = math.abs(math.floor(copper + 0.5))
    local text
    if full or copper < 10000 then
        text = GetMoneyString(copper, true)
    else
        text = BreakUpLargeNumbers(math.floor(copper / 10000 + 0.5)) .. GOLD_ICON
    end
    return negative and ("-" .. text) or text
end

function Util.TimeLeft(seconds)
    if not seconds or seconds <= 0 then return L.TIME_EXPIRED end
    if seconds >= 86400 then return L.TIME_DAYS:format(math.floor(seconds / 86400)) end
    if seconds >= 3600 then return L.TIME_HOURS:format(math.floor(seconds / 3600)) end
    return L.TIME_MINUTES:format(math.max(1, math.floor(seconds / 60)))
end

-- Under 2 hours red, amber inside the "expiring soon" setting (6 hours).
function Util.TimeColor(seconds)
    if not seconds or seconds < 7200 then return "red" end
    local soon = (ns.db and ns.db.settings.soonHours or 6) * 3600
    if seconds < soon then return "amber" end
    return "grey"
end

-- The crafting quality pip, as inline markup. Atlas names changed between
-- expansions, so the first one the client knows wins.
local qualityAtlas = {}
function Util.QualityIcon(quality, size)
    if not quality or quality < 1 then return "" end
    size = size or 14
    if qualityAtlas[quality] == nil then
        qualityAtlas[quality] = false
        for _, name in ipairs({
            "Professions-ChatIcon-Quality-12-Tier" .. quality,
            "Professions-ChatIcon-Quality-Tier" .. quality,
            "Professions-Icon-Quality-Tier" .. quality .. "-Small",
        }) do
            if C_Texture.GetAtlasInfo(name) then
                qualityAtlas[quality] = name
                break
            end
        end
    end
    local atlas = qualityAtlas[quality]
    if not atlas then return L.QUALITY_SHORT:format(quality) end
    return CreateAtlasMarkup(atlas, size, size)
end

-- 1px backdrop edges can vanish when a frame lands between screen pixels
-- (UI scale, or a width built from text). Unsnapped edges always draw.
local EDGES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }
function Util.CrispEdges(frame)
    for _, key in ipairs(EDGES) do
        local edge = frame[key]
        if type(edge) == "table" and edge.SetSnapToPixelGrid then
            edge:SetSnapToPixelGrid(false)
            edge:SetTexelSnappingBias(0)
        end
    end
end

function Util.RarityColor(rarity)
    local c = rarity and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[rarity]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

function Util.Debug(...)
    if ns.db and ns.db.settings.debug then
        print("|cff7fbfffPatron Planner|r", ...)
    end
end
