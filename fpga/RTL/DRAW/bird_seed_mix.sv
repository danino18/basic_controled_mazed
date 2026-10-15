// Derives the bird's private random seed from the shared round seed:
// swap the two bytes, then XOR with a constant, so the bird's stream stays
// independent of the coral world's. Same expression as in Bird_Block.sv.

module bird_seed_mix (
    input  logic [15:0] seed,
    output logic [15:0] seedMix
);

  assign seedMix = {seed[7:0], seed[15:8]} ^ 16'h5A5A;

endmodule
