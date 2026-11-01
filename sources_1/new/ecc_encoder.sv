`timescale 1ns / 1ps



module ecc_encoder #(parameter DATA_WIDTH = 8,
parameter R = 3)(
input logic [DATA_WIDTH-1:0]data_in,
output logic [DATA_WIDTH+R:0]data_out);

function automatic integer calc_parity_bits(input [DATA_WIDTH-1 m);
        integer r;
        begin
            r = 0;
            while ((2**r) < (m + r + 1))
                r = r + 1;

            calc_parity_bits = r;
        end
    endfunction
    
endmodule