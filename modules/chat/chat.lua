local E, L, P, G = unpack(select(2, ...)); --Inport: Engine, Locales, ProfileDB, GlobalDB
local CH = E:NewModule('Chat', 'AceTimer-3.0', 'AceHook-3.0', 'AceEvent-3.0')
local LSM = LibStub("LibSharedMedia-3.0")
local CreatedFrames = 0;
local lines = {};
local msgList, msgCount, msgTime = {}, {}, {}
local response		= L["You need to be at least level %d to whisper me."]
local friendError	= L["You have reached the maximum amount of friends, remove 2 for this module to function properly."]
local good, maybe, filter, login = {}, {}, {}, false

local DEFAULT_STRINGS = {
	BATTLEGROUND = L['BG'],
	GUILD = L['G'],
	PARTY = L['P'],
	RAID = L['R'],
	OFFICER = L['O'],
	BATTLEGROUND_LEADER = L['BGL'],
	PARTY_LEADER = L['PL'],
	RAID_LEADER = L['RL'],	
}

local hyperlinkTypes = {
	['item'] = true,
	['spell'] = true,
	['unit'] = true,
	['quest'] = true,
	['enchant'] = true,
	['achievement'] = true,
	['instancelock'] = true,
	['talent'] = true,
	['glyph'] = true,
}

function CH:StyleChat(frame)
	if frame.styled then return end
	local id = frame:GetID()
	local name = frame:GetName()
	local tab = _G[name..'Tab']
	local editbox = _G[name..'EditBox']

	
	tab:StripTextures()
	tab:SetAlpha(1)
	tab.SetAlpha = UIFrameFadeRemoveFrame	
	_G[tab:GetName()..'Glow']:SetTexture('Interface\\ChatFrame\\ChatFrameTab-NewMessage')
	
	tab.text = _G[name.."TabText"]
	tab.text:FontTemplate()
	tab.text:SetTextColor(unpack(E["media"].rgbvaluecolor))
	tab.text.OldSetTextColor = tab.text.SetTextColor 
	tab.text.SetTextColor = E.noop
	
	frame:SetClampRectInsets(0,0,0,0)
	frame:SetClampedToScreen(false)
	frame:StripTextures(true)
	_G[name..'ButtonFrame']:Kill()

	local a, b, c = select(6, editbox:GetRegions()); a:Kill(); b:Kill(); c:Kill()
	_G[format(editbox:GetName().."FocusLeft", id)]:Kill()
	_G[format(editbox:GetName().."FocusMid", id)]:Kill()
	_G[format(editbox:GetName().."FocusRight", id)]:Kill()	
	editbox:SetTemplate('Default', true)
	editbox:SetAltArrowKeyMode(false)
	editbox:HookScript("OnEditFocusGained", function(self) self:Show(); if not LeftChatPanel:IsShown() then LeftChatPanel.editboxforced = true; LeftChatToggleButton:GetScript('OnEnter')(LeftChatToggleButton) end end)
	editbox:HookScript("OnEditFocusLost", function(self) if LeftChatPanel.editboxforced then LeftChatPanel.editboxforced = nil; if LeftChatPanel:IsShown() then LeftChatToggleButton:GetScript('OnLeave')(LeftChatToggleButton) end end self:Hide() end)	
	editbox:SetAllPoints(LeftChatDataPanel)
	editbox:HookScript("OnTextChanged", function(self)
	   local text = self:GetText()
	   if text:len() < 5 then
		  if text:sub(1, 4) == "/tt " then
			 local unitname, realm
			 unitname, realm = UnitName("target")
			 if unitname then unitname = gsub(unitname, " ", "") end
			 if unitname and not UnitIsSameServer("player", "target") then
				unitname = unitname .. "-" .. gsub(realm, " ", "")
			 end
			 ChatFrame_SendTell((unitname or L['Invalid Target']), ChatFrame1)
		  end
	   end
	end)
	
	hooksecurefunc("ChatEdit_UpdateHeader", function()
		local type = editbox:GetAttribute("chatType")
		if ( type == "CHANNEL" ) then
			local id = GetChannelName(editbox:GetAttribute("channelTarget"))
			if id == 0 then
				editbox:SetBackdropBorderColor(unpack(E.media.bordercolor))
			else
				editbox:SetBackdropBorderColor(ChatTypeInfo[type..id].r,ChatTypeInfo[type..id].g,ChatTypeInfo[type..id].b)
			end
		else
			editbox:SetBackdropBorderColor(ChatTypeInfo[type].r,ChatTypeInfo[type].g,ChatTypeInfo[type].b)
		end
	end)
	
	frame.OldAddMessage = frame.AddMessage
	frame.AddMessage = CH.AddMessage
	
	--copy chat button
	frame.button = CreateFrame('Frame', format("CopyChatButton%d", id), frame)
	frame.button:SetAlpha(0)
	frame.button:SetTemplate('Default', true)
	frame.button:Size(20, 22)
	frame.button:SetPoint('TOPRIGHT')
	
	frame.button.tex = frame.button:CreateTexture(nil, 'OVERLAY')
	frame.button.tex:Point('TOPLEFT', 2, -2)
	frame.button.tex:Point('BOTTOMRIGHT', -2, 2)
	frame.button.tex:SetTexture([[Interface\AddOns\ElvUI\media\textures\copy.tga]])
	
	frame.button:SetScript("OnMouseUp", function(self, btn)
		if btn == "RightButton" and id == 1 then
			ToggleFrame(ChatMenu)
		else
			CH:CopyChat(frame)
		end
	end)
	
	frame.button:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
	frame.button:SetScript("OnLeave", function(self) self:SetAlpha(0) end)	
		
	CreatedFrames = id
	frame.styled = true
