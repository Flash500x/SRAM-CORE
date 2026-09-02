`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.08.2026 18:16:21
// Design Name: 
// Module Name: simpfsm
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


module simpfsm(
input clk,rst,wreq,
output reg we
    );
    reg state;
    reg next_state;
    //current state register
    always @(posedge clk or negedge rst)
    begin
    if(!rst)
    state <= 1'b0;
    else
    state <= next_state;
    end
    
    //next state cobminational logic
    always @(*)
    begin
    case(state)
    1'b0: 
  begin
        if(wreq)
        next_state = 1'b1;
        else 
        next_state = 1'b0;
        end
       
    1'b1: next_state = 1'b0;
    default: next_state = 1'b0;
    endcase
    end
    //output logic
    always @(*)
    begin
    case(state)
    1'b0:we = 1'b0;
    1'b1:we= 1'b1;
    default : we = 1'b0;
    endcase
    end
endmodule
