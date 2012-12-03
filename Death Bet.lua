
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
--Keep death count
RaidDeathCount = 0;
--Bool to check for bets
hasBets = 0;


function Death_Bet_OnMouseDown()
	Death_Bet_MainFrame:StartMoving();
end

function Death_Bet_OnMouseUp()
	Death_Bet_MainFrame:StopMovingOrSizing()
end

--Called on game startup
--Listens for bets through whispers, guild chat, and channels
--Listens for deaths through combat log
--Listens for beginning of raid encounter to end betting
--Starts on user's "/DB start" command
function Death_Bet_OnLoad()
	Death_Bet_MainFrame:RegisterEvent("CHAT_MSG_WHISPER")
	Death_Bet_MainFrame:RegisterEvent("CHAT_MSG_GUILD")
	Death_Bet_MainFrame:RegisterEvent("CHAT_MSG_CHANNEL")
	Death_Bet_MainFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	Death_Bet_MainFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	Death_Bet_MainFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	SLASH_DB1 = "/DB";
	DBActive = 0
	SlashCmdList['DB'] = START_Command;
	DEFAULT_CHAT_FRAME:AddMessage("LOADED UP!")
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
		SendChatMessage("=======================","CHANNEL","ORCISH",index)
		SendChatMessage("Betting has started ","CHANNEL","ORCISH",index)
		SendChatMessage(" !bet name gold ","CHANNEL","ORCISH",index)
		SendChatMessage("ex. !bet Eibon 500","CHANNEL","ORCISH",index)
		SendChatMessage("whisper !help for more commands","CHANNEL","ORCISH",index)
		SendChatMessage("=======================","CHANNEL","ORCISH",index)
		DBActive = 1
	--End gambling in preparation for fight
	--Prints spread for gamblers
	elseif cmd == "end" and DBActive == 1 then
		local index = GetChannelName("MacheteGamble")
		SendChatMessage("============================","CHANNEL","ORCISH",index)
		SendChatMessage("Betting ended ","CHANNEL","ORCISH",index)
		SendChatMessage("!odds to see possible payout ","CHANNEL","ORCISH",index)
		SendChatMessage("============================ ","CHANNEL","ORCISH",index)
		DBActive = 2
		Calc_DB_Totals()
		DBSpread("Gamble", nil)
	--Clear bets for next gambling round
	--Whisper winners and losers amount needed to pay, if necessary
	elseif cmd == "clear" then
		DBClear()
		DBActive = 0
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
	
	RaidDeathCount = 0
	hasBets = 0
end


--[[
function Auto_Command(cmd)
	--Start gambling
	if cmd == "start" and DBActive == 0 then
		DB_Fill_Raid()
		local index = GetChannelName("MacheteGamble")
		SendChatMessage("=======================","CHANNEL","ORCISH",index)
		SendChatMessage("Betting has started ","CHANNEL","ORCISH",index)
		SendChatMessage("!bet name gold ","CHANNEL","ORCISH",index)
		SendChatMessage("ex. !bet Eibon 500","CHANNEL","ORCISH",index)
		SendChatMessage("whisper !help for more commands","CHANNEL","ORCISH",index)
		SendChatMessage("=======================","CHANNEL","ORCISH",index)
		DBActive = 1
	--End gambling in preparation for fight
	--Prints spread for gamblers
	elseif cmd == "end" and DBActive == 1 then
		local index = GetChannelName("MacheteGamble")
		SendChatMessage("============================","CHANNEL","ORCISH",index)
		SendChatMessage("Betting ended ","CHANNEL","ORCISH",index)
		SendChatMessage("!odds to see possible payout ","CHANNEL","ORCISH",index)
		SendChatMessage("============================ ","CHANNEL","ORCISH",index)
		DBActive = 2
		DBSpread()
	--Clear bets for next gambling round
	--Whisper winners and losers amount needed to pay, if necessary
	elseif cmd == "clear" then
		DBSpread()
		DBActive = 0
	end
end --]]

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
			DeathBet['Raid'][i] = strupper(name)
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

