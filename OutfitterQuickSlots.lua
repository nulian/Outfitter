----------------------------------------
Outfitter._FlyoutQuickSlots = {}
----------------------------------------

function Outfitter._FlyoutQuickSlots:Construct()
	for _, vSlotName in ipairs(Outfitter.cSlotNames) do
		local vSlotButton = _G["Character"..vSlotName]
		if vSlotButton then
			Outfitter:HookScript(vSlotButton, "PreClick", function (...) self:PreClick(...) end)
			Outfitter:HookScript(vSlotButton, "PostClick", function (...) self:PostClick(...) end)
		end
	end
	
	local vFlyoutSettings = PaperDollItemsFrame.flyoutSettings
	local vOrigGetItemsFunc = vFlyoutSettings.getItemsFunc
	vFlyoutSettings.getItemsFunc = function (pSlotID, pItemTable, ...)
		vOrigGetItemsFunc(pSlotID, pItemTable, ...)
		-- Remove items on the player from the choices
		for vLocation, vItemID in next, pItemTable do
			local vOnPlayer = bit.band(vLocation, ITEM_INVENTORY_LOCATION_PLAYER + ITEM_INVENTORY_LOCATION_BAGS + ITEM_INVENTORY_LOCATION_BANK) == ITEM_INVENTORY_LOCATION_PLAYER
			if vOnPlayer then pItemTable[vLocation] = nil end
		end
	end
	local vOrigPostGetItemsFunc = vFlyoutSettings.postGetItemsFunc
	vFlyoutSettings.postGetItemsFunc = function (pItemSlotButton, pItemDisplayTable, pNumItems)
		local vNumItems = vOrigPostGetItemsFunc(pItemSlotButton, pItemDisplayTable, pNumItems)
		-- Order the choices by upgrade track, then item level, then name
		self:SortItems(pItemDisplayTable, vNumItems)
		-- If the first item is the PLACEINBAGS item, then move it to the end
		if vNumItems > 0 and (pItemDisplayTable[1] == EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION) then
			table.remove(pItemDisplayTable, 1)
			table.insert(pItemDisplayTable, EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION)
		end
		return vNumItems
	end
end

-- Resolves a packed flyout location to an item link, or nil if the item can't be
-- reached (void storage) or the link came back as a secret value

function Outfitter._FlyoutQuickSlots:GetLocationItemLink(pLocation)
	local vIsPlayer, vIsBank, vIsBags, vSlotIndex, vBagIndex

	if EquipmentManager_GetLocationData then
		local vLocationData = EquipmentManager_GetLocationData(pLocation)

		if not vLocationData then
			return
		end

		vIsPlayer, vIsBank, vIsBags, vSlotIndex, vBagIndex =
			vLocationData.isPlayer, vLocationData.isBank, vLocationData.isBags, vLocationData.slot, vLocationData.bag
	else
		local vIsVoidStorage

		vIsPlayer, vIsBank, vIsBags, vIsVoidStorage, vSlotIndex, vBagIndex = EquipmentManager_UnpackLocation(pLocation)

		if vIsVoidStorage then
			return
		end
	end

	if not vSlotIndex then
		return
	end

	if vIsBags then
		if not vBagIndex then
			return
		end

		return OutfitterAPI:Unsecret(OutfitterAPI:GetContainerItemLink(vBagIndex, vSlotIndex)),
			ItemLocation and ItemLocation:CreateFromBagAndSlot(vBagIndex, vSlotIndex)
	end

	if vIsPlayer
	or vIsBank then
		return Outfitter:GetInventorySlotIDLink(vSlotIndex),
			ItemLocation and ItemLocation:CreateFromEquipmentSlot(vSlotIndex)
	end
end

-- Returns true or false when the game will say, and nil when it won't

function Outfitter._FlyoutQuickSlots:ItemCanBeUpgraded(pItemLocation)
	if not pItemLocation
	or not C_ItemUpgrade
	or not C_ItemUpgrade.CanUpgradeItem
	or not C_Item.DoesItemExist
	or not C_Item.DoesItemExist(pItemLocation) then
		return nil
	end

	local vSucceeded, vCanUpgrade = pcall(C_ItemUpgrade.CanUpgradeItem, pItemLocation)

	if not vSucceeded then
		return nil
	end

	return vCanUpgrade
end

