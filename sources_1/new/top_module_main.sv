`timescale 1ns / 1ps

module top_module_main
import config_pkg::*;
(
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
    input  wire                      RREADY
);

    // ------------------------------------------------------------------
    // AXI_SLAVE <-> controller
    // ------------------------------------------------------------------
    wire                     ctrl_req;
    wire                     ctrl_rw;
    wire                     ctrl_bmode;
    wire [BURST_LENGTH:0]    ctrl_burst_len;
    wire [BURST_TYPE-1:0]    ctrl_burst_type;
    wire [ADDRESS_WIDTH-1:0] ctrl_addr;
    wire [DATA_WIDTH-1:0]    ctrl_wdata;        // AXI_SLAVE.data_in   -> ecc_encoder.data_in
    wire [DATA_WIDTH-1:0]    ctrl_rdata;        // ecc_decoder.data_out -> AXI_SLAVE.data_out
    wire                     ctrl_done;
    wire                     ctrl_op_complete;
    wire                     ctrl_busy;
    wire                     ctrl_data_valid;
    wire                     ctrl_rdata_valid;
    wire                     controller_clk;
    wire                     ctrl_illegal;
    wire                     ctrl_w_avail;
    wire                     ctrl_r_ready;
    wire                     ctrl_w_wait;       // controller waits for a W beat
    wire                     ctrl_w_timeout;    // W beat too late: end the write with SLVERR
    wire                     ctrl_w_last;       // WLAST of the W beat at the controller input

    // ------------------------------------------------------------------
    // ECC (SEC-DED) between AXI_SLAVE and controller
    // ------------------------------------------------------------------
    wire [CODE_WIDTH-1:0]    ecc_wcode;         // ecc_encoder.code_out -> controller.data_in
    wire [CODE_WIDTH-1:0]    ecc_rcode;         // controller.data_out  -> ecc_decoder.code_in
    wire [PARITY_WIDTH-1:0]  ecc_syndrome;
    wire                     ecc_corrected;     // single-bit error fixed, not reported on R, written back
    wire                     ecc_double;        // uncorrectable, the beat gets SLVERR
    wire [CODE_WIDTH-1:0]    ecc_scrub_code;    // corrected data re-encoded, written back by the controller

    // ------------------------------------------------------------------
    // controller <-> SRAM port 1
    // ------------------------------------------------------------------
    wire [ADDRESS_WIDTH-1:0] sram_addr;
    wire [CODE_WIDTH-1:0]    sram_wdata;        // codewords, data + parity
    wire [CODE_WIDTH-1:0]    sram_rdata;
    wire                     sram_wre;
    wire                     sram_oe;
    wire                     sram_ce;
    wire                     sram_status;

    // ------------------------------------------------------------------
    // AXI slave front end
    // ------------------------------------------------------------------
    AXI_SLAVE #(
        .ADDRESS_WIDTH (ADDRESS_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH),
        .BURST_LENGTH  (BURST_LENGTH),
        .ID_WIDTH      (ID_WIDTH),
        .BURST_TYPE    (BURST_TYPE),
        .W_TIMEOUT     (W_TIMEOUT),
        .CLOCK_GATING  (CLOCK_GATING)
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
        .controller_clk(controller_clk),
        .illegal     (ctrl_illegal),
        .w_avail     (ctrl_w_avail),
        .r_ready     (ctrl_r_ready),
        .ecc_err     (ecc_double),
        .w_wait      (ctrl_w_wait),
        .w_timeout   (ctrl_w_timeout),
        .w_last      (ctrl_w_last)
    );

    // ------------------------------------------------------------------
    // ECC encoder (write path) and decoder (read path)
    // ------------------------------------------------------------------
    ecc_encoder u_ecc_encoder (
        .data_in  (ctrl_wdata),
        .code_out (ecc_wcode)
    );

    ecc_decoder u_ecc_decoder (
        .code_in       (ecc_rcode),
        .data_out      (ctrl_rdata),
        .syndrome      (ecc_syndrome),
        .err_corrected (ecc_corrected),
        .err_double    (ecc_double)
    );

    // scrub: re-encode the corrected read data so a single-bit error is fixed in the SRAM too
    ecc_encoder u_ecc_scrub (
        .data_in  (ctrl_rdata),
        .code_out (ecc_scrub_code)
    );

    // ------------------------------------------------------------------
    // SRAM controller
    // ------------------------------------------------------------------
    controller #(
        .DATA_WIDTH    (CODE_WIDTH),        // the controller moves whole codewords
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

        .data_in      (ecc_wcode),
        .data_out     (ecc_rcode),
        .rdata_valid  (ctrl_rdata_valid),
        .illegal      (ctrl_illegal),
        .w_avail      (ctrl_w_avail),
        .r_ready      (ctrl_r_ready),
        .w_timeout    (ctrl_w_timeout),
        .w_wait       (ctrl_w_wait),
        .w_last       (ctrl_w_last),
        .ecc_single   (ecc_corrected),
        .scrub_data   (ecc_scrub_code)
    );

    // ------------------------------------------------------------------
    // Dual-port SRAM, CODE_WIDTH bits per word
    // ------------------------------------------------------------------
    spsram #(
        .DATA_WIDTH    (CODE_WIDTH),        // each word stores data + parity
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

        // port 2 : unused, read FSM removed for now
        .clk2    (1'b0),
        .rst2    (ARST),
        .oe2     (1'b0),
        .addr2   ({ADDRESS_WIDTH{1'b0}}),
        .rdata2  (),
        .status2 ()
    );

endmodule