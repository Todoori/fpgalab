`timescale 1ns / 1ps
`default_nettype none 

module uart_axi_top #(
    parameter int BAUD_RATE   = 9600,
    parameter int CLK_RATE    = 100_000_000,
    parameter int TDATA_WIDTH = 32,
    parameter int ADDR_WIDTH  = 4,
    parameter int ID_WIDTH    = 4  // Add ID_WIDTH parameter
)(
    input var  logic                     aclk,
    input var  logic                     aresetn,

    // AXI4 Full Write Address Channel
    input var  logic [ID_WIDTH-1:0]      s_axi_awid,         // AXI Write Address ID
    input var  logic [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input var  logic [7:0]               s_axi_awlen,
    input var  logic [2:0]               s_axi_awsize,
    input var  logic [1:0]               s_axi_awburst,
    input var  logic                     s_axi_awvalid,
    output logic                     s_axi_awready,

    // AXI4 Full Write Data Channel
    input var  logic [ID_WIDTH-1:0]      s_axi_wid,          // AXI Write Data ID
    input var  logic [TDATA_WIDTH-1:0]   s_axi_wdata,
    input var  logic [(TDATA_WIDTH/8)-1:0] s_axi_wstrb,
    input var  logic                     s_axi_wlast,
    input var  logic                     s_axi_wvalid,
    output logic                     s_axi_wready,

    // AXI4 Full Write Response Channel
    output logic [1:0]               s_axi_bresp,
    output logic                     s_axi_bvalid,
    input var  logic                     s_axi_bready,

    // UART Output
    output logic                     tx_o
);

    // Internal connection between AXI and UART
    logic [TDATA_WIDTH-1:0] data_i;
    logic                   valid_i;
    logic                   ready_o;

    // AXI to UART interface
    axi4_to_uart #(
        .TDATA_WIDTH(TDATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .ID_WIDTH   (ID_WIDTH)    // Pass ID_WIDTH parameter
    ) axi_uart_inst (
        .aclk           (aclk),
        .aresetn        (aresetn),
        .s_axi_awid     (s_axi_awid),         // Pass AWID
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awlen    (s_axi_awlen),
        .s_axi_awsize   (s_axi_awsize),
        .s_axi_awburst  (s_axi_awburst),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wid      (s_axi_wid),          // Pass WID
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wlast    (s_axi_wlast),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .data_i         (data_i),
        .valid_i        (valid_i),
        .ready_o        (ready_o)
    );

    // UART transmitter
    uart_tx_top #(
        .BAUD_RATE   (BAUD_RATE),
        .CLK_RATE    (CLK_RATE),
        .TDATA_WIDTH (TDATA_WIDTH)
    ) uart_top_inst (
        .clk     (aclk),
        .arstn   (aresetn),
        .data_i  (data_i),
        .valid_i (valid_i),
        .ready_o (ready_o),
        .tx_o    (tx_o)
    );

endmodule







