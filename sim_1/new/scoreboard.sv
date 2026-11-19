`timescale 1ns / 1ps

package scoreboard_pkg;
    import config_pkg::*;
    import axi_txn_pkg::*;

    // Scoreboard: reference model of the memory and the AXI responses.
    // Pairs each request from the driver with what the monitor saw, checks every field,
    // keeps per-scenario and per-check counts, and prints the final report.

    // SEC-DED codeword the SRAM should hold for a data byte (same code as ecc_encoder)
    function automatic bit [CODE_WIDTH-1:0] ecc_encode(bit [DATA_WIDTH-1:0] d);
        bit [HAMMING_WIDTH-1:0] h;
        h = '0;
        h[DATA_WIDTH-1:0] = d;
        for (int j = 0; j < PARITY_WIDTH; j++) h[DATA_WIDTH + j] = ^(d & parity_mask(j));
        return {^h, h};
    endfunction

    class scoreboard;
        virtual axi_if     vif;
        mailbox #(axi_txn) drv2scb;
        mailbox #(axi_txn) mon2scb;

        bit [DATA_WIDTH-1:0] model[MEM_DEPTH];   // what every SRAM word should hold

        int n_txn, n_txn_pass, n_txn_fail;
        int n_checks, n_check_fail;
        int resp_wait_limit = 50000;

        // scenario name -> hits / passed / failed (a transaction can hit several scenarios)
        string scen_order[$];
        int    scen_hit[string], scen_pass[string], scen_fail[string];
        // check name -> passed / failed
        string chk_order[$];
        int    chk_pass[string], chk_fail[string];
        // stimulus matrix: [kind][burst][beats-1]
        int    matrix[2][4][16];
        int    phase_cnt[string];
        bit    need_all_scenarios = 1;   // power test runs clean traffic only, it clears this
        // failure log
        string fail_log[$];
        int    max_log = 30;

        // per transaction working state
        bit    cur_ok;
        string cur_scen[$];

        function new(virtual axi_if vif, mailbox #(axi_txn) drv2scb, mailbox #(axi_txn) mon2scb);
            this.vif = vif;
            this.drv2scb = drv2scb;
            this.mon2scb = mon2scb;
            foreach (model[i]) model[i] = '0;      // SRAM starts all zero
            // every scenario is listed up front, so one that never ran shows up as a hole
            scen_order = '{
                "WRITE  legal, OKAY",
                "WRITE  illegal: INCR crosses the top of memory",
                "WRITE  illegal: WRAP length not 2/4/8/16",
                "WRITE  illegal: reserved burst type 2'b11",
                "WRITE  error: early WLAST, burst ends there",
                "WRITE  error: WLAST missing, extra beats purged",
                "WRITE  error: W timeout, no data after AW",
                "WRITE  error: W timeout in the middle of a burst",
                "READ   legal, OKAY",
                "READ   illegal: INCR crosses the top of memory",
                "READ   illegal: WRAP length not 2/4/8/16",
                "READ   illegal: reserved burst type 2'b11",
                "READ   ECC single-bit error corrected, OKAY",
                "READ   ECC double-bit error, SLVERR",
                "ECC    corrected word written back to SRAM",
                "STIM   slow master: idle cycles between W beats",
                "STIM   W data before AW",
                "STIM   AW before W data",
                "STIM   BREADY throttled",
                "STIM   RREADY throttled",
                "FINAL  memory read-back sweep (all 256 words)",
                "FINAL  SRAM backdoor compare, data + ECC bits"
            };
            foreach (scen_order[i]) begin
                scen_hit[scen_order[i]] = 0; scen_pass[scen_order[i]] = 0; scen_fail[scen_order[i]] = 0;
            end
            chk_order = '{"request matches AW/AR", "response arrived",
                          "BRESP", "BID", "R beat count", "RRESP", "RDATA", "RID", "RLAST",
                          "ECC write back", "SRAM word (backdoor)", "W beats driven = seen",
                          "no stray responses"};
            foreach (chk_order[i]) begin chk_pass[chk_order[i]] = 0; chk_fail[chk_order[i]] = 0; end
        endfunction

        // ---------------- check bookkeeping ----------------
        function void check(bit ok, string name, string msg, axi_txn t = null);
            n_checks++;
            if (ok) chk_pass[name]++;
            else begin
                chk_fail[name]++;
                n_check_fail++;
                cur_ok = 0;
                if (fail_log.size() < max_log)
                    fail_log.push_back($sformatf("[%0t] %s: %s%s", $time, name, msg,
                                                 t != null ? {"\n           ", t.sprint()} : ""));
            end
        endfunction

        function void hit(string s);
            cur_scen.push_back(s);
        endfunction

        function void close_txn();
            n_txn++;
            if (cur_ok) n_txn_pass++; else n_txn_fail++;
            foreach (cur_scen[i]) begin
                scen_hit[cur_scen[i]]++;
                if (cur_ok) scen_pass[cur_scen[i]]++; else scen_fail[cur_scen[i]]++;
            end
        endfunction

        // ---------------- main loop ----------------
        task run();
            axi_txn exp, obs;
            forever begin
                drv2scb.get(exp);
                obs = null;
                fork
                    mon2scb.get(obs);
                    repeat (resp_wait_limit) @(vif.mon_cb);
                join_any
                disable fork;
                cur_ok = 1;
                cur_scen.delete();
                phase_cnt[exp.phase]++;
                if (exp.burst <= 3) matrix[exp.kind == RD][exp.burst][exp.len]++;
                check(obs != null && !exp.drv_hang, "response arrived", "no response from the DUT", exp);
                if (obs != null) begin
                    check(!obs.unexpected && obs.kind == exp.kind && obs.addr == exp.addr &&
                          obs.len == exp.len && obs.burst == exp.burst && obs.id == exp.id,
                          "request matches AW/AR",
                          $sformatf("monitor saw %s", obs.unexpected ? "a response with no request" :
                                    obs.sprint()), exp);
                    if (exp.kind == WR) check_write(exp, obs);
                    else                check_read(exp, obs);
                end
                close_txn();
            end
        endtask

        // ---------------- write ----------------
        task check_write(axi_txn t, axi_txn o);
            bit [1:0] exp_resp;
            int n_written;

            exp_resp = (t.is_legal() && t.werr == W_NONE) ? RESP_OKAY : RESP_SLVERR;
            check(o.bresp == exp_resp, "BRESP",
                  $sformatf("got %0d expected %0d", o.bresp, exp_resp), t);
            check(o.bid == t.id, "BID", $sformatf("got %0d expected %0d", o.bid, t.id), t);

            // which beats really reach the SRAM
            case (t.werr)
                W_EARLY_WLAST:     n_written = t.w_err_beat + 1;
                W_TIMEOUT_NO_DATA: n_written = 0;
                W_TIMEOUT_MID:     n_written = t.w_err_beat;
                default:           n_written = t.beats();      // missing WLAST: the extras are purged
            endcase
            if (t.is_legal())
                for (int i = 0; i < n_written; i++) model[t.beat_addr(i)] = t.wdata[i];

            // scenarios
            if (!t.is_legal()) hit({"WRITE  illegal: ", t.illegal_kind()});
            case (t.werr)
                W_NONE:            if (t.is_legal()) hit("WRITE  legal, OKAY");
                W_EARLY_WLAST:     hit("WRITE  error: early WLAST, burst ends there");
                W_MISSING_WLAST:   hit("WRITE  error: WLAST missing, extra beats purged");
                W_TIMEOUT_NO_DATA: hit("WRITE  error: W timeout, no data after AW");
                W_TIMEOUT_MID:     hit("WRITE  error: W timeout in the middle of a burst");
            endcase
            if (t.w_gap_max > 0 && t.pre_b_beats > 1) hit("STIM   slow master: idle cycles between W beats");
            if (t.aw_w_skew < 0 && t.pre_b_beats > 0) hit("STIM   W data before AW");
            if (t.aw_w_skew > 0 && t.pre_b_beats > 0) hit("STIM   AW before W data");
            if (t.bready_pct < 100) hit("STIM   BREADY throttled");
        endtask

        // ---------------- read ----------------
        task check_read(axi_txn t, axi_txn o);
            bit [ADDRESS_WIDTH-1:0] a, bad;
            bit [1:0] exp_resp;
            bit [DATA_WIDTH-1:0] exp_data;
            int n;

            bad = t.beat_addr(t.ecc_beat);
            check(o.rdata.size() == t.beats(), "R beat count",
                  $sformatf("got %0d beats expected %0d", o.rdata.size(), t.beats()), t);
            n = (o.rdata.size() < t.beats()) ? o.rdata.size() : t.beats();
            for (int i = 0; i < n; i++) begin
                a = t.beat_addr(i);
                if (!t.is_legal() || (t.ecc == ECC_DOUBLE && a == bad)) begin
                    exp_resp = RESP_SLVERR;
                    exp_data = '0;
                end
                else begin
                    exp_resp = RESP_OKAY;
                    exp_data = model[a];
                end
                check(o.rresp[i] == exp_resp, "RRESP",
                      $sformatf("beat %0d addr %02h got %0d expected %0d", i, a, o.rresp[i], exp_resp), t);
                check(o.rdata[i] == exp_data, "RDATA",
                      $sformatf("beat %0d addr %02h got %02h expected %02h", i, a, o.rdata[i], exp_data), t);
                check(o.rid[i] == t.id, "RID",
                      $sformatf("beat %0d got %0d expected %0d", i, o.rid[i], t.id), t);
                check(o.rlast[i] == (i == t.beats() - 1), "RLAST",
                      $sformatf("beat %0d RLAST=%0d", i, o.rlast[i]), t);
            end

            // the corrected word must be back in the SRAM once the controller is idle again
            if (t.ecc == ECC_SINGLE) begin
                bit [CODE_WIDTH-1:0] code;
                do @(vif.mon_cb); while (vif.mon_cb.dut_busy);
                peek(bad, code);
                check(code == ecc_encode(model[bad]), "ECC write back",
                      $sformatf("SRAM[%02h] holds %h expected %h", bad, code, ecc_encode(model[bad])), t);
                hit("ECC    corrected word written back to SRAM");
            end

            // scenarios
            if (!t.is_legal()) hit({"READ   illegal: ", t.illegal_kind()});
            else begin
                hit("READ   legal, OKAY");
                if (t.ecc == ECC_SINGLE) hit("READ   ECC single-bit error corrected, OKAY");
                if (t.ecc == ECC_DOUBLE) hit("READ   ECC double-bit error, SLVERR");
            end
            if (t.rready_pct < 100) hit("STIM   RREADY throttled");
            if (t.phase == "sweep") hit("FINAL  memory read-back sweep (all 256 words)");
        endtask

        task peek(input bit [ADDRESS_WIDTH-1:0] a, output bit [CODE_WIDTH-1:0] code);
            vif.peek_addr = a;
            #1;
            code = vif.peek_code;
        endtask

        // ---------------- end of test ----------------
        task final_checks(int w_driven, int w_seen, int mon_pending, int mon_unexpected);
            bit [CODE_WIDTH-1:0] code;
            int bad_words = 0;

            // every SRAM word, data and check bits, against the model
            cur_ok = 1;
            cur_scen.delete();
            for (int a = 0; a < MEM_DEPTH; a++) begin
                peek(a, code);
                if (code !== ecc_encode(model[a])) bad_words++;
                check(code === ecc_encode(model[a]), "SRAM word (backdoor)",
                      $sformatf("SRAM[%02h] holds %h expected %h", a, code, ecc_encode(model[a])));
            end
            hit("FINAL  SRAM backdoor compare, data + ECC bits");
            foreach (cur_scen[i]) begin
                scen_hit[cur_scen[i]]++;
                if (cur_ok) scen_pass[cur_scen[i]]++; else scen_fail[cur_scen[i]]++;
            end

            check(w_driven == w_seen, "W beats driven = seen",
                  $sformatf("driver %0d, monitor %0d", w_driven, w_seen));
            // an extra B or R burst would be left over here, or be seen with no request
            check(mon_pending == 0 && mon2scb.num() == 0 && mon_unexpected == 0, "no stray responses",
                  $sformatf("%0d requests still open, %0d responses left over, %0d responses with no request",
                            mon_pending, mon2scb.num(), mon_unexpected));
        endtask

        // left aligned field, xsim ignores %-Ns
        function string pad(string s, int w);
            while (s.len() < w) s = {s, " "};
            return s;
        endfunction

        function void report(int seed_info);
            string line;
            int holes = 0;
            line = {80{"="}};
            $display("\n%s", line);
            $display("  SRAM CORE AXI TESTBENCH REPORT");
            $display("%s", line);
            $display("  transactions checked : %0d   (directed %0d, random %0d, sweep %0d)",
                     n_txn, phase_cnt["directed"], phase_cnt["random"], phase_cnt["sweep"]);
            $display("  transactions passed  : %0d", n_txn_pass);
            $display("  transactions failed  : %0d", n_txn_fail);
            $display("  checks done          : %0d   (failed %0d)", n_checks, n_check_fail);
            $display("  simulation time      : %0t", $time);

            $display("\n  SCENARIOS                                               hits    pass    fail");
            $display("  %s", {76{"-"}});
            foreach (scen_order[i]) begin
                string s = scen_order[i];
                $display("  %s %7d %7d %7d%s", pad(s, 52), scen_hit[s], scen_pass[s], scen_fail[s],
                         scen_hit[s] == 0 ? "   <-- NOT HIT" : "");
                if (scen_hit[s] == 0) holes++;
            end

            $display("\n  CHECKS                                                         pass    fail");
            $display("  %s", {76{"-"}});
            foreach (chk_order[i])
                $display("  %s %7d %7d", pad(chk_order[i], 60), chk_pass[chk_order[i]], chk_fail[chk_order[i]]);

            $display("\n  BURSTS RUN (transactions per burst type and beat count)");
            $display("  %s", {76{"-"}});
            $display("              beats:  1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16");
            for (int k = 0; k < 2; k++)
                for (int b = 0; b < 4; b++) begin
                    string row;
                    string bname[4] = '{"FIXED", "INCR ", "WRAP ", "RSVD "};
                    row = $sformatf("  %s %s      ", k ? "READ " : "WRITE", bname[b]);
                    for (int l = 0; l < 16; l++) row = {row, $sformatf("%4d", matrix[k][b][l])};
                    $display("%s", row);
                end

            if (fail_log.size() > 0) begin
                $display("\n  FIRST %0d FAILURES", fail_log.size());
                $display("  %s", {76{"-"}});
                foreach (fail_log[i]) $display("  %s", fail_log[i]);
            end

            $display("\n%s", line);
            if (n_check_fail == 0 && n_txn_fail == 0 && holes == 0)
                $display("  RESULT: PASS  -  %0d transactions, %0d checks, every scenario hit", n_txn, n_checks);
            else if (n_check_fail == 0 && n_txn_fail == 0 && !need_all_scenarios)
                $display("  RESULT: PASS  -  %0d transactions, %0d checks (power test: clean traffic, error scenarios not run)",
                         n_txn, n_checks);
            else
                $display("  RESULT: FAIL  -  %0d failed checks, %0d failed transactions, %0d scenarios not hit",
                         n_check_fail, n_txn_fail, holes);
            $display("%s\n", line);
        endfunction
    endclass

endpackage
