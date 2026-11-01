`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 12:40:41
// Design Name: 
// Module Name: ICG
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


module ICG(
input logic en,clk,
output logic clk_out
    );
    logic en_enb;
    always_latch
    begin
        if(!clk)
        en_enb = en;
    end
    always_comb
    begin
    clk_out = en_enb & clk;
    end
endmodule
