`timescale 1ns / 1ps

module top_module_main #(
    parameter ADDRESS_WIDTH = 8,
    parameter DATA_WIDTH    = 8,
    parameter BURST_LENGTH  = 4,
    parameter ID_WIDTH      = 2,
    parameter BURST_TYPE    = 2
)(
    input  wire                      ACLK,
    input  wire                      ARST,      // active low, shared by every block

    // AW - write address channel
    input  wire [ADDRESS_WIDTH-1:0]  AWADDR,
    input  wire [BURST_LENGTH-1:0]   AWLEN,
    input  wire [BURST_TYPE-1:0]     AWBURST,
    input  wire                      AWVALID,
    input  wire [ID_WIDTH-1:0]       AWID,
    output wire                      AWREADY,

    // W - write data channel
    input  wire [DATA_WIDTH-1:0]     WDATA,
    input  wire                      WLAST,
    input  wire                      WVALID,
    output wire                      WREADY,

    // B - write response channel
    output wire [ID_WIDTH-1:0]       BID,
    output wire [1:0]                BRESP,
    output wire                      BVALID,
    input  wire                      BREADY,

    // AR - read address channel
    input  wire [ADDRESS_WIDTH-1:0]  ARADDR,
    input  wire [ID_WIDTH-1:0]       ARID,
    input  wire [BURST_TYPE-1:0]     ARBURST,
    input  wire [BURST_LENGTH-1:0]   ARLEN,
    input  wire                      ARVALID,
    output wire                      ARREADY,

    // R - read data channel
    output wire [DATA_WIDTH-1:0]     RDATA,
    output wire [ID_WIDTH-1:0]       RID,
    output wire [1:0]                RRESP,
    output wire                      RLAST,
    output wire                      RVALID,
    input  wire                      RREADY,

    // direct read port (rd_fsm -> SRAM port 2)
    input  wire                      rd_req,
    input  wire [ADDRESS_WIDTH-1:0]  rd_addr,
    output wire [DATA_WIDTH-1:0]     rd_data,
    output wire                      rd_done,
    output wire                      rd_busy
);

    // ------------------------------------------------------------------
    // AXI_SLAVE <-> controller
    // ------------------------------------------------------------------
    wire                     ctrl_req;
    wire                     ctrl_rw;
    wire                     ctrl_bmode;
    wire [3:0]               ctrl_burst_len;
    wire [BURST_TYPE-1:0]    ctrl_burst_type;
    wire [ADDRESS_WIDTH-1:0] ctrl_addr;
    wire [DATA_WIDTH-1:0]    ctrl_wdata;        // AXI_SLAVE.data_in  -> controller.data_in
    wire [DATA_WIDTH-1:0]    ctrl_rdata;        // controller.data_out -> AXI_SLAVE.data_out
    wire                     ctrl_done;
    wire                     ctrl_op_complete;
    wire                     ctrl_busy;
    wire                     ctrl_data_valid;
    wire                     ctrl_rdata_valid;
    wire                     controller_clk;

    // ------------------------------------------------------------------
    // controller <-> SRAM port 1
    // ------------------------------------------------------------------
    wire [ADDRESS_WIDTH-1:0] sram_addr;
    wire [DATA_WIDTH-1:0]    sram_wdata;
    wire [DATA_WIDTH-1:0]    sram_rdata;
    wire                     sram_wre;
    wire                     sram_oe;
    wire                     sram_ce;
    wire                     sram_status;

    // ------------------------------------------------------------------
    // rd_fsm <-> SRAM port 2
    // ------------------------------------------------------------------
    wire                     rd_oe2;
    wire [ADDRESS_WIDTH-1:0] rd_addr2;
    wire [DATA_WIDTH-1:0]    rd_rdata2;
    wire                     sram_status2;

    // ------------------------------------------------------------------
    // AXI slave front end
    // ------------------------------------------------------------------
    AXI_SLAVE #(
        .ADDRESS_WIDTH (ADDRESS_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH),
        .BURST_LENGTH  (BURST_LENGTH),
        .ID_WIDTH      (ID_WIDTH),
        .BURST_TYPE    (BURST_TYPE)
    ) u_axi_slave (
        .ACLK        (ACLK),
        .ARST        (ARST),

        .AWADDR      (AWADDR),
        .AWLEN       (AWLEN),
        .AWBURST     (AWBURST),
        .AWVALID     (AWVALID),
        .AWID        (AWID),
        .AWREADY     (AWREADY),

        .WDATA       (WDATA),
        .WLAST       (WLAST),
        .WVALID      (WVALID),
        .WREADY      (WREADY),

        .BID         (BID),
        .BRESP       (BRESP),
        .BVALID      (BVALID),
        .BREADY      (BREADY),

        .ARADDR      (ARADDR),
        .ARID        (ARID),
        .ARBURST     (ARBURST),
        .ARLEN       (ARLEN),
        .ARVALID     (ARVALID),
        .ARREADY     (ARREADY),

        .RDATA       (RDATA),
        .RID         (RID),
        .RRESP       (RRESP),
        .RLAST       (RLAST),
        .RVALID      (RVALID),
        .RREADY      (RREADY),

        // controller channels
        .req         (ctrl_req),
        .rw          (ctrl_rw),
        .clk         (),                    // never driven inside AXI_SLAVE
        .abort       (),                    // never driven inside AXI_SLAVE
        .bmode       (ctrl_bmode),
        .burst_len   (ctrl_burst_len),
        .burst_type  (ctrl_burst_type),
        .addr        (ctrl_addr),
        .data_in     (ctrl_wdata),
        .done        (ctrl_done),
        .op_complete (ctrl_op_complete),
        .busy        (ctrl_busy),
        .data_out    (ctrl_rdata),
        .data_valid  (ctrl_data_valid),
        .rdata_valid (ctrl_rdata_valid),
        .controller_clk(controller_clk)
    );

    // ------------------------------------------------------------------
    // SRAM controller
    // ------------------------------------------------------------------
    controller #(
        .DATA_WIDTH    (DATA_WIDTH),
        .ADDRESS_WIDTH (ADDRESS_WIDTH),
        .BURST_LENGTH  (BURST_LENGTH),
        .BURST_TYPE    (BURST_TYPE)
    ) u_controller (
        .req          (ctrl_req),
        .rw           (ctrl_rw),
        .clk          (controller_clk),
        .rst          (ARST),
        .bmode        (ctrl_bmode),
        .abort        (1'b0),
        .ram_stat     (sram_status),
        .burst_len    (ctrl_burst_len),
        .burst_type   (ctrl_burst_type),

        .data_in_ram  (sram_wdata),
        .data_out_ram (sram_rdata),
        .addr         (ctrl_addr),
        .sram_addr    (sram_addr),

        .wre          (sram_wre),
        .oe           (sram_oe),
        .ce           (sram_ce),
                       // unused by spsram
        .op_complete  (ctrl_op_complete),
        .data_valid   (ctrl_data_valid),
        .busy         (ctrl_busy),
        .done         (ctrl_done),

        .data_in      (ctrl_wdata),
        .data_out     (ctrl_rdata),
        .rdata_valid  (ctrl_rdata_valid)
    );

    // ------------------------------------------------------------------
    // Dual-port SRAM
    // ------------------------------------------------------------------
    spsram #(
        .DATA_WIDTH    (DATA_WIDTH),
        .ADDRESS_WIDTH (ADDRESS_WIDTH)
    ) u_spsram (
        // port 1 : controller
        .clk     (controller_clk),
        .rst     (ARST),
        .wre     (sram_wre),
        .oe      (sram_oe),
        .ce      (sram_ce),
        .addr    (sram_addr),
        .wdata   (sram_wdata),
        .rdata   (sram_rdata),
        .status  (sram_status),

        // port 2 : rd_fsm (read only)
        .clk2    (ACLK),
        .rst2    (ARST),
        .oe2     (rd_oe2),
        .addr2   (rd_addr2),
        .rdata2  (rd_rdata2),
        .status2 (sram_status2)
    );

    // ------------------------------------------------------------------
    // Direct read FSM on SRAM port 2
    // ------------------------------------------------------------------
    rd_fsm #(
        .ADDRESS_WIDTH (ADDRESS_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH)
    ) u_rd_fsm (
        .clk       (ACLK),
        .rst       (ARST),
        .req       (rd_req),
        .status2   (sram_status2),
        .addr      (rd_addr),
        .rdata     (rd_data),
        .rdata_ram (rd_rdata2),
        .ram_addr  (rd_addr2),
        .oe        (rd_oe2),
        .done      (rd_done),
        .busy      (rd_busy)
    );

endmodule