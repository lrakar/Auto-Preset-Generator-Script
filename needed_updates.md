### **Update 1: Preset Management and Saving**

**Objective**: Implement a "Save Preset" feature with full preset management, allowing users to save, load, preview, and delete presets using JSON files. Enhance the **Presets** menu for a modern UI experience.

**Features**:

1. **Save Preset Button**:
   - Add a new button named **"Save Preset"** below the "Generate Regions and MIDI" button, styled to match the modern UI.
   - When clicked, it saves all current settings to a JSON file, including:
     - **Preset Name**
     - **Number of Instruments**
     - For each instrument: **Name, Note, Region Length, Number of Dynamic Layers, Number of Variations**, and any future-added fields.
   - The JSON file should be saved in a designated presets directory, and if the directory doesn’t exist, create it automatically.

2. **Loading and Managing Presets in the Menu**:
   - In the **Presets** dropdown in the menu bar:
     - Display all saved presets as a list, with each preset showing a small red **X** on the right for deletion.
     - **Deletion Confirmation**:
       - When a user clicks the **X**, show a confirmation dialog with options **Yes** and **Cancel**.
       - **Yes** (default option) deletes the preset file from storage permanently; **Cancel** closes the dialog.
   - **Preset Preview on Hover**:
     - When the user hovers over a preset in the dropdown list, display a preview window on the right with the preset’s details:
       - **Preset Name, Number of Instruments, Dynamic Layers, Variations, Region Length**, etc.
     - Use a slight delay before showing the preview for a smoother user experience. The preview should disappear instantly when the mouse leaves the preset item.

3. **Loading a Preset**:
   - When the user selects a preset from the dropdown (by clicking on the preset name), load all saved settings into the program. This should overwrite the current settings with those from the selected preset.

4. **Data Storage and JSON Structure**:
   - Each preset should be saved in a separate JSON file within a preset directory (e.g., `presets/` folder).
   - Example JSON structure:
     ```json
     {
       "preset_name": "Rock",
       "number_of_instruments": 3,
       "instruments": [
         {
           "name": "Guitar",
           "note": "C4",
           "region_length": 1.5,
           "dynamic_layers": 5,
           "variations": 3
         },
         ...
       ]
     }
     ```

**Prompt**:
"Create an update for the Preset Generator program with a 'Save Preset' button that saves the current settings to a JSON file. Presets should be listed in the Presets dropdown in the menu, with a preview on hover and an 'X' button for deletion (showing a confirmation dialog). Clicking a preset name loads it into the program, replacing current settings. Ensure saved files are JSON, stored locally in a `presets/` directory. Design the UI to be modern, smooth, and consistent with existing elements."

---

### **Update 2: Rendering and Folder Management**

**Objective**: Implement rendering functionality to create `.wav` files for each region, saved in folders organized by preset names. Add folder management options to overwrite or create duplicate folders.

**Features**:

1. **Rendering Buttons**:
   - Add two new buttons styled consistently with the modern UI:
     - **Render Generated Regions**: Renders each generated region as a `.wav` file.
     - **Generate Regions, MIDI, and Render**: Generates regions and MIDI items first, then renders them.
   - These buttons should appear below the "Save Preset" button.

2. **Render Directory Management**:
   - When either render button is clicked:
     - Check if a **parent directory** has been set for renders (via **File > Presets Directory** in the menu).
     - If no directory is set, prompt the user to select a parent directory through a file explorer. Remember this directory for future renders, unless changed manually in **File > Presets Directory**.

3. **Folder Creation and Naming**:
   - Inside the parent directory, create a subfolder named after the **Preset Name**.
   - **Folder Conflict Handling**:
     - If a folder with the same name already exists:
       - Show a prompt with options **Overwrite** (default) and **Duplicate**.
       - **Overwrite** clears all files in the existing folder and replaces them with the new renders.
       - **Duplicate** creates a new folder with a sequential number (e.g., "PresetName (1)", "PresetName (2)", etc.).

4. **File Naming and Rendering**:
   - Render each region as a `.wav` file named after the **Region Name**, and store it in the preset folder.
   - Ensure each `.wav` file length matches the region length specified in the preset settings.

**Prompt**:
"Enhance the Preset Generator with rendering functionality. Add 'Render Generated Regions' and 'Generate Regions, MIDI, and Render' buttons. When clicked, these buttons should render `.wav` files for each generated region and save them in a folder named after the preset inside a parent directory. If a folder with the same name exists, offer options to overwrite (deletes all files inside) or create a duplicate (adds a sequential number to the folder name). Use a modern UI design, consistent with existing elements."

---

### **Update 3: Undo Functionality and Edit Menu Enhancements**

**Objective**: Add undo functionality with options for session-based undo and all-session undo, and allow customization of keyboard shortcuts.

**Features**:

1. **Undo Options in the Edit Menu**:
   - Add the following items to the **Edit** dropdown in the menu bar:
     - **Undo Generated Regions (Most Recent)**: Deletes all regions and MIDI items created in the most recent session only.
     - **Undo All Generated Regions (All Sessions)**: Deletes all regions and MIDI items with names matching the preset name, regardless of session.

2. **Customizable Keyboard Shortcuts**:
   - Enable customizable keyboard shortcuts for key actions (e.g., Save Preset, Undo, Render).
   - Under **Settings > Shortcut List**, display a list of current shortcuts with options to modify each one.
   - Changes to shortcuts should persist across sessions by saving them to the same JSON settings file.

**Prompt**:
"Add undo functionality to the Preset Generator. In the Edit menu, add 'Undo Generated Regions (Most Recent)' to delete regions from the most recent session and 'Undo All Generated Regions (All Sessions)' to delete all regions matching the preset name. Allow users to customize keyboard shortcuts for key actions (Save, Undo, Render). Include a 'Shortcut List' in Settings to view and modify shortcuts, with changes saved to a JSON file for persistence. Ensure UI and functionality match existing program style."

---

### **Update 4: Settings and Render Specifications**

**Objective**: Add a Render Settings window where users can specify rendering parameters. Render settings should be global and persist across sessions.

**Features**:

1. **Render Settings Window**:
   - In the **Settings** dropdown, add an item called **Render Settings** that opens a configuration window.
   - In the Render Settings window, provide the following options:
     - **Sample Rate**: Default to 44100 Hz, with a dropdown of other Reaper-supported options.
     - **Format**: Only `.wav` for now (default option).
     - **Bit Depth**: Dropdown with Reaper-supported bit depths.
     - **Resample Mode**: Dropdown with Reaper-supported interpolation modes.
     - **Channels**: Mono (default) or Stereo.

2. **Settings Persistence**:
   - Render settings should be saved as global settings in the JSON file and remembered across sessions.
   - When the user reopens the Render Settings window, previously selected options should be preloaded.

**Prompt**:
"Add a Render Settings configuration to the Preset Generator program. In the Settings menu, add 'Render Settings' to open a configuration window where users can set Sample Rate, Format (.wav only), Bit Depth, Resample Mode, and Channels (Mono or Stereo). These settings should be global, saved to a JSON file, and persist across sessions, with previously selected options reloading automatically. Ensure UI consistency with the rest of the program and use a modern, sleek design."