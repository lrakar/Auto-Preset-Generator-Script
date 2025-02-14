-- Enhanced Preset Generator Script for REAPER with Modern UI

-- Initial declarations
local ctx = nil
-- Get the script path and require JSON module from the same directory
local script_path = debug.getinfo(1, "S").source:match([[^@?(.*[\/])[^\/]-$]])
package.path = package.path .. ";" .. script_path .. "?.lua"
local JSON = require("json")
local MatrixView = require("matrix_view")
local Settings = require("settings")

-- Modern UI Color Scheme
local COLORS = {
    text_primary = 0xEAEAEAFF,
    text_secondary = 0xA0A0A0FF,
    background = 0x111216FF,  -- Changed from 0x1E1E1EFF to 0x111216FF
    background_light = 0x2D2D2DFF,
    
    accent = 0x1F6FEBFF,
    accent_hover = 0x60A3D6FF,
    error = 0xFF5555FF,
    success = 0x4BB543FF,
    header = 0x3D5A80FF,
    separator = 0x383838FF,
    
    -- Add the two container background colors
    instrument_container_bg = 0x24252DFF,  -- Parent collapsible header background
    sound_layer_container_bg = 0x363742FF,  -- Child collapsible header background
    
    collapsable_header = 0x596B78FF,         -- Added new color
    collapsable_header_hover = 0x73828CFF    -- Added new color
}

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
        
        -- Presets Menu (left side)
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
                        
                        -- Position tooltip near the mouse
                        local mouseX, mouseY = reaper.ImGui_GetMousePos(ctx)
                        reaper.ImGui_SetNextWindowPos(ctx, mouseX + 12, mouseY + 12)


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
        
        -- Settings Icon (right side)
        local windowWidth = reaper.ImGui_GetWindowContentRegionMax(ctx)
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetCursorPosX(ctx, windowWidth - 30) -- Position from right edge
        
        -- Load settings icon texture if not already loaded
        if not state.settings_texture then
            local script_path = debug.getinfo(1, "S").source:match([[^@?(.*[\/])[^\/]-$]])
            local icon_path = script_path .. "media/settings_icon.png"
            state.settings_texture = reaper.ImGui_CreateImage(icon_path)
        end
        
        -- Draw settings icon as a button
        if state.settings_texture then
            if reaper.ImGui_ImageButton(ctx, "Settings", state.settings_texture, 20, 20) then
                state.show_settings = not state.show_settings
            end
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
    noteStr = noteStr:upper()
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

local function createNewSoundLayer(instrument)
    local layer_count = #instrument.sound_layers + 1
    local default_name = string.format("Sound Layer %d", layer_count)
    return {
        name = default_name,
        temp_name = default_name,
        note = "",
        plugin = "Kontakt 7",
        velocity_min = 0,
        velocity_max = 127,
        start_layer = 1,
        end_layer = max_dynamics or 1,
        track_index = nil,
        is_open = false
    }
end



local function createNewInstrument()
    return {
        name = "",
        note = "",
        length = "1.5",
        dynamics = "",
        variations = "",
        range_min = 0,
        range_max = 127,
        parent_track_index = nil,
        child_track_indices = {},
        sound_layers = {},   
        temp_name = ""
    }
end



local function rgb2num(r, g, b)
    -- Convert RGB to RGBA hex format (alpha FF)
    return (r << 0) | (g << 8) | (b << 16) | (0xFF << 24)
end

local function generateRandomColor()
    local r = math.random(50, 255)
    local g = math.random(50, 255)
    local b = math.random(50, 255)
    return rgb2num(r, g, b)  -- Will return format like 0x0095C5FF
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

        -- Validate each sound layer
        for j, layer in ipairs(inst.sound_layers) do
            if layer.note == "" then
                state.error_messages["layer_note_" .. i .. "_" .. j] = "Note cannot be empty"
                valid = false
            else
                local midiNote = parseNote(layer.note)
                if not midiNote then
                    state.error_messages["layer_note_" .. i .. "_" .. j] = "Invalid note. Please enter a note between C0 and C9"
                    valid = false
                end
            end

            -- Validate layer ranges
            if layer.start_layer > layer.end_layer then
                state.error_messages["layer_range_" .. i .. "_" .. j] = "Start layer cannot be greater than end layer"
                valid = false
            end
        end
    end
    
    return valid
