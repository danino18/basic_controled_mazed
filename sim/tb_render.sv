// Renders complete VGA frames into PPM images, exactly as the board would
// output them (including the drawing pipeline delay).
// Pixel colours are taken from the oVGA pins using the board wiring:
// oVGA[7:0] -> VGA_R, [15:8] -> VGA_G, [23:16] -> VGA_B.
//
//   +shots=<frame>,<frame>,...   save the listed frames (no key presses)
//   +scenario=tour               play through every screen with scripted keys
//   +difficulty=<0..2>           difficulty chosen in the tour (default 1)
//   +columns=<1..3>              coral columns chosen in the tour (default 3)
// Timers and the first coral position are shortened so a tour takes ~100 frames.
`timescale 1ns / 1ps

// Everything controlled_maze_top_struct.sv contains below the board pins,
// PLL, precompiled keyboard block and audio codec: those three are not
// simulatable (no ModelSim-Intel-ASE model for KBDINTF/audio_codec_controller),
// which is exactly why this seam exists, one level below KBD_Block/the codec,
// taking already-decoded key events instead of raw PS2 pins.
module game_core_sim (
    input  logic        clk,
    input  logic        resetN,
    input  logic [8:0]  keyCode,
    input  logic        keyMake,
    input  logic        keyBreak,
    input  logic        muteSw,
    input  logic        backN,
    output logic [28:0] OVGA,
    output logic [6:0]  HEX0,
    output logic [6:0]  HEX1,
    output logic [6:0]  HEX2,
    output logic [6:0]  HEX3,
    output logic [6:0]  HEX4,
    output logic [6:0]  HEX5,
    output logic [9:0]  LEDR,
    output logic [15:0] audioSample
);
  import game_state_pkg::*, palette_pkg::*;

  logic [10:0] pixelX, pixelY;
  logic        startOfFrame;
  color_t      screenRGB;

  VGA_Controller vga (
      .RGBIn(screenRGB), .PixelX(pixelX), .PixelY(pixelY), .startOfFrame(startOfFrame),
      .oVGA(OVGA), .address(), .clk(clk), .resetN(resetN));

  logic tickMove, tickCheck, tickState;

  frame_sequencer sequencer (
      .clk(clk), .resetN(resetN), .startOfFrame(startOfFrame),
      .tickMove(tickMove), .tickCheck(tickCheck), .tickState(tickState));

  logic blink;
  frame_blink blinker (.clk(clk), .resetN(resetN), .startOfFrame(startOfFrame), .blink(blink));

  logic upHeld, downHeld, upPulse, downPulse, enterPulse, speedUpHeld, speedDownHeld;

  key_input keys (
      .clk(clk), .resetN(resetN), .keyCode(keyCode), .keyMake(keyMake), .keyBreak(keyBreak),
      .upHeld(upHeld), .downHeld(downHeld), .upPulse(upPulse), .downPulse(downPulse),
      .enterPulse(enterPulse), .speedUpHeld(speedUpHeld), .speedDownHeld(speedDownHeld));

  logic backPulse;
  button_pulse #(.STABLE_CLOCKS(20)) backButton (
      .clk(clk), .resetN(resetN), .buttonN(backN), .pressed(), .pulse(backPulse));

  logic entropyPulse;
  assign entropyPulse = upPulse || downPulse || enterPulse || backPulse;

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
      .clk(clk), .resetN(resetN), .tickMove(tickMove), .tickCheck(tickCheck), .tickState(tickState),
      .upHeld(upHeld), .downHeld(downHeld), .upPulse(upPulse), .downPulse(downPulse),
      .enterPulse(enterPulse), .speedUpHeld(speedUpHeld), .speedDownHeld(speedDownHeld),
      .entropyPulse(entropyPulse), .abort(backPulse), .speedLoad(1'b0), .speedLoadLevel(3'd0),
      .birdY(birdY),
      .screen(screen), .difficulty(difficulty), .columnCount(columnCount), .menuCursor(menuCursor),
      .stateFrames(stateFrames),
      .birdRun(birdRun), .birdRestart(birdRestart), .birdMode(birdMode),
      .birdSeedLoad(birdSeedLoad), .birdSeed(birdSeed),
      .mazeOffset(mazeOffset), .mazeVy(mazeVy), .colActive(colActive), .colX(colX), .gapBase(gapBase),
      .gapTop(gapTop), .gapBottom(gapBottom), .collision(collision), .hitColumn(hitColumn),
      .score(score), .best(best), .newBest(newBest), .speedLevel(speedLevel),
      .scoreEvent(scoreEvent), .failEvent(failEvent));

  logic inMenu, crashed, flash;
  assign inMenu  = (screen == ST_MENU_DIFF) || (screen == ST_MENU_OBST);
  assign crashed = (screen == ST_HIT) || (screen == ST_GAME_OVER);
  assign flash   = (screen == ST_HIT) && (stateFrames < 8'd8);

  logic [game_params_pkg::NUM_COLUMNS-1:0] coralShown;
  assign coralShown = inMenu ? '0 : colActive;

  logic   birdDR;
  color_t birdRGB;

  Bird_Block bird (
      .clk(clk), .resetN(resetN), .pixelX(pixelX), .pixelY(pixelY),
      .tick(tickMove), .run(birdRun), .restart(birdRestart), .mode(birdMode),
      .seedLoad(birdSeedLoad), .seed(birdSeed),
      .animate(!crashed), .blink(screen == ST_HIT),
      .drawingRequest(birdDR), .RGBout(birdRGB), .birdY(birdY));

  logic   coralDR;
  color_t coralRGB;

  Coral_Block coral (
      .clk(clk), .resetN(resetN), .pixelX(pixelX), .pixelY(pixelY),
      .active(coralShown), .colX(colX), .gapTop(gapTop), .gapBottom(gapBottom),
      .drawingRequest(coralDR), .RGBout(coralRGB));

  color_t waterRGB;
  water_background water (.clk(clk), .resetN(resetN), .pixelX(pixelX), .pixelY(pixelY), .RGBout(waterRGB));

  logic   textDR;
  color_t textRGB;
  text_draw text (
      .clk(clk), .resetN(resetN), .pixelX(pixelX), .pixelY(pixelY), .screen(screen),
      .menuCursor(menuCursor), .scoreDigits(score), .bestDigits(best), .newBest(newBest),
      .blink(blink), .drawingRequest(textDR), .RGBout(textRGB));

  logic   speedDR;
  color_t speedRGB;
  speed_readout speedReadout (
      .clk(clk), .resetN(resetN), .pixelX(pixelX), .pixelY(pixelY), .screen(screen),
      .speedLevel(speedLevel), .drawingRequest(speedDR), .RGBout(speedRGB));

  logic   panelDR;
  color_t panelRGB;
  ui_panels panels (
      .clk(clk), .resetN(resetN), .pixelX(pixelX), .pixelY(pixelY), .screen(screen),
      .menuCursor(menuCursor), .flash(flash), .drawingRequest(panelDR), .RGBout(panelRGB));

  objects_mux mux (
      .clk(clk), .resetN(resetN),
      .speedDrawingRequest(speedDR), .speedRGB(speedRGB),
      .textDrawingRequest(textDR), .textRGB(textRGB),
      .panelDrawingRequest(panelDR), .panelRGB(panelRGB),
      .birdDrawingRequest(birdDR), .birdRGB(birdRGB),
      .coralDrawingRequest(coralDR), .coralRGB(coralRGB),
      .backgroundRGB(waterRGB), .RGBOut(screenRGB));

  logic [2:0][3:0] lowOn, highOn;
  leading_zero_blank #(.DIGITS(3)) lowBlank (.digits(score), .digitOn(lowOn));
  leading_zero_blank #(.DIGITS(3)) highBlank(.digits(best),  .digitOn(highOn));

  hex_display_top hex (
      .clk(clk), .resetN(resetN), .digits({best, score}), .digitOn({highOn, lowOn}),
      .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5));

  sound_core sound (
      .clk(clk), .resetN(resetN), .scoreTrigger(scoreEvent), .failTrigger(failEvent),
      .mute(muteSw), .audioSample(audioSample), .playingScore(), .playingFail());

  assign LEDR = {blink, columnCount, difficulty, screen, resetN, 1'b1};

endmodule

module tb_render;
  import game_state_pkg::*;

  logic clk = 1'b0;
  logic resetN = 1'b0;
  always #15.873 clk = ~clk;

  logic [8:0]  keyCode = 9'h000;
  logic        keyMake = 1'b0;
  logic        keyBreak = 1'b0;
  logic        muteSw = 1'b0;
  logic        backN = 1'b1;
  logic [28:0] ovga;
  logic [6:0]  hex0, hex1, hex2, hex3, hex4, hex5;
  logic [9:0]  ledr;
  logic [15:0] audioSample;

  game_core_sim dut (
      .clk(clk), .resetN(resetN), .keyCode(keyCode), .keyMake(keyMake), .keyBreak(keyBreak),
      .muteSw(muteSw), .backN(backN),
      .OVGA(ovga), .HEX0(hex0), .HEX1(hex1), .HEX2(hex2), .HEX3(hex3), .HEX4(hex4), .HEX5(hex5),
      .LEDR(ledr), .audioSample(audioSample));

  defparam dut.gameLogic.READY_FRAMES     = 12;
  defparam dut.gameLogic.HIT_FRAMES       = 10;
  defparam dut.gameLogic.OVER_LOCK_FRAMES = 2;
  defparam dut.gameLogic.FIRST_X          = 250;

  localparam logic [8:0] KEY_UP = 9'h175, KEY_DOWN = 9'h172, KEY_ENTER = 9'h05A;

  int frameNo = 0;
  always @(posedge clk) if (dut.startOfFrame) frameNo++;

  logic [23:0] image [0:640*480-1];

  // Records the frame that starts at the next startOfFrame and writes it to fname.
  task automatic capture(input string fname);
    int fd;
    int x, y;
    for (int i = 0; i < 640 * 480; i++) image[i] = 24'hFF00FF;
    @(posedge clk iff dut.startOfFrame);
    @(negedge clk);
    while (!dut.startOfFrame) begin
      if (ovga[27]) begin
        x = int'(dut.vga.H_Cont) - 192;
        y = int'(dut.vga.V_Cont) - 40;
        if (x >= 0 && x < 640 && y >= 0 && y < 480)
          image[y * 640 + x] = {ovga[7:0], ovga[15:8], ovga[23:16]};
      end
      @(negedge clk);
    end
    fd = $fopen(fname, "w");
    $fwrite(fd, "P3\n640 480\n255\n");
    for (int i = 0; i < 640 * 480; i++)
      $fwrite(fd, "%0d %0d %0d\n", image[i][23:16], image[i][15:8], image[i][7:0]);
    $fclose(fd);
    $display("INFO: frame %0d (screen %0d, score %0d%0d%0d) -> %s", frameNo, dut.screen,
             dut.score[2], dut.score[1], dut.score[0], fname);
  endtask

  task automatic wait_frames(input int n);
    repeat (n) @(posedge clk iff dut.startOfFrame);
  endtask

  // The keyboard block updates keyCode with a one-clock make or break pulse.
  task automatic key_event(input logic [8:0] code, input bit isBreak);
    @(negedge clk);
    keyCode  = code;
    keyMake  = !isBreak;
    keyBreak = isBreak;
    @(negedge clk);
    keyMake  = 1'b0;
    keyBreak = 1'b0;
  endtask

  task automatic press(input logic [8:0] code);
    key_event(code, 0);
    repeat (1000) @(negedge clk);
    key_event(code, 1);
    wait_frames(1);
  endtask

  // The game now boots straight into the difficulty menu (no mode-selection
  // screen, since HUMAN PLAY is the only mode left).
  task automatic tour();
    int difficulty, columns;
    if (!$value$plusargs("difficulty=%d", difficulty)) difficulty = 1;
    if (!$value$plusargs("columns=%d", columns)) columns = 3;

    wait_frames(3);
    capture("tour_0_menu_difficulty.ppm");
    repeat (difficulty) press(KEY_DOWN);
    press(KEY_ENTER);
    repeat (columns - 1) press(KEY_DOWN);
    capture("tour_1_menu_obstacles.ppm");
    press(KEY_ENTER);
    wait_frames(3);
    capture("tour_2_get_ready.ppm");
    wait (dut.screen == ST_PLAY);
    // steer the maze upwards for a few frames, then let the bird crash
    key_event(KEY_UP, 0);
    wait_frames(12);
    key_event(KEY_UP, 1);
    wait_frames(8);
    capture("tour_3_play.ppm");
    // the crash may already have happened while steering
    wait (dut.screen == ST_HIT || dut.screen == ST_GAME_OVER);
    if (dut.screen == ST_HIT) capture("tour_4_hit_flash.ppm");
    wait (dut.screen == ST_GAME_OVER);
    wait_frames(3);
    capture("tour_5_game_over.ppm");
    press(KEY_DOWN);
    capture("tour_6_game_over_main_menu.ppm");
    press(KEY_ENTER);
    wait_frames(3);
    capture("tour_7_back_to_difficulty_menu.ppm");
    if (dut.screen != ST_MENU_DIFF) $display("FAIL: MAIN MENU did not return to the difficulty menu");
  endtask

  initial begin
    string shots;
    string scenario;
    int    target;
    int    pos;

    repeat (5) @(posedge clk);
    resetN = 1'b1;

    if ($value$plusargs("scenario=%s", scenario) && scenario == "tour") begin
      tour();
    end else begin
      if (!$value$plusargs("shots=%s", shots)) shots = "2";
      pos = 0;
      while (pos < shots.len()) begin
        target = 0;
        while (pos < shots.len() && shots[pos] >= "0" && shots[pos] <= "9") begin
          target = target * 10 + (shots[pos] - "0");
          pos++;
        end
        while (pos < shots.len() && (shots[pos] < "0" || shots[pos] > "9")) pos++;
        while (frameNo < target - 1) @(posedge clk);
        capture($sformatf("frame_%0d%0d%0d.ppm", target / 100, (target / 10) % 10, target % 10));
      end
    end
    $display("PASS: tb_render");
    $finish;
  end

endmodule
