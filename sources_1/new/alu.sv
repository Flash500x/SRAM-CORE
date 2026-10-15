
import alu_operation_pkg::*;
module alu(
input logic [3:0]alu_op,
input logic [31:0]ra,rb,
output logic [31:0] rd
    );
    always_comb
    begin
    rd = 32'b0;
        case(alu_op)
            ALU_ADD : rd = ra+rb;
             default: rd = 32'b0;
        endcase
    end
endmodule
