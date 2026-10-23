-- Patron Planner - the card view over Blizzard's crafting order lists
-- (Patron, Personal, Guild, and Public once an item's orders are listed).
--
-- Blizzard's list is never removed: while the cards show, its rows,
-- headers and scroll bar are made invisible and our panel sits on top and
-- takes the mouse. The Cards / Classic button by the order tabs swaps back.
-- Public orders first come grouped by item: that view stays Blizzard's.
--
-- Hooks on ProfessionsFrame.OrdersPage (Blizzard_Professions):
--   ShowGeneric            new orders arrived: draw the cards
--   SetCraftingOrderType   tab changed: the new tab decides on its next list
--   SendOrderRequest       a search started: dim the cards until it lands,
--                          and keep the request to send again after a hand-in

local _, ns = ...
local L, Util, Orders, Card = ns.L, ns.Util, ns.Orders, ns.Card

local Board = { cards = {}, chips = {}, active = false, scroll = 0 }
ns.Board = Board

local BAR_HEIGHT = 56
local CARD_HEIGHT = 104
local GAP = 8
local COLUMNS = 2
local DIVIDER_HEIGHT = 26
local WHEEL_STEP = 70

local FILTERS = {
    { key = "all", label = "FILTER_ALL", test = function() return true end },
    { key = "craft", label = "FILTER_CRAFT", test = function(rec) return rec.reachable end },
    { key = "profit", label = "FILTER_PROFIT", test = function(rec) return rec.reachable and rec.profit and rec.profit > 0 end },
    { key = "noconc", label = "FILTER_NOCONC", test = function(rec)
        return rec.reachable and rec.reach ~= "conc" and rec.reach ~= "betterConc"
    end },
    { key = "stock", label = "FILTER_STOCK", test = function(rec) return rec.nothingToBuy end },
    { key = "bonus", label = "FILTER_BONUS", test = function(rec) return rec.bonus end },
    { key = "unlearned", label = "FILTER_UNLEARNED", test = function(rec) return not rec.learned end },
}

local function ByProfit(a, b)
    local pa, pb = a.profit or -math.huge, b.profit or -math.huge
    if pa ~= pb then return pa > pb end
    return a.left < b.left
end

local SORTS = {
    { key = "best", label = "SORT_BEST", compare = function(a, b)
        if a.reachable ~= b.reachable then return a.reachable end
        return ByProfit(a, b)
    end },
    { key = "profit", label = "SORT_PROFIT", compare = ByProfit },
    { key = "conc", label = "SORT_CONC", compare = function(a, b)
        -- Orders that need concentration first, best gold per point first.
        local ca, cb = a.perConc or -math.huge, b.perConc or -math.huge
        if (a.perConc ~= nil) ~= (b.perConc ~= nil) then return a.perConc ~= nil end
        if ca ~= cb then return ca > cb end
        return ByProfit(a, b)
    end },
    { key = "reward", label = "SORT_REWARD", compare = function(a, b)
        if a.rewardValue ~= b.rewardValue then return a.rewardValue > b.rewardValue end
        return a.left < b.left
    end },
    { key = "time", label = "SORT_TIME", compare = function(a, b)
        if a.left ~= b.left then return a.left < b.left end
        return ByProfit(a, b)
    end },
}

local function Setting(key)
    return ns.db and ns.db.settings[key]
end

local function Find(list, key)
    for _, entry in ipairs(list) do
        if entry.key == key then return entry end
    end
    return list[1]
end

-- Small rounded-looking buttons for the chips and the sort button. The
-- border is drawn one screen pixel wide (Util.PixelBorder), so no side
-- goes missing at odd UI scales.
local CHIP_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
}

