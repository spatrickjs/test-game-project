Feature: Farmer as disease vector
  The farmer can carry disease from infected plots to healthy plots.
  Transmission is evaluated only when a queued farmer action commits on arrival.

  Background:
    Given a new game with a fixed disease-activation seed
    And a farmer standing on a clean tile
    And a grid containing planted plots

  Scenario: Farmer becomes contaminated after acting on an infected plot
    Given a plot that is infected
    And the farmer is clean
    When the farmer arrives at the plot and the queued action commits
    Then the farmer is contaminated

  Scenario: Contaminated farmer can infect a healthy plot
    Given the farmer is contaminated
    And a plot that is healthy and susceptible
    When the farmer arrives at the plot and the queued action commits
    Then the transmission check uses the disease-activation random stream
    And the plot may become infected according to the transmission chance

  Scenario: Clean farmer never infects a plot
    Given the farmer is clean
    And a plot that is healthy and susceptible
    When the farmer arrives at the plot and the queued action commits
    Then the plot remains healthy

  Scenario: Transmission is deterministic for a given seed
    Given the farmer is contaminated
    And two games started with the same disease-activation seed
    When both farmers perform the same queued actions on the same plots
    Then both games produce identical infection outcomes

  Scenario: Simulation and decoration random streams are unaffected
    Given the farmer is contaminated
    When the farmer commits an action that triggers a transmission check
    Then the simulation random stream state is unchanged
    And the decoration random stream state is unchanged

  Scenario: No transmission occurs during movement
    Given the farmer is contaminated
    And the farmer has a queued action on a healthy plot
    When the farmer is moving toward the plot
    Then no transmission check is made
    And the simulation clock has not advanced

  Scenario: Transmission is committed on arrival only
    Given the farmer is contaminated
    And the farmer has a queued action on a healthy plot
    When the farmer arrives at the plot
    Then the transmission check is made exactly once

  Scenario: Rejected action does not change contamination or plot state
    Given the farmer is contaminated
    And a queued action that fails validation
    When the farmer arrives and the action is rejected
    Then the farmer remains contaminated
    And the plot state is unchanged
    And the random stream state is unchanged
    And the action exposes a last error

  Scenario: Failed commit preserves authoritative state
    Given the farmer is contaminated
    And a transmission would be staged on a copy of the grid
    When validation of the staged copy fails
    Then the authoritative grid, random streams, counters, and clock are unchanged
    And no observers are notified

  Scenario: Observers are notified after a committed transmission
    Given the farmer is contaminated
    When a transmission commits and a plot becomes infected
    Then observers are notified after the commit
    And the notified snapshot shows the plot as infected

  Scenario: Views receive detached snapshots only
    Given the farmer is contaminated
    When a view requests the grid state
    Then it receives a detached copy
    And changing the copy does not alter the farmer's contamination or any plot

  Scenario: Already infected plot is not re-infected
    Given the farmer is contaminated
    And a plot that is already infected
    When the farmer arrives at the plot and the queued action commits
    Then the plot infection state is unchanged

  Scenario: Fenced or protected plot resists transmission
    Given the farmer is contaminated
    And a plot with an active protective treatment
    When the farmer arrives at the plot and the queued action commits
    Then the plot remains healthy

  Scenario: Contamination clears after the configured duration
    Given the farmer is contaminated
    When the configured number of turns pass without contact with an infected plot
    Then the farmer becomes clean

  Scenario: Contamination state is exposed to the presentation layer
    Given the farmer is contaminated
    When the presentation layer reads the farmer state
    Then the contamination flag is available
    And the presentation layer does not mutate it
