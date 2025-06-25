`timescale 1ns / 1ps
`default_nettype none  
`include "pkg.sv"  // Import the package where `data_t` and `NLEDS` are definede

module top_VGA_Screen (
    input  var logic trigger,
    input  var logic clk,
    input  var logic arstn,
    input  var logic mic_data,                  // PDM mic input
    
    output var logic vga_hor_sync,
    output var logic vga_ver_sync,
    output var logic [3:0] vga_green,
	output var logic [3:0] vga_red,
	output var logic [3:0] vga_blue,
    
    output logic mic_bclk,
    output logic mic_lrcl,
    output logic mic_sel,
    output logic [loudness_meter_pkg::NLEDS-1:0] LED  // LED output
);

    // Intermediate signals
        logic        loud_data_valid;
    var loudness_meter_pkg::data_t loud_data;
    
    logic [15:0] tdata_pcm;
    logic        tvalid_pcm;
    logic        data_ready;  // Output from loudness_top (unused here)
    fft_pkg::real_str_t proc_data;
	logic proc_data_valid;
	logic  proc_data_ready;
	logic  active;
	
	
    logic fft_data;
	logic fft_valid;
	logic fft_ready;

    // Instantiate i2s_to_pcm module
    i2s_to_pcm u_i2s (
        .clk(clk),
        .arstn(arstn),
        .data(mic_data),
        .lrclk(mic_lrcl),
        .tdata_pcm(loud_data),
        .tvalid_pcm(loud_data_valid),
        .sel(mic_sel),
        .bclk(mic_bclk)
    );
    fft_top fft_top_IN
    (
    .arstn(arstn),
    .clk(clk),
    .trigger(trigger),
    .data(tdata_pcm),
    .data_valid(tvalid_pcm),
    .proc_data(proc_data),
    .proc_data_valid(proc_data_valid),
    .proc_data_ready(proc_data_ready)
    
    
    
    
    );
     vga_top  #(.fft_t (fft_pkg::real_str_t))  vga_inst
     (
     .arstn(arstn),
     .clk(clk),
     .fft_data(fft_data),
     .fft_valid(proc_data_valid),
     .vga_red(vga_red),
     .vga_green(vga_green),
     .vga_blue(vga_blue),
     .vga_ver_sync(vga_ver_sync),
     .vga_hor_sync(vga_hor_sync)
     
     
     )     
     ;
    
    // Instantiate loudness_top module
    loudness_top u_loudness (
        .clk(clk),
        .arstn(arstn),
        .data_valid(loud_data_valid),
        .data(loud_data), // cast 16-bit to expected type
        .led(LED)
    );

endmodule
