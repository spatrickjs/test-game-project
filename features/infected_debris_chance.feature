@infected_debris
Feature: Infected Debris chance after harvest
	As a player
	I want harvesting to have a chance of leaving infected debris
	So that harvest can leave a visible consequence of crop disease


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

	Scenario: Infected debris is shown in the inspector
		Given an empty tile with infected debris
		When the player inspects the tile
		Then the inspector displays "Infected debris"

	Scenario Outline: Tile operations apply the debris lifecycle
		Given a tile with infected debris
		When <operation> completes successfully on the tile
		Then the tile <outcome>

		Examples:
			| operation          | outcome                |
			| planting           | has no infected debris |
			| fencing            | has no infected debris |
			| terrain conversion | has no infected debris |
			| crop removal       | has infected debris    |
			| turn advancement   | has infected debris    |

	Scenario: Moving a crop preserves residue at both locations
		Given a crop can be moved between two tiles
		When the crop is moved
		Then each tile retains its original infected debris flag

	Scenario: Candidate failure preserves the harvest and random sequence
		Given an eligible mature crop
		And candidate validation will fail after the debris draw
		When harvesting is attempted
		Then harvesting fails without changing the field or debris random state
		And no successful harvest is recorded

	Scenario: Invalid policy cannot replace a session
		Given an existing field
		And the configured debris probability is not finite or is outside zero to one
		When a new field is initialized
		Then initialization fails without changing the field or debris random state

	Scenario: Detached snapshots preserve debris
		Given a tile with infected debris
		When a detached field snapshot is changed to clear that debris
		Then the authoritative tile still has infected debris
