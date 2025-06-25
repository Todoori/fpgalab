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
	
	output logic ledtest,// test
    output logic re, // test
    output logic rlast, //test
    output logic valid_x,
    output logic valid_y,

    output logic mic_bclk,
    output logic mic_lrcl,
    output logic mic_sel,
    output logic [loudness_meter_pkg::NLEDS-1:5] LED  // LED output
);

    // Intermediate signals
     logic        loud_data_valid;
    var loudness_meter_pkg::data_t loud_data;
    

    

    logic        data_ready;  // Output from loudness_top (unused here)
    fft_pkg::real_str_t proc_data;
	logic proc_data_valid;
	logic  proc_data_ready;
	logic  active;
	
	


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
    fft_pkg::complex_t loud_data_complex;
    assign loud_data_complex.r_value = loud_data;
    assign loud_data_complex.i_value = 16'd0;

    fft_top fft_inst
    (
    .arstn(arstn),
    .clk(clk),
    .trigger(trigger),
    .data(loud_data_complex),
    .data_valid(loud_data_valid),
    .proc_data(proc_data),
    .proc_data_valid(proc_data_valid),
    .proc_data_ready(proc_data_ready),
    
    .active(ledtest),
    .re(re),
    .rlast(rlast)
    
    
    
    );
     vga_top  #(.fft_t (fft_pkg::real_str_t))  vga_inst
     (
     .arstn(arstn),
     .clk(clk),
     .fft_data(proc_data),
     .fft_valid(proc_data_valid),
     .vga_red(vga_red),
     .vga_green(vga_green),
     .vga_blue(vga_blue),
     .vga_ver_sync(vga_ver_sync),
     .vga_hor_sync(vga_hor_sync),
     .valid_x(valid_x),
     .valid_y(valid_y),
     .fft_ready(proc_data_ready),
     .word(0)
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


module fft_top #(
) (
	input var logic arstn,
	input var logic clk,
	
	input var logic trigger,
	
	
	input var fft_pkg::complex_t data,
	input var logic data_valid,
	
	output var fft_pkg::real_str_t proc_data,
	output var logic proc_data_valid,
	
	output var logic re,
	output var logic rlast,
	
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
	.ready_i(fft_ser_ready),
	.re(re),
	.rlast(rlast)
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
	output var logic re,
	output var logic rlast,
	
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
		if (sample_count == WINDOWSIZE-1) sample_count <= '0; //change -1
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
// State transition logic
// FSM state register
always_ff @(posedge clk or negedge arstn) begin     //before
    if (!arstn)
        state <= WAIT_TRIGGER;
    else
        state <= state_next;
end

logic trigger_d, trigger_rise;

// Rising edge detection: trigger goes from 0 to 1
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
        trigger_d    <= trigger;  // initialize correctly
        trigger_rise <= 1'b0;
    end else begin
        trigger_rise <= !trigger_d && trigger;  // detect rising edge
        trigger_d    <= trigger;
    end
end

// FSM next state logic
always_comb begin
    state_next = state;
    case (state)
        WAIT_TRIGGER: begin
            if (trigger_rise && !done)
                state_next = ACTIVE;
        end
        ACTIVE: begin
            if (done)
                state_next = WAIT_TRIGGER;
        end
    endcase
end


// Next state logic
/*always_comb begin
    state_next = state;
    case (state)
        WAIT_TRIGGER: begin
            if (trigger && !done)
                state_next = ACTIVE;
        end
        ACTIVE: begin
            if (done)
                state_next = WAIT_TRIGGER;
        end
    endcase
end */ 
/*always_ff@(posedge clk or posedge trigger or negedge arstn) begin    
        if (!arstn)  state_next<=  WAIT_TRIGGER;
        else if (trigger==1) state_next<=ACTIVE;
        else if(state==ACTIVE) begin
            if(done) state_next<=WAIT_TRIGGER;
        end  


end

always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) state_next<= WAIT_TRIGGER;
    else state <= state_next;

end*/
/// Task 2: generate waddr and we to capture data
// Write address logic and write enable
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn)
		waddr <= '0;
	else if (state == WAIT_TRIGGER)
		waddr <= '0;
	else if (valid_i && state == ACTIVE) begin
		if (waddr == Words - 1)
			waddr <= '0;
		else
			waddr <= waddr + 1;
	end
end

assign we = (valid_i && state == ACTIVE); 
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

// Delay pipeline for valid and last signals
logic [Latency-1:0] re_pipe, rlast_pipe;

