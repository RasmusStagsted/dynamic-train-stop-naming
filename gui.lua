local gui = {}

function gui.on_gui_switch_state_changed(event)
  local entity = game.players[event.player_index].opened
  if entity.type == "train-stop" then
    local switch = event.element
    local train_stop = storage.train_stop_table[entity.unit_number]
    train_stop.settings.network_order = switch.switch_state
  end
end

function gui.on_gui_checked_state_changed(event)
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

function add_or_load_ui_element(new_element, parent)
  local result
  if parent[new_element.name] then
    result = parent[new_element.name]
  else
    result = parent.add(new_element)
  end
  return result
end

function gui.on_gui_closed(event)
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

function gui.on_gui_opened(event)
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

return gui