`timescale 1ns / 1ps

module axi_tb();

localparam ADDRESS_WIDTH = 8;
localparam DATA_WIDTH    = 8;
localparam BURST_LENGTH  = 3;

//====================================================
// CLOCK / RESET
//====================================================
reg ACLK;
reg ARST;

//====================================================
// AXI WRITE ADDRESS CHANNEL
//====================================================
reg  [ADDRESS_WIDTH-1:0] AWADDR;
reg  [BURST_LENGTH-1:0]  AWLEN;
reg  [1:0]               AWBURST;
reg                      AWVALID;
reg  [1:0]               AWID;
wire                     AWREADY;

//====================================================
// AXI WRITE DATA CHANNEL
//====================================================
reg  [DATA_WIDTH-1:0] WDATA;
reg                   WLAST;
reg                   WVALID;
wire                  WREADY;

//====================================================
// AXI WRITE RESPONSE CHANNEL
//====================================================
wire [1:0] BID;
wire       BRESP;
wire       BVALID;
reg        BREADY;

//====================================================
// AXI READ ADDRESS CHANNEL
//====================================================
reg  [ADDRESS_WIDTH-1:0] ARADDR;
reg  [1:0]               ARID;
reg  [1:0]               ARBURST;
reg  [BURST_LENGTH-1:0]  ARLEN;
reg                      ARVALID;
wire                     ARREADY;

//====================================================
// AXI READ DATA CHANNEL
//====================================================
wire [DATA_WIDTH-1:0] RDATA;
wire                  RRESP;
wire                  RLAST;
wire                  RVALID;
reg                   RREADY;

//====================================================
// SRAM CONTROLLER ADAPTER
//====================================================
wire [ADDRESS_WIDTH-1:0] addr;
wire [DATA_WIDTH-1:0]    data;
wire                     req;
wire                     bmode;
wire                     abort;
wire                     rw;
wire [BURST_LENGTH-1:0]  burst_len;

wire done;


//====================================================
// SRAM CONTROLLER
//====================================================
controller uut (
    .clk(ACLK),
    .rst(ARST),
    .req(req),
    .rw(rw),
    .bmode(bmode),
    .abort(abort),
    .burst_len(burst_len),
    .addr(addr),
    .data_cn_in_out(data),
    .done(done)
);


//====================================================
// AXI SLAVE
//====================================================
AXI_SLAVE #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .BURST_LENGTH(BURST_LENGTH)
) dut (

    .ACLK(ACLK),
    .ARST(ARST),

    // AW - Write Address Channel
    .AWADDR(AWADDR),
    .AWLEN(AWLEN),
    .AWBURST(AWBURST),
    .AWVALID(AWVALID),
    .AWID(AWID),
    .AWREADY(AWREADY),

    // W - Write Data Channel
    .WDATA(WDATA),
    .WLAST(WLAST),
    .WVALID(WVALID),
    .WREADY(WREADY),

    // B - Write Response Channel
    .BID(BID),
    .BRESP(BRESP),
    .BVALID(BVALID),
    .BREADY(BREADY),

    // AR - Read Address Channel
    .ARADDR(ARADDR),
    .ARID(ARID),
    .ARBURST(ARBURST),
    .ARLEN(ARLEN),
    .ARVALID(ARVALID),
    .ARREADY(ARREADY),

    // R - Read Data Channel
    .RDATA(RDATA),
    .RRESP(RRESP),
    .RLAST(RLAST),
    .RVALID(RVALID),
    .RREADY(RREADY),

    // SRAM Controller Adapter
    .addr(addr),
    .data(data),
    .req(req),
    .bmode(bmode),
    .abort(abort),
    .rw(rw),
    .burst_len(burst_len),

    .done(done)
);


//====================================================
// CLOCK
//====================================================
always #5 ACLK = ~ACLK;


//====================================================
// TEST SEQUENCE
//====================================================
initial begin

    //================================================
    // INITIALIZATION
    //================================================
    ACLK    = 1'b0;
    ARST    = 1'b0;

    // Write address
    AWADDR  = 8'b0;
    AWLEN   = 3'b000;
    AWBURST = 2'b00;
    AWVALID = 1'b0;
    AWID    = 2'b00;

    // Write data
    WDATA   = 8'b0;
    WLAST   = 1'b0;
    WVALID  = 1'b0;

    // Write response
    BREADY  = 1'b0;

    // Read address
    ARADDR  = 8'b0;
    ARLEN   = 3'b000;
    ARBURST = 2'b00;
    ARID    = 2'b00;
    ARVALID = 1'b0;

    // Read data
    RREADY  = 1'b0;


    //================================================
    // RESET
    //================================================
    #10;
    ARST = 1'b1;


    //================================================
    // WRITE TRANSACTION
    //================================================

    // Write address
    #5;

    AWADDR  = 8'b0000_0001;
    AWLEN   = 3'b000;       // Single beat
    AWBURST = 2'b01;        // INCR
    AWVALID = 1'b1;
    AWID    = 2'b01;


    // Wait for AW handshake
    #5;

    AWVALID = 1'b0;


    // Write data
    WDATA  = 8'b0000_0101;
    WVALID = 1'b1;
    WLAST  = 1'b1;


    // Write response ready
    BREADY = 1'b1;


    // Wait for SRAM operation
    #40;


    // End write transaction
    WVALID = 1'b0;
    WLAST   = 1'b0;
    BREADY  = 1'b0;


    //================================================
    // READ TRANSACTION
    //================================================

    #10;

    // Read address
    ARADDR  = 8'b0000_0001;
    ARLEN   = 3'b000;       // Single beat
    ARBURST = 2'b01;        // INCR
    ARID    = 2'b01;
    ARVALID = 1'b1;


    // Wait for AR handshake
    #5;

    ARVALID = 1'b0;


    // Master ready to accept read data
    RREADY = 1'b1;


    // Wait for SRAM read + R response
    #40;


    // End read transaction
    RREADY = 1'b0;


    //================================================
    // FINISH
    //================================================
    #20;

    $finish;

end

endmodule