-- only called once the first time the mod loads on a given save
script.on_init(
  function()
    storage.dynamic_train_stop_settings = {}
    storage.blueprint_mappings = {}
  end
)

-- called when any mod version or game version changed
script.on_configuration_changed(
  function()
    -- create the storage variable for save games with old versions of this mod
    if not storage.dynamic_train_stop_settings then
      storage.dynamic_train_stop_settings = {}
    end
    if not storage.blueprint_mappings then
      storage.blueprint_mappings = {}
    end
  end
)

-- remove settings for no longer existing train stops.
script.on_event(defines.events.on_player_mined_entity,
  function(event)
    storage.dynamic_train_stop_settings[event.entity.unit_number] = nil
  end,
  { { filter = "name", name = "train-stop" } }
)

-- remove settings for no longer existing train stops.
script.on_event(defines.events.on_robot_mined_entity,
  function(event)
    storage.dynamic_train_stop_settings[event.entity.unit_number] = nil
  end,
  { { filter = "name", name = "train-stop" } }
)

-- copy settings when cloning train stop (shift click)
script.on_event(defines.events.on_entity_settings_pasted,
  function(event)
    if event.source.type ~= 'train-stop' or event.destination.type ~= 'train-stop' then
      return
    end
    --game.players[1].print("on_entity_settings_pasted: "..event.source.unit_number)
    local source_settings = storage.dynamic_train_stop_settings[event.source.unit_number]
    local destination_settings = init_dynamic_train_stop_settings(event.destination.unit_number, source_settings.name)
    destination_settings.use_red = source_settings.use_red
    destination_settings.use_green = source_settings.use_green
  end
)

-- saving to copy-paste tool & cut-paste tool
script.on_event(defines.events.on_player_setup_blueprint,
  function(event)
    local player = game.players[event.player_index]

    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read and cursor.type == 'blueprint' then
      save_blueprint_data(cursor, event.mapping.get())
    else
      storage.blueprint_mappings[player.index] = event.mapping.get()
    end
  end
)

-- saving to regular blueprint
script.on_event(defines.events.on_player_configured_blueprint,
  function(event)
    local player = game.players[event.player_index]
    local mapping = storage.blueprint_mappings[player.index]
    local cursor = player.cursor_stack

    if cursor and cursor.valid_for_read and cursor.type == 'blueprint' and mapping and #mapping == cursor.get_blueprint_entity_count() then
      save_blueprint_data(cursor, mapping)
    end
    storage.blueprint_mappings[player.index] = nil
  end
)

-- called when player builds something.
script.on_event(defines.events.on_built_entity,
  function(event)
    on_train_stop_built(event.entity, event.tags)
  end,
  { { filter = "name", name = "train-stop" } }
)

-- called when a construction robot builds an entity.
script.on_event(defines.events.on_robot_built_entity,
  function(event)
    on_train_stop_built(event.entity, event.tags)
  end,
  { { filter = "name", name = "train-stop" } }
)

function save_blueprint_data(blueprint, mapping)
  for i, entity in pairs(mapping) do
    if entity.valid and entity.type == 'train-stop' then
      if storage.dynamic_train_stop_settings[entity.unit_number] then
        local train_stop_setting = storage.dynamic_train_stop_settings[entity.unit_number]
        blueprint.set_blueprint_entity_tag(i, 'train_stop_setting', train_stop_setting)
      end
    end
  end
end

function on_train_stop_built(entity, tags)
  if tags and tags.train_stop_setting then
    local train_stop_setting = init_dynamic_train_stop_settings(entity.unit_number, tags.train_stop_setting.name)
    train_stop_setting.use_red = tags.train_stop_setting.use_red
    train_stop_setting.use_green = tags.train_stop_setting.use_green
  end
end

-- update the postfix name on manual name edit
script.on_event(defines.events.on_entity_renamed,
  function(event)
    --game.players[1].print("on_entity_renamed: "..tostring(event.by_script))
    if event.by_script or event.entity.type ~= 'train-stop' then
      return
    end
    if storage.dynamic_train_stop_settings[event.entity.unit_number] then
      storage.dynamic_train_stop_settings[event.entity.unit_number].name = event.entity.backer_name
    end
  end
)

script.on_event(defines.events.on_tick,
  function(event)
    for train_stop_un, train_stop_setting in pairs(storage.dynamic_train_stop_settings) do
      local train_stop = game.get_entity_by_unit_number(train_stop_un)
      if train_stop then
        if train_stop_setting.use_green then
          local network = train_stop.get_circuit_network(defines.wire_connector_id.circuit_green)
          if network then
            update_train_stop_setting_from_signals(train_stop_setting, network, train_stop, true)
          end
        end
        if train_stop_setting.use_red then
          local network = train_stop.get_circuit_network(defines.wire_connector_id.circuit_red)
          if network then
            update_train_stop_setting_from_signals(train_stop_setting, network, train_stop, false)
          end
        end
        update_train_stop_name_from_settings(train_stop_setting, train_stop)
      end
    end
  end
)

