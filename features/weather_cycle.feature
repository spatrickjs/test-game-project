# Suggested repository location: features/weather_cycle.feature
# Based on WeatherManager and docs/WEATHER_AND_SOIL_TOOLS.md on main.
# These acceptance scenarios describe the existing turn-based weather model.
# Step definitions are required to run this file as automated tests.
# Rainfall, evaporation, humidity, and soil moisture are normalized game values.
# Compare calculated decimal values with a tolerance of 0.000001.

Feature: Turn-based weather cycle
    As a player
    I want weather to change as I advance turns
    So that rainfall and evaporation influence how I manage my crops.

    Background:
        Given I am playing a game with an initialized field
        And weather is enabled using the Inspector source
        And the weather configuration is:
            | setting                             | value |
            | base_temperature_celsius            | 25    |
            | rainfall_per_turn                   | 0.02  |
            | evaporation_per_turn                | 0.02  |
            | ambient_humidity                    | 0.5   |
            | rainfall_moisture_scale              | 1     |
            | temperature_reference_celsius       | 25    |
            | temperature_evaporation_sensitivity | 0.02  |
            | humidity_reference                  | 0.5   |
            | humidity_evaporation_sensitivity    | 1     |
            | minimum_evaporation_factor          | 0     |
            | maximum_evaporation_factor          | 3     |
            | fluctuations_enabled                | false |
            | temperature_amplitude               | 0     |
            | rainfall_amplitude                  | 0     |
            | cycle_length_turns                  | 8     |
        And no other turn processing changes soil moisture
        And the next turn is permitted by the game turn limit

    Scenario: Balanced default weather preserves soil moisture
        Given a soil tile has moisture 0.5
        When I click the Next Turn button and the turn succeeds
        Then the tile moisture should be 0.5
        And the turn counter should increase by 1

    Scenario: Weather waits for the player to advance a turn
        Given weather fluctuations are enabled
        And the temperature amplitude is 5
        And the rainfall amplitude is 0.02
        When I wait without advancing a turn
        Then the weather cycle phase should remain unchanged
        And soil moisture should remain unchanged
        And the turn counter should remain unchanged

    # The weather phase uses the zero-based turn index BEFORE advancing the clock.
    # Each example starts independently with moisture 0.5.
    Scenario Outline: Weather follows a deterministic repeating cycle
        Given weather fluctuations are enabled
        And the cycle length is 4 turns
        And the temperature amplitude is 5
        And the rainfall amplitude is 0.02
        And the current turn index is <turn_index>
        And a soil tile has moisture 0.5
        When I click the Next Turn button and the turn succeeds
        Then weather should use temperature <temperature> Celsius for evaporation
        And weather should use rainfall <rainfall>
        And the tile moisture should be <moisture>

        Examples:
            | turn_index | temperature | rainfall | moisture |
            | 0          | 25          | 0.02     | 0.500    |
            | 1          | 30          | 0.04     | 0.518    |
            | 2          | 25          | 0.02     | 0.500    |
            | 3          | 20          | 0.00     | 0.482    |
            | 4          | 25          | 0.02     | 0.500    |
            | 5          | 30          | 0.04     | 0.518    |

    Scenario: Disabled fluctuations use baseline weather
        Given weather fluctuations are disabled
        And the temperature amplitude is 5
        And the rainfall amplitude is 0.02
        And the current turn index is 1
        And a soil tile has moisture 0.5
        When I click the Next Turn button and the turn succeeds
        Then weather should use temperature 25 Celsius for evaporation
        And weather should use rainfall 0.02
        And the tile moisture should be 0.5

    Scenario Outline: Rainfall remains within normalized bounds
        Given weather fluctuations are enabled
        And the cycle length is 4 turns
        And the rainfall baseline is <baseline>
        And the rainfall amplitude is <amplitude>
        And the current turn index is <turn_index>
        When I click the Next Turn button and the turn succeeds
        Then weather should use rainfall <rainfall>

        Examples:
            | baseline | amplitude | turn_index | rainfall |
            | 0.02     | 0.10      | 3          | 0        |
            | 0.90     | 0.20      | 1          | 1        |

    Scenario Outline: Rainfall and evaporation keep soil moisture within bounds
        Given a soil tile has moisture <initial>
        And the rainfall baseline is <rainfall>
        And the evaporation baseline is <evaporation>
        When I click the Next Turn button and the turn succeeds
        Then the tile moisture should be <expected>

        Examples:
            | initial | rainfall | evaporation | expected |
            | 0.50    | 0.10     | 0.02        | 0.58     |
            | 0.50    | 0        | 0.05        | 0.45     |
            | 0.95    | 0.10     | 0           | 1        |
            | 0.03    | 0        | 0.05        | 0        |

    Scenario: Warm and dry weather increases evaporation
        Given the base temperature is 35 Celsius
        And ambient humidity is 0.3
        And the rainfall baseline is 0
        And a soil tile has moisture 0.5
        When I click the Next Turn button and the turn succeeds
        Then weather should apply evaporation 0.0288
        And the tile moisture should be 0.4712

    Scenario: Weather affects planted and empty soil tiles
        Given an empty dry-soil tile has moisture 0.5
        And a dry-soil tile planted with corn has moisture 0.5
        And a paddy-mud tile planted with rice has moisture 0.5
        And a grass tile has no soil state
        And the rainfall baseline is 0.1
        And the evaporation baseline is 0
        When I click the Next Turn button and the turn succeeds
        Then each of those soil tiles should have moisture 0.6
        And the grass tile should still have no soil state

    Scenario: Crop growth uses the moisture updated by weather
        Given a planted tile has moisture 0.5
        And the rainfall baseline is 0.1
        And the evaporation baseline is 0
        When I click the Next Turn button and the turn succeeds
        Then crop growth for that turn should be evaluated using moisture 0.6

    Scenario: Hydration weather preserves the disease environment
        Given the field has an existing abiotic temperature and humidity
        And the base temperature is 35 Celsius
        And ambient humidity is 0.3
        When I click the Next Turn button and the turn succeeds
        Then weather should not overwrite the field abiotic temperature or humidity

    Scenario: Disabled weather allows the turn to complete without moisture updates
        Given weather is disabled
        And a soil tile has moisture 0.5
        When I click the Next Turn button and the turn succeeds
        Then the tile moisture should be 0.5
        And the turn counter should increase by 1

    Scenario: Runtime weather changes apply on the next successful turn
        Given a soil tile has moisture 0.5
        When the rainfall baseline is changed to 0.1 during play
        Then the tile moisture should still be 0.5
        When I click the Next Turn button and the turn succeeds
        Then the tile moisture should be 0.58

    Scenario Outline: Invalid cycle lengths reject the turn without changing state
        Given the cycle length is <length> turns
        When I click the Next Turn button
        Then the turn should be rejected with a positive cycle length diagnostic
        And the turn counter should remain unchanged
        And the field state should remain unchanged

        Examples:
            | length |
            | 0      |
            | -1     |

    Scenario: A one-turn cycle always uses baseline weather
        Given weather fluctuations are enabled
        And the cycle length is 1 turn
        And the temperature amplitude is 5
        And the rainfall amplitude is 0.02
        When I complete 3 successful turns
        Then every turn should use temperature 25 Celsius for evaporation
        And every turn should use rainfall 0.02

    Scenario Outline: Unsupported climate sources reject the turn
        Given the weather source is <source>
        When I click the Next Turn button
        Then the turn should be rejected with a diagnostic that external climate sources are not implemented
        And the turn counter should remain unchanged
        And the field state should remain unchanged

        Examples:
            | source           |
            | CLIMATE_RESOURCE |
            | CSV              |

    Scenario: A failed turn does not consume a weather cycle phase
        Given weather fluctuations are enabled
        And the cycle length is 4 turns
        And the temperature amplitude is 5
        And the rainfall amplitude is 0.02
        And the current turn index is 1
        And a soil tile has moisture 0.5
        And simulation processing will fail after weather and crop growth are staged
        When I click the Next Turn button
        Then the turn should fail
        And the current turn index should still be 1
        And the entire field state should match its state before the attempt
        And no successful weather update summary should be published for that attempt
        When the simulation failure is resolved
        And I click the Next Turn button and the turn succeeds
        Then weather should use temperature 30 Celsius for evaporation
        And weather should use rainfall 0.04
        And the tile moisture should be 0.518
        And the current turn index should be 2

    Scenario: Sequential turns accumulate moisture using each cycle phase
        Given weather fluctuations are enabled
        And the cycle length is 4 turns
        And the temperature amplitude is 5
        And the rainfall amplitude is 0.02
        And the current turn index is 0
        And a soil tile has moisture 0.5
        When I complete 3 successful turns
        Then the tile moisture should be 0.518
        When I complete 1 more successful turn
        Then the tile moisture should be 0.5

    Scenario: Re-enabling weather uses the current game turn
        Given the four-turn cycle has temperature amplitude 5 and rainfall amplitude 0.02
        And a soil tile has moisture 0.5
        And I have completed the first turn
        When weather is disabled for 2 successful turns
        And weather is enabled again
        And I click the Next Turn button and the turn succeeds
        Then the tile moisture should be 0.482
        And the current turn index should be 4

    Scenario: A new session resets the weather phase
        Given I have advanced the weather cycle
        When a new session initializes the field and resets the clock
        Then the current turn index should be 0
        And the next successful turn should use baseline weather at phase zero

    Scenario: Requests outside active gameplay do not advance weather
        Given the game is on the menu or has ended
        When a Next Turn request is made
        Then the turn should be rejected
        And the field state and turn counter should remain unchanged

    Scenario: A reentrant turn request cannot consume a second phase
        Given a successful turn is notifying completion listeners
        When a listener requests another turn before that notification finishes
        Then the nested request should be rejected
        And only the original turn should be committed

    Scenario: Fence work blocks turns until the queued action completes
        Given a fence action is queued on a soil tile
        When a Next Turn request is made before the farmer arrives
        Then the turn should be rejected
        And the field state and weather phase should remain unchanged

    Scenario: Weather follows the fence and soil lifecycle
        Given the rainfall baseline is 0
        And the evaporation baseline is 0.05
        When the farmer completes a fence action on a soil tile
        And I click the Next Turn button and the turn succeeds
        Then the fenced tile should have no soil
        And neighboring soil should lose 0.05 moisture within normalized bounds
        When the farmer removes that fence
        And I click the Next Turn button and the turn succeeds
        Then the unfenced grass tile should still have no soil
        When the farmer digs that grass tile
        And I click the Next Turn button and the turn succeeds
        Then the restored soil should lose 0.05 moisture within normalized bounds

    Scenario: Disabled weather bypasses configuration errors but not invalid inputs
        Given weather is disabled with invalid settings and an unsupported source
        When weather is evaluated on a valid grid at a nonnegative turn index
        Then the evaluation should succeed without changing the grid
        When weather is evaluated with a missing grid, invalid grid, or negative turn index
        Then the evaluation should be rejected

    Scenario: Invalid numeric weather settings cannot partially change the field
        Given weather settings contain an out-of-range value, a non-finite value, reversed bounds, or a temperature cycle below absolute zero
        When weather is evaluated
        Then the evaluation should be rejected with an actionable diagnostic
        And the complete grid should remain unchanged

    Scenario: Evaporation overflow is rejected even on a soil-free field
        Given finite configured factors would produce non-finite evaporation
        And every field tile has no soil
        When weather is evaluated
        Then the evaluation should be rejected with an overflow diagnostic

    Scenario: A failed activation proposal does not commit weather or randomness
        Given weather and crop growth have been staged
        And disease activation has proposed an introduction
        When activation processing rejects the turn
        Then the complete field and activation history should remain unchanged
        And simulation randomness and counters should be restored
        And no turn completion or new weather summary should be published

    Scenario: Weather summaries describe committed outcomes
        Given debug console output is disabled
        When a successful turn changes soil moisture
        Then the committed summary should record its turn number, changed tile count, total soil tile count, and before and after means
        And no weather summary should be printed to the console
        And balanced, disabled, and soil-free outcomes should remain distinguishable

    Scenario: The selected tile inspector refreshes after weather commits
        Given I am inspecting a soil tile with moisture 0.65
        And the rainfall baseline is 0
        And the evaporation baseline is 0.05
        When I click the Next Turn button and the turn succeeds
        Then the inspector should display soil moisture as 60.0 percent
