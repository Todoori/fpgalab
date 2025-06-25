`default_nettype none


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
		.MEMORY_INIT_FILE("../../../fpga-lab-vga/data/lut.mem"),     // String
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
	output var vga_pkg::vga_ctrl_t vga_ctrl
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
        if (hor_cnt == hor_sync_cycles - 1) begin
            hor_cnt <= 0;
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
        if (hor_cnt< endHs-2 && hor_cnt>=beginHs-2) begin
            hor_sync<=0;
        end
        else begin
            hor_sync<=1;
        end
        //vertical
        if (ver_cnt<endVs-2 && ver_cnt>=beginVs-2 ) begin
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
        if (hor_cnt < hor_dis_width-1 || hor_cnt == hor_sync_cycles-1)
            valid_x <= 1;
        else
            valid_x <= 0;

        if (ver_cnt < ver_dis_width-1 || ver_cnt == ver_sync_cycles-1)
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
localparam int WORDWIDTHPIXEL = 82;
localparam int WORDHEIGHTPIXEL = 22;
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
	.MEMORY_INIT_FILE("../../../fpga-lab-vga/data/text.mem"),     // String
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