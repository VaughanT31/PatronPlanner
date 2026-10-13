-- Patron Planner - one order card, and its hover breakdown.
--
--  +--+------------------------------------------------------------+
--  |  | [icon] Thalassian Spellweaver's Wand              +1,286g  |
--  |  |        Q2 Cheap materials  |  2d left            best pick |
--  |  |  You supply                 Reward                         |
--  |  |  [i][i]  51g                82g [i][i]                     |
--  +--+------------------------------------------------------------+
--  the strip on the left: green good, amber needs more, red loss or
--  can't reach, grey unlearned or no prices.

local _, ns = ...
local L, Util = ns.L, ns.Util

local Card = {}
ns.Card = Card

local ICON = 40
local SMALL = 22
local MAX_SUPPLY = 4
local MAX_REWARDS = 4
local PAD = 12

local REACH_TEXT = {
    any = { "grey", "REACH_ANY" },
    cheap = { "green", "REACH_CHEAP" },
    conc = { "amber", "REACH_CONC" },
    better = { "amber", "REACH_BETTER" },
    betterConc = { "amber", "REACH_BETTER_CONC" },
    none = { "red", "REACH_NONE" },
    unlearned = { "grey", "REACH_UNLEARNED" },
}

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local function Verdict(rec)
    if not rec.learned then return "grey" end
    if rec.reach == "none" then return "red" end
    if rec.profit and rec.profit < 0 then return "red" end
    if rec.reach == "conc" or rec.reach == "better" or rec.reach == "betterConc" then return "amber" end
    if not rec.profit then return "grey" end
    return "green"
end

local function IconSlot(parent)
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetSize(SMALL, SMALL)
    slot.Icon = slot:CreateTexture(nil, "ARTWORK")
    slot.Icon:SetAllPoints()
    slot.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.Border = slot:CreateTexture(nil, "BACKGROUND")
    slot.Border:SetPoint("TOPLEFT", -1, 1)
    slot.Border:SetPoint("BOTTOMRIGHT", 1, -1)
    slot.Border:SetColorTexture(0, 0, 0, 0.9)
    slot.Count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    slot.Count:SetPoint("BOTTOMRIGHT", 2, -1)
    slot.Pip = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slot.Pip:SetPoint("TOPLEFT", -3, 3)
    return slot
end

local function FillSlots(slots, entries, anchor, offsetX)
    local x = offsetX
    for i, slot in ipairs(slots) do
        local entry = entries[i]
        if entry then
            slot.Icon:SetTexture(entry.icon or 134400)
            slot.Count:SetText((entry.count or 1) > 1 and entry.count or "")
            slot.Pip:SetText(entry.quality and entry.quality > 0 and Util.QualityIcon(entry.quality, 12) or "")
            slot:ClearAllPoints()
            slot:SetPoint("LEFT", anchor, "LEFT", x, 0)
            slot:Show()
            x = x + SMALL + 4
        else
            slot:Hide()
        end
    end
    return x
end

function Card.Create(parent)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetBackdrop(BACKDROP)
    card:RegisterForClicks("LeftButtonUp")

    card.Strip = card:CreateTexture(nil, "ARTWORK")
    card.Strip:SetPoint("TOPLEFT", 1, -1)
    card.Strip:SetPoint("BOTTOMLEFT", 1, 1)
    card.Strip:SetWidth(4)

    card.Icon = card:CreateTexture(nil, "ARTWORK")
    card.Icon:SetSize(ICON, ICON)
    card.Icon:SetPoint("TOPLEFT", PAD, -10)
    card.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.IconBorder = card:CreateTexture(nil, "BORDER")
    card.IconBorder:SetPoint("TOPLEFT", card.Icon, -1, 1)
    card.IconBorder:SetPoint("BOTTOMRIGHT", card.Icon, 1, -1)

    card.Profit = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.Profit:SetPoint("TOPRIGHT", -PAD, -11)
    card.ProfitLabel = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.ProfitLabel:SetPoint("TOPRIGHT", card.Profit, "BOTTOMRIGHT", 0, -3)

    card.Name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.Name:SetPoint("TOPLEFT", card.Icon, "TOPRIGHT", 8, -2)
    card.Name:SetPoint("RIGHT", card, "RIGHT", -120, 0)
    card.Name:SetJustifyH("LEFT")
    card.Name:SetWordWrap(false)

    card.Status = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.Status:SetPoint("TOPLEFT", card.Name, "BOTTOMLEFT", 0, -6)
    card.Status:SetPoint("RIGHT", card, "RIGHT", -110, 0)
    card.Status:SetJustifyH("LEFT")
    card.Status:SetWordWrap(false)

    -- Bottom half: what you supply on the left, the reward on the right.
    card.SupplyLabel = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.SupplyLabel:SetPoint("BOTTOMLEFT", PAD + 4, 36)
    card.SupplyLabel:SetText(L.CARD_SUPPLY)
    card.SupplyRow = CreateFrame("Frame", nil, card)
    card.SupplyRow:SetSize(1, SMALL)
    card.SupplyRow:SetPoint("BOTTOMLEFT", PAD + 4, 9)
    card.SupplySlots = {}
    for i = 1, MAX_SUPPLY do card.SupplySlots[i] = IconSlot(card.SupplyRow) end
    card.SupplyText = card.SupplyRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    card.RewardLabel = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.RewardLabel:SetText(L.CARD_REWARD)
    card.RewardRow = CreateFrame("Frame", nil, card)
    card.RewardRow:SetSize(1, SMALL)
    card.RewardGold = card.RewardRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.RewardGold:SetPoint("LEFT", card.RewardRow, "LEFT", 0, 0)
    card.RewardSlots = {}
    for i = 1, MAX_REWARDS do card.RewardSlots[i] = IconSlot(card.RewardRow) end

    card:SetScript("OnSizeChanged", function(self, width)
        self.RewardLabel:ClearAllPoints()
        self.RewardLabel:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", math.floor(width / 2) + 4, 36)
        self.RewardRow:ClearAllPoints()
        self.RewardRow:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", math.floor(width / 2) + 4, 9)
    end)

    card:SetScript("OnEnter", function(self)
        self.hover = true
        self:Paint()
        self:RegisterEvent("MODIFIER_STATE_CHANGED")
        self:ShowTooltip()
    end)
    card:SetScript("OnLeave", function(self)
        self.hover = false
        self:Paint()
        self:UnregisterEvent("MODIFIER_STATE_CHANGED")
        GameTooltip:Hide()
    end)
    card:SetScript("OnEvent", function(self)
        if self.hover then self:ShowTooltip() end
    end)
    card:SetScript("OnClick", function(self)
        if self.rec then ns.Board:Open(self.rec) end
    end)

    for key, fn in pairs(Card) do
        if key ~= "Create" then card[key] = fn end
    end
    return card
