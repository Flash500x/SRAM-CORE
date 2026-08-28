`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.08.2026 22:20:53
// Design Name: 
// Module Name: spsram
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


module spsram #(parameter DATAWIDTH = 8,parameter ADDRESSWIDTH = 8,
parameter DEPTH = 256)(
input clk,wre,oe,ce,
input [ADDRESSWIDTH-1:0]addr,
inout [DATAWIDTH-1:0]data
    );
    reg [DATAWIDTH-1:0] mem[0:DEPTH-1];
    reg [DATAWIDTH-1:0] TEMPDATA;
    always @(posedge clk)
    begin
    if(wre && ce)
        mem[addr] <= data;
    if(!wre && ce)
        TEMPDATA <= mem[addr];
    end
    assign data = !wre & ce & oe? TEMPDATA:'hz;
endmodule