local function PaintChip(chip)
    if chip.accent then
        -- Values and Queue Orders: buttons to click, not filters, so they
        -- stand out in gold.
        if chip.hover or chip.selected then
            chip:SetBackdropColor(0.55, 0.40, 0.06, 1)
            chip:SetPixelBorderColor(1, 0.9, 0.4, 1)
            chip.Text:SetTextColor(1, 1, 1)
        else
            chip:SetBackdropColor(0.40, 0.29, 0.04, 0.95)
            chip:SetPixelBorderColor(1, 0.82, 0, 1)
            chip.Text:SetTextColor(1, 0.95, 0.75)
        end
    elseif chip.selected then
        chip:SetBackdropColor(0.32, 0.24, 0.05, 0.95)
        chip:SetPixelBorderColor(1, 0.82, 0, 0.9)
        chip.Text:SetTextColor(1, 0.9, 0.5)
    elseif chip.hover then
        chip:SetBackdropColor(0.16, 0.15, 0.13, 0.95)
        chip:SetPixelBorderColor(0.6, 0.52, 0.3, 0.9)
        chip.Text:SetTextColor(1, 1, 1)
    else
        chip:SetBackdropColor(0.08, 0.08, 0.09, 0.9)
        chip:SetPixelBorderColor(0.3, 0.28, 0.24, 0.9)
        chip.Text:SetTextColor(0.85, 0.85, 0.85)
    end
end

local function Chip(parent, onClick)
    local chip = CreateFrame("Button", nil, parent, "BackdropTemplate")
    chip:SetBackdrop(CHIP_BACKDROP)
    Util.PixelBorder(chip)
    chip:SetHeight(20)
    chip.Text = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chip.Text:SetPoint("CENTER")
    chip.SetLabel = function(self, text, padding)
        self.Text:SetText(text)
        self:SetWidth(math.ceil(self.Text:GetStringWidth()) + (padding or 20))
    end
    chip:SetScript("OnEnter", function(self) self.hover = true; PaintChip(self) end)
    chip:SetScript("OnLeave", function(self) self.hover = false; PaintChip(self) end)
    chip:SetScript("OnClick", onClick)
    PaintChip(chip)
    return chip
end

-- Building ---------------------------------------------------------------

