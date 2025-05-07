`timescale 1ns/1ps
`default_nettype none

module fft_tb;
    // Basic signals
    logic clk = 0;
    logic arstn = 0;
    logic trigger = 0;
    
    // Data path
    fft_pkg::complex_t data;
    logic data_valid = 0;
    fft_pkg::complex_str_t fft_data;
    logic active;
    
    // Instantiate DUT
    serial_fft dut (
        .clk_i(clk),
        .arstn(arstn),
        .active(active),
        .data_i(data),
        .valid_i(data_valid),
        .trigger(trigger),
        .data_o(fft_data),
        .valid_o(),
        .ready_i(1'b1)
    );
    
    // Clock generation
    always #5 clk = ~clk;
    
    // Counter for input data
    int counter = 0;
    
    // Input data generator
    always_ff @(posedge clk) begin
        if (!arstn)
            counter <= 0;
        else if (data_valid)
            counter <= counter + 1;
            
        data.r_value <= counter;
        data.i_value <= 0;
    end
    
    // Main test sequence
    initial begin
        // Reset
        arstn = 0;
        repeat(5) @(posedge clk);
        arstn = 1;
        
        // Enable data flow
        data_valid = 1;
        
        // Let some data accumulate
        repeat(20) @(posedge clk);
        
        // Trigger and observe
        trigger = 1;
        @(posedge clk);
        trigger = 0;
        
        // Run simulation
        wait(active);
        repeat(500) @(posedge clk);
        
        $display("Test complete - check waveforms to verify windowing");
        $finish;
    end
endmodule
