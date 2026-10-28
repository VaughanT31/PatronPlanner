-- Patron Planner - Midnight profession knowledge: what each of your
-- professions can still earn this week, the one-time treasures still to
-- find, and the points you have unspent or still need for the tree.
--
-- Where the numbers come from:
--   treasures      a hidden quest each, done once per character
--   weekly drops   the two treasure drops of crafting professions have a
--                  weekly quest; the gathering drops are counted as you
--                  loot them
--   treatise and   counted when you use the item (once a week); before
--   trainer notes  that, the window says when one is in your bags
--   Darkmoon Faire the profession's Faire quest, while the Faire is on
--   unspent, tree  the game's specialisation API, read when you open the
--                  profession (it needs the Midnight profession's ID)
--
--   PatronPlannerDB.knowledge = {
--     child = { [baseSkillLine] = midnightSkillLine },
--     flags = { [itemID] = questID },   the weekly quest an item flags, learned
--                                       the first time it's used
--     dropFlags = { [itemID] = { questID, ... } },   the same for gathering
--                                       drops, one quest per drop, learned on loot
--     notesQuests = { [base] = questID },   the trainer's weekly quest (the
--                                       one whose reward is the notes), learned
--                                       on turn-in; Engineering's is known
--     chars = { ["Name-Realm"] = { class, resetAt, used = { [itemID] = true },
--               looted = { [itemID] = n }, profs = { [base] = summary } } },
--   }

local _, ns = ...
local L, Util = ns.L, ns.Util

local Knowledge = {}
ns.Knowledge = Knowledge

-- Map IDs of the coordinates below. The game's own (translated) map name
-- is used when it has one; these are for when it doesn't.
local ZONES = {
    [2393] = "Silvermoon City", [2395] = "Eversong Woods", [2437] = "Zul'Aman", [2536] = "Atal'Aman",
    [2413] = "Harandar", [2405] = "Voidstorm", [2444] = "Voidstorm",
}

function Knowledge.Zone(map)
    local ok, info = pcall(C_Map.GetMapInfo, map)
    local name = ok and info and Util.Clean(info.name)
    return name or ZONES[map] or "?"
end

-- Per profession, by its base skill line. treatiseQuest and notesQuest: the
-- hidden weekly quest a used treatise flags, and the trainer's weekly quest
-- (its reward is the notes). catchup: the currency whose cap less what's
-- been earned is the catch-up knowledge still to get. drops: weekly treasure drops of
-- crafting professions { itemID, quest, points }. gather: gathering and
-- disenchanting drops { items, count, points } (the last one is the rare
-- final drop). treasures: { quest, map, x, y, name }, 3 points each.
local P = {}
Knowledge.PROFESSIONS = P

P[171] = { name = "Alchemy", treatise = 245755, treatiseQuest = 95127, notes = 263454, notesPoints = 1, notesQuest = 93690, faire = 29506, catchup = 3189,
    drops = { { 259188, 93528, 1 }, { 259189, 93529, 1 } },
    treasures = {
        { 89117, 2393, 47.8, 51.8, "Pristine Potion" },
        { 89111, 2393, 45.1, 44.7, "Vial of Eversong Oddities" },
        { 89115, 2393, 49.1, 75.8, "Freshly Plucked Peacebloom" },
        { 89114, 2437, 40.4, 51.1, "Vial of Zul'Aman Oddities" },
        { 89116, 2536, 49.1, 23.6, "Measured Ladle" },
        { 89113, 2413, 34.8, 24.7, "Vial of Rootlands Oddities" },
        { 89118, 2405, 32.8, 43.3, "Failed Experiment" },
        { 89112, 2444, 41.9, 40.6, "Vial of Voidstorm Oddities" },
    } }
P[164] = { name = "Blacksmithing", treatise = 245763, treatiseQuest = 95128, notes = 263455, notesPoints = 2, notesQuest = 93691, faire = 29508, catchup = 3199,
    drops = { { 259190, 93530, 2 }, { 259191, 93531, 2 } },
    treasures = {
        { 89183, 2393, 49.2, 61.3, "Sin'dorei Master's Forgemace" },
        { 89184, 2393, 48.5, 74.7, "Silvermoon Blacksmith's Hammer" },
        { 89177, 2393, 26.9, 60.3, "Deconstructed Forge Techniques" },
        { 89180, 2395, 56.8, 40.8, "Metalworking Cheat Sheet" },
        { 89178, 2395, 48.3, 75.8, "Silvermoon Smithing Kit" },
        { 89179, 2536, 33.2, 65.9, "Carefully Racked Spear" },
        { 89182, 2413, 66.3, 50.9, "Rutaani Floratender's Sword" },
        { 89181, 2444, 30.6, 69.0, "Voidstorm Defense Spear" },
    } }
