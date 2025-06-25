transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib riviera/xpm
vlib riviera/jtag_axi
vlib riviera/xil_defaultlib

vmap xpm riviera/xpm
vmap jtag_axi riviera/jtag_axi
vmap xil_defaultlib riviera/xil_defaultlib

vlog -work xpm  -incr "+incdir+../../../../Experiment_3.gen/sources_1/ip/jtag_axi_0/hdl/verilog" -l xpm -l jtag_axi -l xil_defaultlib \
"C:/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  -incr \
"C:/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work jtag_axi  -incr -v2k5 "+incdir+../../../../Experiment_3.gen/sources_1/ip/jtag_axi_0/hdl/verilog" -l xpm -l jtag_axi -l xil_defaultlib \
"../../../ipstatic/hdl/jtag_axi_v1_2_rfs.v" \

vlog -work xil_defaultlib  -incr -v2k5 "+incdir+../../../../Experiment_3.gen/sources_1/ip/jtag_axi_0/hdl/verilog" -l xpm -l jtag_axi -l xil_defaultlib \
"../../../../Experiment_3.gen/sources_1/ip/jtag_axi_0/sim/jtag_axi_0.v" \

vlog -work xil_defaultlib \
"glbl.v"

