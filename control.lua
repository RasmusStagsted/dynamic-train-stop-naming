script.on_init(
  function()
    log("On init")
    if not storage.train_stop_list then
      log("Initializing train_stop_list")
      storage.train_stop_list = {}
    end
    log("Train stop count: " .. #storage.train_stop_list)
  end
)

script.on_event(defines.events.on_tick,
  function(event)
    if not storage.train_stop_list then
      storage.train_stop_list = {}
    end
    if event.tick % 60 == 0 then
        log("Persisted train stop count: " .. #storage.train_stop_list)
    end
end)

script.on_event(defines.events.on_built_entity,
  function(event)
    log("Train stop added.")
    table.insert(storage.train_stop_list, event.entity)
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_robot_built_entity,
  function(event)
    log("Train stop added.")
    table.insert(storage.train_stop_list, event.entity)
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_player_mined_entity,
  function(event)
    log("Train stop removed.")
    remove_entity_from_list(event.entity, storage.train_stop_list)
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_robot_mined_entity,
  function(event)
    log("Train stop removed.")
    remove_entity_from_list(event.entity, storage.train_stop_list)
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_tick,
  function(event)
    storage.train_stop_list = storage.train_stop_list or {}
    for i, train_stop in ipairs(storage.train_stop_list) do
      local network = train_stop.get_circuit_network(defines.wire_connector_id.circuit_red)
      if network then
        local signals = network.signals
        signals = remove_expected_control_signals(train_stop, signals)
        set_train_stop_name(train_stop, signals)

      end
    end
  end
)

function generate_train_stop_list()
  storage.train_stop_list = storage.train_stop_list or {}
  for _, surface in pairs(game.surfaces) do
    local train_stops = surface.find_entities_filtered({type = "train-stop"})
    for _, stop in pairs(train_stops) do
      table.insert(storage.train_stop_list, stop)
    end
  end
end

function set_train_stop_name(train_stop, signals)
  if signals then
    local new_name = ""
    for index, signal in ipairs(signals) do
      signal = signal.signal
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
          new_name = new_name .. signal.name
      else
        new_name = new_name .. "[" .. pre_fix .. "=" .. signal.name .. "]"
      end
    end
    if not (train_stop.backer_name == new_name) then
      train_stop.backer_name = new_name
    end
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
    if (control_behavior.circuit_condition.condition) then -- This will never become true! Why?
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

function remove_entity_from_list(entity, list)
  for i, val in ipairs(list) do
    if val == entity then
      table.remove(list, i)
      break
    end
  end
end


--[[
script.on_load(
  function()
    generate_train_stop_list()
  end
)

script.on_init(
  function()
    generate_train_stop_list()
  end
)
]]--


--[[
script.on_event(
  defines.events.on_gui_opened,
  function(event)
    if event.entity == nil then
      return
    end
    if event.entity.type == 'train-stop' then
      local player = game.players[event.player_index]
      gui = player.gui.children.center
      if gui.turret_wrap then
        return
      end
      gui.add({
        type = "frame",
        name = "turret_wrap",
        direction = "horizontal",
        style = "trainstopgui"
      })

      gui.turret_wrap.add({
        type = "frame",
        name = "button_f",
        direction = "vertical"
      })
		  
      gui.turret_wrap.add({
        type = "flow",
        name = "textFlow",
        direction = "vertical",
        style = "textlabel_flow"
      })

      gui.turret_wrap.button_f.add({
        type = "radiobutton",
        state = true
      })

      gui.turret_wrap.textFlow.add({
        type = "label",
        name = "test",
        caption = "test2"
      })

      --gui.add(type = "radiobutton", name = "enable-dynamic-name-control", caption = "Enable dynamic name control", state = true)
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
		  if not gui.turret_wrap then
        return  
		  end
		
		  gui.turret_wrap.destroy()
    end
  end
)
]]--