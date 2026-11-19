`timescale 1ns / 1ps

// AXI interface between the class based testbench and top_module_main
interface axi_if (input logic ACLK);
    import config_pkg::*;

    logic                     ARST;

    // AW
    logic [ADDRESS_WIDTH-1:0] AWADDR;
    logic [BURST_LENGTH-1:0]  AWLEN;
    logic [BURST_TYPE-1:0]    AWBURST;
    logic                     AWVALID;
    logic [ID_WIDTH-1:0]      AWID;
    logic                     AWREADY;
    // W
    logic [DATA_WIDTH-1:0]    WDATA;
    logic                     WLAST;
    logic                     WVALID;
    logic                     WREADY;
    // B
    logic [ID_WIDTH-1:0]      BID;
    logic [1:0]               BRESP;
    logic                     BVALID;
    logic                     BREADY;
    // AR
    logic [ADDRESS_WIDTH-1:0] ARADDR;
    logic [ID_WIDTH-1:0]      ARID;
    logic [BURST_TYPE-1:0]    ARBURST;
    logic [BURST_LENGTH-1:0]  ARLEN;
    logic                     ARVALID;
    logic                     ARREADY;
    // R
    logic [DATA_WIDTH-1:0]    RDATA;
    logic [ID_WIDTH-1:0]      RID;
    logic [1:0]               RRESP;
    logic                     RLAST;
    logic                     RVALID;
    logic                     RREADY;

    // backdoor, served by the top module
    logic                     inj_stb = 1'b0;   // toggle: flip inj_mask bits of SRAM word inj_addr
    logic [ADDRESS_WIDTH-1:0] inj_addr;
    logic [CODE_WIDTH-1:0]    inj_mask;
    logic [ADDRESS_WIDTH-1:0] peek_addr = '0;   // SRAM word to look at
    logic [CODE_WIDTH-1:0]    peek_code;        // its stored codeword
    logic                     dut_busy;         // SRAM controller is not idle

    // idle accounting for the power tests: a cycle is idle when the controller clock enable
    // (AXI_SLAVE clk_controller, the ICG enable) is low, i.e. a cycle clock gating would remove.
    // Counted the same way whether CLOCK_GATING is 0 or 1.
    logic                     ctrl_clk_en;      // driven by the top module
    bit                       cnt_en = 1'b0;    // count only while the power test runs
    longint unsigned          cyc_total = 0;
    longint unsigned          cyc_idle  = 0;
    always @(posedge ACLK)
        if (cnt_en) begin
            cyc_total++;
            if (!ctrl_clk_en) cyc_idle++;
        end

    // driver: outputs change 1 ns after the edge, inputs are sampled just before it
    clocking drv_cb @(posedge ACLK);
        default input #1step output #1;
        output AWADDR, AWLEN, AWBURST, AWVALID, AWID;
        output WDATA, WLAST, WVALID;
        output BREADY;
        output ARADDR, ARID, ARBURST, ARLEN, ARVALID;
        output RREADY;
        input  AWREADY, WREADY, BID, BRESP, BVALID, ARREADY;
        input  RDATA, RID, RRESP, RLAST, RVALID;
        input  dut_busy;
    endclocking

    // monitor: samples everything just before each edge, a handshake is VALID && READY there
    clocking mon_cb @(posedge ACLK);
        default input #1step;
        input ARST;
        input AWADDR, AWLEN, AWBURST, AWVALID, AWID, AWREADY;
        input WDATA, WLAST, WVALID, WREADY;
        input BID, BRESP, BVALID, BREADY;
        input ARADDR, ARID, ARBURST, ARLEN, ARVALID, ARREADY;
        input RDATA, RID, RRESP, RLAST, RVALID, RREADY;
        input dut_busy;
    endclocking

endinterface
