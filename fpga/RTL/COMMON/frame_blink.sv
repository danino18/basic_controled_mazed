// Slow toggle for blinking menu lines: one flip every 32 frames.
// Split out as its own leaf so the top level stays pure wiring (no counters).

module frame_blink (
    input  logic clk,
    input  logic resetN,
    input  logic startOfFrame,
    output logic blink
);

  logic [5:0] frameCount;

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN)            frameCount <= '0;
    else if (startOfFrame)  frameCount <= frameCount + 6'd1;
  end

  assign blink = frameCount[5];

endmodule
