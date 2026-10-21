-- Patron Planner - game facts the API doesn't give: what a Master's Surplus
-- bag holds (to estimate what Moxie is worth), each profession's Moxie, the
-- first-craft Moxie bonus, and the Ingenuity stat's name in each language.
--
-- Adapted from CraftSim by Florian Schneider (MIT), see
-- ThirdParty/LICENSE-CraftSim.txt.

local _, ns = ...

local Reference = {}
ns.Reference = Reference

-- A Master's Surplus bag costs this much Moxie at the profession vendor.
Reference.SURPLUS_BAG_MOXIE = 600

-- What one bag holds on average: { itemID, quantity }.
local HERBS = {
    { 236767, 35.0 }, -- Tranquility Bloom
    { 236777, 17.5 }, -- Argentleaf
    { 236779, 17.5 }, -- Mana Lily
    { 236771, 17.5 }, -- Sanguithorn
    { 236775, 17.5 }, -- Azeroot
    { 236780, 4.0 },  -- Nocturnal Lotus
    { 251285, 2 },    -- Petrified Root
}
local ORE = {
    { 237361, 45.0 }, -- Refulgent Copper Ore
    { 237363, 25.0 }, -- Umbral Tin Ore
    { 237365, 25.0 }, -- Brilliant Silver Ore
    { 237366, 7.5 },  -- Dazzling Thorium
    { 251285, 2 },    -- Petrified Root
}
local ENCHANTING = {
    { 243600, 60.0 }, -- Eversinging Dust
    { 243603, 25.0 }, -- Radiant Shard
    { 243606, 7.5 },  -- Dawn Crystal
    { 251285, 2 },    -- Petrified Root
}
local LEATHER = {
    { 238512, 35.2 }, -- Void-Tempered Leather
    { 238514, 35.2 }, -- Void-Tempered Scales
    { 238519, 4.5 },  -- Void-Tempered Hide
    { 238521, 4.5 },  -- Void-Tempered Plating
    { 238528, 1.2 },  -- Majestic Claw
    { 238530, 1.2 },  -- Majestic Fin
    { 238529, 1.2 },  -- Majestic Hide
    { 238522, 5.8 },  -- Peerless Plumage
    { 238525, 5.8 },  -- Fantastic Fur
    { 238523, 5.8 },  -- Carving Canine
    { 251285, 2 },    -- Petrified Root
}
local CLOTH = {
    { 237017, 8.0 },  -- Arcanoweave
    { 237016, 8.0 },  -- Sunfire Silk
    { 239200, 3.0 },  -- Arcanoweave Bolt
    { 239202, 3.0 },  -- Sunfire Silk Bolt
    { 236965, 15.0 }, -- Bright Linen
    { 251285, 2.0 },  -- Petrified Root
}

-- Moxie currency ID -> what its surplus bag holds.
Reference.SURPLUS_BAGS = {
    [3256] = HERBS,      -- Alchemy
    [3260] = HERBS,      -- Herbalism
    [3261] = HERBS,      -- Inscription
    [3257] = ORE,        -- Blacksmithing
    [3259] = ORE,        -- Engineering
    [3262] = ORE,        -- Jewelcrafting
    [3264] = ORE,        -- Mining
    [3258] = ENCHANTING, -- Enchanting
    [3263] = LEATHER,    -- Leatherworking
    [3265] = LEATHER,    -- Skinning
    [3266] = CLOTH,      -- Tailoring
}

-- Each profession's Moxie currency (Enum.Profession -> currency ID).
Reference.MOXIE_BY_PROFESSION = {}
if Enum and Enum.Profession then
    local P = Enum.Profession
    for profession, currencyID in pairs({
        Alchemy = 3256, Blacksmithing = 3257, Enchanting = 3258, Engineering = 3259,
        Herbalism = 3260, Inscription = 3261, Jewelcrafting = 3262, Leatherworking = 3263,
        Mining = 3264, Skinning = 3265, Tailoring = 3266,
    }) do
        if P[profession] then Reference.MOXIE_BY_PROFESSION[P[profession]] = currencyID end
    end
end

-- The first craft of a recipe for a patron pays this much extra Moxie.
Reference.FIRST_CRAFT_MOXIE = 10

-- Ingenuity as the game names it in bonusStats, per client language.
Reference.INGENUITY = {
    enUS = "Ingenuity", enGB = "Ingenuity",
    deDE = "Genialität",
    esES = "Ingenio", esMX = "Ingenio",
    frFR = "Inventivité",
    koKR = "독창성",
    ptBR = "Engenhosidade",
    ruRU = "Изобретательность",
    zhCN = "奇思",
}
-- Ingenuity refunds this share of the concentration (perks can add more).
Reference.INGENUITY_REFUND = 0.5
