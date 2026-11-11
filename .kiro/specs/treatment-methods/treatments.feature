Feature: Chemical and biological treatments
  As a player
  I want to apply treatments that match the disease
  So that I can slow outbreaks and keep the field yielding

  Background:
    Given a level with a field grid
    And the player has enough resources for any single treatment
    And no treatments are on cooldown

  # Requirement 1: queued application

  Scenario: Treatment goes through the work queue
    When the player confirms a fungicide on a fungal-infected cell
    Then a treatment action is added to the work queue
    And the fungicide has no effect yet
    And Next Turn is disabled

  Scenario: Treatment takes effect when the farmer arrives
    Given a fungicide action is queued on a fungal-infected cell
    When the farmer reaches the target and the action commits
    Then the fungicide effect is active on the 3x3 area
    And the cost is deducted
    And the fungicide cooldown starts

  Scenario: Queue cap per turn
    Given the queued treatment cap is 2
    And 2 treatment actions are already queued
    When the player tries to queue another treatment
    Then the action is rejected with a reason
    And the queue is unchanged

  Scenario: Treatment on cooldown is rejected
    Given the bactericide is on cooldown
    When the player tries to queue a bactericide
    Then the action is rejected with the remaining cooldown shown

  # Requirement 2: disease matching

  Scenario: Fungicide on a bacterial disease does nothing
    Given a cell infected with BACTERIAL_LEAF_BLIGHT
    When a fungicide commits on that cell
    Then no effect is applied to the cell
    And a no-effect cue is shown
    And the cost is still spent
    And a mistake is recorded with the treatment, disease, and cell

  Scenario: Mixed-disease area only affects matching cells
    Given an area with a RICE_BLAST cell and a BACTERIAL_LEAF_BLIGHT cell
    When a fungicide commits on the area
    Then the RICE_BLAST cell has the fungicide effect
    And the BACTERIAL_LEAF_BLIGHT cell has no effect
    And one mistake is recorded

  Scenario: Curative treatment on a healthy cell is not a mistake
    Given a healthy cell
    When a fungicide commits on that cell
    Then no effect is applied
    And no mistake is recorded

  # Requirements 3 and 4: curative treatments

  Scenario: Fungicide reduces transmission and speeds recovery
    Given a fungal-infected cell with the fungicide effect active
    When the turn advances
    Then the cell's infection hazard is multiplied by 0.5
    And the cell's recovery rate is scaled by about 1.43
    And the compartment fractions still sum to 1.0

  Scenario: Fungicide lasts 3 turns
    Given a fungicide committed this turn
    When 3 turns advance
    Then the fungicide effect has expired
    And an expiry cue is shown

  Scenario: Bactericide treats bacterial disease
    Given a cell infected with BACTERIAL_LEAF_BLIGHT
    When a bactericide commits on that cell
    Then the bactericide effect is active on the area

  # Requirement 5: protectant

  Scenario: Protectant fungicide lowers susceptibility
    Given a healthy cell
    When a protectant fungicide commits on that cell
    Then the cell's infection hazard is multiplied by 0.6 for 4 turns
    And the cell's recovery rate is unchanged

  Scenario: Protectant wears off
    Given a protectant fungicide committed this turn
    When 4 turns advance
    Then the cell's hazard multiplier returns to 1.0

  # Requirement 6: enhancer

  Scenario: Enhancer raises resilience without curing
    Given a cell infected with RICE_TUNGRO
    When an enhancer commits on that cell
    Then the cell's infection hazard is multiplied by 0.85
    And the infection status is unchanged
    And the recovery rate is unchanged

  Scenario: Repeated enhancer has diminishing returns
    Given an enhancer was applied to a cell this window
    When another enhancer commits on the same cell
    Then the new effect potency is 0.7 of the first

  # Requirement 7: stacking

  Scenario: Same treatment does not stack
    Given a fungicide effect with 1 turn remaining on a cell
    When another fungicide commits on that cell
    Then the effect strength is unchanged
    And the remaining turns are refreshed to 3

  Scenario: Different treatments combine
    Given a fungicide and an enhancer are active on the same fungal-infected cell
    When the turn advances
    Then the hazard multiplier is the product of both effects

  # Requirement 8: resistance

  Scenario: Overusing fungicide weakens it
    Given the fungicide group was used past the threshold in the recent window
    When a fungicide commits
    Then the new effect has reduced potency
    And the resistance indicator for the fungicide group is raised

  Scenario: Protectant counts toward fungicide resistance
    Given the fungicide group is at the threshold
    When a protectant fungicide commits
    Then the fungicide group usage count increases

  Scenario: Resistance decays when unused
    Given the fungicide group has raised resistance
    When enough turns pass without fungicide use
    Then the resistance indicator returns to zero

  # Requirement 9: integration

  Scenario: Treatment state survives save and load
    Given active treatment effects and cooldowns
    When the game is saved and loaded
    Then the effects, cooldowns, usage, and mistakes are restored

  Scenario: Older save loads with no treatment state
    Given a save made before treatments existed
    When the game is loaded
    Then treatment state is empty
    And the game continues normally

  # Requirement 12 (Phase 2): insecticide

  @phase2
  Scenario: Insecticide suppresses vectors for tungro
    Given a cell infected with RICE_TUNGRO
    When an insecticide commits on that cell
    Then the area's vector pressure is 0 for 2 turns
    And the infected crops are not cured

  @phase2
  Scenario: Insecticide on a non-vector disease does nothing
    Given a cell infected with RICE_BLAST
    When an insecticide commits on that cell
    Then no effect is applied
    And a mistake is recorded

  @phase2
  Scenario: Insecticide rebound grows with repeated use
    Given the insecticide was used several times in an area
    When its effect expires
    Then vector pressure rebounds above its starting level
    And the rebound is larger than after a single use
