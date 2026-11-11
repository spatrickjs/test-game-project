Feature: Hoe and Shovel tools
  The hoe converts empty grass into dry soil.
  The shovel removes crops, preserving the underlying terrain and soil, and destroys fences.
  Fence removal is handled by the Shovel tool.

  Background:
    Given the field is initialized
    And the game is in the PLAYING state
    And the HUD shows Hoe and Shovel tool buttons

  # --- Hoe ---

  Scenario: Selecting the hoe
    When the player presses the Hoe button
    Then the tool mode is TOOL_HOE
    And the Hoe button is pressed
    And other tool buttons are not pressed
    And the selected crop label shows "Tool: Hoe"
    And eligible empty grass tiles are highlighted

  Scenario: Deselecting the hoe
    Given the Hoe tool is selected
    When the player presses the Hoe button again
    Then the tool mode is INSPECT
    And no tool button is pressed
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
    When the player drags across several empty grass tiles
    Then a DIG_GRASS action is queued for each eligible tile
    And non-grass tiles in the drag path are not selected

  Scenario Outline: Hoe rejects ineligible terrain
    Given the Hoe tool is selected
    And the target tile has <terrain>
    When the player clicks the target tile
    Then no action is queued
    And the error "Hoe requires empty grass." is reported

    Examples:
      | terrain          |
      | dry soil         |
      | paddy mud        |
      | a crop           |
      | a fence          |

  Scenario: Hoe rejects positions outside the field
    Given the Hoe tool is selected
    When the player clicks a position outside the field
    Then no action is queued
    And the out-of-bounds error is reported

  Scenario: Hoe does not remove crops
    Given the Hoe tool is selected
    And tile (2, 3) has a crop
    When the player clicks tile (2, 3)
    Then no action is queued
    And the crop remains

  Scenario: Tilled soil can become paddy
    Given tile (6, 3) was converted into DRY_SOIL by the Hoe
    When the player uses the Water Bucket on (6, 3)
    Then the tile terrain becomes PADDY_MUD

  # --- Shovel ---

  Scenario: Selecting the shovel
    When the player presses the Shovel button
    Then the tool mode is TOOL_REMOVE
    And the Shovel button is pressed
    And other tool buttons are not pressed
    And the selected crop label shows "Tool: Shovel"
    And tiles with crops or fences are highlighted

  Scenario: Deselecting the shovel
    Given the Shovel tool is selected
    When the player presses the Shovel button again
    Then the tool mode is INSPECT
    And no tool button is pressed
    And the selected crop label shows "Mode: Inspect"
    And no tiles are highlighted

  Scenario: Removing a crop with the shovel
    Given the Shovel tool is selected
    And tile (2, 3) has a crop
    When the player clicks tile (2, 3)
    Then a REMOVE_CROP action is queued for (2, 3)
    And the tile is not changed yet
    When the farmer arrives at the tile
    Then the crop is cleared
    And the tile terrain is preserved
    And the tile soil is preserved
    And growth, vitality and disease state are reset
    And the action completes successfully

  Scenario: Removing a fence with the shovel
    Given the Shovel tool is selected
    And tile (6, 3) has a fence
    When the player clicks tile (6, 3)
    Then a REMOVE_FENCE action is queued for (6, 3)
    And the tile is not changed yet
    When the farmer arrives at the tile
    Then the fence is removed
    And the tile terrain is GRASS
    And the tile soil is null
    And the action completes successfully

  Scenario: Shovel does not dig grass
    Given the Shovel tool is selected
    And tile (6, 3) is empty grass
    When the player clicks tile (6, 3)
    Then no action is queued
    And the error "Choose a crop to remove." is reported
    And the tile remains GRASS

  Scenario: Dragging the shovel selects crops or fences
    Given the Shovel tool is selected
    When the player drags across crops, fences, grass and empty soil
    Then only tiles with crops or fences are selected
    And no action is queued for grass or empty soil

  Scenario: Shovel rejects tiles without crops or fences
    Given the Shovel tool is selected
    And the target tile has no crop and no fence
    When the player clicks the target tile
    Then no action is queued
    And the error "Choose a crop to remove." is reported

  # --- Shared behavior ---

  Scenario: Queued tool actions reserve plots
    Given a DIG_GRASS, REMOVE_CROP or REMOVE_FENCE action is queued for a tile
    When the player queues another action on the same tile
    Then the action is rejected with "This plot already has a queued action."

  Scenario: Queued tool actions block turns
    Given a Hoe or Shovel action is pending
    Then the Next Turn button is disabled
    And advance_turn fails until the queue is empty

  Scenario: Stale tool action is cancelled
    Given a DIG_GRASS, REMOVE_CROP or REMOVE_FENCE action is queued for a tile
    And the tile changes before the farmer arrives
    When the farmer arrives
    Then the action is cancelled
    And the existing stale-action error is reported
    And the tile is not modified by the cancelled action

  Scenario: Switching tools cancels an active drag selection
    Given the player is performing an active drag selection with the Hoe or Shovel
    When the player switches to another tool
    Then the selection is cleared
    And no action is queued from the cancelled selection

  Scenario: Hoe and Shovel are disabled outside gameplay
    Given the game state is MENU, GAME_OVER or VICTORY
    Then the Hoe button is disabled
    And the Shovel button is disabled
