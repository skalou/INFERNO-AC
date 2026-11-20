-- Debug log: CSP log plus debug_log.txt in the app folder.
local modules = require('core.modules')
local Log = modules.debug

local App = modules.paths.App
local settings = modules.settings.settings

local Debug = {}
Debug.simulator = { text = 'Simulated chat message', author = 'Simulated driver', friend = false }
Debug.logFile = "debug_log.txt"
Debug.logFile_path = ac.getFolder(ac.FolderID.ACApps) .. '\\lua\\' .. App.folderName .. '\\debug_log.txt'

-- Clear/Create log file at startup
local f = io.open(Debug.logFile_path, "w")
if f then
    f:write("--- New Session Started: " .. os.date("%Y-%m-%d %H:%M:%S") .. " ---\n")
    f:close()
end

function Debug.log(level, message, ...)
    local args = {...}
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local formattedMessage = string.format("[%s] [%s] %s", timestamp, level, message)
    
    -- Print to AC Log
    ac.log(App.displayName .. " [" .. level .. "]: " .. message)
    
    -- Print to file
    local f = io.open(Debug.logFile_path, "a")
    if f then
        f:write(formattedMessage .. "\n")
        -- Handle extra arguments if any
        if #args > 0 then
            for _, arg in ipairs(args) do
                f:write(tostring(arg) .. " ")
            end
            f:write("\n")
        end
        f:close()
    end
end

function Debug.info(message, ...) Debug.log("INFO", message, ...) end
function Debug.warn(message, ...) Debug.log("WARN", message, ...) end
function Debug.error(message, ...) Debug.log("ERROR", message, ...) end
function Debug.trace(message, ...)
    if settings.debugModeEnabled then
        Debug.log("TRACE", message, ...)
    end
end

Log.Debug = Debug

return Log
