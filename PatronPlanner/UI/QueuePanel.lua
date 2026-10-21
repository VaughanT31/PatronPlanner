-- Patron Planner - the order queue panel, docked to the right of the
-- profession window on the Crafting Orders page.
--
--  +-- Order queue (2) ----------------- [x] -+
--  | [ic] Thalassian Treatise on Tailoring    |
--  |      Q2 Cheap  +412g  for Ana   [Claim]  |
--  |------------------------------------------|
--  | 2 orders  +1,292g  Conc 120 / 820         |
--  | To buy: 3 items, 214g                     |
--  | [Queue all] [*] [Clear]  [Shopping list]  |
--  | [Release]                    [Next: Claim]|
--  +------------------------------------------+
--
-- Shown with the Crafting Orders page, and hidden by its close button
-- until the board's Queue chip turns it on again.

local _, ns = ...
local L, Util, Queue, Craft, Orders, Shopping = ns.L, ns.Util, ns.Queue, ns.Craft, ns.Orders, ns.Shopping

local QueuePanel = { rows = {}, scroll = 0 }
ns.QueuePanel = QueuePanel

local WIDTH = 330
local HEIGHT = 470
local ROW = 46
local FOOTER = 118
local BUTTON = 82

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local REACH_TEXT = {
    any = { "grey", "REACH_ANY" }, cheap = { "green", "REACH_CHEAP" }, conc = { "amber", "REACH_CONC" },
    better = { "amber", "REACH_BETTER" }, betterConc = { "amber", "REACH_BETTER_CONC" },
    none = { "red", "REACH_NONE" }, unknown = { "grey", "REACH_UNKNOWN" }, unlearned = { "grey", "REACH_UNLEARNED" },
}

local function Button(parent, width, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function Tip(button, title, text)
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(title, 1, 0.82, 0)
        if text then GameTooltip:AddLine(type(text) == "function" and text() or text, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", GameTooltip_Hide)
end

-- One queue row.
local function Row(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetBackdrop(BACKDROP)
    Util.CrispEdges(row)
    row:SetHeight(ROW - 4)
    row:RegisterForClicks("RightButtonUp")

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(30, 30)
    row.Icon:SetPoint("LEFT", 6, 0)
    row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.Action = Button(row, BUTTON, "", function(self) if self.entry then Craft.Do(self.entry) end end)
    row.Action:SetPoint("RIGHT", -6, 0)
    row.Action:SetMotionScriptsWhileDisabled(true)
    row.Action:HookScript("OnEnter", function(self)
        if not self.why then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self:GetText() or "", 1, 0.82, 0)
        GameTooltip:AddLine(self.why, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row.Action:HookScript("OnLeave", GameTooltip_Hide)

    row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.Name:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 7, -1)
    row.Name:SetPoint("RIGHT", row.Action, "LEFT", -6, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)

    row.Info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Info:SetPoint("BOTTOMLEFT", row.Icon, "BOTTOMRIGHT", 7, 1)
    row.Info:SetPoint("RIGHT", row.Action, "LEFT", -6, 0)
    row.Info:SetJustifyH("LEFT")
    row.Info:SetWordWrap(false)

    row:SetScript("OnClick", function(self)
        if self.entry then Queue.Remove(self.entry.key) end
    end)
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.16, 0.15, 0.13, 0.96)
        local rec = self.entry and Queue.recs[self.entry.key]
        if rec and ns.Card then
            ns.Card.ShowTooltip(self)
        else
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.entry and self.entry.name or "?", 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.QUEUE_ROW_REMOVE, 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.07, 0.07, 0.08, 0.92)
        GameTooltip:Hide()
    end)
    row:SetBackdropColor(0.07, 0.07, 0.08, 0.92)
    row:SetBackdropBorderColor(0.28, 0.26, 0.22, 0.9)
    return row
end

