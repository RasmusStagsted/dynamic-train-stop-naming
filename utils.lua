local utils = {}

function remove_signal(signals, signal)
  for i, v in pairs(signals) do
    if v.signal.name == signal.name then
      table.remove(signals, i)
      break
    end
  end
end

function utils.get_text_string_from_signal(signals)
  local text_string = ""
  if signals then
    for index, signal in pairs(signals) do
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
        text_string = text_string .. signal.name
      else
        text_string = text_string .. "[" .. pre_fix .. "=" .. signal.name .. "]"
      end
    end
  end
  return text_string
end

function utils.remove_expected_control_signals(control_behavior, signals)

  -- Remove signal from list, used for train stop enable/disable
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

function utils.create_train_stop_object(entity)
  return {
    entity = entity,
    settings = {
      enable_red_network = false,
      enable_green_network = false,
      red_name = "",
      green_name = "",
      network_order = None,
      name_post_fix = ""
    }
  }
end

function utils.generate_train_stop_table()
  storage.train_stop_table = storage.train_stop_table or {}
  if not storage.blueprint_mapping then
    storage.blueprint_mapping = {}
  end
  for _, surface in pairs(game.surfaces) do
    local train_stops = surface.find_entities_filtered({type = "train-stop"})
    for _, train_stop in pairs(train_stops) do
      local entity_id = train_stop.unit_number
      storage.train_stop_table[entity_id] = utils.create_train_stop_object(train_stop)
    end
  end
end

return utils