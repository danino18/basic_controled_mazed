// The arbiter plus the supplied audio chain (melody_player_1 -> ToneDecoder
// -> prescaler -> addr_counter -> sintable), producing a PCM sample -- every-
// thing Sound_Block.bdf contains except audio_codec_controller itself. Split
// out as its own leaf purely as a simulation seam: audio_codec_controller has
// no ModelSim-Intel-ASE model (see sim/tb_render.sv), so anything that
// contains it can't be instantiated by a testbench. Every testbench targets
// this module directly instead of Sound_Block, the same way game_core_sim
// (in sim/tb_render.sv) targets game_logic/Bird_Block/Coral_Block directly
// instead of the un-simulatable controlled_maze_top_struct.

module sound_core (
    input  logic         clk,
    input  logic         resetN,
    input  logic         scoreTrigger,
    input  logic         failTrigger,
    input  logic         mute,          // SW0: gates only the final PCM sample
    output logic [15:0]  audioSample,   // signed PCM, ready for the codec's DAC input
    output logic         playingScore,  // debug/test: a score jingle is currently playing
    output logic         playingFail    // debug/test: the failure tone is currently playing
);

  logic       startMelody;
  logic [3:0] melodySelect;
  logic       melodyEnded;

  sound_arbiter arbiter (
      .clk         (clk),
      .resetN      (resetN),
      .scoreTrigger(scoreTrigger),
      .failTrigger (failTrigger),
      .melodyEnded (melodyEnded),
      .startMelody (startMelody),
      .melodySelect(melodySelect),
      .playingScore(playingScore),
      .playingFail (playingFail)
  );

  // ---------------------------------------------------------------- supplied audio chain, unmodified
  logic [3:0] tone;
  logic [2:0] octave;
  logic       enableSoundOut;

  melody_player_1 player (
      .resetN        (resetN),
      .CLOCK_31p5    (clk),
      .startMelody   (startMelody),
      .melodySelect  (melodySelect),
      .tone          (tone),
      .octave        (octave),
      .EnableSoundOut(enableSoundOut),
      .melodyEnded   (melodyEnded)
  );

  logic [11:0] preScaleValue;

  ToneDecoder toneDecoder (
      .tone         (tone),
      .octave       (octave),
      .preScaleValue(preScaleValue)
  );

  logic slowEnPulse, slowEnPulseD;

  prescaler presc (
      .clk          (clk),
      .resetN       (resetN),
      .preScaleValue(preScaleValue),
      .slowEnPulse  (slowEnPulse),
      .slowEnPulse_d(slowEnPulseD)
  );

  logic [7:0] sinAddr;

  addr_counter #(.COUNT_SIZE(8)) addrCounter (
      .clk   (clk),
      .resetN(resetN),
      .en    (slowEnPulse),
      .en1   (enableSoundOut),
      .addr  (sinAddr)
  );

  logic [15:0] sinVal;

  sintable #(.COUNT_SIZE(8)) sineTable (
      .clk   (clk),
      .resetN(resetN),
      .ADDR  (sinAddr),
      .volume(1'b1),      // full scale; muting is done below, once, at the output
      .Q     (sinVal)
  );

  // ---------------------------------------------------------------- output
  // Muting only zeroes the sample sent to the codec: it cannot affect the
  // arbiter, the melody state machine, or anything upstream of this line.
  assign audioSample = mute ? 16'sd0 : sinVal;

endmodule