end

function CH:GetLines(...)
	local ct = 1
	for i = select("#", ...), 1, -1 do
		local region = select(i, ...)
		if region:GetObjectType() == "FontString" then
			lines[ct] = tostring(region:GetText())
			ct = ct + 1
		end
	end
	return ct - 1
end

function CH:CopyChat(frame)
	if not CopyChatFrame:IsShown() then
		local _, fontSize = FCF_GetChatWindowInfo(frame:GetID());
		FCF_SetChatWindowFontSize(frame, frame, 0.01)
		CopyChatFrame:Show()
		local lineCt = self:GetLines(frame:GetRegions())
		local text = table.concat(lines, "\n", 1, lineCt)
		FCF_SetChatWindowFontSize(frame, frame, fontSize)
		CopyChatFrameEditBox:SetText(text)
	else
		CopyChatFrame:Hide()
	end
end

function CH:SetupTempChat()
	local frame = FCF_GetCurrentChatFrame()
	if frame.styled then return end
	
	self:StyleChat(frame)
end

function CH:PositionChat(override)
	if E.global.chat.enable ~= true then return end
	if (InCombatLockdown() and not override and self.initialMove) or (IsMouseButtonDown("LeftButton") and not override) then return end
	
	local chat, chatbg, tab, id, point, button, isDocked, chatFound
	for i = 1, NUM_CHAT_WINDOWS do
		chat = _G[format("ChatFrame%d", i)]
		id = chat:GetID()
		point = GetChatWindowSavedPosition(id)
		
		if point == "BOTTOMRIGHT" and chat:IsShown() then
			chatFound = true
			break
		end
	end	
	
	RightChatPanel:Size(E.db.general.panelWidth, E.db.general.panelHeight)
	LeftChatPanel:Size(E.db.general.panelWidth, E.db.general.panelHeight)
	
	if chatFound then
		self.RightChatWindowID = id
	else
		self.RightChatWindowID = nil
	end
	
	for i=1, CreatedFrames do
		chat = _G[format("ChatFrame%d", i)]
		chatbg = format("ChatFrame%dBackground", i)
		button = _G[format("ButtonCF%d", i)]
		id = chat:GetID()
		tab = _G[format("ChatFrame%sTab", i)]
		point = GetChatWindowSavedPosition(id)
		_, _, _, _, _, _, _, _, isDocked, _ = GetChatWindowInfo(id)		
		
		if id > NUM_CHAT_WINDOWS then
			if point == nil then
				point = select(1, chat:GetPoint())
			end
			if select(2, tab:GetPoint()):GetName() ~= bg then
				isDocked = true
			else
				isDocked = false
			end	
		end	
		
		if not chat.isInitialized then return end
		
		if point == "BOTTOMRIGHT" and chat:IsShown() and not (id > NUM_CHAT_WINDOWS) and id == self.RightChatWindowID then
			if id ~= 2 then
				chat:ClearAllPoints()
				chat:Point("BOTTOMLEFT", RightChatDataPanel, "TOPLEFT", 1, 3)
				chat:SetSize(E.db.general.panelWidth - 11, (E.db.general.panelHeight - 60))
			else
				chat:ClearAllPoints()
				chat:Point("BOTTOMLEFT", RightChatDataPanel, "TOPLEFT", 1, 3)
				chat:Size(E.db.general.panelWidth - 11, (E.db.general.panelHeight - 60) - CombatLogQuickButtonFrame_Custom:GetHeight())				
			end
			
			
			FCF_SavePositionAndDimensions(chat)			
			
			tab:SetParent(RightChatPanel)
			chat:SetParent(tab)
		elseif not isDocked and chat:IsShown() then
			tab:SetParent(E.UIParent)
			chat:SetParent(E.UIParent)
		else
			if id ~= 2 and not (id > NUM_CHAT_WINDOWS) then
				chat:ClearAllPoints()
				chat:Point("BOTTOMLEFT", LeftChatToggleButton, "TOPLEFT", 1, 3)
				chat:Size(E.db.general.panelWidth - 11, (E.db.general.panelHeight - 60))
				FCF_SavePositionAndDimensions(chat)		
			end
			chat:SetParent(LeftChatPanel)
			tab:SetParent(GeneralDockManager)
		end		
	end
	
	self.initialMove = true;
