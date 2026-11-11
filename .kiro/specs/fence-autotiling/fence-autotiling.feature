Feature: Fence auto-tiling
  Fences connect automatically to adjacent fences on the four cardinal sides.

  Background:
    Given an empty grid
    And a fence is placed at tile (5, 5)

  Scenario Outline: Fence shape matches neighbor combination
    Given fences exist on the following sides of tile (5, 5): "<neighbors>"
    When the fence at tile (5, 5) updates
    Then its connections are "<connections>"
    And its shape is "<shape>"

    Examples:
      | neighbors  | connections | shape    |
      |            | none        | post     |
      | N          | N           | end      |
      | E          | E           | end      |
      | S          | S           | end      |
      | W          | W           | end      |
      | N,S        | N,S         | straight |
      | E,W        | E,W         | straight |
      | N,E        | N,E         | corner   |
      | E,S        | E,S         | corner   |
      | S,W        | S,W         | corner   |
      | W,N        | W,N         | corner   |
      | N,E,S      | N,E,S       | T        |
      | E,S,W      | E,S,W       | T        |
      | S,W,N      | S,W,N       | T        |
      | W,N,E      | W,N,E       | T        |
      | N,E,S,W    | N,E,S,W     | cross    |

  Scenario: Placing a fence updates existing neighbors
    Given a fence exists at tile (4, 5)
    When a fence is placed at tile (5, 5)
    Then the fence at tile (4, 5) has connection "E"
    And the fence at tile (5, 5) has connection "W"

  Scenario: Removing a fence updates remaining neighbors
    Given fences exist at tiles (4, 5) and (6, 5)
    And the fence at tile (5, 5) has connections "E,W"
    When the fence at tile (5, 5) is removed
    Then the fence at tile (4, 5) has no connections
    And the fence at tile (6, 5) has no connections

  Scenario: Non-fence blocks do not connect
    Given a stone block exists at tile (6, 5)
    When the fence at tile (5, 5) updates
    Then its connections are "none"

  Scenario: Diagonal fences do not connect
    Given a fence exists at tile (6, 6)
    When the fence at tile (5, 5) updates
    Then its connections are "none"
