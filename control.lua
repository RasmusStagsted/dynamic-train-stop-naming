gui = require("gui")
utils = require("utils")

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

script.on_event(defines.events.on_player_setup_blueprint,
  function(event)
    local player = game.players[event.player_index]
    local blueprint = player.cursor_stack
    local blueprint_mapping = event.mapping.get()
    if (
      blueprint and
      blueprint.type == 'blueprint' and
      blueprint.valid_for_read
    ) then
      for i, entity in pairs(blueprint_mapping) do
        if (
          entity.valid and entity.type == 'train-stop' and
          storage.train_stop_table[entity.unit_number]
        ) then
          local settings = storage.train_stop_table[entity.unit_number].settings
          log(settings.enable_red_network)
          blueprint.set_blueprint_entity_tag(i, 'train_stop_settings', settings)
        end
      end
    else
      storage.blueprint_mapping[player.index] = blueprint_mapping
    end
  end
)

script.on_event(defines.events.on_player_configured_blueprint,
  function(event)
    local player_index = event.player_index
    local blueprint_mapping = storage.blueprint_mappings[player_index]
    local blueprint = player.cursor_stack

    log(blueprint == nil)
    log(blueprint.type)
    log(blueprint.valid_for_read)
    log(blueprint_mapping)
    log(blueprint.get_blueprint_entity_count())
    log(#blueprint_mapping)

    if (
      blueprint and
      blueprint.type == 'blueprint' and
      blueprint.valid_for_read and
      blueprint_mapping and
      #blueprint_mapping == blueprint.get_blueprint_entity_count()
    ) then
      save_blueprint_data(blueprint, blueprint_mapping)
    end
    storage.blueprint_mappings[player_index] = nil
  end
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
    if not storage.train_stop_table then
      storage.train_stop_table = {}
    end
    for entity_id, train_stop in pairs(storage.train_stop_table) do
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
      if train_stop.entity.valid and not (new_name == train_stop.entity.backer_name) then
        train_stop.entity.backer_name = new_name
      end
    end
  end
)

function on_entity_build(event)
  local entity_id = event.entity.unit_number
  local train_stop = utils.create_train_stop_object(event.entity)
  local tags = event.tags
  storage.train_stop_table[entity_id] = train_stop
  if tags and tags.train_stop_settings then
    local setting = train_stop.settings
    setting.use_red = tags.train_stop_settings.use_red
    setting.use_green = tags.train_stop_settings.use_green
    for key, value in pairs(tags.train_stop_settings) do
      setting[key] = value
    end
  end
end

function on_entity_mined(event)
  local entity_id = event.entity.unit_number
  if storage.train_stop_table[entity_id] then
    storage.train_stop_table[entity_id] = nil
  end
end

train_stop_filter = {{filter = "name", name = "train-stop"}}

-- Initialization callbacks
script.on_init(utils.generate_train_stop_table)
script.on_configuration_changed(utils.generate_train_stop_table)

-- GUI callbacks
script.on_event(defines.events.on_gui_opened, gui.on_gui_opened)
script.on_event(defines.events.on_gui_closed, gui.on_gui_closed)
script.on_event(defines.events.on_gui_checked_state_changed, gui.on_gui_checked_state_changed)
script.on_event(defines.events.on_gui_switch_state_changed, gui.on_gui_switch_state_changed)

-- entity built/removed callbacks
script.on_event(defines.events.on_built_entity, on_entity_build, train_stop_filter)
script.on_event(defines.events.on_robot_built_entity, on_entity_build, train_stop_filter)
script.on_event(defines.events.on_player_mined_entity, on_entity_removed, train_stop_filter)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed, train_stop_filter)