always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) begin
		re_pipe <= '0;
		rlast_pipe <= '0;
	end else begin
		re_pipe <= {re_pipe[Latency-2:0], re};
		rlast_pipe <= {rlast_pipe[Latency-2:0], rlast};
	end
end

assign rvalid = re_pipe[Latency-1];
assign rl = rlast_pipe[Latency-1];

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
// Instantiate the FFT core
xfft_0 u_fft (
    .aclk                  (clk_i),
    .s_axis_data_tvalid   (rvalid),
    .s_axis_data_tready   (fft_ready),
    .s_axis_data_tlast    (rl),
    .s_axis_data_tdata    (rdata), // FFT input from memory
    
    .s_axis_config_tvalid (1'b1),
    .s_axis_config_tready (),      // We don't need to monitor config ready
    .s_axis_config_tdata  (config_data),

    .m_axis_data_tvalid   (valid_o),
    .m_axis_data_tready   (ready_i),
    .m_axis_data_tlast    (data_o.tlast),
    .m_axis_data_tdata    (data_o.tdata)
);
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



module vga_top #(
	parameter type fft_t=logic,
	parameter int NWORDS=10
) (
	input var logic arstn,
	input var logic clk,
	
	output var logic vga_hor_sync,
	output var logic vga_ver_sync,
	
	output var logic [3:0] vga_green,
	output var logic [3:0] vga_red,
	output var logic [3:0] vga_blue,
	
	output var logic valid_x,
	output var logic valid_y,
	
	input var fft_t fft_data,
	input var logic fft_valid,
	output var logic fft_ready,
	
	input var logic [$clog2(NWORDS+1)-1:0] word
);

logic clk_pixel;
clk_wiz_0 clk_wiz_i(
	.resetn(arstn),
	.clk_in1(clk),
	.locked(),
	.clk_out1(clk_pixel)
);

logic rstn_pixel;
logic [1:0] rstn_pixel_sync ;
always_ff @(posedge clk_pixel or negedge arstn) begin
	if (!arstn) {rstn_pixel,rstn_pixel_sync} <= '0;
	else {rstn_pixel,rstn_pixel_sync} <= {rstn_pixel_sync, 1'b1};

end

//parameter int NPIXELS = 480*640;
parameter int BITSPERPIXEL = vga_pkg::BITSPERPIXEL;
parameter bit FFT2D = 1'b1; //If this is set, we write in the data one row at a time instead of duplicating it
parameter int MEMHORPIXEL = vga_pkg::X_PIXEL_MEM;
parameter int MEMVERPIXEL =  vga_pkg::Y_PIXEL_MEM;

vga_pkg::vga_ctrl_t vga_ctrl;

vga_gen vga_gen_i(
	.arstn(rstn_pixel),
	.clk_pixel(clk_pixel),
	.vga_ctrl(vga_ctrl)
);

typedef struct {
	logic [BITSPERPIXEL-1:0] pixel;
	logic tlast;
	logic [$clog2(MEMHORPIXEL*MEMVERPIXEL)-1:0] addr;
} pixel_t;


vga_pkg::render_pixel_t pixel_rendered;
logic pixel_ren_valid, pixel_ren_ready;
render_fft #(
	.fft_t(fft_t),
	.TRANSFORMLENGTH(vga_pkg::Y_PIXEL_MEM)
) render_i(
	.clk(clk),
	.arstn(arstn),
	.fft_data(fft_data),
	.fft_valid(fft_valid),
	.fft_ready(fft_ready),
	.pixel(pixel_rendered),
	.pixel_valid(pixel_ren_valid),
	.pixel_ready(pixel_ren_ready)
);

vga_pkg::mem_pixel_t mem_pixel;
image_buf #(
	.BITSPERPIXEL(BITSPERPIXEL),
	.MEMHORPIXEL(MEMHORPIXEL),
	.MEMVERPIXEL(MEMVERPIXEL)	
) image_buf_i (
	.arstn       (rstn_pixel ),
	.clk_pixel   (clk_pixel  ),
	.vga_ctrl(vga_ctrl),
	.clk(clk),
	.pixel(mem_pixel),
	.rend_pixel(pixel_rendered),
	.rend_pixel_valid(pixel_ren_valid),
	.rend_pixel_ready(pixel_ren_ready)	
);

vga_pkg::vga_pixel_t colored_pixel, vga_pixel;
colorize_pixel #(
	.BITSPERPIXEL(BITSPERPIXEL)		
) colorize_pixel_i (
	.clk_pixel(clk_pixel),
	.arstn(rstn_pixel),
	.mem_pixel(mem_pixel),
	.vga_pixel(colored_pixel)
);

