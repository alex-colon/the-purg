# The Purg — Systems Overview (for you, the developer)

This is a plain-language map of what got added and how it fits together.
Nothing here requires editing GDScript to add a new character — that's
the whole point.

## The four new autoloads (singletons)

Registered in Project Settings → Autoload (already set up in
`project.godot`), in this order, because each depends on the ones before it:

1. **CharacterDB** (`scripts/character_loader.gd`)
   On game start, scans `res://data/characters/` and loads every
   subfolder's `character.json` plus its `events/*.json` files into
   memory. This is the entire "content pipeline" — a new character
   folder is all it takes.

2. **Relationships** (`scripts/relationship_manager.gd`)
   Tracks a single score per character, -10 to +10 (positive = hearts,
   negative = skulls). Checks for milestone crossings (4/8/10) and
   fires signals when one unlocks. Saves/loads automatically to
   `user://relationships.json`, so progress survives closing the game.

3. **Roster** (`scripts/roster_manager.gd`)
   Splits all loaded characters into `active_ids` (currently in town)
   and `pool_ids` (waiting) based on each character's `status` field.
   Listens for `Relationships.case_called` — when a character hits
   level 10 on either track, Roster removes them from `active_ids` and
   promotes a random character from `pool_ids` to take their place.

4. **DialogueBox** (`scenes/dialogue_box.tscn` + `scripts/dialogue_box.gd`)
   A simple UI panel, present the whole game (as an autoload scene, not
   just a script). `DialogueBox.show_for_character(id)` shows that
   character's most relevant line — the highest unlocked milestone, or
   idle chatter otherwise — with two buttons: give a gift (+2) or be
   rude (-2).

## The NPC scene

`scenes/npc.tscn` + `scripts/npc.gd` — a `CharacterBody2D` with an
`Area2D` "Detector" child. When the player walks into range, it shows a
prompt; pressing Enter (the default `ui_accept` action) opens the
DialogueBox for that character. It currently draws itself as a plain
pale rectangle — same placeholder approach as your existing Player and
buildings. Swap `_draw()` for a `Sprite2D`/`AnimatedSprite2D` once art
exists.

## How main.gd ties it together

`build_town()` now calls `spawn_npcs()`, which instantiates one NPC
scene per id in `Roster.active_ids`, at fixed placeholder positions.
`enter_room()` clears them out (NPCs only exist in town for now).
`main.gd` also listens for `Roster.character_departed` /
`character_arrived` and re-spawns the NPC list live if you're standing
in town when someone's case gets called.

## What's included as a working example

- **`data/characters/ghost_gal/`** — Wisp, a full reference character
  with all six events written out. Fully playable: walk up to her,
  press Enter, give gifts or be rude, watch her case eventually get
  called and her disappear from town.
- **`data/characters/silent_monk/`** — Brother Tallow, a minimal
  `status: "pool"` character with no events yet. His only job is to
  prove the cycling logic: when Wisp's case is called, he's the one
  who gets randomly promoted into her spot.

## The art pipeline

`tools/art_pipeline/process_character_art.py` turns one AI-generated
full-body character image into the two files the game actually uses:
a small palette-reduced `sprite.png` (64x96, real pixelation via hard
downscale + quantize + nearest-neighbor upscale) and a more detailed
`portrait.png` (256x256, cropped to the bust). It trims stray
near-invisible alpha pixels before finding the image's bounding box,
which matters — AI-generated "transparent" backgrounds sometimes leave
faint artifacts that throw off a naive crop. See
`docs/CHARACTER_TEMPLATE.md` for the actual generation prompt and
usage instructions. Wisp's and the player's art were both produced
this way — check `assets/characters/npcs/townies/ghost_gal_sprite.png`
etc. for reference output.

`npc.gd` and `player.gd` both check for a real sprite file at
`_ready()` and load it into a `Sprite2D` child if present, falling
back to the old placeholder rectangle otherwise — so a character
works whether or not their art exists yet. `dialogue_box.gd` does the
same for portraits.

## What's deliberately NOT built yet (by your own call)

- **Content moderation** — the `status` field already has room for a
  future `"pending"` state, but there's no review flow. Not needed
  until external submissions are actually open.
- **Animation** — sprites are currently static single images (no walk
  cycle, no directional facing). Fine for now; revisit once the core
  loop feels good.
- **Building-specific spawn points** — NPCs currently spawn at two
  hardcoded positions. Worth revisiting once buildings become real
  scenes instead of drawn shapes.

## Suggested next steps

1. Playtest the loop as-is (see the walkthrough below).
2. Decide on an actual art style/pipeline for character sprites — this
   unblocks a lot of "does this feel like a real game" progress.
3. Write 2-3 more reference characters by hand to stress-test whether
   the JSON schema holds up for very different personalities (a
   "sinner" character told from the skull side would be a good test).
4. Only after that: formalize `docs/CHARACTER_TEMPLATE.md` for public
   submission and think about moderation.

## Quick playtest walkthrough

1. Open the project in Godot 4.7, run the main scene.
2. Walk down through the door to reach the town.
3. Walk to the placeholder NPC near the "home" building (Wisp) and
   press Enter.
4. Click "Give Gift" repeatedly (or "Be Rude" to test the skull track)
   and watch her dialogue line change as you cross 4, 8, then 10.
5. At 10, her case is called, she disappears from town, and Brother
   Tallow appears in her place at the same/next spawn slot.
