local Settings = {}

-- Get the script path and require JSON module
local script_path = debug.getinfo(1, "S").source:match([[^@?(.*[\/])[^\/]-$]])
package.path = package.path .. ";" .. script_path .. "?.lua"
local JSON = require("json")

-- Settings file path
local settings_file = script_path .. "settings.json"

-- Default settings
local defaults = {
    font_size = 14,
    default_plugin = "Kontakt 7",
    default_length = "1.5",
    preview_velocity = 100,
    preview_duration = 0.5,
    autosave_interval = 5,
    autosave_enabled = true,
    region_spacing = 0.0,
    default_dynamics = 10,    -- New default setting
    default_variations = 1    -- New default setting
}

-- Current settings (initialized with defaults)
Settings.current = {}

-- Initialize settings
function Settings.init()
    -- Load settings from file if it exists
    local file = io.open(settings_file, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        local loaded = JSON.decode(content)
        if loaded then
            -- Merge loaded settings with defaults
            for key, value in pairs(defaults) do
                Settings.current[key] = loaded[key] or value
            end
            return
        end
    end
    
    -- If no file exists or loading failed, use defaults
    for key, value in pairs(defaults) do
        Settings.current[key] = value
    end
end

-- Save settings to file
function Settings.save()
    local file = io.open(settings_file, "w")
    if not file then
        return false, "Could not open settings file for writing"
    end
    
    file:write(JSON.encode(Settings.current))
    file:close()
    return true
end

-- Get a setting value
function Settings.get(key)
    return Settings.current[key] or defaults[key]
end

-- Set a setting value
function Settings.set(key, value)
    if defaults[key] == nil then
        return false, "Invalid setting key: " .. key
    end
    
    -- Type checking
    if type(value) ~= type(defaults[key]) then
        return false, "Invalid value type for setting: " .. key
    end
    
    Settings.current[key] = value
    return Settings.save()
end

-- Reset all settings to defaults
function Settings.reset()
    for key, value in pairs(defaults) do
        Settings.current[key] = value
    end
    return Settings.save()
end

-- Get all default settings
function Settings.getDefaults()
    local copy = {}
    for key, value in pairs(defaults) do
        copy[key] = value
    end
    return copy
end

-- Validate a setting value
function Settings.validate(key, value)
    if defaults[key] == nil then
        return false, "Invalid setting key"
    end
    
    local val_type = type(value)
    local def_type = type(defaults[key])
    
    if val_type ~= def_type then
        return false, string.format("Invalid type: expected %s, got %s", def_type, val_type)
    end
    
    -- Specific validations
    if key == "font_size" then
        if value < 8 or value > 32 then
            return false, "Font size must be between 8 and 32"
        end
    elseif key == "preview_velocity" then
        if value < 1 or value > 127 then
            return false, "Velocity must be between 1 and 127"
        end
    elseif key == "preview_duration" then
        if value <= 0 or value > 10 then
            return false, "Preview duration must be between 0 and 10 seconds"
        end
    elseif key == "autosave_interval" then
        if value < 1 or value > 60 then
            return false, "Autosave interval must be between 1 and 60 minutes"
        end
    elseif key == "default_dynamics" or key == "default_variations" then
        if value < 0 or value > 400 then
            return false, "Value must be between 0 and 400"
        end
    end
    
    return true
end

return Settings
