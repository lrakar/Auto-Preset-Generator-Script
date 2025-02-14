local ValidationUtils = {}

function ValidationUtils.validateInteger(value)
    local num = tonumber(value)
    return num and num > 0 and math.floor(num) == num
end

function ValidationUtils.validateFloat(value)
    if not value then return false end
    value = value:gsub(",", ".")
    local num = tonumber(value)
    return num and num > 0
end

function ValidationUtils.toFloat(value)
    if not value then return nil end
    value = value:gsub(",", ".")
    return tonumber(value)
end

function ValidationUtils.validateSample(layer)
    return layer and 
           layer.wav_path and 
           layer.sample_ref and 
           layer.sample_ref.source and 
           layer.peak_db ~= nil and 
           layer.amplitude ~= nil
end

function ValidationUtils.validateWAVSource(layer)
    if not layer or not layer.wav_path then return false end
    
    -- Check if file exists
    local file = io.open(layer.wav_path, "rb")
    if not file then return false end
    file:close()
    
    -- Check if sample reference is valid
    if not layer.sample_ref or not layer.sample_ref.source then
        -- Try to reload the sample
        local source = reaper.PCM_Source_CreateFromFile(layer.wav_path)
        if not source then return false end
        
        -- Create new sample if needed
        if not layer.sample_ref then
            layer.sample_ref = Sample:new(layer.wav_path, source)
            layer.sample_ref:analyze()
        else
            layer.sample_ref.source = source
        end
    end
    
    return true
end

return ValidationUtils