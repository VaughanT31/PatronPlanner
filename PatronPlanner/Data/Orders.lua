-- Patron Planner - turns each patron order into one record the cards can
-- show: reward, what you supply and its cost, profit, quality reach and
-- time left.
--
--   rec = {
--     order, orderID, recipeID, name, icon, rarity, learned, left,
--     gold          commission after the consortium cut (copper)
--     rewards       { { icon, count, name, value, bonus }, ... }
--     rewardValue   gold + priced reward items
--     bonus         true when a reward is soulbound or a currency
--     supply        { { itemID, icon, count, name, price }, ... } you provide
--     cost          what the supply costs, nil when nothing is priced
--     need          requested quality (0 or 1 means any)
--     reach         "any" | "cheap" | "conc" | "better" | "betterConc" | "none" | "unlearned"
--     concCost      concentration the plan needs, when it needs any
--     profit        nil when it can't be worked out
--     partial       true when some prices were missing
--   }

local _, ns = ...
local Util, Pricing = ns.Util, ns.Pricing

local Orders = {}
ns.Orders = Orders

local BIND_ON_PICKUP = 1

local function ItemIDFromLink(link)
    if not link then return nil end
    return (C_Item.GetItemInfoInstant(link))
end

local function ItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if not name then C_Item.RequestLoadItemDataByID(itemID) end
    return name
end

-- Reagent options in a slot, lowest crafting quality first.
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

-- Slots you fill yourself: required, not supplied by the patron, and
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

