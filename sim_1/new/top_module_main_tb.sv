`timescale 1ns / 1ps

// Top of the class based testbench: clock, interface, DUT, backdoor hooks, and the test
module top_module_main_tb;
    import config_pkg::*;
    import test_pkg::*;

    logic ACLK = 1'b0;
    always #5 ACLK = ~ACLK;                 // 100 MHz

    axi_if intf (ACLK);

    top_module_main dut (
        .ACLK    (ACLK),
        .ARST    (intf.ARST),
        .AWADDR  (intf.AWADDR),
        .AWLEN   (intf.AWLEN),
        .AWBURST (intf.AWBURST),
        .AWVALID (intf.AWVALID),
        .AWID    (intf.AWID),
        .AWREADY (intf.AWREADY),
        .WDATA   (intf.WDATA),
        .WLAST   (intf.WLAST),
        .WVALID  (intf.WVALID),
        .WREADY  (intf.WREADY),
        .BID     (intf.BID),
        .BRESP   (intf.BRESP),
        .BVALID  (intf.BVALID),
        .BREADY  (intf.BREADY),
        .ARADDR  (intf.ARADDR),
        .ARID    (intf.ARID),
        .ARBURST (intf.ARBURST),
        .ARLEN   (intf.ARLEN),
        .ARVALID (intf.ARVALID),
        .ARREADY (intf.ARREADY),
        .RDATA   (intf.RDATA),
        .RID     (intf.RID),
        .RRESP   (intf.RRESP),
        .RLAST   (intf.RLAST),
        .RVALID  (intf.RVALID),
        .RREADY  (intf.RREADY)
    );
   perf_mon u_perf (.intf(intf));
    // backdoor: ECC fault injection and SRAM word peek, used by the driver and scoreboard
    always @(intf.inj_stb)
        if (!$isunknown(intf.inj_addr))
            dut.u_spsram.mem[intf.inj_addr] = dut.u_spsram.mem[intf.inj_addr] ^ intf.inj_mask;
    assign intf.peek_code = dut.u_spsram.mem[intf.peek_addr];
    assign intf.dut_busy  = dut.u_controller.busy;
    assign intf.ctrl_clk_en = dut.u_axi_slave.clk_controller;   // ICG enable, idle accounting

    initial begin
        test t;
        t = new(intf);
        t.run();
        $finish;
    end

    // safety net, far longer than 5000 transactions need
    initial begin
        #50ms;
        $display("[tb] TIMEOUT: simulation did not finish");
        $finish;
    end
endmodule
