`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.08.2026 20:45:12
// Design Name: 
// Module Name: rdwrfsmsim
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


module rdwrfsmsim(

    );
    parameter ADDRESS_WIDTH = 8;
    parameter DATA_WIDTH = 8;
    parameter DEPTH = 256;
    reg clk,req,rw,rst;
    reg [ADDRESS_WIDTH-1:0]addr;
    wire [DATA_WIDTH-1:0]data;
    reg [DATA_WIDTH-1:0]wdata;//data to be written when tested.
    wire oe,ce,wre;    
    wr_rd_fsm #(
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
    )uut(
    .clk(clk),
    .rst(rst),
    .rw(rw),
    .req(req),
    .oe(oe),
    .wre(wre),
    .ce(ce),
    .addr(addr),
    .data(data),
    .wdata(wdata)
    );
    spsram #(
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
    )uut1(
    .clk(clk),
    .addr(addr),
    .oe(oe),
    .ce(ce),
    .wre(wre),
    .data(data)
    );
    
    always #5 clk = ~clk;
    
    initial 
    begin
    clk = 0;
    rst = 0;
    req = 0;
    rw = 0;
    addr = 8'h00;
    wdata = 8'h00;
    #10;
    rst = 1'b1;
    req = 1'b1;
    rw = 1'b1;
    addr = 8'h00;
    wdata = 8'h01;
    #10;
    req = 1'b0;
    #10;
    addr = 8'h00;
    wdata = 8'h00;
    rst = 1'b1;
    req = 1'b1;
    rw = 1'b0;
    #10;
    rst = 1'b1;
    req = 1'b0;
    rw = 1'b1;
    #10;
    $finish;
    end
endmodule
