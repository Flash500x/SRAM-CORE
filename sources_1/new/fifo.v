`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.09.2026 00:02:51
// Design Name: 
// Module Name: fifo
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


module fifo #(parameter DATA_WIDTH = 8)(
input clk,rst,wr_en,rd_en,
input [DATA_WIDTH -1 :0] data_in,
output reg [DATA_WIDTH -1:0] data_out,
output full,empty
    );
        reg [DATA_WIDTH -1:0] mem [3:0];
        reg [3:0] count;
        reg [1:0] wr_ptr,rd_ptr;
        assign full = count == 3'd4;
        assign empty = count == 1'b0;
        
        always @(posedge clk or negedge rst)
            begin
                if(!rst)
                    begin
                        data_out <= 0;
                        wr_ptr <= 0;
                        rd_ptr <= 0;
                        count <= 0; 
                    end
                 else
                    begin
                        if(wr_en && !full)
                        begin
                        mem[wr_ptr] <= data_in;
                        wr_ptr <= wr_ptr +1;
                        count <= count + 1;
                       
                        end
                        if(rd_en && !empty)
                        begin
                        data_out <= mem[rd_ptr];
                        rd_ptr <= rd_ptr +1;
                        count <= count - 1;
                        end                       
                    end
            end
        
endmodule
