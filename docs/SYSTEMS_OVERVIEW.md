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

## Autoloads (singletons)

Registered in `project.godot`, in this order (each needs the ones above it):

1. **CharacterDB** (`scripts/character_loader.gd`) - loads
   `data/personalities.json`, `data/items.json` and every folder in
   `data/characters/` at startup, and works out gift reactions. Warns in Godot's
   Output panel if a character is missing a field or event file. Also
   finds a character's art (see "Art" below).
2. **Relationships** (`scripts/relationship_manager.gd`) - score per
   character, which milestone scenes have fired, the current day, and who
   you've already spent time with today. Saved to `user://relationships.json`.
3. **Roster** (`scripts/roster_manager.gd`) - who's in town (active) and
   who's waiting (pool). When a level-10 scene finishes, the character
   leaves town right away and a random pool character **arrives the next
   morning**. Saved to `user://roster.json`, so restarting the game keeps
   everyone where they were.
4. **DialogueBox** (`scenes/dialogue_box.tscn` + `scripts/dialogue_box.gd`) -
   the conversation UI (built in code). Menu -> gift list -> a scene that
   plays one line per Enter/click. A level-10 scene ends with the character
   leaving.

## Scenes and scripts

- `scripts/main.gd` - room and town, the HUD (day counter, arrival/departure
  messages), the bed/sleep interaction, NPC placement. Each character keeps
  the same spot in town while they stay (4 spots for now: in front of the
  home, shop, pub and office).
- `scripts/npc.gd` + `scenes/npc.tscn` - a character standing in town.
  Press Enter near them to talk. Uses their sprite, or a coloured
  placeholder if they don't have art yet.
- `scripts/player.gd` - the player. Stands still while a conversation is open.
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

- **Inventory / shop** - gifts are unlimited for now.
- **A journal** that reveals what you've learned about each character's tastes.
- **Front / back / side sprites** and walk animation.
- **Mini games**, building interiors, music and sound.
- **Moderation flow** - `status` has room for a `"pending"` state, nothing
  reviews submissions yet.
