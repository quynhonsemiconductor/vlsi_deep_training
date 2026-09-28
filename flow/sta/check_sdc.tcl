# OpenSTA script for the GCA stage; driven by flow/sta/run_gca.sh.
read_liberty $::env(LIBERTY)
read_verilog $::env(NETLIST)
link_design  $::env(TOP)
read_sdc     $::env(SDC)

# The GCA pass criterion: nothing below may report a problem.
check_setup -verbose -unconstrained_endpoints -multiple_clock -no_clock \
            -no_input_delay -loops -generated_clocks

report_checks -path_delay max -group_count 5
