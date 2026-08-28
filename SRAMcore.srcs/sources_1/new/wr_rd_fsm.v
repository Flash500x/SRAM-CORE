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


module wr_rd_fsm(
input clk,rst,req,rw,
output  reg re,we
    );
    reg [1:0]state,next_state;
    //state register /memory
    always @(posedge clk or negedge rst)
        begin
            if(!rst)
                state <= 2'b00;//reset to idle
            else
                state <= next_state;// move to next state if rst is high
        end
    
    //next state logic
    always @(*)
        begin
            if(req == 1'b0)
                next_state = 1'b0;
        else
        begin
        case(state)
            2'b00: 
                begin
                    if(!rw)
                        next_state = 2'b01;
                    else
                        next_state = 2'b10;
                end
            2'b01:
                
                        next_state = 2'b00;
                
            2'b10:
                
                        next_state = 2'b00;
                
            default: next_state = 2'b00;
        endcase
        end
        end
    
    //output logic
    always @(*)
        begin
            case(state)
            2'b00: 
                begin
                we = 1'b0;
                re = 1'b0;
                end
            2'b01:
                begin
                we = 1'b0;
                re = 1'b1;
                end
            2'b10:
                begin
                we = 1'b1;
                re = 1'b0;
                end
            default:
                begin
                we = 1'b0;
                re = 1'b0;
                end
            endcase
        end
endmodule
