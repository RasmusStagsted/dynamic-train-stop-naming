script.on_init(
  function()
    generate_train_stop_table()
  end
)

script.on_configuration_changed(
  function()
    generate_train_stop_table()
  end
)

script.on_event(defines.events.on_entity_settings_pasted,
  function(event)
    if event.source.type == 'train-stop' and event.destination.type == 'train-stop' then
      local source = storage.train_stop_table[event.source.unit_number].settings
      local dest = storage.train_stop_table[event.destination.unit_number].settings
      dest.name_post_fix = source.name_post_fix
    end
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
    local entity_id = event.entity.unit_number
    storage.train_stop_table[entity_id] = create_train_stop_object(event.entity)
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_robot_built_entity,
  function(event)
    local entity_id = event.entity.unit_number
    storage.train_stop_table[entity_id] = create_train_stop_object(event.entity)
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_player_mined_entity,
  function(event)
    local entity_id = event.entity.unit_number
    if storage.train_stop_table[entity_id] then
      storage.train_stop_table[entity_id] = nil
    end
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_robot_mined_entity,
  function(event)
    local entity_id = event.entity.unit_number
    if storage.train_stop_table[entity_id] then
      storage.train_stop_table[entity_id] = nil
    end
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_entity_renamed,
  function(event)
	  if event.entity.type == 'train-stop' and not event.by_script then
      local entity_id = event.entity.unit_number
    	if storage.train_stop_table[entity_id] then
		    storage.train_stop_table[entity_id].settings.name_post_fix = event.entity.backer_name
      else
        log("Unrecognized train stop: (id: " .. entity_id .. ")")
      end
    end
  end
)

script.on_event(defines.events.on_tick,
  function(event)
    storage.train_stop_table = storage.train_stop_table or {}
    for i, train_stop in pairs(storage.train_stop_table) do
      local red_signals = {}
      local green_signals = {}
      if train_stop.settings.enable_red_network then
        local network = train_stop.entity.get_circuit_network(defines.wire_connector_id.circuit_red)
        if network then
          local signals = network.signals or {}
          red_signals = remove_expected_control_signals(train_stop, signals)
        end
      end
      if train_stop.settings.enable_green_network then
        local network = train_stop.entity.get_circuit_network(defines.wire_connector_id.circuit_green)
        if network then
          local signals = network.signals or {}
          green_signals = remove_expected_control_signals(train_stop, signals)
        end
      end
      
      local new_name = ""
      if train_stop.settings.network_order == "none" then
        local signals = {table.unpack(red_signals), table.unpack(green_signals)}
        new_name = get_text_string_from_signal(signals)
      else
        local red_name = get_text_string_from_signal(red_signals)
        local green_name = get_text_string_from_signal(green_signals)
        if train_stop.settings.network_order == "left" then
          new_name = red_name .. green_name .. train_stop.settings.name_post_fix
        else
          new_name = green_name .. red_name .. train_stop.settings.name_post_fix
        end
      end
      if not (new_name == train_stop.entity.backer_name) then
        train_stop.entity.backer_name = new_name
      end
    end
  end
)

function create_train_stop_object(entity)
  return {
    entity = entity,
    settings = create_settings()
  }
end

function create_settings()
  return {
    enable_red_network = false,
    enable_green_network = false,
    red_name = "",
    green_name = "",
    network_order = None,
    name_post_fix = ""
  }
end

function generate_train_stop_table()
  storage.train_stop_table = storage.train_stop_table or {}
  for _, surface in pairs(game.surfaces) do
    local train_stops = surface.find_entities_filtered({type = "train-stop"})
    for _, train_stop in pairs(train_stops) do
      local entity_id = train_stop.unit_number
      storage.train_stop_table[entity_id] = create_train_stop_object(train_stop)
    end
  end
end

function get_text_string_from_signal(signals)
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

function remove_signal(signals, signal)
  for i, v in pairs(signals) do
    if v.signal.name == signal.name then
      table.remove(signals, i)
      break
    end
  end
end

function remove_expected_control_signals(train_stop, signals)

  -- Remove signal from list, used for train stop enable/disable
  local control_behavior = train_stop.entity.get_control_behavior()
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

script.on_event(defines.events.on_gui_switch_state_changed,
  function(event)
    local entity = game.players[event.player_index].opened
    if entity.type == "train-stop" then
      local switch = event.element
      local train_stop = storage.train_stop_table[entity.unit_number]
      train_stop.settings.network_order = switch.switch_state
    end
  end
)

