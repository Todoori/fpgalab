`timescale 1ns / 1ps

module dc_block #(
	parameter int WIDTH=16
) (
	input var logic clk,
	input var logic arstn,
	
	input var logic [WIDTH-1:0] data,
	input var logic data_valid,
	
	output var logic [WIDTH:0] filtered,
	output var logic filtered_valid
);

assign filtered_valid = data_valid;
//6212 is a measured DC offset coming from the microphone
assign filtered = $signed($signed(data)+6212);
endmodule

module i2s_to_pcm (
	// system ports
	input var logic clk, //system clk
	input var logic arstn,  // asynchronous reset

	// mic interface
	output var logic bclk,  // mic clk in this case wire
	input var logic data,  // audio samples
	output var logic lrclk, //also ws
	output var logic sel,
	
	// axi output interface
	output var logic[15:0] tdata_pcm,  
	output var logic tvalid_pcm
);

// generating 16.384Mhz clock form 100Mhz system clk
logic clk_gen_fast; // use this signal for 16.384Mhz clk
logic bclk_reg;
// Use actual clock wizard in synthesis
clk_wiz_1
         u_clk_wiz_0 (
                        .clk_in1 (clk),
                        .clk_out1(clk_gen_fast),
                        .reset(arstn)
     
                    );




// generating 4.098Mhz clk for the mic to support 64Khz sampling. To do so a division by 4 is required.
localparam int DOWNSAMPLE = 4; // clock divisor (counter upper bond)
logic [$clog2(DOWNSAMPLE)-1:0] ds_cnt = '0; //Start at 0, use this signal as your counter
always_ff @(posedge clk_gen_fast or negedge arstn) begin
    if (~arstn) begin
    
        bclk_reg <= 0;
        ds_cnt <= 0; end
    else begin
        bclk_reg <= (ds_cnt <= 1) ? 1'b1 : 1'b0;
        ds_cnt <= ds_cnt + 1;   end
end


assign bclk =bclk_reg;


// generating WS and sel for the mic
logic en;
assign en = ds_cnt == '0;
localparam int BITS = 32; 
logic [$clog2(2*BITS)-1:0] ws_cnt;
always_ff @(posedge clk_gen_fast or negedge arstn) begin
	if (!arstn) ws_cnt <= '0;
	else if (en) begin
		if (ws_cnt == 2*BITS-1) ws_cnt <= '0;
		else  ws_cnt <= ws_cnt + 'd1;
	end 
end
assign lrclk = ws_cnt >= BITS;
assign sel = 1'd0;

// recording mic audio samples
logic [BITS-1:0] lreg, rreg;
always_ff @(posedge clk_gen_fast) begin
	if (en) begin
		if (lrclk == 1'd0) lreg[BITS-ws_cnt-1] <= data;
		else rreg[2*BITS-ws_cnt-1] <= data;
	end
end

// generating valid to signal that data has been fully recorded
logic left_valid;
always_ff @(posedge clk_gen_fast) begin
	left_valid <= en && ws_cnt == BITS-1;
end

// Cross Domain Crossing from clk_gen_fast to system clk
logic valid_fast;
xpm_cdc_pulse #(
	.DEST_SYNC_FF(4),   // DECIMAL; range: 2-10
	.INIT_SYNC_FF(1),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
	.REG_OUTPUT(1),     // DECIMAL; 0=disable registered output, 1=enable registered output
	.RST_USED(1),       // DECIMAL; 0=no reset, 1=implement reset
	.SIM_ASSERT_CHK(1)  // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
 )
 xpm_cdc_pulse_inst (
	.dest_pulse(valid_fast), 
	.dest_clk(clk),     // 1-bit input: Destination clock.
	.src_clk(clk_gen_fast),       // 1-bit input: Source clock.
	.src_pulse(left_valid),
	.dest_rst(!arstn),
	.src_rst(!arstn)
 );

localparam int BITSACC = 18;
logic [BITS-1:0] tdata_async_reg;
logic [BITSACC:0] tdata_d1;
logic valid_d,valid_d1;
always_ff @(posedge clk) begin
	if (valid_fast)	tdata_async_reg <= lreg; 
	valid_d <= valid_fast;
end

// handling the mic DC offset
dc_block #(
	.WIDTH(BITSACC)
) u_dc_block (
	.clk           (clk),
	.arstn         (arstn),
	.data          (tdata_async_reg[BITS-1 -: BITSACC]),
	.data_valid    (valid_d),
	.filtered      (tdata_d1),
	.filtered_valid(valid_d1)
);

// average 4 values to get the downsampled signal
logic [$clog2(4)-1:0] outsel;
logic [4-1:0][BITSACC:0] tdata_prev;
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) outsel <= '0;
	else if (valid_d1) outsel <= outsel+'d1;
end
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) tdata_prev <= '0;
	else if (valid_d1) tdata_prev[outsel] <= tdata_d1;
end
logic [BITSACC+$clog2(4):0] tdata_full;
always_comb begin
	tdata_full = '0;
	for(int i=0; i<4; i++) tdata_full = $signed(tdata_full)+$signed(tdata_prev[i]);
end

// generating axi interface 
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) begin
		tdata_pcm <= '0;
		tvalid_pcm <= 1'b0;
	end else if (valid_d1 && outsel == '0) begin
		tdata_pcm <= tdata_full[$bits(tdata_full)-1 -: 16]; 
		tvalid_pcm <= 1'b1;
	end else begin
		tvalid_pcm <= 1'b0;
	end
end


endmodule