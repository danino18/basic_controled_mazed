// Temporary structural top level: a textual, one-to-one stand-in for the
// hand-drawn controlled_maze_top.bdf. It only instantiates and wires the
// same blocks the BDF will contain, in the same shape, so the design can be
// compiled and simulated before the BDF exists. It carries no game rules of
// its own (compare against game_system.sv, which this replaces): every real
// decision lives inside game_logic ("the game controller", matching the
// course's game_controller) or inside the object blocks below it.
//
// Once controlled_maze_top.bdf is hand-built from docs/BDF_CONSTRUCTION.md,
// TOP_LEVEL_ENTITY moves from this module to controlled_maze_top and this
// file is no longer part of the active build.

module controlled_maze_top_struct
  import game_state_pkg::*, palette_pkg::*;
(
    input  logic        CLOCK_50,
    input  logic        resetN_pin,     // KEY[0], active low
    input  logic        PS2_CLK,
    input  logic        PS2_DAT,
    input  logic        SW0,            // global mute (audio only)
    input  logic        backN_pin,      // KEY[1], active low: back / pause
    output logic [9:0]  LEDR,
    output logic [6:0]  HEX0,
    output logic [6:0]  HEX1,
    output logic [6:0]  HEX2,
    output logic [6:0]  HEX3,
    output logic [6:0]  HEX4,
    output logic [6:0]  HEX5,
    output logic [28:0] OVGA,
    input  logic        AUD_ADCLRCK,
    input  logic        AUD_BCLK,
    output logic        AUD_DACDAT,
    output logic        AUD_XCK,
    output logic        AUD_I2C_SCLK,
    inout  logic        AUD_I2C_SDAT
);

  // ---------------------------------------------------------------- clock / reset
  logic clk, resetN, pllLocked;

  CLK_31P5 pll (
      .refclk  (CLOCK_50),
      .rst     (~resetN_pin),
      .outclk_0(clk),
      .locked  (pllLocked)
  );

  reset_sync resetSync (
      .clk        (clk),
      .asyncResetN(resetN_pin & pllLocked),
      .resetN     (resetN)
  );

  // ---------------------------------------------------------------- VGA timing
  logic [10:0] pixelX, pixelY;
  logic        startOfFrame;
  color_t      screenRGB;

  VGA_Controller vga (
      .RGBIn       (screenRGB),
      .PixelX      (pixelX),
      .PixelY      (pixelY),
      .startOfFrame(startOfFrame),
      .oVGA        (OVGA),
      .address     (),
      .clk         (clk),
      .resetN      (resetN)
  );

  logic tickMove, tickCheck, tickState;

  frame_sequencer sequencer (
      .clk         (clk),
      .resetN      (resetN),
      .startOfFrame(startOfFrame),
      .tickMove    (tickMove),
      .tickCheck   (tickCheck),
      .tickState   (tickState)
  );

  logic blink;

  frame_blink blinker (
      .clk         (clk),
      .resetN      (resetN),
      .startOfFrame(startOfFrame),
      .blink       (blink)
  );

  // ---------------------------------------------------------------- keyboard, KEY1
  logic upHeld, downHeld, upPulse, downPulse, enterPulse, speedUpHeld, speedDownHeld;

  KBD_Block kbd (
      .clk          (clk),
      .resetN       (resetN),
      .PS2_CLK      (PS2_CLK),
      .PS2_DAT      (PS2_DAT),
      .upHeld       (upHeld),
      .downHeld     (downHeld),
      .upPulse      (upPulse),
      .downPulse    (downPulse),
      .enterPulse   (enterPulse),
      .speedUpHeld  (speedUpHeld),
      .speedDownHeld(speedDownHeld)
  );

  logic backPulse;

  button_pulse #(.STABLE_CLOCKS(630_000)) backButton (
      .clk    (clk),
      .resetN (resetN),
      .buttonN(backN_pin),
      .pressed(),
      .pulse  (backPulse)
  );

  logic entropyPulse;
  assign entropyPulse = upPulse || downPulse || enterPulse || backPulse;

  // ---------------------------------------------------------------- game controller
  logic [2:0] screen;
  logic [1:0] difficulty, columnCount, menuCursor;
  logic [7:0] stateFrames;
  logic       birdRun, birdRestart;
  logic [1:0] birdMode;
  logic       birdSeedLoad;
  logic [15:0] birdSeed;
  logic signed [9:0] mazeOffset;
  logic signed [4:0] mazeVy;
  logic [game_params_pkg::NUM_COLUMNS-1:0]       colActive, hitColumn;
  logic [game_params_pkg::NUM_COLUMNS-1:0][10:0] colX;
  logic [game_params_pkg::NUM_COLUMNS-1:0][8:0]  gapBase;
  logic [game_params_pkg::NUM_COLUMNS-1:0][9:0]  gapTop, gapBottom;
  logic       collision;
  logic [2:0][3:0] score, best;
  logic       newBest;
  logic [2:0] speedLevel;
  logic       scoreEvent, failEvent;
  logic signed [10:0] birdY;

  game_logic gameLogic (
      .clk           (clk),
      .resetN        (resetN),
      .tickMove      (tickMove),
      .tickCheck     (tickCheck),
      .tickState     (tickState),
      .upHeld        (upHeld),
      .downHeld      (downHeld),
      .upPulse       (upPulse),
      .downPulse     (downPulse),
      .enterPulse    (enterPulse),
      .speedUpHeld   (speedUpHeld),
      .speedDownHeld (speedDownHeld),
      .entropyPulse  (entropyPulse),
      .abort         (backPulse),
      .speedLoad     (1'b0),
      .speedLoadLevel(3'd0),
      .birdY         (birdY),
      .screen        (screen),
      .difficulty    (difficulty),
      .columnCount   (columnCount),
      .menuCursor    (menuCursor),
      .stateFrames   (stateFrames),
      .birdRun       (birdRun),
      .birdRestart   (birdRestart),
      .birdMode      (birdMode),
      .birdSeedLoad  (birdSeedLoad),
      .birdSeed      (birdSeed),
      .mazeOffset    (mazeOffset),
      .mazeVy        (mazeVy),
      .colActive     (colActive),
      .colX          (colX),
      .gapBase       (gapBase),
      .gapTop        (gapTop),
      .gapBottom     (gapBottom),
      .collision     (collision),
      .hitColumn     (hitColumn),
      .score         (score),
      .best          (best),
      .newBest       (newBest),
      .speedLevel    (speedLevel),
      .scoreEvent    (scoreEvent),
      .failEvent     (failEvent)
  );

  logic inMenu, crashed, flash;

  assign inMenu  = (screen == ST_MENU_DIFF) || (screen == ST_MENU_OBST);
  assign crashed = (screen == ST_HIT) || (screen == ST_GAME_OVER);
  assign flash   = (screen == ST_HIT) && (stateFrames < 8'd8);

  logic [game_params_pkg::NUM_COLUMNS-1:0] coralShown;
  assign coralShown = inMenu ? '0 : colActive;

  // ---------------------------------------------------------------- objects
  logic   birdDR;
  color_t birdRGB;

  Bird_Block bird (
      .clk           (clk),
      .resetN        (resetN),
      .pixelX        (pixelX),
      .pixelY        (pixelY),
      .tick          (tickMove),
      .run           (birdRun),
      .restart       (birdRestart),
      .mode          (birdMode),
      .seedLoad      (birdSeedLoad),
      .seed          (birdSeed),
      .animate       (!crashed),
      .blink         (screen == ST_HIT),
      .drawingRequest(birdDR),
      .RGBout        (birdRGB),
      .birdY         (birdY)
  );

  logic   coralDR;
  color_t coralRGB;

  Coral_Block coral (
      .clk           (clk),
      .resetN        (resetN),
      .pixelX        (pixelX),
      .pixelY        (pixelY),
      .active        (coralShown),
      .colX          (colX),
      .gapTop        (gapTop),
      .gapBottom     (gapBottom),
      .drawingRequest(coralDR),
      .RGBout        (coralRGB)
  );

  color_t waterRGB;

  water_background water (
      .clk   (clk),
      .resetN(resetN),
      .pixelX(pixelX),
      .pixelY(pixelY),
      .RGBout(waterRGB)
  );

  logic   textDR;
  color_t textRGB;

  text_draw text (
      .clk           (clk),
      .resetN        (resetN),
      .pixelX        (pixelX),
      .pixelY        (pixelY),
      .screen        (screen),
      .menuCursor    (menuCursor),
      .scoreDigits   (score),
      .bestDigits    (best),
      .newBest       (newBest),
      .blink         (blink),
      .drawingRequest(textDR),
      .RGBout        (textRGB)
  );

  logic   speedDR;
  color_t speedRGB;

  speed_readout speedReadout (
      .clk           (clk),
      .resetN        (resetN),
      .pixelX        (pixelX),
      .pixelY        (pixelY),
      .screen        (screen),
      .speedLevel    (speedLevel),
      .drawingRequest(speedDR),
      .RGBout        (speedRGB)
  );

  logic   panelDR;
  color_t panelRGB;

  ui_panels panels (
      .clk           (clk),
      .resetN        (resetN),
      .pixelX        (pixelX),
      .pixelY        (pixelY),
      .screen        (screen),
      .menuCursor    (menuCursor),
      .flash         (flash),
      .drawingRequest(panelDR),
      .RGBout        (panelRGB)
  );

  objects_mux mux (
      .clk                (clk),
      .resetN             (resetN),
      .speedDrawingRequest(speedDR),
      .speedRGB           (speedRGB),
      .textDrawingRequest (textDR),
      .textRGB            (textRGB),
      .panelDrawingRequest(panelDR),
      .panelRGB           (panelRGB),
      .birdDrawingRequest (birdDR),
      .birdRGB            (birdRGB),
      .coralDrawingRequest(coralDR),
      .coralRGB           (coralRGB),
      .backgroundRGB      (waterRGB),
      .RGBOut             (screenRGB)
  );

  // ---------------------------------------------------------------- score display
  logic [2:0][3:0] lowOn, highOn;

  leading_zero_blank #(.DIGITS(3)) lowBlank (.digits(score), .digitOn(lowOn));
  leading_zero_blank #(.DIGITS(3)) highBlank(.digits(best),  .digitOn(highOn));

  hex_display_top hex (
      .clk    (clk),
      .resetN (resetN),
      .digits ({best, score}),
      .digitOn({highOn, lowOn}),
      .HEX0   (HEX0),
      .HEX1   (HEX1),
      .HEX2   (HEX2),
      .HEX3   (HEX3),
      .HEX4   (HEX4),
      .HEX5   (HEX5)
  );

  // ---------------------------------------------------------------- sound
  Sound_Block sound (
      .clk         (clk),
      .resetN      (resetN),
      .scoreTrigger(scoreEvent),
      .failTrigger (failEvent),
      .mute        (SW0),
      .AUD_ADCLRCK (AUD_ADCLRCK),
      .AUD_BCLK    (AUD_BCLK),
      .AUD_DACDAT  (AUD_DACDAT),
      .AUD_XCK     (AUD_XCK),
      .AUD_I2C_SCLK(AUD_I2C_SCLK),
      .AUD_I2C_SDAT(AUD_I2C_SDAT),
      .playingScore(),
      .playingFail ()
  );

  // LEDR[9]=blink, [8:7]=columns, [6:5]=difficulty, [4:2]=screen, [1]=resetN, [0]=PLL locked.
  assign LEDR = {blink, columnCount, difficulty, screen, resetN, pllLocked};

endmodule
