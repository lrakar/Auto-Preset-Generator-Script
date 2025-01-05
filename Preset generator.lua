-- Enhanced Preset Generator Script for REAPER with Modern UI
-- Creates regions and corresponding MIDI items with per-instrument settings

-- Initial declarations
local ctx = nil
local JSON = {}

-- Modern UI Color Scheme
local COLORS = {
    text_primary = 0xEAEAEAFF,
    text_secondary = 0xA0A0A0FF,
    background = 0x1E1E1EFF,
    background_light = 0x2D2D2DFF,
    accent = 0x0096C7FF,
    accent_hover = 0x48CAE4FF,
    error = 0xFF5555FF,
    success = 0x4BB543FF,
    header = 0x3D5A80FF,
    separator = 0x383838FF
}

-- JSON encoding/decoding functions
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

-- Preset Management Functions
local function getPresetsDirectory()
    local resourcePath = reaper.GetResourcePath()
    local presetsDir = resourcePath .. "/Scripts/PresetGenerator/presets"
    
    -- Create directory if it doesn't exist
    if not reaper.file_exists(presetsDir) then
        reaper.RecursiveCreateDirectory(presetsDir, 0)
    end
    
    return presetsDir
end

local function savePreset(state)
    if state.preset_name == "" then return false, "Preset name cannot be empty" end
    
    local presetData = {
        preset_name = state.preset_name,
        num_instruments = tonumber(state.num_instruments),
        instruments = state.instrument_data
    }
    
    local fileName = string.format("%s/%s.json", getPresetsDirectory(), state.preset_name)
    local file = io.open(fileName, "w")
    if not file then return false, "Could not create preset file" end
    
    file:write(JSON.encode(presetData))
    file:close()
    
    return true, "Preset saved successfully"
end

local function loadPreset(state, presetName)
    local fileName = string.format("%s/%s.json", getPresetsDirectory(), presetName)
    local file = io.open(fileName, "r")
    if not file then return false, "Could not open preset file" end
    
    local content = file:read("*all")
    file:close()
    
    local presetData = JSON.decode(content)
    if not presetData then return false, "Invalid preset file" end
    
    -- Update state with loaded preset data
    state.preset_name = presetData.preset_name
    state.num_instruments = tostring(presetData.num_instruments)
    state.instrument_data = presetData.instruments
    
    for _, inst in ipairs(state.instrument_data) do
        if inst.range_min == nil then 
            inst.range_min = 0 
        end
        if inst.range_max == nil then 
            inst.range_max = 127 
        end
    end
    
    return true, "Preset loaded successfully"
end

local function deletePreset(presetName)
    local fileName = string.format("%s/%s.json", getPresetsDirectory(), presetName)
    os.remove(fileName)
end

local function getPresetList()
    local presets = {}
    local dir = getPresetsDirectory()
    
    -- Get list of JSON files in presets directory
    local i = 0
    
    repeat
        local filename = reaper.EnumerateFiles(dir, i)
        if filename and filename:match("%.json$") then
            local name = filename:gsub("%.json$", "")
            table.insert(presets, name)
        end
        i = i + 1
    until not filename
    
    table.sort(presets)
    return presets
end

