-- Patron Planner - the order queue: orders the player picked to craft,
-- saved per character (orders belong to one character).
--
--   PatronPlannerDB.queues["Name-Realm"] = {
--     { key, recipeID, name, icon, orderType, need, expires, profit,
--       concCost, profession, added,
--       supply = { { itemID, count, quality, name }, ... } }, ...
--   }
--
-- Each entry keeps a snapshot, so the queue and its shopping list still
-- show after a reload or away from the profession window. The latest
-- evaluated record for each order is kept in memory (Queue.recs) for the
-- Craft step, which needs the order's reagent slots.

local _, ns = ...
local L, Util, Orders = ns.L, ns.Util, ns.Orders

local Queue = { recs = {} }
ns.Queue = Queue

local function CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetNormalizedRealmName() or "?")
end

function Queue.List()
    if not ns.db then return {} end
    ns.db.queues = ns.db.queues or {}
    local key = CharKey()
    ns.db.queues[key] = ns.db.queues[key] or {}
    return ns.db.queues[key]
end

local function Find(key)
    for index, entry in ipairs(Queue.List()) do
        if entry.key == key then return entry, index end
    end
    return nil
end

function Queue.Has(key)
    return Find(key) ~= nil
end

function Queue.Count()
    return #Queue.List()
end

local function Changed()
    if ns.QueuePanel then ns.QueuePanel:Refresh() end
    if ns.ShoppingList then ns.ShoppingList:Refresh() end
    if ns.Board and ns.Board.active then ns.Board:Layout() end
end

local function Snapshot(entry, rec)
    entry.recipeID = rec.recipeID
    entry.name = rec.name
    entry.icon = rec.icon
    entry.orderType = rec.orderType
    entry.need = rec.need
    entry.expires = GetServerTime() + math.max(0, rec.left or 0)
    entry.profit = rec.profit
    entry.concCost = rec.concCost
    entry.profession = rec.profession
    entry.customer = rec.customer
    entry.supply = {}
    for _, item in ipairs(rec.supply or {}) do
        entry.supply[#entry.supply + 1] = { itemID = item.itemID, count = item.count, quality = item.quality, name = item.name }
    end
end

-- Why an order can't be queued, or nil when it can.
function Queue.Refusal(rec)
    if not rec.learned then return L.QUEUE_WHY_UNLEARNED end
    if rec.reach == "none" then return L.QUEUE_WHY_REACH end
    if rec.left and rec.left <= 0 then return L.QUEUE_WHY_EXPIRED end
    return nil
end

function Queue.Add(rec)
    if Find(rec.key) or Queue.Refusal(rec) then return false end
    local entry = { key = rec.key, added = GetServerTime() }
    Snapshot(entry, rec)
    local list = Queue.List()
    list[#list + 1] = entry
    Queue.recs[rec.key] = rec
    Changed()
    return true
end

function Queue.Remove(key)
    local _, index = Find(key)
    if not index then return false end
    table.remove(Queue.List(), index)
    Queue.recs[key] = nil
    Changed()
    return true
end

function Queue.Toggle(rec)
    if Queue.Has(rec.key) then
        Queue.Remove(rec.key)
    else
        local why = Queue.Refusal(rec)
        if why then
            Util.Say(L.QUEUE_CANT:format(rec.name, why))
            return
        end
        Queue.Add(rec)
    end
end

function Queue.Clear()
    wipe(Queue.List())
    wipe(Queue.recs)
    Changed()
end

-- The profession the window has open (orders only list for that one).
local function OpenProfession()
    local ok, info = pcall(C_TradeSkillUI.GetChildProfessionInfo)
    return ok and info and Util.Clean(info.profession) or nil
end

-- New records for the tab on screen: refresh the snapshots of queued
-- orders, and drop queued orders that are gone. A full list (fresh, on the
-- patron, personal or guild tab) drops the orders of that type it no
-- longer has, for the open profession only: another profession's orders
-- aren't in this list. Public lists only show one item at a time, so
-- public orders are only dropped when they expire.
function Queue.Update(records, orderType, fresh)
    local byKey = {}
    for _, rec in ipairs(records) do byKey[rec.key] = rec end
    local list = Queue.List()
    local now = GetServerTime()
    local profession = records[1] and records[1].profession or OpenProfession()
    local changed = false
    for index = #list, 1, -1 do
        local entry = list[index]
        local rec = byKey[entry.key]
        if rec then
            Snapshot(entry, rec)
            Queue.recs[entry.key] = rec
        elseif (entry.expires or now + 1) <= now
            or (fresh and orderType and entry.orderType == orderType
                and orderType ~= Enum.CraftingOrderType.Public
                and profession and entry.profession == profession) then
            -- A claimed order leaves the list but isn't gone: keep it, and
            -- one being claimed too (the list can arrive before the claim).
            if not (ns.Craft and ns.Craft.Holds(entry.key)) then
                table.remove(list, index)
                Queue.recs[entry.key] = nil
                changed = true
            end
        end
    end
    if changed then Changed() elseif ns.QueuePanel then ns.QueuePanel:Refresh() end
end

-- Totals for the panel: count, profit, concentration.
function Queue.Totals()
    local profit, conc, priced = 0, 0, false
    local list = Queue.List()
    for _, entry in ipairs(list) do
        local rec = Queue.recs[entry.key]
        local p = rec and rec.profit or entry.profit
        if p then profit, priced = profit + p, true end
        conc = conc + ((rec and (rec.concAvg or rec.concCost)) or entry.concCost or 0)
    end
    return #list, priced and profit or nil, conc
end

-- Queue every order passing the board's filter that is reachable and
-- worth doing, best first, within the options. Returns how many were
-- added and a list of { reason, count } for the ones left out.
function Queue.AddAll(records)
    local settings = ns.db.settings
    local skipped, order = {}, {}
    local function Skip(reason)
        if not skipped[reason] then
            skipped[reason] = 0
            order[#order + 1] = reason
        end
        skipped[reason] = skipped[reason] + 1
    end

    local have = Orders.Concentration(records)
    local _, _, queuedConc = Queue.Totals()
    local concLeft = have and (have - queuedConc) or nil
    local claims
    local added = 0
    for _, rec in ipairs(records) do
        if not Queue.Has(rec.key) then
            local why = Queue.Refusal(rec)
            local conc = rec.concAvg or rec.concCost or 0
            if why then
                Skip(why)
            elseif rec.profit and rec.profit <= 0 then
                Skip(L.QUEUE_WHY_LOSS)
            elseif settings.queueSkipConc and conc > 0 then
                Skip(L.QUEUE_WHY_CONC)
            elseif settings.queueSkipBuy and not rec.nothingToBuy then
                Skip(L.QUEUE_WHY_BUY)
            elseif settings.queueConcLimit and conc > 0 and concLeft and conc > concLeft then
                Skip(L.QUEUE_WHY_CONC_LEFT)
            else
                if rec.orderType == Enum.CraftingOrderType.Public then
                    claims = claims or Orders.ClaimsLeft(rec.profession) or 0
                end
                if rec.orderType == Enum.CraftingOrderType.Public and claims <= 0 then
                    Skip(L.QUEUE_WHY_CLAIMS)
                else
                    Queue.Add(rec)
                    added = added + 1
                    if conc > 0 and concLeft then concLeft = concLeft - conc end
                    if rec.orderType == Enum.CraftingOrderType.Public then claims = claims - 1 end
                end
            end
        end
    end
    local reasons = {}
    for _, reason in ipairs(order) do reasons[#reasons + 1] = { reason = reason, count = skipped[reason] } end
    return added, reasons
end
