# Repo Findings: Action Bar Feature

*Last updated: 2026-11-12*

This document summarizes the current implementation state, architecture patterns, and gaps for implementing the Action Bar feature defined in `action_bar.feature`. Use this as reference when planning and implementing the feature.

## Current Implementation Status

**Action Bar feature is NOT YET IMPLEMENTED**, but a robust foundation exists for farmer actions, turn system, and validation patterns that can be extended.

### ✅ **Existing Components That Support Action Bar**

#### 1. **Farmer Action Queue System** (Fully Implemented)
- **Location**: `src/logic/farming/farming_controller.gd`
- **Core Methods**: 
  - `enqueue_action(request)` - Validates and reserves intent without mutation
  - `arrive_at_action(action_id, stop)` - Commits action when farmer arrives
  - `action_error(action)` - Shared read-only validation for indicators, enqueue, arrival
- **Action Types Supported**: PLANT, REMOVE_CROP, DIG_GRASS, MAKE_PADDY, MOVE_CROP, HARVEST, WATER_SOIL, FERTILIZE, FENCE, REMOVE_FENCE, and treatment actions
- **Signal Pattern**:
  - `action_queue_changed` - Queue modification
  - `action_finished(action_id, success, reason)` - Action completion
  - `queued_harvest_completed(result)` - Specialized harvest signal

#### 2. **Turn System** (Fully Implemented)
- **Location**: `src/logic/turns/turn_controller.gd`
- **Core Methods**:
  - `advance_turn()` - Orchestrates field staging, growth, simulation
  - `try_set_algorithm_override(value)` - Validation pattern example
- **Turn Advancement**:
  - Validates farming controller is initialized
  - Blocks while actions are pending (`has_pending_actions()`)
  - Emits `turn_completed(turn_index)` after successful commit

#### 3. **Validation & State Preservation Patterns** (Established)
- **"Validate-don't-throw"**: `validate() -> PackedStringArray` pattern used throughout
- **"Copy-on-stage"**: Mutations happen on copies, validated before commit
- **State Preservation**: Failed operations preserve grid, RNG, counters, clock
- **Revision Tracking**: `_revisions` dictionary prevents stale action commits

#### 4. **Observer/Notification System** (Established)
- Signal-based communication between Logic and Presentation layers
- `_connect_once()` pattern in presenters prevents duplicate connections
- Local copies of values in signals prevent mutation during listener execution

### ❌ **Missing Components for Action Bar Feature**

#### 1. **Action Counting & Limits**
- No tracking of consumed actions per turn
- No maximum action configuration (`max_actions` property)
- No consumption logic in `arrive_at_action()` or `enqueue_action()`

#### 2. **Turn-Based Reset Mechanism**
- No reset of action counts on turn completion
- No connection between action limits and `turn_completed` signal

#### 3. **Configuration System**
- No resource/configuration for action bar defaults
- No validation for maximum bounds (0, -1 should be rejected)

#### 4. **Observer Signals for Action Count**
- No signals for `actions_remaining_changed` or `max_actions_changed`
- Presentation layer has no UI components for action bar display

#### 5. **Clamping Logic**
- No logic to clamp current count when maximum decreases
- No logic to prevent count from exceeding maximum

## Architecture Patterns to Follow

### 1. **Validation Pattern** (from `FarmingController`)
```gdscript
func validate_max_actions(new_max: int) -> PackedStringArray:
    var errors := PackedStringArray()
    if new_max <= 0:
        errors.append("Maximum actions must be positive.")
    # Additional validation...
    return errors
```

### 2. **Signal Pattern** (from existing queue)
```gdscript
signal actions_remaining_changed(remaining: int, max: int)
signal max_actions_changed(new_max: int)
```

### 3. **State Ownership Pattern**
- Action count should be owned by `FarmingController` (or a new `ActionBarController` in Logic layer)
- Presentation receives signals but doesn't mutate authoritative state
- Reset logic triggered by `TurnController.turn_completed`

