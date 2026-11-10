Feature: Seed Inoculation
  As a player
  I want to inoculate seeds or crops with protective treatments
  So that I can reduce disease transmission rates and improve crop resilience

  Background:
    Given the game is running on a valid 9x6 field grid
    And the player has selected an active crop or seed ready for treatment
    And the "Seed Inoculation" tool is available in the toolbar

  Scenario Outline: Successfully inoculating a valid field cell
    Given the cell at coordinates (<col>, <row>) has a planted crop in stage "<growth_stage>"
    And the current cell soil moisture is adequate for treatment
    When the player selects the "Inoculation" tool
    And the player applies the inoculant to the cell at (<col>, <row>)
    Then the cell state should record an active inoculation modifier
    And the transmission susceptibility modifier for that cell should decrease by <reduction_rate>%
    And the action should be recorded as a valid turn action in the farming controller

    Examples:
      | col | row | growth_stage | reduction_rate |
      | 2   | 1   | Seedling     | 25.0           |
      | 4   | 3   | Vegetative   | 25.0           |
      | 0   | 5   | Mature       | 15.0           |

  Scenario: Attempting to inoculate an empty or invalid cell
    Given the cell at coordinates (1, 1) contains no planted crop and no seed
    When the player selects the "Inoculation" tool
    And the player attempts to apply the inoculant to (1, 1)
    Then the action should be rejected by the farming controller
    And an invalid target warning message should be displayed on the tile inspector

  Scenario: Inoculation effect persistence across turn advancement
    Given a crop at cell (2, 2) has been successfully inoculated
    When the player clicks "Next Turn"
    And the simulation processes spatial disease transmission models
    Then the inoculated crop should retain its protective modifier effect
    And the modifier decay rate should be applied according to the active simulation weather rules