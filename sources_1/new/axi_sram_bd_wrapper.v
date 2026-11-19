`timescale 1ns / 1ps
// axi_sram_bd_wrapper : plain-Verilog shell around top_module_main so it can be added to a
// Vivado Block Design (Add Module). IP Integrator cannot take a SystemVerilog top whose port
// widths come from a package, and it only recognises an AXI port when the names follow the
// s_axi_* convention. This file fixes both.
//
// REQUIREMENT: set DATA_WIDTH = 32 in config_pkg.sv (SmartConnect needs >= 32-bit data).
//              The widths below must match config_pkg.
//
// Notes
//  * AXI addresses are BYTE addresses; the controller is WORD addressed, so the word address is
//    s_axi_axaddr[WORD_AW+1:2]. Use 4-byte aligned accesses (Xil_Out32 / Xil_In32) only.
//  * WSTRB is ignored: every write stores the full 32-bit word. Don't do byte/halfword writes.
//  * AXI4 AxLEN is 8 bits; the controller takes 4 (bursts up to 16 beats). Longer bursts are
//    not supported.
//  * AxSIZE / AxLOCK / AxCACHE / AxPROT / AxQOS are accepted and ignored.
//  * The 4 KB window aliases the 1 KB memory (256 words x 4 bytes).
module axi_sram_bd_wrapper #(
    parameter WORD_AW = 8,     // = config_pkg::ADDRESS_WIDTH
    parameter DW      = 32,    // = config_pkg::DATA_WIDTH
    parameter LW      = 4,     // = config_pkg::BURST_LENGTH
    parameter IDW     = 2      // = config_pkg::ID_WIDTH
)(
    input  wire             s_axi_aclk,
    input  wire             s_axi_aresetn,

    input  wire [11:0]      s_axi_awaddr,
    input  wire [7:0]       s_axi_awlen,
    input  wire [2:0]       s_axi_awsize,
    input  wire [1:0]       s_axi_awburst,
    input  wire [IDW-1:0]   s_axi_awid,
    input  wire             s_axi_awlock,
    input  wire [3:0]       s_axi_awcache,
    input  wire [2:0]       s_axi_awprot,
    input  wire             s_axi_awvalid,
    output wire             s_axi_awready,

    input  wire [DW-1:0]    s_axi_wdata,
    input  wire [DW/8-1:0]  s_axi_wstrb,
    input  wire             s_axi_wlast,
    input  wire             s_axi_wvalid,
    output wire             s_axi_wready,

    output wire [IDW-1:0]   s_axi_bid,
    output wire [1:0]       s_axi_bresp,
    output wire             s_axi_bvalid,
    input  wire             s_axi_bready,

    input  wire [11:0]      s_axi_araddr,
    input  wire [7:0]       s_axi_arlen,
    input  wire [2:0]       s_axi_arsize,
    input  wire [1:0]       s_axi_arburst,
    input  wire [IDW-1:0]   s_axi_arid,
    input  wire             s_axi_arlock,
    input  wire [3:0]       s_axi_arcache,
    input  wire [2:0]       s_axi_arprot,
    input  wire             s_axi_arvalid,
    output wire             s_axi_arready,

    output wire [DW-1:0]    s_axi_rdata,
    output wire [IDW-1:0]   s_axi_rid,
    output wire [1:0]       s_axi_rresp,
    output wire             s_axi_rlast,
    output wire             s_axi_rvalid,
    input  wire             s_axi_rready
);

    top_module_main u_core (
        .ACLK    (s_axi_aclk),
        .ARST    (s_axi_aresetn),

        .AWADDR  (s_axi_awaddr[WORD_AW+1:2]),
        .AWLEN   (s_axi_awlen[LW-1:0]),
        .AWBURST (s_axi_awburst),
        .AWVALID (s_axi_awvalid),
        .AWID    (s_axi_awid),
        .AWREADY (s_axi_awready),

        .WDATA   (s_axi_wdata),
        .WLAST   (s_axi_wlast),
        .WVALID  (s_axi_wvalid),
        .WREADY  (s_axi_wready),

        .BID     (s_axi_bid),
        .BRESP   (s_axi_bresp),
        .BVALID  (s_axi_bvalid),
        .BREADY  (s_axi_bready),

        .ARADDR  (s_axi_araddr[WORD_AW+1:2]),
        .ARID    (s_axi_arid),
        .ARBURST (s_axi_arburst),
        .ARLEN   (s_axi_arlen[LW-1:0]),
        .ARVALID (s_axi_arvalid),
        .ARREADY (s_axi_arready),

        .RDATA   (s_axi_rdata),
        .RID     (s_axi_rid),
        .RRESP   (s_axi_rresp),
        .RLAST   (s_axi_rlast),
        .RVALID  (s_axi_rvalid),
        .RREADY  (s_axi_rready)
    );

endmodule
