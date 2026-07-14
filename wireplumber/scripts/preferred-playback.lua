local log = Log.open_topic("preferred-playback")

-- Both EQ sinks always exist, even while the Bluetooth headphones are absent.
-- WirePlumber periodically asks its hooks to choose a default from candidate
-- nodes; the real Bluetooth node appears only while connected. This hook says:
--   real AirPods output + AirPods EQ -> AirPods EQ; otherwise -> LCD-X EQ.
local AIRPODS_OUTPUT = "bluez_output.90_9C_4A_EE_D6_44.1"
local AIRPODS_EQ = "effect_input.eq_airpods_max"
local LCD_X_EQ = "effect_input.eq_lcd_x"

SimpleEventHook {
    name = "default-nodes/prefer-airpods-max",
    -- Override the standard choice, then let WirePlumber publish our choice.
    after = {
        "default-nodes/find-best-default-node",
        "default-nodes/find-selected-default-node",
        "default-nodes/find-stored-default-node",
    },
    before = "default-nodes/apply-default-node",
    interests = {
        EventInterest {
            Constraint { "event.type", "=", "select-default-node" },
            -- In PipeWire terminology, an audio sink is a playback output.
            Constraint { "default-node.type", "=", "audio.sink" },
        },
    },
    execute = function(event)
        -- available-nodes is WirePlumber's current set of output candidates.
        local available = event:get_data("available-nodes")
        available = available and available:parse()
        if not available then
            return
        end

        local airpods_output_available = false
        local airpods_eq_available = false
        local lcd_x_eq_available = false

        for _, properties in ipairs(available) do
            local name = properties["node.name"]
            airpods_output_available = airpods_output_available or name == AIRPODS_OUTPUT
            airpods_eq_available = airpods_eq_available or name == AIRPODS_EQ
            lcd_x_eq_available = lcd_x_eq_available or name == LCD_X_EQ
        end

        local selected
        if airpods_output_available and airpods_eq_available then
            selected = AIRPODS_EQ
        elseif lcd_x_eq_available then
            selected = LCD_X_EQ
        end

        if selected then
            log:debug("selecting " .. selected)
            -- Replace the standard result; the priority marks this as an override.
            event:set_data("selected-node-priority", 40000)
            event:set_data("selected-node", selected)
        end
    end,
}:register()
