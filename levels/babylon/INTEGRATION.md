# Babylon gardens blockout

Inspection geometry for stage 1 only. The published game is still `index.html`. This folder does not replace legacy levels, the legacy player, or a release export.

Open `project.godot` at the repository root in Godot 4.3 and run the main scene, or run:

```
godot --path . res://levels/babylon/gardens_level.tscn
```

Arrow keys pan the inspection camera. `-` and `=` zoom it. That camera is not the hero.

## What runs

- Placeholder terrain, gardens dressing, a translucent waterfall, and readable story plaques.
- Collision on layer 1 (`Geometry/Collision`), tile size 16.
- Map `gardens_map.txt`, 140 by 26 tiles.

## What does not run

There is no hero in this scene. `res://gameplay/babylon/` is not in this repo, and the legacy `res://player/player.tscn` must not be instanced here: the shipped export’s player is a different move set (double jump, wall jump, pogo, sword, dash). This scene does not simulate clay, dash, reflect, stomp, sword, or enemy AI. `res://enemies/babylon/` and `res://ui/babylon/` are untouched.

Run speed 130 and a 48px single jump are untested estimates. The required route never needs more than a 1-tile step. The optional balcony uses one 2-tile step. There is no mandatory clay-only gap. Clay size 32×16, 4s life, one charge, restore on real ground only, remains a draft on the pickup marker.

## Assembler node paths

Paths are relative to `GardensLevel` (`res://levels/babylon/gardens_level.tscn`).

| Path | Group | Use |
| --- | --- | --- |
| `Markers/PlayerSpawn` | `babylon_player_spawn` | Place the new hero. `take_damage(amount, from_position)` stays on the hero, which also owns invulnerability. |
| `Markers/Checkpoints/Checkpoint_cp_opening` | `babylon_checkpoint` | Safe respawn at tile (8, 19). |
| `Markers/Checkpoints/Checkpoint_cp_before_guard` | `babylon_checkpoint` | Tile (60, 19), before the guard. |
| `Markers/Checkpoints/Checkpoint_cp_before_hazard` | `babylon_checkpoint` | Tile (110, 19). |
| `Markers/Checkpoints/Checkpoint_cp_terrace` | `babylon_checkpoint` | Tile (134, 15), elevated rest. |
| `Markers/Signs/Sign_01` … `Sign_04` | `babylon_story_sign` | Story text. `unlocks_ability` is false. Sign 3 does not grant clay. |
| `Markers/Abilities/ClayPlatformPickup` | `babylon_ability_pickup` | Explicit clay pickup at (48, 19). UI `ability_requested(id)` should connect once to the ability request, not also synthesize input. This scene does not emit that signal. |
| `Markers/Guards/GardensGuardSpawn` | `babylon_guard_spawn` | One gardens-guard marker at (74, 19). Not an enemy. Any future touch, including from above, hurts; there is no stomp. On `respawn_started`, reset this spawn before the hero is re-enabled, then emit `respawned`. |
| `Dressing/SecretRibbon` | visual only | Hanging ribbon behind the falls. `visual_class = hanging_ribbon`. |
| `Markers/Collectibles/PrincessRibbonL1` | `babylon_princess_ribbon` | Optional. Not required to exit or to unlock clay. No save or inventory UI. |
| `Dressing/RouteGuides/RouteGuide_route_branch_01` | `babylon_route_guide` | Short branch band at (38, 17). Not a collectible. |
| `Dressing/RouteGuides/RouteGuide_route_branch_02` | `babylon_route_guide` | Branch band at (108, 17). |
| `Dressing/ProvisionalClay` | `babylon_provisional_clay` | Ghost slabs and the stair practice from tiles 50–58. Not required. |
| `Markers/Hazards/Spike_119_20` (and 120, 121) | `babylon_hazard` | Visible cavity spikes. `damage_enabled` is false. The cap above them is the path. |
| `Markers/Hazards/TimingDripPlaceholder` | none | Not a gate. |
| `Markers/Exit/StageExit` | `babylon_stage_exit` | Visible arch. Does not change scene and does not collapse the tower. Next id: `babylon_l2_foundations`. |
| `Dressing/Waterfall` | `babylon_waterfall` | Decorative, no damage. |
| `Dressing/Stream` | `babylon_decorative_water` | No damage. |
| `Geometry/Collision` | `babylon_world` | Static body, layer 1. |
| `Inspection/Camera` | none | Not the hero. |

Respawn metadata on every checkpoint: `respawn_started` resets enemies before the hero is re-enabled; `respawned` fires afterwards.

## Route

Required steps are 1 tile. That path reaches the exit without the ribbon and without the spike cells. The ribbon is reached with a 2-tile step at the balcony entrance and returns to the main path, including back to the spawn. No reachable ledge drops more than 2 tiles. Tightest required headroom is 32px, under the balcony entrance at tile (83, 20) and under the balcony return at (99, 21). A body taller than 32px will clip those two columns.

Guard tiles 60–79 are flat and open, so there is room to retreat. The guard marker does not block.

## Placeholders

All art is flat color: grass, wet stone, a tower silhouette covering a sun, distant falls, and the secret waterfall. Final Babylon art is not in this repo. Story plaques use Noto Naskh Arabic (SIL OFL, `fonts/`), which is not final Babylon lettering.

## Checks

```
python3 levels/babylon/tests/test_gardens_map.py
godot --headless --path . --script res://levels/babylon/tests/scene_check.gd
```

Godot 4.3 headless scene check printed `SCENE_CHECK_OK` with required route reaching the exit, ribbon off that route and able to return, minimum clearance 32px, cliff count 0, softlock count 0, and spikes avoidable. The map test module reported 9 passed tests. No hero was running, so jump reach is still unmeasured and no gap is claimed to need clay.
