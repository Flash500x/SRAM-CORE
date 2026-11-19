`timescale 1ns / 1ps

// SEC-DED encoder: Hamming parity bits plus one overall parity bit
module ecc_encoder
import config_pkg::*;
(
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [CODE_WIDTH-1:0] code_out
    );
    logic [PARITY_WIDTH-1:0]  P;
    logic [HAMMING_WIDTH-1:0] hamming;

    for (genvar j = 0; j < PARITY_WIDTH; j++) begin : g_parity
        localparam logic [DATA_WIDTH-1:0] MASK = parity_mask(j);
        assign P[j] = ^(data_in & MASK);
    end

    assign hamming  = {P, data_in};
    // overall parity makes the whole codeword even, a double error then keeps it even
    assign code_out = {^hamming, hamming};

endmodule