detection_overlay overlay_i (
	.clk_pixel(clk_pixel),
	.arstn(rstn_pixel),
	.pixel_i(colored_pixel),
	.pixel_o(vga_pixel),
	.word(word)
);
		
//Final mapping to flat signal
assign vga_blue = vga_pixel.pixel.blue;
assign vga_red = vga_pixel.pixel.red;
assign vga_green = vga_pixel.pixel.green;
assign vga_hor_sync = vga_pixel.ctrl.hs;
assign vga_ver_sync = vga_pixel.ctrl.vs;

endmodule

module colorize_pixel #(
	parameter int BITSPERPIXEL = 1
) (
	input var logic clk_pixel,
	input var logic arstn,
	
	input var vga_pkg::mem_pixel_t mem_pixel,
	output vga_pkg::vga_pixel_t vga_pixel
);

if (BITSPERPIXEL == 1) begin //If 1 bit per pixel, we use 2 defined colors
	localparam vga_pkg::color_pixel_t rgb_0 = '0;
	localparam vga_pkg::color_pixel_t rgb_1 = '1;
	always_ff @(posedge clk_pixel or negedge arstn) begin
		if (!arstn) begin
			vga_pixel <= vga_pkg::vga_pixel_dv;
		end else begin
			vga_pixel.pixel <= {$bits(vga_pkg::color_pixel_t){mem_pixel.ctrl.active}} & (mem_pixel.pixel ? rgb_1 : rgb_0);
			vga_pixel.ctrl <= mem_pixel.ctrl;
		end
	end
end else if (BITSPERPIXEL == $bits(vga_pkg::color_pixel_t)) begin //If 12 bits per pixel, we just apply it
	always_ff @(posedge clk_pixel or negedge arstn) begin
		if (!arstn) begin
			vga_pixel <= vga_pkg::vga_pixel_dv;
		end else begin
			vga_pixel.pixel <= {$bits(vga_pkg::color_pixel_t){mem_pixel.ctrl.active}} & mem_pixel.pixel;
			vga_pixel.ctrl <= mem_pixel.ctrl;
		end
	end