script.on_event(defines.events.on_gui_checked_state_changed,
  function(event)
    local entity = game.players[event.player_index].opened
    if entity.type == "train-stop" then
      local checkbox = event.element
      local train_stop = storage.train_stop_table[entity.unit_number]
      if checkbox.name == "dtsn_red_network" then
        train_stop.settings.enable_red_network = checkbox.state
        if not checkbox.state then
          train_stop.settings.red_name = ""
        end
      end
      if checkbox.name == "dtsn_green_network" then
        train_stop.settings.enable_green_network = checkbox.state
        if not checkbox.state then
          train_stop.settings.green_name = ""
        end
      end

      local order_switch = event.element.parent.parent.controls_flow_order.order_switch
      local settings = train_stop.settings
      local green_state = settings.enable_green_network
      local red_state = settings.enable_red_network
      if red_state and (not green_state) then
        settings.network_order = "left"
      elseif (not red_state) and green_state then
        settings.network_order = "right"
      elseif (not red_state) and (not green_state) then
        settings.network_order = "none"
      else
        settings.network_order = "none"
      end
      order_switch.switch_state = settings.network_order
    end
  end
)

script.on_event(
  defines.events.on_gui_opened,
  function(event)
    if event.entity and event.entity.type == 'train-stop' then
      local player = game.players[event.player_index]
      local train_stop = storage.train_stop_table[player.opened.unit_number]
      local gui = player.gui.relative
      local anchor = {
        gui = defines.relative_gui_type.train_stop_gui,
        position = defines.relative_gui_position.right
      }
      local frame = add_or_load_ui_element(
        {
          type = "frame",
          name = "train_stop",
          direction = "vertical",
          caption = "Dynamic Naming",
          anchor = anchor
        },
        gui
      )
      local controls_flow_v = add_or_load_ui_element(
        {
          type = "flow",
          name = "controls_flow_v",
          direction = "vertical"
        },
        frame
      )
      local controls_flow_red = add_or_load_ui_element(
        {
          type = "flow",
          name = "controls_flow_red",
          direction = "horizontal"
        },
        controls_flow_v
      )
      add_or_load_ui_element(
        {
          type = "checkbox",
          name = "dtsn_red_network",
          state = train_stop.settings.enable_red_network
        },
        controls_flow_red
      )
      add_or_load_ui_element(
        {
          type = "label",
          name = "red_label",
          caption = "Use Red network.",
          tooltip = "Add all signals from the red network into the name of the train stop."
        },
        controls_flow_red
      )
      local controls_flow_green = add_or_load_ui_element(
        {
          type = "flow",
          name = "controls_flow_green",
          direction = "horizontal"
        },
        controls_flow_v
      )
      add_or_load_ui_element(
        {
          type = "checkbox",
          name = "dtsn_green_network",
          state = train_stop.settings.enable_green_network
        },
        controls_flow_green
      )
      add_or_load_ui_element(
        {
          type = "label",
          name = "green_label",
          caption = "Use Green network.",
          tooltip = "Add all signals from the green network into the name of the train stop."
        },
        controls_flow_green
      )
      local controls_flow_order = add_or_load_ui_element(
        {
          type = "flow",
          name = "controls_flow_order",
          direction = "horizontal",
          tooltip = "Select which signal goes first when naming the train stop."
        },
        controls_flow_v
      )
      add_or_load_ui_element(
        {
          type = "label",
          name = "order_label",
          caption = "First signal:",
        },
        controls_flow_order
      )
      add_or_load_ui_element(
        {
          type = "label",
          name = "order_left_label",
          caption = "Red",
          tooltip = "Use the red network first when generating the train stop name."
        },
        controls_flow_order
      )
      add_or_load_ui_element(
        {
          type = "switch",
          name = "order_switch",
          allow_none_state = true,
          switch_state = train_stop.settings.network_order
        },
        controls_flow_order
      )
      add_or_load_ui_element(
        {
          type = "label",
          name = "order_right_label",
          caption = "Green",
          tooltip = "Use the green network first when generating the train stop name."
        },
        controls_flow_order
      )
    end
  end
)

function add_or_load_ui_element(new_element, parent)
  local result
  if parent[new_element.name] then
    result = parent[new_element.name]
  else
    result = parent.add(new_element)
  end
  return result
end

script.on_event(
  defines.events.on_gui_closed,
  function(event)
    if event.entity and (event.entity.type == 'train-stop') then
      local player = game.players[event.player_index]
      if player then
        local gui = player.gui.relative
        if gui.train_stop then
          gui.train_stop.destroy()
        end
      end
    end
  end
)