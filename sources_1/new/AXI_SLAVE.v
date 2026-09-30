`timescale 1ns / 1ps

module AXI_SLAVE #(parameter ADDRESS_WIDTH = 8, parameter DATA_WIDTH = 8,
parameter BURST_LENGTH = 4)(
    input ACLK,
    input ARST,
    //system config
    input wire [ADDRESS_WIDTH-1:0]AWADDR,//write address
    input wire [BURST_LENGTH -1:0]AWLEN,//burst length
    input wire [1:0]AWBURST,//burst type only FIXED and INCR
    input wire AWVALID,//from master
    input wire [1:0]AWID,//transaction ID
    output reg AWREADY,//output of slave
        //AW-Write address channel
    input wire [DATA_WIDTH-1:0]WDATA,//actual payload
    input wire WLAST,//last burst transaction
    input wire WVALID,//from master
    output reg WREADY,// output of slave
    output wr_en,
        //W- Write data channel
    output reg [1:0]BID,//transaction ID
    output reg BRESP,//status of write
    output reg BVALID,//from slave
    input wire BREADY,//from master
        //B- Write response channel
    input wire [ADDRESS_WIDTH-1:0] ARADDR,//address bus
    input wire [1:0] ARID,//transaction ID
    input wire [1:0]ARBURST,//burst type
    input wire [BURST_LENGTH-1:0] ARLEN, //read burst length
    input wire ARVALID,//from master
    output reg ARREADY,//from slave
        //AR- Read address Channel
    output reg [DATA_WIDTH -1:0]RDATA,//actual payload
    output reg RRESP,//read response
    output reg RLAST,//last transaction
    output reg RVALID,//from slave
    input wire RREADY,//from master
        //R- read data channel
    //adapter
    output reg [ADDRESS_WIDTH-1:0] addr,
    inout wire [DATA_WIDTH-1:0]data,
    output reg req,bmode,abort,rw,
    output reg [BURST_LENGTH-1:0] burst_len,
    input done,busy
        //adapter
    );

        //internal registers
            
            reg [BURST_LENGTH -1:0]  burst_len_reg;
            reg [1:0] burst_mode_reg;
            reg [2:0]state, next_state;  
            reg [1:0] id_reg;
            reg priority_rr;  
        //internal registers

        //burst modes
            localparam FIXED = 2'b00;
            localparam INCR = 2'b01;
        //burst modes
        
        //states  
           localparam IDLE = 3'b000;
           localparam WRITE_CAPTURE = 3'b001;
           localparam WRITE_EXECUTE = 3'b010;
           localparam WRITE_RESPONSE = 3'b011;
           localparam READ_CAPTURE = 3'b100;
           localparam READ_EXECUTE = 3'b101;
           localparam READ_DATA = 3'b110;
        //states

            assign data = (state == WRITE_EXECUTE)? WDATA: 'hz;
            
            //state register
                always @(posedge ACLK or negedge ARST)
                begin
                   
                
                    // SRAM controller interface
                   
                    
                    if(!ARST)
                    begin
                         // AXI outputs
                        WREADY = 1'b0;
                        BVALID = 1'b0;
                        RVALID = 1'b0;
                        RRESP  = 1'b0;
                        RLAST  = 1'b0;
                        RDATA  = 1'b0;
                        BID    = 1'b0;
                        BRESP  = 1'b0;
                    
                        // SRAM controller interface
                        req    = 1'b0;
                        rw     = 1'b0;
                        bmode  = 1'b0;
                        abort  = 1'b0;
                        
                        
                        burst_len_reg <= 1'b0;
                        priority_rr <= 1'b1;//initial priority set to WRITE;
                        state <= IDLE;
                    end
  
                    else
                    
                        begin 
                         state <= next_state; 
                             if(AWREADY && AWVALID) //round robin arbiter
                                priority_rr <= 1'b0; //round robin arbiter
                             else if(ARVALID && ARREADY) //round robin arbiter
                                priority_rr <= 1'b1; //round robin arbiter
                             
                             if(AWREADY && AWVALID)//initial handshake
                                begin
                                     addr <= AWADDR;
                                     burst_len <= AWLEN;
                                     burst_len_reg <= AWLEN;
                                     if(AWLEN != 0)
                                         bmode <= 1'b1;
                                    else
                                    begin
                                         bmode <= 1'b0;
                                        
                                        end
                                end

                             if(ARREADY && ARVALID)//initial handshake
                                begin
                                     addr <= ARADDR;
                                     burst_len <= ARLEN;
                                     burst_len_reg <= ARLEN;
                                     if(ARLEN != 0)
                                         bmode <= 1'b1;
                                    else
                                    begin
                                         bmode <= 1'b0;
                                    
                                        end
                                end

                             if(state == WRITE_CAPTURE)
                             begin
                                 AWREADY <= 1'b0;
                               
                                end

                             if(state == READ_CAPTURE)
                                 ARREADY <= 1'b0;
                            
                        end
                        
                end
            //state register

            //round robin arbiter
            
             always @(*)
            begin
                 AWREADY = 1'b0;
                 ARREADY = 1'b0;
                  if (AWVALID && ARVALID) begin
                         if (priority_rr)
                        begin
                             AWREADY = 1'b1;   // WRITE wins
                        end
                        else
                        begin
                             ARREADY = 1'b1;   // READ wins
                            end
                    end
                 else if (AWVALID) begin//only write
                             AWREADY = 1'b1;
                                end
                     // Only READ
                 else if (ARVALID) begin
                             ARREADY = 1'b1;
                                end
            end
            //round robin arbiter
               
            //next_state_logic
             always @(*)
                begin
               
                     case(state)
                    
                         IDLE : begin    //0
                                 if(AWVALID && AWREADY)
                                 next_state = WRITE_CAPTURE;
                                 else if(ARVALID && ARREADY)
                                 next_state = READ_CAPTURE;
                                 else
                                     next_state = IDLE;
                                end
                               
                         WRITE_CAPTURE: begin //1
                                            if(WVALID && WREADY)
                                            next_state = WRITE_EXECUTE;
                                        end

                         WRITE_EXECUTE : begin //2
                                             
                                             next_state = WRITE_RESPONSE;
                                            end
                        
                         WRITE_RESPONSE: begin //3
                                             if (BVALID && BREADY)
                                             next_state = IDLE;
                                        end

                          READ_CAPTURE: begin //4
                                       
                                             next_state = READ_EXECUTE;
                                        end

                          READ_EXECUTE : begin //5
                                           
                                             next_state = READ_DATA;
                                        end

                          READ_DATA : begin //6
                                             if(RVALID && RREADY)
                                                 next_state = IDLE;
                                        end

                         default : next_state = IDLE;
                     endcase
                end
            //next_state_logic
            
            //output
             always @(*)
                begin
                      WREADY = 1'b0;
                      BVALID = 1'b0;
                      RVALID = 1'b0;
                     case(state)
                         IDLE : begin
                             rw = 1'b0;
                             req = 1'b0;
                           
                        end

                         WRITE_CAPTURE: begin
                             WREADY = 1'b1;
                             rw = 1'b1;
                             req = 1'b1;
                             
                            
                        end

                         WRITE_EXECUTE: begin
                             
                        end

                         WRITE_RESPONSE: begin
                             
                             BVALID = 1'b1;
                            
                           
                        end

                         READ_CAPTURE: begin
                              req = 1'b1;                  
                              rw = 1'b0;
                        end

                         READ_EXECUTE: begin
                            
                        end

                         READ_DATA: begin
                             RVALID = 1'b1;
                        end
                     endcase
                end
            //output
            
    
endmodule