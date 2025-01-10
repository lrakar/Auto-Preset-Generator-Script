Program Overview
A custom audio sample extraction and preparation tool for REAPER that automates the creation of MIDI items, regions, for rendering each sample midi to wav.

Purpose
Extract audio samples from samplers
Generate MIDI items and regions with consistent naming prepared for rendering.

Key Features
MIDI Item Generation: Creates MIDI items for each note, velocity, and variation.
Region Management: Automatically creates and names regions for rendered samples.
Customizable Dynamics: Supports multiple velocity layers and variations.
Accurate Note Parsing: Converts notes (e.g., C4, F#3) into MIDI notes.
Real-Time Track Naming: Updates track names dynamically during input.
Error Validation: Ensures valid inputs for dynamics, variations, and notes.
JSON Preset Management:
Save and load sampling presets.
Preview preset details on hover.
Delete presets with confirmation.
Standardized Outputs: Produces files consistently named for easy integration.
Efficient Workflow: Automates repetitive tasks, saving time.
Use Cases
Prepare audio samples for your custom sampler.
Render dynamic and variation layers for instruments quickly.
Build standardized sample libraries for consistent use in music production.


Each instrument dropdown menu contains:

Name (Input Field): Sets the instrument name.
Region Length: Sets the maximum length for sound layers.
Dynamic Layers: Defines the total number of dynamic layers.
Number of Variations: Specifies the number of variations.
Add New Sound (Button): Creates a nested dropdown for a new sound layer.
Each sound layer dropdown contains:

Note: Input field for the MIDI note.
Velocity Range: Two sliders for start and stop velocity.
Dynamic Layer Range: Sliders for start generating at and stop generating at.
Delete Sound Layer (Button): Removes the sound layer.
Behavioral Requirements:

Each instrument generates one parent track for grouping/mixing.
Each sound layer generates its own nested track under the parent track.
MIDI is generated for each sound layer based on:
Velocity range defined by the sound layer.
Dynamic layer range defined by the sound layer.
Variations are generated within the valid dynamic layer range.
Parent tracks are used only for grouping and mixing.
Naming Rules:

Parent tracks take the name of the instrument.
Sound layer tracks take the name of the sound layer.