`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.08.2026 22:40:25
// Design Name: 
// Module Name: spsramsim
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


module spsramsim();
    parameter DATAWIDTH = 8;
    parameter ADDRESSWIDTH = 8;
    parameter DEPTH = 256;
    reg clk,wre,oe,ce;
    reg [ADDRESSWIDTH-1:0] addr;
    wire [DATAWIDTH-1:0] data; //bidirectional Data bus
    reg [DATAWIDTH-1:0] indata;//data to be written during test
    assign data = (wre && ce)? indata: 8'hzz;//bus enabled if write mode is selected
    
    //instantiate sram module
    spsram uut(
    .clk(clk),
    .wre(wre),
    .oe(oe),
    .ce(ce),
    .addr(addr),
    .data(data)
    );
    always #5 clk = ~clk;
    
    initial
    begin
    //initial cond
    clk = 0;
    ce = 0;
    oe = 0;
    addr = 0;
    indata = 0;
    wre = 0;
    #10
    //write operation
    ce = 1'b1;
    wre  = 1'b1;
    oe = 0;
    addr = 8'h00;
    indata = 8'hAB;
    #10;
    wre  = 0;
    oe = 0;
    ce = 0;
    #10
    wre = 0;
    oe = 1;
    ce = 1;
    addr = 8'h0;
    #10;
     $display("Read Data = %h", data);
    $finish;
    end
   
endmodule
