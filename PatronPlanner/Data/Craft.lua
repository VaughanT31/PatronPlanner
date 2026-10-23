-- Patron Planner - Claim > Craft > Submit for queued orders.
--
-- The game allows one claimed order at a time and needs you at the
-- profession's crafting table. Every step is a button press: the game only
-- crafts from a hardware click. After each press the buttons lock until
-- the game answers (or LOCK_TIMEOUT passes), so a double click can't claim
-- or craft twice.
--
-- The order of steps, the claimed-order checks (order IDs compared as
-- text, recrafts through RecraftRecipeForOrder, the result attached to the
-- claimed order) follow CraftSim's work order queue.
-- Adapted from CraftSim by Florian Schneider (MIT), see
-- ThirdParty/LICENSE-CraftSim.txt.

local _, ns = ...
local L, Util, Orders, Queue = ns.L, ns.Util, ns.Orders, ns.Queue

local Craft = {}
ns.Craft = Craft

local LOCK_TIMEOUT = 6
local lockedUntil = 0
local crafted = {}        -- key -> true once Craft was pressed, until submitted

local function Locked()
    return GetTime() < lockedUntil
end

local function Lock()
    lockedUntil = GetTime() + LOCK_TIMEOUT
    C_Timer.After(LOCK_TIMEOUT + 0.1, function()
        if ns.QueuePanel then ns.QueuePanel:Refresh() end
    end)
end

local function Unlock()
    lockedUntil = 0
    if ns.QueuePanel then ns.QueuePanel:Refresh() end
end

local function Claimed()
    local order = C_CraftingOrders.GetClaimedOrder()
    if order and order.orderID then return order, tostring(order.orderID) end
    return nil
end

local function OpenProfession()
    local ok, info = pcall(C_TradeSkillUI.GetChildProfessionInfo)
    return ok and info and Util.Clean(info.profession) or nil
end

local function AtTable(profession)
    local ok, near = pcall(C_TradeSkillUI.IsNearProfessionSpellFocus, profession)
    return ok and near == true
end

local function ProfessionName(profession)
    local ok, name = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, profession)
    return ok and name or "?"
end

