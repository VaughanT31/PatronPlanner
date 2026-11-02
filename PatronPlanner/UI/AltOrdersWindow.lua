-- Patron Planner - which character has good patron orders waiting, from
-- what each one last saw (Data/AltOrders.lua). /pp alts or the Alts chip.
--
--  +-- Orders on your characters ------- [x] -+
--  | Zed-Draenor                       1,240g |
--  |  Tailoring: 6 orders, 4 you can craft    |
--  |    [i] Sunfire Robe        2d       640g |
--  +------------------------------------------+

local _, ns = ...
local L, Util, AltOrders = ns.L, ns.Util, ns.AltOrders

local AltOrdersWindow = { rows = {}, scroll = 0 }
ns.AltOrdersWindow = AltOrdersWindow

local WIDTH = 380
local HEIGHT = 420
local ROW = 20
local TOP_ORDERS = 3

local function Row(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW)
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(16, 16)
    row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.Right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Right:SetPoint("RIGHT", -4, 0)
    row.Right:SetJustifyH("RIGHT")
    row.Left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Left:SetPoint("RIGHT", row.Right, "LEFT", -8, 0)
    row.Left:SetJustifyH("LEFT")
    row.Left:SetWordWrap(false)
    return row
end

function AltOrdersWindow:Build()
    local frame = CreateFrame("Frame", "PatronPlannerAltOrders", UIParent, "BackdropTemplate")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    Util.PixelBorder(frame)
    frame:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    frame:SetPixelBorderColor(1, 0.82, 0, 0.45)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", -200, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "PatronPlannerAltOrders")
    self.frame = frame

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Title:SetPoint("TOPLEFT", 12, -10)
    frame.Title:SetText(L.ALTS_TITLE)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 10, -32)
    scroll:SetPoint("BOTTOMRIGHT", -10, 34)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) AltOrdersWindow:ScrollTo(AltOrdersWindow.scroll - delta * ROW * 2) end)
    self.scrollFrame = scroll
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 20, 1)
    scroll:SetScrollChild(content)
    self.content = content

    frame.Empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.Empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 4, -8)
    frame.Empty:SetPoint("RIGHT", scroll, "RIGHT", -4, 0)
    frame.Empty:SetJustifyH("LEFT")
    frame.Empty:SetText(L.ALTS_EMPTY)

    frame.Note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.Note:SetPoint("BOTTOMLEFT", 12, 8)
    frame.Note:SetPoint("BOTTOMRIGHT", -12, 8)
    frame.Note:SetJustifyH("LEFT")
    frame.Note:SetText(L.ALTS_NOTE)

    frame:SetScript("OnShow", function() AltOrdersWindow:Refresh() end)
end

local function ClassName(key, class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return color and ("|c%s%s|r"):format(color.colorStr, key) or key
end

function AltOrdersWindow:Refresh()
    if not (self.frame and self.frame:IsShown()) then return end
    local full = ns.db.settings.showCopper
    local now = GetServerTime()
    local index, y = 0, 0

    local function Line(indent, icon, left, right)
        index = index + 1
        local row = self.rows[index]
        if not row then
            row = Row(self.content)
            self.rows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)
        row.Icon:ClearAllPoints()
        row.Icon:SetPoint("LEFT", indent, 0)
        row.Icon:SetShown(icon ~= nil)
        row.Icon:SetTexture(icon or 134400)
        row.Left:ClearAllPoints()
        row.Left:SetPoint("LEFT", indent + (icon and 20 or 0), 0)
        row.Left:SetPoint("RIGHT", row.Right, "LEFT", -8, 0)
        row.Left:SetText(left)
        row.Right:SetText(right or "")
        row:Show()
        y = y + ROW
    end

    local list = AltOrders.List()
    for _, character in ipairs(list) do
        Line(0, nil, ClassName(character.key, character.class),
            character.profit > 0 and Util.Paint("green", Util.Money(character.profit, full)) or "")
        for _, profession in ipairs(character.professions) do
            Line(8, nil, L.ALTS_PROFESSION:format(profession.name or "?", profession.count, profession.craftable),
                Util.Paint("grey", L.ALTS_SEEN:format(Util.TimeLeft(now - (profession.at or now)))))
            for i = 1, math.min(TOP_ORDERS, #profession.orders) do
                local order = profession.orders[i]
                local left = (order.need and order.need > 1 and (Util.QualityIcon(order.need, 12) .. " ") or "") .. (order.name or "?")
                    .. "  " .. Util.Paint(Util.TimeColor(order.expires - now), Util.TimeLeft(order.expires - now))
                if not order.craftable then left = Util.Paint("grey", left) end
                local money = order.profit and Util.Money(order.profit, full) or "?"
                Line(16, order.icon, left, order.profit and order.profit < 0 and Util.Paint("red", money) or money)
            end
            if #profession.orders > TOP_ORDERS then
                Line(16, nil, Util.Paint("grey", L.ALTS_MORE:format(#profession.orders - TOP_ORDERS)))
            end
        end
        y = y + 6
    end
    for i = index + 1, #self.rows do self.rows[i]:Hide() end
    self.content:SetHeight(math.max(1, y))
    self:ScrollTo(self.scroll)
    self.frame.Empty:SetShown(#list == 0)
end

function AltOrdersWindow:ScrollTo(offset)
    local most = math.max(0, self.content:GetHeight() - self.scrollFrame:GetHeight())
    self.scroll = math.max(0, math.min(offset or 0, most))
    self.scrollFrame:SetVerticalScroll(self.scroll)
end

function AltOrdersWindow:Toggle()
    if not self.frame then self:Build() end
    self.frame:SetShown(not self.frame:IsShown())
end
