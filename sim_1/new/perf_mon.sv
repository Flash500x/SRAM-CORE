`timescale 1ns / 1ps
// perf_mon : passive throughput / latency monitor on the AXI interface.
// Instantiate in top_module_main_tb next to the DUT:   perf_mon u_perf (.intf(intf));
// Run a clean test (e.g. +IDLE_PCT=0) so READY throttling and error bursts don't skew it.
// Only bursts whose every response is OKAY are counted.
//
// Per burst length it reports (all in clock cycles of ACLK):
//   READ  addr->data : AR handshake -> first R beat handshake      (read latency)
//   READ  eff        : beats / (first R beat .. RLAST)              (1.00 = one beat per cycle)
//   READ  total      : AR handshake -> RLAST
//   WRITE eff        : beats / (first W beat .. WLAST)
//   WRITE resp       : WLAST handshake -> B handshake               (write response latency)
//   WRITE total      : first of (AW, first W) -> B handshake
// plus the sustained bus utilisation over the whole run.
module perf_mon (axi_if intf);
    import config_pkg::*;

    localparam int NID  = 1 << ID_WIDTH;
    localparam int MAXL = 1 << BURST_LENGTH;      // AxLEN+1 can reach this

    longint unsigned cyc = 0;

    // ---------------- read side ----------------
    typedef struct { longint unsigned t; int len; } ar_t;
    ar_t             arq [NID][$];
    bit              r_act  [NID];
    bit              r_ok   [NID];
    int              r_cnt  [NID];
    longint unsigned r_first[NID];

    longint unsigned rd_lat[MAXL+1], rd_brst[MAXL+1], rd_tot[MAXL+1];
    int              rd_n  [MAXL+1];

    // ---------------- write side ----------------
    typedef struct { longint unsigned t; int len; int id; } aw_t;
    typedef struct { longint unsigned t0, t1; int beats; } wb_t;
    typedef struct { longint unsigned t_start, t_wlast; int len; bit ok; int brst; } wp_t;
    aw_t             awq[$];
    wb_t             wq [$];
    wp_t             wpend[NID][$];
    bit              w_act;
    int              w_cnt;
    longint unsigned w_first;

    longint unsigned wr_resp[MAXL+1], wr_brst[MAXL+1], wr_tot[MAXL+1];
    int              wr_n   [MAXL+1];

    // ---------------- utilisation ----------------
    longint unsigned beats_r = 0, beats_w = 0, t_begin = 0, t_end = 0;
    bit              seen = 0;

    function automatic void pair_w();
        aw_t a; wb_t w; wp_t p;
        while (awq.size() && wq.size()) begin
            a = awq.pop_front();
            w = wq.pop_front();
            p.t_start = (a.t < w.t0) ? a.t : w.t0;
            p.t_wlast = w.t1;
            p.len     = a.len;
            p.ok      = (w.beats == a.len);
            p.brst    = int'(w.t1 - w.t0 + 1);
            wpend[a.id].push_back(p);
        end
    endfunction

    always @(posedge intf.ACLK) begin
        if (intf.ARST) begin
            // AR
            if (intf.ARVALID && intf.ARREADY) begin
                ar_t na;
                na.t = cyc; na.len = int'(intf.ARLEN) + 1;
                arq[intf.ARID].push_back(na);
            end
            // R
            if (intf.RVALID && intf.RREADY) begin
                automatic int id = intf.RID;
                beats_r++;
                if (!seen) begin seen = 1; t_begin = cyc; end
                t_end = cyc;
                if (!r_act[id]) begin r_act[id] = 1; r_first[id] = cyc; r_cnt[id] = 0; r_ok[id] = 1; end
                r_cnt[id]++;
                if (intf.RRESP != 2'b00) r_ok[id] = 0;
                if (intf.RLAST) begin
                    r_act[id] = 0;
                    if (arq[id].size()) begin
                        automatic ar_t a = arq[id].pop_front();
                        if (r_ok[id] && r_cnt[id] == a.len && a.len <= MAXL) begin
                            rd_lat [a.len] += r_first[id] - a.t;
                            rd_brst[a.len] += cyc - r_first[id] + 1;
                            rd_tot [a.len] += cyc - a.t;
                            rd_n   [a.len]++;
                        end
                    end
                end
            end
            // AW
            if (intf.AWVALID && intf.AWREADY) begin
                aw_t nw;
                nw.t = cyc; nw.len = int'(intf.AWLEN) + 1; nw.id = int'(intf.AWID);
                awq.push_back(nw);
                pair_w();
            end
            // W
            if (intf.WVALID && intf.WREADY) begin
                beats_w++;
                if (!seen) begin seen = 1; t_begin = cyc; end
                t_end = cyc;
                if (!w_act) begin w_act = 1; w_first = cyc; w_cnt = 0; end
                w_cnt++;
                if (intf.WLAST) begin
                    wb_t nb;
                    w_act = 0;
                    nb.t0 = w_first; nb.t1 = cyc; nb.beats = w_cnt;
                    wq.push_back(nb);
                    pair_w();
                end
            end
            // B
            if (intf.BVALID && intf.BREADY) begin
                automatic int id = intf.BID;
                t_end = cyc;
                if (wpend[id].size()) begin
                    automatic wp_t p = wpend[id].pop_front();
                    if (p.ok && intf.BRESP == 2'b00 && p.len <= MAXL) begin
                        wr_resp[p.len] += cyc - p.t_wlast;
                        wr_brst[p.len] += p.brst;
                        wr_tot [p.len] += cyc - p.t_start;
                        wr_n   [p.len]++;
                    end
                end
            end
        end
        cyc++;
    end

    final begin
        real span, util;
        $display("");
        $display("==================================== PERFORMANCE (cycles of ACLK) ====================================");
        $display(" beats |  READ n  addr->data  eff(beat/cyc)  total |  WRITE n  eff(beat/cyc)  WLAST->B  total");
        $display("-------+--------------------------------------------+---------------------------------------------");
        for (int L = 1; L <= MAXL; L++) begin
            if (rd_n[L] == 0 && wr_n[L] == 0) continue;
            $display("  %3d  | %7d  %10.2f  %13.2f  %6.2f | %8d  %13.2f  %8.2f  %6.2f",
                L,
                rd_n[L],
                rd_n[L] ? real'(rd_lat[L]) / rd_n[L] : 0.0,
                rd_n[L] ? real'(L) * rd_n[L] / rd_brst[L] : 0.0,
                rd_n[L] ? real'(rd_tot[L]) / rd_n[L] : 0.0,
                wr_n[L],
                wr_n[L] ? real'(L) * wr_n[L] / wr_brst[L] : 0.0,
                wr_n[L] ? real'(wr_resp[L]) / wr_n[L] : 0.0,
                wr_n[L] ? real'(wr_tot[L]) / wr_n[L] : 0.0);
        end
        span = seen ? real'(t_end - t_begin + 1) : 1.0;
        util = (beats_r + beats_w) / span;
        $display("-------+--------------------------------------------+---------------------------------------------");
        $display(" sustained: %0d R beats + %0d W beats in %0.0f cycles = %0.3f beats/cycle", beats_r, beats_w, span, util);
        $display(" bandwidth: %0.1f MB/s at 100 MHz (DATA_WIDTH = %0d)", util * DATA_WIDTH / 8.0 * 100.0, DATA_WIDTH);
        $display("=======================================================================================================");
    end
endmodule