end

-- MIDI and Region generation function (kept the same as it works correctly)
local function generateRegionsAndMIDI(state)
    if not validateInputs(state) then return end

    local trackCountAtStart = reaper.CountTracks(0)
    
    reaper.Undo_BeginBlock()
    local cursor_pos = reaper.GetCursorPosition()
    local current_pos = cursor_pos
    local total_items = 0
    
    for i = 1, #state.instrument_data do
        local inst = state.instrument_data[i]
        
        -- Generate one color per instrument ONCE at the start
        local instrumentColor = generateRandomColor()
        
        -- Create parent track with the instrument color
        local parentIndex = reaper.CountTracks(0)
        reaper.InsertTrackAtIndex(parentIndex, true)
        local parentTrack = reaper.GetTrack(0, parentIndex)
        
        reaper.SetMediaTrackInfo_Value(parentTrack, "I_FOLDERDEPTH", 1)
        reaper.SetMediaTrackInfo_Value(parentTrack, "D_VOL", 1.0)
        reaper.GetSetMediaTrackInfo_String(parentTrack, "P_NAME", inst.name, true)
        reaper.SetTrackColor(parentTrack, instrumentColor)  -- Set color
        inst.parent_track_index = parentIndex

        -- Create layer tracks with the same color
        local layer_tracks = {}
        for layer_idx, layer in ipairs(inst.sound_layers) do
            local layerIndex = reaper.CountTracks(0)
            reaper.InsertTrackAtIndex(layerIndex, true)
            local layerTrack = reaper.GetTrack(0, layerIndex)
            
            reaper.SetMediaTrackInfo_Value(layerTrack, "I_FOLDERDEPTH", 0)
            reaper.GetSetMediaTrackInfo_String(layerTrack, "P_NAME", 
                string.format("%s_%s", inst.name, layer.name), true)
            reaper.SetTrackColor(layerTrack, instrumentColor)  -- Set same color
            
            -- Add plugin to track
            if layer.plugin and layer.plugin ~= "" then
                local fx_index = reaper.TrackFX_AddByName(layerTrack, layer.plugin, false, -1)
                if fx_index >= 0 then
                    -- Plugin added successfully
                    reaper.TrackFX_Show(layerTrack, fx_index, 3) -- Show the plugin window
                end
            end
            
            layer.track_index = layerIndex
            layer_tracks[layer_idx] = layerTrack
        end

        -- Now generate MIDI content
        local region_length = toFloat(inst.length)
        local num_variations = tonumber(inst.variations)

        -- Iterate through dynamics and variations first
        for d = 1, tonumber(inst.dynamics) do
            for v = 1, num_variations do
                -- Process all sound layers for this dynamic/variation combination
                local region_created = false  -- Track if region has been created for this d/v combo
                for layer_idx, layer in ipairs(inst.sound_layers) do
                    -- Check if this dynamic layer is within the layer's range
                    if d >= layer.start_layer and d <= layer.end_layer then
                        local noteNum = parseNote(layer.note)
                        if noteNum then
                            -- Calculate velocity
                            local velocity
                            if layer.end_layer > layer.start_layer then
                                local fraction = (d - layer.start_layer) / (layer.end_layer - layer.start_layer)
                                velocity = math.floor(
                                    layer.velocity_min + (fraction * (layer.velocity_max - layer.velocity_min))
                                )
                            else
                                velocity = layer.velocity_min
                            end
                            velocity = math.max(1, math.min(127, velocity))

                            -- Create MIDI item with forced initialization
                            local item = reaper.CreateNewMIDIItemInProj(layer_tracks[layer_idx], 
                                current_pos, current_pos + region_length)
                            
                            -- Initialize take
                            local take = reaper.GetActiveTake(item)
                            
                            -- Create empty MIDI event to initialize take
                            reaper.MIDI_InsertNote(take,
                                false,    -- selected
                                false,    -- muted
                                0,        -- startppqpos
                                1,        -- endppqpos
                                1,        -- chan
                                0,        -- pitch
                                0)        -- vel
                                
                            -- Delete the empty note
                            reaper.MIDI_DeleteNote(take, 0)
                            
                            -- Now insert our actual note
                            reaper.MIDI_InsertNote(take, 
                                false,    -- selected
                                false,    -- muted
                                0,        -- startppqpos
                                math.floor((region_length * 960) / 16), -- endppqpos (sixteenth note length)
                                1,        -- channel
                                noteNum,  -- pitch
                                velocity, -- velocity
                                false)    -- noSortIn
                            
                            reaper.MIDI_Sort(take)
                            
                            -- Create region marker if not yet created for this d/v combination
                            if not region_created then
                                local region_name = string.format("%s_%d_%d",
                                    inst.name, d, v)
                                reaper.AddProjectMarker2(0, true, current_pos, 
                                    current_pos + region_length, region_name, 
                                    -1, instrumentColor)  -- Use instrument color instead of generating new one
                                region_created = true
                            end
                            
                            total_items = total_items + 1
                        end
                    end
                end
                -- Only advance position after processing all layers for this dynamic/variation
                current_pos = current_pos + region_length
            end
        end
        
        -- Close the folder
        local lastTrack = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
        if lastTrack then
            reaper.SetMediaTrackInfo_Value(lastTrack, "I_FOLDERDEPTH", -1)
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
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 0x4F4F4FFF)  -- Changed input field background color
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), 0x4F4F4FFF + 0x111111FF)
end