local function drawPresetMenu(ctx, state, COLORS)
    if reaper.ImGui_BeginMenuBar(ctx) then
        local menuWidth = 200
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 4, 4)
        
        if reaper.ImGui_BeginMenu(ctx, "Presets##main") then
            reaper.ImGui_SetNextWindowSize(ctx, menuWidth, 0)
            
            local presets = getPresetList()
            for i, preset in ipairs(presets) do
                -- Calculate sizes
                local availWidth = menuWidth - 12
                local deleteButtonWidth = 24
                local nameWidth = availWidth - deleteButtonWidth
                
                reaper.ImGui_PushID(ctx, "preset_" .. i)
                
                -- Draw preset name
                local clicked = reaper.ImGui_Selectable(ctx, preset, false, nil, nameWidth, 20)
                if clicked then
                    local success, message = loadPreset(state, preset)
                    state.show_message = true
                    state.message = message
                    state.message_type = success and "success" or "error"
                end

                -- Preview on hover over preset name
                local isHovered = reaper.ImGui_IsItemHovered(ctx)
                if isHovered then
                    if not state.hover_start or state.hover_preset ~= preset then
                        -- Reset hover timer and assign current preset
                        state.hover_start = reaper.time_precise()
                        state.hover_preset = preset
                    elseif reaper.time_precise() - state.hover_start > 0.2 then
                        -- Get main window position and size for tooltip positioning
                        local windowX, windowY = reaper.ImGui_GetWindowPos(ctx)
                        local windowWidth = reaper.ImGui_GetWindowSize(ctx)
                        
                        -- Position tooltip to the right of the menu
                        reaper.ImGui_SetNextWindowPos(ctx, windowX + windowWidth, windowY + 30 * i)

                        reaper.ImGui_BeginTooltip(ctx)
                        -- Read and display preset data
                        local fileName = string.format("%s/%s.json", getPresetsDirectory(), preset)
                        local file = io.open(fileName, "r")
                        if file then
                            local content = file:read("*all")
                            file:close()
                            local presetData = JSON.decode(content)
                            if presetData then
                                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLORS.accent)
                                reaper.ImGui_Text(ctx, "Preset Preview")
                                reaper.ImGui_PopStyleColor(ctx)
                                reaper.ImGui_Separator(ctx)
                                
                                reaper.ImGui_Text(ctx, string.format("Name: %s", presetData.preset_name))
                                reaper.ImGui_Text(ctx, string.format("Total Instruments: %d", presetData.num_instruments))
                                reaper.ImGui_Spacing(ctx)
                                
                                for j, inst in ipairs(presetData.instruments) do
                                    if j > 1 then reaper.ImGui_Separator(ctx) end
                                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLORS.accent)
                                    reaper.ImGui_Text(ctx, string.format("Instrument %d", j))
                                    reaper.ImGui_PopStyleColor(ctx)
                                    reaper.ImGui_Text(ctx, string.format("  Name: %s", inst.name))
                                    reaper.ImGui_Text(ctx, string.format("  Note: %s", inst.note))
                                    reaper.ImGui_Text(ctx, string.format("  Length: %s sec", inst.length))
                                    reaper.ImGui_Text(ctx, string.format("  Dynamic Layers: %s", inst.dynamics))
                                    reaper.ImGui_Text(ctx, string.format("  Variations: %s", inst.variations))
                                end
                            end
                        end
                        reaper.ImGui_EndTooltip(ctx)
                    end
                else
                    -- Reset hover timer when not hovering over the item
                    if state.hover_preset == preset then
                        state.hover_start = nil
                        state.hover_preset = nil
                    end
                end
                
                -- Delete button
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_SetCursorPosX(ctx, availWidth - deleteButtonWidth + 8)
                
                -- Style for delete button
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xFF4444FF)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xFF6666FF)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xFF8888FF)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFFFFFFFF)
                
                -- Draw delete button
                if reaper.ImGui_Button(ctx, "×##" .. i, 20, 20) then
                    state.show_delete_confirm = true
                    state.delete_preset = preset
                end
                
                reaper.ImGui_PopStyleColor(ctx, 4)
                reaper.ImGui_PopID(ctx)
            end
            
            reaper.ImGui_EndMenu(ctx)
        end
        
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_EndMenuBar(ctx)
    end
end



