gui = require("gui")
utils = require("utils")

script.on_event(defines.events.on_gui_opened, gui.on_gui_opened)
script.on_event(defines.events.on_gui_closed, gui.on_gui_closed)
script.on_event(defines.events.on_gui_checked_state_changed, gui.on_gui_checked_state_changed)
script.on_event(defines.events.on_gui_switch_state_changed, gui.on_gui_switch_state_changed)

script.on_init(generate_train_stop_table)
script.on_configuration_changed(generate_train_stop_table)

script.on_event(defines.events.on_entity_settings_pasted,
  function(event)
    if event.source.type == 'train-stop' and event.destination.type == 'train-stop' then
      local source = storage.train_stop_table[event.source.unit_number].settings
      local dest = storage.train_stop_table[event.destination.unit_number].settings
      dest.enable_red_network = source.enable_red_network
      dest.enable_green_network = source.enable_green_network
      dest.red_name = source.red_name
      dest.green_name = source.green_name
      dest.network_order = source.network_order
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
    storage.train_stop_table[entity_id] = utils.create_train_stop_object(event.entity)
  end,
  {{filter = "name", name = "train-stop"}}
)

script.on_event(defines.events.on_robot_built_entity,
  function(event)
    local entity_id = event.entity.unit_number
    storage.train_stop_table[entity_id] = utils.create_train_stop_object(event.entity)
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
          local control_behavior = train_stop.entity.get_control_behavior()
          red_signals = utils.remove_expected_control_signals(control_behavior, signals)
        end
      end
      if train_stop.settings.enable_green_network then
        local network = train_stop.entity.get_circuit_network(defines.wire_connector_id.circuit_green)
        if network then
          local signals = network.signals or {}
          local control_behavior = train_stop.entity.get_control_behavior()
          green_signals = utils.remove_expected_control_signals(control_behavior, signals)
        end
      end
      
      local new_name = ""
      if train_stop.settings.network_order == "none" then
        local signals = {table.unpack(red_signals), table.unpack(green_signals)}
        new_name = utils.get_text_string_from_signal(signals) .. train_stop.settings.name_post_fix
      else
        local red_name = utils.get_text_string_from_signal(red_signals)
        local green_name = utils.get_text_string_from_signal(green_signals)
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

function generate_train_stop_table()
  storage.train_stop_table = storage.train_stop_table or {}
  for _, surface in pairs(game.surfaces) do
    local train_stops = surface.find_entities_filtered({type = "train-stop"})
    for _, train_stop in pairs(train_stops) do
      local entity_id = train_stop.unit_number
      storage.train_stop_table[entity_id] = utils.create_train_stop_object(train_stop)
    end
  end
end