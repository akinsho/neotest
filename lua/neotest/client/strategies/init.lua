local lib = require("neotest.lib")
local logger = require("neotest.logging")
local fu = lib.func_util

---@return neotest.Strategy
local get_strategy = fu.memoize(function(name)
  return require("neotest.client.strategies." .. name)
end)

---@class neotest.ProcessTracker
---@field _instances table<integer, neotest.Process>
local NeotestProcessTracker = {}

function NeotestProcessTracker:new()
  local tracker = {
    _instances = {},
  }
  self.__index = self
  setmetatable(tracker, self)
  return tracker
end

---@async
---@param pos_id string
---@param spec neotest.RunSpec
---@param args? table
---@return neotest.StrategyResult
function NeotestProcessTracker:run(pos_id, spec, args)
  local strategy = self:_get_strategy(args)
  logger.info("Starting process", pos_id, "with strategy", args.strategy)
  logger.debug("Strategy spec", spec)
  local instance = strategy(spec)
  self._instances[pos_id] = instance
  local code = instance.result()
  logger.info("Process for position", pos_id, "exited with code", code)
  local output = instance.output()
  logger.debug("Output of process ", output)
  self._instances[pos_id] = nil
  return { code = code, output = output }
end

function NeotestProcessTracker:stop(pos_id)
  local instance = self._instances[pos_id]
  if not instance then
    return false
  end
  instance.stop()
  return true
end

---@return neotest.Strategy
function NeotestProcessTracker:_get_strategy(args)
  if type(args.strategy) == "string" then
    return get_strategy(args.strategy)
  end
  return args.strategy
end

---@async
---@param pos_id string
function NeotestProcessTracker:attach(pos_id)
  local instance = self._instances[pos_id]
  if not instance then
    return false
  end
  instance.attach()
  return true
end

function NeotestProcessTracker:exists(proc_key)
  return self._instances[proc_key] ~= nil
end

return function()
  return NeotestProcessTracker:new()
end