function QueuePanel:Build()
    local frame = CreateFrame("Frame", "PatronPlannerQueuePanel", ProfessionsFrame, "BackdropTemplate")
    frame:SetBackdrop(BACKDROP)
    Util.CrispEdges(frame)
    frame:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    frame:SetBackdropBorderColor(1, 0.82, 0, 0.45)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 6, 0)
    frame:EnableMouse(true)
    frame:Hide()
    self.frame = frame

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Title:SetPoint("TOPLEFT", 12, -10)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function()
        ns.db.settings.queueHidden = true
        QueuePanel:Refresh()
        if ns.Board and ns.Board.active then ns.Board:Layout() end
    end)

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 8, -32)
    scroll:SetPoint("BOTTOMRIGHT", -8, FOOTER)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) QueuePanel:ScrollTo(QueuePanel.scroll - delta * ROW) end)
    self.scrollFrame = scroll
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 16, 1)
    scroll:SetScrollChild(content)
    self.content = content

    frame.Empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.Empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 4, -8)
    frame.Empty:SetPoint("RIGHT", scroll, "RIGHT", -4, 0)
    frame.Empty:SetJustifyH("LEFT")
    frame.Empty:SetText(L.QUEUE_EMPTY)

    local line = frame:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT", 8, FOOTER - 4)
    line:SetPoint("BOTTOMRIGHT", -8, FOOTER - 4)
    line:SetHeight(1)
    line:SetColorTexture(1, 0.82, 0, 0.25)

    frame.Totals = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Totals:SetPoint("BOTTOMLEFT", 12, FOOTER - 20)
    frame.Totals:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    frame.Totals:SetJustifyH("LEFT")
    frame.ToBuy = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.ToBuy:SetPoint("TOPLEFT", frame.Totals, "BOTTOMLEFT", 0, -5)
    frame.ToBuy:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    frame.ToBuy:SetJustifyH("LEFT")

    -- [Queue all] [*] [Clear]      [Shopping list]
    local all = Button(frame, 84, L.QUEUE_ALL, function() QueuePanel:QueueAll() end)
    all:SetPoint("BOTTOMLEFT", 10, 36)
    Tip(all, L.QUEUE_ALL, L.QUEUE_ALL_TIP)
    local options = Button(frame, 24, "", function(self) QueuePanel:OptionsMenu(self) end)
    options:SetPoint("LEFT", all, "RIGHT", 2, 0)
    local cog = options:CreateTexture(nil, "OVERLAY")
    cog:SetSize(14, 14)
    cog:SetPoint("CENTER")
    cog:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    Tip(options, L.QUEUE_OPTIONS, L.QUEUE_OPTIONS_TIP)
    local clear = Button(frame, 60, L.QUEUE_CLEAR, function() Queue.Clear() end)
    clear:SetPoint("LEFT", options, "RIGHT", 2, 0)
    local shop = Button(frame, 110, L.QUEUE_SHOPPING, function() if ns.ShoppingList then ns.ShoppingList:Toggle() end end)
    shop:SetPoint("BOTTOMRIGHT", -10, 36)
    Tip(shop, L.QUEUE_SHOPPING, L.QUEUE_SHOPPING_TIP)

    -- [Release]                    [Next: Claim]
    self.release = Button(frame, 84, L.QUEUE_RELEASE, function() Craft.Release() end)
    self.release:SetPoint("BOTTOMLEFT", 10, 10)
    Tip(self.release, L.QUEUE_RELEASE, L.QUEUE_RELEASE_TIP)
    self.next = Button(frame, 150, L.QUEUE_NEXT_NONE, function() Craft.Next() end)
    self.next:SetPoint("BOTTOMRIGHT", -10, 10)
    Tip(self.next, L.QUEUE_NEXT, L.QUEUE_NEXT_TIP)

    ProfessionsFrame:HookScript("OnHide", function() frame:Hide() end)
    local page = ProfessionsFrame.OrdersPage
    if page then
        page:HookScript("OnShow", function() QueuePanel:Refresh() end)
        page:HookScript("OnHide", function() QueuePanel:Refresh() end)
    end
end

-- Shown whenever the Crafting Orders page is, unless closed with its X
-- (the board's Queue chip, /pp queue or Shift-click on the minimap button
-- bring it back).
function QueuePanel:Wanted()
    local page = ProfessionsFrame and ProfessionsFrame.OrdersPage
    if not (ProfessionsFrame and ProfessionsFrame:IsShown() and page and page:IsShown()) then return false end
    return not ns.db.settings.queueHidden
end

