-- Patron Planner - prices from whichever price addon is installed. Every
-- source is optional: with none, the cards still show quality, time and
-- the gold reward, just no cost or profit.
--
-- Auction Coach joins this list later (AuctionCoachAPI.GetMarketValue).

local _, ns = ...

local Pricing = {}
ns.Pricing = Pricing

local CALLER = "PatronPlanner"

local SOURCES = {
    {
        key = "tsm",
        name = "TradeSkillMaster",
        available = function()
            return TSM_API and TSM_API.GetCustomPriceValue
        end,
        price = function(itemID)
            local itemString = "i:" .. itemID
            return TSM_API.GetCustomPriceValue("DBMarket", itemString)
                or TSM_API.GetCustomPriceValue("DBMinBuyout", itemString)
        end,
    },
    {
        key = "auctionator",
        name = "Auctionator",
        available = function()
            return Auctionator and Auctionator.API and Auctionator.API.v1
                and Auctionator.API.v1.GetAuctionPriceByItemID
        end,
        price = function(itemID)
            return Auctionator.API.v1.GetAuctionPriceByItemID(CALLER, itemID)
        end,
    },
}

-- The source in use: the one picked in settings when it's installed,
-- otherwise the first installed one.
function Pricing.Source()
    local wanted = ns.db and ns.db.settings.priceSource or "auto"
    local first
    for _, source in ipairs(SOURCES) do
        if source.available() then
            if source.key == wanted then return source end
            first = first or source
        end
    end
    return first
end

function Pricing.Available()
    return Pricing.Source() ~= nil
end

-- Copper per item, or nil when there's no source or no price.
function Pricing.Price(itemID)
    if not itemID then return nil end
    local source = Pricing.Source()
    if not source then return nil end
    local ok, value = pcall(source.price, itemID)
    if ok and type(value) == "number" and value > 0 then
        return value
    end
    return nil
end
