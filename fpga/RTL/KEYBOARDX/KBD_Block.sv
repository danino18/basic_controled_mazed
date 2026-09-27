// The keyboard subsystem, matching the course's TOP_KBD: the supplied
// precompiled PS2 decoder (KBDINTF, wrapped by kbd_wrapper because it names an
// output "break", a reserved word) feeds a scancode decoder (key_input, in
// place of the course's keyPad_decoder) that turns raw scancodes into the
// game's held/pulse signals.

module KBD_Block (
    input  logic clk,
    input  logic resetN,
    input  logic PS2_CLK,
    input  logic PS2_DAT,
    output logic upHeld,
    output logic downHeld,
    output logic upPulse,
    output logic downPulse,
    output logic enterPulse,
    output logic speedUpHeld,
    output logic speedDownHeld
);

  logic [8:0] keyCode;
  logic       keyMake, keyBreak;

  kbd_wrapper kbd (
      .clk    (clk),
      .resetN (resetN),
      .PS2_CLK(PS2_CLK),
      .PS2_DAT(PS2_DAT),
      .keyCode(keyCode),
      .make   (keyMake),
      .brakk  (keyBreak)
  );

  key_input keys (
      .clk          (clk),
      .resetN       (resetN),
      .keyCode      (keyCode),
      .keyMake      (keyMake),
      .keyBreak     (keyBreak),
      .upHeld       (upHeld),
      .downHeld     (downHeld),
      .upPulse      (upPulse),
      .downPulse    (downPulse),
      .enterPulse   (enterPulse),
      .speedUpHeld  (speedUpHeld),
      .speedDownHeld(speedDownHeld)
  );

endmodule
