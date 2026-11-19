`timescale 1ns / 1ps

package environment_pkg;
    import config_pkg::*;
    import axi_txn_pkg::*;
    import generator_pkg::*;
    import driver_pkg::*;
    import monitor_pkg::*;
    import scoreboard_pkg::*;

    // Environment: builds generator, driver, monitor and scoreboard, connects their mailboxes,
    // runs them, and waits until every generated transaction has been checked.

    class environment;
        virtual axi_if     vif;
        mailbox #(axi_txn) gen2drv;
        mailbox #(axi_txn) drv2scb;
        mailbox #(axi_txn) mon2scb;

        generator  gen;
        driver     drv;
        monitor    mon;
        scoreboard scb;

        function new(virtual axi_if vif);
            this.vif = vif;
            gen2drv = new(1);          // the generator stays one transaction ahead of the driver
            drv2scb = new();
            mon2scb = new();
            gen = new(gen2drv);
            drv = new(vif, gen2drv, drv2scb);
            mon = new(vif, mon2scb);
            scb = new(vif, drv2scb, mon2scb);
        endfunction

        task run();
            int total;
            drv.reset();
            total = gen.count();
            fork
                gen.run();
                drv.run();
                mon.run();
                scb.run();
            join_none
            wait (scb.n_txn == total);
            vif.cnt_en = 1'b0;                               // power test: end of the measured window
            repeat (50) @(vif.mon_cb);                       // a stray late response would show up here
            scb.final_checks(drv.w_beats_driven, mon.w_beats_seen, mon.pending(), mon.unexpected);
            disable fork;
        endtask
    endclass

endpackage
