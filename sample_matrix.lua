local SampleMatrix = {}

-- Constants
local AMPLITUDE_RANGE = 127
local MIN_DB = -60
local MAX_DB = 0
local GRID_COLS = 8
local CELL_SIZE = 100
local GRID_SPACING = 10

-- Audio analysis utilities
local function calculateRMSAmplitude(buffer)
    local sum = 0
    local count = #buffer
    for i = 1, count do
        sum = sum + (buffer[i] * buffer[i])
    end
    return math.sqrt(sum / count)
end

local function calculatePeakAmplitude(buffer)
    local peak = 0
    for i = 1, #buffer do
        peak = math.max(peak, math.abs(buffer[i]))
    end
    return peak
end

local function dbToLinear(db)
    if db <= MIN_DB then return 0 end
    return 10 ^ (db / 20)
end

local function linearToDb(linear)
    if linear <= 0 then return MIN_DB end
    return 20 * math.log10(linear)
end

local function dbToVelocity(db)
    -- Map dB range to velocity (0-127)
    -- MIN_DB (-60) maps to velocity 0
    -- MAX_DB (0) maps to velocity 127
    if db <= MIN_DB then return 0 end
    if db >= MAX_DB then return 127 end
    
    local normalized = (db - MIN_DB) / (MAX_DB - MIN_DB)
    return math.floor(normalized * 127 + 0.5)
end

local function velocityToDb(velocity)
    -- Convert velocity (0-127) to dB range
    local normalized = velocity / 127
    return MIN_DB + normalized * (MAX_DB - MIN_DB)
end

-- Sample object methods
local Sample = {}
function Sample:new(file_path, source)
    local sample = {
        path = file_path,
        name = file_path:match("([^/\\]+)$"),
        source = source,
        buffer = nil,
        amplitude = 0,
        waveform = nil,
        column = nil,
        layer = nil,
        is_playing = false
    }
    setmetatable(sample, {__index = Sample})
    return sample
end

function Sample:analyze()
    if not self.source then return end
    
    -- Get audio properties
    local channels = reaper.GetMediaSourceNumChannels(self.source)
    local samplerate = reaper.GetMediaSourceSampleRate(self.source)
    local length = reaper.GetMediaSourceLength(self.source)
    
    -- Create analysis buffer
    local buffer_size = math.floor(samplerate * length)
    local buffer = reaper.new_array(buffer_size)
    
    -- Get audio data
    reaper.PCM_Source_GetSamples(self.source, buffer, buffer_size)
    
    -- Calculate amplitude metrics
    self.buffer = buffer
    self.peak_amplitude = calculatePeakAmplitude(buffer)
    self.rms_amplitude = calculateRMSAmplitude(buffer)
    
    -- Store dB values
    self.peak_db = linearToDb(self.peak_amplitude)
    self.rms_db = linearToDb(self.rms_amplitude)
    
    -- Calculate velocity-like amplitude (0-127)
    self.amplitude = dbToVelocity(self.peak_db)
    
    -- Generate waveform visualization
    self.waveform = self:generateWaveform(buffer, 50)
end

