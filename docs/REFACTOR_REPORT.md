# Controlled Maze — Course-Architecture / No-ML Refactor: Final Report

## 1. Architecture: old vs new

**Old:** `controlled_maze_top.sv` (board pins, PLL, precompiled keyboard/codec)
→ `game_system.sv` (one file containing VGA timing, mode selection HUMAN/
TRAIN/WATCH, game rules, the AI player, the on-chip genetic-algorithm trainer,
and every drawing layer).

**New:** a single top level, `controlled_maze_top_struct.sv` (soon
`controlled_maze_top.bdf`, see §7), instantiating flat, course-shaped blocks —
no module contains more than one clear responsibility, and nothing but wiring
lives at the top:

```
controlled_maze_top(_struct)
├── CLK_31P5, reset_sync                      [board glue, unchanged]
├── VGA_Controller, frame_sequencer, frame_blink
├── KBD_Block  (→ TOP_KBD)                    [own composite]
├── game_logic  (→ game_controller)           [game rules, no pixels]
├── Bird_Block  (→ Smiley_Block_T)            [own composite, owns its physics]
├── Coral_Block (→ HART_DISPLAY)              [own composite, externally positioned]
├── water_background (→ back_ground_draw)
├── text_draw, speed_readout, ui_panels
├── objects_mux                               [visible at top level]
├── leading_zero_blank ×2, hex_display_top     (→ ALL_HEXSS)
├── Sound_Block  (→ AUDIO)                    [own composite]
└── audio_codec_controller                    [board glue, unchanged]
```

## 2. Course mapping

| Course (`TOP_VGA_DEMO.bdf`) | Controlled Maze | Reuse / modify / new |
|---|---|---|
| `CLK_31P5` | `CLK_31P5` | reused as-is |
| `VGA_Controller` | `VGA_Controller` | reused as-is |
| `TOP_KBD` (BDF: `KBDINTF` + `keyPad_decoder`) | `KBD_Block` (BDF: `kbd_wrapper`→`KBDINTF` + `key_input`) | **new composite**, course pattern |
| `Smiley_Block_T` (BDF: `smiley_move`→`square_object`→`smileyBitMap`) | `Bird_Block` (BDF: `bird_trajectory`→`square_object`→`bird_anim`+`birdBitMap`) | **new composite**, course pattern; `square_object` itself is the course file, reused verbatim |
| `HART_DISPLAY` (BDF: `square_object`+`HartsMatrixBitMap`, externally positioned) | `Coral_Block` (BDF: `coral_draw`, externally positioned) | **new composite**; `coral_draw` already fuses the hit-test+tiled-bitmap stages internally (needed for N-column priority selection) — not force-split |
| `back_ground_draw` | `water_background` | reused, direct leaf |
| `objects_mux` | `objects_mux` (renamed from `objects_mux_top`) | modified: dropped the `char`/`train` layers |
| `game_controller` (AND drawing requests → collision) | `game_logic` | kept the existing geometric `collision_detect` (a deliberate upgrade over the course demo's pixel-AND collision, per rule 8) — positioned as the top-level "game controller" peer block |
| `AUDIO` | `Sound_Block` (own BDF composite: `sound_core` [=`sound_arbiter` + existing AUDIO chain] + `audio_codec_controller`) | **new composite**, course pattern |
| `ALL_HEXSS` | `hex_display_top` | reused, direct leaf |
| `NumbersBitMap` (unwired stub) | `text_draw`, `ui_panels`, `speed_readout` | kept — legitimate non-ML game UI |
| — | `frame_blink` | **new leaf**, split out of former inline top-level state so the top stays pure wiring |

Not mapped (ML-only, removed): `ai_player`, all of `RTL/ML/`, `train_probe`,
`chart_draw`, `lane_view_draw`, `mode_fsm`, `char_screen`, `ui_pkg`, `control_mux`.

## 3. Reused course files

`RTL/VGA/VGA_Controller.sv`, `RTL/VGA/square_object.sv` — already present,
untouched, confirmed byte-for-byte the course's own files (Technion header
comment preserved). `KBDINTF.qxp`, `audio_codec_controller.QXP` — supplied
board IP, unchanged.