end

-- Background and border, brighter on hover.
function Card:Paint()
    local c = Util.COLOR[self.verdict or "grey"]
    if self.hover then
        self:SetBackdropColor(0.16, 0.15, 0.13, 0.96)
        self:SetBackdropBorderColor(c[1], c[2], c[3], 0.9)
    else
        self:SetBackdropColor(0.07, 0.07, 0.08, 0.92)
        self:SetBackdropBorderColor(0.28, 0.26, 0.22, 0.9)
    end
end

function Card:SetRecord(rec, isBest)
    self.rec = rec
    self.verdict = Verdict(rec)
    local c = Util.COLOR[self.verdict]
    self.Strip:SetColorTexture(c[1], c[2], c[3], 0.95)
    self:Paint()

    self.Icon:SetTexture(rec.icon or 134400)
    self.Icon:SetDesaturated(not rec.learned)
    local r, g, b = Util.RarityColor(rec.rarity)
    self.IconBorder:SetColorTexture(r, g, b, 0.9)
    self.Name:SetText(rec.name)
    if rec.learned then
        self.Name:SetTextColor(r, g, b)
    else
        self.Name:SetTextColor(0.6, 0.6, 0.6)
    end

    -- Quality reach and time left.
    local reach = REACH_TEXT[rec.reach]
    local quality = rec.need > 1 and (Util.QualityIcon(rec.need, 14) .. " ") or ""
    local reachText = L[reach[2]]
    if rec.concCost and rec.concCost > 0 then
        reachText = reachText .. " " .. L.CONC_SHORT:format(rec.concCost)
    end
    self.Status:SetText(quality .. Util.Paint(reach[1], reachText) .. "   "
        .. Util.Paint(Util.TimeColor(rec.left), L.TIME_LEFT:format(Util.TimeLeft(rec.left))))

    -- Profit, the headline.
    local full = ns.db and ns.db.settings.showCopper
    if rec.profit then
        local color = rec.profit < 0 and "red" or (rec.profit > 0 and "green" or "white")
        local sign = rec.profit > 0 and "+" or ""
        self.Profit:SetText(Util.Paint(color, sign .. Util.Money(rec.profit, full)) .. (rec.partial and Util.Paint("grey", "*") or ""))
    else
        self.Profit:SetText(Util.Paint("grey", "?"))
    end
    if isBest then
        self.ProfitLabel:SetText(Util.Paint("gold", CreateAtlasMarkup("auctionhouse-icon-favorite", 11, 11) .. " " .. L.CARD_BEST))
    elseif not rec.profit then
        self.ProfitLabel:SetText(ns.Pricing.Available() and L.CARD_NO_PRICE or L.CARD_NO_SOURCE)
    else
        self.ProfitLabel:SetText(L.CARD_PROFIT)
    end

    -- You supply.
    local x = FillSlots(self.SupplySlots, rec.supply, self.SupplyRow, 0)
    self.SupplyText:ClearAllPoints()
    self.SupplyText:SetPoint("LEFT", self.SupplyRow, "LEFT", x + 2, 0)
    if #rec.supply == 0 then
        self.SupplyText:SetText(Util.Paint("green", L.CARD_ALL_PROVIDED))
    elseif rec.cost then
        local more = #rec.supply > MAX_SUPPLY and ("+" .. (#rec.supply - MAX_SUPPLY) .. "  ") or ""
        self.SupplyText:SetText(more .. Util.Money(rec.cost, full))
    else
        self.SupplyText:SetText("")
    end

    -- Reward: gold, then the items.
    self.RewardGold:SetText(rec.gold > 0 and Util.Money(rec.gold, full) or "")
    local goldWidth = rec.gold > 0 and (self.RewardGold:GetStringWidth() + 6) or 0
    FillSlots(self.RewardSlots, rec.rewards, self.RewardRow, goldWidth)

    self:SetAlpha(rec.learned and 1 or 0.6)
