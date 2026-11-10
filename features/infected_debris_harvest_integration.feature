@draft @infected_debris
Feature: Infected debris integrates with queued harvesting
	As a player
	I want infected debris to be resolved when harvesting completes
	So that queued or cancelled actions do not change my field prematurely

	# Proposed acceptance criteria, not implemented behavior.
	# Eligibility and debris behavior require decisions recorded in
	# infected_debris_chance.feature before gameplay implementation.

	Background:
		Given the field is initialized
		And the game is in the PLAYING state
		And the Harvest tool is selected
		And the infected debris chance is 1.0
		And the target tile has no infected debris

	Scenario: Queuing a harvest does not resolve debris
		Given the target tile has a mature crop eligible to leave infected debris
		When the player queues a harvest on the tile
		Then the tile state is unchanged
		And no infected debris chance is evaluated

	Scenario: Farmer arrival resolves debris on the harvested tile
		Given a queued harvest of a mature crop eligible to leave infected debris
		When the farmer arrives at the target tile
		Then the harvest succeeds
		And the target tile has infected debris and no crop
		And the infected debris chance is evaluated exactly once
		And other tiles are unchanged
		And the turn index is unchanged

	Scenario Outline: Debris outcome preserves the harvest result
		Given a queued harvest of a mature crop eligible to leave infected debris
		And the infected debris chance is <chance>
		When the farmer arrives at the target tile
		Then the harvest succeeds
		And the harvest result identifies the harvested crop and tile
		And its quality multiplier equals one minus the crop's pre-harvest yield quality loss
		And the successful harvest count increases by exactly one

		Examples:
			| chance |
			| 0.0    |
			| 1.0    |

	Scenario Outline: Rejected harvest does not resolve debris
		Given <target>
		When the player attempts to queue a harvest on the target
		Then the harvest is rejected
		And the field state is unchanged
		And no infected debris chance is evaluated
		And the successful harvest count is unchanged

		Examples:
			| target                              |
			| the target tile has no crop          |
			| the target tile has an immature crop |
			| the target is outside the field      |
			| the target tile already has a queued action |

	Scenario: A stale queued harvest does not resolve debris
		Given a queued harvest of a mature crop eligible to leave infected debris
		And the target tile changes before the farmer arrives
		When the farmer arrives at the target tile
		Then the harvest is cancelled
		And the field state is unchanged from immediately before arrival
		And no infected debris chance is evaluated
		And the successful harvest count is unchanged

	Scenario: Duplicate arrival does not repeat debris resolution
		Given an eligible queued harvest has already completed successfully
		When the same farmer arrival is reported again
		Then the outdated arrival is ignored
		And the field state is unchanged
		And no additional infected debris chance is evaluated
		And the successful harvest count is unchanged
