# The Purg — Character Submission Template

Anyone can submit a character (an "OC") to The Purg. This document is the
full spec. If your character folder matches this shape, the game will
find and load it automatically — no code needed on your part.

**Note:** this is the v0.1 draft schema. It works and is fully playable
today, but fields may be added (animation format, audio format,
moderation status) as the game develops. Once submissions open to the
public, this file — not the example below — will be the source of truth.

## Folder structure

Your character is one folder, named with a short lowercase id
(letters, numbers, underscores only — this is permanent, so pick
carefully):

```
your_character_id/
  character.json
  events/
    heart_4.json
    heart_8.json
    heart_10.json
    skull_4.json
    skull_8.json
    skull_10.json
  gifts.json
  sprite.png     (transparent background)
  portrait.png   (transparent background)
  theme.ogg      (planned — audio pipeline not finalized yet)
```

Art can live in the game's shared art folders instead. If the files are
named after the character's id, the game finds them automatically:
`assets/characters/npcs/sprites/<id>.png` and
`assets/characters/npcs/portraits/<id>.png`.

## Generating art without an artist

The game's own launch characters are made this way, so this is a
proven path, not a guess. It's a two-step process: generate one image
with an AI image tool, then run it through a small script that turns
it into the two files the game actually needs.

### Step 1 — generate one full-body image

Use this prompt (swap the bracketed part for your character, keep the
rest as-is — the shared wording is what keeps everyone's art feeling
like it belongs in the same game):

> A single full-body anime-style pixel art character: [CHARACTER DESCRIPTION — appearance, outfit, colors, mood]. Standing in a neutral idle pose, facing directly forward, arms at sides, centered in frame, character fills about 70% of the frame height. Thick clean pixel-art outlines, flat cel-shaded color blocks, soft muted color palette. Fully transparent background, no ground shadow, no text or watermark, no other objects in frame. Square image, high resolution.

Generate a few times if needed and pick the cleanest result — a
front-facing pose with a fully transparent background matters most; a
soft/painterly look is fine and expected, since the next step handles
turning it into real pixel art.

### Step 2 — run it through the processing script

`tools/art_pipeline/process_character_art.py` (in the project repo)
takes that one image and produces both `sprite.png` and `portrait.png`
sized and formatted correctly:

```
python3 tools/art_pipeline/process_character_art.py your_image.png output_folder/ \
  --bust-top 0.0 --bust-bottom 0.45
```

`--bust-top`/`--bust-bottom` control which vertical slice of the image
becomes the portrait (as a fraction of the figure's height, 0 = very
top). Start around `0.0`–`0.45` for a character with nothing floating
above their head, or shift both numbers down if they have a halo,
flame, hat, etc. — open the output and adjust if the face gets cut off
or the crop looks off-center, then rerun. Copy the resulting
`sprite.png` and `portrait.png` into your character folder when
they look right.

## character.json

```json
{
	"id": "your_character_id",
	"name": "Display Name",
	"alignment": "saint",
	"status": "pool",
	"personality": ["cheerful", "compassionate"],
	"description": "One or two sentences: who they were, how they died, why they're stuck here.",
	"home_building": "your_character_id_home",
	"portrait": "portrait.png",
	"sprite": "sprite.png",
	"theme_music": "theme.ogg",
	"idle_dialogue": [
		"A line they might say on any random encounter.",
		"Another one. A few of these keeps them feeling alive."
	]
}
```

| Field | Notes |
|---|---|
| `id` | Must match the folder name. Permanent — save files reference it forever. |
| `name` | What players see. |
| `alignment` | `"saint"` (heaven-bound) or `"sinner"` (hell-bound). |
| `status` | Always submit as `"pool"`. The game promotes characters to `"active"` automatically when a slot opens up. |
| `personality` | 1 to 3 trait ids from `docs/PERSONALITIES.md`. The **first counts double**. This decides which gifts the character loves and hates. |
| `description` | Short bio/hook. Not shown in-game yet, but used for review. |
| `home_building` | Informational for now (which building they belong to). The game places residents in town automatically. |
| `portrait` / `sprite` | Relative paths within your folder — normally just `"portrait.png"` and `"sprite.png"` if you followed the pipeline above. |
| `theme_music` | Optional. Audio pipeline isn't finalized yet. |
| `placeholder_color` | Optional hex colour (e.g. `"a1584f"`) used for the placeholder blob until real art exists. |
| `sprite_height` | Optional number: on-screen height of the sprite in pixels (default 96). |
| `idle_dialogue` | Array of throwaway lines shown outside of milestone events. |

## gifts.json (optional)

Gift tastes come from the character's `personality`, so this file is **not
required**. Use it for two things: personal quirks, and the character's own
voice.

```json
{
	"loves": ["wildflowers"],
	"hates": ["old_coin"],
	"reactions": {
		"love": "Oh! {item}! Thank you!",
		"like": "Aw, the {item}. That's sweet.",
		"neutral": "Oh. The {item}. Thanks, I guess.",
		"dislike": "The {item}? Um. No.",
		"hate": "{item}?! Get that away from me!"
	},
	"rude_reactions": [
		"Wow. Rude.",
		"Was that necessary?"
	]
}
```

- `loves` / `likes` / `dislikes` / `hates` override the personality for those
  specific items. Leave out any you don't need.
- `reactions` and `rude_reactions` are the character's own lines. Anything
  missing falls back to the reactions of their first personality trait.
- `{item}` is replaced with the item's name. Item names can be plural
  ("Wildflowers"), so write "the {item}" or just "{item}" rather than "a {item}".
- (Older files may also hold `"personality"` here instead of in `character.json`. Either works.)

## Events

Every character needs six event files in `events/`, one per relationship
milestone. Hearts are the "saint" track (player is kind to them), skulls
are the "sinner" track (player is unkind to them) — both tracks exist for
every character regardless of their own alignment.

```json
{
	"type": "heart",
	"level": 8,
	"departs": false,
	"dialogue": [
		{ "speaker": "Display Name", "text": "First line of the scene." },
		{ "speaker": "Display Name", "text": "Second line." }
	]
}
```

| Field | Notes |
|---|---|
| `type` | `"heart"` or `"skull"` — must match the filename prefix. |
| `level` | `4`, `8`, or `10` — must match the filename number. |
| `departs` | Set `true` **only** on `heart_10.json` and `skull_10.json`. This is the "case called" event — the character says goodbye and leaves town for good. |
| `dialogue` | An ordered array of lines. Each has a `speaker` and `text`. |

The `heart_10` / `skull_10` events are a character's send-off — write
them like an ending, because for that player, they are one.

## Submitting

Submission process (review, where to send folders, turnaround) isn't
set up yet — the developer is still building the core game. This
document will be updated with submission instructions once that's
ready. For now, this schema is what the game's loader actually reads,
so it's safe to build against.
