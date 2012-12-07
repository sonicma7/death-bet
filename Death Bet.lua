
local PARTY_OR_RAID = bit.bor(COMBATLOG_OBJECT_AFFILIATION_PARTY,
							  COMBATLOG_OBJECT_AFFILIATION_RAID)

--Bad = player bet on
--Player = player who made bet
--Bet = bet player made
--Raid = table to keep track of players in raid
DeathBet = {['Bad'] = {}, ['Player'] = {}, ['Bet']={}, ['Raid']={}};
--Keep track of total bets on player for printout
TotalBets = {['Bad'] = {}, ['Total'] = {}};
--Keep raid count
RaidMemberCount = 0;
--Bool to check for bets
hasBets = 0;
--Bool to check for first death (0 = No Death, 1 = Death w/winners, 2 = Death no winners)
DeathCheck = 0
--String to be used for end condition printouts
EndOutput = ""

--[[ losers[]
Name: Loser player Name
Bet : Bet loser placed
Payout: table for payouts
Player: Loser player name
Amount: Amount owed by that player
]]--
DBLosers = {['Name'] = {}, ['Bet'] = {}, ['Payout']={['Name'] = {}, ['Amount']={}}}

--[[winners[]
Name: Winner players name
Bet : Bet Winner placed
Portion: Portion of total bet against loser winner bet (winners bet)/(total winning bets)
Payout: table for winnings payout(money received)
Player: Winner player name
Amount: Amount owed to that player
]]--
DBWinners = {['Name'] = {}, ['Bet'] = {}, ['Portion']={}, ['Payout']={ ['Name'] = {}, ['Amount']={}}}


function Death_Bet_OnMouseDown()
	Death_Bet_MainFrame:StartMoving();
end

function Death_Bet_OnMouseUp()
	Death_Bet_MainFrame:StopMovingOrSizing()
end

--[[
GUI BUTTON FUNCTIONS: 
START: Starts betting
END: Force betting to end, normally automatically ended when combat starts
Announce: Announces the spread to channel.
Clear: Force clears all bets.
]]--
function Death_Bet_Start_Button_OnClick()
        START_Command("start")
end

function Death_Bet_End_Button_OnClick()
        START_Command("end")
end

function Death_Bet_Announce_Button_OnClick()
        DBSpread("Gamble", nil)
end

function Death_Bet_Clear_Button_OnClick()
        START_Command("clear")
end

--Called on game startup
--Listens for bets through whispers, guild chat, and channels
--Listens for deaths through combat log
--Listens for beginning of raid encounter to end betting
--Starts on user's "/DB start" command
function Death_Bet_OnLoad()
	Death_Bet_MainFrame:RegisterEvent("CHAT_MSG_WHISPER")
	Death_Bet_MainFrame:RegisterEvent("CHAT_MSG_CHANNEL")
	Death_Bet_MainFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	Death_Bet_MainFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	Death_Bet_MainFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	Death_Bet_MainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	SLASH_DB1 = "/DB";
	DBActive = 0
	SlashCmdList['DB'] = START_Command;
	DEFAULT_CHAT_FRAME:AddMessage("LOADED UP!")
	GUIUpdate()
end

function Send_Whisper(target, msg)
	SendChatMessage(msg,"WHISPER","Orcish",target)
end

