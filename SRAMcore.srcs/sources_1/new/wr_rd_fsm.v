`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.08.2026 20:01:29
// Design Name: 
// Module Name: wr_rd_fsm
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module wr_rd_fsm #(parameter ADDRESS_WIDTH=8, parameter DATA_WIDTH=8)(
input clk,rst,req,rw,
input [ADDRESS_WIDTH-1:0]addr,
input [DATA_WIDTH-1:0]wdata,//data in
inout [DATA_WIDTH:0]data,//sram bus

output  reg oe,ce,wre
    );
    localparam MAXTRY = 3;// max tries allowed for read
    reg [1:0]try;//tries counter
    reg [DATA_WIDTH-1:0]rdata;//hold read data
    assign data = ce && wre?{^wdata,wdata}:{(DATA_WIDTH+1){1'hz}};
    reg [1:0]state,next_state;// state register
    //state register /memory
    always @(posedge clk or negedge rst)
        begin
            if(!rst)
            begin
                state <= 2'b00;//reset to idle
                rdata <= 0;
                try <= 0;
                end
            else
                begin
                if(state == 2'b00 && req && !rw)// reset retries for new read
                try <=0;
                if(state == 2'b11)
                    begin
                       
                            if(data[DATA_WIDTH] == ^data[DATA_WIDTH-1:0])
                                begin
                                rdata <= data[DATA_WIDTH-1:0];
                                try <= 0;
                                end
                            else
                            begin
                                if(try < MAXTRY)
                                try <=  try+1'b1;                               
                                end
                    end
                state <= next_state;// move to next state if rst is high after read
                end
        end
    //next state logic
    always @(*)          
        begin
        case(state)
            2'b00: 
                begin
                if(req)
                begin
                    if(!rw)
                        next_state = 2'b01;
                    else
                        next_state = 2'b10;
                end
                else 
                next_state = 2'b00;
                end
            2'b01:
                
                        next_state = 2'b11;
                
            2'b10:
                
                        next_state = 2'b00;
            2'b11: 
                        begin
                             if(data[DATA_WIDTH] == ^data[DATA_WIDTH-1:0])
                             next_state = 2'b00;
                             else
                             begin
                                if(try < MAXTRY)
                                    next_state = 2'b01;
                                else 
                                    next_state = 2'b00;
                             end                       
                        end                           
            default: next_state = 2'b00;
        endcase
        end
        
    
    //output logic
    always @(*)
        begin
            case(state)
            2'b00: //idle
                begin
                ce = 1'b0;
                oe = 1'b0;
                wre = 1'b0;
                end
            2'b01://read
                begin
                ce = 1'b1;
                oe = 1'b1;
                wre = 1'b0;
                end
            2'b10://write
                begin
                ce = 1'b1;
                oe = 1'b0;
                wre = 1'b1;
                end
            2'b11://read-wait
                begin
                ce = 1'b1;
                oe = 1'b1;
                wre = 1'b0;
                
                end    
            default:
                begin
                ce = 1'b0;
                oe = 1'b0;
                wre = 1'b0;
                end
            endcase
        end
endmodule
