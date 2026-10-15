// Packs the debug signals onto the ten red LEDs, exactly as the structural top did:
// LEDR[9]=blink, [8:7]=columns, [6:5]=difficulty, [4:2]=screen, [1]=resetN, [0]=PLL locked.

module led_pack (
    input  logic       blink,
    input  logic [1:0] columnCount,
    input  logic [1:0] difficulty,
    input  logic [2:0] screen,
    input  logic       resetN,
    input  logic       pllLocked,
    output logic [9:0] LEDR
);

  assign LEDR = {blink, columnCount, difficulty, screen, resetN, pllLocked};

endmodule
