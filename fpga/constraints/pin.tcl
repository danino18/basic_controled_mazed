#============================================================
# pin.tcl - DE10-Standard (Cyclone V 5CSXFC6D6F31C6) pin file for controlled_maze
# Registered in controlled_maze.qsf with TCL_SCRIPT_FILE.
# Pin numbers are the ones of the supplied lab constraints/pin.tcl.
#
# How to use (Quartus GUI):
#   1. Processing -> Start -> Start Analysis & Elaboration
#      (the 3.3-V loop at the end needs an analysed netlist)
#   2. Tools -> Tcl Scripts... -> constraints/pin.tcl -> Run
# From a shell:   quartus_sh -t constraints/pin.tcl
# Names must match the ports of the current top-level entity;
# assignments to ports that do not exist are only warned about.
#============================================================


# Opens the project itself when run from a shell (current directory = the project folder).
package require ::quartus::project
set opened_here 0
if {![is_project_open]} {
    project_open controlled_maze
    set opened_here 1
}


#============================================================
# CLOCK
#============================================================
set_location_assignment PIN_AF14 -to CLOCK_50


#============================================================
# KEY
#============================================================
set_location_assignment PIN_AJ4 -to resetN_pin  ; # KEY[0], active low
set_location_assignment PIN_AK4 -to backN_pin  ; # KEY[1], back / pause, active low


#============================================================
# SW
#============================================================
set_location_assignment PIN_AB30 -to SW0  ; # SW[0], global mute


#============================================================
# LED
#============================================================
set_location_assignment PIN_AA24 -to LEDR[0]
set_location_assignment PIN_AB23 -to LEDR[1]
set_location_assignment PIN_AC23 -to LEDR[2]
set_location_assignment PIN_AD24 -to LEDR[3]
set_location_assignment PIN_AG25 -to LEDR[4]
set_location_assignment PIN_AF25 -to LEDR[5]
set_location_assignment PIN_AE24 -to LEDR[6]
set_location_assignment PIN_AF24 -to LEDR[7]
set_location_assignment PIN_AB22 -to LEDR[8]
set_location_assignment PIN_AC22 -to LEDR[9]


#============================================================
# Seg7
#============================================================
set_location_assignment PIN_W17 -to HEX0[0]
set_location_assignment PIN_V18 -to HEX0[1]
set_location_assignment PIN_AG17 -to HEX0[2]
set_location_assignment PIN_AG16 -to HEX0[3]
set_location_assignment PIN_AH17 -to HEX0[4]
set_location_assignment PIN_AG18 -to HEX0[5]
set_location_assignment PIN_AH18 -to HEX0[6]
set_location_assignment PIN_AF16 -to HEX1[0]
set_location_assignment PIN_V16 -to HEX1[1]
set_location_assignment PIN_AE16 -to HEX1[2]
set_location_assignment PIN_AD17 -to HEX1[3]
set_location_assignment PIN_AE18 -to HEX1[4]
set_location_assignment PIN_AE17 -to HEX1[5]
set_location_assignment PIN_V17 -to HEX1[6]
set_location_assignment PIN_AA21 -to HEX2[0]
set_location_assignment PIN_AB17 -to HEX2[1]
set_location_assignment PIN_AA18 -to HEX2[2]
set_location_assignment PIN_Y17 -to HEX2[3]
set_location_assignment PIN_Y18 -to HEX2[4]
set_location_assignment PIN_AF18 -to HEX2[5]
set_location_assignment PIN_W16 -to HEX2[6]
set_location_assignment PIN_Y19 -to HEX3[0]
set_location_assignment PIN_W19 -to HEX3[1]
set_location_assignment PIN_AD19 -to HEX3[2]
set_location_assignment PIN_AA20 -to HEX3[3]
set_location_assignment PIN_AC20 -to HEX3[4]
set_location_assignment PIN_AA19 -to HEX3[5]
set_location_assignment PIN_AD20 -to HEX3[6]
set_location_assignment PIN_AD21 -to HEX4[0]
set_location_assignment PIN_AG22 -to HEX4[1]
set_location_assignment PIN_AE22 -to HEX4[2]
set_location_assignment PIN_AE23 -to HEX4[3]
set_location_assignment PIN_AG23 -to HEX4[4]
set_location_assignment PIN_AF23 -to HEX4[5]
set_location_assignment PIN_AH22 -to HEX4[6]
set_location_assignment PIN_AF21 -to HEX5[0]
set_location_assignment PIN_AG21 -to HEX5[1]
set_location_assignment PIN_AF20 -to HEX5[2]
set_location_assignment PIN_AG20 -to HEX5[3]
set_location_assignment PIN_AE19 -to HEX5[4]
set_location_assignment PIN_AF19 -to HEX5[5]
set_location_assignment PIN_AB21 -to HEX5[6]


