set_property SRC_FILE_INFO {cfile:/home/grant/Projects/CICC/la32r_soc/fpga/project/ipgen/clk_pll/clk_pll.xdc rfile:../project/ipgen/clk_pll/clk_pll.xdc id:1 order:EARLY scoped_inst:pll_clk.u_clk_pll/inst} [current_design]
current_instance pll_clk.u_clk_pll/inst
set_property src_info {type:SCOPED_XDC file:1 line:57 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter [get_clocks -of_objects [get_ports clk_in1]] 0.2
