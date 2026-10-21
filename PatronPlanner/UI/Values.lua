-- Patron Planner - the Values panel, opened from the Values button on the
-- board. The player says what things are worth to them, in gold:
--   concentration   taken off the profit of orders that need it, since a
--                   point spent here can't go on another craft
--   rewards without a price (Moxie and other currencies, knowledge,
--   payout bags)    added to the reward
-- Blank or 0 leaves it out, as before. Moxie rows have an Estimate button:
-- what a Master's Surplus bag holds at AH prices, per Moxie. Only rewards
-- offered in the orders on screen are listed; values for the others are
-- kept.

local _, ns = ...
local L, Util, Orders = ns.L, ns.Util, ns.Orders

local Values = { rows = {} }
ns.Values = Values

local WIDTH = 300
local ROW = 26
local BOX = 70

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

-- "12.5" -> 12.5; blank, 0, negative or not a number -> nil.
local function ReadGold(text)
    local gold = tonumber((tostring(text or ""):gsub(",", ".")))
    if gold and gold > 0 then return gold end
    return nil
end

local function ShowGold(gold)
    if not gold or gold <= 0 then return "" end
    if gold == math.floor(gold) then return tostring(gold) end
    return (("%.2f"):format(gold):gsub("0+$", ""))
end

local function Box(parent, onSave)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(BOX, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(8)
    box:SetJustifyH("RIGHT")
    box:SetTextInsets(0, 6, 0, 0)
    local function Save(self)
        onSave(ReadGold(self:GetText()))
        self:SetText(ShowGold(ReadGold(self:GetText())))
        if ns.Board then ns.Board:Refresh() end
    end
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", Save)
    return box
end

-- One "[icon] label  [box] g" row.
local function Row(parent, onSave)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(WIDTH - 24, ROW)
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(18, 18)
    row.Icon:SetPoint("LEFT")
    row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Label:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
    row.Label:SetPoint("RIGHT", row, "RIGHT", -(BOX + 22 + 26), 0)
    row.Label:SetJustifyH("LEFT")
    row.Label:SetWordWrap(false)
    row.Unit = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Unit:SetPoint("RIGHT")
    row.Unit:SetText("g")
    row.Box = Box(row, function(gold) onSave(row, gold) end)
    row.Box:SetPoint("RIGHT", row.Unit, "LEFT", -4, 0)
    -- Estimate (Moxie rows only): fills the box from the surplus bag.
    row.Estimate = CreateFrame("Button", nil, row)
    row.Estimate:SetSize(20, 20)
    row.Estimate:SetPoint("RIGHT", row.Box, "LEFT", -8, 0)
    row.Estimate:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
    row.Estimate:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.Estimate:SetScript("OnClick", function()
        local copper = row.currencyID and Orders.MoxieEstimate(row.currencyID)
        if not copper then
            Util.Say(L.VALUES_NO_ESTIMATE)
            return
        end
        local gold = math.floor(copper / 100 + 0.5) / 100
        onSave(row, gold)
        row.Box:SetText(ShowGold(gold))
        if ns.Board then ns.Board:Refresh() end
    end)
    row.Estimate:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.VALUES_ESTIMATE, 1, 0.82, 0)
        local copper = row.currencyID and Orders.MoxieEstimate(row.currencyID)
        GameTooltip:AddLine(copper and L.VALUES_ESTIMATE_TIP:format(Util.Money(copper, true)) or L.VALUES_NO_ESTIMATE, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row.Estimate:SetScript("OnLeave", GameTooltip_Hide)
    row.Estimate:Hide()
    return row
end

function Values:Build(board)
    local frame = CreateFrame("Frame", nil, board.panel, "BackdropTemplate")
    frame:SetBackdrop(BACKDROP)
    Util.CrispEdges(frame)
    frame:SetBackdropColor(0.06, 0.06, 0.07, 0.98)
    frame:SetBackdropBorderColor(1, 0.82, 0, 0.5)
    frame:SetWidth(WIDTH)
    frame:SetFrameLevel(board.panel:GetFrameLevel() + 50)
    frame:EnableMouse(true)
    frame:Hide()
    self.frame = frame

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Title:SetPoint("TOPLEFT", 12, -10)
    frame.Title:SetText(L.VALUES_TITLE)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame.Intro = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.Intro:SetPoint("TOPLEFT", 12, -30)
    frame.Intro:SetWidth(WIDTH - 24)
    frame.Intro:SetJustifyH("LEFT")
    frame.Intro:SetText(L.VALUES_INTRO)

    self.conc = Row(frame, function(_, gold) ns.db.settings.concValue = gold or 0 end)
    self.conc.Label:SetPoint("RIGHT", self.conc, "RIGHT", -(BOX + 22), 0)
    self.conc.Label:SetText(L.VALUES_CONC)

    frame.CurrencyHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.CurrencyHeader:SetText(L.VALUES_CURRENCIES)
    frame.None = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.None:SetWidth(WIDTH - 24)
    frame.None:SetJustifyH("LEFT")
    frame.None:SetText(L.VALUES_NO_CURRENCY)
end

-- Lays the panel out for the unpriced rewards in the orders on screen.
function Values:Fill()
    local frame = self.frame
    local settings = ns.db.settings
    settings.currencyValues = settings.currencyValues or {}
    settings.itemValues = settings.itemValues or {}
    local function Store(kind)
        return kind == "currency" and settings.currencyValues or settings.itemValues
    end

    local y = -36 - math.ceil(frame.Intro:GetStringHeight())
    self.conc:ClearAllPoints()
    self.conc:SetPoint("TOPLEFT", 12, y)
    local concID = ns.Board.records and select(3, Orders.Concentration(ns.Board.records))
    local concInfo = concID and C_CurrencyInfo.GetCurrencyInfo(concID)
    self.conc.Icon:SetTexture(concInfo and concInfo.iconFileID or 134400)
    self.conc.Box:SetText(ShowGold(tonumber(settings.concValue)))
    y = y - ROW - 10

    frame.CurrencyHeader:ClearAllPoints()
    frame.CurrencyHeader:SetPoint("TOPLEFT", 12, y)
    y = y - 18

    local currencies = Orders.Valuables(ns.Board.records)
    for i, currency in ipairs(currencies) do
        local row = self.rows[i]
        if not row then
            row = Row(frame, function(self, gold) Store(self.kind)[self.id] = gold end)
            self.rows[i] = row
        end
        row.kind, row.id = currency.kind, currency.id
        row.currencyID = currency.kind == "currency" and currency.id or nil
        row.Estimate:SetShown(row.currencyID ~= nil and ns.Reference.SURPLUS_BAGS[row.currencyID] ~= nil)
        row.Icon:SetTexture(currency.icon or 134400)
        row.Label:SetText(currency.name or ("#" .. currency.id))
        row.Box:SetText(ShowGold(tonumber(Store(currency.kind)[currency.id])))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 12, y)
        row:Show()
        y = y - ROW
    end
    for i = #currencies + 1, #self.rows do self.rows[i]:Hide() end

    frame.None:SetShown(#currencies == 0)
    if #currencies == 0 then
        frame.None:ClearAllPoints()
        frame.None:SetPoint("TOPLEFT", 12, y)
        y = y - math.ceil(frame.None:GetStringHeight()) - 4
    end
    frame:SetHeight(-y + 10)
end

function Values:Toggle(anchor)
    local board = ns.Board
    if not self.frame then self:Build(board) end
    if self.frame:IsShown() then
        self.frame:Hide()
        return
    end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    self:Fill()
    self.frame:Show()
end

function Values:Hide()
    if self.frame then self.frame:Hide() end
end