--Function to start certain instances of gambler
--START = begin betting
--END = end betting
--CLEAR = print results and clear previous bets
function START_Command(cmd)
	--Start gambling
	if cmd == "start" and DBActive == 0 then
		DBClear()
		DB_Fill_Raid()
		local index = GetChannelName("MacheteGamble")
		SendChatMessage("==========================","CHANNEL","ORCISH",index)
		SendChatMessage(" Betting has started ","CHANNEL","ORCISH",index)
		SendChatMessage(" '!bet RAIDERNAME BETAMOUNT' ","CHANNEL","ORCISH",index)
		SendChatMessage(" ex. !bet Eibon 500 ","CHANNEL","ORCISH",index)
		SendChatMessage(" whisper !help for more commands ","CHANNEL","ORCISH",index)
		SendChatMessage("==========================","CHANNEL","ORCISH",index)
		DBActive = 1
	--End gambling in preparation for fight
	--Prints spread for gamblers
	elseif cmd == "end" and DBActive == 1 then
		local index = GetChannelName("MacheteGamble")
		SendChatMessage("=======================","CHANNEL","ORCISH",index)
		SendChatMessage(" Betting ended ","CHANNEL","ORCISH",index)
		SendChatMessage(" !odds to see possible payout ","CHANNEL","ORCISH",index)
		SendChatMessage("=======================","CHANNEL","ORCISH",index)
		DBActive = 2
		Calc_DB_Totals()
		DBSpread("Gamble", nil)
	--Clear bets for next gambling round
	--Whisper winners and losers amount needed to pay, if necessary
	elseif cmd == "clear" then
		DBClear()
	end
end

--Function to clear everything and reset addon
function DBClear()
	for k in pairs(DeathBet['Player']) do
		DeathBet['Player'][k] = nil
		DeathBet['Bad'][k] = nil
		DeathBet['Bet'][k] = nil
	end
	
	for k in pairs(TotalBets['Bad']) do
		TotalBets['Bad'][k] = nil
		TotalBets['Total'][k] = nil
	end
	
	DeathCheck = 0
	hasBets = 0
	EndOutput = ""
	DBActive = 0
end

--Function to print out help options for player
function Print_Help( player )

	if DBActive == 0 then
		Send_Whisper(player, "Betting has not started.")
	elseif DBActive == 1 then
		Send_Whisper(player, "Bets can be placed on any player in raid.")
		Send_Whisper(player, "All bets are in Gold")
		Send_Whisper(player, "The players that bet on the first raider to die wins.")
		Send_Whisper(player, "If the first raider to die was not bet on, then no one wins.")
		Send_Whisper(player, "You may only place one bet.")
		Send_Whisper(player, "Any subsequent bets will replace the previous bet.")
		Send_Whisper(player, "Bets are cleared after the raid has wiped or the boss has been killed.")
		Send_Whisper(player, "Bet commands can be done in chat channel 'machetegamble' or whispered to me.")
		Send_Whisper(player, "Currently available commands:")
		Send_Whisper(player, "Bet on a raider = '!bet RAIDERNAME BETAMOUNT'  ex. !bet Eibon 500")
		Send_Whisper(player, "Check all current bets = '!players'")
		Send_Whisper(player, "Clear your current bet = '!clear'")
	elseif DBActive == 2 then
		Send_Whisper(player, "Currently available commands:")
		Send_Whisper(player, "Check your possible payout = '!odds'")
	end
end

--Function to remove bets from player
--Used when player removed from raid or better removes bet completely
function Remove_Bet(player)
	local removekey = 0
	for key,value in pairs(DeathBet['Player']) do
		if value == player then
			removekey = key
		end
	end
	
	if removekey ~= 0 then
		Send_Whisper(DeathBet['Player'][removekey], "Bet placed for " .. DeathBet['Bet'][removekey] .. " on " .. DeathBet['Bad'][removekey] .. " has been removed.")
		table.remove(DeathBet['Player'], removekey)
		table.remove(DeathBet['Bet'], removekey)
		table.remove(DeathBet['Bad'], removekey)
		Calc_DB_Totals()
	else
		Send_Whisper(player, "No bet to clear.")
	end
end

--Remove all bets on a player
--Called when player leaves group
function Remove_Bad(bad)
	local removekey = {}
	local i = 1
	
	--Find all bets on player
	for key,value in pairs(DeathBet['Bad']) do
		if value == bad then
			removekey[i] = key
			i = i + 1
		end
	end

	--Reverse sort removekey table
	table.sort(removekey,
		function(x,y)
			return x > y
		end
		)
	
	--Remove players bet on in reverse order since the table.remove function
	--may fill in old key with next key thus making next removal wrong
	for key,value in pairs(removekey) do
		Send_Whisper(DeathBet['Player'][value], "Bet placed for " .. DeathBet['Bet'][value] .. " on " .. DeathBet['Bad'][value] .. " has been removed because they have left the raid.")
		table.remove(DeathBet['Player'], tonumber(value))
		table.remove(DeathBet['Bet'], tonumber(value))
		table.remove(DeathBet['Bad'], tonumber(value))
	end
	
	Calc_DB_Totals()
