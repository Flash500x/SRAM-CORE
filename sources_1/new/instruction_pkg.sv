
package nmc_isa_pkg;

    // Instruction opcodes
    localparam logic [7:0] OP_NOP     = 8'h00;
    localparam logic [7:0] OP_HALT    = 8'h01;

    // Memory and internal data movement
    localparam logic [7:0] OP_LDR     = 8'h10;
    localparam logic [7:0] OP_MOV     = 8'h11;

    // Scalar arithmetic
    localparam logic [7:0] OP_ADD     = 8'h20;
    localparam logic [7:0] OP_SUB     = 8'h21;
    localparam logic [7:0] OP_MUL     = 8'h22;
    localparam logic [7:0] OP_MAC     = 8'h23;
    localparam logic [7:0] OP_DOT     = 8'h24;
    localparam logic [7:0] OP_SHIFT   = 8'h25;
    localparam logic [7:0] OP_RELU    = 8'h26;
    localparam logic [7:0] OP_CLAMP   = 8'h27;
    localparam logic [7:0] OP_REDSUM  = 8'h28;
    localparam logic [7:0] OP_MAXPOOL = 8'h29;
    localparam logic [7:0] OP_AVGPOOL = 8'h2A;

    // Control flow
    localparam logic [7:0] OP_LOOP    = 8'h30;

    // Vector operations
    localparam logic [7:0] OP_VADD    = 8'h40;
    localparam logic [7:0] OP_VMAC    = 8'h41;

endpackage
