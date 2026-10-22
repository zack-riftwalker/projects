# RACE CONDITION: reference images

Made by Zakaria with an image model from the prompts in `../../17-race-condition.md` (step 2). **References, not game files**: the builder draws the game's own sprites at the game's size and palette from them (or, for the backdrop, see open question 3 in `../../17-race-build.md` §11). Where an image disagrees with the build plan's geometry (`17-race-build.md` §3), **the plan wins**; take the look from the images.

| file | what | take from it |
|---|---|---|
| `tick_tock.webp` | **main character reference**: TICK (hammer up) and TOCK (hammer on shoulder) | dark bronze body, gold rivets and edges, thin red (TICK) / cyan (TOCK) trim, TOCK's cyan headband and curly bronze beard, torn tan sheepskin skirt, big wind-up key on the back, small clock on the chest |
| `sheet_keys.webp` | key frames for both | idle, walk, hammer up, strike bowing at the waist, hurt, wound down lying on the floor |
| `sheet_4dir.webp` | four-direction sheet with a palette | side views only (the game is side-on); the palette swatches |
| `background_p1.webp` | **phase-1 backdrop, empty** (26 x 30 proportions) | beam on top, dark brick, clock face mid-wall between two arched windows with a night sky and a moon, brass pipes and gears at the sides, two lamps, stone floor |
| `background_p2.webp` | **phase-2 backdrop** | red-orange heat, sparks, steam, cracked clock glass with blurred spinning hands, cracked window glass |
| `arena_full.webp` | the whole belfry with bells and escapement (mood) | how bells, chains, escapement and clock sit together; **bell positions follow the plan, not this image** |
| `bells.webp` | bells: 3 sizes × intact / cracked / fallen on the side / swinging (left, straight, right) | bronze with patina, iron chains, the clapper; the fallen ones show the open mouth and clapper |
| `escapement.webp` | the escapement: broken (red X at the pivot), swinging wildly (sparks), repaired (red dot) | anchor arms with grey pallets, rod, round brass bob |
| `clock.webp` | earlier clock face + bell | the sun-shaped hour hand and riveted rim; **its numerals are broken**: draw I-XII right |
| `background_old.webp` | first backdrop, before the arena changed in step 3 | superseded by `background_p1.webp` |

Notes for the builder:
- The clock numerals in `background_p1/p2.webp` and `arena_full.webp` have stray dots (`IV.`, `V.`): draw clean numerals.
- In `arena_full.webp` the pendulum rod passes in front of the middle bell; in the plan the escapement's bob hangs at (13, 11) above the clock face (centre (13, 15.5)), matching the image's vertical order: beam, escapement, bob, clock.
