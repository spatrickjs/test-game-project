Feature: Action bar
  The action bar holds a configurable maximum number of actions. The default is 5.
  Each farmer action consumes 1 from the bar.
  Ending the turn resets the bar to the current maximum.

  Background:
    Given a new game with a farming grid
    And the action bar maximum is the default of 5

  Scenario: Action bar starts full at the default maximum
    Then the action bar shows 5 of 5

  Scenario Outline: Maximum is swappable
    When the action bar maximum is set to <max>
    Then the action bar maximum is <max>
    And the action bar shows <max> of <max> on a new game

    Examples:
      | max |
      | 1   |
      | 3   |
      | 5   |
      | 8   |
      | 10  |

  Scenario Outline: Invalid maximum is rejected
    When the action bar maximum is set to <max>
    Then the change is rejected
    And last_error reports an invalid maximum
    And the action bar maximum is unchanged

    Examples:
      | max |
      | 0   |
      | -1  |

  Scenario: Raising the maximum keeps the current count
    Given the action bar has 2 remaining
    When the action bar maximum is set to 8
    Then the action bar shows 2 of 8

  Scenario: Lowering the maximum clamps the current count
    Given the action bar has 5 remaining
    When the action bar maximum is set to 3
    Then the action bar shows 3 of 3

  Scenario: Lowering the maximum above the current count keeps it
    Given the action bar has 2 remaining
    When the action bar maximum is set to 3
    Then the action bar shows 2 of 3

  Scenario Outline: Each action consumes one
    Given the action bar maximum is <max>
    And the action bar has <before> remaining
    When the farmer performs a valid "<action>" action
    Then the action bar has <after> remaining
    And observers are notified once

    Examples:
      | max | action  | before | after |
      | 5   | plant   | 5      | 4     |
      | 5   | water   | 4      | 3     |
      | 5   | harvest | 3      | 2     |
      | 5   | treat   | 2      | 1     |
      | 5   | plant   | 1      | 0     |
      | 3   | plant   | 3      | 2     |
      | 8   | water   | 8      | 7     |

  Scenario Outline: Action is rejected when the bar is empty
    Given the action bar maximum is <max>
    And the action bar has 0 remaining
    When the farmer attempts a valid action
    Then the action is rejected
    And last_error reports insufficient actions
    And the grid, RNG, counters, and clock are unchanged
    And the action bar has 0 remaining

    Examples:
      | max |
      | 3   |
      | 5   |
      | 8   |

  Scenario: Invalid action does not consume from the bar
    Given the action bar has 3 remaining
    When the farmer attempts an invalid action
    Then the action is rejected
    And the action bar has 3 remaining

  Scenario Outline: Bar never exceeds the current maximum
    Given the action bar maximum is <max>
    And the action bar has <max> remaining
    When the action bar is increased by 1
    Then the action bar has <max> remaining

    Examples:
      | max |
      | 3   |
      | 5   |
      | 8   |

  Scenario: Bar never drops below zero
    Given the action bar has 0 remaining
    When the action bar is decreased by 1
    Then the action bar has 0 remaining

  Scenario: Queued action consumes at commit
    Given the action bar has 2 remaining
    And the farmer has a queued action
    When the farmer arrives and the action commits
    Then the action bar has 1 remaining

  Scenario: Failed commit preserves the bar
    Given the action bar has 2 remaining
    And the farmer has a queued action that fails validation on arrival
    When the farmer arrives
    Then the action bar has 2 remaining
    And the authoritative state is unchanged

  Scenario: Movement does not consume from the bar
    Given the action bar has 4 remaining
    When the farmer moves without performing an action
    Then the action bar has 4 remaining

  Scenario Outline: End turn resets the bar to the current maximum
    Given the action bar maximum is <max>
    And the action bar has <before> remaining
    When the player ends the turn
    Then the action bar has <max> remaining
    And observers are notified after the turn commits

    Examples:
      | max | before |
      | 5   | 5      |
      | 5   | 3      |
      | 5   | 0      |
      | 3   | 1      |
      | 8   | 0      |

  Scenario: Reset uses a maximum changed mid-turn
    Given the action bar has 1 remaining
    And the action bar maximum is set to 8
    When the player ends the turn
    Then the action bar has 8 remaining

  Scenario: Actions are available again after reset
    Given the action bar has 0 remaining
    When the player ends the turn
    And the farmer performs a valid "plant" action
    Then the action bar has 4 remaining

  Scenario: Bar does not reset without ending the turn
    Given the action bar has 2 remaining
    When the farmer moves and no turn ends
    Then the action bar has 2 remaining

  Scenario: Failed end turn preserves the bar
    Given the action bar has 2 remaining
    And the turn cannot be committed
    When the player ends the turn
    Then the turn is rejected
    And last_error is set
    And the action bar has 2 remaining
    And the grid, RNG, counters, and clock are unchanged
