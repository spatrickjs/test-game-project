Feature: Hoe and Shovel tools
  The hoe converts empty grass into dry soil.
  The shovel removes crops (preserving terrain/soil) and destroys fences.

  Background:
    Given the field is initialized
    And the game is in the PLAYING state
    And the HUD shows Hoe and Shovel tool buttons

  # --- Hoe ---

  Scenario: Selecting and deselecting the hoe
    When the player presses the Hoe button
    Then the tool mode is TOOL_HOE
    And the selected crop label shows "Tool: Hoe"
    And eligible empty grass tiles are highlighted
    When the player presses the Hoe button again
    Then the tool mode is INSPECT
    And the selected crop label shows "Mode: Inspect"
    And no tiles are highlighted

  Scenario: Tilling empty grass
    Given the Hoe tool is selected
    And tile (6, 3) is empty grass
    When the player clicks tile (6, 3)
    Then a DIG_GRASS action is queued for (6, 3)
    And the tile terrain remains GRASS
    When the farmer arrives at the tile
    Then the tile terrain becomes DRY_SOIL
    And the tile soil is a copy of initial_soil
    And the grass tuft on the tile is removed
    And the action completes successfully

  Scenario: Dragging the hoe across grass
    Given the Hoe tool is selected
    When the player drags across empty grass and non-grass tiles
    Then a DIG_GRASS action is queued for each eligible empty grass tile
    And non-grass tiles in the drag path are skipped

  Scenario Outline: Hoe rejects ineligible targets
    Given the Hoe tool is selected
    And the target tile has <target_state>
    When the player clicks the target tile
    Then no action is queued
    And the error "<expected_error>" is reported

    Examples:
      | target_state     | expected_error           |
      | dry soil         | Hoe requires empty grass.|
      | paddy mud        | Hoe requires empty grass.|
      | a crop           | Hoe requires empty grass.|
      | a fence          | Hoe requires empty grass.|
      | outside field    | Out of bounds error      |

  Scenario: Tilled soil can become paddy
    Given tile (6, 3) was converted into DRY_SOIL by the Hoe
    When the player uses the Water Bucket on (6, 3)
    Then the tile terrain becomes PADDY_MUD

  # --- Shovel ---

  Scenario: Selecting and deselecting the shovel
    When the player presses the Shovel button
    Then the tool mode is TOOL_REMOVE
    And the selected crop label shows "Tool: Shovel"
    And tiles with crops or fences are highlighted
    When the player presses the Shovel button again
    Then the tool mode is INSPECT
    And no tiles are highlighted

  Scenario: Removing a crop with the shovel
    Given the Shovel tool is selected
    And tile (2, 3) has a crop
    When the player clicks tile (2, 3)
    Then a REMOVE_CROP action is queued for (2, 3)
    When the farmer arrives at the tile
    Then the crop is cleared
    And the tile terrain and soil are preserved
    And growth, vitality and disease state are reset

  Scenario: Removing a fence with the shovel
    Given the Shovel tool is selected
    And tile (6, 3) has a fence
    When the player clicks tile (6, 3)
    Then a REMOVE_FENCE action is queued for (6, 3)
    When the farmer arrives at the tile
    Then the fence is removed
    And the tile terrain is GRASS

  Scenario: Shovel drag and target rejection
    Given the Shovel tool is selected
    When the player drags across crops, fences, and empty grass
    Then REMOVE_CROP is queued for crops and REMOVE_FENCE is queued for fences
    And empty grass tiles are skipped
    When the player clicks empty grass tile (6, 3)
    Then no action is queued
    And the error "Choose a crop to remove." is reported

  # --- Shared Queue Invariants ---

  Scenario: Queued action invariants and lifecycle
    Given a tool action is queued for tile (6, 3)
    When the player queues another action on tile (6, 3)
    Then the action is rejected with "This plot already has a queued action."
    And the Next Turn button is disabled
    When the tile state changes before arrival and the farmer arrives
    Then the action is cancelled with a stale-action error and tile remains unmodified