`timescale 1ns / 1ps

package monitor_pkg;
    import config_pkg::*;
    import axi_txn_pkg::*;

    // Monitor: watches the AXI pins only, never drives them.
    // A write is reported when its B response is taken, a read when its RLAST beat is taken.

    class monitor;
        virtual axi_if     vif;
        mailbox #(axi_txn) mon2scb;
        axi_txn aw_q[$];          // write addresses waiting for their B
        axi_txn ar_q[$];          // read addresses waiting for their beats
        axi_txn cur_rd;           // read whose beats are coming in
        int w_beats_seen;
        int b_seen, r_beats_seen, unexpected;

        function new(virtual axi_if vif, mailbox #(axi_txn) mon2scb);
            this.vif = vif;
            this.mon2scb = mon2scb;
        endfunction

        task run();
            axi_txn o;
            forever begin
                @(vif.mon_cb);
                if (vif.mon_cb.ARST !== 1'b1) begin
                    aw_q.delete(); ar_q.delete(); cur_rd = null;
                    continue;
                end

                if (vif.mon_cb.AWVALID && vif.mon_cb.AWREADY) begin
                    o = new();
                    o.kind  = WR;
                    o.addr  = vif.mon_cb.AWADDR;
                    o.len   = vif.mon_cb.AWLEN;
                    o.burst = vif.mon_cb.AWBURST;
                    o.id    = vif.mon_cb.AWID;
                    aw_q.push_back(o);
                end

                if (vif.mon_cb.WVALID && vif.mon_cb.WREADY)
                    w_beats_seen++;

                if (vif.mon_cb.BVALID && vif.mon_cb.BREADY) begin
                    b_seen++;
                    if (aw_q.size() == 0) begin
                        o = new(); o.kind = WR; o.unexpected = 1; unexpected++;
                    end
                    else o = aw_q.pop_front();
                    o.bresp = vif.mon_cb.BRESP;
                    o.bid   = vif.mon_cb.BID;
                    mon2scb.put(o);
                end

                if (vif.mon_cb.ARVALID && vif.mon_cb.ARREADY) begin
                    o = new();
                    o.kind  = RD;
                    o.addr  = vif.mon_cb.ARADDR;
                    o.len   = vif.mon_cb.ARLEN;
                    o.burst = vif.mon_cb.ARBURST;
                    o.id    = vif.mon_cb.ARID;
                    ar_q.push_back(o);
                end

                if (vif.mon_cb.RVALID && vif.mon_cb.RREADY) begin
                    r_beats_seen++;
                    if (cur_rd == null) begin
                        if (ar_q.size() == 0) begin
                            cur_rd = new(); cur_rd.kind = RD; cur_rd.unexpected = 1; unexpected++;
                        end
                        else cur_rd = ar_q.pop_front();
                    end
                    cur_rd.rdata.push_back(vif.mon_cb.RDATA);
                    cur_rd.rresp.push_back(vif.mon_cb.RRESP);
                    cur_rd.rid.push_back(vif.mon_cb.RID);
                    cur_rd.rlast.push_back(vif.mon_cb.RLAST);
                    // RLAST closes the burst, a runaway burst is closed at 32 beats so it cannot hang
                    if (vif.mon_cb.RLAST || cur_rd.rdata.size() >= 32) begin
                        mon2scb.put(cur_rd);
                        cur_rd = null;
                    end
                end
            end
        endtask

        function int pending();
            return aw_q.size() + ar_q.size() + (cur_rd != null);
        endfunction
    endclass

endpackage
