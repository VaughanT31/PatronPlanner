-- Patron Planner - what each character's patron orders looked like the last
-- time their Patron tab was open. The game only lists orders for the
-- character at the crafting table, so this is a saved snapshot, never live:
-- it says how long ago it was seen, and expired orders drop out.
--
--   PatronPlannerDB.altOrders["Name-Realm"] = {
--     class = "MAGE",
--     professions = {
--       [profession] = { name, at, orders = { { name, icon, need, expires,
--                        profit, craftable, gold }, ... } }, ...
--     },
--   }

local _, ns = ...
local Util = ns.Util

local AltOrders = {}
ns.AltOrders = AltOrders

local function Store()
    ns.db.altOrders = ns.db.altOrders or {}
    return ns.db.altOrders
end

local function OpenProfession()
    local ok, info = pcall(C_TradeSkillUI.GetChildProfessionInfo)
    if not (ok and info) then return nil end
    return Util.Clean(info.profession), Util.Clean(info.parentProfessionName) or Util.Clean(info.professionName)
end

-- A fresh Patron list for the open profession, empty ones included.
function AltOrders.Save(records)
    if not ns.db then return end
    local profession, name = OpenProfession()
    if not profession then return end
    local key = (UnitName("player") or "?") .. "-" .. (GetNormalizedRealmName() or "?")
    local character = Store()[key] or { professions = {} }
    Store()[key] = character
    character.class = select(2, UnitClass("player"))

    local now = GetServerTime()
    local orders = {}
    for _, rec in ipairs(records) do
        orders[#orders + 1] = {
            name = rec.name,
            icon = rec.icon,
            need = rec.need,
            expires = now + math.max(0, rec.left or 0),
            profit = rec.profit,
            gold = rec.gold,
            craftable = (rec.reachable and rec.learned) or false,
        }
    end
    character.professions[profession] = { name = name, at = now, orders = orders }
end

local function SortOrders(a, b)
    if a.craftable ~= b.craftable then return a.craftable end
    return (a.profit or -math.huge) > (b.profit or -math.huge)
end

-- Every character with orders still open, the most profit first:
-- { { key, class, profit, professions = { { name, at, count, craftable,
--     profit, orders }, ... } }, ... }. Profit adds up orders you could
-- craft that make money.
function AltOrders.List()
    local now = GetServerTime()
    local list = {}
    for key, character in pairs(ns.db and Store() or {}) do
        local row = { key = key, class = character.class, profit = 0, professions = {} }
        for _, saved in pairs(character.professions or {}) do
            local open = {}
            local craftable, profit = 0, 0
            for _, order in ipairs(saved.orders or {}) do
                if (order.expires or 0) > now then
                    open[#open + 1] = order
                    if order.craftable then
                        craftable = craftable + 1
                        if order.profit and order.profit > 0 then profit = profit + order.profit end
                    end
                end
            end
            if #open > 0 then
                table.sort(open, SortOrders)
                row.professions[#row.professions + 1] = {
                    name = saved.name, at = saved.at, count = #open,
                    craftable = craftable, profit = profit, orders = open,
                }
                row.profit = row.profit + profit
            end
        end
        if #row.professions > 0 then
            table.sort(row.professions, function(a, b) return a.profit > b.profit end)
            list[#list + 1] = row
        end
    end
    table.sort(list, function(a, b)
        if a.profit ~= b.profit then return a.profit > b.profit end
        return a.key < b.key
    end)
    return list
end