function Outfitter._FlyoutQuickSlots:GetItemSortInfo(pLocation, pIndex)
	local vSortInfo =
	{
		Location = pLocation,
		Index = pIndex,
		TrackCeiling = 0,
		TrackStringID = 0,
		Level = 0,
	}

	local vItemLink, vItemLocation = self:GetLocationItemLink(pLocation)

	if not vItemLink then
		return vSortInfo
	end

	local vName, _, _, vLevel = C_Item.GetItemInfo(vItemLink)

	vSortInfo.Name = vName
	vSortInfo.Level = vLevel or 0

	local vUpgradeInfo = C_Item.GetItemUpgradeInfo and C_Item.GetItemUpgradeInfo(vItemLink)

	if vUpgradeInfo
	and (vUpgradeInfo.trackStringID or vUpgradeInfo.trackString) then
		-- maxItemLevel is where this item's track tops out, which orders the tracks
		-- (Myth over Hero over Champion and so on) as a number, without having to
		-- recognize the track's name.  trackString is localized, so anything keyed
		-- off the name only works on an enUS client

		vSortInfo.HasTrack = true
		vSortInfo.TrackCeiling = vUpgradeInfo.maxItemLevel or 0
		vSortInfo.TrackStringID = vUpgradeInfo.trackStringID or 0

		-- Whether the track still has anywhere to go, which is the part that decides
		-- if the track is worth ranking on (see ResolveUpgradableItems)

		vSortInfo.HasUpgradeHeadroom = (vUpgradeInfo.currentLevel or 0) < (vUpgradeInfo.maxLevel or 0)
		vSortInfo.CanUpgrade = self:ItemCanBeUpgraded(vItemLocation)
	end

	return vSortInfo
end

-- A track says how good an item can *become*, which stops being meaningful once it
-- can't be upgraded any more: last season's finished Myth piece would otherwise
-- outrank everything on this season's lower tracks no matter how its item level
-- compares.  Only items which can still be upgraded keep their track; the rest are
-- handed to the banding below and placed on item level, the same as crafted gear

function Outfitter._FlyoutQuickSlots:ResolveUpgradableItems(pSortInfos)
	-- C_ItemUpgrade.CanUpgradeItem is the real answer, but it isn't certain to be
	-- meaningful away from an upgrade vendor.  If it turns up nothing upgradable
	-- while the item data says otherwise, fall back to what the track itself says

	local vAnyCanUpgrade = false

	for _, vSortInfo in ipairs(pSortInfos) do
		if vSortInfo.CanUpgrade then
			vAnyCanUpgrade = true
			break
		end
	end

	for _, vSortInfo in ipairs(pSortInfos) do
		local vIsUpgradable

		if vAnyCanUpgrade then
			vIsUpgradable = vSortInfo.CanUpgrade
		else
			vIsUpgradable = vSortInfo.HasUpgradeHeadroom
		end

		vSortInfo.OnTrack = (vSortInfo.HasTrack and vIsUpgradable) or false

		if not vSortInfo.OnTrack then
			vSortInfo.TrackCeiling = 0
			vSortInfo.TrackStringID = 0
		end
	end
end

-- Crafted gear, older gear, and anything which can no longer be upgraded carries no
-- usable track, so rather than dropping it below everything which does, work out
-- which track's item level range it falls in and sort it into that group.  The
-- ranges are taken from the items in this flyout instead of a per-season table, so
-- nothing here needs revisiting when item levels move

function Outfitter._FlyoutQuickSlots:AssignTrackBands(pSortInfos)
	local vTrackMinLevels

	for _, vSortInfo in ipairs(pSortInfos) do
		if vSortInfo.OnTrack
		and vSortInfo.TrackCeiling > 0
		and vSortInfo.Level > 0 then
			if not vTrackMinLevels then
				vTrackMinLevels = {}
			end

			local vMinLevel = vTrackMinLevels[vSortInfo.TrackCeiling]

			if not vMinLevel
			or vSortInfo.Level < vMinLevel then
				vTrackMinLevels[vSortInfo.TrackCeiling] = vSortInfo.Level
			end
		end
	end

	-- No tracks to compare against, so leave everything as it is and let the
	-- comparator fall through to name and item level

	if not vTrackMinLevels then
		return
	end

	for _, vSortInfo in ipairs(pSortInfos) do
		if not vSortInfo.OnTrack
		and vSortInfo.Level > 0 then
			-- Join the highest track whose range starts at or below this item

			for vTrackCeiling, vMinLevel in pairs(vTrackMinLevels) do
				if vSortInfo.Level >= vMinLevel
				and vTrackCeiling > vSortInfo.TrackCeiling then
					vSortInfo.TrackCeiling = vTrackCeiling
				end
			end
		end
	end