end

local function UpdateChatTabColor(hex, r, g, b)
	for i=1, CreatedFrames do
		_G['ChatFrame'..i..'TabText']:OldSetTextColor(r, g, b)
	end
end
E['valueColorUpdateFuncs'][UpdateChatTabColor] = true

function CH:ScrollToBottom(frame)
	frame:ScrollToBottom()
	
	self:CancelTimer(frame.ScrollTimer, true)
end

function FloatingChatFrame_OnMouseScroll(frame, delta)
	if delta < 0 then
		if IsShiftKeyDown() then
			frame:ScrollToBottom()
		else
			for i = 1, 3 do
				frame:ScrollDown()
			end
		end
	elseif delta > 0 then
		if IsShiftKeyDown() then
			frame:ScrollToTop()
		else
			for i = 1, 3 do
				frame:ScrollUp()
			end
		end
		
		if CH.db.scrollDownInterval ~= 0 then
			if frame.ScrollTimer then
				CH:CancelTimer(frame.ScrollTimer, true)
			end

			frame.ScrollTimer = CH:ScheduleTimer('ScrollToBottom', CH.db.scrollDownInterval, frame)
		end		
	end
end

function CH:PrintURL(url)
	return E['media'].hexvaluecolor.."|Hurl:"..url.."|h"..url.."|h|r "
end

function CH:FindURL(event, msg, ...)
	if not CH.db.url then return false, msg, ... end
	local newMsg, found = gsub(msg, "(%a+)://(%S+)%s?", CH:PrintURL("%1://%2"))
	if found > 0 then return false, newMsg, ... end
	
	newMsg, found = gsub(msg, "www%.([_A-Za-z0-9-]+)%.(%S+)%s?", CH:PrintURL("www.%1.%2"))
	if found > 0 then return false, newMsg, ... end

	newMsg, found = gsub(msg, "([_A-Za-z0-9-%.]+)@([_A-Za-z0-9-]+)(%.+)([_A-Za-z0-9-%.]+)%s?", CH:PrintURL("%1@%2%3%4"))
	if found > 0 then return false, newMsg, ... end
end