#============================================================
# VGA
# OVGA[7:0]=VGA_R  [15:8]=VGA_G  [23:16]=VGA_B  [24]=HS  [25]=VS
#      [26]=SYNC_N  [27]=BLANK_N  [28]=VGA_CLK
#============================================================
set_location_assignment PIN_AK29 -to OVGA[0]
set_location_assignment PIN_AK28 -to OVGA[1]
set_location_assignment PIN_AK27 -to OVGA[2]
set_location_assignment PIN_AJ27 -to OVGA[3]
set_location_assignment PIN_AH27 -to OVGA[4]
set_location_assignment PIN_AF26 -to OVGA[5]
set_location_assignment PIN_AG26 -to OVGA[6]
set_location_assignment PIN_AJ26 -to OVGA[7]
set_location_assignment PIN_AK26 -to OVGA[8]
set_location_assignment PIN_AJ25 -to OVGA[9]
set_location_assignment PIN_AH25 -to OVGA[10]
set_location_assignment PIN_AK24 -to OVGA[11]
set_location_assignment PIN_AJ24 -to OVGA[12]
set_location_assignment PIN_AH24 -to OVGA[13]
set_location_assignment PIN_AK23 -to OVGA[14]
set_location_assignment PIN_AH23 -to OVGA[15]
set_location_assignment PIN_AJ21 -to OVGA[16]
set_location_assignment PIN_AJ20 -to OVGA[17]
set_location_assignment PIN_AH20 -to OVGA[18]
set_location_assignment PIN_AJ19 -to OVGA[19]
set_location_assignment PIN_AH19 -to OVGA[20]
set_location_assignment PIN_AJ17 -to OVGA[21]
set_location_assignment PIN_AJ16 -to OVGA[22]
set_location_assignment PIN_AK16 -to OVGA[23]
set_location_assignment PIN_AK19 -to OVGA[24]
set_location_assignment PIN_AK18 -to OVGA[25]
set_location_assignment PIN_AJ22 -to OVGA[26]
set_location_assignment PIN_AK22 -to OVGA[27]
set_location_assignment PIN_AK21 -to OVGA[28]


#============================================================
# Audio (codec WM8731): ADCLRCK/BCLK in, DACDAT/XCK/I2C_SCLK out, I2C_SDAT bidir
#============================================================
set_location_assignment PIN_AH29 -to AUD_ADCLRCK
set_location_assignment PIN_AF30 -to AUD_BCLK
set_location_assignment PIN_AF29 -to AUD_DACDAT
set_location_assignment PIN_AH30 -to AUD_XCK
set_location_assignment PIN_Y24 -to AUD_I2C_SCLK
set_location_assignment PIN_Y23 -to AUD_I2C_SDAT


#============================================================
# PS2
#============================================================
set_location_assignment PIN_AB25 -to PS2_CLK
set_location_assignment PIN_AA25 -to PS2_DAT


#============================================================
# Assigning 3.3 V to all pins
#============================================================

set name_ids [get_names -filter * -node_type pin]

foreach_in_collection name_id $name_ids {
    set pin_name [get_name_info -info full_path $name_id]
    post_message "Assigning 3.3-V LVTTL to $pin_name"
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to $pin_name
}

export_assignments
if {$opened_here} { project_close }