function Sample:generateWaveform(buffer, points)
    local waveform = {}
    local step = math.floor(#buffer / points)
    
    for i = 1, points do
        local sum = 0
        local start = (i-1) * step + 1
        local finish = math.min(start + step - 1, #buffer)
        
        for j = start, finish do
            sum = sum + math.abs(buffer[j])
        end
        
        waveform[i] = sum / (finish - start + 1)
    end
    
    return waveform
end

function Sample:play()
    if self.is_playing then
        -- Stop if already playing
        reaper.StopPreviewSource(self.playback_preview)
        self.is_playing = false
        self.playback_preview = nil
        return
    end
    
    -- Start playback
    self.playback_preview = reaper.PlayPreview(self.source)
    self.is_playing = true
end

function Sample:getVolumeForDynamicLayer(current_layer, start_layer, end_layer)
    local volume = self:calculateDynamicVolume(current_layer, start_layer, end_layer)
    return volume.gain -- Return linear gain multiplier
end

function Sample:calculateDynamicVolume(current_layer, start_layer, end_layer)
    -- Calculate normalized position in dynamic range (0 to 1)
    local layer_range = end_layer - start_layer + 1
    local layer_position = current_layer - start_layer
    local normalized_position = layer_position / (layer_range - 1)
    
    -- Map to dB range (-12dB to 0dB for dynamics)
    local db_range = 12
    local target_db = -db_range + (db_range * normalized_position)
    
    -- Combine with sample's original peak
    local final_db = (self.peak_db or 0) + target_db
    
    -- Convert to gain multiplier
    return {
        db = final_db,
        gain = self:dbToGain(final_db),
        normalized = normalized_position
    }
end

function Sample:dbToGain(db)
    return math.pow(10, db / 20)
end

function Sample:calculateDynamicLayerVolume(dynamic_layer, start_layer, end_layer)
    -- Calculate normalized position in dynamic range
    local range = end_layer - start_layer + 1
    local position = dynamic_layer - start_layer
    local normalized = position / (range - 1)
    
    -- Map to dB range (-12dB to 0dB)
    local db_range = 12
    local target_db = -db_range + (db_range * normalized)
    
    -- Apply to sample's original peak
    return {
        db = self.peak_db + target_db,
        linear = dbToLinear(self.peak_db + target_db),
        normalized = normalized
    }
end

function Sample:getVolumeMultiplier(dynamic_layer, start_layer, end_layer)
    local volume = self:calculateDynamicLayerVolume(dynamic_layer, start_layer, end_layer)
    return volume.linear
end

-- SampleMatrix methods
function SampleMatrix:new()
    local matrix = {
        samples = {},      -- Store samples by position {col = {}, layers = {}}
        playback = {},     -- Track playback state
        grid = {           -- Grid configuration
            columns = GRID_COLS,
            cell_size = CELL_SIZE,
            spacing = GRID_SPACING
        }
    }
    setmetatable(matrix, {__index = self})
    return matrix
end

function SampleMatrix:addSample(file_path, target_col, target_layer)
    -- Create audio source
    local source = reaper.PCM_Source_CreateFromFile(file_path)
    if not source then return nil end
    
    -- Create and analyze sample
    local sample = Sample:new(file_path, source)
    sample:analyze()
    
    -- Position sample
    target_col = target_col or self:findBestColumn(sample.amplitude)
    target_layer = target_layer or self:getNextLayer(target_col)
    
    -- Store sample
    if not self.samples[target_col] then
        self.samples[target_col] = {}
    end
    self.samples[target_col][target_layer] = sample
    sample.column = target_col
    sample.layer = target_layer
    
    return sample
end

function SampleMatrix:findBestColumn(amplitude)
    local col_width = AMPLITUDE_RANGE / self.grid.columns
    return math.min(math.floor(amplitude / col_width) + 1, self.grid.columns)
end

function SampleMatrix:getNextLayer(column)
    if not self.samples[column] then return 1 end
    
    local max_layer = 0
    for layer, _ in pairs(self.samples[column]) do
        max_layer = math.max(max_layer, layer)
    end
    return max_layer + 1
end

function SampleMatrix:moveSample(sample, new_col, new_layer)
    if not sample or not new_col then return false end
    
    -- Remove from current position
    if sample.column and sample.layer then
        if self.samples[sample.column] then
            self.samples[sample.column][sample.layer] = nil
        end
    end
    
    -- Add to new position
    new_layer = new_layer or self:getNextLayer(new_col)
    if not self.samples[new_col] then
        self.samples[new_col] = {}
    end
    self.samples[new_col][new_layer] = sample
    sample.column = new_col
    sample.layer = new_layer
    
    return true
end

function SampleMatrix:playColumn(column)
    if not self.samples[column] then return end
    
    -- Stop any current playback in this column
    self:stopColumn(column)
    
    -- Calculate combined amplitude
    local total_db = MIN_DB
    for _, sample in pairs(self.samples[column]) do
        local sample_db = linearToDb(sample.amplitude / AMPLITUDE_RANGE)
        total_db = 10 * math.log10(10^(total_db/10) + 10^(sample_db/10))
    end
    
    -- Start playback for all samples in column
    self.playback[column] = {}
    for _, sample in pairs(self.samples[column]) do
        local preview = reaper.PlayPreview(sample.source)
        table.insert(self.playback[column], preview)
    end
end

function SampleMatrix:stopColumn(column)
    if self.playback[column] then
        for _, preview in pairs(self.playback[column]) do
            reaper.StopPreviewSource(preview)
        end
        self.playback[column] = nil
    end
end

function SampleMatrix:stopAll()
    for col, _ in pairs(self.samples) do
        self:stopColumn(col)
    end
end

-- Bridge functions for Preset Generator integration
function SampleMatrix:findSampleByPath(file_path)
    for col, layers in pairs(self.samples) do
        for layer, sample in pairs(layers) do
            if sample.path == file_path then
                return sample
            end
        end
    end
    return nil
end

function SampleMatrix:getSampleInfo(sample)
    if not sample then return nil end
    return {
        path = sample.path,
        name = sample.name,
        amplitude = sample.amplitude,
        peak_db = sample.peak_db,
        rms_db = sample.rms_db,
        waveform = sample.waveform and table.concat(sample.waveform, ",") or nil
    }
end

function SampleMatrix:addSampleDirect(file_path)
    local source = reaper.PCM_Source_CreateFromFile(file_path)
    if not source then return nil end
    
    local sample = Sample:new(file_path, source)
    sample:analyze()
    return sample
end

-- New utility function to get volume scaling for dynamic layers
function SampleMatrix:getVolumeForLayer(sample, current_layer, start_layer, end_layer)
    if not sample then return 1.0 end
    return sample:getVolumeForDynamicLayer(current_layer, start_layer, end_layer)
end

-- UI Drawing
function SampleMatrix:draw(ctx, COLORS)
    if not ctx then return end
    
    -- Window styling
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 16, 16)
    
    local window_flags = reaper.ImGui_WindowFlags_NoCollapse()
    local visible = reaper.ImGui_Begin(ctx, "Sample Matrix Builder", true, window_flags)
    
    if visible then
        -- Matrix grid
        reaper.ImGui_BeginChild(ctx, "matrix_grid", -1, -1, true)
        
        for col = 1, self.grid.columns do
            if col > 1 then
                reaper.ImGui_SameLine(ctx)
            end
            
            -- Draw column
            reaper.ImGui_BeginGroup(ctx)
            
            -- Column header with combined amplitude
            local total_db = self:getColumnDb(col)
            local header_color = COLORS.header
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), header_color)
            reaper.ImGui_Text(ctx, string.format("Column %d (%.1f dB)", col, total_db))
            reaper.ImGui_PopStyleColor(ctx)
            
            -- Draw samples in this column
            if self.samples[col] then
                for layer, sample in pairs(self.samples[col]) do
                    -- Sample box styling
                    local intensity = (sample.amplitude / AMPLITUDE_RANGE) * 255
                    local color = (intensity << 16) | (intensity << 8) | 0xFF
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), color)
                    
                    -- Sample button and waveform
                    if reaper.ImGui_Button(ctx, sample.name .. "##" .. col .. "_" .. layer, 
                                         self.grid.cell_size, self.grid.cell_size) then
                        sample:play()
                    end
                    
                    -- Show amplitude
                    reaper.ImGui_Text(ctx, string.format("Amp: %d", sample.amplitude))
                    
                    -- Draw waveform if available
                    if sample.waveform then
                        self:drawWaveform(ctx, sample.waveform, self.grid.cell_size, 40)
                    end
                    
                    -- Drag source
                    if reaper.ImGui_BeginDragDropSource(ctx) then
                        reaper.ImGui_SetDragDropPayload(ctx, "SAMPLE", sample)
                        reaper.ImGui_Text(ctx, "Moving: " .. sample.name)
                        reaper.ImGui_EndDragDropSource(ctx)
                    end
                    
                    reaper.ImGui_PopStyleColor(ctx)
                    reaper.ImGui_Spacing(ctx)
                end
            end
            
            -- Drop target
            reaper.ImGui_Button(ctx, "+##drop_" .. col, self.grid.cell_size, 40)
            if reaper.ImGui_BeginDragDropTarget(ctx) then
                -- Accept WAV files
                local payload = reaper.ImGui_AcceptDragDropPayload(ctx, "AUDIO_FILE")
                if payload then
                    self:addSample(payload, col)
                end
                
                -- Accept samples from other columns
                local sample = reaper.ImGui_AcceptDragDropPayload(ctx, "SAMPLE")
                if sample then
                    self:moveSample(sample, col)
                end
                
                reaper.ImGui_EndDragDropTarget(ctx)
            end
            
            -- Column playback button
            if reaper.ImGui_Button(ctx, "Play Column##" .. col, self.grid.cell_size, 30) then
                if self.playback[col] then
                    self:stopColumn(col)
                else
                    self:playColumn(col)
                end
            end
            
            reaper.ImGui_EndGroup(ctx)
        end
        
        reaper.ImGui_EndChild(ctx)
    end
    
    reaper.ImGui_End(ctx)
    reaper.ImGui_PopStyleVar(ctx)
end

function SampleMatrix:drawWaveform(ctx, waveform, width, height)
    if not waveform or #waveform == 0 then return end
    
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local pos_x, pos_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local points = {}
    
    -- Generate points for waveform
    for i = 1, #waveform do
        local x = pos_x + (i-1) * (width / (#waveform-1))
        local y = pos_y + height/2 + (waveform[i] * height/2)
        table.insert(points, {x = x, y = y})
    end
    
    -- Draw waveform lines
    for i = 1, #points-1 do
        reaper.ImGui_DrawList_AddLine(draw_list,
            points[i].x, points[i].y,
            points[i+1].x, points[i+1].y,
            0xFFFFFFFF, 1)
    end
end

function SampleMatrix:getColumnDb(column)
    if not self.samples[column] then return MIN_DB end
    
    local total_db = MIN_DB
    for _, sample in pairs(self.samples[column]) do
        local sample_db = linearToDb(sample.amplitude / AMPLITUDE_RANGE)
        total_db = 10 * math.log10(10^(total_db/10) + 10^(sample_db/10))
    end
    
    return total_db
end

return SampleMatrix