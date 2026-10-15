`timescale 1ns / 1ps
import nmc_isa_pkg::*;
import alu_operation_pkg::*;
module decoder #(parameter INSTRUCTION_WIDTH = 32)(
input logic [INSTRUCTION_WIDTH-1:0]instr,
output logic [3:0]alu_op,
output logic[1:0] rd_addr,ra_addr,rb_addr,
output logic wr_en
    );
    
    always_comb
    begin
        case(instr[31:24])
            OP_ADD: alu_op = ALU_ADD;
        endcase
        rd_addr = instr[23:22];
        ra_addr = instr[21:20];
        rb_addr = instr[19:18];
    end
    
endmodule
