# Personality Traits and Gift Tags

Every character has **1 to 3 personality traits** (listed in `character.json` under `"personality"`).
Every gift item has **tags**. A trait loves some tags and dislikes others, so the game works out
how a character feels about every item automatically.

- The **first trait listed counts double**, so mixed characters lean toward their main trait.
- For each tag on an item: +1 if a trait loves it, -1 if it dislikes it (x2 for the first trait).
- Total 3 or more = **love** (+3 points). 1 to 2 = **like** (+2). 0 = **neutral** (+1).
  -1 to -2 = **dislike** (-1). -3 or less = **hate** (-3).
- A character's `gifts.json` can override individual items for personal quirks.

Traits are not the same as destination: a saint can have flawed traits, and a sinner can be compassionate.

## Good traits

| Trait | Vibe | Loves | Dislikes |
|---|---|---|---|
| `compassionate` | Soft-hearted; can't stand cruelty. | gentle, sweet | violent, vice |
| `devout` | Faith comes first. | holy, gentle | dark, vice |
| `scholarly` | Curious and bookish. | intellectual, beautiful | violent, risky |
| `humble` | Simple tastes, no fuss. | natural, sentimental | luxury |
| `cheerful` | Can't help being upbeat. | playful, sweet | dark |
| `artistic` | Sees beauty in everything. | beautiful, natural | violent |
| `loyal` | Attached to people and keepsakes. | sentimental, holy | risky |
| `adventurous` | Restless; travels light. | risky, natural | sentimental |

## Flawed traits

| Trait | Vibe | Loves | Dislikes |
|---|---|---|---|
| `vain` | Image is everything. | beautiful, luxury | sentimental |
| `greedy` | Always counting. | luxury, risky | sentimental, holy |
| `cruel` | Enjoys other people's discomfort. | violent, dark | gentle, holy |
| `gluttonous` | Can't say no. | sweet, vice | intellectual |
| `reckless` | Lives for the thrill. | risky, vice | intellectual, natural |
| `bitter` | Resents everyone else's luck. | dark, sentimental | playful, beautiful |
| `scheming` | Always working an angle. | intellectual, dark | holy, sentimental |
| `wrathful` | Short fuse. | violent, vice | gentle, playful |

## Tags

`gentle`, `natural`, `sweet`, `holy`, `intellectual`, `beautiful`, `sentimental`, `playful`, `luxury`, `vice`, `dark`, `violent`, `risky`

## Items

| Item id | Name | Tags |
|---|---|---|
| `wildflowers` | Wildflowers | gentle, natural, beautiful |
| `sweet_bun` | Sweet Bun | sweet, gentle |
| `old_coin` | Tarnished Coin | luxury, sentimental |
| `prayer_beads` | Prayer Beads | holy, sentimental |
| `whiskey` | Cheap Whiskey | vice, risky |
| `black_candle` | Black Candle | dark, beautiful |
| `paperback` | Paperback Book | intellectual, sentimental |
| `bone_dice` | Bone Dice | risky, vice |
| `rusty_knife` | Rusty Knife | violent, dark |
| `fine_perfume` | Fine Perfume | luxury, beautiful |
| `holy_water` | Vial of Holy Water | holy, gentle |
| `old_photograph` | Old Photograph | sentimental, gentle |
| `wooden_toy` | Wooden Toy | playful, natural |
| `chocolates` | Box of Chocolates | sweet, luxury |
| `sketchbook` | Blank Sketchbook | beautiful, intellectual |
| `herbal_tea` | Herbal Tea | gentle, natural |
| `mystery_powder` | Mystery Powder | vice, risky, dark |

To add an item, add an entry to `data/items.json` with 2-3 tags from the list above.
Every character then reacts to it in character, with no other changes needed.