function DBSpread(channel, person)
	local index = GetChannelName("MacheteGamble")
	if channel ~= "Whisper" then
		SendChatMessage("Spread:","CHANNEL","ORCISH",index)
	end
	
	for key,value in pairs(TotalBets['Bad']) do
		if channel == "Whisper" then
			Send_Whisper(person, key .. ". " .. value .. " " ..  TotalBets['Total'][key])
		else
			SendChatMessage(key .. ". " .. value .. " " .. TotalBets['Total'][key],"CHANNEL","ORCISH",index)
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

	if event == "GROUP_ROSTER_UPDATE" then
		DB_Fill_Raid()
	end
	
	--split arg1 (will be msg if from chat event)
	if event ~= "GROUP_ROSTER_UPDATE" and event ~= "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
		local split1 = DBsplit(" ", arg1)
		--if first val in split is !bet then add/adjust bet in arrays
		if split1[1] == "!bet" and DBActive == 1 then
			local better = strupper(arg2)
			local bettee = strupper(split1[2])
			--Check to make sure better is not betting on self
			if bettee ~= better then
				--Check to make sure bet is a number
				local testbet = tonumber(split1[3])
				if testbet ~= nil and DBround(testbet) > 0 then
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
								Send_Whisper(arg2, "Bet changed from " .. DeathBet['Bet'][rebet] .. " on " .. DeathBet['Bad'][rebet] .. " to " .. DBround(tonumber(split1[3])) .. " on " .. strupper(split1[2]) .. ".")
								DeathBet['Bad'][rebet]=strupper(split1[2])
								DeathBet['Bet'][rebet]=DBround(tonumber(split1[3]))
								Calc_DB_Totals()
							end
						end
						
						if betteeInRaid == 0 then
							Send_Whisper(arg2, "Person whom you bet on is not in raid! Original bet still in place.")
						end
					end
				else
					--Error for bad bet value
					Send_Whisper(arg2, "Not a valid bet!")
				end
			else
				--Error for betting on self
				Send_Whisper(arg2, "Can not bet on yourself!")
			end
		end

	--Print players
		if split1[1] == "!players" then
			if hasBets == 0 then
				Send_Whisper(arg2, "No bets have been placed.")
			else
				DBSpread("Whisper", arg2)
			end
		end
	
		--Allows players to clear their own bet
		if split1[1] == "!clear" and DBActive == 1 then
			Remove_Bet( arg2 )
		elseif split1[1] == "!clear" and DBActive == 2 then
			Send_Whisper(arg2, "Can not remove bet while encounter is in progress...cheater!")
		elseif split1[1] == "!clear" and DBActive == 0 then
			Send_Whisper(arg2, "No bet to clear.")
		end
	
		--Watch combat log
		--On unit death, check to see if its a player who was bet on and print payouts
		--On boss death with no players who were bet on dieing, reset bets
		if arg2 == "UNIT_DIED" and DBActive == 2 then
			local index = GetChannelName("MacheteGamble")

			for key2,value2 in pairs(DeathBet['Raid']) do
				if strupper(arg9) == strupper(value2) then
					local deathcheck = 0
					for key,value in pairs(DeathBet['Bad']) do
						if strupper(arg9) == strupper(value) and RaidDeathCount == 0 then
							if deathcheck == 0 then
								SendChatMessage(arg9 .. " death.","CHANNEL","ORCISH",index)
							end
							deathcheck = 1
							DBPayout(strupper(arg9))
							START_Command("clear")
						end
					end
					
					if deathcheck == 0 then
						SendChatMessage(arg9 .. " death. No winners.","CHANNEL","ORCISH",index)
						START_Command("clear")
					end
				end
			end
		end
	end

	--On boss encounter start, end betting
	if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" and DBActive == 1 then
		START_Command("end")
	end
	
	--Update GUI with bets or changes
	GUIUpdate()
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


--Function to update the GUI with the current spread information, called after any event
function GUIUpdate()
	local outputstring = ""

	if DBActive == 0 then
		outputstring = "Death Bet has not been started\n"
	elseif DBActive == 1 or DBActive == 2 then
		if DBActive == 1 then
			outputstring = "CURRENTLY BETTING\n\n"
		else
			outputstring = "BETTING DONE\n\n"
		end
			
		outputstring = outputstring .. "Spread:\n"

		for key,value in pairs(TotalBets['Bad']) do
			outputstring = outputstring .. value .. " " .. TotalBets['Total'][key] .. "\n"
		end
	end
	
	Death_Bet_MainFrame_GoldString:SetText(outputstring)
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


--[[
****In Developement****
Function will take a string of the person who died(post checking if valid for payouts) and whisper all nessiary actions for payouts.
]]--

function DBPayout(loser)

	--[[winners[]
	Name: Winner players name
	Bet : Bet Winner placed
	Portion: Portion of total bet against loser winner bet (winners bet)/(total winning bets)
	Payout: table for winnings payout(money received)
	Player: Loser player name
	Amount: Amount owed to winner
	]]--
	local winners = {['Name'] = {}, ['Bet'] = {}, ['Portion']={}, ['Payout']={ ['Player'] = {}, ['Amount']={}}}
	local winnersindex = 0

	--[[ losers[]
	Name: Loser player Name
	Bet : Bet loser placed
	Payout: table for payouts
	Player: Winner player name
	Amount: Amount owed to that player
	]]--
	local losers={['Name'] = {}, ['Bet'] = {}, ['Payout']={['Player'] = {}, ['Amount']={}}}
	local losersindex = 0


	--Populate winners and losers table
	for key,value in pairs(DeathBet['Bad']) do
		if value == loser then
			winnersindex = winnersindex + 1
			winners['Name'][winnersindex]= DeathBet['Players'][key]
			winners['Name'][winnersindex]= DeathBet['Bet'][key]
		else
			losersindex = loserindex + 1
			losers['Name'][losersindex]= DeathBet['Players'][key]
			losers['Name'][losersindex]= DeathBet['Bet'][key]
		end
	end

	--Calulate and populate Portion for winners table
	local totalbets = 0
	for key,value in pairs(winners['Bet']) do
		totalbets = totalbets + value
	end

	for key,value in pairs(winners['Bet']) do
		winners['Portion'][key] = winners['Bet']/totalbets
	end

	--Calculate and populate Payout tables
	for key,value in pairs(losers['Name']) do
		local Payoutindex = 0
		for key2,value2 in pairs(winners['Name']) do
			Payoutindex = Payoutindex + 1
			if losers['Bet'][key] < winners['Bet'][key2] then
				losers['Payout']['Name'][Payoutindex] = value2	--value2 = winners['Name']
				losers['Payout']['Amount'][Payoutindex]=losers['Bet'][key]*winners['Portion']
			else
				losers['Payout']['Name'][Payoutindex] = value2	--value2 = winners['Name']
				losers['Payout']['Amount'][Payoutindex]=winners['Bet'][key2]*winners['Portion']
			end
		end
	end
	
end
