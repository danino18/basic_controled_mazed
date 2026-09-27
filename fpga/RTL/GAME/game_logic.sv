// All game rules, with no knowledge of pixels: game flow, maze steering, coral
// columns, collision and score. Driven by the three per-frame ticks, so the
// same module can run behind the VGA display or be stepped much faster than
// real time by a testbench.
//
// The bird's own autonomous motion lives in Bird_Block (a top-level object,
// matching the course's Smiley_Block_T owning its own physics); this module
// only takes the bird's current position as an input for collision, and
// drives Bird_Block's run/restart/mode/seed the same way it drives the coral
// world below. The coral columns' player-independent motion lives in
// world_engine and the player's part (maze offset, openings, collision) in
// lane_engine.

module game_logic
  import game_params_pkg::*, game_state_pkg::*;
#(
    parameter int READY_FRAMES     = 88,
    parameter int HIT_FRAMES       = 51,
    parameter int OVER_LOCK_FRAMES = 36,
    parameter int FIRST_X          = CORAL_FIRST_X
) (
    input  logic                         clk,
    input  logic                         resetN,
    input  logic                         tickMove,
    input  logic                         tickCheck,
    input  logic                         tickState,

    // keyboard
    input  logic                         upHeld,
    input  logic                         downHeld,
    input  logic                         upPulse,
    input  logic                         downPulse,
    input  logic                         enterPulse,
    input  logic                         speedUpHeld,
    input  logic                         speedDownHeld,
    input  logic                         entropyPulse,   // any key press: latches the random seed
    input  logic                         abort,          // back to the first menu
    input  logic                         speedLoad,      // set the world speed level
    input  logic [2:0]                   speedLoadLevel,

    // the bird's current position, from Bird_Block (for collision only)
    input  logic signed [10:0]           birdY,

    // game flow
    output logic [2:0]                   screen,
    output logic [1:0]                   difficulty,
    output logic [1:0]                   columnCount,
    output logic [1:0]                   menuCursor,
    output logic [7:0]                   stateFrames,

    // drives to Bird_Block: same run/restart/mode/seed shape as world_engine
    // below, so the bird and the coral world stay in lockstep
    output logic                         birdRun,
    output logic                         birdRestart,
    output logic [1:0]                   birdMode,
    output logic                         birdSeedLoad,
    output logic [15:0]                  birdSeed,

    // world state
    output logic signed [9:0]            mazeOffset,
    output logic signed [4:0]            mazeVy,
    output logic [NUM_COLUMNS-1:0]       colActive,
    output logic [NUM_COLUMNS-1:0][10:0] colX,
    output logic [NUM_COLUMNS-1:0][8:0]  gapBase,
    output logic [NUM_COLUMNS-1:0][9:0]  gapTop,
    output logic [NUM_COLUMNS-1:0][9:0]  gapBottom,
    output logic                         collision,
    output logic [NUM_COLUMNS-1:0]       hitColumn,

    // score
    output logic [2:0][3:0]              score,
    output logic [2:0][3:0]              best,
    output logic                         newBest,

    // world/coral scroll speed (Numpad 4/6)
    output logic [2:0]                   speedLevel,

    // raw one-clock events for sound_engine (in the top level): tied to the exact
    // same pulses that award the point and commit the round, so a sound
    // cannot fire without its matching game event, or vice versa
    output logic                         scoreEvent,
    output logic                         failEvent
);

  // ---------------------------------------------------------------- game flow
  logic roundStart;
  logic roundOver;
  logic menuStart;

  game_fsm #(
      .READY_FRAMES    (READY_FRAMES),
      .HIT_FRAMES      (HIT_FRAMES),
      .OVER_LOCK_FRAMES(OVER_LOCK_FRAMES)
  ) fsm (
      .clk        (clk),
      .resetN     (resetN),
      .tick       (tickState),
      .upPulse    (upPulse),
      .downPulse  (downPulse),
      .enterPulse (enterPulse),
      .collision  (collision),
      .abort      (abort),
      .state      (screen),
      .difficulty (difficulty),
      .columnCount(columnCount),
      .menuCursor (menuCursor),
      .stateFrames(stateFrames),
      .roundStart (roundStart),
      .roundOver  (roundOver),
      .menuStart  (menuStart)
  );

  // The round restarts one clock after the seeds are loaded, so the first coral
  // openings already come from the new seed. A round is then a pure function of
  // its seed, which the on-chip trainer relies on to replay identical worlds.
  logic roundStartD;

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) roundStartD <= 1'b0;
    else         roundStartD <= roundStart;
  end

  // ---------------------------------------------------------------- randomness
  // The supplied random.sv latches a free-running counter on every key press;
  // human timing makes that value unpredictable, so it seeds the world at the
  // start of every round.
  logic [15:0] entropy;

  random #(.SIZE_BITS(16), .MIN_VAL(16'h0000), .MAX_VAL(16'hFFFF)) entropySource (
      .clk   (clk),
      .resetN(resetN),
      .rise  (entropyPulse),
      .dout  (entropy)
  );

  logic inMenu, worldRun, steerRun;

  assign inMenu   = (screen == ST_MENU_DIFF) || (screen == ST_MENU_OBST);
  assign worldRun = (screen == ST_PLAY);
  assign steerRun = (screen == ST_PLAY) || (screen == ST_READY);   // the player may line up the coral while getting ready
  assign birdRun  = worldRun || inMenu;                               // the bird bobs behind the menus
  assign birdRestart = roundStartD || menuStart;
  assign birdMode     = inMenu ? DIFF_EASY : difficulty;
  assign birdSeedLoad = roundStart;
  assign birdSeed     = entropy;

  // ---------------------------------------------------------------- world/coral scroll speed
  logic [11:0] worldStep;

  world_speed_control speedControl (
      .clk          (clk),
      .resetN       (resetN),
      .tick         (tickMove),
      .speedUpHeld  (speedUpHeld),
      .speedDownHeld(speedDownHeld),
      .load         (speedLoad),
      .loadLevel    (speedLoadLevel),
      .speedLevel   (speedLevel),
      .worldStep    (worldStep)
  );

  // ---------------------------------------------------------------- world: coral columns
  logic scorePulse;

  world_engine #(.FIRST_X(FIRST_X)) world (
      .clk        (clk),
      .resetN     (resetN),
      .tickMove   (tickMove),
      .tickCheck  (tickCheck),
      .seedLoad   (roundStart),
      .seed       (entropy),
      .restart    (roundStartD),
      .worldRun   (worldRun),
      .columnCount(columnCount),
      .worldStep  (worldStep),
      .colActive  (colActive),
      .colX       (colX),
      .gapBase    (gapBase),
      .passPulse  (scorePulse)
  );

  // ---------------------------------------------------------------- player: maze, openings, collision
  lane_engine lane (
      .clk       (clk),
      .resetN    (resetN),
      .tickMove  (tickMove),
      .tickCheck (tickCheck),
      .steerRun  (steerRun),
      .restart   (roundStartD),
      .moveUp    (upHeld),
      .moveDown  (downHeld),
      .birdY     (birdY),
      .colActive (colActive),
      .colX      (colX),
      .gapBase   (gapBase),
      .mazeOffset(mazeOffset),
      .mazeVy    (mazeVy),
      .gapTop    (gapTop),
      .gapBottom (gapBottom),
      .collision (collision),
      .hitColumn (hitColumn)
  );

  // ---------------------------------------------------------------- score
  score_bcd scoring (
      .clk       (clk),
      .resetN    (resetN),
      .clearScore(roundStartD),
      .addPoint  (scorePulse),
      .commitBest(roundOver),
      .score     (score),
      .best      (best),
      .newBest   (newBest)
  );

  assign scoreEvent = scorePulse;
  assign failEvent  = roundOver;

endmodule
