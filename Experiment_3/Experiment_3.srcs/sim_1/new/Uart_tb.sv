

`timescale 1ns / 1ps

module uart_tx_tb;

    // Parameters
    parameter int baud_rate = 10_000_000;
    parameter int tdata_width = 16;
    parameter int clk_rate = 100_000_000;
    parameter int clk_period = 10; // 100 MHz => 10ns
 


    // DUT signals
    logic clk;
    logic arstn;
    logic [tdata_width-1:0] data_i;
    logic valid_i;
    logic ready_o;
    logic tx_o;

    // Instantiate DUT
    uart_tx_top #( .baud_rate(baud_rate),
               .TDATA_WIDTH(tdata_width),
               .clk_rate(clk_rate)
  
               ) dut (
        .clk(clk),
        .arstn(arstn),
        .data_i(data_i),
        .valid_i(valid_i),
        .ready_o(ready_o),
        .tx_o(tx_o)
    );

    // Clock generation
    initial clk = 0;
    always #(clk_period / 2) clk = ~clk;

    // Stimulus
    initial begin
        valid_i=0;
        arstn = 1;

        // Reset
        #(10*clk_period);
        arstn = 0;
        #(10*clk_period);
        arstn = 1;
        wait (ready_o);

        // Send first byte
       data_i = 16'hC3F8;  // Example random 16-bit hex value
        valid_i = 1;
        #(10 *clk_period);
        valid_i = 0;

        // Wait for transmission to finish
        wait (ready_o);

        // Send another byte
        #(20*clk_period);
        data_i = 16'h3CB9;
        valid_i = 1;
        #(clk_period);
        valid_i=0;

        // Wait again for transmission
        wait (ready_o);
        

        #(100*clk_period);
        $display("Test completed");
        $finish;
    end
endmodule


/*module uart_tx_test 
#(parameter int baud_rate=9600,tdata_width=8,clk_rate=100_000_000)
(
    
    input var logic clk,
    input var logic arstn,
    
    input var logic [tdata_width-1:0] data_i,
    
    input var logic valid_i,            //AXI interface of UART MASTER
    output var logic ready_o,       
    
    output logic tx_o

    
  
    


);
    logic data_intermediate; //buffer for when handschake is fulfilled at the input
    

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
     
    typedef enum logic [2:0] {
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
            baud_counter<=1;
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
    
endmodule  */


