script.on_init(
  function()
    storage.dynamicTrainStopSettings = {}
  end
)

script.on_event(defines.events.on_player_mined_entity,
  function(event)
	storage.dynamicTrainStopSettings[event.entity.unit_number] = nil
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_robot_mined_entity,
  function(event)
	storage.dynamicTrainStopSettings[event.entity.unit_number] = nil
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_entity_renamed,
  function(event)
	if event.by_script or event.entity.type ~= 'train-stop' then
		return
	end
	if not storage.dynamicTrainStopSettings[event.entity.unit_number] then 
		initDynamicTrainStopSettings(event.entity.unit_number, event.entity.backer_name)
	else 
		storage.dynamicTrainStopSettings[event.entity.unit_number].name = event.entity.backer_name
	end
  end
)

script.on_event(defines.events.on_tick,
  function(event)  
    for trainStopUn, trainStopSetting in pairs(storage.dynamicTrainStopSettings) do
	  local train_stop = game.get_entity_by_unit_number(trainStopUn)
	  if train_stop then
		  if trainStopSetting.useGreen then 
			local network = train_stop.get_circuit_network(defines.wire_connector_id.circuit_green)
			if network then
				updateTrainStopSettingName(trainStopSetting, network, train_stop, true)
			end
		  end
		  if trainStopSetting.useRed then 
			local network = train_stop.get_circuit_network(defines.wire_connector_id.circuit_red)
			if network then
				updateTrainStopSettingName(trainStopSetting, network, train_stop, false)
			end
		  end
		  updateName(trainStopSetting, train_stop)
	  end
	end
  end
)


function updateTrainStopSettingName(trainStopSetting, network, train_stop, green)
	local signals = network.signals
	signals = remove_expected_control_signals(train_stop, signals)
	local signalName = ""
	if signals then
		for _, signal in ipairs(signals) do
		  local signal = signal.signal
		  local pre_fix = nil
		  if signal.name == "solar-system-edge" then
			pre_fix = "space-location"
		  elseif signal.type == "virtual" then
			pre_fix = "virtual-signal"
		  elseif signal.type == "space-location" then
			pre_fix = "planet"
		  elseif signal.type == nil then
			pre_fix = "item"
		  else
			pre_fix = signal.type
		  end
		  
		  if not pre_fix then
			signalName = signalName .. signal.name
		  else
			signalName = signalName .. "[" .. pre_fix .. "=" .. signal.name .. "]"
		  end
	    end
    end
	if green then		
		if trainStopSetting.greenName ~= signalName then
			trainStopSetting.greenName = signalName
		end
	else 
		if trainStopSetting.redName ~= signalName then
			trainStopSetting.redName = signalName
		end
	end
end

function updateName(trainStopSetting, train_stop) 
	local newName = trainStopSetting.redName..trainStopSetting.greenName..trainStopSetting.name
	if  newName ~= train_stop.backer_name then
		train_stop.backer_name = newName
	end
end

function remove_signal(signals, signal)
  for i, v in ipairs(signals) do
    if v.signal.name == signal.name then
      table.remove(signals, i)
      break
    end
  end
end


function remove_expected_control_signals(train_stop, signals)

  -- Remove signal from list, used for train stop enable/disable
  local control_behavior = train_stop.get_control_behavior()
  if (control_behavior.circuit_enable_disable) then
	local condition = control_behavior.circuit_condition
    if (condition.first_signal) then
      remove_signal(signals, condition.first_signal)
      if (condition.second_signal) then
        remove_signal(signals, condition.second_signal)
      end
    end
  end

  -- Remove signal from list, used for priority control
  if (control_behavior.set_priority) then
    remove_signal(signals, control_behavior.priority_signal)
  end

  -- Remove signal from list, used for indicating train count
  if (control_behavior.read_trains_count) then
    remove_signal(signals, control_behavior.trains_count_signal)
  end

  -- Remove signal from list, used for indicating train id
  if (control_behavior.read_stopped_train) then
    remove_signal(signals, control_behavior.stopped_train_signal)
  end

  -- Remove signal from list, used for train limit control
  if (control_behavior.set_trains_limit) then
    remove_signal(signals, control_behavior.trains_limit_signal)
  end

  return signals
end

