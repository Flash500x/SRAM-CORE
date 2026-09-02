`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.08.2026 18:24:12
// Design Name: 
// Module Name: simpfsmsim
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


module simpfsmsim(

    );
    reg clk,rst,wreq;
    wire we;
    
    simpfsm uut(
    .clk(clk),
    .rst(rst),
    .wreq(wreq),
    .we(we)
    );
    always #5 clk = ~clk;
    initial
    begin
    clk = 0;
    rst = 0;
    wreq = 0;
    #10;
    rst = 1'b1;
    wreq = 1'b1;
    #10;
    rst = 1'b1;
    wreq = 1'b0;
    #10;
    $finish;
    end
endmodule