end else begin //Otherwise, we use a lookup table
	vga_pkg::color_pixel_t pixel_fc;
	localparam int Latency = 2;
	// @SuppressProblem -type unresolved_hierarchy -count 1 -length 1
	xpm_memory_sprom #(
		.ADDR_WIDTH_A(BITSPERPIXEL),              // DECIMAL
		.AUTO_SLEEP_TIME(0),           // DECIMAL
		.CASCADE_HEIGHT(0),            // DECIMAL
		.ECC_MODE("no_ecc"),           // String
		.MEMORY_INIT_FILE("C:/Users/moham/Desktop/Fpga/Mem/lut.mem"),     // String
		.MEMORY_INIT_PARAM("0"),       // String
		.MEMORY_OPTIMIZATION("true"),  // String
		.MEMORY_PRIMITIVE("auto"),     // String
		.MEMORY_SIZE($bits(vga_pkg::color_pixel_t)*(2**BITSPERPIXEL)),            // DECIMAL
		.MESSAGE_CONTROL(0),           // DECIMAL
		.READ_DATA_WIDTH_A($bits(vga_pkg::color_pixel_t)),        // DECIMAL
		.READ_LATENCY_A(Latency),            // DECIMAL
		.READ_RESET_VALUE_A("0"),      // String
		.RST_MODE_A("SYNC"),           // String
		.SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
		.USE_MEM_INIT(1),              // DECIMAL
		.WAKEUP_TIME("disable_sleep")  // String
	 )	 lut_mem (
		.douta(pixel_fc),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
		.addra(mem_pixel.pixel),                   // ADDR_WIDTH_A-bit input: Address for port A read operations.
		.clka(clk_pixel),                     // 1-bit input: Clock signal for port A.
		.ena(1'd1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
		.injectdbiterra(1'b0), // 1-bit input: Do not change from the provided value.
		.injectsbiterra(1'b0), // 1-bit input: Do not change from the provided value.
		.regcea(1'd1),                 // 1-bit input: Do not change from the provided value.
		.rsta(!arstn),                     // 1-bit input: Reset signal for the final port A output register stage.
		.sleep(1'b0)                    // 1-bit input: sleep signal to enable the dynamic power saving feature.
	 );
	
	
	vga_pkg::vga_ctrl_t [Latency-1:0] vga_ctrl_del;
	always_ff @(posedge clk_pixel or negedge arstn) begin
		if (!arstn)	vga_ctrl_del <= {Latency{vga_pkg::vga_ctrl_dv}};
		else vga_ctrl_del <= {vga_ctrl_del[Latency-2:0], mem_pixel.ctrl};
	end
		
	always_ff @(posedge clk_pixel or negedge arstn) begin
		if (!arstn) begin
			vga_pixel <= vga_pkg::vga_pixel_dv;
		end else begin
			vga_pixel.pixel <= {$bits(vga_pkg::color_pixel_t){vga_ctrl_del[Latency-1].active}} & pixel_fc;
			vga_pixel.ctrl <= vga_ctrl_del[Latency-1];
		end
	end

end

endmodule

// This module takes in a 25MHz clock as pixel clock
module vga_gen #(
	//DO NOT TOUCH ME!
	parameter int HORPIXEL = 640,
	parameter int VERPIXEL = 480
) (
	input var logic arstn,
	input var logic clk_pixel,	
	output var vga_pkg::vga_ctrl_t vga_ctrl,
	output var logic valid_x, valid_y
);



localparam int hor_sync_cycles =    800; //At 25MHz, it takes this many cycles for one row
localparam int ver_sync_cycles =    525; //At 25MHz, it takes this many cycles for an entire image

//In one cycle, we first have the front porch, then the pulse, then the back porch and then the display area
localparam int ver_fp_width =        10;
localparam int hor_fp_width =        16;
		
localparam int ver_pulse_width =      2; //At 25MHz, pulse width for the vertical sync
localparam int hor_pulse_width =     96; //At 25MHz, pulse width for the horizontal sync

localparam int ver_bp_width =        33;
localparam int hor_bp_width =        48;

localparam int ver_dis_width =      480;
localparam int hor_dis_width =      640;



localparam int beginHs   =      hor_dis_width+hor_fp_width;
localparam int endHs     =      hor_sync_cycles-hor_bp_width;
localparam int beginVs   =      ver_dis_width+ver_fp_width;
localparam int endVs    =       ver_sync_cycles-ver_bp_width;

//synthesis translate_off
initial begin
	assert(hor_sync_cycles == hor_fp_width+hor_pulse_width+hor_bp_width+hor_dis_width) else $error("Horizontal parameters are wrong");
	assert(ver_sync_cycles == ver_fp_width+ver_pulse_width+ver_bp_width+ver_dis_width) else $error("Vertical parameters are wrong");
end

//synthesis translate_on


/// Task 1:
// design two counters to track vertical and horizontal sync
logic [$clog2(ver_sync_cycles)-1:0] ver_cnt;
logic [$clog2(hor_sync_cycles)-1:0] hor_cnt;
always_ff @(posedge clk_pixel or negedge arstn) begin
    if (!arstn) begin
        hor_cnt <= 0;
        ver_cnt <= 0;
    end else begin
        // Horizontal counter wraps at the end of a line
        if (hor_cnt == hor_sync_cycles - 1) begin
            hor_cnt <= 0;

            // Vertical counter increments at end of line
            if (ver_cnt == ver_sync_cycles - 1)
                ver_cnt <= 0;
            else
                ver_cnt <= ver_cnt + 1;

        end else begin
            hor_cnt <= hor_cnt + 1;
        end
    end
end



// generate vertical and horizontal syncs accordingly (VS, HS) task 2
logic hor_sync;
logic ver_sync;
always_ff @(posedge clk_pixel  or negedge arstn) begin
    if (!arstn) begin
        ver_sync <=1;
        hor_sync <=1;
    end
    else begin
        if (hor_cnt< hor_fp_width+hor_pulse_width && hor_cnt>= hor_fp_width) begin
            hor_sync<=0;
        end
        else begin
            hor_sync<=1;
        end
        //vertical
        if (ver_cnt<ver_fp_width+ver_pulse_width-2 && ver_cnt>=ver_fp_width-2) begin
            ver_sync<=0;
        end
        else begin
            ver_sync<=1;
        end
    end

end

// generate valid signals for both x and y dimenssion
logic valid_x, valid_y;
always_ff @(posedge clk_pixel or negedge arstn) begin
    if (!arstn) begin
        valid_x <= 0;
        valid_y <= 0;
    end else begin
        if ( (hor_cnt < hor_dis_width-1+hor_bp_width+hor_fp_width+hor_pulse_width ) || hor_cnt >= hor_bp_width+hor_fp_width+hor_pulse_width-1 )
            valid_x <= 1;
        else
            valid_x <= 0;

        if ( (ver_cnt <  ver_dis_width-1+ver_bp_width+ver_fp_width+ver_pulse_width ) || ( ver_cnt >= ver_bp_width+ver_fp_width+ver_pulse_width-1 ) )
            valid_y <= 1;
        else
            valid_y <= 0;
    end
end


always_ff @(posedge clk_pixel or negedge arstn) begin
	if (!arstn) vga_ctrl <= vga_pkg::vga_ctrl_dv;
	else begin
		vga_ctrl.active <= valid_y && valid_x;
		vga_ctrl.pixel_y <= ver_cnt - (ver_fp_width+ver_pulse_width+ver_bp_width);
		vga_ctrl.pixel_x <= hor_cnt - (hor_fp_width+hor_pulse_width+hor_bp_width);
		vga_ctrl.hs <= hor_sync;
		vga_ctrl.vs <= ver_sync;
	end
end
endmodule

module image_buf #(
	//Pixel for the actual output
	parameter int HORPIXEL = 640,
	parameter int VERPIXEL = 480,
	//Pixel we store
	parameter int MEMHORPIXEL = 640,
	parameter int MEMVERPIXEL = 480,
	parameter int BITSPERPIXEL = 1
) (
	input var logic arstn,
	input var logic clk_pixel,
	
	input var vga_pkg::vga_ctrl_t vga_ctrl,
	
	output vga_pkg::mem_pixel_t pixel,
	
	input var logic clk,
	input var vga_pkg::render_pixel_t rend_pixel,
	input var logic rend_pixel_valid,
	output var logic rend_pixel_ready
);

localparam int AddrWidth = $clog2(MEMHORPIXEL*MEMVERPIXEL);
localparam int DataWidthAligned = BITSPERPIXEL;
localparam int Size = MEMHORPIXEL*MEMVERPIXEL*BITSPERPIXEL;
localparam int Latency = 3;

logic [$clog2(MEMVERPIXEL*MEMHORPIXEL)-1:0] raddr;
logic [$clog2(HORPIXEL)-1:0] addr_x;
logic [$clog2(VERPIXEL)-1:0] addr_y;
assign addr_x = vga_ctrl.pixel_x;
assign addr_y = vga_ctrl.pixel_y;
logic [$clog2(MEMVERPIXEL)-1:0] addr_y_scaled;
logic [$clog2(MEMHORPIXEL)-1:0] addr_x_scaled;
assign addr_y_scaled = (addr_y*MEMVERPIXEL)/VERPIXEL;
assign addr_x_scaled = (addr_x*MEMHORPIXEL)/HORPIXEL;
always_ff @(posedge clk_pixel) raddr <= addr_x_scaled + MEMHORPIXEL*addr_y_scaled;


logic [$clog2(vga_pkg::X_PIXEL_MEM*vga_pkg::Y_PIXEL_MEM)-1:0] waddr;
assign waddr = rend_pixel.pixel_x + rend_pixel.pixel_y*vga_pkg::X_PIXEL_MEM;
logic we;
assign we = rend_pixel_valid && rend_pixel_ready;
assign rend_pixel_ready = 1'd1;

// @SuppressProblem -type unresolved_hierarchy -count 1 -length 1
xpm_memory_tdpram#(
	.ADDR_WIDTH_A            ( AddrWidth        ), // DECIMAL
	.ADDR_WIDTH_B            ( AddrWidth        ), // DECIMAL
	.AUTO_SLEEP_TIME         ( 0                ), // DECIMAL
	.BYTE_WRITE_WIDTH_A      ( BITSPERPIXEL     ), // DECIMAL
	.BYTE_WRITE_WIDTH_B      ( BITSPERPIXEL     ), // DECIMAL
	.CLOCKING_MODE           ( "independent_clock"   ), // String
	.ECC_MODE                ( "no_ecc"         ), // String
	.MEMORY_INIT_FILE        ( "../../../fpga-lab-vga/data/default.mem" ), // String
	.MEMORY_INIT_PARAM       ( "0"              ), // String
	.MEMORY_OPTIMIZATION     ( "true"           ), // String
	.MEMORY_PRIMITIVE        ( "auto"           ), // String
	.MEMORY_SIZE             ( Size             ), // DECIMAL in bits!
	.MESSAGE_CONTROL         ( 0                ), // DECIMAL
	.READ_DATA_WIDTH_A       ( DataWidthAligned ), // DECIMAL
	.READ_DATA_WIDTH_B       ( DataWidthAligned ), // DECIMAL
	.READ_LATENCY_A          ( Latency-1          ), // DECIMAL
	.READ_LATENCY_B          ( Latency-1          ), // DECIMAL
	.READ_RESET_VALUE_A      ( "0"              ), // String
	.READ_RESET_VALUE_B      ( "0"              ), // String
	.USE_EMBEDDED_CONSTRAINT ( 0                ), // DECIMAL
	.USE_MEM_INIT            ( 1                ), // DECIMAL
	.WAKEUP_TIME             ( "disable_sleep"  ), // String
	.WRITE_DATA_WIDTH_A      ( DataWidthAligned ), // DECIMAL
	.WRITE_DATA_WIDTH_B      ( DataWidthAligned ), // DECIMAL
	.WRITE_MODE_A            ( "no_change"      ), // String
	.WRITE_MODE_B            ( "no_change"      )  // String
  ) i_xpm_memory_tdpram (
	.dbiterra ( /*not used*/ ), // 1-bit output: Doubble bit error A
	.dbiterrb ( /*not used*/ ), // 1-bit output: Doubble bit error B
	.sbiterra ( /*not used*/ ), // 1-bit output: Single bit error A
	.sbiterrb ( /*not used*/ ), // 1-bit output: Single bit error B
	.addra    ( raddr        ), // ADDR_WIDTH_A-bit input: Address for port A
	.addrb    ( waddr        ), // ADDR_WIDTH_B-bit input: Address for port B
	.clka     ( clk_pixel    ), // 1-bit input: Clock signal for port A
	.clkb     ( clk          ), // 1-bit input: Clock signal for port B
	.dina     ( '0           ), // WRITE_DATA_WIDTH_A-bit input: Data input for port A
	.dinb     ( rend_pixel.pixel        ), // WRITE_DATA_WIDTH_B-bit input: Data input for port B
	.douta    ( pixel.pixel  ), // READ_DATA_WIDTH_A-bit output: Data output for port A
	.doutb    ( /*not used*/ ), // READ_DATA_WIDTH_B-bit output: Data output for port B
	.ena      ( 1'd1         ), // 1-bit input: Memory enable signal for port A
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


vga_pkg::vga_ctrl_t [Latency-1:0] vga_ctrl_del;
always_ff @(posedge clk_pixel or negedge arstn) begin
	if (!arstn)	vga_ctrl_del <= '1;
	else vga_ctrl_del <= {vga_ctrl_del[Latency-2:0], vga_ctrl};
end
assign pixel.ctrl = vga_ctrl_del[Latency-1];


// Instantiate checkers for the axi stream
//synthesis translate_off
	stream_prop #(.dtype_t($typeof(rend_pixel))) rend_prop (
		.clk  (clk  ),
		.rstn (arstn ),
		.valid(rend_pixel_valid),
		.ready(rend_pixel_ready),
		.data (rend_pixel )
	);
//synthesis translate_on

endmodule


module render_fft #(
	parameter int TRANSFORMLENGTH=256,
	parameter type fft_t=logic
) (
	input var logic clk,
	input var logic arstn,
	
	input var fft_t fft_data,
	input var logic fft_valid,
	output var logic fft_ready,
	

	output var vga_pkg::render_pixel_t pixel,
	output var logic pixel_valid,
	input var logic pixel_ready
);

logic [$clog2(vga_pkg::X_PIXEL_MEM)-1:0] xidx;
logic [$clog2(vga_pkg::Y_PIXEL_MEM)-1:0] yidx;

vga_pkg::render_pixel_t pixel_ren;
logic pixel_ren_valid, pixel_ren_ready;

//This is not a BRAM
logic [$bits(fft_data.tdata)-1:0] fft_buffer [TRANSFORMLENGTH-1:0];
logic [$clog2(TRANSFORMLENGTH)-1:0] fft_widx;
enum {RENDER,NOTRENDER} state;
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) fft_widx <= '0;
	else if(state == RENDER) begin
		fft_widx <= '0;
	end else if (fft_valid && fft_ready) begin
		if (fft_data.tlast) fft_widx <= '0;
		else fft_widx <= fft_widx + 'd1;
	end
end

always_ff @(posedge clk) begin
	if (fft_valid && fft_ready) fft_buffer[fft_widx] <= fft_data.tdata;
end


assign fft_ready = state == NOTRENDER;

logic done_render;
assign done_render = (yidx == vga_pkg::Y_PIXEL_MEM-1);

always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) state <= NOTRENDER;
	else if (fft_valid && fft_ready && fft_data.tlast) state <= RENDER;
	else if (state == RENDER && pixel_ren_valid && pixel_ren_ready && done_render) state <= NOTRENDER;
end


always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) xidx <= '0;
	else if (pixel_ren_valid && pixel_ren_ready) begin
		if (yidx == vga_pkg::Y_PIXEL_MEM-1) begin
			if (xidx == vga_pkg::X_PIXEL_MEM-1) xidx <= '0;
			else xidx <= xidx + 'd1;
		end
	end
