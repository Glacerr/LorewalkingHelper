-- Title         : LorewalkingHelper
-- Author        : Glacerr
-- Last Updated  : 22SEP2026
-- Game Version  : 12.1.0
-- Addon Version : 1.1.0
-- https://github.com/Glacerr/LorewalkingHelper

-- Addon config
local ADDON_NAME = ...
local DB
local KEYBIND
local RESET_KEYBIND
local LOGOUT_KEYBIND
local TEMP_INTERACT_KEY
local STARTOVER
local MAXLEVEL = 90

local function InitDB()
    LorewalkingHelperDB = LorewalkingHelperDB or {}
    DB = LorewalkingHelperDB

    if DB.enabled == nil then
        DB.enabled = true
    end
end

-- Li Li/cho Gossip id's
local GOSSIP_IDS = {
    [124311] = true, -- Lorewalking (start)
    [136652] = true, -- Enter Lorewalking
    [136642] = true  -- Continue Lorewalking
}

-- Quest ID's
local warpack = 49965
local loa     = 92826

-- Zone ids
local stormwind     = 84
local orgrimmar     = 85
local dornogal      = 2339
local silvermoon    = 2393
local zandalar_king = 1165
local zandalar_gonk = 862

-- targets
local LiLi = "Li Li Stormstout"
local King = "King Rastakhan"
local Gonk = "Gonk"

-- Create the secure buttons
-- main macro
local mainButton = CreateFrame("Button", "MainButton", UIParent, "SecureActionButtonTemplate")
mainButton:SetAttribute("type", "macro") 
-- reset
local resetButton = CreateFrame("Button", "ResetButton", UIParent, "SecureActionButtonTemplate")
resetButton:SetAttribute("type", "macro") 
resetButton:SetAttribute("macrotext", "/lw startover")
-- logout
local logoutButton = CreateFrame("Button", "LogoutButton", UIParent, "SecureActionButtonTemplate")
logoutButton:SetAttribute("type", "macro") 
logoutButton:SetAttribute("macrotext", "/logout")

-- create interact frame
local interactAnchor = CreateFrame("Frame", "InteractOverrideAnchor", UIParent)

-- Window Frame
local window = CreateFrame("Frame", "LorewalkingWindow", UIParent, "BackdropTemplate")
-- set highest frame strata
window:SetFrameStrata("TOOLTIP")

window:SetSize(450, 250)
window:SetPoint("CENTER")
window:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8x8",
})
window:SetBackdropColor(0, 0, 0, 1)

window:SetMovable(true)
window:SetResizable(true)
window:SetResizeBounds(300, 160, 800, 500)
window:SetClampedToScreen(true)
window:EnableMouse(true)
window:RegisterForDrag("LeftButton")

window:SetScript("OnDragStart", window.StartMoving)
window:SetScript("OnDragStop", window.StopMovingOrSizing)

local resizeButton = CreateFrame("Button", nil, window)
resizeButton:SetPoint("BOTTOMRIGHT", -4, 4)
resizeButton:SetSize(18, 18)
resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeButton:SetScript("OnMouseDown", function()
	window:StartSizing("BOTTOMRIGHT")
end)
resizeButton:SetScript("OnMouseUp", function()
	window:StopMovingOrSizing()
end)

local text = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetFont("Interface\\AddOns\\LorewalkingHelper\\media\\fonts\\Ubuntu-Medium.ttf", 18)
text:SetPoint("TOPLEFT", 25, -25)
text:SetPoint("BOTTOMRIGHT", -25, 25)
text:SetJustifyH("LEFT")
text:SetJustifyV("TOP")

local textLvl = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
textLvl:SetFont("Interface\\AddOns\\LorewalkingHelper\\media\\fonts\\Ubuntu-Medium.ttf", 18)
textLvl:SetPoint("BOTTOMLEFT", 25, 15)

local textXP = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
textXP:SetFont("Interface\\AddOns\\LorewalkingHelper\\media\\fonts\\Ubuntu-Medium.ttf", 18)
textXP:SetPoint("BOTTOMRIGHT", -25, 15)

-- start hidden
window:Hide()

local function PrintToWindow(msg)
    text:SetText(msg)
end

local function PrintLevel(msg)
    textLvl:SetText(msg)
end