end

local function TipIcon(icon)
    return icon and ("|T" .. icon .. ":14:14:0:0:64:64:5:59:5:59|t ") or ""
end

function Card:ShowTooltip()
    local rec = self.rec
    if not rec then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    -- Shift: Blizzard's own item tooltip for what you'd craft.
    if IsShiftKeyDown() then
        local reagents = {}
        for _, reagent in ipairs(rec.order.reagents or {}) do
            if reagent.reagentInfo then reagents[#reagents + 1] = reagent.reagentInfo end
        end
        local qualityIDs = C_TradeSkillUI.GetQualitiesForRecipe(rec.recipeID)
        local qualityID = qualityIDs and qualityIDs[math.max(rec.need, 1)]
        GameTooltip:SetRecipeResultItem(rec.recipeID, reagents, nil, nil, qualityID)
        GameTooltip:Show()
        return
    end

    local full = true
    local r, g, b = Util.RarityColor(rec.rarity)
    GameTooltip:AddLine(rec.name, r, g, b)

    if not rec.learned then
        GameTooltip:AddLine(L.TIP_UNLEARNED, 1, 0.4, 0.4)
        local source = C_TradeSkillUI.GetRecipeSourceText(rec.recipeID)
        if source and source ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.TIP_HOW_TO_LEARN, 1, 0.82, 0)
            GameTooltip:AddLine(source, 1, 1, 1, true)
        end
    else
        local reach = REACH_TEXT[rec.reach]
        if rec.need > 1 then
            GameTooltip:AddDoubleLine(L.TIP_QUALITY, Util.QualityIcon(rec.need, 16), 1, 0.82, 0)
        end
        GameTooltip:AddLine(Util.Paint(reach[1], L["TIP_" .. reach[2]]), 1, 1, 1, true)
        if rec.concCost and rec.concCost > 0 then
            local have = ns.Orders.Concentration({ rec })
            GameTooltip:AddDoubleLine(L.TIP_CONCENTRATION,
                have and L.TIP_CONC_OF:format(rec.concCost, have) or tostring(rec.concCost),
                1, 0.82, 0, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.CARD_REWARD, 1, 0.82, 0)
    if rec.gold > 0 then
        GameTooltip:AddDoubleLine(L.TIP_GOLD, Util.Money(rec.gold, full), 1, 1, 1, 1, 1, 1)
    end
    for _, reward in ipairs(rec.rewards) do
        local name = TipIcon(reward.icon) .. (reward.name or "...") .. (reward.count > 1 and (" x" .. reward.count) or "")
        local value
        if reward.value then
            value = Util.Money(reward.value, full)
        elseif reward.bonus then
            value = Util.Paint("blue", L.TIP_BONUS)
        else
            value = Util.Paint("grey", L.TIP_NO_PRICE)
        end
        GameTooltip:AddDoubleLine(name, value, 1, 1, 1, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.CARD_SUPPLY, 1, 0.82, 0)
    if #rec.supply == 0 then
        GameTooltip:AddLine(L.CARD_ALL_PROVIDED, 0.35, 0.85, 0.45)
    end
    for _, item in ipairs(rec.supply) do
        local name = TipIcon(item.icon) .. (item.name or "...") .. " x" .. item.count
            .. (item.quality and item.quality > 0 and (" " .. Util.QualityIcon(item.quality, 12)) or "")
        GameTooltip:AddDoubleLine(name, item.price and Util.Money(item.price, full) or Util.Paint("grey", L.TIP_NO_PRICE),
            1, 1, 1, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    if rec.profit then
        local color = rec.profit < 0 and "red" or "green"
        GameTooltip:AddDoubleLine(L.CARD_PROFIT_TITLE, Util.Paint(color, Util.Money(rec.profit, full)), 1, 0.82, 0)
        if rec.partial then GameTooltip:AddLine(L.TIP_PARTIAL, 0.6, 0.6, 0.6, true) end
    elseif not ns.Pricing.Available() then
        GameTooltip:AddLine(L.TIP_NO_SOURCE, 0.6, 0.6, 0.6, true)
    else
        GameTooltip:AddLine(L.TIP_CANT_PRICE, 0.6, 0.6, 0.6, true)
    end
    GameTooltip:AddDoubleLine(L.TIP_TIME_LEFT, Util.TimeLeft(rec.left), 1, 0.82, 0, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.TIP_CLICK, 0.5, 0.5, 0.5)
    GameTooltip:Show()
end
