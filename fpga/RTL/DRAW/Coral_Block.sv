// The maze/obstacle object, matching the course's HART_DISPLAY: its position
// (which columns are active, where, and where their openings are) is placed
// by the game controller outside this block, exactly as HART_DISPLAY takes
// topLeftX/topLeftY from outside rather than owning a position of its own.
// coral_draw already implements HART_DISPLAY's own two-stage pattern (a
// rectangle hit test per column, then a tiled bitmap lookup) in one module,
// because selecting which of several columns is hit needs a priority pick
// that a single square_object instance cannot do on its own; splitting that
// pick into N separate square_object copies would not match how the course
// block works, so this wrapper is kept a thin pass-through onto coral_draw.

module Coral_Block
  import palette_pkg::*, game_params_pkg::*;
(
    input  logic                         clk,
    input  logic                         resetN,
    input  logic [10:0]                  pixelX,
    input  logic [10:0]                  pixelY,
    input  logic [NUM_COLUMNS-1:0]       active,
    input  logic [NUM_COLUMNS-1:0][10:0] colX,
    input  logic [NUM_COLUMNS-1:0][9:0]  gapTop,
    input  logic [NUM_COLUMNS-1:0][9:0]  gapBottom,
    output logic                         drawingRequest,
    output color_t                       RGBout
);

  coral_draw draw (
      .clk           (clk),
      .resetN        (resetN),
      .pixelX        (pixelX),
      .pixelY        (pixelY),
      .active        (active),
      .colX          (colX),
      .gapTop        (gapTop),
      .gapBottom     (gapBottom),
      .drawingRequest(drawingRequest),
      .RGBout        (RGBout)
  );

endmodule