-- Delete Confirmation Dialog
local function drawDeleteConfirmDialog(ctx, state)
    if state.show_delete_confirm then
        reaper.ImGui_OpenPopup(ctx, "Delete Preset?##confirm")
    end
    
    if reaper.ImGui_BeginPopupModal(ctx, "Delete Preset?##confirm", true, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        reaper.ImGui_Text(ctx, string.format("Are you sure you want to delete preset '%s'?", state.delete_preset))
        reaper.ImGui_Text(ctx, "This action cannot be undone.")
        reaper.ImGui_Separator(ctx)
        
        if reaper.ImGui_Button(ctx, "Yes") then
            deletePreset(state.delete_preset)
            state.show_delete_confirm = false
            state.delete_preset = nil
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        
        reaper.ImGui_SameLine(ctx)
        
        if reaper.ImGui_Button(ctx, "Cancel") then
            state.show_delete_confirm = false
            state.delete_preset = nil
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        
        reaper.ImGui_EndPopup(ctx)
    end
end

-- Note conversion utilities
local NOTE_NAMES = {
    ["C"] = 0, ["C#"] = 1, ["DB"] = 1, ["D"] = 2, ["D#"] = 3, ["EB"] = 3,
    ["E"] = 4, ["F"] = 5, ["F#"] = 6, ["GB"] = 6, ["G"] = 7, ["G#"] = 8,
    ["AB"] = 8, ["A"] = 9, ["A#"] = 10, ["BB"] = 10, ["B"] = 11
}

local NOTE_NAMES_REVERSE = {
    [0] = "C", [1] = "C#", [2] = "D", [3] = "D#",
    [4] = "E", [5] = "F", [6] = "F#", [7] = "G",
    [8] = "G#", [9] = "A", [10] = "A#", [11] = "B"
}


local function parseNote(noteStr)
    if not noteStr then return nil end
    noteStr = noteStr:upper():gsub("B", "#")
    local noteName = noteStr:match("^[A-G][#]?")
    local octave = tonumber(noteStr:match("%d+$"))
    
    if not noteName or not octave or octave < 0 or octave > 9 then
        return nil
    end
    
    local noteNum = NOTE_NAMES[noteName]
    if not noteNum then return nil end
    
    local midiNote = noteNum + (octave + 1) * 12
    if midiNote < 0 or midiNote > 127 then
        return nil
    end
    
    return midiNote
end

-- MIDI Utilities
local function playMIDINote(note, duration)
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then return end
    
    local noteNum = type(note) == "string" and parseNote(note) or note
    if not noteNum then return end
    
    -- Get track MIDI output
    local midiOutputChannel = 0  -- 0 = channel 1
    local velocity = 100
    
    -- Send MIDI note on
    reaper.StuffMIDIMessage(0, 0x90 | midiOutputChannel, noteNum, velocity)
    
    -- Schedule note off
    reaper.defer(function()
        reaper.StuffMIDIMessage(0, 0x80 | midiOutputChannel, noteNum, 0)
    end)
end

local function handleMIDIInput(state)
    local retval, msg = reaper.MIDI_GetRecentInputEvent(0)
    if not retval then return end
    
    -- Check if we have any data
    if #msg < 3 then return end
    
    local statusByte = msg:byte(1)
    local noteOn = (statusByte >= 0x90 and statusByte <= 0x9F)
    
    if noteOn then
        local note = msg:byte(2)
        local velocity = msg:byte(3)
        if velocity > 0 then
            -- Find which instrument section is open and update its note
            for i, inst in ipairs(state.instrument_data) do
                if state.open_sections and state.open_sections[i] then
                    local octave = math.floor(note / 12) - 1
                    local noteName = NOTE_NAMES_REVERSE[note % 12]
                    inst.note = string.format("%s%d", noteName, octave)
                    break
                end
            end
        end
    end
end

-- Utility Functions (kept the same as they work correctly)
local function rgb2num(r, g, b)
    return r + (g * 256) + (b * 65536)
end

local function generateRandomColor()
    local r = math.random(50, 255)
    local g = math.random(50, 255)
    local b = math.random(50, 255)
    return rgb2num(r, g, b)
end

local function validateInteger(value)
    local num = tonumber(value)
    return num and num > 0 and math.floor(num) == num
end

local function validateFloat(value)
    if not value then return false end
    value = value:gsub(",", ".")
    local num = tonumber(value)
    return num and num > 0
end

local function toFloat(value)
    if not value then return nil end
    value = value:gsub(",", ".")
    return tonumber(value)
end

-- Input validation function
local function validateInputs(state)
    state.error_messages = {}
    local valid = true
    
    if state.preset_name == "" then
        state.error_messages.preset = "Preset name cannot be empty"
        valid = false
    end
    
    if not validateInteger(state.num_instruments) then
        state.error_messages.instruments = "Please enter a valid number"
        valid = false
    end
    
    for i = 1, #state.instrument_data do
        local inst = state.instrument_data[i]
        
        if inst.name == "" then
            state.error_messages["inst_name_" .. i] = "Instrument name cannot be empty"
            valid = false
        end
        
        if inst.note == "" then
            state.error_messages["inst_note_" .. i] = "Note cannot be empty"
            valid = false
        else
            local midiNote = parseNote(inst.note)
            if not midiNote then
                state.error_messages["inst_note_" .. i] = "Invalid note. Please enter a note between C0 and C9"
                valid = false
            end
        end
        
        if not validateFloat(inst.length) then
            state.error_messages["inst_length_" .. i] = "Please enter a valid positive number"
            valid = false
        end
        
        if not validateInteger(inst.dynamics) then
            state.error_messages["inst_dynamics_" .. i] = "Please enter a valid number"
            valid = false
        end
        
        if not validateInteger(inst.variations) then
            state.error_messages["inst_variations_" .. i] = "Please enter a valid number"
            valid = false
        end
    end
    
    return valid
end

-- MIDI and Region generation function (kept the same as it works correctly)
local function generateRegionsAndMIDI(state)
    if not validateInputs(state) then return end
    
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowMessageBox("Please select a track first", "Error", 0)
        return
    end
    
    reaper.Undo_BeginBlock()
    
    local cursor_pos = reaper.GetCursorPosition()
    local current_pos = cursor_pos
    local total_items = 0
    
    for i = 1, #state.instrument_data do
        local inst = state.instrument_data[i]
        local color = generateRandomColor()
        local noteNum = parseNote(inst.note)
        local region_length = toFloat(inst.length)
        local num_dynamics = tonumber(inst.dynamics)
        local num_variations = tonumber(inst.variations)
        
        local sixteenth_length = (region_length * 960) / 16
        
        for d = 1, num_dynamics do
            local velocity
            if num_dynamics > 1 then
                -- d ranges from 1..num_dynamics
                -- fraction goes from 0..1 over the course of dynamic layers
                local fraction = (d - 1) / (num_dynamics - 1)

                velocity = math.floor(
                    inst.range_min + (fraction * (inst.range_max - inst.range_min))
                )
            else
                -- If there's only 1 dynamic layer, just set velocity to range_min
                velocity = inst.range_min
            end

            -- Ensure velocity is between 0..127 (if needed)
            if velocity < 0 then velocity = 0 end
            if velocity > 127 then velocity = 127 end
            
            for v = 1, num_variations do
                local region_name = string.format("%s_%s_%d_%d",
                    state.preset_name, inst.name, d, v)
                
                local _, region_idx = reaper.AddProjectMarker2(0, true,
                    current_pos,
                    current_pos + region_length,
                    region_name,
                    -1,
                    color)
                
                local item = reaper.CreateNewMIDIItemInProj(track,
                    current_pos,
                    current_pos + region_length)
                
                local take = reaper.GetActiveTake(item)
                reaper.MIDI_InsertNote(take, false, false,
                    0,
                    sixteenth_length,
                    1,
                    noteNum,
                    velocity,
                    false)
                
                reaper.MIDI_Sort(take)
                
                current_pos = current_pos + region_length
                total_items = total_items + 1
            end
        end
    end
    
    reaper.Undo_EndBlock("Generate Preset Regions and MIDI", -1)
    reaper.UpdateArrange()
    
    state.show_success = true
    state.success_message = string.format("Successfully created %d regions and MIDI items", total_items)
end

-- Modern UI Components
local function styleInput(ctx)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4.0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 8, 6)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), COLORS.background_light)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), COLORS.background_light + 0x111111FF)
end

