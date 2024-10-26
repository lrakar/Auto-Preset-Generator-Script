-- Enhanced Preset Generator Script for REAPER with MIDI Support
-- Creates regions and corresponding MIDI items with per-instrument settings

-- Note conversion utilities
local NOTE_NAMES = {
    ["C"] = 0, ["C#"] = 1, ["DB"] = 1, ["D"] = 2, ["D#"] = 3, ["EB"] = 3,
    ["E"] = 4, ["F"] = 5, ["F#"] = 6, ["GB"] = 6, ["G"] = 7, ["G#"] = 8,
    ["AB"] = 8, ["A"] = 9, ["A#"] = 10, ["BB"] = 10, ["B"] = 11
}

local function rgb2num(r, g, b)
    return r + (g * 256) + (b * 65536)
end

local function generateRandomColor()
    local r = math.random(50, 255)
    local g = math.random(50, 255)
    local b = math.random(50, 255)
    return rgb2num(r, g, b)
end

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

local function validateInteger(value)
    local num = tonumber(value)
    return num and num > 0 and math.floor(num) == num
end

local function validateFloat(value)
    if not value then return false end
    -- Replace comma with decimal point if present
    value = value:gsub(",", ".")
    local num = tonumber(value)
    return num and num > 0
end

-- Convert string to float, handling both . and , as decimal separators
local function toFloat(value)
    if not value then return nil end
    value = value:gsub(",", ".")
    return tonumber(value)
end

local ctx = nil  -- Global context variable

local function validateInputs(state)
    state.error_messages = {}
    local valid = true
    
    -- Validate preset name
    if state.preset_name == "" then
        state.error_messages.preset = "Preset name cannot be empty"
        valid = false
    end
    
    -- Validate number of instruments
    if not validateInteger(state.num_instruments) then
        state.error_messages.instruments = "Please enter a valid number"
        valid = false
    end
    
    -- Validate instrument data
    for i = 1, #state.instrument_data do
        local inst = state.instrument_data[i]
        
        -- Validate name
        if inst.name == "" then
            state.error_messages["inst_name_" .. i] = "Instrument name cannot be empty"
            valid = false
        end
        
        -- Validate note
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
        
        -- Validate region length
        if not validateFloat(inst.length) then
            state.error_messages["inst_length_" .. i] = "Please enter a valid positive number"
            valid = false
        end
        
        -- Validate dynamics
        if not validateInteger(inst.dynamics) then
            state.error_messages["inst_dynamics_" .. i] = "Please enter a valid number"
            valid = false
        end
        
        -- Validate variations
        if not validateInteger(inst.variations) then
            state.error_messages["inst_variations_" .. i] = "Please enter a valid number"
            valid = false
        end
    end
    
    return valid
end

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
        
        -- Calculate sixteenth note length for this instrument's regions
        local sixteenth_length = (region_length * 960) / 16  -- PPQ = 960
        
        for d = 1, num_dynamics do
            local velocity = math.max(1, math.floor((d / num_dynamics) * 127))
            
            for v = 1, num_variations do
                -- Create region
                local region_name = string.format("%s_%s_%d_%d",
                    state.preset_name, inst.name, d, v)
                
                local _, region_idx = reaper.AddProjectMarker2(0, true,
                    current_pos,
                    current_pos + region_length,
                    region_name,
                    -1,
                    color)
                
                -- Create MIDI item
                local item = reaper.CreateNewMIDIItemInProj(track,
                    current_pos,
                    current_pos + region_length)
                
                -- Insert MIDI note
                local take = reaper.GetActiveTake(item)
                reaper.MIDI_InsertNote(take, false, false,
                    0,                  -- Start position
                    sixteenth_length,   -- Note length (1/16 of region)
                    1,                  -- Channel
                    noteNum,            -- Note number
                    velocity,           -- Velocity
                    false)             -- Selected
                
                reaper.MIDI_Sort(take)
                
                current_pos = current_pos + region_length
                total_items = total_items + 1
            end
        end
    end
    
    reaper.Undo_EndBlock("Generate Preset Regions and MIDI", -1)
    reaper.UpdateArrange()
    
    state.show_success = true
    state.success_message = string.format(
        "Regions and MIDI items generated successfully: %d created",
        total_items)
end