local OldChatFrame_OnHyperlinkShow
local function URLChatFrame_OnHyperlinkShow(self, link, ...)
	if (link):sub(1, 3) == "url" then
		local ChatFrameEditBox = ChatEdit_ChooseBoxForSend()
		local currentLink = (link):sub(5)
		if (not ChatFrameEditBox:IsShown()) then
			ChatEdit_ActivateChat(ChatFrameEditBox)
		end
		ChatFrameEditBox:Insert(currentLink)
		ChatFrameEditBox:HighlightText()
		return
	end
	OldChatFrame_OnHyperlinkShow(self, link, ...)
end

function CH:ShortChannel()
	return string.format("|Hchannel:%s|h[%s]|h", self, DEFAULT_STRINGS[self] or self:gsub("channel:", ""))
end

function CH:AddMessage(text, ...)
	if type(text) == "string" then		
		if CH.db.shortChannels then
			text = text:gsub("|Hchannel:(.-)|h%[(.-)%]|h", CH.ShortChannel)
			text = text:gsub('CHANNEL:', '')
			text = text:gsub("^(.-|h) "..L['whispers'], "%1")
			text = text:gsub("^(.-|h) "..L['says'], "%1")
			text = text:gsub("^(.-|h) "..L['yells'], "%1")
			text = text:gsub("<"..AFK..">", "[|cffFF0000"..L['AFK'].."|r] ")
			text = text:gsub("<"..DND..">", "[|cffE7E716"..L['DND'].."|r] ")
			text = text:gsub("^%["..RAID_WARNING.."%]", '['..L['RW']..']')	
		end
		
		text = text:gsub('|Hplayer:Elv:', '|TInterface\\ChatFrame\\UI-ChatIcon-Blizz:12:20:0:0:32:16:4:28:0:16|t|Hplayer:Elv:')
	end
	
	self.OldAddMessage(self, text, ...)
end

if E:IsFoolsDay() then
	local playerName = UnitName('player')
	function CH:AddMessage(text, ...)
		if type(text) == "string" then
			if CH.db.shortChannels then
				text = text:gsub("|Hchannel:(.-)|h%[(.-)%]|h", CH.ShortChannel)
				text = text:gsub('CHANNEL:', '')
				text = text:gsub("^(.-|h) "..L['whispers'], "%1")
				text = text:gsub("^(.-|h) "..L['says'], "%1")
				text = text:gsub("^(.-|h) "..L['yells'], "%1")
				text = text:gsub("<"..AFK..">", "[|cffFF0000"..L['AFK'].."|r] ")
				text = text:gsub("<"..DND..">", "[|cffE7E716"..L['DND'].."|r] ")
				text = text:gsub("^%["..RAID_WARNING.."%]", '['..L['RW']..']')	
			end
			
			text = text:gsub('|Hplayer:'..playerName..':', '|TInterface\\ChatFrame\\UI-ChatIcon-Blizz:12:20:0:0:32:16:4:28:0:16|t|Hplayer:'..playerName..':')
		end
		
		self.OldAddMessage(self, text, ...)
	end
end

local hyperLinkEntered
function CH:OnHyperlinkEnter(frame, refString)
	if InCombatLockdown() then return; end
	local linkToken = refString:match("^([^:]+)")
	if hyperlinkTypes[linkToken] then
		ShowUIPanel(GameTooltip)
		GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(refString)
		hyperLinkEntered = frame;
		GameTooltip:Show()
	end
end

function CH:OnHyperlinkLeave(frame, refString)
	local linkToken = refString:match("^([^:]+)")
	if hyperlinkTypes[linkToken] then
		HideUIPanel(GameTooltip)
		hyperLinkEntered = nil;
	end
end

function CH:OnMessageScrollChanged(frame)
	if hyperLinkEntered == frame then
		HideUIPanel(GameTooltip)
		hyperLinkEntered = false;
	end
end

function CH:EnableHyperlink()
	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G[format("ChatFrame%s", i)]
		if not self.hooks[frame] then
			self:HookScript(frame, 'OnHyperlinkEnter')
			self:HookScript(frame, 'OnHyperlinkLeave')
			self:HookScript(frame, 'OnMessageScrollChanged')
		end
	end