module axi4_to_uart #(
    parameter int TDATA_WIDTH = 32,
    parameter int ADDR_WIDTH  = 4,
    parameter int ID_WIDTH    = 4 // Add ID_WIDTH parameter
)(
    input var  logic                     aclk,
    input var  logic                     aresetn,

    // AXI4 Full Write Address Channel
    input var  logic [ID_WIDTH-1:0]      s_axi_awid,         // AXI Write Address ID
    input var  logic [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input var  logic [7:0]               s_axi_awlen,
    input var  logic [2:0]               s_axi_awsize,
    input var  logic [1:0]               s_axi_awburst,
    input var  logic                     s_axi_awvalid,
    output logic                     s_axi_awready,

    // AXI4 Full Write Data Channel
    input var  logic [ID_WIDTH-1:0]      s_axi_wid,          // AXI Write Data ID
    input var  logic [TDATA_WIDTH-1:0]   s_axi_wdata,
    input var  logic [(TDATA_WIDTH/8)-1:0] s_axi_wstrb,
    input var  logic                     s_axi_wlast,
    input var  logic                     s_axi_wvalid,
    output logic                     s_axi_wready,

    // AXI4 Full Write Response Channel
    output logic [1:0]               s_axi_bresp,
    output logic                     s_axi_bvalid,
    input var  logic                     s_axi_bready,

    // UART TX Interface
    output logic [TDATA_WIDTH-1:0]   data_i,
    output logic                     valid_i,
    input var  logic                     ready_o
);

    // Internal state
    typedef enum logic [1:0] {IDLE, WRITE, RESP} state_t;
    state_t state;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state         <= IDLE;
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_bvalid  <= 0;
            s_axi_bresp   <= 2'b00;
            data_i        <= 0;
            valid_i       <= 0;
        end else begin
            case (state)
                IDLE: begin
                    s_axi_awready <= 1;
                    s_axi_wready  <= 1;
                    valid_i       <= 0;
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 0;
                        s_axi_wready  <= 0;
                        data_i        <= s_axi_wdata;
                        valid_i       <= 1;
                        state         <= WRITE;
                    end
                end
                WRITE: begin
                    valid_i <= 0;
                    if (ready_o) begin
                        s_axi_bvalid <= 1;
                        s_axi_bresp  <= 2'b00; // OKAY
                        state        <= RESP;
                    end
                end
                RESP: begin
                    if (s_axi_bready) begin
                        s_axi_bvalid <= 0;
                        state        <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule



module uart_tx_top #(
    parameter int BAUD_RATE   = 9600,
    parameter int CLK_RATE    = 100_000_000,
    parameter int TDATA_WIDTH = 32
)(
    input  var logic                  clk,
    input  var logic                  arstn,

    input  var logic [TDATA_WIDTH-1:0] data_i,
    input  var logic                  valid_i,
    output var logic                  ready_o,

    output var logic                  tx_o
);

    // Internal signals connecting packetizer to uart_tx
    logic [7:0] tx_byte;
    logic       tx_valid;
    logic       tx_ready;

    // Packetizer: Breaks data_i into 8-bit bytes
    uart_tx_packetizer_3 #(
        .tdata_width(TDATA_WIDTH)
    ) packetizer_inst (
        .clk      (clk),
        .arstn    (arstn),
        .data_i   (data_i),
        .valid_i  (valid_i),
        .ready_o  (ready_o),

        .byte_o   (tx_byte),
        .valid_o  (tx_valid),
        .ready_i  (tx_ready)
    );

    // UART Transmitter: Sends 8-bit bytes over tx_o
    uart_tx #(
        .baud_rate (BAUD_RATE),
        .tdata_width(8),  // Always 8-bit for UART
        .clk_rate  (CLK_RATE)
    ) uart_tx_inst (
        .clk      (clk),
        .arstn    (arstn),
        .data_i   (tx_byte),
        .valid_i  (tx_valid),
        .ready_o  (tx_ready),
        .tx_o     (tx_o)
    );

endmodule





