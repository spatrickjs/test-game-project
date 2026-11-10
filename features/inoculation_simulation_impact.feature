Feature: Inoculation Impact on Epidemiological Models
  As a researcher evaluating crop disease spread
  I want inoculated cells to alter transmission coefficients within Spatial SIR and SEIR models
  So that disease outbreaks spread slower through treated regions of the field

  Background:
    Given the simulation controller is initialized with an active disease outbreak
    And transmission modifier profiles recognize seed and crop inoculation statuses

  Scenario Outline: Reduced infection probability in an inoculated neighborhood
    Given cell (3, 3) is infected with "Rice Blast"
    And the adjacent cell (3, 4) contains an inoculated crop with an active defense modifier
    When the simulation processes turn transition dynamics using the <model> model
    Then the effective transmission rate ($\beta$) between cell (3, 3) and cell (3, 4) should be scaled down by the inoculation factor
    And with identical positive pressure and uncapped coefficients its effective transmission rate should be 75% of an untreated recipient
    And its infection risk should not exceed the untreated recipient at zero pressure or saturation

    Examples:
      | model        |
      | Spatial SIR  |
      | Spatial SEIR |

  Scenario: Staged durability and expiration of inoculation protection
    Given an inoculated crop has received protection for 2 successful turns with zero weather decay
    When the third successful turn applies protection and then ages the modifier
    Then the inoculation modifier status on the cell state should expire
    And the transmission modifier should return to baseline unshielded values
