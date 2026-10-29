-- Patron Planner - turns each crafting order (patron, personal, guild or
-- public) into one record the cards can show: reward, what you supply and
-- its cost, profit, quality reach, time left, and the plan the queue's
-- Craft button follows.
--
--   rec = {
--     order, orderID, key (orderID as text), recipeID, name, icon, rarity,
--     learned, left, orderType, isPatron, customer, note, profession,
--     gold          commission after the consortium cut (copper)
--     rewards       { { icon, count, name, value, bonus, currencyID, itemID,
--                       firstCraft }, ... }
--     rewardValue   gold + priced reward items (after the AH cut) + rewards
--                   the player gave a value (Values panel)
--     bonus         true when a reward is soulbound or a currency
--     supply        { { itemID, icon, count, name, price, have, owned,
--                       quality, slot }, ... } you provide
--     cost          what the supply is worth, nil when nothing is priced
--     buyCost       what the part you don't own costs
--     fromStock     true when you own everything you'd supply
--     need          requested quality (0 or 1 means any)
--     reach         "any" | "cheap" | "conc" | "better" | "betterConc" |
--                   "none" | "unknown" | "unlearned"
--     plan          { high = bool, conc = bool } the materials and
--                   concentration the reach was found with
--     concCost      concentration the plan needs, when it needs any
--     concAvg       concCost after Ingenuity's average refund
--     concWorth     what concAvg is worth at the player's gold per point
--     profit        nil when it can't be worked out; concWorth is taken off
--     perConc       profit per concentration point before concWorth
--     partial       true when some prices were missing
--   }

local _, ns = ...
local Util, Pricing, Reference = ns.Util, ns.Pricing, ns.Reference

local Orders = {}
ns.Orders = Orders

local BIND_ON_PICKUP = 1
-- Reward items are worth what they sell for after the AH's 5% cut.
local AH_CUT = 0.95
local COPPER_PER_GOLD = 10000

local function Gold(value)
    local gold = tonumber(value)
    if gold and gold > 0 then return gold * COPPER_PER_GOLD end
    return nil
end

-- The player's gold value for one of a currency (Moxie), or nil.
function Orders.CurrencyValue(currencyID)
    local values = ns.db and ns.db.settings.currencyValues
    return values and Gold(values[currencyID])
end

-- The player's gold value for one of an unpriced reward item (knowledge,
-- payout bags), or nil.
function Orders.ItemValue(itemID)
    local values = ns.db and ns.db.settings.itemValues
    return values and Gold(values[itemID])
end

-- The player's gold value for one concentration point, or nil.
function Orders.ConcentrationValue()
    return ns.db and Gold(ns.db.settings.concValue)
end

-- What one Moxie is worth from its surplus bag at AH prices, after the
-- cut, or nil when the bag or its prices aren't known.
function Orders.MoxieEstimate(currencyID)
    local bag = Reference.SURPLUS_BAGS[currencyID]
    if not bag then return nil end
    local total = 0
    for _, entry in ipairs(bag) do
        local price = Pricing.Price(entry[1])
        if price then total = total + price * entry[2] end
    end
    if total <= 0 then return nil end
    return total * AH_CUT / Reference.SURPLUS_BAG_MOXIE
end

local function ItemIDFromLink(link)
    if not link then return nil end
    return (C_Item.GetItemInfoInstant(link))
end

-- How many you have in bags, bank, reagent bank and warband bank. The
-- bank counts are the game's cache from your last bank visit.
function Orders.Owned(itemID)
    local ok, count = pcall(C_Item.GetItemCount, itemID, true, false, true, true)
    return ok and count or 0
end
local Owned = Orders.Owned

local function ItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if not name then C_Item.RequestLoadItemDataByID(itemID) end
    return name
end

