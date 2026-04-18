set dcp "D:/New/Image_processing/Image_processing.runs/impl_1/top_fpga_routed.dcp"
if {![file exists $dcp]} {
  puts "ERROR: DCP not found: $dcp"
  exit 2
}
open_checkpoint $dcp

proc summarize_inits {label pattern} {
  set cells [get_cells -hier -filter "REF_NAME =~ RAMB* && NAME =~ $pattern"]
  puts "${label}_cells=[llength $cells]"
  set total 0
  set nonzero 0
  set printed 0
  foreach c $cells {
    foreach p [list_property $c] {
      if {([string match "INIT_*" $p] && $p ne "INIT_FILE") || [string match "INITP_*" $p]} {
        incr total
        set v [string trim [get_property $p $c]]
        set hex_payload $v
        if {[regexp {^[0-9]+'h([0-9A-Fa-f]+)$} $v -> extracted]} {
          set hex_payload $extracted
        }
        if {$hex_payload ne "" && [regexp {[1-9A-Fa-f]} $hex_payload]} {
          incr nonzero
          if {$printed < 3} {
            puts "${label}_sample_nonzero: cell=$c prop=$p val=$hex_payload"
            incr printed
          }
        }
      }
    }
  }
  puts "${label}_init_props_total=$total"
  puts "${label}_init_props_nonzero=$nonzero"
}

summarize_inits IMEM "*IMEM*"
summarize_inits DMEM "*DMEM*"

close_design
exit 0
