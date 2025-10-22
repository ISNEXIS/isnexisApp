# Bomb Sprites

Place your custom bomb sprites in this directory.

## Option 1: Character-Specific Bomb Sprites

Each character can have their own unique bomb sprite!

**File naming:**
- `bomb_character1.png` - Bomb for Character 1 (Kawin)
- `bomb_character2.png` - Bomb for Character 2
- `bomb_character3.png` - Bomb for Character 3
- `bomb_character4.png` - Bomb for Character 4

**How it works:**
- When a player places a bomb, it tries to load their character-specific sprite
- If character-specific sprite not found, falls back to generic bomb
- If generic bomb not found, uses a colored circle matching the player's color

## Option 2: Generic Bomb Sprite

**File naming:**
- `bomb.png` - Used by all characters

**How it works:**
- All characters share the same bomb sprite
- Simpler if you want consistent bomb appearance
- Falls back to colored circle if not found

## Fallback Behavior (Without Sprites)

If no sprites are provided, bombs appear as colored circles matching each player:
- **Character 1**: Blue circle
- **Character 2**: Red circle
- **Character 3**: Green circle
- **Character 4**: Yellow circle

## Requirements

- **Format**: PNG with transparency recommended
- **Size**: Square dimensions (16x16, 32x32, 64x64, etc.)
- **Recommended**: 16x16 to match character sprites
- **Style**: Classic round bomb, cartridge, mine, etc.

## Visual Effects

All bombs (sprite or fallback) have these effects:
- **Timer countdown**: 3 seconds until explosion
- **Flash warning**: In the last second, bomb flashes red rapidly
- **Automatic scaling**: Sprites scale to 66% of tile size

## Design Tips

### Character-Specific Bombs
- Different colors per character
- Unique designs that match character personality
- Example: Character 1 could have a tech bomb, Character 2 a classic round bomb

### Generic Bomb
- Neutral design that works for all characters
- Classic black bomb with fuse
- Modern explosive device

### Color Coordination
- Consider matching bomb colors to character colors
- Make bombs visible against all tile backgrounds
- Ensure the red flash effect is visible on your sprite

## Priority

**Start with one of these:**

1. **Character-specific** (if you want unique bombs):
   ```
   bomb_character1.png
   ```

2. **Generic** (if you want simple/consistent):
   ```
   bomb.png
   ```

3. **No sprites** (uses colored circles):
   - Works perfectly! No sprites needed.

## Testing

1. Select different characters in player selection
2. Place bombs with each character
3. Observe if character-specific sprites load
4. Watch the flash effect in the last second
5. See the explosion when timer reaches 0

## Examples

### Character-Specific Theme
- Character 1 (Kawin): Blue hi-tech energy bomb
- Character 2: Red classic round bomb with fuse
- Character 3: Green nature/organic explosive
- Character 4: Yellow lightning/electric bomb

### Generic Theme
- Classic black cartoon bomb with lit fuse
- Modern gray explosive device
- Fantasy magic orb

The system is flexible - use what fits your game's style! 🎨💣