module uart_tx 
#(parameter int baud_rate=9600,tdata_width=8,clk_rate=100_000_000)
(
    
    input var logic clk,
    input var logic arstn,
    
    input var logic [tdata_width-1:0] data_i,
    input var logic valid_i,            //AXI interface of UART MASTER
    output var logic ready_o,       
    
    output logic tx_o                   //output to receiver

);
    logic  [tdata_width-1:0] data_intermediate; //buffer for when handschake is fulfilled at the input


     always_ff @(posedge clk or negedge arstn )
     begin
        
         if(!arstn)
         begin
            data_intermediate<=0;
         end 
         else if (valid_i & ready_o) 
         begin
            data_intermediate<= data_i;
         end
     
     end
     
    typedef enum logic [3:0] {
    IDLE   = 3'b000,
    START = 3'b001,
    DATA  = 3'b010,
    PARITY = 3'b011,
    STOP   = 3'b100 
    } uart_state;
    //define States
    uart_state current_state,next_state;
    //define tx_line_constant
    localparam TX_IDLE=1'b1;
    localparam TX_START=1'b0;
    localparam TX_STOP=1'b1;
    
    //count the BAUD
    localparam BAUD_COUNTER_MAX=clk_rate/baud_rate;
    localparam BAUD_COUNTER_SIZE=$clog2(BAUD_COUNTER_MAX);
    //count the Data
    localparam DATA_COUNTER_MAX=tdata_width;
    localparam DATA_COUNTER_SIZE=$clog2(tdata_width);
    //counter variables
    var logic [BAUD_COUNTER_SIZE-1:0] baud_counter;
    var logic [DATA_COUNTER_SIZE-1:0] data_counter;
    //BAUD done and data_done
    var logic baud_done;
    var logic data_done;
    // buffer to store data while shifting
    var logic [tdata_width-1:0] data_shift_buffer;
    
    always_ff @(posedge clk or negedge arstn) 
    begin
        if(!arstn) 
            baud_counter<=0;
        else if (current_state !=next_state)
            baud_counter<=0;
        else
            baud_counter<=baud_counter+1'd1;
     end
     //BAUD CLOCK IS DONE I DONT WANT 100MHZ 
     assign baud_done=(baud_counter== BAUD_COUNTER_MAX -1)? 1'b1 :1'b0;
     
     
   always_ff @(posedge clk or negedge arstn)
   begin

        if(!arstn)
        begin
            data_counter<='0;
            data_shift_buffer<='0;
        end    
    
        else if (baud_done) 
        begin
        //reset at state transition
            if(current_state!=next_state)
            begin
                data_counter<=0;
                data_shift_buffer<=data_intermediate;
            end
            else begin
                data_counter<=data_counter+1'd1;
                data_shift_buffer<=data_shift_buffer>>1;
            end    
            
         end
   end    
   assign data_done= (data_counter==DATA_COUNTER_MAX-1)? 1'b1:0;
     
   //FSM 
   always_comb
   begin
      
       case(current_state)
       
            IDLE : next_state= (valid_i) ? START:current_state;   
            START : next_state = (baud_done) ? DATA:current_state;
            DATA  : next_state = (baud_done &data_done) ? PARITY:current_state;
            PARITY : next_state= (baud_done)? STOP: current_state;
            STOP   : next_state = (baud_done) ? IDLE: current_state;
            default:
            next_state=current_state;
       
       
       endcase
   end
    always @(posedge clk or negedge arstn)
    begin   
        if(!arstn)
        begin    
            current_state<=IDLE;
        end 
        else
            current_state=next_state;   
    end
    
    always @(posedge clk or negedge arstn) //now drive_tx_o depending on state
    begin
        if(!arstn)
            tx_o<=TX_IDLE;
        else 
        begin 
            case(next_state) // non blocking assignment to next state would case delay
                IDLE : tx_o<=TX_IDLE;
                START: tx_o<=TX_START;
                DATA:  tx_o<=data_shift_buffer[0];
                PARITY: tx_o<=^data_intermediate;
                STOP: tx_o<=TX_STOP;
            endcase
        end
    end
    
   assign ready_o= (current_state==IDLE)? 1'b1 : 1'b0;
    
endmodule  



`timescale 1ns / 1ps
`default_nettype none

