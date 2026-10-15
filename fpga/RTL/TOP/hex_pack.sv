// Packs score and best into the six display digits (best in the high half, as in the
// structural top) and the matching leading-zero blanking bits.

module hex_pack (
    input  logic [2:0][3:0] score,
    input  logic [2:0][3:0] best,
    input  logic [2:0]      lowOn,
    input  logic [2:0]      highOn,
    output logic [5:0][3:0] digits,
    output logic [5:0]      digitOn
);

  assign digits  = {best, score};
  assign digitOn = {highOn, lowOn};

endmodule