function update_train_stop_setting_from_signals(train_stop_setting, network, train_stop, green)
  local signals = network.signals
  signals = remove_expected_control_signals(train_stop, signals)
  local signal_name = ""
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
        signal_name = signal_name .. signal.name
      else
        signal_name = signal_name .. "[" .. pre_fix .. "=" .. signal.name .. "]"
      end
    end
  end
  if green then
    if train_stop_setting.green_name ~= signal_name then
      train_stop_setting.green_name = signal_name
    end
  else
    if train_stop_setting.red_name ~= signal_name then
      train_stop_setting.red_name = signal_name
    end
  end
end

function update_train_stop_name_from_settings(train_stop_setting, train_stop)
  local new_name = train_stop_setting.red_name .. train_stop_setting.green_name .. train_stop_setting.name
  if new_name ~= train_stop.backer_name then
    train_stop.backer_name = new_name
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

function init_dynamic_train_stop_settings(unit_number, name)
  -- data structure for the mod settings
  storage.dynamic_train_stop_settings[unit_number] = {
    use_red = false,
    use_green = false,
    red_name = "",
    green_name = "",
    name = name
  }
  return storage.dynamic_train_stop_settings[unit_number]
end

-- checkbox clicked events
script.on_event(defines.events.on_gui_checked_state_changed,
  function(event)
    local player = game.players[event.player_index]
    local train_stop = player.opened
    local checkbox = event.element
    if checkbox.name == "dynamic_train_stop_red" then
      -- update mod settings for this train stop
      storage.dynamic_train_stop_settings[train_stop.unit_number].use_red = checkbox.state
      if not checkbox.state then
        storage.dynamic_train_stop_settings[train_stop.unit_number].red_name = ""
      end
    end
    if checkbox.name == "dynamic_train_stop_green" then
      -- update mod settings for this train stop
      storage.dynamic_train_stop_settings[train_stop.unit_number].use_green = checkbox.state
      if not checkbox.state then
        storage.dynamic_train_stop_settings[train_stop.unit_number].green_name = ""
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

    -- train stop opened
    if event.entity.type == 'train-stop' then
      local player = game.players[event.player_index]
      -- init/load mod settings for this train stop
      if not storage.dynamic_train_stop_settings[player.opened.unit_number] then
        init_dynamic_train_stop_settings(player.opened.unit_number, player.opened.backer_name)
      end
      local train_stop_setting = storage.dynamic_train_stop_settings[player.opened.unit_number]
      -- DEBUG
      --player.print(tostring(train_stop_setting.use_red).." : "
      --		..tostring(train_stop_setting.use_green).."   "
      --		..tostring(train_stop_setting.red_name).." - "
      --		..tostring(train_stop_setting.green_name).." - "
      --		..tostring(train_stop_setting.name).." : "
      --)

      local gui = player.gui.relative

      -- check if the ui was created with an old mod version and destroy it to rebuild the new one
      if gui.train_stop and not gui.train_stop.controls_flow_v.controls_flow_red.dynamic_train_stop_red then
        gui.train_stop.destroy()
      end

      if gui.train_stop then
        -- if gui was already created, only update button state
        gui.train_stop.controls_flow_v.controls_flow_red.dynamic_train_stop_red.state = train_stop_setting.use_red;
        gui.train_stop.controls_flow_v.controls_flow_green.dynamic_train_stop_green.state = train_stop_setting.use_green;
        return
      end

      -- create gui
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
        "train_stop",
        gui
      )
      local controls_flow_v = add_or_load_ui_element(
        {
          type = "flow",
          name = "controls_flow_v",
          direction = "vertical"
        },
        "controls_flow_v",
        frame
      )
      local controls_flow_red = add_or_load_ui_element(
        {
          type = "flow",
          name = "controls_flow_red",
          direction = "horizontal"
        },
        "controls_flow_red",
        controls_flow_v
      )
      add_or_load_ui_element(
        {
          type = "checkbox",
          name = "dynamic_train_stop_red",
          state = train_stop_setting.use_red
        },
        "dynamic_train_stop_red",
        controls_flow_red
      )
      add_or_load_ui_element(
        {
          type = "label",
          name = "red_label",
          caption = "Use Red Circuit",
          tooltip = "Puts all signals from the red circuit into at the beginning of the name of the train stop."
        },
        "red_label",
        controls_flow_red
      )
      local controls_flow_green = add_or_load_ui_element(
        {
          type = "flow",
          name = "controls_flow_green",
          direction = "horizontal"
        },
        "controls_flow_green",
        controls_flow_v
      )
      add_or_load_ui_element(
        {
          type = "checkbox",
          name = "dynamic_train_stop_green",
          state = train_stop_setting.use_green
        },
        "dynamic_train_stop_green",
        controls_flow_green
      )
      add_or_load_ui_element(
        {
          type = "label",
          name = "green_label",
          caption = "Use Green Circuit",
          tooltip = "Puts all signals from the green circuit into at the beginning of the name of the train stop."
        },
        "green_label",
        controls_flow_green
      )
    end
  end
)

function add_or_load_ui_element(new_element, new_element_name, parent)
  local result
  if parent[new_element_name] then
    result = parent[new_element_name]
  else
    result = parent.add(new_element)
  end
  return result
end

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