function Board:Build(list)
    local panel = CreateFrame("Frame", nil, list)
    panel:SetPoint("TOPLEFT", list, "TOPLEFT", 3, -1)
    panel:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -6, 2)
    panel:SetFrameLevel(list:GetFrameLevel() + 100)
    panel:EnableMouse(true)
    panel:Hide()
    self.panel = panel

    local bar = panel:CreateTexture(nil, "BACKGROUND")
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(BAR_HEIGHT)
    bar:SetColorTexture(0, 0, 0, 0.45)
    local line = panel:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", bar, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(1, 0.82, 0, 0.25)

    self.sortButton = Chip(panel, function(button) Board:SortMenu(button) end)
    -- Whole screen pixels, or the top edge can land between pixels.
    PixelUtil.SetPoint(self.sortButton, "TOPRIGHT", panel, "TOPRIGHT", -8, -6)

    -- Shows or hides the queue panel (UI/QueuePanel.lua).
    self.queueButton = Chip(panel, function() if ns.QueuePanel then ns.QueuePanel:Toggle() end end)
    self.queueButton.accent = true
    PixelUtil.SetPoint(self.queueButton, "RIGHT", self.sortButton, "LEFT", -6, 0)
    self.queueButton:HookScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.QUEUE_CHIP_TITLE, 1, 0.82, 0)
        GameTooltip:AddLine(L.QUEUE_CHIP_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    self.queueButton:HookScript("OnLeave", GameTooltip_Hide)

    -- What concentration and Moxie are worth to you (UI/Values.lua).
    self.valuesButton = Chip(panel, function(button) ns.Values:Toggle(button) end)
    self.valuesButton.accent = true
    PixelUtil.SetPoint(self.valuesButton, "RIGHT", self.queueButton, "LEFT", -6, 0)
    self.valuesButton:SetLabel(L.VALUES_BUTTON)
    PaintChip(self.valuesButton)
    self.valuesButton:HookScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.VALUES_TITLE, 1, 0.82, 0)
        GameTooltip:AddLine(L.VALUES_BUTTON_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    self.valuesButton:HookScript("OnLeave", GameTooltip_Hide)

    self.summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.summary:SetPoint("TOPLEFT", 10, -9)
    self.summary:SetPoint("RIGHT", self.valuesButton, "LEFT", -10, 0)
    self.summary:SetJustifyH("LEFT")
    self.summary:SetWordWrap(false)

    for _, filter in ipairs(FILTERS) do
        local chip = Chip(panel, function()
            ns.db.settings.filter = filter.key
            Board.scroll = 0
            Board:Refresh()
        end)
        chip.filter = filter
        self.chips[#self.chips + 1] = chip
    end

    -- The scrolling card area, with a slim scroll bar of our own.
    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 8, -(BAR_HEIGHT + 8))
    scroll:SetPoint("BOTTOMRIGHT", -18, 6)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) Board:ScrollTo(Board.scroll - delta * WHEEL_STEP) end)
    scroll:SetScript("OnSizeChanged", function() if Board.active then Board:Layout() end end)
    self.scrollFrame = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    self.content = content

    local track = panel:CreateTexture(nil, "ARTWORK")
    track:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -7, -(BAR_HEIGHT + 8))
    track:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -7, 6)
    track:SetWidth(4)
    track:SetColorTexture(1, 1, 1, 0.06)
    self.track = track

    local thumb = CreateFrame("Button", nil, panel)
    thumb:SetWidth(6)
    thumb.Texture = thumb:CreateTexture(nil, "OVERLAY")
    thumb.Texture:SetAllPoints()
    thumb.Texture:SetColorTexture(0.75, 0.62, 0.3, 0.75)
    thumb:SetScript("OnMouseDown", function(self)
        local _, y = GetCursorPosition()
        self.dragFrom, self.dragScroll = y / self:GetEffectiveScale(), Board.scroll
        self:SetScript("OnUpdate", function(me)
            local _, now = GetCursorPosition()
            local moved = me.dragFrom - now / me:GetEffectiveScale()
            local range = Board:MaxScroll()
            local travel = track:GetHeight() - me:GetHeight()
            if travel > 0 then Board:ScrollTo(me.dragScroll + moved * range / travel) end
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    self.thumb = thumb

    self.divider = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.divider:SetText(L.DIVIDER_UNLEARNED)
    self.dividerLeft = content:CreateTexture(nil, "ARTWORK")
    self.dividerLeft:SetHeight(1)
    self.dividerLeft:SetColorTexture(1, 0.82, 0, 0.3)
    self.dividerRight = content:CreateTexture(nil, "ARTWORK")
    self.dividerRight:SetHeight(1)
    self.dividerRight:SetColorTexture(1, 0.82, 0, 0.3)

    self.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.empty:SetPoint("TOP", scroll, "TOP", 0, -40)
end

-- The Cards / Classic switch, beside the order type tabs. Only on the
-- Patron tab.
function Board:BuildToggle(page)
    local button = CreateFrame("Button", nil, page.BrowseFrame, "UIPanelButtonTemplate")
    button:SetSize(110, 22)
    button:SetPoint("LEFT", page.BrowseFrame.PersonalOrdersButton, "RIGHT", 12, 0)
    button:SetScript("OnClick", function()
        ns.db.settings.classic = not ns.db.settings.classic
        Board:Decide(page:GetBrowseType())
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.ADDON_TITLE, 1, 0.82, 0)
        GameTooltip:AddLine(Setting("classic") and L.TOGGLE_TO_CARDS_TIP or L.TOGGLE_TO_CLASSIC_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    self.toggle = button
end

function Board:UpdateToggle()
    local page = self.page
    if not (page and self.toggle) then return end
    self.toggle:SetShown(page.orderType ~= nil)
    self.toggle:SetText(Setting("classic") and L.TOGGLE_CARDS or L.TOGGLE_CLASSIC)
end

-- Showing and hiding --------------------------------------------------------

local function BlizzardParts(list)
    return { list.ScrollBox, list.ScrollBar, list.HeaderContainer, list.ResultsText }
end

function Board:Activate()
    if self.active then return end
    self.active = true
    for _, part in ipairs(BlizzardParts(self.list)) do part:SetAlpha(0) end
    self.panel:Show()
end

function Board:Deactivate()
    if not self.active then return end
    self.active = false
    for _, part in ipairs(BlizzardParts(self.list)) do part:SetAlpha(1) end
    if ns.Values then ns.Values:Hide() end
    self.panel:Hide()
    GameTooltip:Hide()
end

-- Cards for a flat list on any order tab, unless Classic is chosen.
-- (Public orders grouped by item keep Blizzard's view.)
function Board:Decide(browseType)
    local page = self.page
    local flat = OrderBrowseType and OrderBrowseType.Flat
    local wanted = page.orderType ~= nil
        and (flat == nil or browseType == flat)
        and not Setting("classic")
    if wanted then
        self:Activate()
        self:Refresh(true)
    else
        self:Deactivate()
    end
    self:UpdateToggle()
end

function Board:Open(rec)
    if self.page and rec.order then
        GameTooltip:Hide()
        self.page:ViewOrder(rec.order)
    end
end

-- Drawing ---------------------------------------------------------------

-- The game empties its order list while it fetches a new one: after an
-- order is crafted, for example, and crafting (CraftSim most of all) fires
-- bursts of item and currency events in that gap. So only Blizzard's own
-- results (ShowGeneric, fresh = true) may empty the board; any other
-- refresh that reads an empty list keeps the cards it had and looks again
-- a moment later, and refreshes wait while a request is in flight.
local RECHECK_DELAY, RECHECKS = 1, 5

function Board:Refresh(fresh)
    if not self.active then return end
    if fresh then self.waiting = false end
    local records = Orders.All()
    if not fresh and #records == 0 and self.records and #self.records > 0 then
        self:Recheck()
        self:Layout()
        return
    end
    self.rechecks = 0
    self.panel:SetAlpha(1)
    self.records = records
    if ns.Queue then ns.Queue.Update(records, self.page and self.page.orderType, fresh) end
    self:Layout()
end

-- After a hand-in from the queue the game's list still has the order, so
-- its card goes at once and the tab's last search is sent again, as its
-- Search button would. The game turns requests away for a few seconds
-- after the last one, so it waits a moment, tries once more if nothing
-- came back, and never leaves the cards dimmed.
local AGAIN_DELAY, AGAIN_TRIES, AGAIN_WAIT = 1.5, 2, 4

function Board:RequestAgain(doneKey)
    if doneKey and self.records then
        for i = #self.records, 1, -1 do
            if self.records[i].key == doneKey then table.remove(self.records, i) end
        end
        if self.active then self:Layout() end
    end
    self:SendAgain(AGAIN_TRIES)
end

function Board:SendAgain(tries)
    local page, request = self.page, self.lastRequest
    if not (page and request and page.BrowseFrame and page.BrowseFrame:IsVisible()) then return end
    C_Timer.After(AGAIN_DELAY, function()
        if not page.BrowseFrame:IsVisible() then return end
        local ok = pcall(page.SendOrderRequest, page, request)
        C_Timer.After(AGAIN_WAIT, function()
            if not Board.waiting then return end
            if ok and tries > 1 then
                Board:SendAgain(tries - 1)
            else
                Board.waiting = false
                if Board.active then Board:Refresh() end
            end
        end)
    end)
end

function Board:Recheck()
    if self.recheckPending or (self.rechecks or 0) >= RECHECKS then return end
    self.recheckPending = true
    self.rechecks = (self.rechecks or 0) + 1
    C_Timer.After(RECHECK_DELAY, function()
        Board.recheckPending = false
        if not Board.waiting then Board:Refresh() end
    end)
end

-- Throttled refresh for bursts of item data and currency events. While
-- an order request is in flight it only redraws what it has.
function Board:Soon()
    if not self.active or self.pending then return end
    self.pending = true
    C_Timer.After(0.3, function()
        Board.pending = false
        if Board.waiting then
            if Board.active then Board:Layout() end
        else
            Board:Refresh()
        end
    end)
end

function Board:Layout()
    local records = self.records or {}
    local width = self.scrollFrame:GetWidth()
    if width < 100 then
        C_Timer.After(0, function() Board:Layout() end)
        return
    end

    -- Filter and sort: learned recipes first, unlearned under a divider.
    local filter = Find(FILTERS, Setting("filter"))
    local sort = Find(SORTS, Setting("sort"))
    local shown = {}
    for _, rec in ipairs(records) do
        if filter.test(rec) then shown[#shown + 1] = rec end
    end
    table.sort(shown, function(a, b)
        if a.learned ~= b.learned then return a.learned end
        return sort.compare(a, b)
    end)
    -- What the queue panel's Queue all goes through.
    self.shown = shown

    local best
    for _, rec in ipairs(records) do
        if rec.reachable and rec.profit and rec.profit > 0 and (not best or rec.profit > best.profit) then
            best = rec
        end
    end

    local cardWidth = math.floor((width - GAP * (COLUMNS - 1)) / COLUMNS)
    local y, column, dividerAt = 0, 0, nil
    for i, rec in ipairs(shown) do
        if not rec.learned and not dividerAt then
            if column > 0 then y, column = y + CARD_HEIGHT + GAP, 0 end
            dividerAt = y
            y = y + DIVIDER_HEIGHT
        end
        local card = self.cards[i]
        if not card then
            card = Card.Create(self.content)
            self.cards[i] = card
        end
        card:SetSize(cardWidth, CARD_HEIGHT)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", self.content, "TOPLEFT", column * (cardWidth + GAP), -y)
        card:SetRecord(rec, rec == best)
        card:Show()
        column = column + 1
        if column == COLUMNS then y, column = y + CARD_HEIGHT + GAP, 0 end
    end
    if column > 0 then y = y + CARD_HEIGHT + GAP end
    for i = #shown + 1, #self.cards do self.cards[i]:Hide() end

    local showDivider = dividerAt ~= nil and #shown > 0 and shown[1].learned
    self.divider:SetShown(showDivider)
    self.dividerLeft:SetShown(showDivider)
    self.dividerRight:SetShown(showDivider)
    if showDivider then
        self.divider:ClearAllPoints()
        self.divider:SetPoint("TOP", self.content, "TOPLEFT", width / 2, -(dividerAt + 6))
        self.dividerLeft:ClearAllPoints()
        self.dividerLeft:SetPoint("LEFT", self.content, "TOPLEFT", 0, -(dividerAt + 12))
        self.dividerLeft:SetPoint("RIGHT", self.divider, "LEFT", -10, 0)
        self.dividerRight:ClearAllPoints()
        self.dividerRight:SetPoint("LEFT", self.divider, "RIGHT", 10, 0)
        self.dividerRight:SetPoint("RIGHT", self.content, "TOPLEFT", width, -(dividerAt + 12))
    end

    self.content:SetSize(width, math.max(y - GAP, 1))
    self.empty:SetShown(#shown == 0)
    self.empty:SetText(#records == 0 and L.EMPTY_NONE or L.EMPTY_FILTERED)

    self:UpdateBar(records, filter, sort)
    self:ScrollTo(self.scroll)
end

function Board:UpdateBar(records, filter, sort)
    local craftable, onOffer = 0, 0
    for _, rec in ipairs(records) do
        if rec.reachable then
            craftable = craftable + 1
            if rec.profit and rec.profit > 0 then onOffer = onOffer + rec.profit end
        end
    end
    local parts = {
        L.SUMMARY_ORDERS:format(#records),
        L.SUMMARY_CRAFTABLE:format(craftable),
    }
    if onOffer > 0 then
        parts[#parts + 1] = Util.Paint("green", L.SUMMARY_ON_OFFER:format(Util.Money(onOffer)))
    end
    local have, most = Orders.Concentration(records)
    if have then
        parts[#parts + 1] = L.SUMMARY_CONC:format(have, most or have)
    end
    if self.page and self.page.orderType == Enum.CraftingOrderType.Public and records[1] then
        local claims = Orders.ClaimsLeft(records[1].profession)
        if claims then parts[#parts + 1] = Util.Paint(claims > 0 and "white" or "red", L.SUMMARY_CLAIMS:format(claims)) end
    end
    if not ns.Pricing.Available() then
        parts[#parts + 1] = Util.Paint("grey", L.SUMMARY_NO_PRICES)
    end
    self.summary:SetText(table.concat(parts, Util.Paint("grey", "   |   ")))

    self.sortButton:SetLabel(L.SORT_LABEL:format(L[sort.label]))
    local queued = ns.Queue and ns.Queue.Count() or 0
    self.queueButton:SetLabel(queued > 0 and L.QUEUE_CHIP_COUNT:format(queued) or L.QUEUE_CHIP)
    self.queueButton.selected = ns.QueuePanel and ns.QueuePanel.frame and ns.QueuePanel.frame:IsShown() or false
    PaintChip(self.queueButton)

    -- The chips are laid out roomy, then tighter when the row would run past the panel's right
    -- edge: Blizzard's list clips what sticks out, which cut the last chip's right border off.
    local labels, textWidth = {}, 0
    for i, chip in ipairs(self.chips) do
        local count = 0
        for _, rec in ipairs(records) do
            if chip.filter.test(rec) then count = count + 1 end
        end
        labels[i] = L[chip.filter.label] .. "  " .. Util.Paint("grey", count)
        chip:SetLabel(labels[i], 0)
        textWidth = textWidth + chip:GetWidth()
    end
    -- Keep clear of the list's right edge, which clips what sticks out.
    local room = (self.panel:GetWidth() or 0) - 16 - 8
    local padding, gap = 20, 6
    if room > 0 and textWidth + #self.chips * padding + (#self.chips - 1) * gap > room then
        padding, gap = 12, 4
    end
    local x = 8
    for i, chip in ipairs(self.chips) do
        chip:SetLabel(labels[i], padding)
        chip.selected = chip.filter == filter
        PaintChip(chip)
        chip:ClearAllPoints()
        PixelUtil.SetPoint(chip, "TOPLEFT", self.panel, "TOPLEFT", x, -30)
        x = x + chip:GetWidth() + gap
    end
end

function Board:SortMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.SORT_TITLE)
        for _, sort in ipairs(SORTS) do
            root:CreateRadio(L[sort.label],
                function() return Find(SORTS, Setting("sort")) == sort end,
                function()
                    ns.db.settings.sort = sort.key
                    Board.scroll = 0
                    Board:Layout()
                end)
        end
    end)
end

-- Scrolling -------------------------------------------------------------

function Board:MaxScroll()
    return math.max(0, self.content:GetHeight() - self.scrollFrame:GetHeight())
end

function Board:ScrollTo(offset)
    local most = self:MaxScroll()
    self.scroll = math.max(0, math.min(offset or 0, most))
    self.scrollFrame:SetVerticalScroll(self.scroll)

    local trackHeight = self.track:GetHeight()
    if most <= 0 or trackHeight <= 0 then
        self.thumb:Hide()
        self.track:Hide()
        return
    end
    self.track:Show()
    local visible = self.scrollFrame:GetHeight()
    local thumbHeight = math.max(24, trackHeight * visible / (visible + most))
    self.thumb:SetHeight(thumbHeight)
    self.thumb:ClearAllPoints()
    self.thumb:SetPoint("TOP", self.track, "TOP", 0, -(trackHeight - thumbHeight) * self.scroll / most)
    self.thumb:Show()
end

-- Setup -----------------------------------------------------------------

function Board:Install()
    local page = ProfessionsFrame and ProfessionsFrame.OrdersPage
    if self.page or not (page and page.BrowseFrame and page.BrowseFrame.OrderList) then return end
    self.page = page
    self.list = page.BrowseFrame.OrderList
    self:Build(self.list)
    self:BuildToggle(page)

    hooksecurefunc(page, "ShowGeneric", function(_, _, browseType)
        Board:Decide(browseType)
        -- Patron lists are short, but fetch any remaining page so every
        -- order gets a card. Blizzard clears its request after this hook.
        C_Timer.After(0, function()
            if Board.active and page.expectMoreRows then page:RequestMoreOrders() end
        end)
    end)
    hooksecurefunc(page, "SetCraftingOrderType", function()
        -- A new tab: its list arrives through ShowGeneric, which decides
        -- whether the cards show.
        Board:UpdateToggle()
    end)
    hooksecurefunc(page, "SendOrderRequest", function(_, request)
        Board.waiting = true
        if Board.active then Board.panel:SetAlpha(0.45) end
        -- The tab's own search (first page only, not "more rows").
        if type(request) == "table" and (request.offset or 0) == 0 then Board.lastRequest = request end
    end)
    -- Back on the list after viewing (or crafting) an order: read it again.
    if page.BrowseFrame.HookScript then
        page.BrowseFrame:HookScript("OnShow", function() Board:Soon() end)
    end
    self:UpdateToggle()
    if ns.QueuePanel then ns.QueuePanel:Refresh() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("CRAFTINGORDERS_UPDATE_REWARDS")
events:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "CRAFTINGORDERS_UPDATE_REWARDS" then
        local rewards, orderID = ...
        Orders.SetRewards(orderID, rewards)
    end
    Board:Soon()
end)

EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", function()
    Board:Install()
end)
