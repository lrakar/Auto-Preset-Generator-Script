-- Enhanced Preset Generator Script for REAPER with Modern UI
-- Creates regions and corresponding MIDI items with per-instrument settings

local ctx = nil

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
            local velocity = math.max(1, math.floor((d / num_dynamics) * 127))
            
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
    state.success_message = string.format("√ Successfully created %d regions and MIDI items", total_items)
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
    
    local window_flags = reaper.ImGui_WindowFlags_NoCollapse()
    local visible, open = reaper.ImGui_Begin(ctx, "Preset Generator", true, window_flags)
    
    if visible then
        reaper.ImGui_SetWindowSize(ctx, 450, 600, reaper.ImGui_Cond_FirstUseEver())
        
        -- Title
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLORS.accent)
        reaper.ImGui_Text(ctx, "PRESET GENERATOR")
        reaper.ImGui_PopStyleColor(ctx)  -- Fixed: Added ctx parameter
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
        
        -- Generate Button
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.accent)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.accent_hover)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4.0)
        if reaper.ImGui_Button(ctx, "Generate Regions and MIDI", -1, 40) then
            generateRegionsAndMIDI(state)
        end
        
        -- Pop the styles we pushed for the button
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_PopStyleColor(ctx, 2)
        
        -- Success Message
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
    
    -- Add font configuration
    local font_size = 14
    local font = reaper.ImGui_CreateFont('Calibri', font_size)
    reaper.ImGui_Attach(ctx, font)
    
    local state = {
        preset_name = "",
        num_instruments = "",
        instrument_data = {},
        error_messages = {},
        show_success = false,
        success_message = "",
        font = font,  -- Store font reference
        open_sections = {}  -- Track which sections are open
    }
    
    local function loop()
        reaper.ImGui_PushFont(ctx, state.font)  -- Push font at start of frame
        handleMIDIInput(state)  -- Handle MIDI input each frame
        local open = drawUI(state)
        reaper.ImGui_PopFont(ctx)  -- Pop font at end of frame
        
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