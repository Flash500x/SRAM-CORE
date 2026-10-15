`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 12:47:37
// Design Name: 
// Module Name: icg_sim
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


module icg_sim(

    );
    logic clk,en,clk_out;
    
    ICG dut(
    .clk(clk),
    .en(en),
    .clk_out(clk_out)
    );
    
    always #5 clk = ~clk;
    
    initial begin
    clk = 0;
    en = 0;
    #10;
    en = 1;
    #20;
    en = 0;
    #10;
    
    $finish;
    end
endmodule