P[333] = { name = "Enchanting", treatise = 245759, treatiseQuest = 95129, notes = 263464, notesPoints = 3, notesQuest = 93698, faire = 29510, catchup = 3198,
    drops = { { 259192, 93532, 2 }, { 259193, 93533, 2 } },
    gather = { { items = { 267654 }, count = 5, points = 1 }, { items = { 267655 }, count = 1, points = 4 } },
    treasures = {
        { 89107, 2395, 63.5, 32.6, "Sin'dorei Enchanting Rod" },
        { 89103, 2395, 60.8, 53.0, "Everblazing Sunmote" },
        { 89101, 2395, 40.2, 61.2, "Enchanted Sunfire Silk" },
        { 89106, 2437, 40.4, 51.1, "Loa-Blessed Dust" },
        { 89100, 2536, 48.4, 22.9, "Enchanted Amani Mask" },
        { 89105, 2413, 65.8, 50.2, "Primal Essence Orb" },
        { 89104, 2413, 37.7, 65.3, "Entropic Shard" },
        { 89102, 2405, 35.5, 58.8, "Pure Void Crystal" },
    } }
P[202] = { name = "Engineering", treatise = 245809, treatiseQuest = 95138, notes = 263456, notesPoints = 1, notesQuest = 93692, faire = 29511, catchup = 3197,
    drops = { { 259194, 93534, 1 }, { 259195, 93535, 1 } },
    treasures = {
        { 89133, 2393, 51.2, 74.6, "One Engineer's Junk" },
        { 89139, 2393, 51.3, 57.0, "What To Do When Nothing Works" },
        { 89135, 2395, 39.6, 45.8, "Manual of Mistakes and Mishaps" },
        { 89138, 2536, 65.3, 35.0, "Offline Helper Bot" },
        { 89140, 2437, 34.2, 87.8, "Handy Wrench" },
        { 89136, 2413, 68.0, 49.8, "Expeditious Pylon" },
        { 89137, 2444, 54.1, 51.1, "Ethereal Stormwrench" },
        { 89134, 2444, 28.9, 39.1, "Miniaturized Transport Skiff" },
    } }
P[182] = { name = "Herbalism", treatise = 245761, treatiseQuest = 95130, notes = 263462, notesPoints = 3, notesQuest = 93700, faire = 29514, catchup = 3196,
    gather = { { items = { 238465 }, count = 5, points = 1 }, { items = { 238466 }, count = 1, points = 4 } },
    treasures = {
        { 89160, 2393, 49.0, 75.9, "Simple Leaf Pruners" },
        { 89158, 2395, 64.2, 30.5, "A Spade" },
        { 89161, 2437, 41.9, 45.9, "Sweeping Harvester's Scythe" },
        { 89156, 2405, 34.7, 57.0, "Peculiar Lotus" },
        { 89155, 2413, 51.1, 55.7, "Planting Shovel" },
        { 89162, 2413, 38.3, 66.9, "Bloomed Bud" },
        { 89159, 2413, 36.6, 25.1, "Lightbloom Root" },
        { 89157, 2413, 76.1, 51.1, "Harvester's Sickle" },
    } }
P[773] = { name = "Inscription", treatise = 245757, treatiseQuest = 95131, notes = 263457, notesPoints = 2, notesQuest = 93693, faire = 29515, catchup = 3195,
    drops = { { 259196, 93536, 2 }, { 259197, 93537, 2 } },
    treasures = {
        { 89073, 2393, 47.7, 50.4, "Songwriter's Pen" },
        { 89074, 2395, 40.3, 61.2, "Songwriter's Quill" },
        { 89069, 2395, 48.3, 75.6, "Spare Ink" },
        { 89072, 2395, 39.3, 45.4, "Half-Baked Techniques" },
        { 89068, 2437, 40.5, 49.4, "Leather-Bound Techniques" },
        { 89071, 2413, 52.7, 50.0, "Leftover Sanguithorn Pigment" },
        { 89070, 2413, 52.4, 52.6, "Intrepid Explorer's Marker" },
        { 89067, 2444, 60.7, 84.3, "Void-Touched Quill" },
    } }
P[755] = { name = "Jewelcrafting", treatise = 245760, treatiseQuest = 95133, notes = 263458, notesPoints = 3, notesQuest = 93694, faire = 29516, catchup = 3194,
    drops = { { 259198, 93538, 2 }, { 259199, 93539, 2 } },
    treasures = {
        { 89122, 2393, 50.6, 56.6, "Sin'dorei Masterwork Chisel" },
        { 89127, 2393, 55.4, 48.0, "Vintage Soul Gem" },
        { 89124, 2393, 28.6, 46.5, "Dual-Function Magnifiers" },
        { 89125, 2395, 56.6, 40.9, "Poorly Rounded Vial" },
        { 89129, 2395, 39.6, 38.9, "Sin'dorei Gem Faceters" },
        { 89123, 2444, 30.5, 69.1, "Speculative Voidstorm Crystal" },
        { 89128, 2444, 54.2, 51.2, "Ethereal Gem Pliers" },
        { 89126, 2444, 62.7, 53.4, "Shattered Glass" },
    } }
