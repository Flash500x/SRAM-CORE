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


module spsram #(parameter DATA_WIDTH = 9,parameter ADDRESS_WIDTH = 8
)(
input clk,wre,oe,ce,
input [ADDRESS_WIDTH-1:0]addr,
inout [DATA_WIDTH-1:0]data // bidirectional data bus
    );
    localparam DEPTH = 2**ADDRESS_WIDTH;
    reg [DATA_WIDTH-1:0] mem[0:DEPTH-1];
    
    always @(posedge clk)
    begin
    if(wre && ce)
        mem[addr] <= data;
    end
    assign data = !wre & ce & oe? mem[addr]:'hz; 
endmodule