end

function CH:DisableHyperlink()
	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G[format("ChatFrame%s", i)]
		if self.hooks[frame] then
			self:Unhook(frame, 'OnHyperlinkEnter')
			self:Unhook(frame, 'OnHyperlinkLeave')
			self:Unhook(frame, 'OnMessageScrollChanged')
		end
	end
end

function CH:EnableChatThrottle()
	self:RegisterEvent("CHAT_MSG_CHANNEL", "ChatThrottleHandler")
	self:RegisterEvent("CHAT_MSG_YELL", "ChatThrottleHandler")	
end

function CH:DisableChatThrottle()
	self:UnregisterEvent("CHAT_MSG_CHANNEL")
	self:UnregisterEvent("CHAT_MSG_YELL")	
	table.wipe(msgList); table.wipe(msgCount); table.wipe(msgTime)
end

function CH:EnableMinLevelWhisper()
	self:RegisterEvent("FRIENDLIST_UPDATE")
	self:PLAYER_LOGIN()
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", CH.CHAT_MSG_SYSTEM)
end

function CH:DisableMinLevelWhisper()
	self:UnregisterEvent("FRIENDLIST_UPDATE")
	ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", CH.CHAT_MSG_SYSTEM)
end

function CH:SetupChat(event, ...)	
	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G[format("ChatFrame%s", i)]
		local _, fontSize = FCF_GetChatWindowInfo(frame:GetID());
		self:StyleChat(frame)
		FCFTab_UpdateAlpha(frame)
		frame:SetFont(LSM:Fetch("font", self.db.font), fontSize, self.db.fontoutline)
		if self.db.fontoutline ~= 'NONE' then
			frame:SetShadowColor(0, 0, 0, 0.2)
		else
			frame:SetShadowColor(0, 0, 0, 1)
		end
		frame:SetShadowOffset((E.mult or 1), -(E.mult or 1))		
	end	
	
	if self.db.hyperlinkHover then
		self:EnableHyperlink()
	end
	
	if self.db.throttleInterval ~= 0 then
		self:EnableChatThrottle()
	end
	
	if self.db.minWhisperLevel ~= 0 then
		CH:EnableMinLevelWhisper()
	end

	GeneralDockManager:SetParent(LeftChatPanel)
	self:ScheduleRepeatingTimer('PositionChat', 1)
	self:PositionChat(true)
	
	if self.HookSecured then
		self:SecureHook('FCF_OpenTemporaryWindow', 'SetupTempChat')
		self.HookSecured = true;
	end
	
	self:UnregisterEvent('UPDATE_CHAT_WINDOWS')
	self:UnregisterEvent('UPDATE_FLOATING_CHAT_WINDOWS')
end

local sizes = {
	":14:14",
	":16:16",
	":12:20",
	":14",
}

local function PrepareMessage(author, message)
	return author:upper() .. message
end

function CH:ChatThrottleHandler(event, ...)
	local arg1, arg2 = ...
	
	if arg2 ~= "" then
		local message = PrepareMessage(arg2, arg1)
		if msgList[message] == nil then
			msgList[message] = true
			msgCount[message] = 1
			msgTime[message] = time()
		else
			msgCount[message] = msgCount[message] + 1
		end
	end
end

local locale = GetLocale()
function CH:CHAT_MSG_CHANNEL(...)
	local isSpam = nil
	if locale == 'enUS' or locale == 'enGB' then
		isSpam = CH.SpamFilter(self, ...)
	end
	
	if isSpam then
		return true;
	else
		local event, message, author = ...
		local blockFlag = false
		local msg = PrepareMessage(author, message)
		
		if msg == nil then return CH.FindURL(self, ...) end	
		-- ignore player messages
		if author == UnitName("player") then return CH.FindURL(self, ...) end
		if msgList[msg] and CH.db.throttleInterval ~= 0 then
			if difftime(time(), msgTime[msg]) <= CH.db.throttleInterval then
				blockFlag = true
			end
		end
		
		if blockFlag then
			return true;
		else
			if CH.db.throttleInterval ~= 0 then
				msgTime[msg] = time()
			end
			
			return CH.FindURL(self, ...)
		end
	end