end

--Function to refill Raid array with current members
--Called on GROUP_ROSTER_UPDATE
function DB_Fill_Raid()
	--Get current count of group members
	local curCount = GetNumGroupMembers()

	--If count is different reset 'Raid' table
	if RaidMemberCount ~= curCount then
		RaidMemberCount = curCount
		for k in pairs(DeathBet['Raid']) do
			DeathBet['Raid'][k] = nil
		end
		for i=1,RaidMemberCount,1 do
			local name, rank, subgroup, level, class, fileName,
				zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)
			if name ~= nil then
				DeathBet['Raid'][i] = gsub(strupper(name), " ", "")
			end
		end
	end
	
	--Create table for list of people to remove from bets if left raid
	local BadRemove = {}
	for key,value in pairs(DeathBet['Bad']) do
		local badfound = 0
		--If in raid, set found
		for key2,value2 in pairs(DeathBet['Raid']) do
			if value == value2 then
				badfound = 1
			end
		end
		
		if value == 'NONE' then
			badfound = 1
		end
		
		--If found not set to 1 then not found in raid so add that player to list
		--Do not add to list if already on list
		if badfound == 0 then
			local lastkey = 0
			local badremfound = 0
			for key3,value3 in pairs(BadRemove) do
				lastkey = key3
				if value3 == value then
					badremfound = 1
				end
			end
			
			if badremfound == 0 then
				BadRemove[lastkey + 1] = value
			end
		end
	end
	
	--Check for bets placed by player who is no longer in raid
	for key,value in pairs(DeathBet['Player']) do
		local badfound = 0
		for key2,value2 in pairs(DeathBet['Raid']) do
			if value == value2 then
				Remove_Bet(value)
			end
		end
	end

	--For all people on list call function to remove them
	for key,value in pairs(BadRemove) do
		Remove_Bad(value)
	end
end

--Refill totals
function Calc_DB_Totals()
	--Clear totals so they can be refilled
	for k in pairs(TotalBets['Bad']) do
		TotalBets['Bad'][k] = nil
		TotalBets['Total'][k] = nil
	end
	
	local Badcount = 0
	
	for key,value in pairs(DeathBet['Bad']) do
		local foundbad = 0
		for badkey,badval in pairs(TotalBets['Bad']) do
			Badcount = badkey
			if badval == value then
				foundbad = 1
			end
		end

		if foundbad == 0 then
			Badcount = Badcount + 1
			TotalBets['Bad'][Badcount] = value
			TotalBets['Total'][Badcount] = 0
		end
	end
	
	
	for key,value in pairs(TotalBets['Bad']) do
		local totalbets = 0
		for key2,value2 in pairs(DeathBet['Bad']) do
			if value2 == value then
				TotalBets['Total'][key] = TotalBets['Total'][key] + DeathBet['Bet'][key2]
			end 
		end
	end
	
end

--Add single bet to totals
function Addto_DB_Totals(bad, bet)
	local foundbad = 0
	local lastkey = 0
	
	for key,value in pairs(TotalBets['Bad']) do
		lastkey = key
		if bad == value then
			TotalBets['Total'][key] = TotalBets['Total'][key] + bet
			foundbad = 1
		end
	end
	
	if foundbad == 0 then
		TotalBets['Bad'][lastkey + 1] = bad
		TotalBets['Total'][lastkey + 1] = bet
	end
	
	hasBets = 1
end

--Print out current total bets on players
function DBSpread(channel, person)
	local index = GetChannelName("MacheteGamble")
	if channel ~= "Whisper" then
		SendChatMessage("Spread:","CHANNEL","ORCISH",index)
	end
	
	local tmpvalue = ''
	for key,value in pairs(TotalBets['Bad']) do
		if value == 'NONE' then
			tmpvalue = "'No Death'"
		else
			tmpvalue = value
		end
		
		if channel == "Whisper" then
			Send_Whisper(person, key .. ". " .. tmpvalue .. " " ..  TotalBets['Total'][key])
		else
			SendChatMessage(key .. ". " .. tmpvalue .. " " .. TotalBets['Total'][key],"CHANNEL","ORCISH",index)
		end
	end