local function endStyleInput(ctx)
    reaper.ImGui_PopStyleColor(ctx, 2)  -- Fixed: Added ctx parameter
    reaper.ImGui_PopStyleVar(ctx, 2)    -- Fixed: Added ctx parameter
end

local function drawInstrumentSection(ctx, state, index)
    local inst = state.instrument_data[index]
    
    -- Enhanced header styling
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), COLORS.header)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), COLORS.header + 0x111111FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), COLORS.header + 0x222222FF)
    
    local is_open = reaper.ImGui_CollapsingHeader(ctx, string.format("Instrument %d Settings", index))
    reaper.ImGui_PopStyleColor(ctx, 3)
    
    -- Store open state for MIDI input handling
    if not state.open_sections then state.open_sections = {} end
    state.open_sections[index] = is_open
    
    if is_open then
        reaper.ImGui_PushID(ctx, index)
        reaper.ImGui_Indent(ctx, 10)
        
        -- Name Input
        styleInput(ctx)
        reaper.ImGui_Text(ctx, "Name")
        _, inst.name = reaper.ImGui_InputText(ctx, "##name", inst.name)
        if state.error_messages["inst_name_" .. index] then
            reaper.ImGui_TextColored(ctx, COLORS.error, state.error_messages["inst_name_" .. index])
        end
        endStyleInput(ctx)
        
        reaper.ImGui_Spacing(ctx)
        
        -- Note Input with Play Button
        styleInput(ctx)
        reaper.ImGui_Text(ctx, "Note (e.g., C4, F#3)")
        reaper.ImGui_PushItemWidth(ctx, -80) -- Make room for Play button
        _, inst.note = reaper.ImGui_InputText(ctx, "##note", inst.note)
        reaper.ImGui_PopItemWidth(ctx)
        
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.accent)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.accent_hover)
        if reaper.ImGui_Button(ctx, "Play##" .. index, 70, 22) then
            if parseNote(inst.note) then
                playMIDINote(inst.note, 0.5) -- Play for 0.5 seconds
            end
        end
        reaper.ImGui_PopStyleColor(ctx, 2)
        
        if state.error_messages["inst_note_" .. index] then
            reaper.ImGui_TextColored(ctx, COLORS.error, state.error_messages["inst_note_" .. index])
        end
        endStyleInput(ctx)
        
        reaper.ImGui_Spacing(ctx)
        
        -- Length Input
        styleInput(ctx)
        reaper.ImGui_Text(ctx, "Region Length (seconds)")
        _, inst.length = reaper.ImGui_InputText(ctx, "##length", inst.length)
        if state.error_messages["inst_length_" .. index] then
            reaper.ImGui_TextColored(ctx, COLORS.error, state.error_messages["inst_length_" .. index])
        end
        endStyleInput(ctx)
        
        reaper.ImGui_Spacing(ctx)
        
        -- Dynamics Input
        styleInput(ctx)
        reaper.ImGui_Text(ctx, "Number of Dynamic Layers")
        _, inst.dynamics = reaper.ImGui_InputText(ctx, "##dynamics", inst.dynamics)
        if state.error_messages["inst_dynamics_" .. index] then
            reaper.ImGui_TextColored(ctx, COLORS.error, state.error_messages["inst_dynamics_" .. index])
        end
        endStyleInput(ctx)
        
        reaper.ImGui_Spacing(ctx)
        
        -- Variations Input
        styleInput(ctx)
        reaper.ImGui_Text(ctx, "Number of Variations")
        _, inst.variations = reaper.ImGui_InputText(ctx, "##variations", inst.variations)
        if state.error_messages["inst_variations_" .. index] then
            reaper.ImGui_TextColored(ctx, COLORS.error, state.error_messages["inst_variations_" .. index])
        end
        endStyleInput(ctx)
         -- Two-handle (range) slider for velocity
        styleInput(ctx)
        reaper.ImGui_Text(ctx, "Velocity Range")

        -- Attempt to use ImGui_SliderInt2 (ReaImGui must support it)
        local changed, newMin, newMax = reaper.ImGui_SliderInt2(
            ctx,
            "##velocity_range_" .. index,
            inst.range_min,   -- current min
            inst.range_max,   -- current max
            0,                -- slider lowest possible value
            127,              -- slider highest possible value
            "%d",             -- display format (optional)
            reaper.ImGui_SliderFlags_AlwaysClamp()  -- optional clamp
        )
        if changed then
            inst.range_min = newMin
            inst.range_max = newMax
        end
        endStyleInput(ctx)

        reaper.ImGui_Spacing(ctx)

        reaper.ImGui_Unindent(ctx, 10)
        reaper.ImGui_PopID(ctx)
        reaper.ImGui_Spacing(ctx)
    end
