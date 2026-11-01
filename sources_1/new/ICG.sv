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
    input  logic en, clk,
    output logic clk_out
);
`ifdef ASIC
    // ASIC-style integrated clock gate: latch + AND
    logic en_enb;
    always_latch if (!clk) en_enb = en;
    assign clk_out = en_enb & clk;
`else
    // FPGA: dedicated glitch-free clock buffer with enable
    BUFGCE u_bufgce (.I(clk), .CE(en), .O(clk_out));
`endif
endmodule
