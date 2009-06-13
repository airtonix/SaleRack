local g = getfenv(0)
local addon = DongleStub"Dongle-1.2":New"SaleRack"
local GetItemInfo = GetItemInfo
local blacklist = {}
local excludeList = {
	[2] = true,
	[4] = true,
	[11] = true,
	[12] = true,
	[13] = true,
	[14] = true,
	[15] = true,
	[19] = true,
}

function addon:Initialize()
	for _,tooltip in pairs{ItemRefTooltip,	GameTooltip} do
		local orig = tooltip:GetScript("OnTooltipSetItem")
		tooltip:SetScript("OnTooltipSetItem", function(frame, ...)
			local name = frame:GetItem()
			self:SetTooltip(frame, name)
			if orig then return orig(frame, ...) end
		end)
	end
end

function addon:Enable()
	self.db = addon:InitializeDB"SaleRackDB"
	self.profile = self.db.profile
	self.events = {}
	if( not self.profile) then self.profile = {} end
	self.slash = addon:InitializeSlashCommand("SaleRack", "SALERACK", "salerack", "sr", "gear")
	local slash = self.slash
	slash:RegisterSlashHandler("save: Saves the current items as a set.", "save (%a+)", "SaveSet")
	slash:RegisterSlashHandler("savewpn: Changes weaponset", "savewpn (%a+)", "SaveWpn")	
	slash:RegisterSlashHandler("wear: Loads a set.", "wear (%a+)", "WearSet")
	slash:RegisterSlashHandler("sets: Lists your saved sets", "sets", "ShowSets")
	slash:RegisterSlashHandler("nekkid: Lets get nekkid?!", "nekkid", "GetNekkid")
	slash:RegisterSlashHandler("del: Deletes a set", "del (%a+)", "DeleteSet")
	slash:RegisterSlashHandler("reset: OPS!! Resets all the sets", "reset", "ResetSets")
end

function addon:SaveSet(name)
	if not self.profile[name] then
		self:Print("Saving set: ".. name)
		self.profile[name] = {}
		self.profile[name].InBank = nil
	else
		self:Print("Updating set: ".. name)
	end
	local set = self.profile[name]

	for slotID = 1, 19 do
		local link = GetInventoryItemLink("player", slotID)
		if not link then 
			set[slotID] = nil
		else
			local itemid = link:match"item:(%d+):"
			set[slotID] = itemid
		end
	end
	self:FireEvent("EQUIPMENT_SETS_CHANGED")
end

function addon:SaveWpn(name)
	if not self.profile[name] then
		self:Print("Saving set: ".. name)
		self.profile[name] = {}
	else
		self:Print("Updating set: ".. name)
	end
	local set = self.profile[name]
	for slotID = 16, 17 do
		local link = GetInventoryItemLink("player", slotID)
		if not link then 
			set[slotID] = nil
		else
			local itemid = link:match"item:(%d+):"
			set[slotID] = itemid
		end
	end
	self:FireEvent("EQUIPMENT_SETS_CHANGED")
end

function addon:FindItem(item)
	for i = NUM_BAG_FRAMES, 0, -1 do
		for j = GetContainerNumSlots(i), 1, -1 do
			local link = GetContainerItemLink(i, j)
			if link then
				local ci = GetItemInfo(link)
				if ci and ci == item then return i, j end
			end
			end
	end
	return nil
end

function addon:EquipDupes(set, item, slot)
	if self.profile[set][slot-1] == self.profile[set][slot] then
		local b, s = addon:FindItem(item)
		if b then
			PickupContainerItem(b, s)
			EquipCursorItem(slot)
		end
	end
end

function addon:DeleteSet(name)
	local error = string.format("Set \"%s\" does not exist.", name)
	if not self.profile[name] then return self:Print(error) end
	self:Print("Deleting set: ".. name)
	self.profile[name] = nil
	addon:FireEvent("EQUIPMENT_SETS_CHANGED")
end

function addon:WearSet(name)
	local error = string.format("Set \"%s\" does not exist.", name)	
	if not self.profile[name] then return self:Print(error) end
	if self.profile[name].InBank then return self:Print("This set is in the bank") end
	for i,n in pairs(self.profile[name]) do
		local itemname = GetItemInfo(n)
		EquipItemByName(itemname, i)
		if i == 12 or i == 17 then
			addon:EquipDupes(name, itemname, i)
		end
	end
end

function addon:ShowSets()
	if not self.profile then return self:Print"You dont have any saved sets." end
	self:Print("Your saved sets:")
		for n,_ in pairs(self.profile) do
		self:Print("- "..n)
	end
end

function addon:FindFreeSlots()
	for b = 0,4 do
		for s = 1, GetContainerNumSlots(b) do
			if not GetContainerItemLink(b,s) and not blacklist[b..":"..s] then
				return b, s
			end
		end
	end
	return nil
end

function addon:GetNekkid()
	for i = 1,19 do
		if GetInventoryItemLink("player", i) and not excludeList[i] then
			local b,s = addon:FindFreeSlots()
			if b then
				PickupInventoryItem(i)
				PickupContainerItem(b,s)
				blacklist[b..":"..s] = true
			else
				wipe(blacklist)
				return print"No more free slots!"
			end
		end
	end
	wipe(blacklist)
end

function addon:ResetSets()
	self.db:ResetProfile()
	self:FireEvent("EQUIPMENT_SETS_CHANGED")
end

function addon:SetTooltip(frame, name)
	if not self.profile then return end
	for s, t in pairs(self.profile) do
		for sl, n in pairs(t) do
			if GetItemInfo(n) == name then
				frame:AddLine("SaleRack: "..s)
			end
		end
	end
end

function addon:FireEvent(event)
	if(self.events and self.events[event])then
		for index,func in pairs(self.events[event])do
			func()
		end
	end
end

function addon:HookEvent(event,func)
	if(not self.events)then self.events = {} end
	if(not self.events[event])then
		self.events[event] = {}
	end
	table.insert(self.events[event], func)
end

g["SaleRack"] = addon
