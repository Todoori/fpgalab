`default_nettype none
`include "pkg.sv"  // Import the package where `data_t` and `NLEDS` are defined

module loudness_top #(
) (
	input var logic arstn,
	input var logic clk,

	input var loudness_meter_pkg::data_t data,
	input var logic data_valid,
	output var logic data_ready,
	
	output var logic [loudness_meter_pkg::NLEDS-1:0] led
	
);

//This module computes the lowpassfiltered signal of abs(input) and then takes the logarithm of that and outputs that to the LEDS in a temperature code
//We pipeline this as much as feasible, but this is probably not required
logic [$bits(loudness_meter_pkg::data_t)-1:0] abs_v;
logic abs_valid, abs_ready;
abs_value #(
	.dtype_out_t(logic [$bits(loudness_meter_pkg::data_t)-1:0])
) abs_value_i (
	.arstn(arstn),
	.clk(clk),
	.data(data),
	.data_valid(data_valid),
	.data_ready(data_ready),
	.abs(abs_v),
	.abs_valid(abs_valid),
	.abs_ready(abs_ready)
);

logic[$bits(loudness_meter_pkg::data_t)-1:0] filtered_v;
logic filtered_valid, filtered_ready;
iir_filter #(
	.dtype_in_t(logic[$bits(loudness_meter_pkg::data_t)-1:0]),
	.dtype_out_t(logic[$bits(loudness_meter_pkg::data_t)-1:0]),
	.BITSINTERNAL($bits(loudness_meter_pkg::data_t)+4)
) filter_i (
	.arstn(arstn),
	.clk(clk),
	.data(abs_v),
	.data_valid(abs_valid),
	.data_ready(abs_ready),
	.filtered_data(filtered_v),
	.filtered_valid(filtered_valid),
	.filtered_ready(filtered_ready)
);

logic[$clog2($bits(loudness_meter_pkg::data_t)+1)-1:0] log_v;
logic log_valid, log_ready;
logarithm #(
	.dtype_in_t(logic [$bits(loudness_meter_pkg::data_t)-1:0]),
	.dtype_out_t(logic[$clog2($bits(loudness_meter_pkg::data_t)+1)-1:0])
) log_i (
	.arstn(arstn),
	.clk(clk),
	.data(filtered_v),
	.data_valid(filtered_valid),
	.data_ready(filtered_ready),
	.log_data(log_v),
	.log_valid(log_valid),
	.log_ready(log_ready)
);

logic [loudness_meter_pkg::NLEDS-1:0] temp;
logic temp_valid, temp_ready;
temp_encoder #(
	.dtype_in_t(logic[$clog2($bits(loudness_meter_pkg::data_t)+1)-1:0]),
	.NOUT(loudness_meter_pkg::NLEDS)
) encoder_i (
	.arstn(arstn),
	.clk(clk),
	.data(log_v),
	.data_valid(log_valid),
	.data_ready(log_ready),
	.temp(temp),
	.temp_valid(temp_valid),
	.temp_ready(temp_ready)
);
assign temp_ready = 1'd1;
//The LEDs are physically located right to left in ascending (index) order.
//Conceptually, the display should be filling from left to right, so we reverse the bitorder here
assign led = {<<{temp}};

endmodule



module abs_value #(
	parameter type dtype_out_t=logic
) (
	input var logic arstn,
	input var logic clk,

	input var loudness_meter_pkg::data_t data,
	input var logic data_valid,
	output var logic data_ready,
	
	output var dtype_out_t abs,
	output var logic abs_valid,
	input var logic abs_ready
);

dtype_out_t abs_value;

assign abs_value = ($signed(data) < 0) ? -data : data;
stream_register #(
		.dtype_t(dtype_out_t)
) output_reg (
	.clk(clk),
	.arstn(arstn),
	.data_i(abs_value),
	.valid_i(data_valid),
	.ready_o(data_ready),
	.data_o(abs),
	.valid_o(abs_valid),
	.ready_i(abs_ready)
);

endmodule


module logarithm #(
	parameter type dtype_in_t=logic,
	parameter type dtype_out_t=logic
) (
	input var logic arstn,
	input var logic clk,

	input var dtype_in_t data,
	input var logic data_valid,
	output var logic data_ready,
	
	output var dtype_out_t log_data,
	output var logic log_valid,
	input var logic log_ready
);

