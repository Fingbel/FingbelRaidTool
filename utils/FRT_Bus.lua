-- FRT_Bus.lua
-- Tiny pub/sub for view updates

FRT = FRT or {}
FRT.Bus = FRT.Bus or {}

do
  local subs = {}

  function FRT.Bus.Subscribe(fn)
    if type(fn) ~= "function" then return end
    table.insert(subs, fn)
  end

  function FRT.Bus.Unsubscribe(fn)
    local i=1
    while i <= table.getn(subs) do
      if subs[i] == fn then table.remove(subs, i); return end
      i=i+1
    end
  end

  function FRT.Bus.Notify()
    local i=1
    while i <= table.getn(subs) do
      local ok = pcall(subs[i])
      i=i+1
    end
  end
end
