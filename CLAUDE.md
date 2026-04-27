# awesome WM config

## Visual verification: headless screenshot pipeline

For any UI work in this repo (widgets, popups, themes, bar layout), use the
headless screenshot pipeline to verify changes — the real `rc.lua` is loaded
inside Xvfb so what you see in the PNG matches what would render on the
actual desktop.

### Quick start

```bash
# Bar only
dev/take-screenshot.sh

# Bar + hover popup at given coords
MOUSE_X=875 MOUSE_Y=11 dev/take-screenshot.sh
```

Outputs land in `/tmp/awesome-shots/`:
- `bar.png` — full-screen capture (bar + wallpaper).
- `hover.png` — only if `MOUSE_X`/`MOUSE_Y` set.
- `awesome.log` — awesome's stderr; check this if a screenshot looks empty
  or wrong.

Read the PNGs back with the `Read` tool to inspect them.

### Picking hover coordinates

The bar is at `y ≈ 0–24`. For `x`, take a `bar.png` first, eyeball where the
widget you care about is, and pass those coords on the next run. Coordinates
shift if the screen size or bar layout (`widgets.lua`) changes.

### How the pipeline works

`dev/take-screenshot.sh` is the launcher: starts Xvfb on `:99`, runs
`awesome -c dev/screenshot-rc.lua` under `dbus-run-session`, waits a few
seconds, then `scrot`s.

`dev/screenshot-rc.lua` is a thin wrapper that:
1. Replaces backends that need network/hardware with stubs/canned data.
2. `dofile`s the real `~/.config/awesome/rc.lua`.

Currently stubbed:
- **Weather** — `widgets.weather.backends.weather_gov.new` returns the
  canned backend. Driven by `canned-weather-gov-{station,observations,points,forecast-hourly}.json`
  in the repo root.
- **Temperature** — `widgets.temperature.backends.sysfs` is monkey-patched
  to skip hwmon detection and return a fixed 42.5 °C (the green number on
  the bar).

### Adding a new stub

If you change a widget that depends on something the sandbox lacks (network,
specific hardware, an external daemon), pre-load its backends module in
`dev/screenshot-rc.lua` and patch the constructor or the methods you need
to bypass. Mirror the existing weather/temperature patterns.

### Sandbox limitations (not bugs)

These are environmental, not config issues — leave them alone unless the
feature you're working on touches them:

- **PulseAudio** not running → `audio.lua`'s reconnect loop runs in vain;
  volume / MPRIS keys are no-ops in the screenshot.
- **Battery** absent → `battery()` returns `nil`, widget is silently
  omitted.
- **Systray** empty (no real apps).
- `xset` / `xmodmap` / `xrdb` typically missing → harmless startup
  warnings in `awesome.log`.

## Codebase shape

Widgets live under `widgets/<name>/` with three files:
- `init.lua` — wibar widget construction + refresh wiring (timers, signals,
  hover handlers).
- `render.lua` — pure rendering: takes a state table, emits Pango markup
  via the `widgets.renderer` helper.
- `backends.lua` — data sources. Backends are plain Lua tables with
  `:new()`, `:detect()`, `:state()`. Most backends have a paired
  `canned_*` variant fed from a JSON fixture, used by tests and by the
  screenshot pipeline.

`donut` is the user's local async/dbus shim (under `donut/`). `donut.run(work,
callback)` schedules `work` in a coroutine and invokes `callback(ok, result)`
when it finishes.