end

function CH:CHAT_MSG_YELL(...)
	local isSpam = nil
	if locale == 'enUS' or locale == 'enGB' then
		isSpam = CH.SpamFilter(self, ...)
	end
	
	if isSpam then
		return true;
	else
		local event, message, author = ...
		local blockFlag = false
		local msg = PrepareMessage(author, message)
		
		if msg == nil then return CH.FindURL(self, ...) end	
		
		-- ignore player messages
		if author == UnitName("player") then return CH.FindURL(self, ...) end
		if msgList[msg] and msgCount[msg] > 1 and CH.db.throttleInterval ~= 0 then
			if difftime(time(), msgTime[msg]) <= CH.db.throttleInterval then
				blockFlag = true
			end
		end
		
		if blockFlag then
			return true;
		else
			if CH.db.throttleInterval ~= 0 then
				msgTime[msg] = time()
			end
			
			return CH.FindURL(self, ...)
		end
	end
end

function CH:CHAT_MSG_SAY(...)
	local isSpam = nil
	if locale == 'enUS' or locale == 'enGB' then
		isSpam = CH.SpamFilter(self, ...)
	end
	
	if isSpam then
		return true;
	else
		return CH.FindURL(self, ...)
	end
end

function CH:CHAT_MSG_WHISPER(...)
	local player, flag = select(3, ...), select(7, ...)
	if good[player] or player:find("%-") or flag == "GM" or CH.db.minWhisperLevel == 0 then return CH.FindURL(self, ...) end
	
	for i = 1, select(2, BNGetNumFriends()) do
		local toon = BNGetNumFriendToons(i)
		for j = 1, toon do
			local _, rName, rGame, rServer = BNGetFriendToonInfo(i, j)
			if rName == player and rGame == "WoW" and rServer == GetRealmName() then
				good[player] = true
				return CH.FindURL(self, ...)
			end
		end
	end
	
	if not maybe[player] then maybe[player] = {} end
	local frame = self:GetName()
	if IsAddOnLoaded("WIM") and not frame:find("WIM") then return true end
	if not maybe[player][frame] then maybe[player][frame] = {} end
	
	local id = select(12, ...)
	maybe[player][frame][id] = {}
	local n = IsAddOnLoaded("WIM") and 1 or 0
	for i = 1, select("#", ...) do
		maybe[player][frame][id][i] = select(i + n, ...)
	end
	
	local guid = select(13, ...)
	local _, class = GetPlayerInfoByGUID(guid)
	local level = (class == "DEATHKNIGHT") and 55 + CH.db.minWhisperLevel or CH.db.minWhisperLevel + 1
	if not filter[player] or filter[player] ~= level then
		filter[player] = level
		AddFriend(player, true)	-- for FriendsWithBenefits compatibility
	end
	return true
end

function CH:CHAT_MSG_WHISPER_INFORM(...)
	local _, message, player = ...
	if good[player] or CH.db.minWhisperLevel == 0 then return CH.FindURL(self, ...) end
	if filter[player] and message:find(format(response, filter[player])) then return true end
	good[player] = true
end

function CH:CHAT_MSG_SYSTEM(_, message)
	if message == ERR_FRIEND_LIST_FULL then
		E:Print(friendError)
		return
	end
	
	if CH.db.minWhisperLevel ~= 0 then
		for k in pairs(filter) do
			if message == ERR_FRIEND_ADDED_S:format(k) or message == ERR_FRIEND_REMOVED_S:format(k) then
				return true
			end
		end
	end
end

function CH:PLAYER_LOGIN()
	ShowFriends()
	good[E.myname] = true -- we're good
end

function CH:ExcludeFriends()
	for i = 1, GetNumFriends() do
		local friend = GetFriendInfo(i)
		if friend then good[friend] = true end
	end
	
	for i = 1, GetNumGuildMembers() do
		local guild = GetGuildRosterInfo(i)
		if guild then good[guild] = true end
	end
