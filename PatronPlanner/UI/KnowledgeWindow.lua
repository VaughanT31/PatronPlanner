-- Patron Planner - the knowledge window: for each of your professions the
-- knowledge still to earn this week, the one-time treasures still to find
-- (click one for a waypoint), and your unspent points; or every character
-- at a glance. Opens from the Knowledge chip, the minimap button
-- (middle-click) or /pp knowledge.
--
--  +-- Knowledge -------------- resets in 3d 4h - [x] +
--  | [This character] [All characters]                 |
--  | Tailoring            4 of 9 left | 12 unspent     |
--  |   v Thalassian Treatise          1   done         |
--  |   o Trainer's weekly quest       2   in your bags |
--  |   Treasures, 5 of 8 found                         |
--  |   o Satin Throw Pillow  Slayer's Rise 61.6, 85.0  |
--  +---------------------------------------------------+

local _, ns = ...
local L, Util, Knowledge = ns.L, ns.Util, ns.Knowledge

local KnowledgeWindow = { rows = {}, scroll = 0, view = "me" }
ns.KnowledgeWindow = KnowledgeWindow

local WIDTH = 420
local HEIGHT = 500
local ROW = 20
local TOP = 58
local FOOTER = 46         -- room under the list for the two-line footer

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}
local DONE = "|TInterface\\RaidFrame\\ReadyCheck-Ready:13|t"
local OPEN = "|TInterface\\COMMON\\Indicator-Gray:13|t"

local function Row(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW)
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
    row.Right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Right:SetPoint("RIGHT", -4, 0)
    row.Right:SetJustifyH("RIGHT")
    row.Points = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Points:SetPoint("RIGHT", -150, 0)
    row.Points:SetJustifyH("RIGHT")
    row.Left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Left:SetPoint("LEFT", 4, 0)
    row.Left:SetPoint("RIGHT", row.Points, "LEFT", -8, 0)
    row.Left:SetJustifyH("LEFT")
    row.Left:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
        if not (self.itemID or self.tip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemID then
            GameTooltip:SetItemByID(self.itemID)
        else
            GameTooltip:AddLine(self.tipTitle or "", 1, 0.82, 0)
        end
        if self.tip then GameTooltip:AddLine(self.tip, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
        if self.treasure then Knowledge.Waypoint(self.treasure) end
    end)
    return row
end

local function Tab(parent, label, view)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(130, 20)
    button:SetText(label)
    button:SetScript("OnClick", function()
        KnowledgeWindow.view = view
        KnowledgeWindow.scroll = 0
        KnowledgeWindow:Refresh()
    end)
    return button
end

function KnowledgeWindow:Build()
    local frame = CreateFrame("Frame", "PatronPlannerKnowledge", UIParent, "BackdropTemplate")
    frame:SetBackdrop(BACKDROP)
    Util.CrispEdges(frame)
    frame:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
    frame:SetBackdropBorderColor(1, 0.82, 0, 0.45)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", -300, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "PatronPlannerKnowledge")
    self.frame = frame

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Title:SetPoint("TOPLEFT", 12, -10)
    frame.Title:SetText(L.KP_TITLE)
    frame.Reset = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.Reset:SetPoint("TOPRIGHT", -30, -12)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() frame:Hide() end)

    self.meTab = Tab(frame, L.KP_TAB_ME, "me")
    self.meTab:SetPoint("TOPLEFT", 10, -30)
    self.altsTab = Tab(frame, L.KP_TAB_ALTS, "alts")
    self.altsTab:SetPoint("LEFT", self.meTab, "RIGHT", 6, 0)

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 10, -TOP)
    scroll:SetPoint("BOTTOMRIGHT", -10, FOOTER)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) KnowledgeWindow:ScrollTo(KnowledgeWindow.scroll - delta * ROW * 3) end)
    self.scrollFrame = scroll
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 20, 1)
    scroll:SetScrollChild(content)
    self.content = content

    local line = frame:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT", 10, FOOTER - 4)
    line:SetPoint("BOTTOMRIGHT", -10, FOOTER - 4)
    line:SetHeight(1)
    line:SetColorTexture(1, 0.82, 0, 0.25)

    frame.Footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.Footer:SetPoint("BOTTOMLEFT", 12, 10)
    frame.Footer:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    frame.Footer:SetJustifyH("LEFT")

    frame:SetScript("OnShow", function() KnowledgeWindow:Refresh() end)