P[165] = { name = "Leatherworking", treatise = 245758, treatiseQuest = 95134, notes = 263459, notesPoints = 2, notesQuest = 93695, faire = 29517, catchup = 3193,
    drops = { { 259200, 93540, 2 }, { 259201, 93541, 2 } },
    treasures = {
        { 89096, 2393, 44.8, 56.2, "Artisan's Considered Order" },
        { 89092, 2536, 45.4, 45.5, "Bundle of Tanner's Trinkets" },
        { 89089, 2437, 33.1, 78.9, "Amani Leatherworker's Tool" },
        { 89091, 2437, 30.8, 84.0, "Prestigiously Racked Hide" },
        { 89090, 2405, 34.7, 57.0, "Ethereal Leatherworking Knife" },
        { 89094, 2413, 51.7, 51.3, "Haranir Leatherworking Mallet" },
        { 89095, 2413, 36.1, 25.2, "Haranir Leatherworking Knife" },
        { 89093, 2444, 53.7, 51.7, "Patterns: Beyond the Void" },
    } }
P[186] = { name = "Mining", treatise = 245762, treatiseQuest = 95135, notes = 263463, notesPoints = 3, notesQuest = 93709, faire = 29518, catchup = 3192,
    gather = { { items = { 237496 }, count = 5, points = 1 }, { items = { 237506 }, count = 1, points = 3 } },
    treasures = {
        { 89147, 2395, 38.0, 45.4, "Solid Ore Punchers" },
        { 89149, 2536, 33.4, 65.9, "Amani Expert's Chisel" },
        { 89145, 2437, 42.0, 46.5, "Spelunker's Lucky Charm" },
        { 89151, 2413, 38.8, 65.9, "Spare Expedition Torch" },
        { 89150, 2444, 34.2, 76.0, "Star Metal Deposit" },
        { 89144, 2444, 30.5, 69.1, "Miner's Guide to Voidstorm" },
        { 89148, 2444, 28.7, 38.5, "Glimmering Void Pearl" },
        { 89146, 2444, 54.2, 51.5, "Lost Voidstorm Satchel" },
    } }
P[393] = { name = "Skinning", treatise = 245828, treatiseQuest = 95136, notes = 263461, notesPoints = 3, notesQuest = 93710, faire = 29519, catchup = 3191,
    gather = { { items = { 238625, 238627 }, count = 5, points = 1 }, { items = { 238626 }, count = 1, points = 3 } },
    treasures = {
        { 89171, 2393, 43.2, 55.7, "Sin'dorei Tanning Oil" },
        { 89173, 2395, 48.4, 76.3, "Thalassian Skinning Knife" },
        { 89167, 2536, 44.9, 45.2, "Cadre Skinning Knife" },
        { 89172, 2437, 33.1, 79.1, "Amani Skinning Knife" },
        { 89170, 2437, 40.4, 36.0, "Amani Tanning Oil" },
        { 89168, 2413, 69.5, 49.2, "Primal Hide" },
        { 89166, 2413, 76.0, 51.0, "Lightbloom Afflicted Hide" },
        { 89169, 2444, 45.5, 42.3, "Voidstorm Leather Sample" },
    } }
P[197] = { name = "Tailoring", treatise = 245756, treatiseQuest = 95137, notes = 263460, notesPoints = 2, notesQuest = 93696, faire = 29520, catchup = 3190,
    drops = { { 259202, 93542, 2 }, { 259203, 93543, 2 } },
    treasures = {
        { 89079, 2393, 35.9, 61.3, "A Really Nice Curtain" },
        { 89084, 2393, 31.8, 68.2, "Particularly Enchanting Tablecloth" },
        { 89080, 2395, 46.3, 34.8, "Sin'dorei Outfitter's Ruler" },
        { 89085, 2437, 40.5, 49.4, "Artisan's Cover Comb" },
        { 89081, 2413, 69.8, 51.0, "Wooden Weaving Sword" },
        { 89078, 2413, 70.5, 50.9, "A Child's Stuffy" },
        { 89082, 2444, 62.0, 83.6, "Book of Sin'dorei Stitches" },
        { 89083, 2444, 61.6, 85.0, "Satin Throw Pillow" },
    } }

-- Where Midnight's hidden weekly quests sit, for /pp kpscan and for
-- learning which quest a drop flags.
local SCAN_FROM, SCAN_TO = 92500, 95500

local TREASURE_POINTS = 3
local TREATISE_POINTS = 1
local FAIRE_POINTS = 3