//For a 4 bit number, the logarithm for some values is:
// 0001: 0
// 0010: 1
// 0100: 2
// 1000: 3
//This means that the first approximation of the logarithm is NBITS - LZC
//A better approximation can then use a  LUT on the next N bits. We have a 4 bit output, so this might not matter here.
localparam int INPUTBITS = $bits(dtype_in_t);
logic [$clog2(INPUTBITS+1)-1:0] lzc; //Leading zero count
always_comb begin
	lzc = INPUTBITS;
	// @SuppressProblem -type non_synthesizable_construct -count 1 -length 1
	for (int i = 0; i < INPUTBITS; i++) begin
		if (data[INPUTBITS-i-1] == 1'b1) begin
			lzc = i;
			break;
		end
	end
	
end

stream_register #(
	.dtype_t(dtype_out_t)
) output_reg (
.clk(clk),
.arstn(arstn),
.data_i(INPUTBITS - lzc),
.valid_i(data_valid),
.ready_o(data_ready),
.data_o(log_data),
.valid_o(log_valid),
.ready_i(log_ready)
);


//synthesis translate_off
int log_gt;
assign log_gt = $clog2(data);
//synthesis translate_on
endmodule


module iir_filter #(
	parameter type dtype_in_t=logic,
	parameter type dtype_out_t=logic,
	parameter int BITSINTERNAL=24
) (
	input var logic arstn,
	input var logic clk,

	input var dtype_in_t data,
	input var logic data_valid,
	output var logic data_ready,
	
	output var dtype_out_t filtered_data,
	output var logic filtered_valid,
	input var logic filtered_ready
);

localparam int SHIFTVALUE = (BITSINTERNAL - $bits(dtype_out_t));

logic unsigned [BITSINTERNAL-1:0] int_value, next_value;
assign next_value = (int_value*15/16) + data;
stream_register #(
	.dtype_t(logic unsigned [BITSINTERNAL-1:0])
) output_reg (
.clk(clk),
.arstn(arstn),
.data_i(next_value),
.valid_i(data_valid),
.ready_o(data_ready),
.data_o(int_value),
.valid_o(filtered_valid),
.ready_i(filtered_ready)
);

assign filtered_data = (int_value >> SHIFTVALUE); //only output the upper bits

endmodule

module temp_encoder #(
	parameter type dtype_in_t=logic,
	parameter int NOUT= 16
) (
	input var logic arstn,
	input var logic clk,

	input var dtype_in_t data,
	input var logic data_valid,
	output var logic data_ready,
	
	output var logic [NOUT-1:0] temp,
	output var logic temp_valid,
	input var logic temp_ready
);

logic [NOUT-1:0] temp_coded;
assign temp_coded = (1 << data) - 'd1;
stream_register #(
	.dtype_t(logic [NOUT-1:0])
) output_reg (
.clk(clk),
.arstn(arstn),
.data_i(temp_coded),
.valid_i(data_valid),
.ready_o(data_ready),
.data_o(temp),
.valid_o(temp_valid),
.ready_i(temp_ready)
);

endmodule


// A streaming register
module stream_register #(
	parameter type dtype_t=logic		
) (
	input var logic clk,
	input var logic arstn,
	input var dtype_t data_i,
	input var logic valid_i,
	output var logic ready_o,
	
	output var dtype_t data_o,
	output var logic valid_o,
	input var logic ready_i	
);

always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) data_o <= '0;
	else if (valid_i && ready_o) data_o <= data_i;
end

always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) valid_o <= 1'b0;
	else if (ready_o) valid_o <= valid_i;
end

assign ready_o = ready_i || !valid_o;
endmodule

// Instantiate checkers for the axi stream
// synthesis translate_off
// stream_prop #(.dtype_t(dtype_t)) prop_in (
//     .clk  (clk),
//     .rstn (arstn),
//     .valid(valid_i),
//     .ready(ready_o),
//     .data (data_i)
// );
// stream_prop #(.dtype_t(dtype_t)) prop_out (
//     .clk  (clk),
//     .rstn (arstn),
//     .valid(valid_o),
//     .ready(ready_i),
//     .data (data_o)
// );
// synthesis translate_on




//A wrapper for debugging that instantiates the vga top and a debug core to drive the input signal
module loudness_top_wrapper (
	input var logic arstn,
	input var logic clk,
	
	output var logic [15:0] led
);



loudness_meter_pkg::data_t data;
logic data_valid, data_ready;
jtag_axi jtag_axi_i(
	.aclk(clk),
	.aresetn(arstn),
	.m_axi_awready(1'd1),
	.m_axi_wdata(data),
	.m_axi_wvalid(data_valid),
	.m_axi_wready(data_ready),
	.m_axi_bid('d0),
	.m_axi_bresp('d0),
	.m_axi_bvalid(1'd1),
	.m_axi_arready(1'd0),
	.m_axi_rvalid(1'd0)
);

loudness_top DUT (
	.clk(clk),
	.arstn(arstn),
	.data(data),
	.data_valid(data_valid),
	.data_ready(data_ready),
	.led(led)
);

endmodule