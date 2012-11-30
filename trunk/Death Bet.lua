
local PARTY_OR_RAID = bit.bor(COMBATLOG_OBJECT_AFFILIATION_PARTY,
							  COMBATLOG_OBJECT_AFFILIATION_RAID)

--Bad = player bet on
--Player = player who made bet
--Bet = bet player made
--Raid = table to keep track of players in raid
DeathBet = {['Bad'] = {}, ['Player'] = {}, ['Bet']={}, ['Raid']={}};
--Keep raid count
RaidMemberCount = 0;


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

--Function to start certain instances of gambler
--START = begin betting
--END = end betting
--CLEAR = print results and clear previous bets
function START_Command(cmd)
	--Start gambling
	if cmd == "start" and DBActive == 0 then
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
		table.remove(DeathBet['Player'], removekey)
		table.remove(DeathBet['Bet'], removekey)
		table.remove(DeathBet['Bad'], removekey)
	end
end

function Remove_Bad(bad)
	local removekey = {}
	local i = 1
	
	--Find all bets on player
	for key,value in pairs(DeathBet['Bad']) do
		if value == bad then
			removekey[i] = value
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
		table.remove(DeathBet['Player'], value)
		table.remove(DeathBet['Bet'], value)
		table.remove(DeathBet['Bad'], value)
	end
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
			for key3,value3 pairs(BadRemove) do
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

	--For all people on list call function to remove them
	for key,value in pairs(BadRemove) do
		Remove_Bad(value)
	end
end

function DBSpread()
	local index = GetChannelName("MacheteGamble")
	SendChatMessage("Spread:","CHANNEL","ORCISH",index)
	
	local Badcount = 0
	local Badtotal = {}

	for key,value in pairs(DeathBet['Bad']) do
		local foundbad = 0
		for badkey,badval in pairs(Badtotal) do
			if badval == value then
				foundbad = 1
			end
		end

		if foundbad == 0 then
			Badcount = Badcount + 1
			Badtotal[Badcount] = value	
		end
	end
	
	
	for key,value in pairs(Badtotal) do
		local totalbets = 0
		for key2,value2 in pairs(DeathBet['Bad']) do
			if value2 == value then
				totalbets = totalbets + DeathBet['Bet'][key2]
			end 
		end
		SendChatMessage(value .. " " .. totalbets,"CHANNEL","ORCISH",index)

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
	local split1 = DBsplit(" ", arg1)
	--if first val in split is !bet then add/adjust bet in arrays
	if split1[1] == "!bet" then
		--Check for previous bet from player
		for key,value in pairs(DeathBet['Player']) do
			lastkey = key
			if value == arg2 then
				DEFAULT_CHAT_FRAME:AddMessage(key)
				rebet = key
			end
		end
		--If player already bet then change their bet
		--Otherwise add new bet
		if rebet == 0 then
			DeathBet['Player'][lastkey+1]=arg2
			DeathBet['Bad'][lastkey+1]=strupper(split1[2])
			DeathBet['Bet'][lastkey+1]=split1[3]
		else
			DeathBet['Bad'][rebet]=strupper(split1[2])
			DeathBet['Bet'][rebet]=split1[3]
		end
	end

	--Print players
	if split1[1] == "!players" then
		for key,value in pairs(DeathBet['Player']) do
			DEFAULT_CHAT_FRAME:AddMessage(key .. " " .. value .. " "  .. DeathBet['Bad'][key] .. " " .. DeathBet['Bet'][key])
		end
	end
	
	--Allows players to clear their own bet
	if split1[1] == "!clear" and DBActive == 1 then
		Remove_Bet( arg2 )
	end
	
	--Watch combat log
	--On unit death, check to see if its a player who was bet on and print payouts
	--On boss death with no players who were bet on dieing, reset bets
	if arg2 == "UNIT_DIED" and DBActive == 2 then
		local index = GetChannelName("MacheteGamble")

		for key,value in pairs(DeathBet['Bad']) do
			if strupper(arg9) == strupper(value) then
				SendChatMessage(value .. " death, Payout: " .. DeathBet['Player'][key] .. " +###","CHANNEL","ORCISH",index)
				DBActive = 0
			end
		end
	end

	--On boss encounter start, end betting
	if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
		START_command("end")
	end

	
end

function Death_Bet_Button_OnClick()
	DEFAULT_CHAT_FRAME:AddMessage("Clicky")
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
