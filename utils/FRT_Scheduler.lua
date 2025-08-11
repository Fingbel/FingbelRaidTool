-- FRT_Scheduler.lua
-- Tiny After/Debounce utilities (OnUpdate-based)

FRT = FRT or {}
FRT.Scheduler = FRT.Scheduler or {}

do
  local driver = nil

  local function ensureDriver()
    if driver then return driver end
    driver = CreateFrame("Frame")
    driver._timers = {}
    driver:SetScript("OnUpdate", function()
      local dt = arg1 or 0
      local i = 1
      while i <= table.getn(driver._timers) do
        local t = driver._timers[i]
        if t then
          t.elapsed = (t.elapsed or 0) + dt
          if t.elapsed >= t.delay then
            local fn = t.fn
            table.remove(driver._timers, i)
            if type(fn) == "function" then pcall(fn) end
            i = i - 1
          end
        end
        i = i + 1
      end
    end)
    return driver
  end

  function FRT.Scheduler.After(seconds, fn)
    if not seconds or seconds <= 0 then seconds = 0.01 end
    ensureDriver()
    table.insert(driver._timers, { delay = seconds, fn = fn, elapsed = 0 })
  end

  function FRT.Scheduler.Debounce(seconds, fn)
    local pending = false
    local function fire()
      pending = false
      if type(fn) == "function" then pcall(fn) end
    end
    return function()
      if pending then return end
      pending = true
      FRT.Scheduler.After(seconds or 0.10, fire)
    end
  end
end
