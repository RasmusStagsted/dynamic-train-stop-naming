script.on_init(
  function()
    if not storage.train_stop_table then
      storage.train_stop_table = {}
    end
    generate_train_stop_table()
  end
)

script.on_configuration_changed(
  function()
    -- Initialize the train stop table if not initialized when mod version is changed
    if not storage.train_stop_table then
      storage.train_stop_table = {}
    end
    generate_train_stop_table()
  end
)

script.on_event(defines.events.on_tick,
  function(event)
    if not storage.train_stop_table then
      storage.train_stop_table = {}
    end
end)

script.on_event(defines.events.on_built_entity,
  function(event)
    entity_id = event.entity.unit_number
    storage.train_stop_table[entity_id] = event.entity
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_robot_built_entity,
  function(event)
    entity_id = event.entity.unit_number
    storage.train_stop_table[entity_id] = event.entity
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_player_mined_entity,
  function(event)
    entity_id = event.entity.unit_number
    if storage.train_stop_table[entity_id] then
      storage.train_stop_table[entity_id] = nil
    end
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_robot_mined_entity,
  function(event)
    entity_id = event.entity.unit_number
    if storage.train_stop_table[entity_id] then
      storage.train_stop_table[entity_id] = nil
    end
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_tick,
  function(event)
    storage.train_stop_table = storage.train_stop_table or {}
    for i, train_stop in pairs(storage.train_stop_table) do
      local network = train_stop.get_circuit_network(defines.wire_connector_id.circuit_red)
      if network then
        local signals = network.signals
        signals = remove_expected_control_signals(train_stop, signals)
        set_train_stop_name(train_stop, signals)

      end
    end
  end
)

function generate_train_stop_table()
  storage.train_stop_table = storage.train_stop_table or {}
  for _, surface in pairs(game.surfaces) do
    local train_stops = surface.find_entities_filtered({type = "train-stop"})
    for _, stop in pairs(train_stops) do
      entity_id = stop.unit_number
      storage.train_stop_table[entity_id] = stop
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
    local condition = control_behavior.circuit_condition.condition
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