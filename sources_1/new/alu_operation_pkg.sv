package alu_operation_pkg;
    localparam [3:0] ALU_ADD = 4'h0;
    localparam [3:0] ALU_SUB = 4'h1;
    localparam [3:0] ALU_MUL = 4'h2;
    localparam [3:0] ALU_AND = 4'h3;
    localparam [3:0] ALU_OR = 4'h4;
    localparam [3:0] ALU_XOR = 4'h5;
    localparam [3:0] ALU_SLL = 4'h6;
    localparam [3:0] ALU_SRL = 4'h7;
    localparam [3:0] ALU_SRA = 4'h8;
    localparam [3:0] ALU_RELU = 4'h9;
    localparam [3:0] ALU_CLAMP = 4'hA;
    localparam [3:0] ALU_NOP = 4'hF;
    
    
endpackage