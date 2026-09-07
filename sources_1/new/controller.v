`timescale 1ns / 1ps

module controller #(parameter DATA_WIDTH = 8, parameter ADDRESS_WIDTH = 8)(
input wire req,rw,clk,rst,bmode,abort,ram_stat,
input [3:0]burst_len,
inout wire [DATA_WIDTH:0]data_cn_ram,
input wire [ADDRESS_WIDTH-1:0]addr,
output wire wre,oe,ce,busy,tri_o,
output reg done,error_flag,
inout wire [DATA_WIDTH-1:0]data_cn_in_out
    );
    //internal registers
    reg [ADDRESS_WIDTH-1:0]addr_reg;
    reg [DATA_WIDTH-1:0] data_reg;
    reg [1:0]try;
    reg rw_reg,req_reg,bmode_reg;
    reg [3:0]state,next_state; 
    reg [3:0]burst_len_reg;
    reg [3:0]burst_count;
    //internal registers
    
    //local parameters
    localparam IDLE = 4'b0001;
    localparam PRE_IDLE = 4'b0000;
    localparam PRE = 4'b0010;
    localparam WRITE = 4'b0011;
    localparam READ = 4'b0100;
    localparam BE = 4'b0101;
    
    localparam MAXTRY = 2'b11;
    
    //local parameters
    
    
    //state-register
    always @(posedge clk)
        begin
            if(!rst)
                begin
                    state <= PRE_IDLE;
                    try <= 2'b00;
                    addr_reg  <= 0;
                    data_reg  <= 0;
                    rw_reg    <= 0;
                    error_flag <=0;
                    done <=0;
                    burst_count <= 1'b0;
                    bmode_reg <= 0;
                    burst_len_reg <= 0;
                    req_reg <= 0;
                end
             else
             begin
                state <= next_state;
                done <= 0;
                
                    if(state == IDLE && req)
                        begin
                            addr_reg <= addr;
                           
                            rw_reg <= rw;
                            bmode_reg <= bmode;
                            burst_len_reg <= burst_len;
                            burst_count <= 1'b0;
                            error_flag <=0;
                            if(rw)
                                data_reg <= data_cn_in_out;  
                        end
                    else if(state == WRITE || state == READ)
                            begin
                                if(ram_stat)
                                    begin
                                        if(bmode_reg)
                                        begin
                                            if(burst_count < burst_len_reg -1)
                                                begin
                                                    burst_count <= burst_count +1'b1;
                                                    addr_reg <= addr_reg + 1'b1;
                                                end   
                                        end
                                    end
                           
                    
                         end
                end
        end
    //state-register
    
    //next-state-logic
        always @(*)
        
        begin
        next_state = state;
            case(state)
                
                PRE_IDLE : next_state = IDLE;
                
                IDLE: begin
                            if(req)
                            next_state = PRE;
                            else
                            next_state = IDLE;
                        end
                
                PRE: begin
                            if(rw_reg)
                            next_state = WRITE;
                            else
                            next_state = READ;
                     end
                WRITE: begin
                            if(ram_stat)
                                begin
                                    if(bmode_reg)
                                        begin
                                            if(burst_count == burst_len_reg -1)
                                                next_state = BE;
                                            else
                                                next_state = WRITE;
                                        end
                                     else
                                        next_state = IDLE;
                                end
                        end
                READ: begin
                            if(ram_stat)
                                begin
                                    if(bmode_reg)
                                        begin
                                            if(burst_count == burst_len_reg -1)
                                                next_state = BE;
                                            else
                                                next_state = READ;
                                        end
                                     else
                                        next_state = IDLE;
                                end
                        end
                BE: next_state = IDLE;
            endcase
        end
    //next-state-logic
endmodule
