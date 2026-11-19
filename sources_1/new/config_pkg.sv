package config_pkg;
    localparam ADDRESS_WIDTH = 8;
    localparam DATA_WIDTH    = 32;
    localparam BURST_LENGTH  = 4;
    localparam ID_WIDTH      = 2;
    localparam BURST_TYPE    = 2;

    // write data handshake timeout: if the master leaves the slave waiting for a W beat
    // (after AW, or between beats of a burst) this many ACLK cycles, the write ends with SLVERR
    localparam W_TIMEOUT     = 32;

    // clock gating of the controller + SRAM clock (ICG / BUFGCE in AXI_SLAVE)
    //   1: controller_clk only toggles while a transfer is in flight
    //   0: controller_clk = ACLK, free running (baseline for power comparison)
    localparam CLOCK_GATING  = 0;

    // number of Hamming parity bits for k data bits: smallest p with 2^p >= k + p + 1
    function automatic int calc_parity(input int k);
        int p = 0;
        for (int i = 0; i < 31; i++)
            if ((1 << i) < (k + i + 1)) p = i + 1;
        return p;
    endfunction

    // SEC-DED codeword, stored in the SRAM:
    //   [CODE_WIDTH-1]               overall parity over the Hamming word (the DED bit)
    //   [HAMMING_WIDTH-1:DATA_WIDTH] Hamming parity bits P[PARITY_WIDTH-1:0]
    //   [DATA_WIDTH-1:0]             data
    localparam int PARITY_WIDTH  = calc_parity(DATA_WIDTH);      // 4 for 8 data bits
    localparam int HAMMING_WIDTH = DATA_WIDTH + PARITY_WIDTH;    // 12, the SEC part
    localparam int CODE_WIDTH    = HAMMING_WIDTH + 1;            // 13, plus the overall parity bit

    // data bits covered by Hamming parity bit j: data positions (1..HAMMING_WIDTH,
    // not a power of 2) whose position number has bit j set
    function automatic logic [DATA_WIDTH-1:0] parity_mask(input int j);
        int d = 0;
        parity_mask = '0;
        for (int pos = 1; pos <= HAMMING_WIDTH; pos++)
            if ((pos & (pos - 1)) != 0) begin      // data position (not a power of 2)
                if ((pos >> j) & 1)                // position has bit j set, so p[j] covers it
                    parity_mask[d] = 1'b1;
                d++;
            end
    endfunction

endpackage
