`timescale 1ns / 1ps

package driver_pkg;
    import config_pkg::*;
    import axi_txn_pkg::*;

    // Driver: takes one transaction at a time from the generator and drives it on the AXI pins.
    // It hands the same transaction to the scoreboard first, so the scoreboard knows what to expect.
    // Transactions run one after another, the next starts when the previous one has its response.

    class driver;
        virtual axi_if     vif;
        mailbox #(axi_txn) gen2drv;
        mailbox #(axi_txn) drv2scb;
        int n_driven;          // transactions finished
        int w_beats_driven;    // W handshakes, checked against the monitor
        int hang_limit = 20000;
        int idle_pct   = -1;   // power test: hold off new transactions until this % of cycles are idle

        function new(virtual axi_if vif, mailbox #(axi_txn) gen2drv, mailbox #(axi_txn) drv2scb);
            this.vif = vif;
            this.gen2drv = gen2drv;
            this.drv2scb = drv2scb;
        endfunction

        task reset();
            vif.ARST <= 1'b0;
            vif.drv_cb.AWVALID <= 0; vif.drv_cb.AWADDR <= 0; vif.drv_cb.AWLEN <= 0;
            vif.drv_cb.AWBURST <= 0; vif.drv_cb.AWID <= 0;
            vif.drv_cb.WVALID  <= 0; vif.drv_cb.WDATA  <= 0; vif.drv_cb.WLAST <= 0;
            vif.drv_cb.BREADY  <= 0;
            vif.drv_cb.ARVALID <= 0; vif.drv_cb.ARADDR <= 0; vif.drv_cb.ARLEN <= 0;
            vif.drv_cb.ARBURST <= 0; vif.drv_cb.ARID <= 0;
            vif.drv_cb.RREADY  <= 0;
            repeat (5) @(vif.drv_cb);
            vif.ARST <= 1'b1;
            repeat (3) @(vif.drv_cb);
        endtask

        task run();
            axi_txn t;
            if (idle_pct >= 0) vif.cnt_en = 1'b1;
            forever begin
                gen2drv.get(t);
                // the previous read may still be writing back a corrected word
                while (vif.drv_cb.dut_busy) @(vif.drv_cb);
                // scoreboard checks the ECC write back in this gap; the power test has no ECC faults
                if (idle_pct < 0) repeat (2) @(vif.drv_cb);
                // power test: stay idle until the measured idle share reaches the target, so the
                // idle time is spread evenly between transactions (0% never waits here)
                if (idle_pct > 0) begin
                    longint unsigned idl, tot;
                    forever begin
                        idl = vif.cyc_idle;
                        tot = vif.cyc_total;
                        if (idl * 100 >= tot * idle_pct) break;
                        @(vif.drv_cb);
                    end
                end
                drv2scb.put(t);
                if (t.kind == WR) do_write(t);
                else              do_read(t);
                n_driven++;
            end
        endtask

        // ---------------- write ----------------
        task do_write(axi_txn t);
            fork
                begin
                    if (t.aw_w_skew < 0) repeat (-t.aw_w_skew) @(vif.drv_cb);
                    send_aw(t);
                end
                begin
                    if (t.aw_w_skew > 0) repeat (t.aw_w_skew) @(vif.drv_cb);
                    for (int i = 0; i < t.pre_b_beats; i++) send_w(t, i);
                end
            join
            wait_b(t);
            // timed out bursts: the late beats come now, the slave must throw them away
            for (int i = t.pre_b_beats; i < t.wdata.size(); i++) send_w(t, i);
        endtask

        task send_aw(axi_txn t);
            vif.drv_cb.AWADDR  <= t.addr;
            vif.drv_cb.AWLEN   <= t.len;
            vif.drv_cb.AWBURST <= t.burst;
            vif.drv_cb.AWID    <= t.id;
            vif.drv_cb.AWVALID <= 1'b1;
            do @(vif.drv_cb); while (!vif.drv_cb.AWREADY);
            vif.drv_cb.AWVALID <= 1'b0;
        endtask

        task send_w(axi_txn t, int i);
            vif.drv_cb.WDATA  <= t.wdata[i];
            vif.drv_cb.WLAST  <= t.wlast[i];
            vif.drv_cb.WVALID <= 1'b1;
            do @(vif.drv_cb); while (!vif.drv_cb.WREADY);
            w_beats_driven++;
            vif.drv_cb.WVALID <= 1'b0;
            vif.drv_cb.WLAST  <= 1'b0;
            if (t.w_gap_max > 0) repeat ($urandom_range(t.w_gap_max, 0)) @(vif.drv_cb);
        endtask

        task wait_b(axi_txn t);
            bit br;
            int cyc = 0;
            forever begin
                br = ($urandom_range(100, 1) <= t.bready_pct);
                vif.drv_cb.BREADY <= br;
                @(vif.drv_cb);
                if (vif.drv_cb.BVALID && br) break;
                if (++cyc > hang_limit) begin t.drv_hang = 1; break; end
            end
            vif.drv_cb.BREADY <= 1'b0;
        endtask

        // ---------------- read ----------------
        task do_read(axi_txn t);
            bit rr;
            int cyc = 0;
            bit [ADDRESS_WIDTH-1:0] bad_addr;

            // ECC fault: flip bits of one SRAM word the burst will read
            if (t.ecc != ECC_NONE) begin
                bad_addr = t.beat_addr(t.ecc_beat);
                inject(bad_addr, t.ecc_mask);
            end

            if (idle_pct < 0) repeat ($urandom_range(3, 0)) @(vif.drv_cb);   // power test: no extra gap
            vif.drv_cb.ARADDR  <= t.addr;
            vif.drv_cb.ARLEN   <= t.len;
            vif.drv_cb.ARBURST <= t.burst;
            vif.drv_cb.ARID    <= t.id;
            vif.drv_cb.ARVALID <= 1'b1;
            do @(vif.drv_cb); while (!vif.drv_cb.ARREADY);
            vif.drv_cb.ARVALID <= 1'b0;

            forever begin
                rr = ($urandom_range(100, 1) <= t.rready_pct);
                vif.drv_cb.RREADY <= rr;
                @(vif.drv_cb);
                if (vif.drv_cb.RVALID && rr && vif.drv_cb.RLAST) break;
                if (++cyc > hang_limit) begin t.drv_hang = 1; break; end
            end
            vif.drv_cb.RREADY <= 1'b0;

            // a double error is never written back, put the word right for the next transactions
            if (t.ecc == ECC_DOUBLE) begin
                @(vif.drv_cb);
                while (vif.drv_cb.dut_busy) @(vif.drv_cb);
                inject(bad_addr, t.ecc_mask);
            end
        endtask

        task inject(bit [ADDRESS_WIDTH-1:0] a, bit [CODE_WIDTH-1:0] mask);
            vif.inj_addr = a;
            vif.inj_mask = mask;
            vif.inj_stb  = ~vif.inj_stb;
            @(vif.drv_cb);
        endtask
    endclass

endpackage
