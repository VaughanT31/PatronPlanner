-- Patron Planner - the shopping list window: what the queued orders still
-- need, counted once across the queue. It works anywhere (at the AH too),
-- from the queue panel, the minimap button or /pp shop.
--
--  +-- Shopping list ------------------- [x] -+
--  | [i] Sunfire Silk Q2   buy 12 (have 8)  96g |
--  | [i] Bright Linen      all in your bags     |
--  |--------------------------------------------|
--  | 1 item to buy, 96g                         |
--  | [Auction Coach] [Auctionator]              |
--  +--------------------------------------------+

local _, ns = ...
local L, Util, Shopping, Queue = ns.L, ns.Util, ns.Shopping, ns.Queue

local ShoppingList = { rows = {}, scroll = 0 }
ns.ShoppingList = ShoppingList

local WIDTH = 340
local HEIGHT = 380
local ROW = 24
local FOOTER = 70

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local function Row(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW - 2)
    row:EnableMouse(true)
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(18, 18)
    row.Icon:SetPoint("LEFT", 2, 0)
    row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.Price = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Price:SetPoint("RIGHT", -4, 0)
    row.Price:SetJustifyH("RIGHT")
    row.Need = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Need:SetPoint("RIGHT", row.Price, "LEFT", -10, 0)
    row.Need:SetJustifyH("RIGHT")
    row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
    row.Name:SetPoint("RIGHT", row.Need, "LEFT", -8, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

function ShoppingList:Build()
    local frame = CreateFrame("Frame", "PatronPlannerShoppingList", UIParent, "BackdropTemplate")
    frame:SetBackdrop(BACKDROP)
    Util.CrispEdges(frame)
    frame:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    frame:SetBackdropBorderColor(1, 0.82, 0, 0.45)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", 300, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "PatronPlannerShoppingList")
    self.frame = frame

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Title:SetPoint("TOPLEFT", 12, -10)
    frame.Title:SetText(L.SHOP_TITLE)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 10, -32)
    scroll:SetPoint("BOTTOMRIGHT", -10, FOOTER)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) ShoppingList:ScrollTo(ShoppingList.scroll - delta * ROW * 2) end)
    self.scrollFrame = scroll
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 20, 1)
    scroll:SetScrollChild(content)
    self.content = content

    frame.Empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.Empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 4, -8)
    frame.Empty:SetPoint("RIGHT", scroll, "RIGHT", -4, 0)
    frame.Empty:SetJustifyH("LEFT")
    frame.Empty:SetText(L.SHOP_EMPTY)

    local line = frame:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT", 10, FOOTER - 4)
    line:SetPoint("BOTTOMRIGHT", -10, FOOTER - 4)
    line:SetHeight(1)
    line:SetColorTexture(1, 0.82, 0, 0.25)

    frame.Summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Summary:SetPoint("BOTTOMLEFT", 12, FOOTER - 22)
    frame.Summary:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    frame.Summary:SetJustifyH("LEFT")

    local function Export(label, tip, onClick)
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(120, 22)
        button:SetText(label)
        button:SetScript("OnClick", onClick)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(label, 1, 0.82, 0)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        return button
    end
    self.toAC = Export(L.SHOP_TO_AC, L.SHOP_TO_AC_TIP, function() Shopping.ToAuctionCoach() end)
    self.toAuctionator = Export(L.SHOP_TO_AUCTIONATOR, L.SHOP_TO_AUCTIONATOR_TIP, function() Shopping.ToAuctionator() end)
    frame.NoExport = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.NoExport:SetPoint("BOTTOMLEFT", 12, 16)
    frame.NoExport:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    frame.NoExport:SetJustifyH("LEFT")
    frame.NoExport:SetText(L.SHOP_NO_EXPORT)

    frame:SetScript("OnShow", function() ShoppingList:Refresh() end)
end

function ShoppingList:Refresh()
    if not (self.frame and self.frame:IsShown()) then return end
    local full = ns.db.settings.showCopper
    local items = Shopping.Items()
    for i, item in ipairs(items) do
        local row = self.rows[i]
        if not row then
            row = Row(self.content)
            self.rows[i] = row
        end
        row.itemID = item.itemID
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(i - 1) * ROW)
        row:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)
        row.Icon:SetTexture(C_Item.GetItemIconByID(item.itemID) or 134400)
        local quality = item.quality and item.quality > 0 and (" " .. Util.QualityIcon(item.quality, 12)) or ""
        row.Name:SetText((item.name or "...") .. quality)
        if item.need > 0 then
            row.Need:SetText(L.SHOP_NEED:format(item.need, item.have))
            row.Price:SetText(item.price and Util.Money(item.price * item.need, full) or Util.Paint("grey", "?"))
            row.Name:SetTextColor(1, 1, 1)
        else
            row.Need:SetText(Util.Paint("green", L.SHOP_OWNED))
            row.Price:SetText("")
            row.Name:SetTextColor(0.6, 0.6, 0.6)
        end
        row:Show()
    end
    for i = #items + 1, #self.rows do self.rows[i]:Hide() end
    self.content:SetHeight(math.max(1, #items * ROW))
    self:ScrollTo(self.scroll)
    self.frame.Empty:SetShown(#items == 0)
    self.frame.Empty:SetText(Queue.Count() == 0 and L.SHOP_EMPTY or L.SHOP_NONE)

    local count, cost = Shopping.Summary(items)
    if count == 0 then
        self.frame.Summary:SetText(#items > 0 and Util.Paint("green", L.QUEUE_ALL_OWNED) or "")
    else
        self.frame.Summary:SetText(L.QUEUE_TO_BUY:format(count, cost and Util.Money(cost, full) or "?"))
    end

    -- Export buttons for whichever addons are installed.
    local x = 10
    for _, pair in ipairs({ { self.toAC, Shopping.HasAuctionCoach() }, { self.toAuctionator, Shopping.HasAuctionator() } }) do
        local button, shown = pair[1], pair[2]
        button:SetShown(shown)
        button:SetEnabled(count > 0)
        if shown then
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", x, 12)
            x = x + button:GetWidth() + 6
        end
    end
    self.frame.NoExport:SetShown(x == 10)
end

function ShoppingList:ScrollTo(offset)
    local most = math.max(0, self.content:GetHeight() - self.scrollFrame:GetHeight())
    self.scroll = math.max(0, math.min(offset or 0, most))
    self.scrollFrame:SetVerticalScroll(self.scroll)
end

function ShoppingList:Toggle()
    if not self.frame then self:Build() end
    self.frame:SetShown(not self.frame:IsShown())
end

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function() ShoppingList:Refresh() end)
