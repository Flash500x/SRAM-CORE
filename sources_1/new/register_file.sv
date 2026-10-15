`timescale 1ns / 1ps

module register_file(
input logic clk,rst,wr_en,
input logic [1:0]wr_addr,rd_addr_a,rd_addr_b,
input logic [31:0] wr_data,
output logic [31:0]rd_data_a,
output logic [31:0]rd_data_b
    );
    logic [31:0] mem [0:3];
    integer i;
    initial begin
    mem[0] = 32'd5;
    mem[1] = 32'd7;
    mem[2] = 32'd0;
    mem[3] = 32'd0;
    end
    always_ff @(posedge clk)
    begin
        if(!rst)
        begin
           
           
        end
        else
            begin
                if(wr_en)
                    mem[wr_addr] <= wr_data;
            end
    end
    
    always_comb
    begin
    if(!rst)
        begin
        rd_data_a = 0;
        rd_data_b = 0;
        end
        else
        begin
        rd_data_a = mem[rd_addr_a];
        rd_data_b = mem[rd_addr_b];
        end
    end
    
endmodule