-- Items whose use or loot we count, to the profession they belong to.
local USED, LOOTED, GATHERED, NOTES = {}, {}, {}, {}
for base, prof in pairs(P) do
    USED[prof.treatise] = base
    USED[prof.notes] = base
    NOTES[prof.notes] = base
    for _, step in ipairs(prof.gather or {}) do
        for _, itemID in ipairs(step.items) do
            LOOTED[itemID] = base
            GATHERED[itemID] = true
        end
    end
    for _, drop in ipairs(prof.drops or {}) do LOOTED[drop[1]] = base end
end

local function CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetNormalizedRealmName() or "?")
end

local function Done(quest)
    local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, quest)
    return ok and Util.Clean(done) == true
end

local function InBags(itemID)
    local ok, count = pcall(C_Item.GetItemCount, itemID)
    return ok and (Util.Clean(count) or 0) or 0
end

-- When this week's knowledge resets, to the minute.
local function ResetAt()
    local ok, left = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
    left = ok and Util.Clean(left)
    if not left then return nil end
    return math.floor((GetServerTime() + left) / 60 + 0.5) * 60
end

-- The Faire runs from the first Sunday of the month for a week.
function Knowledge.FaireOn()
    local today = date("*t")
    local first = date("*t", time({ year = today.year, month = today.month, day = 1, hour = 12 }))
    local sunday = 1 + (8 - first.wday) % 7
    return today.day >= sunday and today.day < sunday + 7
end

local function Store()
    if not ns.db then return nil end
    ns.db.knowledge = ns.db.knowledge or {}
    local store = ns.db.knowledge
    store.child = store.child or {}
    store.chars = store.chars or {}
    -- itemID -> the hidden weekly quest using it flags, learned in game.
    store.flags = store.flags or {}
    -- itemID -> { quests }: a gathering drop flags one quest per drop of the
    -- week (5 for the common one), learned as they're looted.
    store.dropFlags = store.dropFlags or {}
    store.notesQuests = store.notesQuests or {}
    return store
end

-- This character's saved record, with last week's counts cleared.
function Knowledge.Me()
    local store = Store()
    if not store then return nil end
    local key = CharKey()
    local me = store.chars[key] or {}
    store.chars[key] = me
    me.used = me.used or {}
    me.looted = me.looted or {}
    me.profs = me.profs or {}
    me.class = select(2, UnitClass("player"))
    local resetAt = ResetAt()
    if resetAt and (not me.resetAt or GetServerTime() >= me.resetAt) then
        if me.resetAt and math.abs(resetAt - me.resetAt) > 120 then
            wipe(me.used)
            wipe(me.looted)
        end
        me.resetAt = resetAt
    end
    return me
end

-- This character's Midnight-era professions, by base skill line.
function Knowledge.MyProfessions()
    local list = {}
    local ok, a, b, _, _, c = pcall(GetProfessions)
    if not ok then return list end
    for _, index in ipairs({ a, b, c }) do
        if index then
            local skillLine = select(7, GetProfessionInfo(index))
            skillLine = Util.Clean(skillLine)
            -- Fishing and Cooking have no treasures here.
            if skillLine and P[skillLine] then list[#list + 1] = skillLine end
        end
    end
    table.sort(list, function(x, y) return P[x].name < P[y].name end)
    return list
end

-- Unspent points and what the tree still needs, from the game's
-- specialisation API. nil when the game won't say yet.
local function ReadSpecs(child)
    if not (child and C_ProfSpecs and C_Traits) then return nil end
    local ok, currency = pcall(C_ProfSpecs.GetCurrencyInfoForSkillLine, child)
    local unspent = ok and currency and Util.Clean(currency.numAvailable)
    local remaining
    local okConfig, configID = pcall(C_ProfSpecs.GetConfigIDForSkillLine, child)
    local okTabs, tabs = pcall(C_ProfSpecs.GetSpecTabIDsForSkillLine, child)
    if okConfig and configID and okTabs and tabs then
        remaining = 0
        for _, treeID in ipairs(tabs) do
            local okNodes, nodes = pcall(C_Traits.GetTreeNodes, treeID)
            for _, nodeID in ipairs(okNodes and nodes or {}) do
                local okInfo, info = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                local max = okInfo and info and Util.Clean(info.maxRanks)
                local have = okInfo and info and Util.Clean(info.currentRank)
                if max and have and max > have then remaining = remaining + (max - have) end
            end
        end
    end
    if unspent == nil and remaining == nil then return nil end
    return unspent, remaining
end

-- Catch-up knowledge still to get: the catch-up currency's cap less what's
-- been earned toward it. nil when the game won't say.
function Knowledge.Catchup(base)
    local prof = P[base]
    if not (prof and prof.catchup and C_CurrencyInfo) then return nil end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, prof.catchup)
    if not (ok and info) then return nil end
    local max, earned = Util.Clean(info.maxQuantity), Util.Clean(info.totalEarned)
    if not (max and earned) or max <= 0 then return nil end
    return math.max(0, max - earned)
end

