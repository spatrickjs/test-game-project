# Design

Presentation-only Feedback children reference their Button through an exported property. A canvas shader transforms the button drawing around its center and applies press and disabled shading. The child draws the selection outline and checkmark without intercepting input.

Feedback reads toggle state so set_pressed_no_signal updates remain visible. Inspector exports tune press scale, animation duration, selection color, and outline thickness.

The authored scene uses 80-pixel tool rectangles with 12-pixel gaps and unit scale. Godot serialization creates the scene changes. Existing gameplay selection and action handlers remain authoritative.

