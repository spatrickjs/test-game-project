Feature: Day and night cycle
  As a player
  I want night to appear when I end my turn
  So that ending a turn feels like time passing

  Night is a presentation state shown only as a result of ending a turn.
  Time never advances through timers or frame callbacks.

  Background:
    Given a farming game is in progress

  Scenario: New game starts in day
    When a new game starts
    Then the scene is day

  Scenario: Day persists while the player acts
    Given the scene is day
    When the player performs farmer actions without ending the turn
    Then the scene is day
    And the turn index does not change

  Scenario: Real time passing does not trigger night
    Given the scene is day
    When real time passes without the player ending the turn
    Then the scene is day
    And the turn index does not change

  Scenario: End Turn is unavailable while farmer actions are pending
    Given the farmer has pending or in-flight actions
    Then Next Turn is disabled

  Scenario: Pending actions commit during day before End Turn is available
    Given the farmer has queued actions
    When the farmer arrives at each target
    Then each action commits on arrival
    And the scene is day
    And Next Turn becomes enabled when no actions are pending

  Scenario: Ending the turn shows night
    Given the scene is day
    And no farmer actions are pending
    When the player ends the turn
    Then advance_turn commits and turn_completed is emitted
    And the scene transitions to night
    And the turn index increases by one

  Scenario: Night ends when its transition completes
    Given the scene is night after a turn ended
    When the night-to-day transition animation completes
    Then the scene is day
    And the player may act again

  Scenario: Day and night transitions do not advance the clock
    When a day-to-night or night-to-day transition animation plays
    Then the turn index does not change
    And the simulation state does not change

  Scenario: Farmer movement does not advance the clock or show night
    Given the farmer is moving to a target
    When the movement animation plays
    Then the turn index does not change
    And the scene is day

  Scenario: Night is a presentation state only
    Then the Simulation layer has no concept of night
    And night is driven by the turn_completed signal in the Presentation layer

  Scenario: Failed turn end preserves state
    Given the scene is day
    When advance_turn is rejected
    Then the scene is day
    And authoritative state, RNG, counters and clock are unchanged
    And last_error describes the rejection

  Scenario: Turn limit reached
    Given the game is on the final turn
    When the player ends the turn
    Then the scene transitions to night
    And the game ends via check_turn_limit
    And End Turn is not offered afterward

  Scenario: Loading a save starts in day
    Given a save made at turn index N
    When the player continues the game
    Then the turn index is N
    And the scene is day

  Scenario: Older save without day or night state loads
    Given a save with no day or night state
    When the player continues the game
    Then the scene is day
    And the load succeeds

  Scenario: Same seed gives the same turn index and phase
    Given two games with the same seed
    When both players end the same number of turns
    Then both games have the same turn index
    And both games show the same scene phase