local function endStyleInput(ctx)
    reaper.ImGui_PopStyleColor(ctx, 2)  -- Fixed: Added ctx parameter
    reaper.ImGui_PopStyleVar(ctx, 2)    -- Fixed: Added ctx parameter
end

local function drawSoundLayer(ctx, instrument, layer, layer_idx, state, inst_idx)
    reaper.ImGui_PushID(ctx, string.format("sound_layer_%d_%d", inst_idx, layer_idx))
    
    -- Ensure layer has a proper name
    if not layer.name or layer.name == "" then
        layer.name = string.format("Sound Layer %d", layer_idx)
    end
    if not layer.temp_name then
        layer.temp_name = layer.name
    end

    -- Get available width and calculate margins
    local contentWidth = reaper.ImGui_GetContentRegionAvail(ctx)
    local margin = 10  -- Margin size

    -- Add left margin
    reaper.ImGui_Indent(ctx, margin)
    
    -- Header styling
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 12, 6)  -- Reduced vertical padding
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6.0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), COLORS.collapsable_header)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), COLORS.collapsable_header_hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), COLORS.header + 0x222222FF)

    -- Create dummy for width control
    reaper.ImGui_BeginGroup(ctx)
    local is_open = reaper.ImGui_CollapsingHeader(ctx, layer.name)
    reaper.ImGui_EndGroup(ctx)
    

    layer.is_open = is_open

    -- Restore header styles
    reaper.ImGui_PopStyleColor(ctx, 3)
    reaper.ImGui_PopStyleVar(ctx, 2)

    if is_open then
        -- Content container styling
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 6.0)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), COLORS.sound_layer_container_bg)  -- Changed background color
        
        if reaper.ImGui_BeginChild(ctx, "layer_content" .. layer_idx, -margin, 365) then
            -- Add top padding
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Indent(ctx, margin)
            -- Add right padding to match left
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 10, 0)

            -- Name Input
            styleInput(ctx)
            reaper.ImGui_Text(ctx, "Sound Layer Name")
            local pressedEnter, new_name = reaper.ImGui_InputText(ctx, 
                string.format("##name_%d_%d", inst_idx, layer_idx), 
                layer.temp_name or layer.name, 
                reaper.ImGui_InputTextFlags_EnterReturnsTrue())
            
            if pressedEnter then
                layer.name = new_name
                layer.temp_name = new_name
            end
            endStyleInput(ctx)
            reaper.ImGui_Spacing(ctx)

            -- Note Input with Play Button
            styleInput(ctx)
            reaper.ImGui_Text(ctx, "Note (e.g., C4, F#3)")
            reaper.ImGui_PushItemWidth(ctx, 60)  -- Changed back to 60px width
            _, layer.note = reaper.ImGui_InputText(ctx, 
                string.format("##note_%d_%d", inst_idx, layer_idx), 
                layer.note or "")
            reaper.ImGui_PopItemWidth(ctx)

            -- Play Button
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.accent)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.accent_hover)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 4, 2)  -- Add back padding
            if reaper.ImGui_Button(ctx, string.format("Play##%d_%d", inst_idx, layer_idx), 70, 22) then
                if parseNote(layer.note) then
                    playMIDINote(layer.note, 0.5)
                end
            end
            reaper.ImGui_PopStyleColor(ctx, 2)
            reaper.ImGui_PopStyleVar(ctx)
            endStyleInput(ctx)
            reaper.ImGui_Spacing(ctx)

            -- Plugin Input
            styleInput(ctx)
            reaper.ImGui_Text(ctx, "Plugin")
            _, layer.plugin = reaper.ImGui_InputText(ctx, 
                string.format("##plugin_%d_%d", inst_idx, layer_idx), 
                layer.plugin or "Kontakt 7")
            endStyleInput(ctx)
            reaper.ImGui_Spacing(ctx)

            -- Sliders styling
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(), 6.0)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), COLORS.accent)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), COLORS.accent_hover)

            -- Velocity Range Slider
            styleInput(ctx)
            reaper.ImGui_Text(ctx, "Velocity Range")
            _, layer.velocity_min, layer.velocity_max = reaper.ImGui_SliderInt2(ctx, 
                string.format("##velocity_%d_%d", inst_idx, layer_idx),
                layer.velocity_min or 0,
                layer.velocity_max or 127,
                0, 127, "%d")
            endStyleInput(ctx)
            reaper.ImGui_Spacing(ctx)

            -- Dynamic Layer Range Slider
            local max_dynamics = tonumber(instrument.dynamics) or 1
            styleInput(ctx)
            reaper.ImGui_Text(ctx, "Dynamic Layer Range")
            _, layer.start_layer, layer.end_layer = reaper.ImGui_SliderInt2(ctx, 
                string.format("##dynamics_%d_%d", inst_idx, layer_idx),
                layer.start_layer or 1,
                layer.end_layer or max_dynamics,
                1, max_dynamics, "%d")
            endStyleInput(ctx)
            reaper.ImGui_Spacing(ctx)

            -- Restore slider styles
            reaper.ImGui_PopStyleColor(ctx, 2)
            reaper.ImGui_PopStyleVar(ctx)

            -- Delete Button with minimal padding
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6.0)
            reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 2, 4)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.error)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.error + 0x222222FF)
            if reaper.ImGui_Button(ctx, "Delete Sound Layer", 150, 22) then
                table.remove(instrument.sound_layers, layer_idx)
            end
            reaper.ImGui_PopStyleColor(ctx, 2)
            reaper.ImGui_PopStyleVar(ctx, 2)

            reaper.ImGui_Unindent(ctx, margin)
            reaper.ImGui_PopStyleVar(ctx)
            reaper.ImGui_EndChild(ctx)
        end
        
        reaper.ImGui_PopStyleColor(ctx)
        reaper.ImGui_PopStyleVar(ctx)
    end

    -- Remove the indent we added
    reaper.ImGui_Unindent(ctx, margin)

    reaper.ImGui_PopID(ctx)
