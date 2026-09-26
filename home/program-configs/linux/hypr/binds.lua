-- Keybinds. Required automatically by the Home Manager Hyprland module via
-- extraLuaFiles, so this file runs before the hl.config(...) calls generated
-- from `settings`. Nothing here depends on config values at load time.

local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "rofi -show drun"
local screenshot  = "grimblast -f -n copy area"
local colorPicker = "hyprpicker -a"

hl.bind(mainMod .. " + RETURN",         hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Q",      hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + E",      hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E",              hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V",              hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",              hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P",              hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",              hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + Y",              hl.dsp.exec_cmd(colorPicker))

-- Toggle layout dwindle <-> scrolling. Native now: `hyprctl keyword` no longer
-- works under the Lua config manager, and hl.get_config/hl.config do the same
-- job in-process without shelling out.
hl.bind(mainMod .. " + TAB", function()
    local layout = hl.get_config("general.layout")
    hl.config({ general = { layout = layout == "scrolling" and "dwindle" or "scrolling" } })
end)

-- Scrolling layout. hl.dsp.layout only acts in the scrolling layout and is
-- harmless in dwindle.
hl.bind(mainMod .. " + period",         hl.dsp.layout("move +col"))     -- scroll the tape one column right
hl.bind(mainMod .. " + comma",          hl.dsp.layout("move -col"))     -- scroll the tape one column left
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.layout("swapcol r"))     -- swap active column with its right neighbour
hl.bind(mainMod .. " + SHIFT + comma",  hl.dsp.layout("swapcol l"))     -- swap active column with its left neighbour
hl.bind(mainMod .. " + R",              hl.dsp.layout("colresize +conf")) -- cycle column width forward
hl.bind(mainMod .. " + SHIFT + R",      hl.dsp.layout("colresize -conf")) -- cycle column width backward
hl.bind(mainMod .. " + G",              hl.dsp.layout("fit visible"))   -- fit all visible columns
hl.bind(mainMod .. " + M",              hl.dsp.layout("fit expand"))    -- let the active window fill free space
hl.bind(mainMod .. " + C",              hl.dsp.layout("consume"))       -- suck the window into the previous column
hl.bind(mainMod .. " + X",              hl.dsp.layout("expel"))         -- detach the window into its own column
hl.bind(mainMod .. " + U",              hl.dsp.layout("promote"))       -- promote the window into a new column

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshot))
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("~/.config/quickshell/scripts/theme-switch.sh menu"))
hl.bind(mainMod .. " + ALT + R",   hl.dsp.exec_cmd("killall -SIGUSR1 gpu-screen-recorder"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces 1-10; key 0 maps to workspace 10.
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S",          hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + CTRL + S",   hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Former bindel: locked + repeating
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Former bindl: locked, requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
