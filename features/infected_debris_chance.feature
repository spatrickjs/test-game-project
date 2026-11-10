@draft @infected_debris
Feature: Infected Debris chance after harvest
	As a player
	I want harvesting to have a chance of leaving infected debris
	So that harvest can leave a visible consequence of crop disease

	# Proposed acceptance criteria, not implemented behavior.
	# Pending decisions: which harvested crops qualify, the default chance,
	# and whether the chance varies by crop or disease.
	# "Eligible" deliberately leaves infection eligibility undefined until agreed.
	# Probabilities below are fictional test inputs, not agricultural predictions.
	# Proposed rule: a controlled draw in [0, 1) succeeds when draw < chance.
	# Debris appearance, persistence, removal, planting effects, and transmission
	# are outside these scenarios and need separate requirements.

	Background:
		Given the field is initialized
		And the game is in the PLAYING state
		And a mature crop is eligible to leave infected debris after harvest
		And its tile has no infected debris

	Scenario Outline: Resolve the configured chance on successful harvest
		Given the infected debris chance is <chance>
		And the next infected debris random draw is <draw>
		When the crop is successfully harvested
		Then the harvested tile <outcome>
		And the harvested tile has no crop
		And the harvested tile retains its terrain and soil

		Examples:
			| chance | draw     | outcome                |
			| 0.0    | 0.0      | has no infected debris |
			| 0.0    | 0.999999 | has no infected debris |
			| 0.25   | 0.249999 | has infected debris    |
			| 0.25   | 0.25     | has no infected debris |
			| 0.25   | 0.250001 | has no infected debris |
			| 1.0    | 0.0      | has infected debris    |
			| 1.0    | 0.999999 | has infected debris    |

	Scenario: Ineligible harvest does not create infected debris
		Given the crop is instead ineligible to leave infected debris
		And the infected debris chance is 1.0
		When the crop is successfully harvested
		Then the harvested tile has no infected debris
		And no infected debris chance is evaluated

	Scenario: Repeat a harvest sequence deterministically
		Given two identical fields with the same infected debris random seed
		And both fields use the same infected debris chance
		When the same sequence of eligible harvests completes in both fields
		Then both fields have the same infected debris outcomes at each harvested tile
