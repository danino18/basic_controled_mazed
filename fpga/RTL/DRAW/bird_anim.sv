// Bird fin-flap animation counter, split out of Bird_Block so that block
// stays pure wiring (BDF-representable): plays frames 0-1-2-1 while
// animate is high, and derives the post-hit blink-off flag from the same
// counter. Latency: 0 clocks (frame/blinkOff are combinational from state).

module bird_anim
  import game_params_pkg::*;
(
    input  logic       clk,
    input  logic       resetN,
    input  logic       tick,       // once per frame
    input  logic       animate,    // flap the fin
    input  logic       blink,      // flash the bird (after a hit)
    output logic [1:0] frame,
    output logic       blinkOff
);

  logic [3:0] frameCount;
  logic [1:0] animStep;

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      frameCount <= '0;
      animStep   <= '0;
    end else if (tick) begin
      frameCount <= frameCount + 4'd1;
      if (animate && frameCount == 4'(BIRD_FRAMES_PER_ANIM_STEP - 1)) begin
        frameCount <= '0;
        animStep   <= animStep + 2'd1;
      end
    end
  end

  assign frame    = (animStep == 2'd3) ? 2'd1 : animStep;
  assign blinkOff = blink && frameCount[2];

endmodule