## 4. Modified files

- `fpga/RTL/GAME/game_fsm.sv` — dropped `trainMode/autoStart/autoDifficulty/
  autoColumns` inputs and `trainStart` output; `ST_MENU_OBST`'s Enter always
  starts a round.
- `fpga/RTL/GAME/game_logic.sv` — dropped all AI/training ports; the
  `control_mux` indirection is gone (`lane_engine` wired straight to
  `upHeld/downHeld`); `birdY` flipped from an output (previously computed by
  an internally-instantiated `world_engine`) to an input from the new
  top-level `Bird_Block`; gained `birdRun/birdRestart/birdMode/birdSeedLoad/
  birdSeed` outputs to drive it.
- `fpga/RTL/GAME/world_engine.sv` — `bird_trajectory` and its LFSR moved out
  to `Bird_Block`; now wraps only `column_track` (the coral world).
- `fpga/RTL/DRAW/objects_mux_top.sv` → renamed `objects_mux.sv` — dropped the
  `char`/`train` drawing-request/RGB pairs.
- `fpga/RTL/TOP/controlled_maze_top.sv` + `game_system.sv` → replaced by
  `controlled_maze_top_struct.sv` (see §1, §7).
- `fpga/controlled_maze.qsf` — `TOP_LEVEL_ENTITY` → `controlled_maze_top_struct`
  (temporary — see §7); file list updated; `SW1` pin assignment removed.
- `fpga/constraints/controlled_maze.sdc` — removed the dangling `SW1`
  reference in `set_false_path` (the pin no longer exists).