end

local function drawInstrumentSection(ctx, state, index)
    local inst = state.instrument_data[index]

    -- Ensure initialization
    if not inst.temp_name or inst.temp_name == "" then
        inst.temp_name = inst.name
    end
    if not inst.sound_layers then
        inst.sound_layers = {}
    end    

    -- Create the header label
    local displayLabel = string.format(
        "%s##inst_%d",
        inst.temp_name ~= "" and inst.temp_name or string.format("Instrument %d", index),
        index
    )

    -- Header styling
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 12, 8)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6.0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), COLORS.collapsable_header)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), COLORS.collapsable_header_hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), COLORS.header + 0x222222FF)

    if state.keep_open_index == index then
        reaper.ImGui_SetNextItemOpen(ctx, true, reaper.ImGui_Cond_Once())
    end

    local is_open = reaper.ImGui_CollapsingHeader(ctx, displayLabel)
    state.open_sections[index] = is_open

    -- Restore header styles
    reaper.ImGui_PopStyleVar(ctx, 2)
    reaper.ImGui_PopStyleColor(ctx, 3)

    if is_open then
        reaper.ImGui_PushID(ctx, index)
        
        -- Container background
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 6.0)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), COLORS.instrument_container_bg)  -- Changed background color
        
        -- Add consistent padding on all sides
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 10, 10)
        
        -- Begin child with explicit height
        local contentHeight = 315 + (#inst.sound_layers * 36) -- Reduced multiplier for tighter spacing

        reaper.ImGui_Indent(ctx, 10)

        -- Name Input
        styleInput(ctx)
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Text(ctx, "Name")
        local inputFlags = reaper.ImGui_InputTextFlags_EnterReturnsTrue()
        local pressedEnter, new_temp_name = reaper.ImGui_InputText(ctx, "##temp_name", inst.temp_name, inputFlags)

        if pressedEnter then
            inst.name = new_temp_name
            inst.temp_name = new_temp_name
            if inst.parent_track_index then
                local parentTrack = reaper.GetTrack(0, inst.parent_track_index)
                if parentTrack then
                    reaper.GetSetMediaTrackInfo_String(parentTrack, "P_NAME", inst.name, true)
                end
            end
            state.keep_open_index = index
        elseif not reaper.ImGui_IsItemActive(ctx) then
            state.keep_open_index = nil
        end

        if state.error_messages["inst_name_" .. index] then
            reaper.ImGui_TextColored(ctx, COLORS.error, state.error_messages["inst_name_" .. index])
        end
        endStyleInput(ctx)
        reaper.ImGui_Spacing(ctx)

        -- Region Length
        styleInput(ctx)
        reaper.ImGui_Text(ctx, "Region Length (seconds)")
        _, inst.length = reaper.ImGui_InputText(ctx, "##length", inst.length)
        if state.error_messages["inst_length_" .. index] then
            reaper.ImGui_TextColored(ctx, COLORS.error, state.error_messages["inst_length_" .. index])
        end
        endStyleInput(ctx)
        reaper.ImGui_Spacing(ctx)

        -- Dynamic Layers
        styleInput(ctx)
        reaper.ImGui_Text(ctx, "Number of Dynamic Layers")
        _, inst.dynamics = reaper.ImGui_InputText(ctx, "##dynamics", inst.dynamics)
        if state.error_messages["inst_dynamics_" .. index] then
            reaper.ImGui_TextColored(ctx, COLORS.error, state.error_messages["inst_dynamics_" .. index])
        end
        endStyleInput(ctx)
        reaper.ImGui_Spacing(ctx)

        -- Variations
        styleInput(ctx)
        reaper.ImGui_Text(ctx, "Number of Variations")
        _, inst.variations = reaper.ImGui_InputText(ctx, "##variations", inst.variations)
        if state.error_messages["inst_variations_" .. index] then
            reaper.ImGui_TextColored(ctx, COLORS.error, state.error_messages["inst_variations_" .. index])
        end
        endStyleInput(ctx)
        reaper.ImGui_Spacing(ctx)

        -- Add New Sound Layer Button (moved up)
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6.0)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.accent)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.accent_hover)

        local contentWidth = reaper.ImGui_GetContentRegionAvail(ctx)
        local buttonWidth = contentWidth - 10  -- Subtract 10 to create 10px margin on each side
        if #inst.sound_layers == 0 then
            if reaper.ImGui_Button(ctx, "Add Sound Layer", buttonWidth, 30) then
                table.insert(inst.sound_layers, createNewSoundLayer(inst))
            end
        else
            -- Show regular "Add New Sound Layer" button if there are existing layers
            if reaper.ImGui_Button(ctx, "Add New Sound Layer", buttonWidth, 30) then
                table.insert(inst.sound_layers, createNewSoundLayer(inst))
            end
        end

        reaper.ImGui_PopStyleColor(ctx, 2)
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_Spacing(ctx)

        -- Draw Sound Layers
        for layer_idx, layer in ipairs(inst.sound_layers) do
            drawSoundLayer(ctx, inst, layer, layer_idx, state, index)
        end

        reaper.ImGui_Unindent(ctx, 10)
        
        reaper.ImGui_PopStyleVar(ctx, 2) -- Pop WindowPadding and ChildRounding
        reaper.ImGui_PopStyleColor(ctx)
        reaper.ImGui_PopID(ctx)
    end