end
always_ff @(posedge clk or negedge arstn) begin
	if (!arstn) yidx <= '0;
	else if (pixel_ren_valid && pixel_ren_ready) begin
		if (yidx == vga_pkg::Y_PIXEL_MEM-1) yidx <= '0;
		else yidx <= yidx + 'd1;
	end
end

logic [$clog2(TRANSFORMLENGTH)-1:0] ridx;
if (TRANSFORMLENGTH == vga_pkg::Y_PIXEL_MEM) assign ridx = yidx;
else assign ridx = (yidx*TRANSFORMLENGTH)/vga_pkg::Y_PIXEL_MEM;

assign pixel_ren_valid = state == RENDER;
assign pixel_ren.pixel_x = xidx;
assign pixel_ren.pixel_y = yidx;
assign pixel_ren.pixel = fft_buffer[ridx][7:0]; //Manually changed to fit
stream_register #(
	.dtype_t(vga_pkg::render_pixel_t)	
) pixel_reg (
	.clk(clk),
	.arstn(arstn),
	.data_i(pixel_ren),
	.valid_i(pixel_ren_valid),
	.ready_o(pixel_ren_ready),
	.data_o(pixel),
	.valid_o(pixel_valid),
	.ready_i(pixel_ready)
);

//synthesis translate_off
stream_prop #(.dtype_t(fft_t)) prop_in (
	.clk  (clk  ),
	.rstn (arstn ),
	.valid(fft_valid),
	.ready(fft_ready),
	.data (fft_data )
);
//synthesis translate_on


