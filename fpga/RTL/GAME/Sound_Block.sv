// Textual, one-to-one stand-in for Sound_Block.bdf -- every block it
// instantiates and every net it wires is exactly what belongs in the BDF,
// giving the audio subsystem the same shape as the course's own AUDIO.bdf
// (see docs/BDF_CONSTRUCTION.md): AUDIO.bdf places audio_codec_controller
// directly alongside the melody chain (melody_player_1 -> ToneDecoder ->
// prescaler -> addr_counter -> sintable), so this module does too -- flat,
// no extra sub-block. sound_arbiter is the one piece with no course
// equivalent (it decides which of two jingles plays next).
//
// sound_core.sv (a separate file) duplicates this same wiring minus
// audio_codec_controller, purely as a simulation seam: the codec has no
// ModelSim-Intel-ASE model, so every testbench (sim/tb_sound.sv, and
// game_core_sim in sim/tb_render.sv) instantiates sound_core directly
// instead of Sound_Block -- the same reason game_core_sim itself exists one
// level below controlled_maze_top_struct.

module Sound_Block (
    input  logic  clk,
    input  logic  resetN,
    input  logic  scoreTrigger,
    input  logic  failTrigger,
    input  logic  mute,           // SW0: gates only the final PCM sample
    input  logic  AUD_ADCLRCK,    // codec is I2S clock master
    input  logic  AUD_BCLK,
    output logic  AUD_DACDAT,
    output logic  AUD_XCK,
    output logic  AUD_I2C_SCLK,
    inout  logic  AUD_I2C_SDAT,
    output logic  playingScore,   // debug/test: a score jingle is currently playing
    output logic  playingFail     // debug/test: the failure tone is currently playing
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

  // ---------------------------------------------------------------- output / codec
  logic [15:0] audioSample;
  assign audioSample = mute ? 16'sd0 : sinVal;

  audio_codec_controller codec (
      .CLOCK31_5    (clk),
      .resetN       (resetN),
      .AUD_ADCLRCK  (AUD_ADCLRCK),
      .AUD_BCLK     (AUD_BCLK),
      .dacdata_left (audioSample),
      .dacdata_right(audioSample),  // mono: same sample on both channels
      .AUD_DACDAT   (AUD_DACDAT),
      .AUD_XCK      (AUD_XCK),
      .AUD_I2C_SCLK (AUD_I2C_SCLK),
      .adcdata_left (),
      .adcdata_right(),
      .AUD_I2C_SDAT (AUD_I2C_SDAT)
  );

endmodule
