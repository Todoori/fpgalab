`default_nettype none

package vga_pkg;
	//Raw parameters
	localparam int X_PIXEL_SCREEN=480;
	localparam int Y_PIXEL_SCREEN=640;
	
	localparam int X_PIXEL_MEM   =97;
	localparam int Y_PIXEL_MEM   =257;
	
	localparam int CDEPTH = 4; //Bits per color
	localparam int BITSPERPIXEL = 8;
	
	//Derived structs
	typedef struct packed {
		logic [$clog2(Y_PIXEL_SCREEN)-1:0] pixel_x;
		logic [$clog2(X_PIXEL_SCREEN)-1:0] pixel_y;
		logic hs;
		logic vs;
		logic active;
	} vga_ctrl_t;
	localparam vga_ctrl_t vga_ctrl_dv = '{active:1'b0, hs:1'd1, vs:1'd1, pixel_x:'0,pixel_y:'0};
	
	
	typedef struct packed {
		logic [CDEPTH-1:0] blue;
		logic [CDEPTH-1:0] green;
		logic [CDEPTH-1:0] red;
		
	} color_pixel_t;
	localparam color_pixel_t color_pixel_dv = '{'0, '0, '0};
	
	typedef struct packed {
		vga_ctrl_t ctrl;
		color_pixel_t pixel;
	} vga_pixel_t;
	localparam vga_pixel_t vga_pixel_dv = '{pixel:color_pixel_dv, ctrl:vga_ctrl_dv};
	
	typedef logic [BITSPERPIXEL-1:0] raw_pixel_t;
	localparam raw_pixel_t raw_pixel_dv = '0;
	
	typedef struct packed {
		vga_ctrl_t ctrl;
		raw_pixel_t pixel; //The value actually loaded from the frame buffer
	} mem_pixel_t;
	localparam mem_pixel_t mem_pixel_dv = '{ctrl:vga_ctrl_dv, pixel:raw_pixel_dv};
	
	typedef struct packed {
		logic [$clog2(X_PIXEL_MEM)-1:0] pixel_x;
		logic [$clog2(Y_PIXEL_MEM)-1:0] pixel_y;
		raw_pixel_t pixel; //The value actually loaded from the frame buffer
	} render_pixel_t;
	localparam render_pixel_t render_pixel_dv = '{pixel_x:'0, pixel_y:'0, pixel:raw_pixel_dv};

    
endpackage : vga_pkg
package fft_pkg;
	//Raw parameters
	parameter int BITSIMAG = 16;
	parameter int BITSREAL = 16;
	
	
	
	
	typedef logic signed [31:0] data_t;
	
	typedef logic [127:0] fftout_t;
	
	
	
	parameter int WINDOWSTEP_MS = 10;
	parameter int WINDOWSIZE_MS = 32;
	parameter int SAMPLE_PER_MS = 16;
	parameter int FRAME_WIDTH_MS = 1000;
	
	parameter int REQUIRED_FRAMES = 97; //Is 97, but we use less to test
	
	
	/* DEPENDENT PARAMETERS; DO NOT CHANGE*/
	parameter int PARALLELISM = (WINDOWSIZE_MS + (WINDOWSTEP_MS-1))/WINDOWSTEP_MS; //Has to fit to FFT instance
	parameter int FIFO_DEPTH_MS = PARALLELISM*WINDOWSTEP_MS + WINDOWSIZE_MS; //Technically PARALLELISM-1, but we keep some margin
	parameter int FIFO_DEPTH = SAMPLE_PER_MS*FIFO_DEPTH_MS;
	parameter int WINDOWSTEP = SAMPLE_PER_MS*WINDOWSTEP_MS;
	
	
	parameter int ENOUGH_DATA = (PARALLELISM-1)*WINDOWSTEP_MS*SAMPLE_PER_MS;
	parameter int FRAME_SIZE = WINDOWSIZE_MS*SAMPLE_PER_MS;
	parameter int WAIT_SIZE = (PARALLELISM*WINDOWSTEP_MS-WINDOWSIZE_MS)*SAMPLE_PER_MS;
	
	parameter int FRAME_COUNT = FRAME_WIDTH_MS/WINDOWSTEP_MS/PARALLELISM;
	
	
	typedef logic signed [BITSIMAG-1:0] imag_t;
	typedef logic signed [BITSREAL-1:0] real_t;
	
	typedef struct packed {
		imag_t i_value;
		real_t r_value;
	} complex_t;
	

	typedef complex_t [PARALLELISM-1:0] parallel_t;
	
	typedef struct packed {
		complex_t [PARALLELISM-1:0] tdata;
		logic tlast;
	} parallel_str_t;
	
	typedef struct packed {
		complex_t  tdata;
		logic tlast;
	} complex_str_t;
    
	typedef struct packed {
		real_t tdata;
		logic tlast;
	} real_str_t;
	
endpackage : fft_pkg

package loudness_meter_pkg;
	//Raw parameters
	localparam int NLEDS=16;
	
	typedef logic signed [15:0] data_t;
	
endpackage : loudness_meter_pkg