-- The reagent list for a craft: the patron's reagents plus yours, at the
-- lowest or highest quality.
local function Reagents(order, slots, pick)
    local list = {}
    for _, reagent in ipairs(order.reagents or {}) do
        if reagent.reagentInfo then list[#list + 1] = reagent.reagentInfo end
    end
    for _, entry in ipairs(slots) do
        if entry.slot.reagentType == Enum.CraftingReagentType.Basic then
            local option = pick == "high" and entry.options[#entry.options] or entry.options[1]
            list[#list + 1] = {
                reagent = option.reagent,
                dataSlotIndex = entry.slot.dataSlotIndex,
                quantity = entry.slot.quantityRequired,
            }
        end
    end
    return list
end

local function Operation(order, reagents, concentration)
    local ok, info = pcall(C_TradeSkillUI.GetCraftingOperationInfoForOrder,
        order.spellID, reagents, order.orderID, concentration)
    if ok then return info end
    return nil
end

-- Can the order reach its quality with cheap materials, with
-- concentration, with the best materials, or not at all?
local function Reach(rec, order, slots)
    if not rec.learned then return "unlearned" end
    local low = Reagents(order, slots, "low")
    local info = Operation(order, low, false)
    if info then rec.concentrationID = info.concentrationCurrencyID end
    if rec.need <= 1 or not info or not info.isQualityCraft then return "any" end
    if info.craftingQuality >= rec.need then return "cheap" end

    local withConc = Operation(order, low, true)
    if withConc and withConc.craftingQuality >= rec.need then
        rec.concCost = withConc.concentrationCost
        return "conc"
    end
    local high = Reagents(order, slots, "high")
    local best = Operation(order, high, false)
    if best and best.craftingQuality >= rec.need then return "better" end
    local bestConc = Operation(order, high, true)
    if bestConc and bestConc.craftingQuality >= rec.need then
        rec.concCost = bestConc.concentrationCost
        return "betterConc"
    end
    return "none"
end

local function Rewards(rec, order)
    rec.rewards, rec.rewardValue = {}, rec.gold
    for _, reward in ipairs(order.npcOrderRewards or {}) do
        local entry = { count = reward.count or 1 }
        if reward.itemLink then
            local itemID = ItemIDFromLink(reward.itemLink)
            entry.itemID = itemID
            entry.link = reward.itemLink
            entry.icon = itemID and C_Item.GetItemIconByID(itemID)
            entry.name = itemID and ItemName(itemID)
            local price = Pricing.Price(itemID)
            if price then
                entry.value = price * entry.count
                rec.rewardValue = rec.rewardValue + entry.value
            else
                local bindType = select(14, C_Item.GetItemInfo(reward.itemLink))
                entry.bonus = bindType == BIND_ON_PICKUP
                if not entry.bonus and Pricing.Available() then rec.partial = true end
            end
        elseif reward.currencyType then
            local info = C_CurrencyInfo.GetCurrencyInfo(reward.currencyType)
            entry.icon = info and info.iconFileID
            entry.name = info and info.name
            entry.bonus = true
        end
        rec.bonus = rec.bonus or entry.bonus
        rec.rewards[#rec.rewards + 1] = entry
    end
end

-- What you supply, priced at the quality the plan uses.
local function Supply(rec, slots)
    local useHigh = rec.reach == "better" or rec.reach == "betterConc"
    rec.supply = {}
    local cost, priced = 0, false
    for _, entry in ipairs(slots) do
        local slot = entry.slot
        local count = slot.quantityRequired or 1
        local option
        if slot.reagentType == Enum.CraftingReagentType.Basic then
            option = useHigh and entry.options[#entry.options] or entry.options[1]
        else
            -- Several items fit this slot: count the cheapest.
            local cheapest
            for _, candidate in ipairs(entry.options) do
                local price = Pricing.Price(candidate.reagent.itemID)
                if price and (not cheapest or price < cheapest) then
                    cheapest, option = price, candidate
                end
            end
            option = option or entry.options[1]
        end
        local itemID = option.reagent.itemID
        local price = Pricing.Price(itemID)
        rec.supply[#rec.supply + 1] = {
            itemID = itemID,
            icon = C_Item.GetItemIconByID(itemID),
            count = count,
            name = ItemName(itemID),
            quality = option.quality,
            price = price and price * count,
        }
        if price then
            cost, priced = cost + price * count, true
        elseif Pricing.Available() then
            rec.partial = true
        end
    end
    if #rec.supply == 0 then
        rec.cost = 0
    elseif priced then
        rec.cost = cost
    end
end

function Orders.Evaluate(order, now)
    local recipe = C_TradeSkillUI.GetRecipeInfo(order.spellID)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(order.spellID, order.isRecraft and true or false)
    local rec = {
        order = order,
        orderID = order.orderID,
        recipeID = order.spellID,
        itemID = order.itemID,
        name = (recipe and recipe.name) or (schematic and schematic.name) or "?",
        icon = C_Item.GetItemIconByID(order.itemID) or (recipe and recipe.icon),
        rarity = C_Item.GetItemQualityByID(order.itemID),
        learned = recipe and recipe.learned or false,
        left = (Util.Clean(order.expirationTime) or now) - now,
        gold = (Util.Clean(order.tipAmount) or 0) - (Util.Clean(order.consortiumCut) or 0),
        need = Util.Clean(order.minQuality) or 0,
    }

    local slots = SupplySlots(order, schematic)
    rec.reach = Reach(rec, order, slots)
    Rewards(rec, order)
    Supply(rec, slots)

    if Pricing.Available() then
        if rec.cost then rec.profit = rec.rewardValue - rec.cost end
    elseif #rec.supply == 0 then
        -- No price addon, but nothing to buy: the gold is the profit.
        rec.profit = rec.gold
        rec.partial = #rec.rewards > 0 and not rec.bonus
    end
    rec.reachable = rec.reach ~= "none" and rec.reach ~= "unlearned"
    return rec
end

-- Rewards can arrive after the order (CRAFTINGORDERS_UPDATE_REWARDS).
local lateRewards = {}
function Orders.SetRewards(orderID, rewards)
    if orderID and type(rewards) == "table" then lateRewards[orderID] = rewards end
end

-- Every patron order Blizzard has handed us, evaluated.
function Orders.All()
    local now = GetServerTime()
    local list = {}
    for _, order in ipairs(C_CraftingOrders.GetCrafterOrders() or {}) do
        if order.orderType == Enum.CraftingOrderType.Npc then
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
    end
    return list
end

-- Current and most concentration for the profession, from any record
-- that found its currency.
function Orders.Concentration(list)
    for _, rec in ipairs(list) do
        if rec.concentrationID then
            local info = C_CurrencyInfo.GetCurrencyInfo(rec.concentrationID)
            if info then return info.quantity, info.maxQuantity end
        end
    end
    return nil
end
