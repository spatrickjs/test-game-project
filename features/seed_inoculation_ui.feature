Feature: Seed Inoculation UI and Tile Inspector
  As a player
  I want clear visual indicators and inspector feedback when using the Inoculation tool
  So that I can easily verify which crops are protected

  Background:
    Given the main game scene `field_prototype.tscn` is loaded and active
    And the FieldWorldView is rendering the active grid state

  Scenario: Selecting the Inoculation tool from the HUD toolbar
    When the player clicks the "Inoculate" tool button in the UI toolbar
    Then the FieldPrototypePresenter tool mode should update to `TOOL_INOCULATE`
    And the cursor representation should switch to the inoculation applicator icon

  Scenario: Viewing inoculation status in the Tile Inspector
    Given the player selects a cell that currently has an active inoculation treatment
    When the tile inspector view opens for that cell
    Then the inspector panel should display "Inoculated: Active"
    And it should show the remaining protection turns and current resistance bonus percentage

  Scenario: Visual overlay feedback for treated crops
    Given several crops across the field have been inoculated
    When the player toggles the crop debug or status overlay view
    Then the treated crops should display a subtle protective aura or icon indicator matching their status snapshot