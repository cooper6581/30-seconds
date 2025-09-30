# Godot Best Practices - Entity Architecture

## What We Just Implemented:

### 1. **Single Responsibility Principle**
- **main.gd**: Handles WHEN to spawn and lifecycle management
- **unified_power_up.gd**: Handles HOW to spawn and self-configuration

### 2. **Entity Self-Management**
- Power-ups now handle their own:
  - Type randomization
  - Position calculation 
  - Visual setup
  - Animation start
- This matches your mob pattern!

### 3. **"Tell, Don't Ask" Principle**
- Before: main.gd asked power-up "what type are you?" then configured it
- After: main.gd tells power-up "spawn yourself" and trusts it to do it right

### 4. **Consistent Architecture**
- Mob: `mob.spawn(player_position, screen_size)`
- Power-up: `power_up.spawn(screen_size)`
- Both entities handle their own spawn logic!

### 5. **Cleaner Separation of Concerns**
```gdscript
# MAIN.GD - Game Coordination
func spawn_power_up():
    # I decide WHEN to spawn
    cleanup_old_powerup()
    create_new_powerup()
    powerup.spawn(screen_size)  # You decide HOW to spawn

# POWER_UP.GD - Entity Behavior  
func spawn(screen_size):
    # I decide my type, position, appearance
    configure_myself()
    start_my_animations()
```

## Benefits:
- **Easier to maintain**: All power-up logic in one file
- **Easier to extend**: Adding new power-up types is simpler
- **More testable**: Each component has clear responsibilities
- **More reusable**: Power-ups can be spawned from anywhere now
- **Follows Godot conventions**: Scenes manage themselves

## This is Professional Game Development Practice!