end

local function drawSettingsWindow(ctx, state)
    if state.show_settings then
        local window_flags = reaper.ImGui_WindowFlags_NoCollapse()
        reaper.ImGui_SetNextWindowSize(ctx, 400, 600, reaper.ImGui_Cond_FirstUseEver())
        
        -- Store window open state
        local visible, open = reaper.ImGui_Begin(ctx, "Settings##window", true, window_flags)
        
        if visible then
            local settings_changed = false
            
            -- UI Settings
            reaper.ImGui_TextColored(ctx, COLORS.accent, "UI Settings")
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Spacing(ctx)
            
            -- Font size slider
            styleInput(ctx)
            reaper.ImGui_Text(ctx, "Font Size")
            local changed
            changed, state.settings.font_size = reaper.ImGui_SliderInt(ctx, "##font_size", 
                state.settings.font_size or Settings.get("font_size"), 8, 32, "%d px")
            if changed then settings_changed = true end
            endStyleInput(ctx)
            reaper.ImGui_Spacing(ctx)
            
            -- Default Values
            reaper.ImGui_TextColored(ctx, COLORS.accent, "Default Values")
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Spacing(ctx)
            
            -- Default plugin
            styleInput(ctx)
            reaper.ImGui_Text(ctx, "Default Plugin")
            changed, state.settings.default_plugin = reaper.ImGui_InputText(ctx, "##default_plugin", 
                state.settings.default_plugin or Settings.get("default_plugin"))
            if changed then settings_changed = true end
            endStyleInput(ctx)
            reaper.ImGui_Spacing(ctx)
            
            -- Default region length
            styleInput(ctx)
            reaper.ImGui_Text(ctx, "Default Region Length (seconds)")
            changed, state.settings.default_length = reaper.ImGui_InputText(ctx, "##default_length", 
                state.settings.default_length or Settings.get("default_length"))
            if changed then settings_changed = true end
            endStyleInput(ctx)
            reaper.ImGui_Spacing(ctx)
            
            -- Preview Settings
            reaper.ImGui_TextColored(ctx, COLORS.accent, "Preview Settings")
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Spacing(ctx)
            
            -- Preview velocity
            styleInput(ctx)
            reaper.ImGui_Text(ctx, "Preview Note Velocity")
            changed, state.settings.preview_velocity = reaper.ImGui_SliderInt(ctx, "##preview_velocity", 
                state.settings.preview_velocity or Settings.get("preview_velocity"), 1, 127, "%d")
            if changed then settings_changed = true end
            endStyleInput(ctx)
            reaper.ImGui_Spacing(ctx)
            
            -- Preview duration (using SliderDouble instead of SliderFloat)
            styleInput(ctx)
            reaper.ImGui_Text(ctx, "Preview Duration (seconds)")
            changed, state.settings.preview_duration = reaper.ImGui_SliderDouble(ctx, "##preview_duration", 
                state.settings.preview_duration or Settings.get("preview_duration"), 0.1, 2.0, "%.1f")
            if changed then settings_changed = true end
            endStyleInput(ctx)
            reaper.ImGui_Spacing(ctx)
            
            -- Save and Reset buttons
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Spacing(ctx)
            
            -- Save Button
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.accent)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.accent_hover)
            if reaper.ImGui_Button(ctx, "Save Settings", -1, 30) or settings_changed then
                -- Save all settings
                for key, value in pairs(state.settings) do
                    Settings.set(key, value)
                end
                state.show_message = true
                state.message = "Settings saved successfully"
                state.message_type = "success"
            end
            reaper.ImGui_PopStyleColor(ctx, 2)
        end
        
        -- Always end the window
        reaper.ImGui_End(ctx)
        
        -- Handle window close button
        if not open then
            state.show_settings = false
        end
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
    
    if not visible then
        reaper.ImGui_PopStyleVar(ctx, 2)
        reaper.ImGui_PopStyleColor(ctx, 2)
        reaper.ImGui_End(ctx)
        return false
    end

    -- Add Preset Menu and Delete Dialog
    drawPresetMenu(ctx, state, COLORS)
    drawDeleteConfirmDialog(ctx, state)
    
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
            table.insert(state.instrument_data, createNewInstrument())
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
    reaper.ImGui_Spacing(ctx)
    
    -- Instrument Sections
    if validateInteger(state.num_instruments) then
        for i = 1, #state.instrument_data do
            drawInstrumentSection(ctx, state, i)
        end
    end
    
    -- Generate and Save Buttons
    reaper.ImGui_Spacing(ctx)
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

    -- Matrix View Button
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), COLORS.accent)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), COLORS.accent_hover)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4.0)
    if reaper.ImGui_Button(ctx, "Show Matrix View", -1, 40) then
        state.show_matrix = not state.show_matrix
        -- Reset any lingering state when toggling
        if state.show_matrix then
            state.matrix_maximized = false
        end
    end
    reaper.ImGui_PopStyleVar(ctx)
    reaper.ImGui_PopStyleColor(ctx, 2)

    -- End main window
    reaper.ImGui_End(ctx)
    reaper.ImGui_PopStyleVar(ctx, 2)
    reaper.ImGui_PopStyleColor(ctx, 2)

    -- Show matrix view in a separate window if enabled
    if state.show_matrix then
        MatrixView.showMatrixView(ctx, state, COLORS)
    end

    -- Draw settings window if enabled
    if state.show_settings then
        drawSettingsWindow(ctx, state)
    end

    return open
