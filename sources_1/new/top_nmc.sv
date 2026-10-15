`timescale 1ns / 1ps;
//////////////////////////////////////////////////////////////////////////////////

module top_nmc(
input logic [31:0] instr,
input clk,rst,wr_en
    );
    logic[1:0]rd,ra,rb;
    
    logic [3:0] alu_op;
        decoder dut (
        .instr(instr),
        .rd_addr(rd),
        .ra_addr(ra),
        .rb_addr(rb),
        
        .alu_op(alu_op)
        );
    logic [31:0]rd_data_a,rd_data_b,rd_data_rd;
        register_file dut1(
            .clk(clk),
            .rst(rst),
            .rd_addr_a(ra),
            .rd_addr_b(rb),
            .wr_addr(rd),
            .wr_en(wr_en),
            .rd_data_a(rd_data_a),
            .rd_data_b(rd_data_b),
            .wr_data(rd_data_rd)
            
        );
        
        alu dut2(
        .ra(rd_data_a),
        .rb(rd_data_b),
        .alu_op(alu_op),
        .rd(rd_data_rd)
        );
endmodule
