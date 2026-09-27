// The part of the coral world that does not depend on the player: the
// columns' horizontal motion and their random openings.
//
// Given the same seed, settings and tick sequence it always produces the same
// world. (The bird's own autonomous motion lives in Bird_Block, a top-level
// object with its own seed stream — see game_logic.sv.)

module world_engine
  import game_params_pkg::*;
#(
    parameter int FIRST_X = CORAL_FIRST_X
) (
    input  logic                         clk,
    input  logic                         resetN,
    input  logic                         tickMove,
    input  logic                         tickCheck,

    input  logic                         seedLoad,     // load the round seed (one clock before restart)
    input  logic [15:0]                  seed,
    input  logic                         restart,      // new round: place the columns
    input  logic                         worldRun,     // columns advance on tickMove, passes count
    input  logic [1:0]                   columnCount,  // 1..3
    input  logic [11:0]                  worldStep,    // 1/64 px per frame

    output logic [NUM_COLUMNS-1:0]       colActive,
    output logic [NUM_COLUMNS-1:0][10:0] colX,
    output logic [NUM_COLUMNS-1:0][8:0]  gapBase,
    output logic                         passPulse     // one column passed the bird
);

  logic [15:0] worldRnd;

  lfsr_rng worldRng (
      .clk     (clk),
      .resetN  (resetN),
      .step    (tickMove),
      .seedLoad(seedLoad),
      .seed    (seed),
      .rnd     (worldRnd)
  );

  column_track #(.FIRST_X(FIRST_X)) columns (
      .clk        (clk),
      .resetN     (resetN),
      .tickMove   (tickMove),
      .tickCheck  (tickCheck),
      .run        (worldRun),
      .restart    (restart),
      .columnCount(columnCount),
      .worldStep  (worldStep),
      .rnd        (worldRnd),
      .active     (colActive),
      .colX       (colX),
      .gapBase    (gapBase),
      .passPulse  (passPulse)
  );

endmodule
