// Final mute gate of the sound chain: the sine sample passes through, or is replaced by
// silence while the mute switch (SW0) is on. Same as `mute ? 0 : sinVal` in Sound_Block.sv.

module audio_mute (
    input  logic        mute,
    input  logic [15:0] sample,
    output logic [15:0] audioSample
);

  assign audioSample = mute ? 16'd0 : sample;

endmodule