end

function CH:FRIENDLIST_UPDATE()
	if not login then
		login = true
		CH:ExcludeFriends()
		return
	end
	
	for i = 1, GetNumFriends() do
		local player, level = GetFriendInfo(i)
		
		if not player then
			ShowFriends()
		else
			if maybe[player] then
				RemoveFriend(player, true)
				if level < filter[player] then
					SendChatMessage(response:format(filter[player]), "WHISPER", nil, player)
					for _, v in pairs(maybe[player]) do
						for _, p in pairs(v) do
							wipe(p)
						end
						wipe(v)
					end
				else
					good[player] = true
					for _, v in pairs(maybe[player]) do
						for _, p in pairs(v) do
							if IsAddOnLoaded("WIM") then
								WIM.modules.WhisperEngine:CHAT_MSG_WHISPER(unpack(p))
							else
								ChatFrame_MessageEventHandler(unpack(p))
							end
							wipe(p)
						end
						wipe(v)
					end
				end
				wipe(maybe[player])
				maybe[player] = nil
			end
		end
	end
end

function CH:Initialize()
	self.db = E.db.chat
	if E.global.chat.enable ~= true then return end
	E.Chat = self
	
	FriendsMicroButton:Kill()
	ChatFrameMenuButton:Kill()
	OldChatFrame_OnHyperlinkShow = ChatFrame_OnHyperlinkShow
	ChatFrame_OnHyperlinkShow = URLChatFrame_OnHyperlinkShow
	self:RegisterEvent('UPDATE_CHAT_WINDOWS', 'SetupChat')
	self:RegisterEvent('UPDATE_FLOATING_CHAT_WINDOWS', 'SetupChat')
	
	self:SetupChat()

	ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", CH.CHAT_MSG_CHANNEL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", CH.CHAT_MSG_YELL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", CH.CHAT_MSG_SAY)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", CH.CHAT_MSG_WHISPER_INFORM)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", CH.CHAT_MSG_WHISPER)	
	ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", CH.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", CH.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", CH.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", CH.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", CH.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", CH.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BATTLEGROUND", CH.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BATTLEGROUND_LEADER", CH.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_CONVERSATION", CH.FindURL)	
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", CH.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", CH.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_INLINE_TOAST_BROADCAST", CH.FindURL)
	
	local S = E:GetModule('Skins')
	local frame = CreateFrame("Frame", "CopyChatFrame", E.UIParent)
	frame:SetTemplate('Transparent')
	frame:Size(700, 200)
	frame:Point('BOTTOM', E.UIParent, 'BOTTOM', 0, 3)
	frame:Hide()
	frame:EnableMouse(true)
	frame:SetFrameStrata("DIALOG")


	local scrollArea = CreateFrame("ScrollFrame", "CopyChatScrollFrame", frame, "UIPanelScrollFrameTemplate")
	scrollArea:Point("TOPLEFT", frame, "TOPLEFT", 8, -30)
	scrollArea:Point("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 8)
	S:HandleScrollBar(CopyChatScrollFrameScrollBar)

	local editBox = CreateFrame("EditBox", "CopyChatFrameEditBox", frame)
	editBox:SetMultiLine(true)
	editBox:SetMaxLetters(99999)
	editBox:EnableMouse(true)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(ChatFontNormal)
	editBox:Width(scrollArea:GetWidth())
	editBox:Height(200)
	editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
	scrollArea:SetScrollChild(editBox)
	
	--EXTREME HACK..
	editBox:SetScript("OnTextSet", function(self)
		local text = self:GetText()
		
		for _, size in pairs(sizes) do
			if string.find(text, size) then
				self:SetText(string.gsub(text, size, ":12:12"))
			end		
		end
	end)

	local close = CreateFrame("Button", "CopyChatFrameCloseButton", frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT")
	close:SetFrameLevel(close:GetFrameLevel() + 1)
	close:EnableMouse(true)
	
	S:HandleCloseButton(close)	
end

E:RegisterModule(CH:GetName())