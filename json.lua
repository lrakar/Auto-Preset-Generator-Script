local JSON = {}

function JSON.encode(obj)
    local function serialize(o)
        if type(o) == "number" then
            return tostring(o)
        elseif type(o) == "string" then
            return string.format("%q", o)
        elseif type(o) == "table" then
            local parts = {}
            if #o > 0 then -- Array
                for _, v in ipairs(o) do
                    table.insert(parts, serialize(v))
                end
                return "[" .. table.concat(parts, ",") .. "]"
            else -- Object
                for k, v in pairs(o) do
                    table.insert(parts, string.format("%q:%s", k, serialize(v)))
                end
                return "{" .. table.concat(parts, ",") .. "}"
            end
        end
        return "null"
    end
    return serialize(obj)
end

function JSON.decode(str)
    local pos = 1
    
    -- Forward declarations
    local parseValue, parseObject, parseArray, parseString, parseNumber
    
    function parseString()
        local startPos = pos + 1 -- Skip opening quote
        local endPos = startPos
        
        while endPos <= #str do
            if str:sub(endPos,endPos) == '"' and str:sub(endPos-1,endPos-1) ~= '\\' then
                break
            end
            endPos = endPos + 1
        end
        
        pos = endPos + 1
        return str:sub(startPos, endPos-1)
    end
    
    function parseNumber()
        local numEnd = pos
        while numEnd <= #str and str:sub(numEnd,numEnd):match("[%d%.%-]") do
            numEnd = numEnd + 1
        end
        local num = str:sub(pos, numEnd-1)
        pos = numEnd
        return tonumber(num)
    end
    
    function parseObject()
        local obj = {}
        pos = pos + 1 -- Skip {
        
        while pos <= #str do
            -- Skip whitespace
            while pos <= #str and str:sub(pos,pos):match("%s") do pos = pos + 1 end
            
            if str:sub(pos,pos) == "}" then
                pos = pos + 1
                break
            end
            
            if str:sub(pos,pos) ~= '"' then
                error("Expected string key in object")
            end
            
            local key = parseString()
            
            -- Skip whitespace and colon
            while pos <= #str and str:sub(pos,pos):match("[%s:]") do pos = pos + 1 end
            
            obj[key] = parseValue()
            
            -- Skip whitespace
            while pos <= #str and str:sub(pos,pos):match("%s") do pos = pos + 1 end
            
            if str:sub(pos,pos) == "}" then
                pos = pos + 1
                break
            elseif str:sub(pos,pos) == "," then
                pos = pos + 1
            end
        end
        return obj
    end
    
    function parseArray()
        local arr = {}
        pos = pos + 1 -- Skip [
        
        while pos <= #str do
            -- Skip whitespace
            while pos <= #str and str:sub(pos,pos):match("%s") do pos = pos + 1 end
            
            if str:sub(pos,pos) == "]" then
                pos = pos + 1
                break
            end
            
            table.insert(arr, parseValue())
            
            -- Skip whitespace
            while pos <= #str and str:sub(pos,pos):match("%s") do pos = pos + 1 end
            
            if str:sub(pos,pos) == "]" then
                pos = pos + 1
                break
            elseif str:sub(pos,pos) == "," then
                pos = pos + 1
            end
        end
        return arr
    end
    
    function parseValue()
        -- Skip whitespace
        while pos <= #str and str:sub(pos,pos):match("%s") do pos = pos + 1 end
        
        local c = str:sub(pos,pos)
        if c == "{" then
            return parseObject()
        elseif c == "[" then
            return parseArray()
        elseif c == '"' then
            return parseString()
        elseif c:match("[%d%-]") then
            return parseNumber()
        elseif str:sub(pos,pos+3) == "true" then
            pos = pos + 4
            return true
        elseif str:sub(pos,pos+4) == "false" then
            pos = pos + 5
            return false
        elseif str:sub(pos,pos+3) == "null" then
            pos = pos + 4
            return nil
        else
            error("Unexpected character at position " .. pos .. ": " .. c)
        end
    end
    
    -- Start parsing
    local result = parseValue()
    
    -- Skip trailing whitespace
    while pos <= #str and str:sub(pos,pos):match("%s") do pos = pos + 1 end
    
    -- Check for trailing characters
    if pos <= #str then
        error("Trailing characters in JSON string")
    end
    
    return result
end

return JSON