end

--Handle events
--Event 1 = Chat msgs to bet on a player
--Event 2 = Watch combat log for deaths and discover first death
--Event 3 = Watching for encounter start to end betting
--Event 4 = Watch for group changes to adjust raid players array
function Death_Bet_OnEvent(self, event, ...)
	local arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9 = ...;
	local lastkey = 0
	local rebet = 0
	local index = GetChannelName("MacheteGamble")
	local goodChannel = 1
	local split2 = {}

	if event == "CHAT_MSG_CHANNEL" then
		if strlower(arg9) ~= "machetegamble" then
			goodChannel = 0
			split2 = DBsplit(" ", arg1)
		end
	end
	
	if event == "GROUP_ROSTER_UPDATE" then
		DB_Fill_Raid()
	end
	
	--split arg1 (will be msg if from chat event in MacheteGamble or whisper)
	if event ~= "GROUP_ROSTER_UPDATE" and event ~= "INSTANCE_ENCOUNTER_ENGAGE_UNIT"
	    and event ~= "PLAYER_REGEN_ENABLED" and goodChannel == 1 then
		local split1 = DBsplit(" ", arg1)
		--if first val in split is !bet then add/adjust bet in arrays
		if strlower(split1[1]) == "!bet" and DBActive == 1 then
			local better = strupper(arg2)
			local bettee = strupper(split1[2])
			--Check to make sure better is not betting on self
			if bettee ~= better then
				--Check to make sure bet is a number
				local testbet = tonumber(split1[3])
				if testbet ~= nil and DBround(testbet) > 0 and DBround(testbet) < 1001 then
					--Check for previous bet from player
					for key,value in pairs(DeathBet['Player']) do
						lastkey = key
						if value == arg2 then
							rebet = key
						end
					end
					--If player already bet then change their bet
					--Otherwise add new bet
					if rebet == 0 then
						local betterInRaid = 0
						--Check to make sure better is in raid
						for key2,value2 in pairs(DeathBet['Raid']) do
							if better == value2 then
								betterInRaid = 1
								--Check to make sure bettee is in raid
								local betteeInRaid = 0
								for key,value in pairs(DeathBet['Raid']) do
									if strupper(split1[2]) == value then
										betteeInRaid = 1
										Send_Whisper(arg2, "Bet placed for " .. DBround(tonumber(split1[3])) .. " on " .. strupper(split1[2]) .. ".")
										DeathBet['Player'][lastkey+1]=arg2
										DeathBet['Bad'][lastkey+1]=strupper(split1[2])
										DeathBet['Bet'][lastkey+1]=DBround(tonumber(split1[3]))
										Addto_DB_Totals(DeathBet['Bad'][lastkey+1], DeathBet['Bet'][lastkey+1])
									end
								end
								
								if strupper(split1[2]) == "NONE" or strupper(split1[2]) == "NOONE" or strupper(split1[2]) == "NODEATH" then
									betteeInRaid = 1
									Send_Whisper(arg2, "Bet placed for " .. DBround(tonumber(split1[3])) .. " on 'No Deaths'.")
									DeathBet['Player'][lastkey+1]=arg2
									DeathBet['Bad'][lastkey+1]='NONE'
									DeathBet['Bet'][lastkey+1]=DBround(tonumber(split1[3]))
									Addto_DB_Totals(DeathBet['Bad'][lastkey+1], DeathBet['Bet'][lastkey+1])
								end
								
								--Error for bettee not in raid
								if betteeInRaid == 0 then
									Send_Whisper(arg2, "Person whom you bet on is not in raid!")
								end
							end
						end
						--Error for better not in raid
						if betterInRaid == 0 then
							Send_Whisper(arg2, "You are not in raid!")
						end
					else
						local betteeInRaid = 0
						for key,value in pairs(DeathBet['Raid']) do
							if strupper(split1[2]) == value then
								betteeInRaid = 1
								if DeathBet['Bad'][rebet] == strupper(split1[2]) and DeathBet['Bet'][rebet] == DBround(tonumber(split1[3])) then
									Send_Whisper(arg2, "You have already made that bet!")
								else
									Send_Whisper(arg2, "Bet changed from " .. DeathBet['Bet'][rebet] .. " on " .. DeathBet['Bad'][rebet] .. " to " .. DBround(tonumber(split1[3])) .. " on " .. strupper(split1[2]) .. ".")
									DeathBet['Bad'][rebet]=strupper(split1[2])
									DeathBet['Bet'][rebet]=DBround(tonumber(split1[3]))
									Calc_DB_Totals()
								end
							end
						end

						if strupper(split1[2]) == "NONE" or strupper(split1[2]) == "NOONE" or strupper(split1[2]) == "NODEATH" then
							betteeInRaid = 1
							if DeathBet['Bad'][rebet] == 'NONE' and DeathBet['Bet'][rebet] == DBround(tonumber(split1[3])) then
								Send_Whisper(arg2, "You have already made that bet!")
							else
								Send_Whisper(arg2, "Bet changed from " .. DeathBet['Bet'][rebet] .. " on " .. DeathBet['Bad'][rebet] .. " to " .. DBround(tonumber(split1[3])) .. " on 'No Deaths'.")
								DeathBet['Bad'][rebet]= 'NONE'
								DeathBet['Bet'][rebet]=DBround(tonumber(split1[3]))
								Calc_DB_Totals()
							end
						end
						
						if betteeInRaid == 0 then
							Send_Whisper(arg2, "Person whom you bet on is not in raid! Original bet still in place.")
						end
					end
				elseif testbet ~= nil and DBround(testbet) > 1000 then
					Send_Whisper(arg2, "Max is bet is 1000!")
				else
					--Error for bad bet value
					Send_Whisper(arg2, "Not a valid bet!")
				end
			else
				--Error for betting on self
				Send_Whisper(arg2, "Can not bet on yourself!")
			end
			
		elseif strlower(split1[1]) == "!bet" and DBActive == 2 then
			Send_Whisper(arg2, "Betting has ended!")
		elseif strlower(split1[1]) == "!bet" and DBActive == 0 then
			Send_Whisper(arg2, "Betting has not started!")
		end

		--Print players
		if strlower(split1[1]) == "!players" then
			if hasBets == 0 then
				Send_Whisper(arg2, "No bets have been placed.")
			else
				DBSpread("Whisper", arg2)
			end
		end
		
		--TEST FUNCTION
		if strlower(split1[1]) == "!testbet" then
			DeathBet['Player'][lastkey+1]=arg2
			if strupper(split1[2]) == 'NONE' or strupper(split1[2]) == 'NOONE' or strupper(split1[2]) == 'NODEATH' then
				DeathBet['Bad'][lastkey+1] = 'NONE'
			else
				DeathBet['Bad'][lastkey+1]=strupper(split1[2])
			end
			DeathBet['Bet'][lastkey+1]=DBround(tonumber(split1[3]))
			Addto_DB_Totals(DeathBet['Bad'][lastkey+1], DeathBet['Bet'][lastkey+1])
		end
	
		--Allows players to clear their own bet
		if strlower(split1[1]) == "!clear" and DBActive == 1 then
			Remove_Bet( arg2 )
		elseif strlower(split1[1]) == "!clear" and DBActive == 2 then
			Send_Whisper(arg2, "Can not remove bet while encounter is in progress...cheater!")
		elseif strlower(split1[1]) == "!clear" and DBActive == 0 then
			Send_Whisper(arg2, "No bet to clear.")
		end
		
		--Check for !help printout
		if strlower(split1[1]) == "!help" then
			Print_Help( arg2 )
		end
		
		--Check for !odds printout
		--Should only show odds when betting has completed and no one has died yet
		--(Can be changed to show during betting but then someone could game the system by picking someone with highest possible win and lowest possible loss)
		--Otherwise it would overwrite the winners if called again
		if strlower(split1[1]) == "!odds" and DBActive == 2 and DeathCheck == 0 then
			local madeBet = 0
			for key,value in pairs(DeathBet['Player']) do
				if value == arg2 then
					madeBet = 1
					DBPayout( DeathBet['Bad'][key], value, "Check" )
				end
			end
			if madeBet == 0 then
				Send_Whisper( arg2, "You did not make a bet!" )
			end
		elseif strlower(split1[1]) == "!odds" and DBActive == 1 then
			Send_Whisper( arg2, "Can not check payout until betting is done!" )
		elseif strlower(split1[1]) == "!odds" and DBActive == 0 then
			Send_Whisper( arg2, "Betting has not started!" )
		elseif strlower(split1[1]) == "!odds" and DBActive == 2 and DeathCheck ~= 0 then
			local whispered = 0
			for key,value in pairs(DBWinners['Payout']['Name']) do
				if value == arg2 then
					whispered = 1
					Send_Whisper(arg2, "You won! You will be paid " .. DBWinners['Payout']['Amount'][key] .. ". You will be notified of who will pay you when encounter has finished.")
				end
			end
			
			for key,value in pairs(DBLosers['Payout']['Name']) do
				if value == arg2 then
					whispered = 1
					Send_Whisper(arg2, "You lost! You will pay " .. DBLosers['Payout']['Amount'][key] .. ". You will be notified of who to pay when encounter has finished.")
				end
			end
			
			if whispered == 0 then
				Send_Whisper( arg2, "Payout has been calculated. You did not bet on this encounter!" )
			end
		end
	
		--Watch combat log
		--On unit death, check to see if its a player who was bet on and save payouts to be printed after combat has ended
		--If not player who was bet on and is in raid then no winners.
		if arg2 == "UNIT_DIED" and DBActive == 2 and DeathCheck == 0 then
			for key2,value2 in pairs(DeathBet['Raid']) do
				if strupper(arg9) == strupper(value2) then
					local name, rank, subgroup, level, class, fileName,
						zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(key2)
					for key,value in pairs(DeathBet['Bad']) do
						if strupper(arg9) == strupper(value) then
							if isDead ~= nil then
								EndOutput = arg9 .. " death. Winners and losers will be notified of pending payments."
								DeathCheck = 1
								DBPayout(strupper(arg9), nil, "Death")
							end
						end
					end

					if DeathCheck == 0 and isDead ~= nil then
						EndOutput = arg9 .. " death. No winners."
						DeathCheck = 2
					end
				end
			end
		end
	
	--Need to allow MacheteGamble channel to accept Death Bet commands but all channels should be able to use !help
	elseif goodChannel == 0 then
		if strlower(split2[1]) == "!help" then
			Print_Help( arg2 )
		elseif strlower(split2[1]) == "!bet" or strlower(split2[1]) == "!players" or strlower(split2[1]) == "!clear" or strlower(split2[1])  == "!odds" then
			Send_Whisper( arg2, "Commands for Death Bet are not accepted from that chat channel." )
		end
	end

	--On boss encounter start, end betting
	if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" and DBActive == 1 then
		START_Command("end")
	end
	
	--Check for combat ending, should not fire until boss has died or raid has wiped/boss reset
	if event == "PLAYER_REGEN_ENABLED" and DBActive == 2 then
		--On boss death with no players who were bet on dieing, reset bets
		if DeathCheck == 0 then
			for key,value in pairs(DeathBet['Bad']) do
				if value == 'NONE' then
					DeathCheck = 1
					DBPayout('NONE', nil, "Death")
				end
			end
			
			if DeathCheck == 0 then 
				EndOutput = "No deaths. No winners."
			else
				EndOutput = "No deaths. Winners and losers will be notified of pending payments."
			end
		end
		
		--Print out correct end output and clear bets for next boss
		SendChatMessage(EndOutput,"CHANNEL","ORCISH",index)
		if DeathCheck == 1 then
			Print_Payout( "Gamble", nil )
		end
		
		START_Command("clear")
	end
	
	--Update GUI with bets or changes
	GUIUpdate()