end

local function drawUI(state)
    -- Set window styling
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), COLORS.background)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLORS.text_primary)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 16, 16)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 8, 8)
    
    local window_flags = reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_MenuBar()
    local visible, open = reaper.ImGui_Begin(ctx, "Preset Generator", true, window_flags)
    
    if visible then
        reaper.ImGui_SetWindowSize(ctx, 450, 600, reaper.ImGui_Cond_FirstUseEver())
        
        -- Add Preset Menu and Delete Dialog
        drawPresetMenu(ctx, state, COLORS)
        drawDeleteConfirmDialog(ctx, state)
        
        -- Title
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLORS.accent)
        reaper.ImGui_Text(ctx, "PRESET GENERATOR")
        reaper.ImGui_PopStyleColor(ctx)
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Main Settings
        styleInput(ctx)
        reaper.ImGui_Text(ctx, "Preset Name")
        _, state.preset_name = reaper.ImGui_InputText(ctx, "##preset_name", state.preset_name)
        if state.error_messages.preset then
            reaper.ImGui_TextColored(ctx, COLORS.error, state.error_messages.preset)
        end
        endStyleInput(ctx)
        
        reaper.ImGui_Spacing(ctx)
        
        styleInput(ctx)
        reaper.ImGui_Text(ctx, "Number of Instruments")
        local prev_num = state.num_instruments
        _, state.num_instruments = reaper.ImGui_InputText(ctx, "##num_instruments", state.num_instruments)
        
        if state.num_instruments ~= prev_num and validateInteger(state.num_instruments) then
            local new_count = tonumber(state.num_instruments)
            while #state.instrument_data < new_count do
                table.insert(state.instrument_data, {
                    name = "",
                    note = "",
                    length = "1.5",
                    dynamics = "",
                    variations = ""
                })
            end
            while #state.instrument_data > new_count do
                table.remove(state.instrument_data)
            end
        end
        
        if state.error_messages.instruments then
            reaper.ImGui_TextColored(ctx, COLORS.error, state.error_messages.instruments)
        end
        endStyleInput(ctx)
        
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Instrument Sections
        if validateInteger(state.num_instruments) then
            for i = 1, #state.instrument_data do
                drawInstrumentSection(ctx, state, i)
            end
        end
        
        -- Generate and Save Buttons
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Generate Button
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.accent)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.accent_hover)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4.0)
        if reaper.ImGui_Button(ctx, "Generate Regions and MIDI", -1, 40) then
            generateRegionsAndMIDI(state)
        end
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_PopStyleColor(ctx, 2)
        
        -- Save Preset Button
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.accent)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.accent_hover)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4.0)
        if reaper.ImGui_Button(ctx, "Save Preset", -1, 40) then
            local success, message = savePreset(state)
            state.show_message = true
            state.message = message
            state.message_type = success and "success" or "error"
        end
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_PopStyleColor(ctx, 2)
        
        -- Success/Error Messages
        if state.show_message then
            reaper.ImGui_Spacing(ctx)
            local color = state.message_type == "success" and COLORS.success or COLORS.error
            reaper.ImGui_TextColored(ctx, color, state.message)
            
            -- Clear message after delay
            if not state.message_start then
                state.message_start = reaper.time_precise()
            elseif reaper.time_precise() - state.message_start > 3 then
                state.show_message = false
                state.message = nil
                state.message_type = nil
                state.message_start = nil
            end
        end
        
        -- Success Message (from generate function)
        if state.show_success then
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_TextColored(ctx, COLORS.success, state.success_message)
        end
    end
    
    reaper.ImGui_End(ctx)
    
    -- Pop window styling
    reaper.ImGui_PopStyleVar(ctx, 2)
    reaper.ImGui_PopStyleColor(ctx, 2)
    
    return open
