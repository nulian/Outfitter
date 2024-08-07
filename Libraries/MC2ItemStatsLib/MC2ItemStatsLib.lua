----------------------------------------
-- ItemStatsLib
--
-- Provides functions for converting item references (links, locations) into structured info about the item
--
-- Requires: MC2AddonLib, MC2TooltipLib
----------------------------------------

local _, Addon = ...

local function stripColonFromBlizzardLabel(label)
	if not label then
		return "nil"
	end

	return label:gsub(":$", "")
end

----------------------------------------
Addon.ItemStatsLib = {
----------------------------------------
	version = 1,
}

Addon.ItemStatsLib.strings = {}
Addon.ItemStatsLib.strings.Stamina = stripColonFromBlizzardLabel(STAMINA_COLON)
Addon.ItemStatsLib.strings.Strength = stripColonFromBlizzardLabel(STRENGTH_COLON) 
Addon.ItemStatsLib.strings.Intellect = stripColonFromBlizzardLabel(INTELLECT_COLON)
Addon.ItemStatsLib.strings.Agility = stripColonFromBlizzardLabel(AGILITY_COLON)
Addon.ItemStatsLib.strings.Spirit = stripColonFromBlizzardLabel(SPIRIT_COLON)
Addon.ItemStatsLib.strings.Haste = STAT_HASTE
Addon.ItemStatsLib.strings.Versatility = "Versatility"
Addon.ItemStatsLib.strings.Mastery = STAT_MASTERY
Addon.ItemStatsLib.strings.CriticalStrike = "Critical Strike"
Addon.ItemStatsLib.strings.Power = ATTACK_POWER
Addon.ItemStatsLib.strings.Dodge = STAT_DODGE
Addon.ItemStatsLib.strings.ItemLevel = "Item Level"

Addon.ItemStatsLib.statNormalization = {}
Addon.ItemStatsLib.statNormalization[Addon.ItemStatsLib.strings.Stamina] = "STA"
Addon.ItemStatsLib.statNormalization[Addon.ItemStatsLib.strings.Strength] = "STR"
Addon.ItemStatsLib.statNormalization[Addon.ItemStatsLib.strings.Intellect] = "INT"
Addon.ItemStatsLib.statNormalization[Addon.ItemStatsLib.strings.Agility] = "AGI"
Addon.ItemStatsLib.statNormalization[Addon.ItemStatsLib.strings.Spirit] = "SPI"
Addon.ItemStatsLib.statNormalization[Addon.ItemStatsLib.strings.Haste] = "HAS"
Addon.ItemStatsLib.statNormalization[Addon.ItemStatsLib.strings.Versatility] = "VER"
Addon.ItemStatsLib.statNormalization[Addon.ItemStatsLib.strings.Mastery] = "MAS"
Addon.ItemStatsLib.statNormalization[Addon.ItemStatsLib.strings.CriticalStrike] = "CRI"
Addon.ItemStatsLib.statNormalization[Addon.ItemStatsLib.strings.ItemLevel] = "ITEM_LEVEL"

function Addon.ItemStatsLib:statsForBagItem(bag, slot)
	local stats = Addon:new(self._Stats)
	stats:setToBagItem(bag, slot)
	return stats
end

function Addon.ItemStatsLib:statsForLink(link)
	local stats = Addon:new(self._Stats)
	stats:setToLink(link)
	return stats
end

----------------------------------------
Addon.ItemStatsLib._Stats = {}
----------------------------------------

function Addon.ItemStatsLib._Stats:setToInventoryItem(inventorySlot)
	local stats = Addon.TooltipLib:StatsForInventoryItem(inventorySlot)
	self:setTooltipStats(stats)

	local link = GetInventoryItemLink("player", inventorySlot)
	self:setInfoFromLink(link)
end

function Addon.ItemStatsLib._Stats:setToBagItem(bag, slot)
	local stats = Addon.TooltipLib:StatsForBagItem(bag, slot)
	self:setTooltipStats(stats)

	local link = C_Container.GetContainerItemLink(bag, slot)
	self:setInfoFromLink(link)
end

function Addon.ItemStatsLib._Stats:setToLink(link)
	local stats = Addon.TooltipLib:StatsForLink(link)
	self:setTooltipStats(stats)
	self:setInfoFromLink(link)
end

function Addon.ItemStatsLib._Stats:setTooltipStats(tooltipStats)
	self.values = {}
	for key, value in pairs(Addon.ItemStatsLib.statNormalization) do
		if tooltipStats[key] then
			self.values[value] = tooltipStats[key]
		end
	end
end

function Addon.ItemStatsLib._Stats:setInfoFromLink(link)
	local name, link, rarity, level, minLevel, type, subType, stackCount, equipLoc, texture, sellPrice = C_Item.GetItemInfo(link)

	self.itemLevel = tonumber(level)
	self.minLevel = tonumber(minLevel)
end

-- /dump Outfitter.ItemStatsLib:statsForBagItem(0, 1)
