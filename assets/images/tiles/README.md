# Tile Sprites Guide

This directory contains sprites for the game's map tiles.

## Required Sprites

Place your tile sprites in this directory with these exact names:

### 1. Ground Tile - `ground.png`
- **What it is**: The walkable floor/background of the game
- **Used for**: Empty spaces where players can walk
- **Recommended size**: 16x16 pixels or larger (will auto-scale)
- **Style suggestions**: Grass, stone floor, dirt, sand, etc.
- **Example**: Green grass texture, cobblestone, dirt path

### 2. Wall Tile - `wall.png`
- **What it is**: Indestructible walls that form the map structure
- **Used for**: Border walls and internal grid walls (every other tile)
- **Recommended size**: 16x16 pixels or larger
- **Style suggestions**: Stone blocks, brick wall, metal barrier
- **Example**: Gray stone brick, concrete wall, metal panels
- **Note**: These cannot be destroyed by bombs

### 3. Destructible Block - `destructible.png`
- **What it is**: Blocks that can be destroyed by bomb explosions
- **Used for**: Obstacles that fill the maze initially
- **Recommended size**: 16x16 pixels or larger
- **Style suggestions**: Wooden crates, soft blocks, bushes, barrels
- **Example**: Wooden box, clay pot, hay bale
- **Note**: These are destroyed by bomb explosions and give 10 points each

## Fallback Colors

If sprites are not provided, the game uses these colored rectangles:

- **Ground**: Light green (`Colors.green[100]`)
- **Wall**: Dark gray (`Colors.grey[800]`)
- **Destructible**: Brown (`Colors.brown[400]`)

## Design Tips

### Visual Hierarchy
- **Walls** should look solid and sturdy
- **Destructible blocks** should look breakable/fragile
- **Ground** should be subtle so it doesn't distract from gameplay

### Style Consistency
- Keep all tiles in the same art style (pixel art, cartoon, realistic, etc.)
- Match the style of your character sprite (KawinPlayable.png)
- Use similar color palettes across all tiles

### Size and Scaling
- Original sprite size can be any square dimension (16x16, 32x32, 64x64, etc.)
- The game automatically scales sprites to fit the tile size
- Higher resolution = better quality when scaled up
- 16x16 matches your character sprite dimensions

### Transparency
- PNG format with transparency is recommended
- Transparent areas will show through to the background
- Can be used for decorative effects

## Example Tile Sets

### Classic Bomberman Style
- Ground: Green grass with subtle texture
- Wall: Gray stone blocks with mortar lines
- Destructible: Brown wooden crates with planks

### Nature Theme
- Ground: Dirt or grass
- Wall: Large rocks or tree trunks
- Destructible: Bushes or smaller rocks

### Tech/Sci-Fi Theme
- Ground: Metal grid or circuit board
- Wall: Steel plating or force fields
- Destructible: Cargo containers or energy cells

## Quick Start

1. Create three 16x16 PNG images:
   - `ground.png` - Your floor texture
   - `wall.png` - Your wall texture
   - `destructible.png` - Your breakable block texture

2. Save them in this directory: `assets/images/tiles/`

3. Run:
   ```bash
   flutter pub get
   flutter run
   ```

4. Your tiles will automatically load!

## Testing

Start the game and observe:
- **Ground tiles**: Empty walkable areas
- **Wall tiles**: Border and grid structure (darker, permanent)
- **Destructible tiles**: Everything else (can be bombed)

Place bombs and destroy destructible blocks to see them turn into ground tiles!

## Advanced: Tile Variations

Want more variety? You can extend the system by:
1. Adding more tile types to the `TileType` enum
2. Creating multiple sprite variations
3. Randomly selecting from sprite pools
4. Adding animated tiles (similar to character animation)
