`timescale 1ns / 1ps

package generator_pkg;
    import config_pkg::*;
    import axi_txn_pkg::*;

    // Generator: makes the transaction stream in three phases
    //   1. directed: a write then a read for every burst type and every length 1..16
    //   2. random:   num_random constrained random transactions (errors, ECC, back-pressure)
    //   3. sweep:    read the whole memory back, so every word the model knows is checked
    // power mode (idle_pct >= 0, set by +IDLE_PCT): instead of the three phases above, num_power
    // clean legal transactions (no errors, no back-pressure) so every idle level sees the same
    // kind of traffic; the driver adds the idle time

    class generator;
        mailbox #(axi_txn) gen2drv;
        int num_random = 5000;
        int idle_pct   = -1;  // -1: normal test, 0..99: power test
        int num_power  = 2000;
        int total;            // all transactions this generator will send
        event done;

        function new(mailbox #(axi_txn) gen2drv);
            this.gen2drv = gen2drv;
        endfunction

        function int count();
            if (idle_pct >= 0) return num_power;
            return 3 * 16 * 2 + num_random + MEM_DEPTH / 16;
        endfunction

        // a clean, full speed transaction with the request fields given
        function axi_txn directed(kind_e k, bit [1:0] b, int l, int a);
            axi_txn t = new();
            t.fixed_req  = 1;
            t.kind       = k;
            t.burst      = b;
            t.len        = l;
            t.addr       = a;
            t.werr       = W_NONE;
            t.ecc        = ECC_NONE;
            t.w_gap_max  = 0;
            t.aw_w_skew  = 0;
            t.rready_pct = 100;
            t.bready_pct = 100;
            if (!t.randomize()) $fatal(1, "generator: randomize failed");
            t.phase = "directed";
            return t;
        endfunction

        task send(axi_txn t);
            gen2drv.put(t);
        endtask

        // one clean, legal, random transaction for the power test
        function axi_txn power_txn();
            axi_txn t;
            kind_e    k;
            bit [1:0] b;
            int       l;
            k = $urandom_range(1, 0) ? RD : WR;
            case ($urandom_range(2, 0))
                0: b = B_FIXED;
                1: b = B_INCR;
                default: b = B_WRAP;
            endcase
            if (b == B_WRAP) begin
                int wl[4] = '{1, 3, 7, 15};
                l = wl[$urandom_range(3, 0)];
            end else
                l = $urandom_range(15, 0);
            t = directed(k, b, l, $urandom_range(MEM_DEPTH - 17, 0));
            t.phase = "power";
            return t;
        endfunction

        task run();
            axi_txn t;
            total = count();

            if (idle_pct >= 0) begin
                for (int i = 0; i < num_power; i++) send(power_txn());
                -> done;
                return;
            end

            // ---- phase 1: directed matrix, clean writes and reads ----
            for (int b = 0; b < 3; b++) begin
                for (int l = 0; l < 16; l++) begin
                    bit [1:0] bt;
                    bit [ADDRESS_WIDTH-1:0] a;
                    bt = (b == 0) ? B_FIXED : (b == 1) ? B_INCR : B_WRAP;
                    a  = $urandom_range(MEM_DEPTH - 17, 0);
                    send(directed(WR, bt, l, a));
                    send(directed(RD, bt, l, a));
                end
            end

            // ---- phase 2: constrained random ----
            for (int i = 0; i < num_random; i++) begin
                t = new();
                if (!t.randomize()) $fatal(1, "generator: randomize failed");
                send(t);
            end

            // ---- phase 3: read back all of memory, 16 beats at a time ----
            for (int a = 0; a < MEM_DEPTH; a += 16) begin
                t = directed(RD, B_INCR, 15, a);
                t.phase = "sweep";
                send(t);
            end

            -> done;
        endtask
    endclass

endpackage