function initDynamicTrainStopSettings(unit_number, name) 
	--game.players[1].print("init: "..unit_number.." "..name)
	storage.dynamicTrainStopSettings[unit_number] = {
		useRed = false,
		useGreen = false,
		redName = "",
		greenName = "",
		name = name
	}
end

script.on_event(defines.events.on_gui_checked_state_changed, 
  function(event)
	local player = game.players[event.player_index]
	local opened = player.opened
	local checkbox = event.element
    if checkbox.name == "dynamicTrainStopRed" then 
	  if not storage.dynamicTrainStopSettings[player.opened.unit_number] then
		initDynamicTrainStopSettings(player.opened.unit_number, "")
	  end
	  storage.dynamicTrainStopSettings[player.opened.unit_number].useRed = checkbox.state
	  if not checkbox.state then
		storage.dynamicTrainStopSettings[player.opened.unit_number].redName = ""
	  end
    end
	if checkbox.name == "dynamicTrainStopGreen" then 
	  if not storage.dynamicTrainStopSettings[player.opened.unit_number] then
		initDynamicTrainStopSettings(player.opened.unit_number, "")
	  end
	  storage.dynamicTrainStopSettings[player.opened.unit_number].useGreen = checkbox.state
	  if not checkbox.state then
		storage.dynamicTrainStopSettings[player.opened.unit_number].greenName = ""
	  end
    end
  end
)

script.on_event(
  defines.events.on_gui_opened,
  function(event)
    if event.entity == nil then
      return
    end
	
    if event.entity.type == 'train-stop' then
	  local player = game.players[event.player_index]
	  if not storage.dynamicTrainStopSettings[player.opened.unit_number] then
		initDynamicTrainStopSettings(player.opened.unit_number, player.opened.backer_name) 
	  end
	  local trainStopSetting = storage.dynamicTrainStopSettings[player.opened.unit_number]
	  -- DEBUG
	  --player.print(tostring(trainStopSetting.useRed).." : "
	  --		..tostring(trainStopSetting.useGreen).."   "
	  --		..tostring(trainStopSetting.redName).." - "
	  --		..tostring(trainStopSetting.greenName).." - "
	  --		..tostring(trainStopSetting.name).." : "
	  --)
	  
	  local anchor = {
		gui = defines.relative_gui_type.train_stop_gui, 
		position = defines.relative_gui_position.right
	  }
      local gui = player.gui.relative
	  
      if gui.train_stop then
		gui.train_stop.controls_flow_v.controls_flow_red.dynamicTrainStopRed.state = trainStopSetting.useRed;
		gui.train_stop.controls_flow_v.controls_flow_green.dynamicTrainStopGreen.state = trainStopSetting.useGreen;
        return
      end
	 
      local frame = gui.add({
        type = "frame",
        name = "train_stop",
        direction = "vertical",
		caption="Dynamic Naming",
		anchor = anchor
      })
	  local controls_flow_v = frame.add {
		type="flow", 
		name="controls_flow_v", 
		direction="vertical"
	  }
	  
	  local controls_flow_red = controls_flow_v.add {
		type="flow", 
		name="controls_flow_red", 
		direction="horizontal"	  
	  }
	  controls_flow_red.add({
        type = "checkbox",
		name = "dynamicTrainStopRed",
        state = trainStopSetting.useRed
      })
      controls_flow_red.add({
        type = "label",
        name = "redLabel",
		caption = "Use Red Circuit",
        tooltip = "Puts all signals from the red circuit into at the beginning of the name of the train stop."
      })

	  local controls_flow_green = controls_flow_v.add {
		type="flow", 
		name="controls_flow_green", 
		direction="horizontal"	  
	  }
	  controls_flow_green.add({
        type = "checkbox",
		name = "dynamicTrainStopGreen",
        state = trainStopSetting.useGreen
      })
      controls_flow_green.add({
        type = "label",
		name = "greenLabel",
        caption = "Use Green Circuit",
        tooltip = "Puts all signals from the green circuit into at the beginning of the name of the train stop."
      })
    end
  end
)

script.on_event(
  defines.events.on_gui_closed,
  function(event)
    if event.entity == nil then
      return
    end
    if event.entity.type == 'train-stop' then
      local player = game.players[event.player_index]
      if player == nil then
        return
      end
	  local gui = player.gui.center
	  if not gui.train_stop then
        return  
	  end
	  gui.train_stop.destroy()
    end
  end
)

