-- Patron Planner - the minimap button: left-click opens the options,
-- right-click the shopping list, Shift-click shows or hides the queue
-- panel. Drag it around the minimap. /pp minimap hides or shows it.

local _, ns = ...
local L, Util, Queue, Shopping = ns.L, ns.Util, ns.Queue, ns.Shopping

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local ICON = "Interface\\AddOns\\PatronPlanner\\icon"
local RADIAN = math.pi / 180
local button

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
    return y > 0 and math.pi / 2 or (y < 0 and -math.pi / 2 or 0)
end

local function Place()
    local angle = ns.db.settings.minimapAngle or 200
    local radius = (Minimap:GetWidth() / 2) + 6
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(angle * RADIAN), radius * math.sin(angle * RADIAN))
end

local function Tooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L.ADDON_TITLE)
    local count = Queue.Count()
    if count > 0 then
        local _, profit = Queue.Totals()
        GameTooltip:AddLine(L.MINIMAP_QUEUE:format(count) .. (profit and ("  " .. Util.Money(profit)) or ""), 1, 1, 1)
        local toBuy, cost = Shopping.Summary()
        if toBuy > 0 then
            GameTooltip:AddLine(L.QUEUE_TO_BUY:format(toBuy, cost and Util.Money(cost) or "?"), 1, 1, 1)
        end
    else
        GameTooltip:AddLine(L.MINIMAP_NO_QUEUE, 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.MINIMAP_LEFT, 0.9, 0.9, 0.9)
    GameTooltip:AddLine(L.MINIMAP_RIGHT, 0.9, 0.9, 0.9)
    GameTooltip:AddLine(L.MINIMAP_SHIFT, 0.9, 0.9, 0.9)
    GameTooltip:AddLine(L.MINIMAP_DRAG, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function Create()
    button = CreateFrame("Button", "PatronPlannerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON)
    local mask = button:CreateMaskTexture()
    mask:SetAllPoints(icon)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(mask)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local centerX, centerY = Minimap:GetCenter()
            local cursorX, cursorY = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.db.settings.minimapAngle = Atan2(cursorY / scale - centerY, cursorX / scale - centerX) / RADIAN
            Place()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnClick", function(_, mouse)
        GameTooltip:Hide()
        if IsShiftKeyDown() then
            if ns.QueuePanel then ns.QueuePanel:Toggle() end
        elseif mouse == "RightButton" then
            if ns.ShoppingList then ns.ShoppingList:Toggle() end
        elseif ns.Options and ns.Options.Open then
            ns.Options.Open()
        end
    end)
    button:SetScript("OnEnter", Tooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
end

function MinimapButton.Refresh()
    if not ns.db then return end
    if ns.db.settings.minimapHidden then
        if button then button:Hide() end
        return
    end
    if not button then Create() end
    button:Show()
end

function MinimapButton.Toggle()
    ns.db.settings.minimapHidden = not ns.db.settings.minimapHidden
    MinimapButton.Refresh()
    Util.Say(ns.db.settings.minimapHidden and L.MINIMAP_HIDDEN or L.MINIMAP_SHOWN)
end
