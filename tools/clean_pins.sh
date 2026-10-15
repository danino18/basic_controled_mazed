#!/bin/sh
# Removes the pin assignments that Quartus wrote into the project file while running
# constraints/pin.tcl (set_location_assignment and the per-pin IO_STANDARD lines).
# pin.tcl stays the only place the pins are defined; run it again after a fresh checkout.
# Usage (from the repository root, with Quartus closed): tools/clean_pins.sh

QSF="${1:-fpga/controlled_maze.qsf}"
[ -f "$QSF" ] || { echo "no such file: $QSF" >&2; exit 1; }

before=$(grep -c -E '^set_location_assignment|^set_instance_assignment -name IO_STANDARD' "$QSF")
grep -v -E '^set_location_assignment|^set_instance_assignment -name IO_STANDARD' "$QSF" > "$QSF.tmp" && mv "$QSF.tmp" "$QSF"
echo "removed $before pin lines from $QSF"