local function drawUI(state)
    local window_flags = reaper.ImGui_WindowFlags_NoCollapse()
    local visible, open = reaper.ImGui_Begin(ctx, 'Preset Generator', true, window_flags)
    
    if visible then
        reaper.ImGui_SetWindowSize(ctx, 400, 450, reaper.ImGui_Cond_FirstUseEver())
        
        -- Preset Name
        reaper.ImGui_Text(ctx, 'Preset Name')
        _, state.preset_name = reaper.ImGui_InputText(ctx, '##preset_name', state.preset_name)
        if state.error_messages.preset then
            reaper.ImGui_TextColored(ctx, 0xFF5555FF, state.error_messages.preset)
        end
        
        reaper.ImGui_Spacing(ctx)
        
        -- Number of Instruments
        reaper.ImGui_Text(ctx, 'Number of Instruments')
        local prev_num = state.num_instruments
        _, state.num_instruments = reaper.ImGui_InputText(ctx, '##num_instruments', state.num_instruments)
        
        if validateInteger(state.num_instruments) and state.num_instruments ~= prev_num then
            local new_count = tonumber(state.num_instruments)
            while #state.instrument_data < new_count do
                table.insert(state.instrument_data, {
                    name = "",
                    note = "",
                    length = "1.5",  -- Default length
                    dynamics = "",
                    variations = ""
                })
            end
            while #state.instrument_data > new_count do
                table.remove(state.instrument_data)
            end
        end
        
        if state.error_messages.instruments then
            reaper.ImGui_TextColored(ctx, 0xFF5555FF, state.error_messages.instruments)
        end
        
        reaper.ImGui_Spacing(ctx)
        
        -- Dynamic Instrument Fields
        if validateInteger(state.num_instruments) then
            for i = 1, tonumber(state.num_instruments) do
                reaper.ImGui_PushID(ctx, i)
                
                -- Instrument section header
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_TextColored(ctx, 0x88BB88FF, 
                    string.format('Instrument %d Settings', i))
                reaper.ImGui_Separator(ctx)
                reaper.ImGui_Spacing(ctx)
                
                -- Instrument Name
                reaper.ImGui_Text(ctx, 'Name')
                _, state.instrument_data[i].name = reaper.ImGui_InputText(ctx, '##name', 
                    state.instrument_data[i].name or "")
                if state.error_messages["inst_name_" .. i] then
                    reaper.ImGui_TextColored(ctx, 0xFF5555FF, 
                        state.error_messages["inst_name_" .. i])
                end
                
                -- Note Input
                reaper.ImGui_Text(ctx, 'Note (e.g., C4, F#3, Gb5)')
                _, state.instrument_data[i].note = reaper.ImGui_InputText(ctx, '##note',
                    state.instrument_data[i].note or "")
                if state.error_messages["inst_note_" .. i] then
                    reaper.ImGui_TextColored(ctx, 0xFF5555FF, 
                        state.error_messages["inst_note_" .. i])
                end
                
                -- Region Length
                reaper.ImGui_Text(ctx, 'Region Length (seconds)')
                _, state.instrument_data[i].length = reaper.ImGui_InputText(ctx, '##length',
                    state.instrument_data[i].length or "1.5")
                if state.error_messages["inst_length_" .. i] then
                    reaper.ImGui_TextColored(ctx, 0xFF5555FF, 
                        state.error_messages["inst_length_" .. i])
                end
                
                -- Dynamic Layers
                reaper.ImGui_Text(ctx, 'Number of Dynamic Layers')
                _, state.instrument_data[i].dynamics = reaper.ImGui_InputText(ctx, '##dynamics',
                    state.instrument_data[i].dynamics or "")
                if state.error_messages["inst_dynamics_" .. i] then
                    reaper.ImGui_TextColored(ctx, 0xFF5555FF, 
                        state.error_messages["inst_dynamics_" .. i])
                end
                
                -- Variations
                reaper.ImGui_Text(ctx, 'Number of Variations')
                _, state.instrument_data[i].variations = reaper.ImGui_InputText(ctx, '##variations',
                    state.instrument_data[i].variations or "")
                if state.error_messages["inst_variations_" .. i] then
                    reaper.ImGui_TextColored(ctx, 0xFF5555FF, 
                        state.error_messages["inst_variations_" .. i])
                end
                
                reaper.ImGui_Spacing(ctx)
                reaper.ImGui_PopID(ctx)
            end
        end
        
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Generate Button
        if reaper.ImGui_Button(ctx, 'Generate Regions and MIDI', -1) then
            generateRegionsAndMIDI(state)
        end
        
        -- Success message
        if state.show_success then
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_TextColored(ctx, 0x55FF55FF, state.success_message)
        end
    end
    
    reaper.ImGui_End(ctx)
    return open
end

local function createUI()
    ctx = reaper.ImGui_CreateContext('Preset Generator')
    
    local state = {
        preset_name = "",
        num_instruments = "",
        instrument_data = {},
        error_messages = {},
        show_success = false,
        success_message = ""
    }
    
    local function loop()
        local open = drawUI(state)
        if open then
            reaper.defer(loop)
        else
            reaper.ImGui_DestroyContext(ctx)
        end
    end
    
    reaper.defer(loop)
end

-- Initialize random seed
math.randomseed(os.time())

-- Start the script
createUI()