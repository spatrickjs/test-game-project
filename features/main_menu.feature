Feature: Main Menu
    As a player
    I want to navigate the main menu and configure game settings
    So that I can customize my game experience and start playing.

    Background:
        Given the game has finished loading
        And I am on the Main Menu screen

    # Settings Navigation

    Scenario: Player opens the Settings panel
        When I click the Settings button
        Then I should see the Settings panel

    Scenario: Player opens the Sound tab
        Given I am on the Settings panel
        When I click the Sound tab
        Then I should see the sound settings
        And I should be able to adjust the volume levels

    Scenario: Player opens the Graphics tab
        Given I am on the Settings panel
        When I click the Graphics tab
        Then I should see the graphics settings
        And I should be able to adjust the display and graphics quality

    Scenario: Player opens the Difficulty tab
        Given I am on the Settings panel
        When I click the Difficulty tab
        Then I should see the difficulty settings
        And I should be able to select a game difficulty

    # Settings Management

    Scenario: Player saves settings
        Given I am on the Settings panel
        And I have modified one or more settings
        When I click the Save button
        Then my changes should be saved
        And I should see a save confirmation

    Scenario: Player exits Settings without unsaved changes
        Given I am on the Settings panel
        And I have no unsaved changes
        When I click the Exit button
        Then I should return to the Main Menu screen

    Scenario: Player exits Settings with unsaved changes
        Given I am on the Settings panel
        And I have modified one or more settings
        When I click the Exit button
        Then I should see a confirmation dialog
        And I should be asked whether to discard my changes

    Scenario: Player confirms discarding unsaved changes
        Given I am viewing the discard changes confirmation dialog
        When I click the Discard button
        Then my unsaved changes should be discarded
        And I should return to the Main Menu screen

    Scenario: Player cancels discarding unsaved changes
        Given I am viewing the discard changes confirmation dialog
        When I click the Cancel button
        Then I should return to the Settings panel
        And my unsaved changes should remain

    # About Us

    Scenario: Player opens the About Us panel
        Given I am on the Main Menu screen
        When I click the About Us button
        Then I should see the About Us panel
        And I should see information about the game and its developers

    Scenario: Player exits the About Us panel
        Given I am on the About Us panel
        When I click the Back button
        Then I should return to the Main Menu screen

    # Starting a Game

    Scenario: Player opens the Play menu
        Given I am on the Main Menu screen
        When I click the Play button
        Then I should see the game selection panel
        And I should see the New Game and Continue options

    Scenario: Player starts a new game
        Given I am on the game selection panel
        When I click the New Game button
        Then a new game should be initialized
        And I should be taken to the game

    Scenario: Player continues an existing game
        Given I am on the game selection panel
        And I have an existing saved game
        When I click the Continue button
        Then my saved game should be loaded
        And I should resume my previous progress

    Scenario: Player attempts to continue without a saved game
        Given I am on the game selection panel
        And I do not have an existing saved game
        When I click the Continue button
        Then the Continue option should be disabled
        Or I should see a message indicating that no saved game exists

    # Exiting the Game

    Scenario: Player exits the game
        Given I am on the Main Menu screen
        When I click the Exit Game button
        Then I should see an exit confirmation dialog

    Scenario: Player confirms exiting the game
        Given I am viewing the exit confirmation dialog
        When I click the Confirm button
        Then the game should close

    Scenario: Player cancels exiting the game
        Given I am viewing the exit confirmation dialog
        When I click the Cancel button
        Then I should return to the Main Menu screen

    # Pause Menu

    Scenario: Player pauses the game
        Given I am playing the game
        When I press the Escape key
        Then I should see the pause menu
        And the game should be paused
        And I should see a Continue button
        And I should see an Exit to Main Menu button

    Scenario: Player resumes the game from the pause menu
        Given I am viewing the pause menu
        When I click the Continue button
        Then the game should resume
        And I should no longer see the pause menu

    Scenario: Player exits to the main menu from the pause menu
        Given I am viewing the pause menu
        When I click the Exit to Main Menu button
        Then I should return to the Main Menu screen