end

--Function to update the GUI with the current spread information, called after any event
function GUIUpdate()
	local outputstring = ""
	local outputstring2= ""

	if DBActive == 0 then
		outputstring = "Death Bet has not been started\n"
		outputstring2= "Death Bet has not been started"
	elseif DBActive == 1 or DBActive == 2 then
		if DBActive == 1 then
			outputstring = "CURRENTLY BETTING\n\n"
		else
			outputstring = "BETTING DONE\n\n"
		end
			
		for key,value in pairs(DeathBet['Player']) do
			outputstring2 = outputstring2 .. value .. " " .. DeathBet['Bet'][key] .. " " .. DeathBet['Bad'][key] .. "\n"
		end


			outputstring = outputstring .. "Spread:\n"
	
		for key,value in pairs(TotalBets['Bad']) do
			outputstring = outputstring .. value .. " " .. TotalBets['Total'][key] .. "\n"
		end
	end
	
	Death_Bet_MainFrame_GoldString2:SetText(outputstring2)
	Death_Bet_MainFrame_GoldString:SetText(outputstring)
end

--Function to print payout on !odds and payments when a player wins
function Print_Payout( channel, player )
	local index = GetChannelName("MacheteGamble")
	
	--Check for !odds call and print the total possible win and loss amounts for player
	if channel == "Whisper" then
		for key,value in pairs(DBWinners['Payout']['Name']) do
			if value == player then
				Send_Whisper( player, "Possible winnings: " .. DBWinners['Payout']['Amount'][key] )
			end
		end
		
		local savekey
		for key,value in pairs(DeathBet['Player']) do
			if value == player then
				savekey = key
			end
		end
		
		local saveBet = 0
		for key,value in pairs(DeathBet['Player']) do
			if value ~= player and DeathBet['Bad'][key] ~= DeathBet['Bad'][savekey] then
				if DeathBet['Bet'][key] > DeathBet['Bet'][savekey] then
					saveBet = DeathBet['Bet'][savekey]
				elseif DeathBet['Bet'][key] > saveBet then
					saveBet = DeathBet['Bet'][key]
				end
			end
		end
		Send_Whisper( player, "Possible loss: " .. saveBet )
	--Should only be called on combat end and there is a winner
	else
		--Print out loss notifications
		for key,value in pairs(DBLosers['Payout']['Name']) do
			Send_Whisper( DBLosers['Payout']['Name'][key], "You lost Death Bet!")
		end
		
		--Loop through winners
		--Set currpay to amount that needs to be paid to winner
		--If amount needed to be paid is less than the loser has to pay then move to next winner
		--If amount needed to be paid is more than the loser has to pay then reduce amount needed by what is to be paid by that loser and move to next loser
		--Logic should dictate that amount paid to winners should be equal to amount paid by losers thus everything should become 0 in loop before indexes run out and cause 'nil' error
		for key,value in pairs(DBWinners['Payout']['Amount']) do
			Send_Whisper( DBWinners['Payout']['Name'][key], "You won Death Bet!")
			local currpay = value
			local loserindex = 1
			while currpay ~= 0 do
				if DBLosers['Payout']['Amount'][loserindex] ~= 0 then
					if currpay <= DBLosers['Payout']['Amount'][loserindex] then
						Send_Whisper( DBWinners['Payout']['Name'][key], "You should receive " .. currpay .. " from " .. DBLosers['Payout']['Name'][loserindex] )
						Send_Whisper( DBLosers['Payout']['Name'][loserindex], "Pay " .. currpay .. " to " .. DBWinners['Payout']['Name'][key] )
						DBLosers['Payout']['Amount'][loserindex] = DBLosers['Payout']['Amount'][loserindex] - currpay
						currpay = 0
					else
						Send_Whisper( DBWinners['Payout']['Name'][key], "You should receive " .. DBLosers['Payout']['Amount'][loserindex] .. " from " .. DBLosers['Payout']['Name'][loserindex] )
						Send_Whisper( DBLosers['Payout']['Name'][loserindex], "Pay " .. DBLosers['Payout']['Amount'][loserindex] .. " to " .. DBWinners['Payout']['Name'][key] )
						currpay = currpay - DBLosers['Payout']['Amount'][loserindex]
						DBLosers['Payout']['Amount'][loserindex] = 0
					end
				end
				loserindex = loserindex + 1
			end
		end
	end