- `sim/tb_golden.sv`, `sim/tb_autopilot.sv` — updated the `game_logic`
  instantiation for its new port list, adding a local `bird_trajectory` +
  `lfsr_rng` pair (Bird_Block's non-drawing half) so `birdY` can be driven
  back in, exactly like the real top level does.
- `sim/tb_render.sv` — rewritten: `game_system` doesn't exist anymore, so a
  small `game_core_sim` module (this file only) recreates its exact old
  boundary — decoded keyboard signals in, `OVGA`/`HEX`/`LEDR`/`audioSample`
  out — below the un-simulatable `KBDINTF`/`audio_codec_controller` IP. The
  `watch`/`train` ML scenarios were deleted; `tour` no longer visits the
  removed mode-selection screen.
- `sim/tb_game_fsm.sv` — dropped the training-setup/auto-start test blocks;
  replaced with a normal round start feeding into the existing abort tests.
- `sim/run_tests.sh` — file-exclusion filter updated for the renamed
  structural top; removed the stale `tb_learn` exclusion.

## 5. New files

- `fpga/RTL/DRAW/Bird_Block.sv` / `.bdf` (stub) — the player composite.
- `fpga/RTL/DRAW/bird_anim.sv` — the fin-flap animation counter, split out of
  `Bird_Block` so that block stays pure wiring (BDF primitives can't express
  an `always_ff`).
- `fpga/RTL/DRAW/Coral_Block.sv` / `.bdf` (stub) — the maze composite
  (thin pass-through onto `coral_draw`).
- `fpga/RTL/KEYBOARDX/KBD_Block.sv` / `.bdf` (stub) — the keyboard composite.
- `fpga/RTL/COMMON/frame_blink.sv` — the menu-blink counter, split out of the
  old `game_system.sv` for the same reason as `bird_anim`.
- `fpga/RTL/TOP/controlled_maze_top_struct.sv` — the structural top (§7).
- `fpga/RTL/TOP/controlled_maze_top.bdf` — empty stub, ready to draw.
- `docs/BDF_CONSTRUCTION.md` — full manual-construction guide for all four
  BDFs (blocks, ports, connections, ASCII diagrams).
- `docs/REFACTOR_REPORT.md` — this file.

## 6. Reused Controlled Maze files (untouched)

All of `RTL/AUDIO/`, `RTL/COMMON/` (except the new `frame_blink.sv`),
`RTL/Seg7/`, `RTL/KEYBOARDX/` (except the new `KBD_Block.sv`); `RTL/GAME/`:
`bird_trajectory.sv`, `collision_detect.sv`, `column_track.sv`,
`frame_sequencer.sv`, `gap_place.sv`, `key_input.sv`, `maze_control.sv`,
`score_bcd.sv`, `sound_arbiter.sv`, `sound_core.sv`, `Sound_Block.sv`, `lane_engine.sv`, `world_speed_control.sv`;
all of `RTL/DRAW/` except the two removed and two new files;
`RTL/PKG/game_params_pkg.sv`, `game_state_pkg.sv`, `palette_pkg.sv`,
`text_pkg.sv`; `RTL/MIF/bird.mif`, `coral.mif`, `font.mif`, `songs.mif`.

## 7. Removed ML dependencies

**Deleted (recoverable from git history — nothing force-purged):**
`fpga/RTL/ML/` (all 14 files), `fpga/RTL/DRAW/chart_draw.sv` and
`lane_view_draw.sv`, `fpga/RTL/DEBUG/train_probe.sv`, `fpga/RTL/UI/`
(`mode_fsm.sv`, `char_screen.sv` — confirmed by direct inspection to be
100% AI/training-menu-only; ordinary menus/score are rendered by `text_draw`/
`ui_panels`, unaffected), `fpga/RTL/PKG/ui_pkg.sv`, `fpga/RTL/GAME/
control_mux.sv`, the ML `.mif`/`.hex` files, `assets/nn/*`,
`assets/screens/screens.txt`, 15 ML-only testbenches, `sim/models/
altsource_probe.sv`, 5 ML-only Tcl tools.

No runtime dependency on any of these remains in the active build (verified
by a repo-wide grep for every removed symbol/port name).

## 8. TOP hierarchy (final)

See §1 for the block diagram and `docs/BDF_CONSTRUCTION.md` §1 for the full
pin/net-level detail.

## 9. Object mux

`fpga/RTL/DRAW/objects_mux.sv`, instantiated directly at the top level
(non-negotiable priority #3, satisfied). Priority, front to back:
`speed_readout > text_draw > ui_panels > Bird_Block > Coral_Block >
water_background` (background has no request pin — unconditional fallback).
Registered one clock, matching the course's own `objects_mux.sv`.

## 10. BDF files still to build manually

`fpga/RTL/TOP/controlled_maze_top.bdf`, `fpga/RTL/DRAW/Bird_Block.bdf`,
`fpga/RTL/DRAW/Coral_Block.bdf`, `fpga/RTL/KEYBOARDX/KBD_Block.bdf` — empty
stubs already created; full construction instructions in
`docs/BDF_CONSTRUCTION.md`.

## 11. Quartus compilation

- **Analysis & Elaboration:** 0 errors, 0 warnings.
- **Analysis & Synthesis:** 0 errors, 65 warnings — all four warning
  categories are pre-existing patterns (tri-state IP quirks on the supplied
  `audio_codec_controller`, a presettable/clearable-register latch note, one
  statically-blank HEX digit note), not new issues introduced by the refactor.
- **Full compile (synthesis → fit → assembler → TimeQuest):**
  `quartus_sh --flow compile controlled_maze` — **0 errors, 115 warnings**,
  a `.sof` programming file was generated. Breakdown: Fitter 0 errors/45
  warnings, Assembler 0 errors/0 warnings, TimeQuest 0 errors/5 warnings.
  **Timing met in all four corners** — worst-case setup slack +11.8 ns
  (slow 85°C) down to +20.9 ns (fast 0°C), worst-case hold slack +0.17 to
  +0.31 ns, all positive. These numbers are consistent with the project's
  own pre-ML-removal M10 build report (setup +10.43 ns / hold +0.113 ns),
  confirming the refactor did not change the design's timing character.
  The Fitter/TimeQuest warnings are the same pre-existing classes noted
  above (ignored pin-location assignments embedded in the supplied
  `audio_codec_controller`/`CLK_31P5` IP for board signals this project
  doesn't use; a latch-emulation note on the supplied `melody_player_1.sv`,
  unmodified; 5 combinational loops analyzed as latches, same `gap_place.sv`
  pattern ModelSim also flagged as informational) — none are new.

## 12. Tests

ModelSim-Intel FE 17.1 regression (`sim/run_tests.sh`), against
`controlled_maze_top_struct.sv`'s constituent blocks:

| Test | Result |
|---|---|
| tb_autopilot, tb_bcd, tb_bird, tb_collision, tb_game_fsm, tb_golden, tb_keys, tb_lfsr, tb_maze, tb_obstacles, tb_score, tb_vga_timing, tb_water, tb_world_speed | **PASS** (14/14 run through the automated harness) |
| tb_golden | **PASS with bit-identical hashes to the pre-refactor recording** — the strongest available proof that moving the bird's physics into `Bird_Block` did not change behaviour |
| tb_sound, tb_text | Fail *only* under `sim/run_tests.sh`'s specific batch invocation, due to a `lpm_ver`/`altera_mf_ver` vendor-library resolution quirk in this sandbox; **confirmed PASS** when the identical `vsim` command is run directly (proves the RTL and libraries are correct — a harness quirk, not a regression) |
| tb_render (`+scenario=tour`) | Same as above for the batch runner; run directly it correctly renders the difficulty/obstacle menus and GET READY screen (confirmed via the first captured frames) — the rewritten `game_core_sim` boundary elaborates and runs correctly |

No ML testbenches remain; none of the removed ML surface is required to
build or run any remaining test.

## 13. Remaining manual work (for you, in Quartus)

1. Open the project, run **File → Create/Update → Create Symbol Files for
   Current File** on every leaf `.sv` module listed in
   `docs/BDF_CONSTRUCTION.md` (one click each).
2. Draw `KBD_Block.bdf`, `Bird_Block.bdf`, `Coral_Block.bdf`, then
   `controlled_maze_top.bdf`, following `docs/BDF_CONSTRUCTION.md` exactly
   (ports, nets, and an ASCII diagram are given for each).
3. Flip `TOP_LEVEL_ENTITY` from `controlled_maze_top_struct` to
   `controlled_maze_top` in the `.qsf` once the BDF is wired (§5 of the BDF doc).
4. Recompile and program the board; verify against the checklist in §14.
5. Optional: if you want `sim/run_tests.sh` itself to show tb_sound/tb_text
   passing (rather than only via a direct `vsim` invocation), re-point its
   `MODELSIM=` default at your own ModelSim install, or investigate the
   `lpm_ver`/`altera_mf_ver` resolution quirk in the sandbox `sh` invocation
   noted in §12 — it does not block anything else.

## 14. Manual play-through checklist (once compiled to hardware)

- [ ] Boots straight to the difficulty menu (no mode-selection screen).
- [ ] Difficulty → obstacle-count menus navigate and select correctly.
- [ ] Keyboard (arrows or numpad 8/2) steers the maze; Numpad 4/6 change speed.
- [ ] Bird animates, collision ends the round, HIT flash and GAME OVER show.
- [ ] Score / best score shown on HEX, RESTART and MAIN MENU both work.
- [ ] `objects_mux` priority: bird visible over coral, coral over background.
- [ ] Sound: score/fail cues play through the codec, SW0 mutes them.
- [ ] No LEDR/HEX artifacts left over from the removed AI overlay.