local function PrintXP(msg)
    textXP:SetText(msg)
end

local function UpdateMacro(text)
	macroBody = string.format("%s", text)
    mainButton:SetAttribute("macrotext", macroBody)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
eventFrame:RegisterEvent("SPELL_CONFIRMATION_PROMPT")
eventFrame:RegisterEvent("QUEST_DETAIL")
eventFrame:RegisterEvent("QUEST_COMPLETE")
eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
eventFrame:RegisterEvent("CLIENT_SCENE_CLOSED")
eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
-- not using for now, saving for future use if needed
-- eventFrame:RegisterEvent("UNIT_ENTERING_VEHICLE")
-- eventFrame:RegisterEvent("UNIT_EXITING_VEHICLE")
-- eventFrame:RegisterEvent("VEHICLE_UPDATE")
-- eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
-- eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

--------------------------------------------------
-- Events
--------------------------------------------------
eventFrame:SetScript("OnEvent", function(_, event, arg1)

	if InCombatLockdown() then
        return
    end

    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitDB()
		if not DB.enabled then
			return
		elseif DB.enabled then
			if DB and DB.primaryKeybind then
				KEYBIND = DB.primaryKeybind
				TEMP_INTERACT_KEY = DB.primaryKeybind
				PrintToWindow("Lorewalking Helper\n\nKeybind: " .. KEYBIND .. "")
				-- Bind the key for targeting on initial addon or reload
				SetOverrideBindingClick(mainButton, true, KEYBIND, "MainButton", "LeftButton")
				ClearOverrideBindings(interactAnchor)
			else
				PrintToWindow("Lorewalking Helper\n\nNo Keybind Set!\n\nSet with: '/lw kb <your keybind>'")
			end

			if DB and DB.resetKeybind then
				RESET_KEYBIND = DB.resetKeybind
				-- Bind the key for lorewalking reset
				SetOverrideBindingClick(resetButton, true, RESET_KEYBIND, "ResetButton", "LeftButton")
			end

			if DB and DB.logoutKeybind then
				LOGOUT_KEYBIND = DB.logoutKeybind
				-- Bind the key for logout
				SetOverrideBindingClick(logoutButton, true, LOGOUT_KEYBIND, "LogoutButton", "LeftButton")
			end

			-- enable 'click to move'
			C_CVar.SetCVar("autointeract", 1)
			-- enable interact key. I don't disable it later, the user can do that themselves if they want
			C_CVar.SetCVar("SoftTargetInteract", "3")
			-- reset view 4 to default to use later
			ResetView(4)

			-- print level and xp info
			local curlevel = UnitLevel("player")
			local curXP = UnitXP("player")
			PrintLevel("LVL:  " .. curlevel)
			PrintXP("XP:  " .. curXP)

			if window and not window:IsVisible() then
				window:Show()
			end

		else
			return
		end
	end
	
	if event == "PLAYER_LOGIN" then
        -- re-register my slash prefixes
        SLASH_LOREWALKINGHELPER1 = "/lw"
		SLASH_LOREWALKINGHELPER2 = "/lorewalking"

		-- block guild invites for unwanted popups
		-- maybe add code someday to hide/block party invites as well
		SetAutoDeclineGuildInvites(true)

	elseif event == "PLAYER_LOGOUT" then
		-- undo click to move
		C_CVar.SetCVar("autointeract", 0)
	end

	if event == "PLAYER_XP_UPDATE" then
		local curlevel = UnitLevel("player")
		local curXP = UnitXP("player")
		PrintLevel("LVL:  " .. curlevel)
		PrintXP("XP:  " .. curXP)
	elseif event == "PLAYER_LEVEL_UP" then
		local level = arg1
		local curXP = UnitXP("player")
		if level == MAXLEVEL then
			PrintToWindow("DING DING DING!\n\nCONGRATULATIONS!\nYou've reached level " .. level)
		else
			PrintToWindow("DING DING DING!!\n\nYou've reached level " .. level)
			PrintLevel("LVL:  " .. level)
			PrintXP("XP:  " .. curXP)
		end
	end

	if KEYBIND and TEMP_INTERACT_KEY and DB.enabled then

		if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
			C_Timer.After(0.5, function() -- short delay to let the frame load
				-- If no quest in log, then LOA start over button
				if PlayerChoiceFrame and PlayerChoiceFrame:IsVisible() then
					-- confirm quest is visible to continue
					local checkQuest = C_QuestLog.GetLogIndexForQuestID(warpack)
					local beginText = C_PlayerChoice.GetCurrentPlayerChoiceInfo().options[5].buttons[1].text
					if checkQuest and not STARTOVER then
						-- continue the story
						C_PlayerChoice.SendPlayerChoiceResponse(C_PlayerChoice.GetCurrentPlayerChoiceInfo().options[5].buttons[1].id)
						PlayerChoiceFrame.CloseButton:Click()
						PrintToWindow("RESUME THE STORY..")
					elseif beginText == "Begin" then
						-- start the story for the very first time
						C_PlayerChoice.SendPlayerChoiceResponse(C_PlayerChoice.GetCurrentPlayerChoiceInfo().options[5].buttons[1].id)
						PlayerChoiceFrame.CloseButton:Click()
						STARTOVER = false
						local endTime = GetTime() + 60

						window:SetScript("OnUpdate", function(self)
							local remaining = endTime - GetTime()

							if remaining <= 0 then
								PrintToWindow("STORY TIME.. ZZZzzz")
								self:SetScript("OnUpdate", nil)
								return
							end
							PrintToWindow("STORY TIME.. ZZZzzz\n\nTime Remaining: " .. math.ceil(remaining))
						end)
					else
						-- Start the story over
						C_PlayerChoice.SendPlayerChoiceResponse(C_PlayerChoice.GetCurrentPlayerChoiceInfo().options[5].buttons[2].id)
						PlayerChoiceFrame.CloseButton:Click()
						STARTOVER = false
						local endTime = GetTime() + 60

						window:SetScript("OnUpdate", function(self)
							local remaining = endTime - GetTime()

							if remaining <= 0 then
								PrintToWindow("STORY TIME.. ZZZzzz")
								self:SetScript("OnUpdate", nil)
								return
							end
							PrintToWindow("STORY TIME.. ZZZzzz\n\nTime Remaining: " .. math.ceil(remaining))
						end)
					end
				end
			end)

		elseif event == "UNIT_ENTERED_VEHICLE" then
			local zone = C_Map.GetBestMapForUnit("player")
			if zone ~= zandalar_king and zone ~= zandalar_gonk then
				UpdateMacro("/cleartarget\n/targetexact Li Li Stormstout")
				ClearOverrideBindings(interactAnchor)
			end

		elseif event == "UNIT_EXITED_VEHICLE" then
			local zone = C_Map.GetBestMapForUnit("player")
			local checkQuest = C_QuestLog.GetLogIndexForQuestID(warpack)
			local checkQuest2 = C_QuestLog.GetLogIndexForQuestID(loa)
			local inLorewalking = C_UnitAuras.GetPlayerAuraBySpellID(463943)
			if zone ~= zandalar_king and zone ~= zandalar_gonk and not checkQuest and not checkQuest2 and not inLorewalking then
				UpdateMacro("/cleartarget\n/targetexact Li Li Stormstout")
				ClearOverrideBindings(interactAnchor)
				PrintToWindow("START LOREWALKING")
			end

		elseif event == "PLAYER_TARGET_CHANGED" then
			if not QuestFrame:IsVisible() then
				local targetName = UnitName("target")
				if targetName == LiLi or targetName == King or targetName == Gonk then
					SetOverrideBinding(interactAnchor, true, TEMP_INTERACT_KEY, "INTERACTTARGET")
				else
					UpdateMacro("/targetexact Gonk\n/targetexact King Rastakhan\n/targetexact Li Li Stormstout")
					ClearOverrideBindings(interactAnchor)
				end
			end

		elseif event == "GOSSIP_SHOW" then
			local options = C_GossipInfo.GetOptions()
			if not options then
				return
			end

			for _, optionInfo in ipairs(options) do
				local id = optionInfo.gossipOptionID

				if GOSSIP_IDS[id] then
					C_GossipInfo.SelectOption(id)
					print("|cFF00FF00[Lorewalking Auto-Select]:|r Quest: (" .. id .. ") " .. optionInfo.name)
					return
				end
			end
			if GossipFrame and GossipFrameCloseButton then
				GossipFrameCloseButton:Click()
			end

		elseif event == "QUEST_WATCH_UPDATE" then
			local zone = C_Map.GetBestMapForUnit("player")
			if C_QuestLog.GetLogIndexForQuestID(loa) and zone ~= zandalar_king and zone ~= zandalar_gonk then
				UpdateMacro("/cleartarget\n/targetexact Li Li Stormstout")
				ClearOverrideBindings(interactAnchor)
				PrintToWindow("STORY FINISHED, LET'S GO!")
			end

		elseif event == "SPELL_CONFIRMATION_PROMPT" then
			UpdateMacro("/click StaticPopup1Button1")

		elseif event == "ZONE_CHANGED_NEW_AREA" or event == "LOADING_SCREEN_DISABLED" or event == "PLAYER_ENTERING_WORLD" or (event == "CLIENT_SCENE_CLOSED" and STARTOVER) then
			-- short delay to let zones api's load
			C_Timer.After(0.2, function()
				-- print level and xp info
				local curlevel = UnitLevel("player")
				local curXP = UnitXP("player")
				PrintLevel("LVL:  " .. curlevel)
				PrintXP("XP:  " .. curXP)

				local zone = C_Map.GetBestMapForUnit("player")
				if zone == stormwind or zone == orgrimmar or zone == dornogal or zone == silvermoon then
					UpdateMacro("/targetexact Li Li Stormstout")
					ClearOverrideBindings(interactAnchor)
					local checkQuest = C_QuestLog.GetLogIndexForQuestID(warpack)
					SetView(4) -- wide angle to get Gronk in view for targeting
					if checkQuest and not STARTOVER then
						PrintToWindow("RESUME LOREWALKING")
					else
						PrintToWindow("START LOREWALKING")
					end
				elseif zone == zandalar_king then
					SetView(1) -- close up to help with targeting with the other big dinos around
					-- slight delay for cameria view change
					C_Timer.After(0.3, function()
						UpdateMacro("/leavevehicle\n/cast Exit Lorewalking\n/targetexact King Rastakhan")
						ClearOverrideBindings(interactAnchor)
						PrintToWindow("KING RASTAKHAN")
					end)
				elseif zone == zandalar_gonk then
					UpdateMacro("/targetexact Gonk\n/cast Exit Lorewalking")
					ClearOverrideBindings(interactAnchor)
					PrintToWindow("GONK")
				end
			end)

		elseif event == "QUEST_DETAIL" then
			if GetTitleText() == "The Warpack" then
				AcceptQuest()
				UpdateMacro("/click StaticPopup1Button1")
				ClearOverrideBindings(interactAnchor)
				PrintToWindow("START WARPACK QUEST")
			end

		elseif event == "QUEST_COMPLETE" then
			if GetTitleText() == "The Warpack" then
				GetQuestReward()
				UpdateMacro("/click StaticPopup1Button1")
				ClearOverrideBindings(interactAnchor)
				PrintToWindow("COMPLETE WARPACK QUEST")
			end
		end
	end
end)