end

--[[
****In Developement****
Function will take a string of the person who died(post checking if valid for payouts).
]]--

function DBPayout( loser, winner, channel )
	local winnersindex = 0
	local losersindex = 0
	
	--Clear out winner/loser/payout values
	for key,value in pairs(DBWinners['Name']) do
		DBWinners['Name'][key] = nil
		DBWinners['Bet'][key] = nil
		DBWinners['Portion'][key] = nil
	end
	
	for key,value in pairs(DBLosers['Name']) do
		DBLosers['Name'][key] = nil
		DBLosers['Bet'][key] = nil
	end
	
	for key,value in pairs(DBWinners['Payout']['Name']) do
		DBWinners['Payout']['Name'][key] = nil
		DBWinners['Payout']['Amount'][key] = nil
	end
	
	for key,value in pairs(DBLosers['Payout']['Name']) do
		DBLosers['Payout']['Name'][key] = nil
		DBLosers['Payout']['Amount'][key] = nil
	end

	--Populate winners and losers table
	for key,value in pairs(DeathBet['Bad']) do
		if value == loser then
			winnersindex = winnersindex + 1
			DBWinners['Name'][winnersindex] = DeathBet['Player'][key]
			DBWinners['Bet'][winnersindex] = DeathBet['Bet'][key]
		else
			losersindex = losersindex + 1
			DBLosers['Name'][losersindex] = DeathBet['Player'][key]
			DBLosers['Bet'][losersindex] = DeathBet['Bet'][key]
		end
	end

	--Calulate and populate Portion for winners table
	local totalbets = 0
	local highbet = 0
	local highkey = 0
	for key,value in pairs(DBWinners['Bet']) do
		if highbet < value then
			highbet = value
			highkey = key
		end
		totalbets = totalbets + value
	end

	for key,value in pairs(DBWinners['Bet']) do
		DBWinners['Portion'][key] = value/totalbets
	end

	--Calculate and populate Payout table
	local totalpayout = 0
	local payindex = 0
	for key,value in pairs(DBLosers['Name']) do
		local TMPLoser = value
		local TMPAmount = 0
		for key2,value2 in pairs(DBWinners['Name']) do
			if DBLosers['Bet'][key] < highbet then
				TMPAmount = TMPAmount + DBround( DBLosers['Bet'][key]*DBWinners['Portion'][key2] )
			else
				TMPAmount = TMPAmount + DBround( DBWinners['Bet'][highkey]*DBWinners['Portion'][key2] )
			end
		end
		payindex = payindex + 1
		DBLosers['Payout']['Name'][payindex] = value
		DBLosers['Payout']['Amount'][payindex] = TMPAmount
		totalpayout = totalpayout + TMPAmount
	end
	
	payindex = 0
	for key,value in pairs(DBWinners['Name']) do
		payindex = payindex + 1
		DBWinners['Payout']['Name'][payindex] = value
		DBWinners['Payout']['Amount'][payindex] = DBround( totalpayout * DBWinners['Portion'][key] )
	end
	
	if channel == "Check" then
		Print_Payout( "Whisper", winner )
	end
end

--Function to round numbers
function DBround(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

--Function to split chat msgs
function DBsplit(delimiter, text)
  local list = {}
  local pos = 1
  if strfind("", delimiter, 1) then -- this would result in endless loops
    error("delimiter matches empty string!")
  end
  while 1 do
    local first, last = strfind(text, delimiter, pos)
    if first then -- found?
      tinsert(list, strsub(text, pos, first-1))
      pos = last+1
    else
      tinsert(list, strsub(text, pos))
      break
    end
  end
  return list
end
