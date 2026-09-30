`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.09.2026 00:14:14
// Design Name: 
// Module Name: fifo_sim
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


module fifo_sim(

    );
    reg clk,rst,wr_en,rd_en;
    reg [7:0]data_in;
    wire [7:0]data_out;
    wire full,empty;
    
    fifo uut(
    .clk(clk),
    .rst(rst),
    .data_in(data_in),
    .data_out(data_out),
    .full(full),
    .empty(empty),
    .wr_en(wr_en),
    .rd_en(rd_en)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
        rst = 0;
        data_in = 0;
        wr_en = 0;
        rd_en = 0;
        #10;
        rst = 1'b1;
        #10;
        wr_en = 1'b1;
        data_in = 8'b0000_0001;
        #10
        data_in = 8'b0000_0010;
        #10;
        data_in = 8'b0000_0100;
        #10;
        data_in = 8'b0000_1010;
        #10;
        data_in = 8'b0000_1010;
        #10;
        data_in = 0;
        wr_en = 0;
        #10;
        rd_en = 1;
        #70;
    $finish;
    end
endmodule
