`timescale 1ns / 1ps

module axi_tb;

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
    reg  [ID_WIDTH-1:0]     ARID;
    reg  [BURST_TYPE-1:0]   ARBURST;
    reg  [BURST_LENGTH-1:0] ARLEN;
    reg                     ARVALID;
    wire                    ARREADY;

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
    // CONTROLLER INTERFACE
    //==================================================
    wire req;
    wire rw;
    wire clk;
    wire bmode;
    wire abort;

    wire [3:0] burst_len;
    wire [1:0] burst_type;
    wire [ADDRESS_WIDTH-1:0] addr;
    wire [DATA_WIDTH-1:0] data_in;

    wire done;
    wire op_complete;
    wire busy;
    wire data_valid;
    wire [DATA_WIDTH-1:0] data_out;


    //==================================================
    // CLOCK
    //==================================================
    always #5 ACLK = ~ACLK;


    //==================================================
    // AXI SLAVE
    //==================================================
    AXI_SLAVE #(
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BURST_LENGTH(BURST_LENGTH),
        .ID_WIDTH(ID_WIDTH),
        .BURST_TYPE(BURST_TYPE)
    ) axi_slave (

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

        // Controller
        .req(req),
        .rw(rw),
        .clk(clk),
        .bmode(bmode),
        .abort(abort),
        .burst_len(burst_len),
        .burst_type(burst_type),
        .addr(addr),
        .data_in(data_in),

        .done(done),
        .op_complete(op_complete),
        .busy(busy),
        .data_out(data_out),
        .data_valid(data_valid)
    );


    //==================================================
    // TOP MODULE
    //==================================================
    top_module #(
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) top (

        .req(req),
        .rw(rw),
        .clk(ACLK),
        .rst(ARST),
        .rst2(ARST),

        .bmode(bmode),
        .abort(abort),

        .burst_len(burst_len),
        .burst_type(burst_type),

        .addr(addr),

        .done(done),
        .op_complete(op_complete),
        .busy(busy),
        .data_valid(data_valid),

        .data_in(data_in),
        .data_out(data_out),

        .clk2(ACLK),
        .req2(1'b0),
        .addr2(8'b0),

        .rdata2(),
        .done2(),
        .busy2()
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

        #20;
        ARST = 1;

        #10;


        //================================================
        // NORMAL WRITE 1
        // 20 = A1
        //================================================

        AWADDR  = 8'h20;
        AWLEN   = 4'd0;
        AWBURST = 2'b01;
        AWID    = 2'b00;
        AWVALID = 1'b1;

        #10;
        AWVALID = 1'b0;

        WDATA  = 8'hA1;
        WLAST  = 1'b1;
        WVALID = 1'b1;

        #10;
        WVALID = 1'b0;

        #30;


        //================================================
        // NORMAL WRITE 2
        // 24 = A2
        //================================================

        AWADDR  = 8'h24;
        AWLEN   = 4'd0;
        AWBURST = 2'b01;
        AWID    = 2'b01;
        AWVALID = 1'b1;

        #10;
        AWVALID = 1'b0;

        WDATA  = 8'hA2;
        WLAST  = 1'b1;
        WVALID = 1'b1;

        #10;
        WVALID = 1'b0;

        #30;


        //================================================
        // NORMAL WRITE 3
        // 28 = A3
        //================================================

        AWADDR  = 8'h28;
        AWLEN   = 4'd0;
        AWBURST = 2'b01;
        AWID    = 2'b10;
        AWVALID = 1'b1;

        #10;
        AWVALID = 1'b0;

        WDATA  = 8'hA3;
        WLAST  = 1'b1;
        WVALID = 1'b1;

        #10;
        WVALID = 1'b0;

        #30;


        //================================================
        // FINISH
        //================================================

        #50;

        $display("========================================");
        $display("ALL THREE NORMAL WRITES COMPLETE");
        $display("========================================");

        $finish;

    end

endmodule