--------------------------------------------------
-- Slash Commands
--------------------------------------------------
SLASH_LOREWALKINGHELPER1 = "/lw"
SLASH_LOREWALKINGHELPER2 = "/lorewalking"

SlashCmdList["LOREWALKINGHELPER"] = function(msg)
    local cmd, param = msg:match("^%s*(%S+)%s*(.-)%s*$")
    cmd = cmd and cmd:lower()

    if cmd == "on" then
		if DB.enabled == true then
			print("|cff00ff00Lorewalking Helper is already Enabled!|r")
		else
			DB.enabled = true
			if DB.primaryKeybind then
				userKeybind = DB.primaryKeybind
				KEYBIND = userKeybind
				TEMP_INTERACT_KEY = userKeybind 
				C_CVar.SetCVar("autointeract", 1)
				C_CVar.SetCVar("SoftTargetInteract", "3")
				SetOverrideBindingClick(mainButton, true, userKeybind, "MainButton", "LeftButton")
				print("|cff00ff00Lorewalking Helper Enabled|r")
				local zone = C_Map.GetBestMapForUnit("player")
				local targetName = UnitName("target")
				if zone == stormwind or zone == orgrimmar or zone == dornogal or zone == silvermoon then
					if targetName == LiLi then
						SetOverrideBinding(interactAnchor, true, TEMP_INTERACT_KEY, "INTERACTTARGET")
					else
						UpdateMacro("/targetexact Li Li Stormstout")
						ClearOverrideBindings(interactAnchor)
					end

					local checkQuest = C_QuestLog.GetLogIndexForQuestID(warpack)
					if checkQuest then
						PrintToWindow("RESUME LOREWALKING")
					else
						PrintToWindow("START LOREWALKING")
					end
				elseif zone == zandalar_king then
					-- timer to give the viewing angle time to adjust
					SetView(1) -- close up to help with targeting with the other big dinos around
					if targetName == King then
						SetOverrideBinding(interactAnchor, true, TEMP_INTERACT_KEY, "INTERACTTARGET")
					else
						UpdateMacro("/leavevehicle\n/cast Exit Lorewalking\n/targetexact King Rastakhan")
						ClearOverrideBindings(interactAnchor)
					end
					PrintToWindow("KING RASTAKHAN")
				elseif zone == zandalar_gonk then
					if targetName == Gonk then
						SetOverrideBinding(interactAnchor, true, TEMP_INTERACT_KEY, "INTERACTTARGET")
					else
						UpdateMacro("/targetexact Gonk")
						SetOverrideBindingClick(mainButton, true, userKeybind, "MainButton", "LeftButton")
						ClearOverrideBindings(interactAnchor)
					end
					PrintToWindow("GONK")
				end
			else
				PrintToWindow("Lorewalking Helper\n\nNo Keybind Set!\n\nSet with: '/lw kb <your keybind>'")
			end

			if DB.resetKeybind then
				SetOverrideBindingClick(resetButton, true, DB.resetKeybind, "resetButton", "LeftButton")
			end

			if DB.logoutKeybind then
				SetOverrideBindingClick(logoutButton, true, DB.logoutKeybind, "logoutButton", "LeftButton")
			end

			if window and not window:IsVisible() then
				window:Show()
			end
		end

    elseif cmd == "off" then
        DB.enabled = false
		C_CVar.SetCVar("autointeract", 0)
		ClearOverrideBindings(mainButton)
		ClearOverrideBindings(resetButton)
		ClearOverrideBindings(logoutButton)
		ClearOverrideBindings(interactAnchor)
		print("|cffff5555Lorewalking Helper Disabled|r")
		if window and window:IsVisible() then
            window:Hide()
        end

	elseif cmd == "kb" and param == "remove" then
		local userKeybind = tostring(param)
		DB.primaryKeybind = nil
		-- unbind the key
		ClearOverrideBindings(mainButton)
		ClearOverrideBindings(interactAnchor)
		print("|cffff5555Lorewalking Helper Primary Keybind removed|r")
		PrintToWindow("Lorewalking Helper\n\nNo Keybind Set!\n\nSet with: '/lw kb <your keybind>'")

	elseif cmd == "kbfailsafe" and param == "remove" then
		local userKeybind = tostring(param)
		DB.primaryKeybind = nil
		-- unbind the key
		ClearOverrideBindings(resetButton)
		ClearOverrideBindings(interactAnchor)
		print("|cffff5555Lorewalking Helper Failsafe Keybind removed|r")

	elseif cmd == "kblogout" and param == "remove" then
		local userKeybind = tostring(param)
		DB.primaryKeybind = nil
		-- unbind the key
		ClearOverrideBindings(logoutButton)
		ClearOverrideBindings(interactAnchor)
		print("|cffff5555Lorewalking Helper Logout Keybind removed|r")

	elseif cmd == "kb" and param == "removeall" then
		local userKeybind = tostring(param)
		DB.primaryKeybind = nil
		-- unbind the key
		ClearOverrideBindings(mainButton)
		ClearOverrideBindings(resetButton)
		ClearOverrideBindings(logoutButton)
		ClearOverrideBindings(interactAnchor)
		print("|cffff5555All Lorewalking Helper Keybinds removed|r")
		PrintToWindow("Lorewalking Helper\n\nNo Keybind Set!\n\nSet with: '/lw kb <your keybind>'")

	elseif cmd == "kb" and param ~= "" then
		local userKeybind = tostring(param)
		DB.primaryKeybind = userKeybind
		KEYBIND = userKeybind
		TEMP_INTERACT_KEY = userKeybind
		SetOverrideBindingClick(mainButton, true, userKeybind, "MainButton", "LeftButton")
		local targetName = UnitName("target")
		if targetName == LiLi or targetName == King or targetName == Gonk then
			SetOverrideBinding(interactAnchor, true, TEMP_INTERACT_KEY, "INTERACTTARGET")
		else
			UpdateMacro("/targetexact Gonk\n/targetexact King Rastakhan\n/targetexact Li Li Stormstout")
			ClearOverrideBindings(interactAnchor)
		end
		PrintToWindow("START LOREWALKING\n\nKeybind set to: " .. KEYBIND .. "")
		print("|cff00ff00Lorewalking Helper Keybind set to: |cffffff00" .. userKeybind .. "|r")

	elseif cmd == "kbfailsafe" and param ~= "" then
		local resetKeybind = tostring(param)
		DB.resetKeybind = resetKeybind
		SetOverrideBindingClick(resetButton, true, resetKeybind, "resetButton", "LeftButton")
		print("|cff00ff00Lorewalking Helper Failsafe Keybind set to: |cffffff00" .. resetKeybind .. "|r")

	elseif cmd == "kblogout" and param ~= "" then
		local logoutKeybind = tostring(param)
		DB.logoutKeybind = logoutKeybind
		SetOverrideBindingClick(logoutButton, true, logoutKeybind, "logoutButton", "LeftButton")
		print("|cff00ff00Lorewalking Helper Logout Keybind set to: |cffffff00" .. logoutKeybind .. "|r")

    elseif cmd == "startover" then
		-- set up next actions for resetting back to beginning of lorewalking
		-- check if currently NOT in lorewalking and also in one of the Lili zones, because then we need a /reload
		local inLorewalking = C_UnitAuras.GetPlayerAuraBySpellID(463943)
		if not inLorewalking then
				PrintToWindow("START LOREWALKING")
				print("|cffffff00Lorewalking Helper: Resetting|r")
				STARTOVER = true
				UpdateMacro("/targetexact Gonk\n/targetexact King Rastakhan\n/targetexact Li Li Stormstout")
				ClearOverrideBindings(interactAnchor)
		else
			-- try and remove quest if we have it, although not technically required
			local checkQuest = C_QuestLog.GetLogIndexForQuestID(warpack)
			if checkQuest then
				C_QuestLog.SetSelectedQuest(warpack)
				C_QuestLog.SetAbandonQuest()
				C_QuestLog.AbandonQuest()
			end

			UpdateMacro("/cast Exit Lorewalking\n/click StaticPopup1Button1")
			ClearOverrideBindings(interactAnchor)
			PrintToWindow("Resetting")
			print("|cffffff00Lorewalking Helper: Resetting|r")
			STARTOVER = true
		end

    elseif not cmd then
        print("Lorewalking Helper Status: " .. (DB.enabled and "|cff00ff00Enabled|r" or "|cffff5555Disabled|r"))
		if DB and DB.primaryKeybind then
        	print("Current Primary Keybind:|cffffff00 " .. DB.primaryKeybind .. "|r")
		else
			print("Current Primary Keybind: NO PRIMARY KEYBIND SET. Set one with: /lw keybind <keybind>")
		end

		if DB and DB.resetKeybind then
        	print("Current Failsafe Keybind:|cffffff00 " .. DB.resetKeybind .. "|r")
		else
			print("Current Failsafe Keybind: NO FAILSAFE KEYBIND SET. Set one with: /lw keybind <keybind>")
		end

		if DB and DB.logoutKeybind then
        	print("Current Logout Keybind:|cffffff00 " .. DB.logoutKeybind .. "|r")
		else
			print("Current Logout Keybind: NO LOGOUT KEYBIND SET. Set one with: /lw keybind <keybind>")
		end

        print("Commands: /lw on | off | kb <keybind> | kbfailsafe <keybind> | kblogout <keybind> | kb/kbfailsafe/kblogout remove | kb removeall | startover")

    else
    	print("Commands: /lw on | off | kb <keybind> | kbfailsafe <keybind> | kblogout <keybind> | kb/kbfailsafe/kblogout remove | kb removeall | startover")
    end
end