-- What the row's button does now:
--   { action = "claim"|"craft"|"submit"|nil, label, enabled, why }
function Craft.Step(entry)
    local rec = Queue.recs[entry.key]
    local profession = entry.profession or (rec and rec.profession)
    local claimed, claimedKey = Claimed()
    local mine = claimed and claimedKey == entry.key

    if Locked() then return { label = L.STEP_WAIT, enabled = false } end
    if not ProfessionsFrame or not ProfessionsFrame:IsShown() or OpenProfession() ~= profession then
        return { label = L.STEP_OPEN, enabled = false, why = L.STEP_OPEN_WHY:format(ProfessionName(profession)) }
    end
    if not AtTable(profession) then
        return { label = L.STEP_TABLE, enabled = false, why = L.STEP_TABLE_WHY }
    end

    if mine then
        if Util.Clean(claimed.isFulfillable) then
            return { action = "submit", label = L.STEP_SUBMIT, enabled = true }
        end
        if crafted[entry.key] then return { label = L.STEP_WAIT, enabled = false } end
        if not rec then
            return { label = L.STEP_LIST, enabled = false, why = L.STEP_LIST_WHY }
        end
        local missing = Orders.Missing(rec)
        if #missing > 0 then
            local names = {}
            for _, item in ipairs(missing) do names[#names + 1] = item.need .. "x " .. (item.name or ("#" .. item.itemID)) end
            return { label = L.STEP_MATERIALS, enabled = false, why = table.concat(names, ", ") }
        end
        if not Orders.StillReaches(rec) then
            return { label = L.STEP_REACH, enabled = false, why = L.STEP_REACH_WHY }
        end
        return { action = "craft", label = L.STEP_CRAFT, enabled = true }
    end
    if claimed then
        return { label = L.STEP_BUSY, enabled = false, why = L.STEP_BUSY_WHY }
    end
    if entry.orderType == Enum.CraftingOrderType.Public and (Orders.ClaimsLeft(profession) or 1) <= 0 then
        return { label = L.STEP_NO_CLAIMS, enabled = false, why = L.STEP_NO_CLAIMS_WHY }
    end
    return { action = "claim", label = L.STEP_CLAIM, enabled = true }
end

local function Run(entry, step)
    local rec = Queue.recs[entry.key]
    local profession = entry.profession or (rec and rec.profession)
    local claimed = Claimed()
    if step.action == "claim" then
        -- The order ID as the game gave it (it can be a big number).
        local orderID = rec and rec.orderID or tonumber(entry.key)
        C_CraftingOrders.ClaimOrder(orderID, profession)
    elseif step.action == "craft" then
        local reagents, concentrating = Orders.CraftReagents(rec)
        crafted[entry.key] = true
        local ok, err
        if rec.isRecraft and claimed and claimed.outputItemGUID then
            ok, err = pcall(C_TradeSkillUI.RecraftRecipeForOrder, claimed.orderID, claimed.outputItemGUID,
                reagents, nil, concentrating)
        else
            ok, err = pcall(C_TradeSkillUI.CraftRecipe, rec.recipeID, 1, reagents, nil, claimed.orderID, concentrating)
        end
        if not ok then
            crafted[entry.key] = nil
            Util.Say(L.STEP_FAILED:format(tostring(err)))
            return
        end
    elseif step.action == "submit" then
        C_CraftingOrders.FulfillOrder(claimed.orderID, "", profession)
    end
    Lock()
end

-- Presses the row's button.
function Craft.Do(entry)
    local step = Craft.Step(entry)
    if not step.enabled or not step.action then return end
    Run(entry, step)
    if ns.QueuePanel then ns.QueuePanel:Refresh() end
end

-- Next: the first row with something to do, top down.
function Craft.Next()
    for _, entry in ipairs(Queue.List()) do
        local step = Craft.Step(entry)
        if step.enabled and step.action then
            Run(entry, step)
            if ns.QueuePanel then ns.QueuePanel:Refresh() end
            return entry, step
        end
    end
    return nil
end

-- The step the Next button would take, for its label.
function Craft.NextStep()
    for _, entry in ipairs(Queue.List()) do
        local step = Craft.Step(entry)
        if step.enabled and step.action then return step, entry end
    end
    return nil
end

-- Lets go of the claimed order (it goes back to the list).
function Craft.Release()
    local claimed = Claimed()
    if not claimed then return end
    local profession = OpenProfession()
    pcall(C_CraftingOrders.ReleaseOrder, claimed.orderID, profession)
    Lock()
end

function Craft.ClaimedKey()
    return select(2, Claimed())
end

-- The game's answers unlock the buttons.
local events = CreateFrame("Frame")
for _, event in ipairs({
    "CRAFTINGORDERS_CLAIM_ORDER_RESPONSE", "CRAFTINGORDERS_CLAIMED_ORDER_ADDED",
    "CRAFTINGORDERS_CLAIMED_ORDER_UPDATED", "CRAFTINGORDERS_CLAIMED_ORDER_REMOVED",
    "CRAFTINGORDERS_RELEASE_ORDER_RESPONSE", "CRAFTINGORDERS_FULFILL_ORDER_RESPONSE",
    "TRADE_SKILL_ITEM_CRAFTED_RESULT", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        if unit ~= "player" then return end
        -- The craft didn't happen: allow Craft again.
        local key = Craft.ClaimedKey()
        if key then crafted[key] = nil end
    elseif event == "CRAFTINGORDERS_FULFILL_ORDER_RESPONSE" then
        local result, orderID = ...
        local key = orderID and tostring(orderID)
        if key then crafted[key] = nil end
        if key and (result == 0 or (Enum.CraftingOrderResult and result == Enum.CraftingOrderResult.Ok)) then
            Queue.Remove(key)
            -- Show what's left on the tab.
            if ns.Board then ns.Board:RequestAgain(key) end
        end
    elseif event == "CRAFTINGORDERS_CLAIMED_ORDER_REMOVED" then
        wipe(crafted)
    end
    Unlock()
end)
