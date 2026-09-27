// Arbiter in front of the supplied audio chain: only one melody can play at
// a time. Split out of the former monolithic sound_engine so the chain
// wiring (melody_player_1 -> ToneDecoder -> prescaler -> addr_counter ->
// sintable) can sit as its own graphical block, Sound_Block.bdf, matching
// the course's own AUDIO.bdf shape -- see docs/BDF_CONSTRUCTION.md. The
// course's AUDIO.bdf has no such arbiter (it has no game events to
// arbitrate for), so this piece stays a plain leaf, not further BDF wiring.
//
// scoreTrigger and failTrigger are one-clock pulses tied directly to the same
// events that award the point (column_track's passPulse, via world_engine)
// and end the round (game_fsm's roundOver) -- there is no separate
// scoring/sound path, so a sound cannot fire without its matching game event
// or vice versa.
//
// Failure can only happen once before a new round starts (game_fsm freezes
// gameplay after a collision), so one pending bit is enough for it. Score
// events can in principle queue up faster than the ~0.2-0.3 s jingles play,
// so pendingScore is a small saturating counter: every trigger is eventually
// played, in the order fail (higher priority) then score.
//
// melodySelect must be stable for two clocks before startMelody pulses, so
// the supplied melody_player_1's registered-address songs.mif read has
// settled to the right melody before its state machine reads the first
// note's duration (S_SET is exactly that one settle cycle).

module sound_arbiter (
    input  logic       clk,
    input  logic       resetN,
    input  logic       scoreTrigger,
    input  logic       failTrigger,
    input  logic       melodyEnded,   // from melody_player_1
    output logic       startMelody,
    output logic [3:0] melodySelect,
    output logic       playingScore,  // debug/test: a score jingle is currently playing
    output logic       playingFail    // debug/test: the failure tone is currently playing
);

  localparam logic [3:0] SCORE_MELODY = 4'd0;
  localparam logic [3:0] FAIL_MELODY  = 4'd1;
  localparam int         PENDING_SCORE_MAX = 7;

  enum logic [1:0] {S_IDLE, S_SET, S_FIRE, S_WAIT} state;

  logic [2:0] pendingScore;
  logic       pendingFail;

  assign startMelody = (state == S_FIRE);

  // A new trigger and S_FIRE consuming the head of that same queue can land on
  // the same clock (three score events in quick succession is enough to hit
  // this). Two separate "pendingX <= pendingX +/- 1" statements would race --
  // whichever is later in program order silently wins and the other's count
  // is lost -- so both events are folded into one next-value computation per
  // counter instead, and "arrive and consume in the same cycle" nets to zero.
  logic scoreConsume, failConsume;
  logic scoreArrive, failArrive;
  logic [2:0] pendingScoreNext;

  assign scoreConsume = (state == S_FIRE) && (melodySelect == SCORE_MELODY);
  assign failConsume  = (state == S_FIRE) && (melodySelect == FAIL_MELODY);
  // A slot is free either because one is already free, or because this same
  // cycle's S_FIRE is about to consume one (see pendingScoreNext below).
  assign scoreArrive  = scoreTrigger && (scoreConsume || (pendingScore != PENDING_SCORE_MAX[2:0]));
  assign failArrive   = failTrigger;

  always_comb begin
    case ({scoreArrive, scoreConsume})
      2'b10:   pendingScoreNext = pendingScore + 3'd1;
      2'b01:   pendingScoreNext = pendingScore - 3'd1;
      default: pendingScoreNext = pendingScore;   // neither, or both (nets to no change)
    endcase
  end

  always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
      state        <= S_IDLE;
      melodySelect <= '0;
      pendingScore <= '0;
      pendingFail  <= 1'b0;
    end else begin
      pendingScore <= pendingScoreNext;
      pendingFail  <= failArrive || (pendingFail && !failConsume);

      case (state)
        S_IDLE: begin
          if (pendingFail) begin
            melodySelect <= FAIL_MELODY;
            state        <= S_SET;
          end else if (pendingScore != 3'd0) begin
            melodySelect <= SCORE_MELODY;
            state        <= S_SET;
          end
        end
        S_SET:  state <= S_FIRE;
        S_FIRE: state <= S_WAIT;
        S_WAIT: if (melodyEnded) state <= S_IDLE;
        default: state <= S_IDLE;
      endcase
    end
  end

  assign playingScore = (state == S_WAIT) && (melodySelect == SCORE_MELODY);
  assign playingFail  = (state == S_WAIT) && (melodySelect == FAIL_MELODY);

endmodule
