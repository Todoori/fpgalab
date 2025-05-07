`default_nettype none

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
