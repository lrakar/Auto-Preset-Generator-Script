-- Add helper function for color conversion
local function HSVToRGB(_, _, intensity)
    -- Scale RGB components from black (0,0,0) to target color (0x69,0xDB,0xFF)
    local r = math.floor(0x69 * intensity)
    local g = math.floor(0xDB * intensity)
    local b = math.floor(0xFF * intensity)
    return reaper.ImGui_ColorConvertDouble4ToU32(r/255, g/255, b/255, 1)
end

function showMatrixView(ctx, state, COLORS)
    if not state.show_matrix then return end

    -- Apply modern styling
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), COLORS.background)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), COLORS.text_primary)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 16, 16)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 6.0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6.0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_CellPadding(), 8, 6)

    local window_flags = reaper.ImGui_WindowFlags_NoCollapse()
    reaper.ImGui_SetNextWindowSize(ctx, 800, 600, reaper.ImGui_Cond_FirstUseEver())
    local openVar = true
    local visible, open = reaper.ImGui_Begin(ctx, "Matrix View##popup", openVar, window_flags)
    if not visible or not open then
        reaper.ImGui_End(ctx)
        reaper.ImGui_PopStyleVar(ctx, 4)
        reaper.ImGui_PopStyleColor(ctx, 2)
        if not open then
            state.show_matrix = false
        end
        return
    end

    -- Iterate through instruments
    for inst_idx, inst in ipairs(state.instrument_data) do
        -- Header styling for instruments
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), COLORS.collapsable_header)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), COLORS.collapsable_header_hover)
        
        local header_label = (inst.name and inst.name ~= "") 
            and (inst.name .. "##inst_" .. inst_idx) 
            or ("Instrument " .. inst_idx .. "##inst_" .. inst_idx)
        
        if reaper.ImGui_CollapsingHeader(ctx, header_label) then
            reaper.ImGui_PopStyleColor(ctx, 2)
            
            local dynamics = tonumber(inst.dynamics) or 0
            local variations = tonumber(inst.variations) or 0
            
            -- Basic info table with modern styling
            if reaper.ImGui_BeginTable(ctx, "info_" .. inst_idx, 3, 
                reaper.ImGui_TableFlags_Borders() | 
                reaper.ImGui_TableFlags_BordersH() | 
                reaper.ImGui_TableFlags_BordersV()) then

                reaper.ImGui_TableSetupColumn(ctx, "Property")
                reaper.ImGui_TableSetupColumn(ctx, "Value")
                reaper.ImGui_TableSetupColumn(ctx, "Details")
                reaper.ImGui_TableHeadersRow(ctx)
                
                -- Region Length row
                reaper.ImGui_TableNextRow(ctx)
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_Text(ctx, "Region Length")
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_Text(ctx, (inst.length or "0") .. " seconds")
                
                -- Total Regions row
                reaper.ImGui_TableNextRow(ctx)
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_Text(ctx, "Total Regions")
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_Text(ctx, tostring(dynamics * variations))
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_Text(ctx, string.format("(%d dynamics × %d variations)", dynamics, variations))

                reaper.ImGui_EndTable(ctx)
            end
            
            reaper.ImGui_Spacing(ctx)
            
            -- Sound Layers Matrix with consistent left padding
            if #inst.sound_layers > 0 and dynamics > 0 then
                local table_flags = reaper.ImGui_TableFlags_BordersInnerH()  -- Only horizontal separators

                -- Use same cell padding as info table (8,6)
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_CellPadding(), 8, 6)

                if reaper.ImGui_BeginTable(ctx, "layers_" .. inst_idx, dynamics + 2, table_flags) then
                    -- Setup columns: Layer and Note with fixed widths; dynamic columns without WidthStretch
                    reaper.ImGui_TableSetupColumn(ctx, "Layer", reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoResize(), 100)
                    reaper.ImGui_TableSetupColumn(ctx, "Note", reaper.ImGui_TableColumnFlags_WidthFixed() | reaper.ImGui_TableColumnFlags_NoResize(), 60)
                    for d = 1, dynamics do
                        local column_flags = reaper.ImGui_TableColumnFlags_NoSort() | reaper.ImGui_TableColumnFlags_NoResize()
                        reaper.ImGui_TableSetupColumn(ctx, string.format("D%d", d), column_flags)
                    end
                    
                    -- Draw headers with built-in styling (now headers, including D1, D2, etc., appear centered)
                    reaper.ImGui_TableHeadersRow(ctx)

                    -- Draw each sound layer
                    for layer_idx, layer in ipairs(inst.sound_layers) do
                        reaper.ImGui_TableNextRow(ctx)
                        
                        -- Layer name
                        reaper.ImGui_TableNextColumn(ctx)
                        reaper.ImGui_Text(ctx, layer.name or "Layer " .. layer_idx)
                        
                        -- Note
                        reaper.ImGui_TableNextColumn(ctx)
                        reaper.ImGui_Text(ctx, layer.note or "-")
                        
                        -- Dynamic cells
                        for d = 1, dynamics do
                            reaper.ImGui_TableNextColumn(ctx)
                            
                            if d >= (layer.start_layer or 1) and d <= (layer.end_layer or dynamics) then
                                local velocity_min = layer.velocity_min or 0
                                local velocity_max = layer.velocity_max or 127
                                local start_layer = layer.start_layer or 1
                                local end_layer = layer.end_layer or dynamics
                                local velocity = velocity_min
                                if end_layer > start_layer then
                                    velocity = velocity_min + ((d - start_layer) / (end_layer - start_layer) * (velocity_max - velocity_min))
                                end
                                velocity = math.floor(velocity)
                                
                                -- Color based on velocity
                                local intensity = velocity / 127
                                local cellBgColor = HSVToRGB(0.6, 0.7, intensity)
                                
                                -- Get cell dimensions
                                local cell_min_x, cell_min_y = reaper.ImGui_GetCursorScreenPos(ctx)
                                local cell_width = reaper.ImGui_GetContentRegionAvail(ctx)
                                local cell_height = reaper.ImGui_GetFrameHeight(ctx)
                                local text = tostring(velocity)
                                local text_width = reaper.ImGui_CalcTextSize(ctx, text)
                                
                                -- Draw rounded rectangle background
                                local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
                                reaper.ImGui_DrawList_AddRectFilled(
                                    draw_list,
                                    cell_min_x + 1, cell_min_y + 1,  -- +1 for margin
                                    cell_min_x + cell_width - 1, cell_min_y + cell_height - 1,  -- -1 for margin
                                    cellBgColor,
                                    4.0  -- corner radius
                                )
                                
                                -- Center and draw text
                                local text_x = cell_min_x + (cell_width - text_width) * 0.5
                                local text_y = cell_min_y + (cell_height - reaper.ImGui_GetTextLineHeight(ctx)) * 0.5
                                local text_color = intensity > 0.6 and 0x000000FF or 0xFFFFFFFF
                                reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, text)
                                
                                -- Dummy item to maintain layout
                                reaper.ImGui_Dummy(ctx, cell_width, cell_height)
                            else
                                -- Empty cell instead of "-"
                                reaper.ImGui_Dummy(ctx, 1, reaper.ImGui_GetFrameHeight(ctx))
                            end
                        end
                    end
                    
                    reaper.ImGui_EndTable(ctx)
                end
                
                reaper.ImGui_PopStyleVar(ctx, 1)  -- Pop the cell padding
                
                if variations > 1 then
                    reaper.ImGui_Spacing(ctx)
                    reaper.ImGui_TextColored(ctx, COLORS.text_secondary, 
                        string.format("Each dynamic will be recorded %d times for variations", variations))
                end
            end
            
            reaper.ImGui_Spacing(ctx)
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Spacing(ctx)
        else
            reaper.ImGui_PopStyleColor(ctx, 2)
        end
    end
    
    reaper.ImGui_End(ctx)
    reaper.ImGui_PopStyleVar(ctx, 4)
    reaper.ImGui_PopStyleColor(ctx, 2)
end

return {
    showMatrixView = showMatrixView
}