end

local function createUI()
    ctx = reaper.ImGui_CreateContext('Preset Generator')
    
    -- Font configuration
    local font_size = 14
    local font = reaper.ImGui_CreateFont('Calibri', font_size)
    reaper.ImGui_Attach(ctx, font)
    
    -- Initialize state
    local state = {
        -- Basic preset data
        preset_name = "",
        num_instruments = "",
        instrument_data = {},
        
        -- UI state
        error_messages = {},
        show_success = false,
        success_message = "",
        open_sections = {},
        
        -- Font reference
        font = font,
        
        -- Preset management state
        show_delete_confirm = false,  -- Controls delete confirmation dialog
        delete_preset = nil,          -- Stores name of preset pending deletion
        show_message = false,         -- Controls visibility of status messages
        message = nil,                -- Current status message text
        message_type = nil,           -- Message type (success/error)
        message_start = nil,          -- Timestamp for message auto-hide
        hover_start = nil,            -- Timestamp for preset preview delay
        
        -- MIDI handling state
        open_sections = {},           -- Track which instrument sections are open
        
        -- Load/Save state
        last_saved_preset = nil,      -- Name of last saved/loaded preset
        unsaved_changes = false,      -- Track if there are unsaved changes
        
        -- Additional UI state
        is_popup_open = false,        -- Track if any popup is currently open
        selected_preset = nil,        -- Currently selected preset in menu
        
        -- Error handling
        last_error = nil,            -- Store last error message
        error_timestamp = nil,       -- When the error occurred
        
        -- Validation state
        validation_errors = {},      -- Store validation errors by field
        is_valid = true,            -- Overall form validation state
        
        -- Theme/styling (can be expanded later)
        current_theme = "dark",     -- Current UI theme
        
        -- Undo/Redo state
        history = {},               -- Store state history
        history_index = 1,          -- Current position in history
        max_history = 50            -- Maximum number of history states to keep
    }
    
    -- Initialize default instrument if empty
    if #state.instrument_data == 0 then
        table.insert(state.instrument_data, {
            name = "",
            note = "",
            length = "1.5",
            dynamics = "",
            variations = "",
            range_min = 0,
            range_max = 127
        })
    end
    
    -- Function to check for MIDI input and update UI
    local function handleInput()
        -- Handle MIDI input for note updates
        handleMIDIInput(state)
        
        -- Auto-save timer (every 5 minutes)
        local current_time = reaper.time_precise()
        if not state.last_autosave then
            state.last_autosave = current_time
        elseif current_time - state.last_autosave > 300 and state.unsaved_changes then
            local success, message = savePreset(state)
            if success then
                state.last_autosave = current_time
                state.unsaved_changes = false
            end
        end
        
        -- Clear old error messages
        if state.last_error and current_time - state.error_timestamp > 5 then
            state.last_error = nil
            state.error_timestamp = nil
        end
    end
    
    -- Main loop function
local function loop()
    -- Check if context exists
    if not ctx then return end
    
    -- Push global styling
    reaper.ImGui_PushFont(ctx, state.font)
    
    -- Handle input and updates
    handleInput()
    
    -- Draw main UI
    local open = drawUI(state)
    
    -- Pop global styling
    reaper.ImGui_PopFont(ctx)
    
    -- Continue loop if window is open
    if open then
        reaper.defer(loop)
    else
        -- Store context before clearing
        local context = ctx
        
        -- Cleanup when closing
        if state.unsaved_changes then
            local save_success = savePreset(state)
            if not save_success then
                state.last_error = "Failed to save changes on exit"
                state.error_timestamp = reaper.time_precise()
            end
        end

        ctx = nil
    end
end
    
    -- Start the main loop
    reaper.defer(loop)
    
    -- Return state for external access if needed
    return state
end

-- Initialize random seed
math.randomseed(os.time())

-- Start the script
createUI()