// Constant 144: the bird's fixed horizontal position (BIRD_X in game_params_pkg).
// A tiny leaf so Bird_Block.bdf can feed square_object.topLeftX with one symbol.

module bird_x_const (
    output logic [10:0] topLeftX
);

  assign topLeftX = 11'd144;

endmodule
