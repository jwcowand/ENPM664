TP_DBG_BOMB = 4
TP_VLT_EXPLODE = 3
TP_VLT_DISARM = 2
TP_SRL_BOMB = 5
TP_VLT_CLKENABLE = 6
TP_DBG_CLK = 7
TP_VLT_POWER = 1
TP_VLT_ERROR = 0
COUNTDOWN = 99
POWER = false
ARMED = false
DISARM = false
EXPLODE = false
RL_KeypadChip = {{name="KEYCODE", value="08090605", access=REGACCESS_READ},
				 {name="KEYSWAP", value="0F0F0F0F", access=REGACCESS_READ}}

RL_LockChip = { {name="KEYCODE", value="01040606", access=REGACCESS_READ},
				{name="KEYSWAP", value="0F0F0F0F", access=REGACCESS_READ},
				{name="ERROR", value="00000000", access=REGACCESS_READ} }
				
pulseStates = {PULSESTATE_NONE, PULSESTATE_NONE, PULSESTATE_NONE, PULSESTATE_NONE, PULSESTATE_NONE}

errorState = false

--API_WidgetSet("DiscreteLED1", "Enabled", true)
--API_WidgetSet("Switch1", "value", false)
API_WidgetSet("ExternalImage1", "enabled", false)

function LEVEL_ReadVoltage(pointId)
	if pointId == TP_VLT_ERROR and errorState == true then
		return 2.5
	end
	
	--add more here
	if pointId == TP_VLT_BOMB and EXPLODE ==true then
		return 5
	end
	if pointId == TP_VLT_POWER and API_WidgetGet("Switch1", "value")then
		return 5
	end
	if pointId == TP_VLT_CLKENABLE and ARMED==true then
		return 5
	end
	return 0
end

function LEVEL_SetPulse(pointId, pulseState)
	pulseStates[pointId+1] = pulseState
end

function LEVEL_ReadDebug(pointId)
	if pointId == TP_DBG_CLK then
		return RL_LockChip
	elseif pointId == TP_DBG_BOMB then
		return RL_KeypadChip
	end
	return nil
end

function LEVEL_WriteDebug(pointId, registerIndex, registerValue)
	-- All of the registers for this level are read only!
end

function LEVEL_WriteSerial(pointId, serialData)
	if pointId == TP_SRL_BOMB and string.find("123456789",serialData) ~= nil then
		if (ARMED==true and DISARM ==true) then
		SendSerialData(serialData)
		end
	end
end

function LEVEL_Update(timeDelta)
	if pulseStates[TP_VLT_ERROR+1] == PULSESTATE_HIGH or ( pulseStates[TP_VLT_ERROR+1] ~= PULSESTATE_LOW and errorState == true ) then
		API_WidgetSet("DiscreteLED3", "Enabled", true)
	else
		API_WidgetSet("DiscreteLED3", "Enabled", false)
	end
	if API_WidgetGet("Switch1", "value") then
		API_WidgetSet("DiscreteLED2", "Enabled", true)
	else
		API_WidgetSet("DiscreteLED2", "Enabled", false)
	end
	if pulseStates[TP_VLT_DISARM+1] == PULSESTATE_HIGH then
		DISARM = true
	else 
		DISARM = false
	end
	if pulseStates[TP_VLT_EXPLODE+1] == PULSESTATE_HIGH and ARMED==true and EXPLODE==false then
		EXPLODE = true
		API_WidgetSet("ExternalImage1", "enabled", true)
		API_PlaySound("explode.wav")
		API_SetTimer("explodeTimer", 0.25, false)
		
	end
	if pulseStates[TP_VLT_CLKENABLE+1] == PULSESTATE_HIGH and POWER==true and ARMED==false then
		ARMED=true
		API_WidgetSet("DiscreteLED1", "Enabled", true)
			--begin countdown
		API_SetTimer('countDown', 1, true)
	end
	if pulseStates[TP_VLT_POWER+1] == PULSESTATE_HIGH or API_WidgetGet("Switch1", "value") then
		POWER = true
	else 
		POWER = false
	end
end

function LEVEL_WidgetEvent(widgetName, eventName)
	if eventName == "pressed" then
		buttonValue = string.sub(widgetName,7)
		if (POWER==true and ARMED==false)then
		SendButtonData(buttonValue)
		end
	end
end

function LEVEL_TimerCallback(timerName)
	if timerName == "errorTimer" then
		errorState = false
		RL_LockChip[3].value = "00000000"
		--RL_KeypadChip[1].value = "00000000"
	elseif timerName == "winTimer" then
		API_LevelWin()
	elseif timerName == "countDown" then
		--API_SetTimer('countDown',1,)
		COUNTDOWN = COUNTDOWN - 1
		API_WidgetSet("LEDDisplay1", "value", tostring(COUNTDOWN))
		if COUNTDOWN==0 then 
			API_WidgetSet("ExternalImage1", "enabled", true)
			API_PlaySound("explode.wav")
			API_SetTimer("explodeTimer", 0.25, false)
			
			--API_LevelLose()
			
		end
	elseif timerName == "explodeTimer" then 
		API_LevelLose()
	
	end
end

-- This function is called both by LEVEL_WidgetEvent when pushing a button and LEVEL_WriteSerial when
-- the player sends a serial character to TP_SER_KEYPAD. buttonvalue is a single character string.
function SendButtonData(buttonValue)
	RL_LockChip[2].value = "0" .. buttonValue .. string.sub(RL_LockChip[2].value,1,6)
	if string.sub(RL_LockChip[2].value,8) ~= "F" then
		if RL_LockChip[1].value == RL_LockChip[2].value then
			-- The code matches, so we win!
			--API_PlaySound("unlock.wav")
			--API_SetTimer("winTimer", 1, false)
			API_WidgetSet("DiscreteLED1", "Enabled", true)
			--begin countdown
			API_SetTimer('countDown', 1, true)
			ARMED = true
		else
			-- The code doesn't match, so set the error flags.
			API_PlaySound("_error")
			API_SetTimer("errorTimer", 0.25, false)
			errorState = true
			RL_LockChip[3].value = "00000001"
			RL_KeypadChip[1].value = "00000001"
		end
		-- Regardless, reset the swap space.
		RL_LockChip[2].value = "0F0F0F0F"
	end
end

function SendSerialData(serialData)
	RL_KeypadChip[2].value = "0" .. serialData .. string.sub(RL_KeypadChip[2].value,1,6)
	if string.sub(RL_KeypadChip[2].value,8) ~= "F" then
		if RL_KeypadChip[1].value == RL_KeypadChip[2].value then
			--API_LevelWin()
			API_SetTimer("winTimer", .5, false)
			API_PlaySound("win.wav")
		end
	end
end
