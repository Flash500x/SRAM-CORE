`timescale 1ns / 1ps


module ecc_decoder
import config_pkg::*;
(
    input  logic [CODE_WIDTH-1:0]   code_in,
    output logic [DATA_WIDTH-1:0]   data_out,
    output logic [PARITY_WIDTH-1:0] syndrome,        
    output logic                    err_corrected,  
    output logic                    err_double      
    );

    // Position number (1..HAMMING_WIDTH) of data bit i - the seat it sits in
    function automatic int data_pos(input int i);
        int d     = 0;
        int pos_i = 0;
        for (int pos = 1; pos <= HAMMING_WIDTH; pos++)
            if ((pos & (pos - 1)) != 0) begin       // data position (not a power of 2)
                if (d == i) pos_i = pos;
                d++;
            end
        return pos_i;
    endfunction

    // Step 1: split the stored word
    logic [DATA_WIDTH-1:0]   data_rx;
    logic [PARITY_WIDTH-1:0] P_rx;
    logic                    odd;          // whole codeword has odd parity: an odd number of bits flipped
    logic                    pos_valid;    // syndrome points at a real position
    assign data_rx = code_in[DATA_WIDTH-1:0];
    assign P_rx    = code_in[HAMMING_WIDTH-1:DATA_WIDTH];
    assign odd     = ^code_in;

    // Step 2 + 3: recompute each parity bit with the same masks, compare with the stored one
    for (genvar j = 0; j < PARITY_WIDTH; j++) begin : g_syndrome
        localparam logic [DATA_WIDTH-1:0] MASK = parity_mask(j);
        assign syndrome[j] = P_rx[j] ^ (^(data_rx & MASK));
    end

    assign pos_valid     = (syndrome <= HAMMING_WIDTH);
    assign err_corrected = odd && pos_valid;
    assign err_double    = (!odd && syndrome != 0) || (odd && !pos_valid);

    // Step 4: flip the data bit whose position equals the syndrome, only for a single error
    for (genvar i = 0; i < DATA_WIDTH; i++) begin : g_correct
        localparam int POS = data_pos(i);
        assign data_out[i] = data_rx[i] ^ (odd && syndrome == POS);
    end

endmodule