-- Everything for one profession of this character:
--   { base, name, weekly = { lines }, weeklyLeft, weeklyTotal,
--     treasures = { lines }, treasuresLeft, unspent, remaining }
-- A line is { kind, label, itemID, points, done, inBags, have, need, treasure }.
function Knowledge.Status(base)
    local prof, me = P[base], Knowledge.Me()
    if not (prof and me) then return nil end
    local status = { base = base, name = prof.name, weekly = {}, treasures = {} }
    local function Weekly(line)
        status.weekly[#status.weekly + 1] = line
    end

    local flags = Store().flags
    local function Studied(itemID)
        return me.used[itemID] == true or (flags[itemID] ~= nil and Done(flags[itemID]))
    end
    Weekly({ kind = "treatise", label = L.KP_TREATISE, itemID = prof.treatise, points = TREATISE_POINTS,
        done = Studied(prof.treatise) or Done(prof.treatiseQuest), inBags = InBags(prof.treatise) })
    -- The trainer's quest done and its notes gone from the bags: used, even
    -- when the use itself wasn't seen (from a bag addon, or before install).
    local notesQuest = prof.notesQuest or Store().notesQuests[base]
    local notesInBags = InBags(prof.notes)
    Weekly({ kind = "notes", label = L.KP_NOTES, itemID = prof.notes, points = prof.notesPoints,
        done = Studied(prof.notes) or (notesQuest ~= nil and Done(notesQuest) and notesInBags == 0),
        inBags = notesInBags })
    for _, drop in ipairs(prof.drops or {}) do
        local itemID, quest, points = drop[1], drop[2], drop[3]
        Weekly({ kind = "drop", itemID = itemID, points = points,
            done = Done(quest) or (me.looted[itemID] or 0) > 0, inBags = InBags(itemID) })
    end
    local dropFlags = Store().dropFlags
    for _, step in ipairs(prof.gather or {}) do
        local have, flagged, inBags = 0, 0, 0
        for _, itemID in ipairs(step.items) do
            have = have + (me.looted[itemID] or 0)
            inBags = inBags + InBags(itemID)
            for _, quest in ipairs(dropFlags[itemID] or {}) do
                if Done(quest) then flagged = flagged + 1 end
            end
        end
        -- The learned quests know about drops looted before install too.
        have = math.max(have, flagged)
        Weekly({ kind = "gather", itemID = step.items[1], points = step.points * step.count,
            have = math.min(have, step.count), need = step.count, done = have >= step.count, inBags = inBags })
    end
    if Knowledge.FaireOn() then
        Weekly({ kind = "faire", label = L.KP_FAIRE, points = FAIRE_POINTS, done = Done(prof.faire) })
    end

    status.weeklyLeft, status.weeklyTotal = 0, 0
    for _, line in ipairs(status.weekly) do
        status.weeklyTotal = status.weeklyTotal + line.points
        if not line.done then
            if line.need then
                status.weeklyLeft = status.weeklyLeft + line.points * (line.need - line.have) / line.need
            else
                status.weeklyLeft = status.weeklyLeft + line.points
            end
        end
    end

    status.treasuresLeft = 0
    for _, t in ipairs(prof.treasures) do
        local done = Done(t[1])
        if not done then status.treasuresLeft = status.treasuresLeft + 1 end
        status.treasures[#status.treasures + 1] = { kind = "treasure", label = t[5], points = TREASURE_POINTS,
            done = done, treasure = { map = t[2], x = t[3], y = t[4], name = t[5] } }
    end
    -- Still to find first.
    table.sort(status.treasures, function(x, y)
        if x.done ~= y.done then return not x.done end
        return x.label < y.label
    end)

    local saved = me.profs[base]
    status.unspent, status.remaining = saved and saved.unspent, saved and saved.remaining
    status.catchup = Knowledge.Catchup(base)
    return status
end

-- Saves this character's summary for the alts view.
function Knowledge.Save()
    local me = Knowledge.Me()
    if not me then return end
    local store = Store()
    for _, base in ipairs(Knowledge.MyProfessions()) do
        local saved = me.profs[base] or {}
        me.profs[base] = saved
        local unspent, remaining = ReadSpecs(store.child[base])
        if unspent ~= nil then saved.unspent = unspent end
        if remaining ~= nil then saved.remaining = remaining end
        local status = Knowledge.Status(base)
        saved.weeklyLeft, saved.weeklyTotal = status.weeklyLeft, status.weeklyTotal
        saved.treasuresLeft = status.treasuresLeft
        saved.catchup = status.catchup
        saved.at = GetServerTime()
    end
    -- Professions this character no longer has.
    local have = {}
    for _, base in ipairs(Knowledge.MyProfessions()) do have[base] = true end
    for base in pairs(me.profs) do
        if not have[base] then me.profs[base] = nil end
    end
end

-- Every character's saved summary: { { key, class, profs, resetAt } },
-- this one first. A saved week that has reset since counts as all open.
function Knowledge.Alts()
    local store = Store()
    if not store then return {} end
    local now, mine, list = GetServerTime(), CharKey(), {}
    for key, char in pairs(store.chars) do
        if next(char.profs or {}) then
            list[#list + 1] = { key = key, class = char.class, profs = char.profs,
                newWeek = char.resetAt and now >= char.resetAt, mine = key == mine }
        end
    end
    table.sort(list, function(a, b)
        if a.mine ~= b.mine then return a.mine end
        return a.key < b.key
    end)
    return list
end

-- /pp kpscan: the quests flagged done on this character in the stretch
-- of IDs around the known weekly ones, with their titles where the game
-- has one (hidden tracking quests have none). Run on a character that has
-- done its week, it shows which IDs the weekly sources use.
function Knowledge.Scan()
    local lines = {}
    for quest = SCAN_FROM, SCAN_TO do
        if Done(quest) then
            local ok, title = pcall(C_QuestLog.GetTitleForQuestID, quest)
            title = ok and Util.Clean(title)
            lines[#lines + 1] = title and (quest .. " " .. title) or tostring(quest)
        end
    end
    local names = {}
    for _, base in ipairs(Knowledge.MyProfessions()) do names[#names + 1] = P[base].name end
    return ("%s (%s) %d-%d, %d done:\n%s"):format(CharKey(), table.concat(names, ", "), SCAN_FROM, SCAN_TO,
        #lines, table.concat(lines, "\n"))
end

-- A map pin: TomTom when it's installed, otherwise the game's own pin.
function Knowledge.Waypoint(treasure)
    local x, y = treasure.x / 100, treasure.y / 100
    if TomTom and TomTom.AddWaypoint then
        TomTom:AddWaypoint(treasure.map, x, y, { title = treasure.name, persistent = false, minimap = true, world = true })
        Util.Say(L.KP_WAYPOINT_TOMTOM:format(treasure.name))
        return
    end
    local okCan, can = pcall(C_Map.CanSetUserWaypointOnMap, treasure.map)
    if not (okCan and can) then
        Util.Say(L.KP_WAYPOINT_NO:format(treasure.name, Knowledge.Zone(treasure.map), treasure.x, treasure.y))
        return
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(treasure.map, x, y))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    Util.Say(L.KP_WAYPOINT_SET:format(treasure.name, Knowledge.Zone(treasure.map)))
end

local function Changed()
    Knowledge.Save()
    if ns.KnowledgeWindow then ns.KnowledgeWindow:Refresh() end
end

local function MarkUsed(itemID)
    local me = Knowledge.Me()
    if me then me.used[itemID] = true end
    Changed()
end

-- Right-click in the window: the player says a treatise or notes was used
-- this week (or wasn't), for a use Patron Planner couldn't see.
function Knowledge.ToggleUsed(itemID)
    local me = Knowledge.Me()
    if not (me and USED[itemID]) then return end
    me.used[itemID] = not me.used[itemID] or nil
    Changed()
end

local function CompletedSet()
    local ok, list = pcall(C_QuestLog.GetAllCompletedQuestIDs)
    if not (ok and list) then return nil end
    local set = {}
    for _, quest in ipairs(list) do set[quest] = true end
    return set
end

-- The item being used, for the game's answer: { itemID, at }.
local trying

-- Completed quests as they were just before the last gathering or
-- disenchanting cast, to spot the one quest a drop flags.
local known, knownAt = nil, 0
local function Remember()
    if InCombatLockdown() or GetTime() - knownAt < 2 then return end
    known, knownAt = CompletedSet(), GetTime()
end

-- A gathering drop looted: the one Midnight-era quest that went done since
-- the cast is that drop's quest for this week.
local function LearnDrop(itemID)
    local store, before = Store(), known
    if not (store and before) then return end
    C_Timer.After(1, function()
        local now, new = CompletedSet(), nil
        for quest in pairs(now or {}) do
            if not before[quest] and quest >= SCAN_FROM and quest <= SCAN_TO then
                if new then return end -- more than one: can't tell which
                new = quest
            end
        end
        if not new then return end
        local list = store.dropFlags[itemID] or {}
        store.dropFlags[itemID] = list
        if not tContains(list, new) then
            list[#list + 1] = new
            Util.Debug("knowledge drop", itemID, "flags quest", new)
        end
        known = now
    end)
end

-- A treatise or notes used: counted once its stack goes down. The first
-- time an item is used, the hidden weekly quest the game flags for it is
-- learned (the one quest that went done) and kept for every character, so
-- from then on the quest says whether it's done, even for a use made
-- before Patron Planner was installed.
local function Used(itemID)
    local base = itemID and USED[itemID]
    if not base then return end
    local store = Store()
    local before = InBags(itemID)
    local completed = store and not store.flags[itemID] and CompletedSet()
    trying = { itemID = itemID, at = GetTime() }
    C_Timer.After(1.5, function()
        if InBags(itemID) >= before then return end
        if completed then
            local now, new = CompletedSet(), nil
            for quest in pairs(now or {}) do
                if not completed[quest] then
                    -- More than one went done at once: can't tell which.
                    if new then new = false break end
                    new = quest
                end
            end
            if new then
                store.flags[itemID] = new
                Util.Debug("knowledge item", itemID, "flags quest", new)
            end
        end
        MarkUsed(itemID)
    end)
end

-- Uses the hooks above miss: a bag addon's or the default bag's secure
-- button uses the item without going through Lua. So while a treatise or
-- notes sits in the bags, its count and the Midnight-era quests already
-- done are kept; when the count goes down and a quest went done with it,
-- that was a use (and that quest is the item's weekly flag). A count that
-- goes down with no quest is a move to the bank, not a use.
local watched -- { counts = { [itemID] = n }, quests = { [questID] = true } }

-- The interaction windows open now (bank, mailbox, vendor, trade, AH...),
-- by type, from PLAYER_INTERACTION_MANAGER_FRAME_SHOW and _HIDE.
Knowledge.open = {}

local function RangeDone()
    local set = {}
    for quest = SCAN_FROM, SCAN_TO do
        if Done(quest) then set[quest] = true end
    end
    return set
end

local function Watch()
    local counts, any = {}, false
    for _, base in ipairs(Knowledge.MyProfessions()) do
        for _, itemID in ipairs({ P[base].treatise, P[base].notes }) do
            local n = InBags(itemID)
            if n > 0 then counts[itemID], any = n, true end
        end
    end
    watched = any and { counts = counts, quests = RangeDone() } or nil
end

local function CheckWatched()
    if not watched then return Watch() end
    local dropped = {}
    for itemID, n in pairs(watched.counts) do
        if InBags(itemID) < n then dropped[#dropped + 1] = itemID end
    end
    if #dropped == 0 then return Watch() end
    local before = watched.quests
    -- Gone with no bank, mailbox, vendor, trade or Auction House open: it
    -- can only have been used, even if no quest shows it.
    local nowhere = not next(Knowledge.open)
    -- The quest flag lands a moment after the item goes.
    C_Timer.After(1.5, function()
        local new = {}
        for quest in pairs(RangeDone()) do
            if not before[quest] then new[#new + 1] = quest end
        end
        local store, me = Store(), Knowledge.Me()
        if store and me and (#new >= #dropped or nowhere) then
            for _, itemID in ipairs(dropped) do
                if not store.flags[itemID] and #dropped == 1 and #new == 1 then
                    store.flags[itemID] = new[1]
                    Util.Debug("knowledge item", itemID, "flags quest", new[1], "(from the bags)")
                end
                me.used[itemID] = true
            end
            Changed()
        end
        Watch()
    end)
end

-- "You have studied these notes extensively and there is nothing new to
-- learn from them": a use refused right away means this week's is done.
local function Refused()
    if not trying or GetTime() - trying.at > 1 then return end
    local itemID = trying.itemID
    trying = nil
    MarkUsed(itemID)
end

if C_Container and C_Container.UseContainerItem then
    hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
        local ok, itemID = pcall(C_Container.GetContainerItemID, bag, slot)
        if ok then Used(Util.Clean(itemID)) end
    end)
end
if C_Item and C_Item.UseItemByName then
    hooksecurefunc(C_Item, "UseItemByName", function(name)
        local ok, itemID = pcall(C_Item.GetItemInfoInstant, name)
        if ok then Used(Util.Clean(itemID)) end
    end)
end

-- The trainer's weekly quest, learned from its reward: a quest turned in
-- and a profession's notes received within a few seconds of each other,
-- in either order.
local lastTurnIn, lastNotes
local function LearnNotesQuest()
    if not (lastTurnIn and lastNotes) or math.abs(lastTurnIn.at - lastNotes.at) > 5 then return end
    local store = Store()
    if store and not P[lastNotes.base].notesQuest then
        store.notesQuests[lastNotes.base] = lastTurnIn.quest
        Util.Debug("knowledge notes", lastNotes.base, "from quest", lastTurnIn.quest)
    end
    lastTurnIn, lastNotes = nil, nil
end

-- "You receive loot: " and "You receive item: ", for loot lines that come
-- without the looter's GUID.
local OWN_LOOT = LOOT_ITEM_SELF and LOOT_ITEM_SELF:match("^(.-)%%s")
local OWN_PUSH = LOOT_ITEM_PUSHED_SELF and LOOT_ITEM_PUSHED_SELF:match("^(.-)%%s")
local function Mine(text)
    return (OWN_LOOT and text:sub(1, #OWN_LOOT) == OWN_LOOT) or (OWN_PUSH and text:sub(1, #OWN_PUSH) == OWN_PUSH)
end

-- Using a treatise or notes casts its own spell (a 2 second cast that
-- grants the knowledge), however the item was clicked. spellID -> itemID,
-- asked from the game per item, filled in as item data loads.
local SPELL_ITEM = {}
local function ItemSpells()
    for itemID in pairs(USED) do
        local ok, _, spellID = pcall(C_Item.GetItemSpell, itemID)
        spellID = ok and Util.Clean(spellID)
        if spellID then
            SPELL_ITEM[spellID] = itemID
        elseif C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, itemID)
        end
    end
end

local function Cast(spellID)
    spellID = Util.Clean(spellID)
    if not spellID then return end
    -- An item whose data hadn't loaded yet may be the one: ask again (out of
    -- combat, where these are used).
    if not SPELL_ITEM[spellID] and not InCombatLockdown() then ItemSpells() end
    local itemID = SPELL_ITEM[spellID]
    if not itemID then return end
    Util.Debug("knowledge item", itemID, "used (cast", spellID .. ")")
    MarkUsed(itemID)
    -- The quest the game flags for it, at any ID: the one that went done
    -- between the cast starting (UNIT_SPELLCAST_SENT) and now. Kept for the
    -- whole account, so every character can be checked, even for a use
    -- made before Patron Planner was installed.
    local store, before = Store(), known
    if not (store and before) or store.flags[itemID] then return end
    C_Timer.After(1.5, function()
        local new
        for quest in pairs(CompletedSet() or {}) do
            if not before[quest] then
                if new then return end -- more than one: can't tell which
                new = quest
            end
        end
        if new then
            store.flags[itemID] = new
            Util.Debug("knowledge item", itemID, "flags quest", new, "(from its cast)")
            Changed()
        end
    end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "CHAT_MSG_LOOT", "QUEST_TURNED_IN", "UNIT_SPELLCAST_SUCCEEDED",
    "TRADE_SKILL_SHOW", "TRAIT_CONFIG_UPDATED", "CURRENCY_DISPLAY_UPDATE", "SKILL_LINES_CHANGED",
    "UI_ERROR_MESSAGE", "UNIT_SPELLCAST_SENT", "BAG_UPDATE_DELAYED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }) do
    pcall(events.RegisterEvent, events, event)
end
local pending = false
local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(1, function()
        pending = false
        Changed()
    end)
end
events:SetScript("OnEvent", function(_, event, ...)
    if not ns.db then return end
    if event == "UI_ERROR_MESSAGE" then
        Refused()
    elseif event == "BAG_UPDATE_DELAYED" then
        if not InCombatLockdown() then CheckWatched() end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local kind = ...
        if kind then Knowledge.open[kind] = true end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        -- Hidden after the bag update it caused, so a move still counts as one.
        local kind = ...
        if kind then C_Timer.After(0.5, function() Knowledge.open[kind] = nil end) end
    elseif event == "UNIT_SPELLCAST_SENT" then
        -- Gathering and disenchanting start with a cast: remember what's done.
        if ... == "player" then Remember() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then Cast(spellID) end
    elseif event == "CHAT_MSG_LOOT" then
        local text, _, _, _, _, _, _, _, _, _, _, guid = ...
        text, guid = Util.Clean(text), Util.Clean(guid)
        if not text then return end
        if guid then
            if guid ~= UnitGUID("player") then return end
        elseif not Mine(text) then
            return
        end
        local itemID = tonumber(text:match("|Hitem:(%d+)"))
        if itemID and NOTES[itemID] then
            lastNotes = { base = NOTES[itemID], at = GetTime() }
            LearnNotesQuest()
            Soon()
            return
        end
        if not (itemID and LOOTED[itemID]) then return end
        local count = tonumber(text:match("|rx(%d+)")) or 1
        local me = Knowledge.Me()
        if me then me.looted[itemID] = (me.looted[itemID] or 0) + count end
        if GATHERED[itemID] then LearnDrop(itemID) end
        Soon()
    elseif event == "TRADE_SKILL_SHOW" or event == "TRAIT_CONFIG_UPDATED" then
        -- The open profession's Midnight skill line (its newest expansion,
        -- whichever one the window shows), kept for every character.
        local ok, info = pcall(C_TradeSkillUI.GetChildProfessionInfo)
        local base = ok and info and Util.Clean(info.parentProfessionID)
        local okAll, all = pcall(C_TradeSkillUI.GetChildProfessionInfos)
        local child
        for _, each in ipairs(okAll and all or {}) do
            local id = Util.Clean(each.professionID)
            if id and (not child or id > child) then child = id end
        end
        local store = Store()
        if child and base and P[base] and store then store.child[base] = child end
        Soon()
    elseif event == "QUEST_TURNED_IN" then
        local quest = Util.Clean((...))
        if quest then
            lastTurnIn = { quest = quest, at = GetTime() }
            LearnNotesQuest()
        end
        Soon()
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(5, function()
            ItemSpells()
            Changed()
            Watch()
        end)
    else
        Soon()
    end
end)
