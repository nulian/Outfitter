local API = {}; OutfitterAPI = API;
local IS_WOW1002 = select(4, GetBuildInfo()) >= 100002 or nil;

OutfitterAPI.IsWoW1002 = IS_WOW1002;

function API:GetContainerItemLink(...)
    if C_Container and C_Container.GetContainerItemLink then return C_Container.GetContainerItemLink(...) end
  return GetContainerItemLink(...)
end

function API:GetContainerItemInfo(...)
    if C_Container and C_Container.GetContainerItemInfo then
        local containerInfo = C_Container.GetContainerItemInfo(...)
        if containerInfo then
            return containerInfo.iconFileID
        end
        return
    end
  return GetContainerItemInfo(...)
end

function API:ContainerIDToInventoryID(...)
    if C_Container and C_Container.ContainerIDToInventoryID then return C_Container.ContainerIDToInventoryID(...) end
  return ContainerIDToInventoryID(...)
end

function API:GetContainerNumFreeSlots(...)
    if C_Container and C_Container.GetContainerNumFreeSlots then return C_Container.GetContainerNumFreeSlots(...) end
  return GetContainerNumFreeSlots(...)
end

function API:UseContainerItem(...)
    if C_Container and C_Container.UseContainerItem then return C_Container.UseContainerItem(...) end
  return UseContainerItem(...)
end

function API:GetContainerNumSlots(...)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(...) end
  return GetContainerNumSlots(...)
end

function API:PickupContainerItem(...)
    if C_Container and C_Container.PickupContainerItem then return C_Container.PickupContainerItem(...) end
  return PickupContainerItem(...)
end

function API:ShowContainerSellCursor(...)
    if C_Container and C_Container.ShowContainerSellCursor then return C_Container.ShowContainerSellCursor(...) end
  return ShowContainerSellCursor(...)
end

function API:GetNumTrackingTypes(...)
    if C_Minimap and C_Minimap.GetNumTrackingTypes then return C_Minimap.GetNumTrackingTypes(...) end
    return GetNumTrackingTypes(...)
end

function API:GetTrackingInfo(...)
    if C_Minimap and C_Minimap.GetTrackingInfo then
        local result = C_Minimap.GetTrackingInfo(...)
        if type(result) == 'table' then
            return result.name, result.texture, result.active
        else
            return C_Minimap.GetTrackingInfo(...)
        end
    else
        return GetTrackingInfo(...)
    end
end

function API:SetTracking(...)
    if C_Minimap and C_Minimap.SetTracking then return C_Minimap.SetTracking(...) end
    return SetTracking(...)
end

--
-- Secret values
--
-- Since 11.2 the game hides information the player isn't supposed to automate
-- decisions on (dungeon/raid loot being the common case) by returning "secret"
-- values instead of real ones.  A secret value can be passed around and stored,
-- but tainted (addon) code can't compare it, do arithmetic on it, concatenate
-- it, take its length or use it as a table key -- all of those raise an error.
-- Anything coming back from the game therefore has to be checked before it's
-- used, and the check has to come before any other test (including a plain
-- truthiness test) since that's an inspection too.
--

local gIsSecretValue = _G.issecretvalue

-- Returns true if pValue can't safely be inspected
function API:IsSecret(pValue)
    if not gIsSecretValue then
        return false
    end

    -- pcall in case the client doesn't accept every value type
    local vSucceeded, vIsSecret = pcall(gIsSecretValue, pValue)
    return vSucceeded and vIsSecret == true
end

-- Returns pValue, or pDefault (nil when omitted) if pValue is secret
function API:Unsecret(pValue, pDefault)
    if self:IsSecret(pValue) then
        return pDefault
    end

    return pValue
end

-- Returns pValue if it's a usable number, otherwise pDefault
function API:UnsecretNumber(pValue, pDefault)
    if self:IsSecret(pValue) or type(pValue) ~= "number" then
        return pDefault
    end

    return pValue
end
