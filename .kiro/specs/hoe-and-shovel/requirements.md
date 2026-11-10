# Requirements — Hoe and Shovel Tools

## 1. Tool Selection & HUD

* **REQ-TOOL-001 (Hoe Mode):** Pressing Hoe toggles between `TOOL_HOE` and `INSPECT`. Active HUD label reads `Tool: Hoe`. Highlight empty grass tiles only.
* **REQ-TOOL-002 (Shovel Mode):** Pressing Shovel toggles between `TOOL_REMOVE` and `INSPECT`. Active HUD label reads `Tool: Shovel`. Highlight crop and fence tiles only.
* **REQ-TOOL-003 (UI Invariants):** Only the selected tool button shows as pressed. Tools are disabled outside `PLAYING` state.

## 2. Hoe Rules (`DIG_GRASS`)

* **REQ-HOE-001 (Eligibility):** Accepts only in-bounds tiles with terrain `GRASS`, no crop, and no fence.
* **REQ-HOE-002 (Execution & Mutation):** On farmer arrival at a valid target, terrain becomes `DRY_SOIL`, soil is set to a independent copy of `initial_soil`, and grass visual is removed.
* **REQ-HOE-003 (Rejection):** Direct clicks on any ineligible in-bounds target (dry soil, mud, crop, fence) report `Hoe requires empty grass.` Out-of-bounds reports standard out-of-bounds error.
* **REQ-HOE-004 (Water Bucket):** Tilled `DRY_SOIL` remains compatible with Water Bucket to convert to `PADDY_MUD`.

## 3. Shovel Rules (`REMOVE_CROP` / `REMOVE_FENCE`)

* **REQ-SHOVEL-001 (Eligibility):** Accepts tiles containing a crop (`REMOVE_CROP`) or a fence (`REMOVE_FENCE`). Does **not** dig grass.
* **REQ-SHOVEL-002 (Crop Removal Commit):** On farmer arrival, clears crop and resets growth, vitality, and disease fields on `FieldCellState`. Terrain and soil are preserved.
* **REQ-SHOVEL-003 (Fence Removal Commit):** On farmer arrival, clears fence from tile.
* **REQ-SHOVEL-004 (Rejection):** Direct clicks on tiles lacking both crops and fences report `Choose a crop to remove.`

## 4. Shared Queue & Drag Semantics

* **REQ-QUEUE-001 (Plot Reservation):** Enqueued actions reserve the target plot. Duplicate action attempts report `This plot already has a queued action.`
* **REQ-QUEUE-002 (Turn Blocking):** Non-empty queue disables Next Turn button and blocks `advance_turn`.
* **REQ-QUEUE-003 (Arrival Commit & Stale Cancellation):** Mutations occur strictly on farmer arrival. If tile state changed invalidating preconditions during movement, the action is cancelled with standard stale reporting.
* **REQ-QUEUE-004 (Per-Tile Drag Evaluation):** Drags evaluate eligibility independently per tile based on active tool. Ineligible tiles in drag path are skipped without error. Tool switching clears active drag.