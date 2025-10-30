# 🎮 User Interaction Guide - ISNEXIS Bomberman

This document explains how players interact with the game, including all input methods, UI elements, feedback systems, and user flows.

## 📋 Table of Contents
- [Main Menu Interactions](#main-menu-interactions)
- [Player Selection Flow](#player-selection-flow)
- [Multiplayer Setup Flow](#multiplayer-setup-flow)
- [In-Game Interactions](#in-game-interactions)
- [UI Feedback Systems](#ui-feedback-systems)
- [Game States & Transitions](#game-states--transitions)

---

## 🏠 Main Menu Interactions

### Navigation
**Location**: Main menu screen upon launch

**Available Options**:
1. **START GAME** - Launch single-player mode
2. **MULTIPLAYER** - Enter multiplayer setup
3. **EXIT** - Close the application

**Input Methods**:
- **Mouse Click**: Click on any menu option
- **Keyboard Navigation**: 
  - Arrow keys (↑/↓) to highlight options
  - Enter/Space to select highlighted option
- **Touch**: Tap on menu buttons (mobile/tablet)

**Visual Feedback**:
- Hovered/selected button changes to bright green (`#9BBC0F`)
- Glow effect appears around active button
- Title has gradient animation (yellow to orange)
- Pixel grid background for retro aesthetic

---

## 👥 Player Selection Flow

### Single Player Mode

**Step 1: Choose Number of Players**
- **Range**: 2-4 players (minimum 2 enforced)
- **Interaction**: Click on number buttons (2, 3, or 4)
- **Visual Feedback**: 
  - Selected number highlighted in green
  - Other numbers shown in black with green border
  - Default selection: 2 players

**Step 2: Select Characters**
- **Player 1 (You)**:
  - Always marked as "👤 HUMAN" (green badge)
  - Cannot be changed to bot
  - Select from 4 character skins
  
- **Players 2-4 (Bots)**:
  - Always marked as "🤖 BOT" (orange badge)
  - Automatically set as AI-controlled
  - Each bot needs a character selection

**Character Selection Interaction**:
- Click on character portraits to select
- Selected character has:
  - Bright green background
  - Thicker border (4px vs 2px)
  - Character name in black text
- Unselected characters:
  - Dark background
  - Green border
  - Character name in green

**Validation**:
- "START GAME" button is disabled (grey) until:
  - All player slots have characters selected
  - Each player has a valid character choice
- Enabled button:
  - Bright green background
  - Glowing border effect
  - Black text
  - Clickable

**Navigation**:
- **Back Arrow**: Return to main menu (top-left)
- **START GAME**: Launch the game (bottom, centered)

---

## 🌐 Multiplayer Setup Flow

### Create or Join Room

**Initial Screen**:
- **Input Fields**:
  1. Player Name (text input)
  2. Backend URL (text input with default)
  3. Room Code (for joining only)

**Create Room Flow**:
1. Enter your display name
2. Click "CREATE ROOM"
3. System generates 6-digit room code
4. Transition to multiplayer lobby

**Join Room Flow**:
1. Enter your display name
2. Enter room code received from host
3. Enter backend server URL
4. Click "JOIN ROOM"
5. Connect to existing room
6. Transition to multiplayer lobby

**Visual Feedback**:
- Input fields have retro green borders
- Active input field highlighted
- Loading spinner during connection
- Error messages displayed for connection failures

### Multiplayer Lobby

**Room Information Display**:
- **Room Code**: Prominently displayed at top
- **Player List**: Shows all players in room with:
  - Player name
  - Character selection
  - Host indicator (👑 with yellow border)

**Character Selection**:
- Same interaction as single-player
- Real-time synchronization:
  - Your selection broadcasts to all players
  - Other players' selections appear instantly
  - Each player sees everyone's current character

**Host Controls**:
- **Host Player**:
  - Yellow border around player card
  - 👑 HOST label
  - "START GAME" button enabled (green, glowing)
  
- **Non-Host Players**:
  - Green border on player card
  - "WAITING FOR HOST..." button (grey, disabled)
  - Cannot start the game

**Host Migration**:
- If host leaves, first remaining player becomes new host
- Automatic transition with visual update
- Console logs show host change
- New host's button becomes active

**Player Join/Leave**:
- New player appears in list immediately
- Leaving player removed from list
- Player count updates (X/4)

**Navigation**:
- **Back Arrow**: Leave room and return to setup screen

---

## 🎮 In-Game Interactions

### Movement Controls

**Keyboard (Primary)**:
- **Arrow Keys** (↑ ↓ ← →): Move in four directions
- **WASD Keys**: Alternative movement controls
- **Space Bar**: Place bomb

**Touch/Mobile**:
- **Virtual Joystick**: Appears on screen
  - Drag in any direction to move
  - Release to stop
- **Bomb Button**: Tap to place bomb

**Movement Behavior**:
- Grid-based movement (tile by tile)
- Smooth interpolation between tiles
- Cannot move through walls or bombs
- Player sprite updates direction

### Bomb Placement

**Trigger**:
- Press Space bar (keyboard)
- Click bomb button (UI)
- Tap screen button (mobile)

**Constraints**:
- Maximum bombs based on powerup collection
- Default: 1 bomb at a time
- Bombs cannot be placed on occupied tiles
- Must wait for bomb to explode before placing new one (if at max)

**Visual Feedback**:
- Bomb appears with sprite/colored square
- Fuse timer visible (optional sprite animation)
- Sound effect on placement (if implemented)

### Powerup Collection

**Interaction**: Automatic on contact
- Walk over powerup tile
- Instant application of effect
- Powerup disappears from game

**Types & Effects**:
1. **💚 Extra Life** (+1 Health)
   - Allows one more hit before death
   - Stacks with multiple collections
   
2. **💣 Extra Bomb** (+1 Max Bombs)
   - Increase simultaneous bomb capacity
   - Place more bombs at once
   
3. **🔥 Explosion Range** (+1 Radius)
   - Bombs explode further in all directions
   - More destructive power

**Visual Feedback**:
- Powerup disappears instantly
- Stats sidebar updates immediately
- Console log shows collection
- (Optional) Particle effect on collection

### Damage & Death

**Taking Damage**:
- Hit by explosion
- Health decreases by 1
- **Invincibility Period**: 2 seconds
  - Player cannot take damage
  - Visual indicator (flashing/transparency)
  - Can move and place bombs

**Death**:
- Health reaches 0
- Player sprite disappears
- **Single Player**: 
  - Game ends immediately
  - Show "Game Over" screen
- **Multiplayer**:
  - Enter spectator mode
  - Camera continues to show arena
  - Wait for game to end
  - Winner screen displays when 1 player remains

---

## 📊 UI Feedback Systems

### Stats Sidebar (Right Side)

**Displayed Information**:
```
PLAYER 1
❤️ Health: X
💣 Bombs: X
🔥 Range: X
```

**Real-time Updates**:
- Health changes on damage/powerup
- Bomb count shows current/max
- Range shows explosion radius
- Updates immediately on stat change

### Controls Panel (Bottom)

**Keyboard Layout Visual**:
- Arrow keys diagram
- WASD keys diagram
- Space bar for bomb
- Helps new players learn controls

**Touch Controls**:
- Virtual joystick on left
- Bomb button on right
- Only visible on touch devices

### In-Game Messages

**Console Logs** (Developer Mode):
- Player movement coordinates
- Bomb placement confirmation
- Powerup collection details
- Network synchronization events
- Damage and death notifications

**On-Screen Indicators**:
- Invincibility flash effect
- Explosion animations
- Bomb countdown (visual)

---

## 🔄 Game States & Transitions

### State Flow Diagram

```
Main Menu
    ├─→ START GAME → Player Selection → In-Game (Single Player)
    │                                      ├─→ Game Over Screen
    │                                      └─→ Winning Screen
    │
    ├─→ MULTIPLAYER → Setup Screen → Lobby → In-Game (Multiplayer)
    │                                              ├─→ Winning Screen (All)
    │                                              └─→ Spectator Mode (Dead)
    │
    └─→ EXIT → Close Application
```

### Transition Animations

**Screen Changes**:
- Fade in/fade out effects
- Instant navigation (no loading screens)
- Smooth state transitions

**In-Game Transitions**:
- Bomb explosion: Radial animation
- Player death: Fade out
- Powerup collection: Quick disappear
- Victory: Overlay modal

---

## 🎯 User Experience Features

### Accessibility

**Visual**:
- High contrast colors (Game Boy palette)
- Clear tile boundaries
- Distinct character colors
- Large UI elements

**Controls**:
- Multiple input methods (keyboard/touch)
- Alternative key bindings (arrows/WASD)
- One-button bomb placement
- Simple grid movement

**Feedback**:
- Immediate visual response
- Clear button states (enabled/disabled)
- Obvious selection highlights
- Status indicators always visible

### Responsive Design

**Screen Adaptation**:
- Game scales to window size
- Maintains aspect ratio
- Tile size calculated dynamically
- UI elements positioned responsively

**Platform Support**:
- Web (Chrome recommended)
- Windows desktop
- Android mobile
- iOS mobile

---

## 🔊 Interaction Feedback Summary

| Action | Visual Feedback | Audio Feedback | UI Update |
|--------|----------------|----------------|-----------|
| Move Player | Sprite moves smoothly | (Optional) Step sound | Position updates |
| Place Bomb | Bomb appears on grid | (Optional) Placement sound | None |
| Bomb Explodes | Explosion animation | (Optional) Explosion sound | Possible damage |
| Take Damage | Flash/invincibility effect | (Optional) Damage sound | Health -1 |
| Collect Powerup | Powerup disappears | (Optional) Collect sound | Stats +1 |
| Player Dies | Sprite disappears | (Optional) Death sound | Screen change |
| Menu Hover | Color change, glow | (Optional) Hover sound | None |
| Menu Select | Button press effect | (Optional) Click sound | Screen transition |

---

## 📱 Platform-Specific Interactions

### Web (Chrome)

**Input**:
- Keyboard for all controls
- Mouse for menu navigation
- Click for bomb placement (UI button)

**Features**:
- Full keyboard support
- Precise mouse control
- Fast response time

### Mobile (Android/iOS)

**Input**:
- Virtual joystick for movement
- Touch button for bombs
- Tap for menu navigation

**Features**:
- Touch-optimized UI
- Larger hit boxes
- Gesture support

### Desktop (Windows)

**Input**:
- Keyboard primary
- Mouse for menus
- Gamepad support (future)

**Features**:
- Native window controls
- Alt+F4 to exit
- Fullscreen support

---

## 🎓 Learning Curve

### First-Time Player Experience

**Tutorial Elements** (Implicit):
1. Controls panel shows key layout
2. Character selection introduces game mechanics
3. First bomb teaches explosion mechanics
4. Powerup discovery teaches progression
5. Death teaches consequence

**Skill Progression**:
- Beginner: Learn movement and bomb placement
- Intermediate: Strategic bomb timing, powerup hunting
- Advanced: Trap opponents, chain reactions, speed running

---

## 🔧 Customization & Settings

### Current Limitations
- No in-game settings menu (removed)
- Audio controls not implemented
- Control remapping not available
- Graphics options limited

### Future Enhancements
- Adjustable volume
- Custom key bindings
- Graphics quality options
- Accessibility options

---

## 💡 Tips for Best User Experience

1. **Use Full Screen**: Better immersion and control precision
2. **Stable Connection**: Essential for smooth multiplayer
3. **Clear Browser Cache**: After updates for latest version
4. **Use Chrome**: Best performance and compatibility
5. **Keyboard Recommended**: Faster and more precise than touch

---

**This interaction model is designed to be intuitive, responsive, and enjoyable for both new and experienced players!** 🎮✨