endmodule




//A ROM with rendered text (white on black) with the words in it. Overlays the word on the video signal
module detection_overlay #(
	parameter int NWORDS = 10,
	parameter int OFFSET_X = 240,
	parameter int OFFSET_Y = 200
) (
	input var logic clk_pixel,
	input var logic arstn,
	
	input var vga_pkg::vga_pixel_t pixel_i,
	output var vga_pkg::vga_pixel_t pixel_o,
	input var logic [$clog2(NWORDS+1)-1:0] word //+1 because the last one we do not render
);

localparam vga_pkg::color_pixel_t rgb_0 = '0;
localparam vga_pkg::color_pixel_t rgb_1 = '1;
localparam int Latency = 2;

logic text_bin;
localparam int WORDWIDTHPIXEL = 90;
localparam int WORDHEIGHTPIXEL = 24;
localparam int BITSPERWORD = WORDWIDTHPIXEL*WORDHEIGHTPIXEL;


//Compute the addr
logic [$clog2(NWORDS*BITSPERWORD)-1:0] addr;
assign addr = word*BITSPERWORD+(pixel_i.ctrl.pixel_x-OFFSET_X) + (pixel_i.ctrl.pixel_y-OFFSET_Y)*WORDWIDTHPIXEL;
// @SuppressProblem -type unresolved_hierarchy -count 1 -length 1
xpm_memory_sprom #(
	.ADDR_WIDTH_A($clog2(NWORDS*BITSPERWORD)),              // DECIMAL
	.AUTO_SLEEP_TIME(0),           // DECIMAL
	.CASCADE_HEIGHT(0),            // DECIMAL
	.ECC_MODE("no_ecc"),           // String
	.MEMORY_INIT_FILE("C:/Users/moham/Desktop/Fpga/Mem/text.mem"),     // String
	.MEMORY_INIT_PARAM("0"),       // String
	.MEMORY_OPTIMIZATION("true"),  // String
	.MEMORY_PRIMITIVE("auto"),     // String
	.MEMORY_SIZE(BITSPERWORD*NWORDS),            // DECIMAL based on the text bounding box
	.MESSAGE_CONTROL(0),           // DECIMAL
	.READ_DATA_WIDTH_A(1),        // DECIMAL
	.READ_LATENCY_A(Latency),            // DECIMAL
	.READ_RESET_VALUE_A("0"),      // String
	.RST_MODE_A("SYNC"),           // String
	.SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
	.USE_MEM_INIT(1),              // DECIMAL
	.WAKEUP_TIME("disable_sleep")  // String
 )	 lut_words (
	.douta(text_bin),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
	.addra(addr),                   // ADDR_WIDTH_A-bit input: Address for port A read operations.
	.clka(clk_pixel),                     // 1-bit input: Clock signal for port A.
	.ena(1'd1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
	.injectdbiterra(1'b0), // 1-bit input: Do not change from the provided value.
	.injectsbiterra(1'b0), // 1-bit input: Do not change from the provided value.
	.regcea(1'd1),                 // 1-bit input: Do not change from the provided value.
	.rsta(!arstn),                     // 1-bit input: Reset signal for the final port A output register stage.
	.sleep(1'b0)                    // 1-bit input: sleep signal to enable the dynamic power saving feature.
 );

vga_pkg::vga_pixel_t [Latency-1:0] vga_pixel_del;
always_ff @(posedge clk_pixel or negedge arstn) begin
	if (!arstn)	vga_pixel_del <= {Latency{vga_pkg::vga_pixel_dv}};
	else vga_pixel_del <= {vga_pixel_del[Latency-2:0], pixel_i};
end

logic overwrite;
always_comb begin
	overwrite = 1'd0; //By default do not overwrite
	if (word < NWORDS) begin //We have detected a word
		if (vga_pixel_del[Latency-1].ctrl.pixel_x-OFFSET_X < WORDWIDTHPIXEL && vga_pixel_del[Latency-1].ctrl.pixel_y-OFFSET_Y < WORDHEIGHTPIXEL) begin
			overwrite = 1'd1;
		end
	end
end
vga_pkg::color_pixel_t mapped_w;
assign mapped_w = text_bin ? rgb_1 : rgb_0;
always_ff @(posedge clk_pixel or negedge arstn) begin
	if (!arstn) pixel_o <= vga_pkg::vga_pixel_dv;
	else begin
		pixel_o <= vga_pixel_del[Latency-1];
		if (overwrite) pixel_o.pixel <= mapped_w;
	end
end

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


// Instantiate checkers for the axi stream
//synthesis translate_off
	stream_prop #(.dtype_t(dtype_t)) prop_in (
		.clk  (clk  ),
		.rstn (arstn ),
		.valid(valid_i),
		.ready(ready_o),
		.data (data_i )
	);
	stream_prop #(.dtype_t(dtype_t)) prop_out (
		.clk  (clk  ),
		.rstn (arstn ),
		.valid(valid_o),
		.ready(ready_i),
		.data (data_o )
	);
//synthesis translate_on
endmodule


//A wrapper for debugging that instantiates the vga top and a debug core to drive the input signal
module vga_top_wrapper (
	input var logic arstn,
	input var logic clk,
	input var logic [3:0] word,
	
	output var logic vga_hor_sync,
	output var logic vga_ver_sync,
	
	output var logic [3:0] vga_green,
	output var logic [3:0] vga_red,
	output var logic [3:0] vga_blue
);

typedef struct {
	logic [8:0] tdata;
	logic tlast;
} fft_t;

fft_t fft;
logic fft_valid, fft_ready;
jtag_axi jtag_axi_i(
	.aclk(clk),
	.aresetn(arstn),
	.m_axi_awready(1'd1),
	.m_axi_wdata(fft.tdata),
	.m_axi_wlast(fft.tlast),
	.m_axi_wvalid(fft_valid),
	.m_axi_wready(fft_ready),
	.m_axi_bid('d0),
	.m_axi_bresp('d0),
	.m_axi_bvalid(1'd1),
	.m_axi_arready(1'd0),
	.m_axi_rvalid(1'd0)
);

vga_top #(
	.fft_t(fft_t)
) DUT (
	.clk(clk),
	.arstn(arstn),
	.vga_hor_sync(vga_hor_sync),
	.vga_ver_sync(vga_ver_sync),
	.vga_green(vga_green),
	.vga_red(vga_red),
	.vga_blue(vga_blue),
	.fft_data(fft),
	.fft_valid(fft_valid),
	.fft_ready(fft_ready),
	.word(word)
);
endmodule
`default_nettype none

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
`ifdef SYNTHESIS
    // Use actual clock wizard in synthesis
    clk_wiz_1 u_clk_wiz_0 (
        .clk_in1 (clk),
        .clk_out1(clk_gen_fast),
        .resetn(arstn)
     
    );
`else
    // Simulation clock: ~16.384 MHz => 61.04 ns period
    logic clk_gen_fast_sim = 0;
    always #30.52 clk_gen_fast_sim = ~clk_gen_fast_sim;
    assign clk_gen_fast = clk_gen_fast_sim;
`endif


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