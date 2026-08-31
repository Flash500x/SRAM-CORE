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
    reg data_valid;
    reg [DATA_WIDTH-1:0] mem[0:DEPTH-1];
    reg [DATA_WIDTH-1:0] TEMPDATA;
    always @(posedge clk)
        begin
            data_valid <= 1'b0;
            if(wre && ce)
                mem[addr] <= data;
            else if(oe && !wre && ce)
                begin
                    TEMPDATA <= mem[addr];
                    data_valid <= 1'b1;
            end
    end
    assign data = (!wre && ce && oe&& data_valid)? TEMPDATA:{DATA_WIDTH{1'hz}}; 
    
endmodule