end

local function Points(n)
    if not n or n <= 0 then return "" end
    return L.KP_POINTS:format(math.floor(n + 0.5))
end

-- The line on the right: what to do about it.
-- Every one of these is an item you use for the knowledge, so one still in
-- the bags is points waiting.
local function Doing(line)
    local inBags = (line.inBags or 0) > 0
    if line.kind == "gather" then
        local text = line.done and Util.Paint("green", L.KP_DONE) or L.KP_GATHERED:format(line.have, line.need)
        if inBags then text = text .. "  " .. Util.Paint("amber", L.KP_USE_N:format(line.inBags)) end
        return text
    end
    -- A second treatise waits for next week; a looted drop still needs using.
    local once = line.kind == "treatise" or line.kind == "notes"
    if line.done and once then return Util.Paint("green", L.KP_DONE) end
    if inBags then return Util.Paint("amber", L.KP_IN_BAGS) end
    if line.done then return Util.Paint("green", L.KP_DONE) end
    return Util.Paint("grey", L["KP_HOW_" .. line.kind:upper()] or "")
end

local function ItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if not name then C_Item.RequestLoadItemDataByID(itemID) end
    return name or "..."
end

-- The item's icon before its name.
local function ItemIcon(itemID)
    local icon = itemID and C_Item.GetItemIconByID(itemID)
    return icon and ("|T" .. icon .. ":14:14:0:0:64:64:5:59:5:59|t ") or ""
end