module uart_tx_packetizer #(
    parameter int tdata_width = 32
)(
    input  var logic         clk,
    input  var logic         arstn,
    input  var logic [tdata_width-1:0] data_i,
    input  var logic         valid_i,
    output var logic         ready_o,

    // To internal UART TX
    output logic [7:0]       byte_o,
    output logic             valid_o,
    input var  logic         ready_i  // from uart_tx
);

    localparam int NUM_BYTES = tdata_width / 8;
    localparam int BYTE_COUNTER_WIDTH = (NUM_BYTES > 1) ? $clog2(NUM_BYTES) : 1;

    logic [tdata_width-1:0] buffer;
    logic [BYTE_COUNTER_WIDTH-1:0] byte_index;
    logic active;

    always_ff @(posedge clk or negedge arstn) begin
        if (!arstn) begin
            buffer      <= 0;
            byte_index  <= 0;
            active      <= 0;
        end else begin
            if (valid_i && ready_o) begin
                buffer      <= data_i;
                byte_index  <= 0;
                active      <= 1;
            end else if (active && valid_o && ready_i) begin
                byte_index <= byte_index + 1;
                if (byte_index == NUM_BYTES - 1)
                    active <= 0;
            end
        end
    end

    assign byte_o   = buffer[8*byte_index +: 8];
    assign valid_o  = active;
    assign ready_o  = ~active;

endmodule

module uart_tx_packetizer_3 #(
    parameter int tdata_width = 32
)(
    input  var logic         clk,
    input  var logic         arstn,
    input  var logic [tdata_width-1:0] data_i,
    input  var logic         valid_i,
    output var logic         ready_o,

    // To internal UART TX
    output logic [7:0]       byte_o,
    output logic             valid_o,
    input var  logic         ready_i  // from uart_tx
);

    localparam int NUM_BYTES = tdata_width / 8;
    localparam int BYTE_COUNTER_WIDTH = (NUM_BYTES > 1) ? $clog2(NUM_BYTES) : 1;

    logic [tdata_width-1:0] buffer;
    logic [BYTE_COUNTER_WIDTH:0] byte_index;
    logic bytes_done;
    typedef enum logic[1:0] {
    PKT_IDLE = 2'b00,
    PKT_SEND_BYTE=2'b01,
    PKT_NEXT_BYTE=2'b10,
    PKT_DONE=2'b11
    } packetizer_t;
    packetizer_t current_state,next_state;

    
    always_ff @(posedge clk  or negedge arstn) begin
        if(!arstn) begin
           buffer<=0; 
           byte_index<=0;
        end
        else if( ready_o & valid_i)     //AXI HANDSHAKE
            buffer<=data_i;
    
    end
    
        
    always_ff @(posedge clk or negedge arstn) begin
        if(!arstn) begin
           byte_index<=0; 
        end
        else if (next_state==PKT_DONE)  begin
            byte_index<=0;
        end
        
        else if (next_state==PKT_NEXT_BYTE)
            byte_index<= byte_index +1'd1;
    
    end
    
    assign bytes_done= (byte_index==NUM_BYTES) ? 1'b1:1'b0;

    always_ff @(posedge clk or negedge arstn) begin
        if(!arstn) begin
           current_state<=PKT_IDLE; 
        end
        else  begin
            current_state<=next_state;
        end
    end
    
    always_comb  begin
        case(current_state)
        PKT_IDLE: next_state= (valid_i)? PKT_SEND_BYTE:current_state;
        PKT_SEND_BYTE : next_state= (ready_i & !bytes_done)? PKT_NEXT_BYTE  :current_state;
        PKT_NEXT_BYTE :  next_state= (bytes_done)? PKT_DONE  :PKT_SEND_BYTE;
        PKT_DONE : next_state = PKT_IDLE;
        default: next_state =PKT_IDLE;   
        endcase    
    end
always_ff @(posedge clk or negedge arstn) begin
    if (!arstn) begin
        byte_o <= 8'hFF;  // or 8'h00 for reset
     end
    else begin
        case(current_state)
        PKT_IDLE: byte_o <= 8'hFF;
        PKT_SEND_BYTE : byte_o= buffer[8*byte_index +: 8];
        PKT_NEXT_BYTE: byte_o<=8'hFF;
        PKT_DONE :  byte_o<=8'hFF;
        
        endcase
    end
end

 
assign ready_o= current_state==PKT_IDLE;
assign valid_o= current_state==PKT_SEND_BYTE;    



endmodule