local lastKey = ""

local function numberText(value, pattern)
  if type(value) ~= "number" then
    return "--"
  end
  return string.format(pattern, value)
end

local function render()
  local stats = noctalia.systemStats() or {}
  local cpu = stats.cpu or {}
  local ram = stats.ram or {}
  local usage = numberText(cpu.usagePercent, "%.0f%%")
  local temperature = numberText(cpu.tempC, "%.0f°C")
  local memoryGiB = if type(ram.usedMb) == "number" then ram.usedMb * 1000000 / 1073741824 else nil
  local memory = numberText(memoryGiB, "%.1f GiB")
  local key = usage .. "|" .. temperature .. "|" .. memory
  if key == lastKey then
    return
  end
  lastKey = key
  local temperatureColor = "on_surface"
  if type(cpu.tempC) == "number" then
    if cpu.tempC >= 80 then
      temperatureColor = "error"
    elseif cpu.tempC >= 60 then
      temperatureColor = "tertiary"
    end
  end
  local memoryColor = if type(ram.usagePercent) == "number" and ram.usagePercent >= 90 then "error" else "on_surface"
  barWidget.render(ui.row({ gap = 6, align = "center", justify = "center" }, {
    ui.glyph({ name = "gauge", size = 14 }),
    ui.label({ text = usage, maxLines = 1 }),
    ui.box({ width = 3, height = 1, opacity = 0 }),
    ui.glyph({ name = "flame", size = 14, color = temperatureColor }),
    ui.label({ text = temperature, color = temperatureColor, maxLines = 1 }),
    ui.box({ width = 3, height = 1, opacity = 0 }),
    ui.glyph({ name = "cpu", size = 14, color = memoryColor }),
    ui.label({ text = memory, color = memoryColor, maxLines = 1 }),
  }))
  barWidget.setTooltip({
    { key = "CPU", value = usage },
    { key = "温度", value = temperature },
    { key = "内存", value = memory },
  })
end

function update()
  render()
end

function onConfigChanged()
  lastKey = ""
  render()
end

noctalia.setUpdateInterval(1000)
render()
