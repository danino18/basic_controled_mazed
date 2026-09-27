// The player object, matching the course's Smiley_Block_T: it owns its own
// autonomous motion (bird_trajectory, in place of smiley_move) and its own
// random stream, then draws itself the same way (square_object for the
// moving 32x32 bracket, birdBitMap for the pixels, in place of smileyBitMap).
// birdY is also exposed for game_logic's collision check, since this game
// uses geometric collision rather than the course demo's drawing-request AND.
// Latency: 3 clocks from pixelX/pixelY to drawingRequest/RGBout.

module Bird_Block
  import palette_pkg::*, game_params_pkg::*;
(
    input  logic                clk,
    input  logic                resetN,
    input  logic [10:0]         pixelX,
    input  logic [10:0]         pixelY,
    input  logic                tick,         // once per frame (tickMove)
    input  logic                run,          // advance the bird's motion this frame
    input  logic                restart,      // return the bird to centre (one clock)
    input  logic [1:0]          mode,         // DIFF_EASY / DIFF_MEDIUM / DIFF_HARD
    input  logic                seedLoad,     // load the round seed (one clock before restart)
    input  logic [15:0]         seed,
    input  logic                animate,      // flap the fin
    input  logic                blink,        // flash the bird (after a hit)
    output logic                drawingRequest,
    output color_t              RGBout,
    output logic signed [10:0]  birdY         // top edge of the sprite, for collision
);

  // Own random stream, derived from the shared round seed the same way
  // world_engine derived the coral world's stream, so the two stay independent.
  logic [15:0] rnd;

  lfsr_rng birdRng (
      .clk     (clk),
      .resetN  (resetN),
      .step    (tick),
      .seedLoad(seedLoad),
      .seed    ({seed[7:0], seed[15:8]} ^ 16'h5A5A),
      .rnd     (rnd)
  );

  bird_trajectory trajectory (
      .clk      (clk),
      .resetN   (resetN),
      .tick     (tick),
      .run      (run),
      .restart  (restart),
      .mode     (mode),
      .rnd      (rnd),
      .birdY    (birdY),
      .birdVy   (),
      .trajState()
  );

  logic [10:0] offsetX;
  logic [10:0] offsetY;
  logic        inBracket;

  square_object #(
      .OBJECT_WIDTH_X (BIRD_SIZE),
      .OBJECT_HEIGHT_Y(BIRD_SIZE)
  ) bracket (
      .clk           (clk),
      .resetN        (resetN),
      .pixelX        (pixelX),
      .pixelY        (pixelY),
      .topLeftX      (11'(BIRD_X)),
      .topLeftY      (birdY),
      .offsetX       (offsetX),
      .offsetY       (offsetY),
      .drawingRequest(inBracket),
      .RGBout        ()
  );

  // ---------------------------------------------------------------- animation
  logic [1:0] frame;
  logic       blinkOff;

  bird_anim anim (
      .clk     (clk),
      .resetN  (resetN),
      .tick    (tick),
      .animate (animate),
      .blink   (blink),
      .frame   (frame),
      .blinkOff(blinkOff)
  );

  logic   bitmapDR;
  color_t bitmapRGB;

  birdBitMap bitmap (
      .clk            (clk),
      .resetN         (resetN),
      .offsetX        (offsetX),
      .offsetY        (offsetY),
      .InsideRectangle(inBracket),
      .frame          (frame),
      .drawingRequest (bitmapDR),
      .RGBout         (bitmapRGB)
  );

  assign drawingRequest = bitmapDR && !blinkOff;
  assign RGBout         = bitmapRGB;

endmodule
