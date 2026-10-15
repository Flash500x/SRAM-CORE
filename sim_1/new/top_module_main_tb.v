`timescale 1ns / 1ps

module top_module_main_tb;

    parameter ADDRESS_WIDTH = 8;
    parameter DATA_WIDTH    = 8;
    parameter BURST_LENGTH  = 4;
    parameter ID_WIDTH      = 2;
    parameter BURST_TYPE    = 2;

    //==================================================
    // CLOCK / RESET
    //==================================================
    reg ACLK;
    reg ARST;

    //==================================================
    // AW CHANNEL
    //==================================================
    reg  [ADDRESS_WIDTH-1:0] AWADDR;
    reg  [BURST_LENGTH-1:0]  AWLEN;
    reg  [BURST_TYPE-1:0]    AWBURST;
    reg                      AWVALID;
    reg  [ID_WIDTH-1:0]      AWID;
    wire                     AWREADY;

    //==================================================
    // W CHANNEL
    //==================================================
    reg  [DATA_WIDTH-1:0] WDATA;
    reg                   WLAST;
    reg                   WVALID;
    wire                  WREADY;

    //==================================================
    // B CHANNEL
    //==================================================
    wire [ID_WIDTH-1:0] BID;
    wire [1:0]          BRESP;
    wire                BVALID;
    reg                 BREADY;

    //==================================================
    // AR CHANNEL
    //==================================================
    reg  [ADDRESS_WIDTH-1:0] ARADDR;
    reg  [ID_WIDTH-1:0]      ARID;
    reg  [BURST_TYPE-1:0]    ARBURST;
    reg  [BURST_LENGTH-1:0]  ARLEN;
    reg                      ARVALID;
    wire                     ARREADY;

    //==================================================
    // R CHANNEL
    //==================================================
    wire [DATA_WIDTH-1:0] RDATA;
    wire [ID_WIDTH-1:0]   RID;
    wire [1:0]            RRESP;
    wire                  RLAST;
    wire                  RVALID;
    reg                   RREADY;

    //==================================================
    // CLOCK
    //==================================================
    always #5 ACLK = ~ACLK;


    //==================================================
    // TOP MODULE (AXI_SLAVE + controller + SRAM + rd_fsm)
    //==================================================
    top_module_main #(
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BURST_LENGTH(BURST_LENGTH),
        .ID_WIDTH(ID_WIDTH),
        .BURST_TYPE(BURST_TYPE)
    ) dut (

        .ACLK(ACLK),
        .ARST(ARST),

        // AW
        .AWADDR(AWADDR),
        .AWLEN(AWLEN),
        .AWBURST(AWBURST),
        .AWVALID(AWVALID),
        .AWID(AWID),
        .AWREADY(AWREADY),

        // W
        .WDATA(WDATA),
        .WLAST(WLAST),
        .WVALID(WVALID),
        .WREADY(WREADY),

        // B
        .BID(BID),
        .BRESP(BRESP),
        .BVALID(BVALID),
        .BREADY(BREADY),

        // AR
        .ARADDR(ARADDR),
        .ARID(ARID),
        .ARBURST(ARBURST),
        .ARLEN(ARLEN),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),

        // R
        .RDATA(RDATA),
        .RID(RID),
        .RRESP(RRESP),
        .RLAST(RLAST),
        .RVALID(RVALID),
        .RREADY(RREADY),

        // direct read port (unused here)
        .rd_req(1'b0),
        .rd_addr(8'b0),
        .rd_data(),
        .rd_done(),
        .rd_busy()
    );


    //==================================================
    // TEST
    //==================================================
    initial begin

    //================================================
    // INITIAL VALUES
    //================================================
    ACLK = 0;
    ARST = 0;

    AWADDR  = 0;
    AWLEN   = 0;
    AWBURST = 0;
    AWVALID = 0;
    AWID    = 0;

    WDATA   = 0;
    WLAST   = 0;
    WVALID  = 0;

    BREADY  = 0;

    ARADDR  = 0;
    ARID    = 0;
    ARBURST = 0;
    ARLEN   = 0;
    ARVALID = 0;

    RREADY  = 0;


    //================================================
    // RESET
    //================================================
    $display("the current time is %0t",$time);
    #20;
    ARST = 1;

    #10;


    //================================================
    // WRITE 1
    // ADDR = 0x01
    // DATA = A1
    //================================================
    $display("the current time write 1 is %0t",$time);
    AWADDR  = 8'h01;
    AWLEN   = 4'd0;
    AWBURST = 2'b01;
    AWID    = 2'b00;
    AWVALID = 1'b1;

    WDATA   = 8'hA1;
    WLAST   = 1'b1;
    WVALID  = 1'b1;

    #10;
    BREADY = 1'b1;

    //================================================
    // WRITE 2
    // ADDR = 0x02
    // DATA = A2
    //================================================
    $display("the current time is %0t",$time);
    AWADDR  = 8'h02;
    AWLEN   = 4'd0;
    AWBURST = 2'b01;
    AWID    = 2'b01;
    AWVALID = 1'b1;

    WDATA   = 8'hA2;
    WLAST   = 1'b1;
    WVALID  = 1'b1;

    #10;
    $display("the current time is %0t",$time);

    //================================================
    // WRITE 3
    // ADDR = 0x03
    // DATA = A3
    //================================================
    $display("the current time is %0t",$time);
    AWADDR  = 8'h03;
    AWLEN   = 4'd0;
    AWBURST = 2'b01;
    AWID    = 2'b10;
    AWVALID = 1'b1;

    WDATA   = 8'hA3;
    WLAST   = 1'b1;
    WVALID  = 1'b1;
    $display("the current time is %0t",$time);
    #10;

    if(dut.ctrl_done)
        $display("the current time write 1 is %0t",$time);
    //================================================
    // END SINGLE WRITES
    //================================================

    AWVALID = 1'b0;
    WVALID  = 1'b0;
    WLAST   = 1'b0;

    AWADDR  = 8'h00;
    WDATA   = 8'h00;

    #50;
    BREADY = 1'b0;

    //================================================
    // BURST WRITE
    // START ADDRESS = 0x10
    // 4 BEATS
    //================================================
    $display("the current time is %0t",$time);
    AWADDR  = 8'hfe;
    AWLEN   = 4'd3;       // 4 beats
    AWBURST = 2'b01;      // INCR
    AWID    = 2'b11;
    AWVALID = 1'b1;

    //================================================
    // BURST BEAT 1
    // 0x10 = B1
    //================================================

    WDATA  = 8'hB1;
    WLAST  = 1'b0;
    WVALID = 1'b1;

    #10;

    AWVALID = 1'b0;       // one AW entry only: drop AWVALID after its first clock edge


    //================================================
    // BURST BEAT 2
    // 0x11 = B2
    //================================================

    WDATA  = 8'hB2;
    WLAST  = 1'b0;
    WVALID = 1'b1;

    #10;


    //================================================
    // BURST BEAT 3
    // 0x12 = B3
    //================================================

    WDATA  = 8'hB3;
    WLAST  = 1'b0;
    WVALID = 1'b1;

    #10;


    //================================================
    // BURST BEAT 4
    // 0x13 = B4
    //================================================
    WDATA  = 8'hB4;
    WLAST  = 1'b1;
    WVALID = 1'b1;
    BREADY = 1'b1;
    #30;


    //================================================
    // END BURST
    //================================================

    AWVALID = 1'b0;
    WVALID  = 1'b0;
    WLAST   = 1'b0;

    AWADDR  = 8'h00;
    WDATA   = 8'h00;
    #200;
    $display("the current time is %0t",$time);
    //================================================
    // READ 3
    // ADDR = 0x03
    //================================================
    $display("the current time is %0t",$time);
    ARADDR  = 8'h03;
    ARLEN   = 4'd0;
    ARBURST = 2'b01;
    ARID    = 2'b10;
    ARVALID = 1'b1;
    BREADY  = 1'b0;
    #10;
    ARVALID = 1'b0;
    $display("the current time is %0t",$time);
    #100;
    //================================================
    // BURST READ
    // START ADDRESS = 0x10
    // 4 BEATS
    // EXPECTED:
    // 0x10 = B1
    // 0x11 = B2
    // 0x12 = B3
    // 0x13 = B4
    //================================================
    $display("the current time is %0t",$time);
    ARADDR  = 8'hfe;
    ARLEN   = 4'd3;       // 4 beats
    ARBURST = 2'b00;      // INCR
    ARID    = 2'b11;
    ARVALID = 1'b1;
    RREADY  = 1'b1;

    #10;

    ARVALID = 1'b0;

    #200;
    $display("the current time is %0t",$time);

    //================================================
    // FINISH
    //================================================

    $display("========================================");
    $display("ALL WRITES COMPLETE");
    $display("0x01 = A1");
    $display("0x02 = A2");
    $display("0x03 = A3");
    $display("BURST:");
    $display("0x10 = B1");
    $display("0x11 = B2");
    $display("0x12 = B3");
    $display("0x13 = B4");
    $display("========================================");

    $finish;

end
endmodule