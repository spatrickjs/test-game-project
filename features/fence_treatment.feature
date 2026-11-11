Feature: Fence Treatment Method
	As a player
	I want to fence off tiles
	So that I can contain vector-borne disease spread

	Background:
		Given the field is initialized
		And the game is in the PLAYING state
		And the Fence tool is selected

	Scenario: Fence an empty dry soil tile
		Given an empty dry soil tile
		When the player queues a fence on the tile
		And the farmer arrives at the tile
		Then the tile has a fence
		And the tile terrain is GRASS
		And the tile soil is null
		And the tile cannot be planted

	Scenario: Fence an empty paddy mud tile
		Given an empty paddy mud tile
		When the player queues a fence on the tile
		And the farmer arrives at the tile
		Then the tile has a fence
		And the tile terrain is GRASS
		And the tile soil is null

	Scenario Outline: Reject fencing a planted plot
		Given a tile with <crop>
		When the player queues a fence on the tile
		Then the action is rejected with "Remove or harvest the crop before placing a fence."
		And the tile state is unchanged
		And no fence action is queued

		Examples:
			| crop                           |
			| a healthy crop                 |
			| a crop with an active disease  |

	Scenario: Fenced tile is not a disease host
		Given a fenced tile adjacent to an infected crop
		When the turn advances
		Then the fenced tile receives no infection
		And the fenced tile is not counted as disease pressure

	Scenario: Fenced tile rejects planting
		Given a fenced tile
		When the player attempts to plant any crop on the tile
		Then planting is rejected
		And the tile state is unchanged

	Scenario: Fenced tile rejects soil tools
		Given a fenced tile
		When the player applies water or fertilizer to the tile
		Then the action is rejected with "Choose a tile with soil."

	Scenario: Fenced tile rejects another fence
		Given a fenced tile
		When the player queues a fence on the tile
		Then the action is rejected

	Scenario: Fence on a queued tile is rejected
		Given a tile with a queued action
		When the player queues a fence on the tile
		Then the action is rejected with "This plot already has a queued action."

	Scenario: Fence on a tile outside the field
		When the player queues a fence outside the field
		Then the action is rejected with "Choose a tile inside the field."

	Scenario: Fence takes effect only on farmer arrival
		Given an empty dry soil tile
		When the player queues a fence on the tile
		Then the tile state is unchanged
		And the tile is highlighted as queued

	Scenario: Fence does not advance the turn
		Given an empty dry soil tile
		When the fence action completes
		Then the turn index is unchanged

	Scenario: Stale fence action is cancelled
		Given a queued fence on a tile
		And the tile changes before the farmer arrives
		When the farmer arrives at the tile
		Then the action is cancelled
		And the tile state is unchanged

	Scenario: Shovel destroys a fence
		Given a fenced tile
		When the player drag-and-drops the shovel on the tile
		And the farmer arrives at the tile
		Then the fence is destroyed
		And the tile terrain is GRASS
		And the tile soil is null

	Scenario: Dug fenced tile can become dry soil
		Given a tile whose fence was destroyed
		When the player digs the tile with the shovel
		Then the tile terrain is DRY_SOIL
		And the tile soil is a fresh copy of the initial soil

	Scenario: Shovel drag excludes mixed contexts
		Given fenced tiles and crop tiles
		When the player starts a shovel drag on a fenced tile
		Then only fenced tiles are selected
		And crop tiles are not selected

	Scenario: Fence persists across turns
		Given a fenced tile
		When the turn advances
		Then the tile still has a fence
		And the grid validates without errors

	Scenario: Fence is cleared on new game
		Given a fenced tile
		When the player starts a new game
		Then no tile has a fence
