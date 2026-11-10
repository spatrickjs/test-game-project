Feature: Inoculation Impact on Epidemiological Models
  As a researcher evaluating crop disease spread
  I want inoculated cells to alter transmission coefficients within Spatial SIR and SEIR models
  So that disease outbreaks spread slower through treated regions of the field

  Background:
    Given the simulation controller is initialized with an active disease outbreak
    And transmission modifier profiles recognize seed and crop inoculation statuses

  Scenario: Reduced infection probability in an inoculated neighborhood
    Given cell (3, 3) is infected with "Rice Blast"
    And the adjacent cell (3, 4) contains an inoculated crop with an active defense modifier
    When the simulation processes turn transition dynamics using the Spatial SIR model
    Then the effective transmission rate ($\beta$) between cell (3, 3) and cell (3, 4) should be scaled down by the inoculation factor
    And the calculated probability of infection for cell (3, 4) should be significantly lower than an uninoculated neighbor

  Scenario: Staged durability and expiration of inoculation protection
    Given an inoculated crop has received protection for <turn_count> turns
    When the turn counter advances past the maximum efficacy duration threshold
    Then the inoculation modifier status on the cell state should expire
    And the transmission modifier should return to baseline unshielded values