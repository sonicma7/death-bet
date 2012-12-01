
local PARTY_OR_RAID = bit.bor(COMBATLOG_OBJECT_AFFILIATION_PARTY,
							  COMBATLOG_OBJECT_AFFILIATION_RAID)

DeathBet = {['Bad'] = {}, ['Player'] = {}, ['Bet']={}};


function Death_Bet_OnMouseDown()
	Death_Bet_MainFrame:StartMoving();
end

function Death_Bet_OnMouseUp()
	Death_Bet_MainFrame:StopMovingOrSizing()
end

function Death_Bet_OnLoad()
	Death_Bet_MainFrame:RegisterEvent("CHAT_MSG_WHISPER")
	Death_Bet_MainFrame:RegisterEvent("CHAT_MSG_GUILD")
	Death_Bet_MainFrame:RegisterEvent("CHAT_MSG_CHANNEL")
	Death_Bet_MainFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	SLASH_DB1 = "/DB";
	DBActive = 0
	SlashCmdList['DB'] = START_Command;
	DEFAULT_CHAT_FRAME:AddMessage("LOADED UP!")
end

function START_Command(cmd)
	if cmd == "start" and DBActive == 0 then
		local index = GetChannelName("MacheteGamble")
		SendChatMessage("=======================","CHANNEL","ORCISH",index)
		SendChatMessage("Betting has started ","CHANNEL","ORCISH",index)
		SendChatMessage("!bet name gold ","CHANNEL","ORCISH",index)
		SendChatMessage("ex. !bet Eibon 500","CHANNEL","ORCISH",index)
		SendChatMessage("whisper !help for more commands","CHANNEL","ORCISH",index)
		SendChatMessage("=======================","CHANNEL","ORCISH",index)
		DBActive = 1
	elseif cmd == "end" and DBActive == 1 then
		local index = GetChannelName("MacheteGamble")
		SendChatMessage("============================","CHANNEL","ORCISH",index)
		SendChatMessage("Betting ended ","CHANNEL","ORCISH",index)
		SendChatMessage("!odds to see possible payout ","CHANNEL","ORCISH",index)
		SendChatMessage("============================ ","CHANNEL","ORCISH",index)
		DBActive = 2
		DBSpread()
	elseif cmd == "clear" then
		DBSpread()
		DBActive = 0
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

function Death_Bet_OnEvent(self, event, ...)
	local arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9 = ...;
	local lastkey = 0
	local rebet = 0
	



	local split1 = DBsplit(" ", arg1)
	if split1[1] == "!bet" then
		for key,value in pairs(DeathBet['Player']) do
			lastkey = key
			if value == arg2 then
				DEFAULT_CHAT_FRAME:AddMessage(key)
				rebet = key
			end
		end
		if rebet == 0 then
			DeathBet['Player'][lastkey+1]=arg2
			DeathBet['Bad'][lastkey+1]=strupper(split1[2])
			DeathBet['Bet'][lastkey+1]=split1[3]
		else
			DeathBet['Bad'][rebet]=strupper(split1[2])
			DeathBet['Bet'][rebet]=split1[3]
		end
		
		
	end




	
	if split1[1] == "!players" then
		for key,value in pairs(DeathBet['Player']) do
			DEFAULT_CHAT_FRAME:AddMessage(key .. " " .. value .. " "  .. DeathBet['Bad'][key] .. " " .. DeathBet['Bet'][key])

		end
	end
	

	if arg2 == "UNIT_DIED" and DBActive == 1 then
		local index = GetChannelName("MacheteGamble")

		for key,value in pairs(DeathBet['Bad']) do
			if strupper(arg9) == strupper(value) then
				SendChatMessage(value .. " death, Payout: " .. DeathBet['Player'][key] .. " +###","CHANNEL","ORCISH",index)
				DBActive = 0
			end
		end
		
	end


	
end






function Death_Bet_Button_OnClick()
	DEFAULT_CHAT_FRAME:AddMessage("Clicky")
end

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
