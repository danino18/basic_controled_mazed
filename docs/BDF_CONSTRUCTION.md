# Manual BDF construction guide

This document is the step-by-step reference for hand-building the graphical
Block Diagram Files (BDFs) that give Controlled Maze the same top-level shape
as the course's `VGA_DEMO_Students` / `TOP_VGA_DEMO.bdf`. The RTL is already
refactored and verified (Quartus Analysis & Synthesis, ModelSim regression —
see the final report) against a **temporary structural SystemVerilog top**,
`fpga/RTL/TOP/controlled_maze_top_struct.sv`. That file is a textual,
one-to-one stand-in for `controlled_maze_top.bdf`: every block it instantiates
and every net it wires is exactly what belongs in the BDF. The same is true of
`Bird_Block.sv` / `Coral_Block.sv` / `KBD_Block.sv` versus their own BDFs.

**You do not need to re-derive any wiring.** Each section below lists the
blocks, their exact ports (name, direction, width), and the exact connections,
read directly off the working `.sv` files. Open the matching `.sv` file
alongside this document if you want to double check a line.

## Before you start: generating `.bsf` symbols

For every leaf module a BDF instantiates, Quartus needs a `.bsf` symbol file.
In the Quartus GUI, with the project open: open the module's `.sv` file, then
**File → Create/Update → Create Symbol Files for Current File**. This reads
the module's port list and writes a `.bsf` next to it — do this once per
module listed under "Blocks to insert" in each section below. It is safe to
re-run any time the module's ports change; Quartus regenerates the symbol.

Four blocks already have empty starting `.bdf` stubs, ready to open in the
Block Editor (**File → Open**, then start placing symbols with **Edit →
Insert Symbol**, or drag from the Project Navigator):

- `fpga/RTL/TOP/controlled_maze_top.bdf`
- `fpga/RTL/DRAW/Bird_Block.bdf`
- `fpga/RTL/DRAW/Coral_Block.bdf`
- `fpga/RTL/KEYBOARDX/KBD_Block.bdf`

## Conventions used throughout

- `clk` / `resetN`: the global 31.5 MHz pixel clock and its active-low
  synchronous reset, present on almost every block (course names, unchanged).
- `pixelX[10:0]` / `pixelY[10:0]`: current VGA raster position, from
  `VGA_Controller` (course names, unchanged).
- `drawingRequest` / `RGBout` (`color_t`, 8 bits): the course's
  request/colour pair — "this layer wants to draw the current pixel, in this
  colour." `color_t` is an 8-bit type from `palette_pkg` (3/3/2-style packed
  RGB); on a BDF pin it is just an 8-bit bus.
- Every drawing block has a fixed 3-clock latency from `pixelX/pixelY` to its
  `drawingRequest/RGBout` (registered ROM address → registered ROM data →
  registered output), matching the course's own pipeline depth.

---

## 1. `controlled_maze_top.bdf` — the top level

Corresponds to `RTL/VGA/TOP_VGA_DEMO.bdf`. Reference source:
`fpga/RTL/TOP/controlled_maze_top_struct.sv` (copy its wiring exactly).

### Top-level pins

| Pin | Dir | Width | Notes |
|---|---|---|---|
| `CLOCK_50` | in | 1 | board 50 MHz |
| `resetN_pin` | in | 1 | KEY[0], active low |
| `PS2_CLK`, `PS2_DAT` | in | 1 each | keyboard |
| `SW0` | in | 1 | mute |
| `backN_pin` | in | 1 | KEY[1], back/pause |
| `LEDR` | out | [9:0] | |
| `HEX0`..`HEX5` | out | [6:0] each | |
| `OVGA` | out | [28:0] | |
| `AUD_ADCLRCK`, `AUD_BCLK` | in | 1 each | codec is I2S clock master |
| `AUD_DACDAT`, `AUD_XCK`, `AUD_I2C_SCLK` | out | 1 each | |
| `AUD_I2C_SDAT` | inout | 1 | |

(SW1 / debugSw no longer exists — the AI debug overlay it fed is gone.)

### Blocks to insert (symbol name — module — count)

