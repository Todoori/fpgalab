`default_nettype none

module fft_top #(
) (
	input var logic arstn,
	input var logic clk,
	
	input var logic trigger,
	
	
	input var fft_pkg::complex_t data,
	input var logic data_valid,
	
	output var fft_pkg::real_str_t proc_data,
	output var logic proc_data_valid,
	input var logic proc_data_ready,
	
	output var logic active
	
);
fft_pkg::complex_str_t fft_ser;
logic fft_ser_valid, fft_ser_ready;

serial_fft u_serial_fft (
	.clk_i    (clk    ),
	.arstn  (arstn  ),
	.active (active ),
	.data_i (data ),
	.valid_i(data_valid),
	.trigger(trigger),
	.data_o(fft_ser),
	.valid_o(fft_ser_valid),
	.ready_i(fft_ser_ready)
);


//Compute the absolute value of the complex numbers
fft_pkg::real_str_t abs_value;
logic abs_valid, abs_ready;
fft_abs_value abs_value_i(
	.clk(clk),
	.arstn(arstn),
	.data(fft_ser),
	.data_valid(fft_ser_valid),
	.data_ready(fft_ser_ready),
	.abs_data(abs_value),
	.abs_valid(abs_valid),
	.abs_ready(abs_ready)
);

fft_pkg::real_str_t dropped_freqs;
logic dropped_freqs_valid, dropped_freqs_ready;
drop_upper_freqs #(
	.dtype_t(fft_pkg::real_t)
) u_drop_upper_freqs (
	.clk    (clk    ),
	.arstn  (arstn  ),
	.data_i (abs_value.tdata ),
	.last_i (abs_value.tlast ),
	.valid_i(abs_valid),
	.ready_o(abs_ready),
	.data_o (dropped_freqs.tdata ),
	.last_o (dropped_freqs.tlast ),
	.valid_o(dropped_freqs_valid),
	.ready_i(dropped_freqs_ready)
);

assign dropped_freqs_ready = proc_data_ready;
assign proc_data = dropped_freqs;
assign proc_data_valid = dropped_freqs_valid;

endmodule


//this module and the one below compute the same thing: 512 point ffts every 10ms, for 100 frames
module serial_fft (
	input var logic clk_i,
	input var logic arstn,
	
	output var active,
	input var fft_pkg::complex_t data_i,
	input var logic valid_i,
		
	input var logic trigger,
	
	output var fft_pkg::complex_str_t data_o,
	output var logic valid_o,
	input var logic ready_i
);

logic clk;

// A memory to hold the data
parameter int WINDOWSIZE = fft_pkg::SAMPLE_PER_MS*fft_pkg::WINDOWSIZE_MS;
parameter int Words = 2*WINDOWSIZE;
parameter int AddrWidth = $clog2(Words);
parameter int DataWidth = $bits(data_i);
parameter int Latency = 2;
parameter int Size = 2*fft_pkg::SAMPLE_PER_MS*fft_pkg::WINDOWSIZE_MS*DataWidth;

logic [AddrWidth-1:0] waddr,raddr, raddr_base;
logic [DataWidth-1:0] wdata,rdata;
logic we,re;
xpm_memory_tdpram #(
	.ADDR_WIDTH_A            ( AddrWidth        ), // DECIMAL
	.ADDR_WIDTH_B            ( AddrWidth        ), // DECIMAL
	.AUTO_SLEEP_TIME         ( 0                ), // DECIMAL
	.BYTE_WRITE_WIDTH_A      ( DataWidth     ), // DECIMAL
	.BYTE_WRITE_WIDTH_B      ( DataWidth     ), // DECIMAL
	.CLOCKING_MODE           ( "common_clock"   ), // String
	.ECC_MODE                ( "no_ecc"         ), // String
	.MEMORY_INIT_FILE        ( "none" ), // String
	.MEMORY_INIT_PARAM       ( "0"              ), // String
	.MEMORY_OPTIMIZATION     ( "true"           ), // String
	.MEMORY_PRIMITIVE        ( "auto"           ), // String
	.MEMORY_SIZE             ( Size             ), // DECIMAL in bits!
	.MESSAGE_CONTROL         ( 0                ), // DECIMAL
	.READ_DATA_WIDTH_A       ( DataWidth ), // DECIMAL
	.READ_DATA_WIDTH_B       ( DataWidth ), // DECIMAL
	.READ_LATENCY_A          ( Latency          ), // DECIMAL
	.READ_LATENCY_B          ( Latency          ), // DECIMAL
	.READ_RESET_VALUE_A      ( "0"              ), // String
	.READ_RESET_VALUE_B      ( "0"              ), // String
	.USE_EMBEDDED_CONSTRAINT ( 0                ), // DECIMAL
	.USE_MEM_INIT            ( 1                ), // DECIMAL
	.WAKEUP_TIME             ( "disable_sleep"  ), // String
	.WRITE_DATA_WIDTH_A      ( DataWidth ), // DECIMAL
	.WRITE_DATA_WIDTH_B      ( DataWidth ), // DECIMAL
	.WRITE_MODE_A            ( "no_change"      ), // String
	.WRITE_MODE_B            ( "no_change"      )  // String
) i_xpm_memory_tdpram (
	.dbiterra ( /*not used*/ ), // 1-bit output: Doubble bit error A
	.dbiterrb ( /*not used*/ ), // 1-bit output: Doubble bit error B
	.sbiterra ( /*not used*/ ), // 1-bit output: Single bit error A
	.sbiterrb ( /*not used*/ ), // 1-bit output: Single bit error B
	.addra    ( raddr        ), // ADDR_WIDTH_A-bit input: Address for port A
	.addrb    ( waddr        ), // ADDR_WIDTH_B-bit input: Address for port B
	.clka     ( clk    ), // 1-bit input: Clock signal for port A
	.clkb     ( clk          ), // 1-bit input: Clock signal for port B
	.dina     ( '0           ), // WRITE_DATA_WIDTH_A-bit input: Data input for port A
	.dinb     ( data_i       ), // WRITE_DATA_WIDTH_B-bit input: Data input for port B
	.douta    ( rdata  ), // READ_DATA_WIDTH_A-bit output: Data output for port A
	.doutb    ( /*not used*/ ), // READ_DATA_WIDTH_B-bit output: Data output for port B
	.ena      ( re         ), // 1-bit input: Memory enable signal for port A
	.enb      ( we           ), // 1-bit input: Memory enable signal for port B
	.injectdbiterra ( 1'b0   ), // 1-bit input: Controls doublebiterror injection on input data
	.injectdbiterrb ( 1'b0   ), // 1-bit input: Controls doublebiterror injection on input data
	.injectsbiterra ( 1'b0   ), // 1-bit input: Controls singlebiterror injection on input data
	.injectsbiterrb ( 1'b0   ), // 1-bit input: Controls singlebiterror injection on input data
	.regcea   ( 1'b1         ), // 1-bit input: Clock Enable for the last register stage
	.regceb   ( 1'b1         ), // 1-bit input: Clock Enable for the last register stage
	.rsta     ( ~arstn       ), // 1-bit input: Reset signal for the final port A output
	.rstb     ( ~arstn       ), // 1-bit input: Reset signal for the final port B output
	.sleep    ( 1'b0         ), // 1-bit input: sleep signal to enable the dynamic power
	.wea      ( 1'b0         ), // WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A
	.web      ( 1'b1         )  // WRITE_DATA_WIDTH_B-bit input: Write enable vector for port B
);

// counting processed samples
logic rlast;
logic [$clog2(WINDOWSIZE)-1:0] sample_count;
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) sample_count <= '0;
	else if (re) begin
		if (sample_count == WINDOWSIZE-1) sample_count <= '0;
		else sample_count <= sample_count + 'd1;
	end
end
assign rlast = sample_count == WINDOWSIZE-1;

// counting processed frame to see if we met the requirements
logic [$clog2(fft_pkg::REQUIRED_FRAMES)-1:0] frame_count;
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) frame_count <= '0;
	else if (re && rlast) begin
		if (frame_count == fft_pkg::REQUIRED_FRAMES-1) frame_count <= '0;
		else frame_count <= frame_count + 'd1;
	end
end
logic done;
assign done = (frame_count == fft_pkg::REQUIRED_FRAMES-1) && rlast && re;

// defining the state machine with two states: WAIT_TRIGGER (waiting for trigger) or ACTIVE (trigger activated)
typedef enum {WAIT_TRIGGER, ACTIVE} state_t;
state_t state,state_next;
assign active  = state != WAIT_TRIGGER;

/// Task 1: implement the state machine
always_ff @(posedge clk or negedge arstn) begin // arstn = trigger button ?
	if(!arstn)
		state <= WAIT_TRIGGER;
	else
		state <= state_next;
	 
end

always_comb begin
	case (state)
		WAIT_TRIGGER: 
			if (trigger) state_next = ACTIVE;
		
		ACTIVE: 
			if (done) state_next = WAIT_TRIGGER;
			
		default: 
			state_next = WAIT_TRIGGER;
	endcase
end

/// Task 2: generate waddr and we to capture data
// Generate write enable signal - we write data when in ACTIVE state and input data is valid
assign we = state == ACTIVE && valid_i;

always_ff @(posedge clk or negedge arstn) begin
    if (!arstn || state == WAIT_TRIGGER) waddr <= '0;
    else if (we) begin
        if (waddr == Words - 1) waddr <= '0; //reset waddr to 0 when it reaches the end
        else waddr <= waddr + 'd1; // increment waddr
    end
end

// generating raddr and re to control data movement
// generating raddr:
logic window_last;
assign window_last = re && rlast;
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) raddr_base <= '0;
	else if (state == WAIT_TRIGGER) raddr_base <= '0;
	else if (window_last) begin
		if (raddr_base < Words-fft_pkg::WINDOWSTEP) raddr_base <= raddr_base + fft_pkg::WINDOWSTEP;
		else raddr_base <= raddr_base + fft_pkg::WINDOWSTEP - Words;
	end
end
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) raddr <= '0;
	else if (state == WAIT_TRIGGER) raddr <= '0;
	else if (re) begin
		if (window_last) begin
			if (raddr_base < Words-fft_pkg::WINDOWSTEP) raddr <= raddr_base + fft_pkg::WINDOWSTEP;
			else raddr <= raddr_base + fft_pkg::WINDOWSTEP - Words;
		end else begin
			if (raddr == Words - 1) raddr <= '0;
			else raddr <= raddr + 'd1;
		end
	end
end
// generating re:
logic [$clog2(Words)-1:0] count;
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) count <= '0;
	else if (state == WAIT_TRIGGER) count <= '0;
	else if (window_last && we)	    count <= count + 1 - fft_pkg::WINDOWSTEP;
	else if (!window_last && we)	count <= count + 1;
	else if (window_last && !we)	count <= count - fft_pkg::WINDOWSTEP;
end
assign re = count > 0 && raddr != waddr && state == ACTIVE;

/// Task 3: generate delayed valid and last signals
logic rvalid; 
logic rl;
logic [1:0] valid_shift_reg;
logic [1:0] last_shift_reg;

// Create 2-cycle delay for valid and last signals to match memory read latency
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) begin
		valid_shift_reg <= '0;
		last_shift_reg <= '0;
	end else begin
		valid_shift_reg <= {valid_shift_reg[0], re};
		last_shift_reg <= {last_shift_reg[0], rlast & re};
	end
end

// Connect delayed signals
assign rvalid = valid_shift_reg[1];
assign rl = last_shift_reg[1];



// FFT instantiation and its configuration
// FFT tdata configuration 
struct packed {
	logic [4:0] pad;
	logic [17:0] scale_sched;
	logic  fwd_inv;
} config_data;
assign config_data.fwd_inv = '1;
assign config_data.scale_sched = 18'hAAA; 
logic fft_ready;  // .s_axis_data_tready (fft_ready), assume that tready is always true
BUFGCE clk_gate (
	.O(clk),
	.CE(fft_ready),
	.I(clk_i)
);
/// Task 4: instantiate the FFT IP 

endmodule


module fft_abs_value (
	input var logic clk,
	input var logic arstn,
	
	input var fft_pkg::complex_str_t data,
	input var logic data_valid,
	output var logic data_ready,
	
	output var fft_pkg::real_str_t abs_data,
	output var logic abs_valid,
	input var logic abs_ready
);
typedef struct packed {
	logic [39:0] value;
	logic last;
} value_t;
value_t square_value, square_value_reg;
logic square_value_valid, square_value_ready;
assign square_value.value = $signed(data.tdata.r_value)*$signed(data.tdata.r_value)+$signed(data.tdata.i_value)*$signed(data.tdata.i_value);
assign square_value.last = data.tlast;
stream_register #(
	.dtype_t(value_t)
) square_reg (
	.clk    (clk    ),
	.arstn  (arstn  ),
	.data_i (square_value ),
	.valid_i(data_valid),
	.ready_o(data_ready),
	.data_o (square_value_reg ),
	.valid_o(square_value_valid),
	.ready_i(square_value_ready)
);
logic [15:0] sqrt_value;
sqrt_cordic sqrt_i (
	.aclk(clk),
	.s_axis_cartesian_tvalid(square_value_valid),
	.s_axis_cartesian_tready(square_value_ready),
	.s_axis_cartesian_tlast(square_value_reg.last),
	.s_axis_cartesian_tdata(square_value_reg.value),
	.m_axis_dout_tvalid(abs_valid),
	.m_axis_dout_tready(abs_ready),
	.m_axis_dout_tlast(abs_data.tlast),
	.m_axis_dout_tdata(sqrt_value )
);
assign abs_data.tdata = 2*sqrt_value[0+:16];
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


//The next block only takes the lower 257 frequencies, so we have to discard all the others
module drop_upper_freqs #(
	parameter int NACCEPT=257, //The first 257 will be accepted, all afterwards (until tlast) will be dropped
	parameter type dtype_t //Must have a last flag
) (
	input var logic clk,
	input var logic arstn,
	input var dtype_t data_i,
	input var logic last_i,
	input var logic valid_i,
	output var logic ready_o,
	
	output var dtype_t data_o,
	output var logic last_o,
	output var logic valid_o,
	input var logic ready_i	 
);
logic [$clog2(NACCEPT*2)-1:0] cnt;
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) cnt <= '0;
	else if(valid_i && ready_o) begin
		if (last_i) cnt <= '0;
		else cnt <= cnt + 'd1;
	end
end
assign data_o = data_i;
assign valid_o = valid_i && (cnt < NACCEPT);
assign ready_o = ready_i || (cnt >= NACCEPT);
assign last_o = (cnt == NACCEPT-1);
endmodule


//We generate currently 100 frames (25*4) to cover 1 second. However, only 97 of those are expected, so we have to get rid of the last 3
module drop_upper_frames #(
	parameter type dtype_t=logic
) (
	input var logic clk,
	input var logic arstn,
	input var dtype_t data_i,
	input var logic last_i,
	input var logic valid_i,
	output var logic ready_o,
	
	output var dtype_t data_o,
	output var logic last_o,
	output var logic valid_o,
	input var logic ready_i	 
);
localparam int TOTALFRAMECOUNT = fft_pkg::FRAME_COUNT*fft_pkg::PARALLELISM;
logic [$clog2(TOTALFRAMECOUNT)-1:0] cnt;
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) cnt <= '0;
	else if(valid_i && ready_o && last_i) begin
		if (cnt == TOTALFRAMECOUNT-1) cnt <= '0;
		else cnt <= cnt + 'd1;
	end
end
assign data_o = data_i;
assign valid_o = valid_i && (cnt < fft_pkg::REQUIRED_FRAMES);
assign ready_o = ready_i || (cnt >= fft_pkg::REQUIRED_FRAMES);
assign last_o = last_i;
endmodule