end

local function createUI()
    ctx = reaper.ImGui_CreateContext('Preset Generator')
    
    -- Initialize settings first
    Settings.init()
    
    -- Font configuration
    local font_size = Settings.get("font_size")
    local font = reaper.ImGui_CreateFont('Calibri', font_size)
    reaper.ImGui_Attach(ctx, font)
    
    -- Initialize state
    local state = {
        -- Settings state
        settings_texture = nil,     -- Will hold the settings icon texture
        show_settings = false,      -- Controls settings window visibility
        settings = Settings.current, -- Use the settings module's current settings
        
        -- Basic preset data
        preset_name = "",
        num_instruments = "",
        instrument_data = {},
        
        -- UI state
        error_messages = {},
        show_success = false,
        success_message = "",
        open_sections = {},
        
        -- sound layer name editing
        keep_open_layer_index = nil,
        -- Font reference
        font = font,  -- THIS LINE WAS REFERENCING AN UNDEFINED font VARIABLE
        
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
        max_history = 50,            -- Maximum number of history states to keep
        show_matrix = false         -- Track if matrix view is open
    }
    
    -- Initialize default instrument if empty
    if #state.instrument_data == 0 then
        table.insert(state.instrument_data, createNewInstrument())
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
    if not ctx then return end
    
    -- Handle input and updates
    handleInput()
    
    -- Push font once at the start
    reaper.ImGui_PushFont(ctx, state.font)
    
    -- Draw main UI and get open state
    local open = drawUI(state)
    
    -- Pop font once at the end
    reaper.ImGui_PopFont(ctx)
    
    -- Continue loop if window is open
    if open then
        reaper.defer(loop)
    else
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