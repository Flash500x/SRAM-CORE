`timescale 1ns / 1ps

package test_pkg;
    import config_pkg::*;
    import axi_txn_pkg::*;
    import environment_pkg::*;

    // Test: sets the knobs, runs the environment, prints the report.
    //   +NUM_TXNS=<n>   random transactions (default 5000; the directed and sweep phases add 112 more)
    //   +IDLE_PCT=<p>   power test instead: clean traffic with p% idle cycles (0, 50, 90, ... 0..99)
    //   +POWER_TXNS=<n> transactions in the power test (default 2000)
    // An idle cycle is one where the controller clock enable (the ICG enable) is low.

    class test;
        virtual axi_if vif;
        environment    env;

        function new(virtual axi_if vif);
            this.vif = vif;
            env = new(vif);
        endfunction

        task run();
            int n;
            if ($value$plusargs("IDLE_PCT=%d", n)) begin
                if (n < 0 || n > 99) $fatal(1, "[test] IDLE_PCT must be 0..99, got %0d", n);
                run_power(n);
                return;
            end
            if ($value$plusargs("NUM_TXNS=%d", n)) env.gen.num_random = n;
            $display("[test] %0d directed + %0d random + %0d sweep transactions, W_TIMEOUT = %0d cycles",
                     3 * 16 * 2, env.gen.num_random, MEM_DEPTH / 16, W_TIMEOUT);
            env.run();
            env.scb.report(0);
        endtask

        // power test: same clean traffic, only the idle share changes between runs
        task run_power(int pct);
            int n;
            real meas;
            env.gen.idle_pct = pct;
            env.drv.idle_pct = pct;
            env.scb.need_all_scenarios = 0;
            if ($value$plusargs("POWER_TXNS=%d", n)) env.gen.num_power = n;
            $display("[test] POWER TEST: %0d clean transactions, target idle %0d%%, CLOCK_GATING = %0d",
                     env.gen.num_power, pct, CLOCK_GATING);
            env.run();
            meas = vif.cyc_total ? 100.0 * vif.cyc_idle / vif.cyc_total : 0.0;
            $display("[test] POWER TEST idle: target %0d%%, measured %0.1f%% (%0d idle of %0d cycles, %0.1f us)",
                     pct, meas, vif.cyc_idle, vif.cyc_total, vif.cyc_total * 0.01);
            if (pct == 0)
                $display("[test] note: 0%% is back to back traffic; the measured idle left is the handshake gap between transactions");
            env.scb.report(0);
        endtask
    endclass

endpackage