end

function Outfitter._FlyoutQuickSlots.CompareItemSortInfo(pInfo1, pInfo2)
	-- Highest upgrade track first, ranked by where the track tops out, which puts
	-- Myth over Hero over Champion and so on.  Untracked items have been given the
	-- ceiling of the track their item level lands in, so only gear below every
	-- track's range is left at 0

	if pInfo1.TrackCeiling ~= pInfo2.TrackCeiling then
		return pInfo1.TrackCeiling > pInfo2.TrackCeiling
	end

	-- Two distinct tracks that happen to top out at the same item level, so keep
	-- each of them together rather than interleaving them

	if pInfo1.OnTrack
	and pInfo2.OnTrack
	and pInfo1.TrackStringID ~= pInfo2.TrackStringID then
		return pInfo1.TrackStringID > pInfo2.TrackStringID
	end

	-- Highest item level next, so within a track the most upgraded pieces come first

	if pInfo1.Level ~= pInfo2.Level then
		return pInfo1.Level > pInfo2.Level
	end

	if pInfo1.Name ~= pInfo2.Name then
		-- Items whose name isn't in the client cache yet go last within their track

		if not pInfo1.Name then
			return false
		end

		if not pInfo2.Name then
			return true
		end

		return pInfo1.Name < pInfo2.Name
	end

	-- Still tied, so keep the order the flyout gave us instead of letting equal
	-- items shuffle each time it's opened

	return pInfo1.Index < pInfo2.Index
end

function Outfitter._FlyoutQuickSlots:SortItems(pItemDisplayTable, pNumItems)
	if not pNumItems
	or pNumItems < 2 then
		return
	end

	-- Locations at or above this are the flyout's own entries (place in bags,
	-- ignore slot) rather than items

	local vFirstSpecialLocation = EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION or 0xFFFFFFFD

	local vSortInfos = {}
	local vDisplayIndexes = {}

	for vIndex = 1, pNumItems do
		local vLocation = pItemDisplayTable[vIndex]

		if type(vLocation) == "number"
		and vLocation > 0
		and vLocation < vFirstSpecialLocation then
			table.insert(vSortInfos, self:GetItemSortInfo(vLocation, vIndex))
			table.insert(vDisplayIndexes, vIndex)
		end
	end

	self:ResolveUpgradableItems(vSortInfos)
	self:AssignTrackBands(vSortInfos)

	table.sort(vSortInfos, self.CompareItemSortInfo)

	-- Write the items back into the slots they came from, which leaves the
	-- flyout's own entries where Blizzard put them

	for vIndex, vSortInfo in ipairs(vSortInfos) do
		pItemDisplayTable[vDisplayIndexes[vIndex]] = vSortInfo.Location
	end
end

function Outfitter._FlyoutQuickSlots:PreClick(pButton, ...)
	self.CurrentInventorySlot = Outfitter.cSlotIDToInventorySlot[pButton:GetID()]
end

function Outfitter._FlyoutQuickSlots:PostClick(pButton, ...)
	local vSlotItemLink = Outfitter:GetInventorySlotIDLink(pButton.id or pButton:GetID())
	
	if EquipmentFlyoutFrame:IsVisible() and EquipmentFlyoutFrame.button == pButton then
		EquipmentFlyoutFrame:Hide()

	-- If there's an item on the cursor after clicking or the slot is empty then open the flyout
	elseif CursorHasItem() or not vSlotItemLink then
		pButton.popoutButton.flyoutLocked = true
		EquipmentFlyout_Show(pButton)
		EquipmentFlyoutPopoutButton_SetReversed(pButton.popoutButton, true)
	end
end

----------------------------------------
----------------------------------------

function Outfitter:InitializeQuickSlots()
	Outfitter.QuickSlots = Outfitter:New(Outfitter._FlyoutQuickSlots)
end

Outfitter:RegisterOutfitEvent("OUTFITTER_INIT", function () Outfitter:InitializeQuickSlots() end)