function QueuePanel:Refresh()
    if not ns.db then return end
    if not self.frame then
        if not ProfessionsFrame then return end
        self:Build()
    end
    if not self:Wanted() then
        self.frame:Hide()
        return
    end
    self.frame:Show()
    local list = Queue.List()
    self.frame.Title:SetText(L.QUEUE_TITLE:format(#list))
    self.frame.Empty:SetShown(#list == 0)

    local full = ns.db.settings.showCopper
    local claimedKey = Craft.ClaimedKey()
    for i, entry in ipairs(list) do
        local row = self.rows[i]
        if not row then
            row = Row(self.content)
            self.rows[i] = row
        end
        local rec = Queue.recs[entry.key]
        row.entry, row.rec = entry, rec
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(i - 1) * ROW)
        row:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)
        row.Icon:SetTexture(entry.icon or 134400)
        row.Name:SetText(entry.name or "?")
        local parts = {}
        if (entry.need or 0) > 1 then parts[#parts + 1] = Util.QualityIcon(entry.need, 12) end
        local reach = rec and REACH_TEXT[rec.reach]
        if reach then parts[#parts + 1] = Util.Paint(reach[1], L[reach[2]]) end
        local profit = rec and rec.profit or entry.profit
        if profit then
            parts[#parts + 1] = Util.Paint(profit < 0 and "red" or "green", (profit > 0 and "+" or "") .. Util.Money(profit, full))
        end
        local conc = rec and (rec.concCost) or entry.concCost
        if conc and conc > 0 then parts[#parts + 1] = Util.Paint("amber", L.QUEUE_CONC:format(conc)) end
        if entry.customer then parts[#parts + 1] = Util.Paint("grey", L.CARD_FOR:format(Ambiguate(entry.customer, "short"))) end
        row.Info:SetText(table.concat(parts, "  "))
        row:SetBackdropBorderColor(entry.key == claimedKey and 1 or 0.28, entry.key == claimedKey and 0.82 or 0.26,
            entry.key == claimedKey and 0 or 0.22, 0.9)

        local step = Craft.Step(entry)
        row.Action.entry = entry
        row.Action.why = step.why
        row.Action:SetText(step.label)
        row.Action:SetEnabled(step.enabled and step.action ~= nil)
        row:Show()
    end
    for i = #list + 1, #self.rows do self.rows[i]:Hide() end
    self.content:SetHeight(math.max(1, #list * ROW))
    self:ScrollTo(self.scroll)

    -- Totals: orders, profit, concentration against what you have.
    local count, profit, conc = Queue.Totals()
    local parts = { L.QUEUE_ORDERS:format(count) }
    if profit then parts[#parts + 1] = Util.Paint(profit < 0 and "red" or "green", (profit > 0 and "+" or "") .. Util.Money(profit, full)) end
    if conc > 0 then
        local have = Orders.Concentration(ns.Board and ns.Board.records)
        local text = have and L.QUEUE_CONC_OF:format(math.floor(conc + 0.5), have) or L.QUEUE_CONC:format(math.floor(conc + 0.5))
        parts[#parts + 1] = Util.Paint(have and conc > have and "red" or "amber", text)
    end
    self.frame.Totals:SetText(table.concat(parts, Util.Paint("grey", "  |  ")))
    local toBuy, cost = Shopping.Summary()
    if toBuy == 0 then
        self.frame.ToBuy:SetText(count > 0 and Util.Paint("green", L.QUEUE_ALL_OWNED) or "")
    else
        self.frame.ToBuy:SetText(L.QUEUE_TO_BUY:format(toBuy, cost and Util.Money(cost, full) or "?"))
    end

    self.release:SetShown(claimedKey ~= nil)
    local step = Craft.NextStep()
    self.next:SetText(step and L.QUEUE_NEXT_STEP:format(step.label) or L.QUEUE_NEXT_NONE)
    self.next:SetEnabled(step ~= nil)
end

function QueuePanel:ScrollTo(offset)
    local most = math.max(0, self.content:GetHeight() - self.scrollFrame:GetHeight())
    self.scroll = math.max(0, math.min(offset or 0, most))
    self.scrollFrame:SetVerticalScroll(self.scroll)
end

-- Queue all: the orders on the board that pass its filter, in its order.
function QueuePanel:QueueAll()
    local board = ns.Board
    local records = board and board.shown or {}
    if #records == 0 then
        Util.Say(L.QUEUE_ALL_NONE)
        return
    end
    local added, reasons = Queue.AddAll(records)
    local skipped = {}
    for _, item in ipairs(reasons) do skipped[#skipped + 1] = L.QUEUE_SKIPPED_ITEM:format(item.count, item.reason) end
    local text = L.QUEUE_ADDED:format(added)
    if #skipped > 0 then text = text .. " " .. L.QUEUE_SKIPPED:format(table.concat(skipped, ", ")) end
    Util.Say(text)
end

function QueuePanel:OptionsMenu(owner)
    local settings = ns.db.settings
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.QUEUE_OPTIONS)
        for _, option in ipairs({
            { "queueSkipConc", L.QUEUE_OPT_SKIP_CONC },
            { "queueSkipBuy", L.QUEUE_OPT_SKIP_BUY },
            { "queueConcLimit", L.QUEUE_OPT_CONC_LIMIT },
        }) do
            root:CreateCheckbox(option[2],
                function() return settings[option[1]] == true end,
                function() settings[option[1]] = not settings[option[1]] end)
        end
    end)
end

-- Turns the panel on or off from the board's Queue chip.
function QueuePanel:Toggle()
    local settings = ns.db.settings
    settings.queueHidden = self.frame ~= nil and self.frame:IsShown()
    self:Refresh()
end

-- Bags and the claimed order change what the buttons can do.
local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
events:SetScript("OnEvent", function()
    if QueuePanel.frame and QueuePanel.frame:IsShown() then QueuePanel:Refresh() end
end)
