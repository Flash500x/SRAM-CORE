`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.10.2026 11:47:09
// Design Name: 
// Module Name: arbiter_sim
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


module arbiter_sim(

    );
    reg clk,rst,a,b;
    wire rg,wg;
    
    arbiter art( 
    .clk(clk),
    .rst(rst),
    .a(a),
    .b(b),
    .rg(rg),
    .wg(wg)
    );
    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
        rst = 1'b0;
        a = 0;
        b = 0;
        #10;
        rst = 1'b1;
        a = 1'b1;
        #10;
        a = 1'b0;
        b = 1'b1;
        #10;
        a = 1'b1;
        #10;
        b = 1'b0;
        #10
        b = 1'b1;
        #20;
    end
endmodule
