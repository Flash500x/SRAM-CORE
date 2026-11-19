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
`ifdef SYNTHESIS
    //FPGA: dedicated global clock buffer with enable. Glitch free, and no LUT on the
    //clock tree (a latch + AND here gives the TIMING-14 critical warning)
    BUFGCE u_bufgce (
        .I  (clk),
        .CE (en),
        .O  (clk_out)
    );
`else
    //simulation model of the same gate: enable is latched while the clock is low,
    //so it can only change between pulses, then ANDed with the clock
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
`endif
endmodule
