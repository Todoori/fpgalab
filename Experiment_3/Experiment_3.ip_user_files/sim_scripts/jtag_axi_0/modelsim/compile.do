vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xpm
vlib modelsim_lib/msim/jtag_axi
vlib modelsim_lib/msim/xil_defaultlib

vmap xpm modelsim_lib/msim/xpm
vmap jtag_axi modelsim_lib/msim/jtag_axi
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vlog -work xpm  -incr -mfcu  -sv "+incdir+../../../../Experiment_3.gen/sources_1/ip/jtag_axi_0/hdl/verilog" \
"C:/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm  -93  \
"C:/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work jtag_axi  -incr -mfcu  "+incdir+../../../../Experiment_3.gen/sources_1/ip/jtag_axi_0/hdl/verilog" \
"../../../ipstatic/hdl/jtag_axi_v1_2_rfs.v" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../../Experiment_3.gen/sources_1/ip/jtag_axi_0/hdl/verilog" \
"../../../../Experiment_3.gen/sources_1/ip/jtag_axi_0/sim/jtag_axi_0.v" \

vlog -work xil_defaultlib \
"glbl.v"