-- Reagent options in a slot, lowest crafting quality first. quality 0
-- means the item has no qualities.
local function SortedOptions(slot)
    local options = {}
    for _, reagent in ipairs(slot.reagents or {}) do
        if reagent.itemID then
            local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(reagent.itemID) or 0
            options[#options + 1] = { reagent = reagent, quality = quality }
        end
    end
    table.sort(options, function(a, b) return a.quality < b.quality end)
    return options
end

-- Slots you fill yourself: required, not supplied by the customer, and
-- not one the game fills automatically.
local function SupplySlots(order, schematic)
    local provided = {}
    for _, reagent in ipairs(order.reagents or {}) do
        provided[reagent.slotIndex] = true
    end
    local slots = {}
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        if slot.required and not provided[slot.slotIndex]
            and slot.reagentType ~= Enum.CraftingReagentType.Automatic then
            local options = SortedOptions(slot)
            if #options > 0 then
                slots[#slots + 1] = { slot = slot, options = options }
            end
        end
    end
    return slots
end

local function IsBasic(slot)
    return slot.reagentType == Enum.CraftingReagentType.Basic
end

-- The option a slot uses: basic slots the lowest or highest quality,
-- other required slots (sparks and the like) the cheapest.
local function Pick(entry, high)
    if IsBasic(entry.slot) then
        return high and entry.options[#entry.options] or entry.options[1]
    end
    local best, cheapest
    for _, candidate in ipairs(entry.options) do
        local price = Pricing.Price(candidate.reagent.itemID)
        if price and (not cheapest or price < cheapest) then
            cheapest, best = price, candidate
        end
    end
    -- Nothing priced: one you own, else the first.
    if not best then
        for _, candidate in ipairs(entry.options) do
            if Owned(candidate.reagent.itemID) >= (entry.slot.quantityRequired or 1) then return candidate end
        end
    end
    return best or entry.options[1]
end

-- Your materials for a craft at the lowest or highest quality. Only
-- materials that come in qualities go in: the game fills in the rest
-- itself, and adding them makes its quality answer come back empty.
-- forCraft also adds the other required slots you fill (sparks).
local function YourReagents(slots, high, forCraft)
    local list = {}
    for _, entry in ipairs(slots) do
        local option = Pick(entry, high)
        if (IsBasic(entry.slot) and option.quality > 0) or (forCraft and not IsBasic(entry.slot)) then
            list[#list + 1] = {
                reagent = { itemID = option.reagent.itemID },
                dataSlotIndex = entry.slot.dataSlotIndex,
                quantity = entry.slot.quantityRequired or 1,
            }
        end
    end
    return list
end

-- The customer's reagents plus yours, for asking the game about quality.
-- Only materials that come in qualities, like YourReagents: the customer's
-- Spark (every patron and personal order with one supplies it) made the
-- game's answer come back empty. everything adds the rest of both.
local function Reagents(order, slots, high, everything)
    local list = {}
    for _, reagent in ipairs(order.reagents or {}) do
        local info = reagent.reagentInfo
        local itemID = info and info.reagent and info.reagent.itemID
        if info and (everything or (itemID and (C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID) or 0) > 0)) then
            list[#list + 1] = info
        end
    end
    for _, item in ipairs(YourReagents(slots, high, everything)) do list[#list + 1] = item end
    return list
end

local function Ask(order, reagents, concentration)
    local ok, info = pcall(C_TradeSkillUI.GetCraftingOperationInfoForOrder,
        order.spellID, reagents, order.orderID, concentration)
    if ok then return info end
    return nil
end

-- Which quality a craft reaches with the low or high materials: asked with
-- the quality materials only, then, when that comes back empty, with
-- every material in.
local function Operation(order, slots, high, concentration)
    local info = Ask(order, Reagents(order, slots, high, false), concentration)
    if info then return info end
    return Ask(order, Reagents(order, slots, high, true), concentration)
end

-- Ingenuity's chance (0 to 1) from the game's stat list, or 0.
local function IngenuityChance(info)
    local name = Reference.INGENUITY[GetLocale()] or Reference.INGENUITY.enUS
    for _, stat in ipairs(info and info.bonusStats or {}) do
        local statName = Util.Clean(stat.bonusStatName)
        if statName and statName:lower() == name:lower() then
            local pct = Util.Clean(stat.ratingPct)
            return (tonumber(pct) or 0) / 100
        end
    end
    return 0
end

local function UseConcentration(rec, info)
    rec.concCost = Util.Clean(info.concentrationCost)
    if rec.concCost and rec.concCost > 0 then
        local chance = IngenuityChance(info)
        rec.ingenuity = chance
        rec.concAvg = rec.concCost * (1 - chance * Reference.INGENUITY_REFUND)
    end
end

-- Can the order reach its quality with cheap materials, with
-- concentration, with the best materials, or not at all? Sets rec.plan.
local function Reach(rec, order, slots)
    if not rec.learned then return "unlearned" end
    rec.plan = { high = false, conc = false }
    local info = Operation(order, slots, false, false)
    if info then rec.concentrationID = Util.Clean(info.concentrationCurrencyID) end
    if rec.need <= 1 then return "any" end
    -- The game didn't answer: say so rather than guess.
    if not info then return "unknown" end
    if not info.isQualityCraft then return "any" end
    if info.craftingQuality >= rec.need then return "cheap" end

    local withConc = Operation(order, slots, false, true)
    if withConc and withConc.craftingQuality >= rec.need then
        rec.plan.conc = true
        UseConcentration(rec, withConc)
        return "conc"
    end
    local best = Operation(order, slots, true, false)
    if best and best.craftingQuality >= rec.need then
        rec.plan.high = true
        return "better"
    end
    local bestConc = Operation(order, slots, true, true)
    if bestConc and bestConc.craftingQuality >= rec.need then
        rec.plan.high, rec.plan.conc = true, true
        UseConcentration(rec, bestConc)
        return "betterConc"
    end
    return "none"
end

-- A reward entry for a currency, valued when the player gave it a value.
local function CurrencyEntry(rec, currencyID, count)
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    local entry = {
        count = count, currencyID = currencyID, bonus = true,
        icon = info and info.iconFileID, name = info and info.name,
    }
    local each = Orders.CurrencyValue(currencyID)
    if each then
        entry.value = each * count
        rec.rewardValue = rec.rewardValue + entry.value
    end
    return entry
end

local function Rewards(rec, order)
    rec.rewards, rec.rewardValue = {}, rec.gold
    local moxieEntry
    for _, reward in ipairs(order.npcOrderRewards or {}) do
        local entry
        if reward.itemLink then
            entry = { count = reward.count or 1 }
            local itemID = ItemIDFromLink(reward.itemLink)
            entry.itemID = itemID
            entry.link = reward.itemLink
            entry.icon = itemID and C_Item.GetItemIconByID(itemID)
            entry.name = itemID and ItemName(itemID)
            local bindType = select(14, C_Item.GetItemInfo(reward.itemLink))
            local soulbound = bindType == BIND_ON_PICKUP
            local price = not soulbound and Pricing.Price(itemID)
            local own = itemID and Orders.ItemValue(itemID)
            if price then
                entry.value = math.floor(price * AH_CUT) * entry.count
            elseif own then
                entry.value = own * entry.count
            elseif not soulbound and Pricing.Available() then
                rec.partial = true
            end
            entry.bonus = soulbound
            -- Unpriced items can be given a value in the Values panel.
            entry.valuable = not price
            if entry.value then rec.rewardValue = rec.rewardValue + entry.value end
        elseif reward.currencyType then
            entry = CurrencyEntry(rec, reward.currencyType, reward.count or 1)
            if entry.currencyID == rec.moxieID then moxieEntry = entry end
        end
        if entry then
            rec.bonus = rec.bonus or entry.bonus
            rec.rewards[#rec.rewards + 1] = entry
        end
    end
    -- A recipe's first craft for a patron pays extra Moxie, which the
    -- order's reward list doesn't include.
    if rec.isPatron and rec.firstCraft and rec.moxieID then
        local extra = Reference.FIRST_CRAFT_MOXIE
        if moxieEntry then
            moxieEntry.count = moxieEntry.count + extra
            moxieEntry.firstCraft = extra
            local each = Orders.CurrencyValue(rec.moxieID)
            if each then
                moxieEntry.value = (moxieEntry.value or 0) + each * extra
                rec.rewardValue = rec.rewardValue + each * extra
            end
        else
            local entry = CurrencyEntry(rec, rec.moxieID, extra)
            entry.firstCraft = extra
            rec.bonus = true
            rec.rewards[#rec.rewards + 1] = entry
        end
    end
end

-- What you supply, priced at the quality the plan uses.
local function Supply(rec, slots)
    local high = rec.plan and rec.plan.high
    rec.supply = {}
    local cost, buyCost, priced = 0, 0, false
    local allOwned = true
    for _, entry in ipairs(slots) do
        local count = entry.slot.quantityRequired or 1
        local option = Pick(entry, high)
        local itemID = option.reagent.itemID
        local price = Pricing.Price(itemID)
        local have = Owned(itemID)
        local owned = math.min(have, count)
        if owned < count then allOwned = false end
        rec.supply[#rec.supply + 1] = {
            have = have,
            owned = owned,
            itemID = itemID,
            icon = C_Item.GetItemIconByID(itemID),
            count = count,
            name = ItemName(itemID),
            quality = option.quality,
            price = price and price * count,
        }
        if price then
            cost, priced = cost + price * count, true
            buyCost = buyCost + price * (count - owned)
        elseif Pricing.Available() then
            rec.partial = true
        end
    end
    rec.fromStock = #rec.supply > 0 and allOwned
    if #rec.supply == 0 then
        rec.cost, rec.buyCost = 0, 0
    elseif priced then
        rec.cost, rec.buyCost = cost, buyCost
    end
end

local function Profession(recipeID)
    local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
    return ok and info and Util.Clean(info.profession) or nil
end

function Orders.Evaluate(order, now)
    local recipe = C_TradeSkillUI.GetRecipeInfo(order.spellID)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(order.spellID, order.isRecraft and true or false)
    local orderType = Util.Clean(order.orderType)
    local rec = {
        order = order,
        orderID = order.orderID,
        key = tostring(order.orderID),
        orderType = orderType,
        isPatron = orderType == Enum.CraftingOrderType.Npc,
        recipeID = order.spellID,
        itemID = order.itemID,
        name = (recipe and recipe.name) or (schematic and schematic.name) or "?",
        icon = C_Item.GetItemIconByID(order.itemID) or (recipe and recipe.icon),
        rarity = C_Item.GetItemQualityByID(order.itemID),
        learned = recipe and recipe.learned or false,
        firstCraft = recipe and recipe.firstCraft or false,
        left = (Util.Clean(order.expirationTime) or now) - now,
        gold = (Util.Clean(order.tipAmount) or 0) - (Util.Clean(order.consortiumCut) or 0),
        need = Util.Clean(order.minQuality) or 0,
        customer = Util.Clean(order.customerName),
        note = Util.Clean(order.customerNotes),
        isRecraft = order.isRecraft or order.outputItemGUID ~= nil,
    }
    if rec.note == "" then rec.note = nil end
    rec.profession = Profession(order.spellID)
    rec.moxieID = rec.profession and Reference.MOXIE_BY_PROFESSION[rec.profession]

    local slots = SupplySlots(order, schematic)
    rec.slots = slots
    rec.reach = Reach(rec, order, slots)
    Rewards(rec, order)
    Supply(rec, slots)

    -- Materials you own count at their market value (you could sell them
    -- instead), unless the player chose to count them as free.
    local ownedFree = ns.db and ns.db.settings.ownedFree
    if Pricing.Available() then
        local spend = ownedFree and rec.buyCost or rec.cost
        if spend then rec.profit = rec.rewardValue - spend end
    elseif #rec.supply == 0 then
        -- No price addon, but nothing to buy: the gold (and any reward the
        -- player gave a value) is the profit.
        rec.profit = rec.rewardValue
        rec.partial = #rec.rewards > 0 and not rec.bonus
    end
    local conc = rec.concAvg or rec.concCost
    if rec.profit and conc and conc > 0 then
        rec.perConc = rec.profit / conc
        -- Concentration spent here can't be spent on another craft, so
        -- when the player says what a point is worth, that comes off.
        local each = Orders.ConcentrationValue()
        if each then
            rec.concWorth = each * conc
            rec.profit = rec.profit - rec.concWorth
        end
    end
    rec.reachable = rec.reach ~= "none" and rec.reach ~= "unlearned"
    rec.nothingToBuy = rec.reachable and (#rec.supply == 0 or rec.fromStock)
    return rec
end

-- The materials list to craft this order with its plan: only yours, the
-- customer's are added by the game. Returns list, concentration.
function Orders.CraftReagents(rec)
    local high = rec.plan and rec.plan.high
    return YourReagents(rec.slots or {}, high, true), rec.plan and rec.plan.conc or false
end

-- Does the plan still reach the quality right now? (Asked just before
-- crafting, with the exact list that will be used.)
function Orders.StillReaches(rec)
    if rec.need <= 1 then return true end
    local info = Operation(rec.order, rec.slots or {}, rec.plan and rec.plan.high or false, rec.plan and rec.plan.conc or false)
    -- Still no answer, either way: don't block the craft on that.
    -- The card already said "Not sure", and the game checks the craft itself.
    if not info then
        Util.Debug("no quality answer for order", rec.orderID, "recipe", rec.recipeID)
        return true
    end
    Util.Debug("order", rec.orderID, "reaches", info.craftingQuality, "needs", rec.need)
    return not info.isQualityCraft or info.craftingQuality >= rec.need
end

-- What's still missing to craft it: { { itemID, name, need }, ... }.
function Orders.Missing(rec)
    local missing = {}
    for _, item in ipairs(rec.supply or {}) do
        local have = Owned(item.itemID)
        if have < item.count then
            missing[#missing + 1] = { itemID = item.itemID, name = item.name, need = item.count - have }
        end
    end
    return missing
end

-- Rewards can arrive after the order (CRAFTINGORDERS_UPDATE_REWARDS).
local lateRewards = {}
function Orders.SetRewards(orderID, rewards)
    if orderID and type(rewards) == "table" then lateRewards[orderID] = rewards end
end

-- Every order Blizzard has handed us for the tab on screen, evaluated.
function Orders.All()
    local now = GetServerTime()
    local list = {}
    for _, order in ipairs(C_CraftingOrders.GetCrafterOrders() or {}) do
        if lateRewards[order.orderID] and #(order.npcOrderRewards or {}) == 0 then
            order.npcOrderRewards = lateRewards[order.orderID]
        end
        local ok, rec = pcall(Orders.Evaluate, order, now)
        if ok then
            list[#list + 1] = rec
        else
            Util.Debug("could not read order", order.orderID, rec)
        end
    end
    return list
end

-- Rewards the player can give a value (Moxie and other currencies, and
-- unpriced items like knowledge), for the Values panel:
-- { { kind = "currency"|"item", id, name, icon }, ... } in the order first seen.
function Orders.Valuables(list)
    local seen, out = {}, {}
    for _, rec in ipairs(list or {}) do
        for _, reward in ipairs(rec.rewards or {}) do
            local kind, id
            if reward.currencyID then
                kind, id = "currency", reward.currencyID
            elseif reward.itemID and reward.valuable then
                kind, id = "item", reward.itemID
            end
            if id and not seen[kind .. id] then
                seen[kind .. id] = true
                out[#out + 1] = { kind = kind, id = id, name = reward.name, icon = reward.icon }
            end
        end
    end
    return out
end

-- Current and most concentration for the profession, and its currency
-- ID, from any record that found its currency.
function Orders.Concentration(list)
    for _, rec in ipairs(list or {}) do
        if rec.concentrationID then
            local info = C_CurrencyInfo.GetCurrencyInfo(rec.concentrationID)
            if info then return info.quantity, info.maxQuantity, rec.concentrationID end
        end
    end
    return nil
end

-- Public order claims left today, or nil.
function Orders.ClaimsLeft(profession)
    if not profession then return nil end
    local ok, info = pcall(C_CraftingOrders.GetOrderClaimInfo, profession)
    if ok and info then return Util.Clean(info.claimsRemaining) end
    return nil
end
