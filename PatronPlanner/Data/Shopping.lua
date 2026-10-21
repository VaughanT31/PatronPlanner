-- Patron Planner - what the queued orders still need, counted once across
-- the whole queue (what you own is shared out, not counted per order), and
-- sending it on:
--   Auction Coach   AuctionCoachAPI.AddToShoppingList (Auction Coach 0.15+):
--                   it watches the AH and says when each one is cheap
--   Auctionator     a shopping list named "Patron Planner"
-- Without either, Patron Planner's own list window is the shopping list.

local _, ns = ...
local L, Util, Orders, Pricing, Queue = ns.L, ns.Util, ns.Orders, ns.Pricing, ns.Queue

local Shopping = {}
ns.Shopping = Shopping

local CALLER = "PatronPlanner"
local LIST_NAME = "Patron Planner"
-- The most to pay: this much over the usual price.
local MAX_OVER = 1.10

-- { { itemID, name, quality, total, have, need, price }, ... } sorted by
-- what's left to buy, then name.
function Shopping.Items()
    local byItem, order = {}, {}
    for _, entry in ipairs(Queue.List()) do
        local rec = Queue.recs[entry.key]
        for _, item in ipairs((rec and rec.supply) or entry.supply or {}) do
            local row = byItem[item.itemID]
            if not row then
                row = { itemID = item.itemID, name = item.name, quality = item.quality, total = 0 }
                byItem[item.itemID] = row
                order[#order + 1] = row
            end
            row.total = row.total + (item.count or 1)
            row.name = row.name or item.name
        end
    end
    for _, row in ipairs(order) do
        row.name = row.name or C_Item.GetItemNameByID(row.itemID)
        row.have = Orders.Owned(row.itemID)
        row.need = math.max(0, row.total - row.have)
        row.price = Pricing.Price(row.itemID)
    end
    table.sort(order, function(a, b)
        if (a.need > 0) ~= (b.need > 0) then return a.need > 0 end
        return (a.name or "") < (b.name or "")
    end)
    return order
end

-- How many items are left to buy, and what they cost (nil when nothing
-- has a price).
function Shopping.Summary(items)
    items = items or Shopping.Items()
    local count, cost, priced = 0, 0, false
    for _, row in ipairs(items) do
        if row.need > 0 then
            count = count + 1
            if row.price then cost, priced = cost + row.price * row.need, true end
        end
    end
    return count, priced and cost or nil
end

-- Auction Coach ---------------------------------------------------------

function Shopping.HasAuctionCoach()
    return AuctionCoachAPI ~= nil and type(AuctionCoachAPI.AddToShoppingList) == "function"
end

function Shopping.ToAuctionCoach()
    if not Shopping.HasAuctionCoach() then return end
    local added, unpriced = 0, 0
    for _, row in ipairs(Shopping.Items()) do
        if row.need > 0 then
            local usual = (AuctionCoachAPI.GetMarketValue and AuctionCoachAPI.GetMarketValue(row.itemID)) or row.price
            if usual and usual > 0 then
                local ok, done = pcall(AuctionCoachAPI.AddToShoppingList, row.itemID, row.need,
                    math.floor(usual * MAX_OVER), LIST_NAME)
                if ok and done then added = added + 1 else unpriced = unpriced + 1 end
            else
                unpriced = unpriced + 1
            end
        end
    end
    if added == 0 and unpriced == 0 then
        Util.Say(L.SHOP_NOTHING)
    else
        Util.Say(L.SHOP_SENT_AC:format(added) .. (unpriced > 0 and (" " .. L.SHOP_UNPRICED:format(unpriced)) or ""))
    end
end

-- Auctionator -----------------------------------------------------------

function Shopping.HasAuctionator()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    return api ~= nil and type(api.CreateShoppingList) == "function"
end

local function SearchString(row)
    local api = Auctionator.API.v1
    if type(api.ConvertToSearchString) == "function" then
        local ok, text = pcall(api.ConvertToSearchString, CALLER, {
            searchString = row.name,
            isExact = true,
            categoryKey = "",
            tier = (row.quality and row.quality > 0) and row.quality or nil,
            quantity = row.need,
        })
        if ok and type(text) == "string" then return text end
    end
    return '"' .. row.name .. '"'
end

function Shopping.ToAuctionator()
    if not Shopping.HasAuctionator() then return end
    local terms = {}
    for _, row in ipairs(Shopping.Items()) do
        if row.need > 0 and row.name then terms[#terms + 1] = SearchString(row) end
    end
    if #terms == 0 then
        Util.Say(L.SHOP_NOTHING)
        return
    end
    local ok, err = pcall(Auctionator.API.v1.CreateShoppingList, CALLER, LIST_NAME, terms)
    if ok then
        Util.Say(L.SHOP_SENT_AUCTIONATOR:format(#terms, LIST_NAME))
    else
        Util.Say(L.SHOP_FAILED:format(tostring(err)))
    end
end