-- Rows for this character: { left, points, right, itemID, treasure, tip, heading }.
local function MeLines()
    local lines = {}
    local function Add(line) lines[#lines + 1] = line end
    local professions = Knowledge.MyProfessions()
    if #professions == 0 then
        Add({ left = Util.Paint("grey", L.KP_NONE) })
        return lines
    end
    for index, base in ipairs(professions) do
        local status = Knowledge.Status(base)
        if index > 1 then Add({ left = " " }) end
        local summary = L.KP_LEFT:format(math.floor(status.weeklyLeft + 0.5), status.weeklyTotal)
        if status.unspent then summary = summary .. "  |  " .. L.KP_UNSPENT:format(status.unspent) end
        Add({ heading = true, left = Util.Paint("gold", status.name), right = summary,
            tipTitle = status.name, tip = status.remaining and L.KP_REMAINING_TIP:format(status.remaining) or L.KP_OPEN_TIP })
        for _, line in ipairs(status.weekly) do
            local label = line.label or (line.itemID and ItemName(line.itemID)) or "?"
            Add({ left = "  " .. (line.done and DONE or OPEN) .. " " .. ItemIcon(line.itemID) .. label, points = Points(line.points),
                right = Doing(line), itemID = line.itemID, tip = L["KP_TIP_" .. line.kind:upper()] })
        end
        local found = #status.treasures - status.treasuresLeft
        Add({ left = "  " .. Util.Paint("white", L.KP_TREASURES:format(found, #status.treasures)),
            right = status.treasuresLeft > 0 and Util.Paint("grey", L.KP_CLICK_WAYPOINT) or "" })
        for _, line in ipairs(status.treasures) do
            local t = line.treasure
            local where = L.KP_WHERE:format(Knowledge.Zone(t.map), t.x, t.y)
            if line.done then
                Add({ left = "  " .. DONE .. " " .. Util.Paint("grey", line.label), right = Util.Paint("grey", where) })
            else
                Add({ left = "  " .. OPEN .. " " .. line.label, points = Points(line.points), right = where,
                    treasure = t, tipTitle = line.label, tip = L.KP_TIP_TREASURE })
            end
        end
    end
    return lines
end

local function AltsLines()
    local lines = {}
    local list = Knowledge.Alts()
    if #list == 0 then
        lines[1] = { left = Util.Paint("grey", L.KP_NO_ALTS) }
        return lines
    end
    for index, char in ipairs(list) do
        if index > 1 then lines[#lines + 1] = { left = " " } end
        local color = char.class and RAID_CLASS_COLORS[char.class]
        local name = color and color:WrapTextInColorCode(char.key) or char.key
        lines[#lines + 1] = { heading = true, left = name, right = char.newWeek and Util.Paint("amber", L.KP_NEW_WEEK) or "" }
        local bases = {}
        for base in pairs(char.profs) do bases[#bases + 1] = base end
        table.sort(bases, function(a, b) return (Knowledge.PROFESSIONS[a].name) < (Knowledge.PROFESSIONS[b].name) end)
        for _, base in ipairs(bases) do
            local saved = char.profs[base]
            local left = char.newWeek and saved.weeklyTotal or saved.weeklyLeft
            local parts = { L.KP_LEFT:format(math.floor((left or 0) + 0.5), saved.weeklyTotal or 0) }
            if (saved.treasuresLeft or 0) > 0 then parts[#parts + 1] = L.KP_ALT_TREASURES:format(saved.treasuresLeft) end
            if saved.unspent and saved.unspent > 0 then parts[#parts + 1] = Util.Paint("amber", L.KP_UNSPENT:format(saved.unspent)) end
            lines[#lines + 1] = { left = "  " .. Knowledge.PROFESSIONS[base].name, right = table.concat(parts, "  |  ") }
        end
    end
    return lines
end

function KnowledgeWindow:Refresh()
    if not (self.frame and self.frame:IsShown()) then return end
    Knowledge.Save()
    local me = self.view == "me"
    self.meTab:SetEnabled(not me)
    self.altsTab:SetEnabled(me)
    local left = C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
    self.frame.Reset:SetText(left and L.KP_RESETS:format(SecondsToTime(left, true)) or "")
    self.frame.Footer:SetText(me and L.KP_FOOTER or L.KP_FOOTER_ALTS)

    local lines = me and MeLines() or AltsLines()
    for i, line in ipairs(lines) do
        local row = self.rows[i]
        if not row then
            row = Row(self.content)
            self.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(i - 1) * ROW)
        row:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)
        row.Left:SetFontObject(line.heading and "GameFontNormal" or "GameFontHighlightSmall")
        row.Left:SetText(line.left or "")
        row.Points:SetText(line.points or "")
        row.Right:SetText(line.right or "")
        row.itemID, row.treasure, row.tip, row.tipTitle = line.itemID, line.treasure, line.tip, line.tipTitle
        row:EnableMouse(line.itemID ~= nil or line.tip ~= nil)
        row:Show()
    end
    for i = #lines + 1, #self.rows do self.rows[i]:Hide() end
    self.content:SetHeight(math.max(1, #lines * ROW))
    self:ScrollTo(self.scroll)
end

function KnowledgeWindow:ScrollTo(offset)
    local most = math.max(0, self.content:GetHeight() - self.scrollFrame:GetHeight())
    self.scroll = math.max(0, math.min(offset or 0, most))
    self.scrollFrame:SetVerticalScroll(self.scroll)
end

-- /pp kpscan: the scan in a box to copy (Ctrl+A, Ctrl+C).
function KnowledgeWindow:ShowScan()
    local box = self.scanBox
    if not box then
        box = CreateFrame("Frame", "PatronPlannerKnowledgeScan", UIParent, "BackdropTemplate")
        box:SetBackdrop(BACKDROP)
        box:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
        box:SetBackdropBorderColor(1, 0.82, 0, 0.45)
        box:SetSize(360, 420)
        box:SetPoint("CENTER")
        box:SetFrameStrata("DIALOG")
        box:EnableMouse(true)
        tinsert(UISpecialFrames, "PatronPlannerKnowledgeScan")
        local close = CreateFrame("Button", nil, box, "UIPanelCloseButtonNoScripts")
        close:SetSize(22, 22)
        close:SetPoint("TOPRIGHT", -2, -2)
        close:SetScript("OnClick", function() box:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -28)
        scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        box.Edit = CreateFrame("EditBox", nil, scroll)
        box.Edit:SetMultiLine(true)
        box.Edit:SetFontObject("ChatFontNormal")
        box.Edit:SetWidth(300)
        box.Edit:SetAutoFocus(false)
        box.Edit:SetScript("OnEscapePressed", function() box:Hide() end)
        scroll:SetScrollChild(box.Edit)
        self.scanBox = box
    end
    box.Edit:SetText(Knowledge.Scan())
    box:Show()
    box.Edit:SetFocus()
    box.Edit:HighlightText()
end

function KnowledgeWindow:Toggle()
    if not self.frame then self:Build() end
    self.frame:SetShown(not self.frame:IsShown())
end

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
local pending = false
events:SetScript("OnEvent", function()
    if pending or not (KnowledgeWindow.frame and KnowledgeWindow.frame:IsShown()) then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        KnowledgeWindow:Refresh()
    end)
end)