| Symbol | Module `.sv`/`.v`/IP | Notes |
|---|---|---|
| `CLK_31P5` | `CLK_31P5.v` (QIP megafunction) | PLL, already has a `.bsf` |
| `reset_sync` | `RTL/COMMON/reset_sync.sv` | |
| `VGA_Controller` | `RTL/VGA/VGA_Controller.sv` | reused from the course, unmodified |
| `KBD_Block` | `RTL/KEYBOARDX/KBD_Block.bdf` (its own BDF — §4) | matches course `TOP_KBD` |
| `button_pulse` | `RTL/COMMON/button_pulse.sv` | param `STABLE_CLOCKS=630000` |
| `game_logic` | `RTL/GAME/game_logic.sv` | matches course `game_controller`'s role, at this hierarchy level |
| `Bird_Block` | `RTL/DRAW/Bird_Block.bdf` (its own BDF — §2) | matches course `Smiley_Block_T` |
| `Coral_Block` | `RTL/DRAW/Coral_Block.bdf` (its own BDF — §3) | matches course `HART_DISPLAY` |
| `water_background` | `RTL/DRAW/water_background.sv` | matches course `back_ground_draw`, direct leaf |
| `text_draw` | `RTL/DRAW/text_draw.sv` | |
| `speed_readout` | `RTL/DRAW/speed_readout.sv` | |
| `ui_panels` | `RTL/DRAW/ui_panels.sv` | |
| `objects_mux` | `RTL/DRAW/objects_mux.sv` | **the course's `objects_mux`, visible at top level** |
| `leading_zero_blank` ×2 | `RTL/COMMON/leading_zero_blank.sv` | param `DIGITS=3`; one for `score`, one for `best` |
| `hex_display_top` | `RTL/DRAW/hex_display_top.sv` | matches course `ALL_HEXSS` |
| `sound_engine` | `RTL/GAME/sound_engine.sv` | matches course `AUDIO`, at this hierarchy level |
| `audio_codec_controller` | `audio_codec_controller.QXP` | supplied IP, already has a `.bsf` |
| Two OR2 gate primitives | Quartus primitive `OR2` | for `entropyPulse` (4-way OR, chain 3× OR2) — see below |
| Two comparator/AND primitives, or one small SV leaf | for `inMenu`/`crashed`/`flash`/`coralShown` | see "small derived signals" below |

### Nets / connections (exactly as in `controlled_maze_top_struct.sv`)

**Clock/reset:**
`CLK_31P5.refclk = CLOCK_50`, `CLK_31P5.rst = NOT(resetN_pin)`,
`CLK_31P5.outclk_0 → clk` (fans out to every block), `CLK_31P5.locked → pllLocked`.
`reset_sync.clk = clk`, `reset_sync.asyncResetN = resetN_pin AND pllLocked`,
`reset_sync.resetN → resetN` (fans out to every block).

**VGA timing:**
`VGA_Controller.RGBIn = screenRGB` (from `objects_mux.RGBOut`, feedback net).
`VGA_Controller.PixelX/PixelY → pixelX/pixelY` (fan to every drawing block).
`VGA_Controller.startOfFrame → startOfFrame` (to `frame_sequencer`, `frame_blink`).
`VGA_Controller.oVGA → OVGA` (top pin). `VGA_Controller.address` left unconnected.

`frame_sequencer`: `startOfFrame` in; `tickMove/tickCheck/tickState` out (fan to `game_logic`, and `tickMove` to `Bird_Block`).

`frame_blink`: `startOfFrame` in; `blink` out → `text_draw.blink`.

**Keyboard:**
`KBD_Block.PS2_CLK/PS2_DAT = PS2_CLK/PS2_DAT` (top pins).
`KBD_Block` outputs `upHeld,downHeld,upPulse,downPulse,enterPulse,speedUpHeld,speedDownHeld` → fan to `game_logic`.
`button_pulse.buttonN = backN_pin`; `.pulse → backPulse` → `game_logic.abort`, and into the `entropyPulse` OR.
`entropyPulse = upPulse OR downPulse OR enterPulse OR backPulse` (3× OR2, or one 4-input OR) → `game_logic.entropyPulse`.