### 4. **Consumption Pattern**
```gdscript
func consume_action() -> bool:
    if _actions_remaining <= 0:
        last_error = "Insufficient actions remaining."
        return false
    _actions_remaining -= 1
    actions_remaining_changed.emit(_actions_remaining, _max_actions)
    return true
```

## Implementation Tasks (Ordered)

### **Phase 1: Core Logic Layer**
1. **Add action count properties** to `FarmingController`:
   - `max_actions: int` (default 5, exported)
   - `actions_remaining: int` (private)
   - `last_error: String` (already exists)

2. **Implement validation & clamping**:
   - `validate_max_actions(new_max: int) -> PackedStringArray`
   - Clamp logic when maximum changes: `_clamp_actions_remaining()`

3. **Add consumption logic**:
   - Modify `arrive_at_action()` to call `_consume_action()` before committing
   - Validate `actions_remaining > 0` before allowing action
   - Preserve state on validation failure (don't consume)

4. **Add turn-based reset**:
   - `reset_actions_remaining()` method
   - Connection to `TurnController.turn_completed` signal
   - Use current `max_actions` for reset (not default)

### **Phase 2: Signals & Observers**
5. **Add signals** in `FarmingController`:
   - `actions_remaining_changed(remaining: int, max: int)`
   - `max_actions_changed(new_max: int)`

6. **Connect signals** in `FieldPrototypePresenter`:
   - Update HUD display on count changes
   - Show error messages from `last_error`

### **Phase 3: Configuration & Testing**
7. **Add export properties** for maximum configuration
8. **Write unit tests** covering all scenarios from `action_bar.feature`
9. **Integration tests** with existing action queue system

## Key Considerations

### **Layer Boundaries**
- **Data Layer**: May need `ActionBarConfig` resource for defaults
- **Logic Layer**: `FarmingController` owns authoritative counts
- **Presentation Layer**: Receives signals, displays UI, never mutates counts

### **Error Handling**
- Invalid maximum (≤0) should be rejected with descriptive `last_error`
- Insufficient actions should reject action with clear error message
- Failed actions should NOT consume from bar (already implemented pattern)

### **State Preservation**
- Must preserve grid, RNG, counters, clock when action rejected due to empty bar
- Failed turn commit should preserve action counts (already in turn system)

### **Edge Cases**
- Changing maximum mid-turn (should use new maximum for reset)
- Clamping when maximum decreases below current count
- Multiple observers must receive consistent state

## Related Files & References

### **Core Implementation Files**
1. `src/logic/farming/farming_controller.gd` - Primary modification target
2. `src/logic/turns/turn_controller.gd` - Turn completion connection
3. `src/presentation/world/field_prototype_presenter.gd` - Signal connections & UI

### **Documentation**
1. `docs/QUEUED_FIELD_ACTIONS.md` - Action queue contract patterns
2. `.agents/architecture.md` - Layer boundaries and dependencies
3. `.agents/testing-guidelines.md` - Verification requirements

### **Test Patterns**
- Use existing test patterns from `tests/logic/queued_field_actions_test.gd`
- Follow "copy-on-stage" validation patterns
- Preserve deterministic RNG streams

## Assumptions & Constraints

1. **Default Maximum**: 5 actions per turn (as specified in feature)
2. **Consumption Point**: Action consumes when committed (farmer arrives), not when enqueued
3. **Movement**: Farmer movement does NOT consume actions (already implemented)
4. **Invalid Actions**: Do NOT consume from bar (already implemented pattern)
5. **Observer Notification**: Single notification per consumption (not per attempted action)

## Open Questions
1. Should maximum actions be configurable per game mode/difficulty?
2. Should there be separate action limits for different action types?
3. Should action count be saved/loaded with game state?
4. Should there be visual feedback when action count is low/empty?

*Note: These questions should be resolved before implementation based on product requirements.*