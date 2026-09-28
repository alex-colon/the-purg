# The Purg - Systems Overview (for you, the developer)

A plain-language map of how the game fits together. Adding a character
never requires editing GDScript - that's the point.

## The daily loop

- The HUD (top-left) shows the current **Day**.
- Each character can spend time with you **once per day**: you either
  give them a gift or say something cruel. Talking is free and unlimited.
- To start the next day, walk to the **bed** in your room and press
  **Enter**. The screen fades, the day counter goes up, everyone's
  "already spent time today" flag resets.
- **F9** wipes all saved progress and restarts (for playtesting).

### Points

| Action | Points |
|---|---|
| Gift they love | +3 |
| Gift they like | +2 |
| Neutral gift | +1 |
| Gift they dislike | -1 |
| Gift they hate | -3 |
| Be rude | -2 |

### Personalities and gifts

Each character has 1-3 **personality traits** (16 to choose from: 8 good, 8
flawed). Each item has **tags**. A trait loves and dislikes certain tags, so
how a character feels about any gift is worked out automatically. The first
trait counts double. A character's `gifts.json` can override single items
for personal quirks (Brother Tallow hates the Tarnished Coin because of what
he stole). See `docs/PERSONALITIES.md` for the full table.

Traits are hidden from the player for now: they find out by trial and error,
and by how characters react.

Score runs from -10 (skulls) to +10 (hearts). Crossing 4, 8 or 10 (in
either direction) plays that milestone scene.

## The town

The town is 2200 x 1500 px, and the camera follows you. Walk into a building's
door (just below it) to go inside; walk into the exit door at the bottom of an
interior to come back out.

| Place | What it does |
|---|---|
| **Your Lodgings** | Your room. Sleep in the bed to start a new day. |
| **Lost & Found** | The shop. Buy gift items (6 different ones each day) and sell things you don't need. |
| **The Pub** | Order a (watered-down) drink for 3 coins, or bet on **Bone Dice** in the back. |
| **Bureau of Case Review** | **Resident files**: standing with everyone, plus every taste you've discovered. Also check on your own case. |
| **The Chapel** | Half-built and never finished. Light a prayer candle out front. |
| **Notice Board** | 3 daily requests from residents. Bring the item they want for coins. Each request also teaches you something they love. |
| **The Reflecting Pool** | Toss in 1 coin (once a day) to see something a random resident loves or hates. |
| **Meadow / Herb Patch** | Pick Wildflowers / Herbal Tea. They grow back every morning. |
| **The Junkyard / The Creek** | Dig or fish once a day for a random item or a few coins. |
| **Bright Gate / Ember Gate** | Where residents go when their case is called: saints through the bright gate, sinners through the ember gate, whatever you felt about them. |
| **Arrival Station** | Each new resident stands here on the day they arrive. |
| **Memorial Garden** | A headstone for everyone who has left, with the day, the gate and how they felt about you. |

When a resident's goodbye scene ends, you actually watch them walk to their gate.

### Economy

You start with 20 coins and a few items. Gifts now come from your bag, so they
run out. Coins come from notice-board requests, selling things, foraging spots,
the junkyard, the creek and gambling. Everything costs what its `price` in
`data/items.json` says. Selling pays 40% of that.

## Autoloads (singletons)

Registered in `project.godot`, in this order (each needs the ones above it):

1. **CharacterDB** (`scripts/character_loader.gd`) - loads
   `data/personalities.json`, `data/items.json` and every folder in
   `data/characters/` at startup, and works out gift reactions. Warns in Godot's
   Output panel if a character is missing a field or event file. Also
   finds a character's art (see "Art" below).
2. **Relationships** (`scripts/relationship_manager.gd`) - the save state for the
   whole run: scores, milestone scenes, the day, who you've spent time with today,
   **coins, your item inventory, what you've learned about tastes, and today's
   one-per-day flags and notice board**. Saved to `user://relationships.json`.
3. **Roster** (`scripts/roster_manager.gd`) - who's in town (active) and
   who's waiting (pool). When a level-10 scene finishes, the character
   leaves town right away and a random pool character **arrives the next
   morning**. It also records where and when everyone left (for the gates and the
   memorial) and the day newcomers arrived. Saved to `user://roster.json`, so
   restarting the game keeps everyone where they were.
4. **DialogueBox** (`scenes/dialogue_box.tscn` + `scripts/dialogue_box.gd`) -
   the conversation UI (built in code). Menu -> gift list -> a scene that
   plays one line per Enter/click. A level-10 scene ends with the character
   leaving.

## Scenes and scripts

- `scripts/map_data.gd` - the layout of every place (bedroom, town, and the three
  interiors) as plain data: what to draw, what's solid, where the doors are,
  which spots you can interact with, and where residents stand. **To add or move
  a building or a spot, edit this file only.** Its comments explain the rules.
- `scripts/main.gd` - loads a map, draws it, builds its walls, moves you through
  doors, runs the camera, finds the spot you're standing at, runs the HUD (day,
  coins, messages) and places residents. Residents keep the same spot while they
  stay in town; a newcomer stands at the station on their first day.
- `scripts/town_actions.gd` - what each spot *does* (shop, board, pool, dice,
  bureau files, ...). To add a new kind of spot: give it a `kind` in `map_data.gd`,
  then add a branch to `run()` and a function.
- `scripts/menu_ui.gd` - the one reusable pop-up (title, text, buttons) every
  town screen uses.
- `scripts/npc.gd` + `scenes/npc.tscn` - a resident standing in town. Press Enter
  near them to talk. When their case is called they walk to their gate.
- `scripts/player.gd` - the player. Stands still while any menu or conversation is open.
- `scripts/sprite_util.gd` - shows a sprite at a consistent on-screen height
  based on the *visible* artwork, ignoring transparent margins.

## Art

`CharacterDB.get_art_path()` looks for a character's image in this order:
1. the `sprite` / `portrait` path in `character.json` (if the file exists)
2. `res://assets/characters/npcs/sprites/<id>.png` and
   `res://assets/characters/npcs/portraits/<id>.png`
3. nothing - the NPC is drawn as a coloured blob and the dialogue box has
   no portrait.

So the simplest way to add art is to save the two images with the
character's id as the file name, e.g. `sprites/innkeeper.png`. Sprites are
scaled to 96px tall; override per character with `"sprite_height"` in
`character.json`. `tools/art_pipeline/process_character_art.py` turns one
AI-generated image into a clean sprite + portrait.

## Characters included

| id | Name | Alignment | Traits | Starts |
|---|---|---|---|---|
| `ghost_gal` | Wisp | saint | cheerful, compassionate | in town |
| `silent_monk` | Brother Tallow | sinner | devout, greedy | in town |
| `innkeeper` | Dolores Marrow | sinner | wrathful, greedy | pool |
| `professor` | Ambrose Quill | saint | scholarly, humble | pool |

Dolores is the schema stress-test: hell-bound, and her skull-side scenes are
the warm ones.

## Not built yet

- **Your own case review** - the Bureau tells you it's "pending". The real ending
  (what triggers it, how it reflects how you treated people) isn't written yet.
- **Character schedules** - residents stand in one place all day.
- **Front / back / side sprites** and walk animation.
- **Music and sound.**
- **Loading characters from outside the project folder** (for community submissions).
- **Moderation flow** - `status` has room for a `"pending"` state, nothing
  reviews submissions yet.