**`game_logic`** ("the game controller" — matches the hierarchy image's own
"Game controller" box): inputs `clk,resetN,tickMove,tickCheck,tickState,
upHeld,downHeld,upPulse,downPulse,enterPulse,speedUpHeld,speedDownHeld,
entropyPulse,abort(=backPulse),speedLoad(=0),speedLoadLevel(=0),birdY(from
Bird_Block)`. Outputs: `screen[2:0],difficulty[1:0],columnCount[1:0],
menuCursor[1:0],stateFrames[7:0]` (fan to drawing blocks), `birdRun,
birdRestart,birdMode[1:0],birdSeedLoad,birdSeed[15:0]` (→ `Bird_Block`),
`mazeOffset[9:0],mazeVy[4:0]` (unused outside, may be left open), `colActive
[2:0],colX[2:0][10:0],gapBase[2:0][8:0]` (unused outside, may be left open),
`gapTop[2:0][9:0],gapBottom[2:0][9:0]` (→ `Coral_Block`), `collision`
(internal to game_logic's own FSM only — no outside consumer), `hitColumn
[2:0]` (unused outside), `score[2:0][3:0],best[2:0][3:0],newBest` (→
`text_draw`, `leading_zero_blank` ×2), `speedLevel[2:0]` (→ `speed_readout`),
`scoreEvent,failEvent` (→ `sound_engine`).

**Small derived signals** (pure combinational, no memory — buildable from
Quartus primitive gates, exactly like the course's own `NOT` gate in
`TOP_VGA_DEMO.bdf`):
- `inMenu = (screen == 3'd0) OR (screen == 3'd1)` — `ST_MENU_DIFF`/`ST_MENU_OBST` (see `game_state_pkg.sv` for the exact encoding)
- `crashed = (screen == ST_HIT) OR (screen == ST_GAME_OVER)`
- `flash = (screen == ST_HIT) AND (stateFrames < 8)`
- `coralShown[2:0] = inMenu ? 3'b000 : colActive[2:0]`

If hand-drawing these as gate primitives is awkward, it is entirely fine to
keep them inside a tiny leaf `.sv` (a 4-input, purely combinational helper) —
Quartus BDFs commonly delegate anything wider than a couple of gates to a leaf
symbol; the course itself does this for its own small helpers.

**Bird_Block** (own BDF, §2): `pixelX,pixelY` in; `tick=tickMove,
run=birdRun,restart=birdRestart,mode=birdMode,seedLoad=birdSeedLoad,
seed=birdSeed` in (from `game_logic`); `animate = NOT(crashed)`,
`blink = (screen == ST_HIT)` in; outputs `drawingRequest → birdDR`,
`RGBout → birdRGB` (both to `objects_mux`), `birdY → game_logic.birdY`
(feedback).

**Coral_Block** (own BDF, §3): `pixelX,pixelY` in; `active = coralShown,
colX = colX, gapTop = gapTop, gapBottom = gapBottom` in (from `game_logic`);
outputs `drawingRequest → coralDR`, `RGBout → coralRGB` (both to `objects_mux`).

**water_background**: `pixelX,pixelY` in; `RGBout → waterRGB` (to `objects_mux.backgroundRGB` — no request pin, it is the unconditional fallback layer).

**text_draw**: `pixelX,pixelY,screen,menuCursor` in; `scoreDigits=score,
bestDigits=best,newBest,blink` in; `drawingRequest → textDR`, `RGBout → textRGB`.

**speed_readout**: `pixelX,pixelY,screen,speedLevel` in; `drawingRequest → speedDR`, `RGBout → speedRGB`.

**ui_panels**: `pixelX,pixelY,screen,menuCursor,flash` in; `drawingRequest → panelDR`, `RGBout → panelRGB`.

**objects_mux** (the compositor — priority order speed > text > panel > bird
> coral > background, front to back):
`speedDrawingRequest=speedDR,speedRGB` / `textDrawingRequest=textDR,textRGB` /
`panelDrawingRequest=panelDR,panelRGB` / `birdDrawingRequest=birdDR,birdRGB` /
`coralDrawingRequest=coralDR,coralRGB` / `backgroundRGB=waterRGB` in;
`RGBOut → screenRGB` (feeds back into `VGA_Controller.RGBIn`).

**Score display:** `leading_zero_blank #(DIGITS=3)` ×2: one takes
`digits=score → digitOn=lowOn`, the other `digits=best → digitOn=highOn`.
`hex_display_top`: `digits = {best[2:0][3:0], score[2:0][3:0]}` (18 bits,
`best` in the high half), `digitOn = {highOn, lowOn}` (6 bits) → `HEX0..HEX5`.

**Sound:** `sound_engine.scoreTrigger=scoreEvent, failTrigger=failEvent,
mute=SW0` in; `audioSample[15:0] → ` both `audio_codec_controller.dacdata_left`
and `.dacdata_right` (mono, same sample on both channels — matches the
supplied board wiring convention).
`audio_codec_controller`: `CLOCK31_5=clk, resetN=resetN, AUD_ADCLRCK,
AUD_BCLK` in (top pins) → `AUD_DACDAT, AUD_XCK, AUD_I2C_SCLK` out (top pins),
`AUD_I2C_SDAT` bidir (top pin); `adcdata_left/right` left unconnected.

**LEDR:** `LEDR[9]=blink, LEDR[8:7]=columnCount, LEDR[6:5]=difficulty,
LEDR[4:2]=screen, LEDR[1]=resetN, LEDR[0]=pllLocked` — a straight bit
concatenation, buildable as individual bus taps into the `LEDR[9:0]` output
pin (no logic, matches how the course ties `redLight`/`greenLight` straight to
constants).

### ASCII diagram

```
controlled_maze_top
├── CLK_31P5 ─────────────────────────┐
├── reset_sync ◄──(pllLocked, resetN_pin)
├── VGA_Controller ◄── screenRGB (from objects_mux, feedback)
│     └──> pixelX, pixelY, startOfFrame, OVGA
├── frame_sequencer ◄── startOfFrame ──> tickMove, tickCheck, tickState
├── frame_blink ◄── startOfFrame ──> blink
├── KBD_Block ◄── PS2_CLK, PS2_DAT ──> upHeld/downHeld/upPulse/downPulse/enterPulse/speedUpHeld/speedDownHeld
├── button_pulse ◄── backN_pin ──> backPulse
├── game_logic ("game controller") ◄── keys, ticks, birdY ──> screen/difficulty/.../birdRun.../gapTop.../score/scoreEvent...
├── Bird_Block ◄── pixelX/Y, birdRun/birdRestart/birdMode/birdSeed(Load) ──> birdDR, birdRGB, birdY (feedback to game_logic)
├── Coral_Block ◄── pixelX/Y, coralShown, colX, gapTop, gapBottom ──> coralDR, coralRGB
├── water_background ◄── pixelX/Y ──> waterRGB
├── text_draw, speed_readout, ui_panels ◄── pixelX/Y, game state ──> *DR, *RGB
├── objects_mux ◄── all *DR/*RGB pairs + waterRGB ──> screenRGB (feeds VGA_Controller)
├── leading_zero_blank ×2, hex_display_top ◄── score, best ──> HEX0..HEX5
├── sound_engine ◄── scoreEvent, failEvent ──> audioSample
├── audio_codec_controller ◄── audioSample, AUD_* pins ──> AUD_* pins
└── LEDR assembly (bit concatenation)
```

---

## 2. `Bird_Block.bdf` — the player object

Corresponds to `RTL/VGA/Smiley_Block_T.bdf`. Reference source:
`fpga/RTL/DRAW/Bird_Block.sv`.

### Block ports

| Port | Dir | Width |
|---|---|---|
| `clk`, `resetN` | in | 1 |
| `pixelX`, `pixelY` | in | [10:0] |
| `tick` | in | 1 |
| `run` | in | 1 |
| `restart` | in | 1 |
| `mode` | in | [1:0] |
| `seedLoad` | in | 1 |
| `seed` | in | [15:0] |
| `animate` | in | 1 |
| `blink` | in | 1 |
| `drawingRequest` | out | 1 |
| `RGBout` | out | 8 (`color_t`) |
| `birdY` | out | signed [10:0] |

### Blocks to insert

| Symbol | Module | Notes |
|---|---|---|
| `lfsr_rng` | `RTL/COMMON/lfsr_rng.sv` | instance `birdRng` |
| `bird_trajectory` | `RTL/GAME/bird_trajectory.sv` | matches course `smiley_move`'s role |
| `square_object` | `RTL/VGA/square_object.sv` | reused verbatim from the course |
| `birdBitMap` | `RTL/DRAW/birdBitMap.sv` | matches course `smileyBitMap` |
| `bird_anim` | `RTL/DRAW/bird_anim.sv` | fin-flap animation counter, a separate leaf so `Bird_Block` stays pure wiring |

### Connections

`birdRng`: `clk,resetN` in; `step=tick, seedLoad=seedLoad,
seed = {seed[7:0], seed[15:8]} XOR 16'h5A5A` (an 8-bit swap then XOR with a
constant — build with bus taps + an XOR-with-constant, or keep as a one-line
leaf) in; `rnd[15:0] → bird_trajectory.rnd`.

`bird_trajectory`: `clk,resetN,tick,run,restart,mode,rnd` in; `birdY → birdY`
(both the block's own output port, and into `square_object.topLeftY`);
`birdVy`, `trajState` unconnected (nothing outside `Bird_Block` needs them).

`square_object` (params `OBJECT_WIDTH_X=BIRD_SIZE, OBJECT_HEIGHT_Y=BIRD_SIZE`
from `game_params_pkg`): `clk,resetN,pixelX,pixelY` in; `topLeftX = 11'(BIRD_X)`
(a tied constant, from `game_params_pkg`), `topLeftY = birdY` in;
`offsetX,offsetY → birdBitMap.offsetX/offsetY`; `drawingRequest → birdBitMap.InsideRectangle`; `RGBout` unconnected (Bird_Block uses `birdBitMap`'s colour, not this stage's placeholder colour).

**bird_anim**: `clk,resetN,tick,animate,blink` in; `frame[1:0]` (0-1-2-1 flip
pattern) → `birdBitMap.frame`; `blinkOff` → the `AND NOT` gate on
`Bird_Block`'s own `drawingRequest` output, described next.

`birdBitMap`: `clk,resetN,offsetX,offsetY,InsideRectangle,frame` in;
`drawingRequest, RGBout` → the block's own outputs, through the
`AND NOT blinkOff` gate on `drawingRequest` described above.

### ASCII diagram

```
Bird_Block
├── lfsr_rng (birdRng) ◄── seedLoad, seed(swap+xor) ──> rnd[15:0]
├── bird_trajectory ◄── tick, run, restart, mode, rnd ──> birdY, (birdVy, trajState unused)
│     birdY ──> (block output) AND ──> square_object.topLeftY
├── square_object (W=H=BIRD_SIZE) ◄── pixelX/Y, topLeftX=BIRD_X(const), topLeftY=birdY
│     ──> offsetX, offsetY, drawingRequest(=InsideRectangle)
├── bird_anim ◄── tick, animate, blink ──> frame[1:0], blinkOff
└── birdBitMap ◄── offsetX, offsetY, InsideRectangle, frame ──> drawingRequest, RGBout
      drawingRequest AND NOT(blinkOff) ──> Bird_Block.drawingRequest
      RGBout ──> Bird_Block.RGBout
```

---

## 3. `Coral_Block.bdf` — the maze/obstacle object

Corresponds to `RTL/VGA/HART_DISPLAY.bdf`. Reference source:
`fpga/RTL/DRAW/Coral_Block.sv`.

Unlike `Bird_Block`, this block does **not** own its position: exactly like
`HART_DISPLAY` takes `topLeftX`/`topLeftY` from outside (tied constants in
the course demo; here, live signals from `game_logic`), `Coral_Block` takes
`active`/`colX`/`gapTop`/`gapBottom` from outside. The rectangle-hit-test
stage (`square_object`'s role in `HART_DISPLAY`) and the tiled-bitmap stage
(`HartsMatrixBitMap`'s role) are both already fused into one leaf module,
`coral_draw.sv`, because picking which of up to 3 columns the current pixel
falls in needs a priority selection across all of them that a single
`square_object` instance cannot do — so `Coral_Block` is a thin, direct
pass-through onto `coral_draw`, not a forced multi-stage split.

### Block ports

| Port | Dir | Width |
|---|---|---|
| `clk`, `resetN` | in | 1 |
| `pixelX`, `pixelY` | in | [10:0] |
| `active` | in | [2:0] (`NUM_COLUMNS`) |
| `colX` | in | [2:0][10:0] |
| `gapTop`, `gapBottom` | in | [2:0][9:0] each |
| `drawingRequest` | out | 1 |
| `RGBout` | out | 8 (`color_t`) |

### Blocks to insert

| Symbol | Module | Notes |
|---|---|---|
| `coral_draw` | `RTL/DRAW/coral_draw.sv` | the whole block's content — 1:1 pass-through |

### Connections

`coral_draw`: `clk,resetN,pixelX,pixelY,active,colX,gapTop,gapBottom` in
(straight from `Coral_Block`'s own ports) → `drawingRequest,RGBout` straight
out to `Coral_Block`'s own ports. No other wiring.

### ASCII diagram

```
Coral_Block
└── coral_draw ◄── pixelX/Y, active, colX, gapTop, gapBottom ──> drawingRequest, RGBout
      (pass straight through to the block's own ports)
```

---

## 4. `KBD_Block.bdf` — the keyboard subsystem

Corresponds to `RTL/KEYBOARDX/TOP_KBD.bdf`. Reference source:
`fpga/RTL/KEYBOARDX/KBD_Block.sv`.

### Block ports

| Port | Dir | Width |
|---|---|---|
| `clk`, `resetN` | in | 1 |
| `PS2_CLK`, `PS2_DAT` | in | 1 each |
| `upHeld`, `downHeld` | out | 1 each |
| `upPulse`, `downPulse`, `enterPulse` | out | 1 each |
| `speedUpHeld`, `speedDownHeld` | out | 1 each |

### Blocks to insert

| Symbol | Module | Notes |
|---|---|---|
| `kbd_wrapper` | `RTL/KEYBOARDX/kbd_wrapper.v` | wraps the supplied `KBDINTF.qxp` (course's `KBDINTF`, reserved-word workaround) |
| `key_input` | `RTL/GAME/key_input.sv` | matches course `keyPad_decoder`'s role; internally instantiates 8× `singleKeyDecoder` |

### Connections

`kbd_wrapper`: `clk,resetN,PS2_CLK,PS2_DAT` in (straight from `KBD_Block`'s
own ports) → `keyCode[8:0], make, brakk` → `key_input.keyCode/keyMake/keyBreak`.

`key_input`: `clk,resetN,keyCode,keyMake,keyBreak` in →
`upHeld,downHeld,upPulse,downPulse,enterPulse,speedUpHeld,speedDownHeld`
straight out to `KBD_Block`'s own ports.

### ASCII diagram

```
KBD_Block
├── kbd_wrapper (wraps KBDINTF) ◄── PS2_CLK, PS2_DAT ──> keyCode[8:0], make, brakk
└── key_input ◄── keyCode, make, brakk ──> upHeld/downHeld/upPulse/downPulse/enterPulse/speedUpHeld/speedDownHeld
      (pass straight through to the block's own ports)
```

---

## 5. Switching the active build from the structural top to the BDF

1. Build all four BDFs as described above (`.bsf` symbols first, then wire
   each BDF, innermost first: `Bird_Block.bdf`, `Coral_Block.bdf`,
   `KBD_Block.bdf`, then `controlled_maze_top.bdf` which uses the other
   three's own symbols).
2. In `fpga/controlled_maze.qsf`, add BDF file assignments for the four files
   (Quartus does this automatically when you save a BDF inside the open
   project — check **Assignments → Settings → Files** afterward to confirm
   all four are listed).
3. Change `set_global_assignment -name TOP_LEVEL_ENTITY controlled_maze_top_struct`
   to `... controlled_maze_top` in the `.qsf`.
4. Recompile (`Start Compilation`). `controlled_maze_top_struct.sv`,
   `Bird_Block.sv`, `Coral_Block.sv`, and `KBD_Block.sv` can stay in the
   project file list (unreferenced files with no path from the new
   `TOP_LEVEL_ENTITY` are simply not elaborated) — keeping them costs
   nothing and preserves the ModelSim regression exactly as-is, since every
   testbench still targets `game_logic`/`Bird_Block`/`Coral_Block`/
   `game_core_sim` (in `sim/tb_render.sv`) directly, never the top-level BDF.
