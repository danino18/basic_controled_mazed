import game_params_pkg::*;
import game_state_pkg::*;

module top_glue_logic (
    input  logic [2:0] screen,
    input  logic [7:0] stateFrames,
    input  logic [2:0] colActive,
    
    output logic inMenu,
    output logic hit,
    output logic crashed,
    output logic flash,
    output logic [2:0] coralShown
);

  assign hit     = (screen == ST_HIT);
  assign inMenu  = (screen == ST_MENU_DIFF) || (screen == ST_MENU_OBST);
  assign crashed = (screen == ST_HIT) || (screen == ST_GAME_OVER);
  assign flash   = (screen == ST_HIT) && (stateFrames < 8'd8);
  
  assign coralShown = inMenu ? '0 : colActive;

endmodule