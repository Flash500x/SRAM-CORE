`timescale 1ns / 1ps


module rdwrfsmsim(

    );
    parameter ADDRESS_WIDTH = 8;
    parameter DATA_WIDTH = 9;
    reg clk,req,rw,rst;
    reg [ADDRESS_WIDTH-1:0]addr;
    wire [DATA_WIDTH-1:0]data;
    wire [DATA_WIDTH-2:0]rdata;
    reg [DATA_WIDTH-2:0]wdata;//data to be written when tested.
    wire [DATA_WIDTH-2:0]ram_addr;
    wire oe,ce,wre,error_flag,busy,done,write_done_ram;    
    wr_rd_fsm #(
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .DATA_WIDTH(DATA_WIDTH-1)
    )uut(
    .clk(clk),
    .rst(rst),
    .rw(rw),
    .req(req),
    .oe(oe),
    .wre(wre),
    .ce(ce),
    .addr(addr),
    .data(data),
    .wdata(wdata),
    .rdata(rdata),
    .ram_addr(ram_addr),
    .error_flag(error_flag),
    .busy(busy),
    .done(done),
    .write_done_ram(write_done_ram)
    );
    spsram #(
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
    )uut1(
    .clk(clk),
    .addr(ram_addr),
    .oe(oe),
    .ce(ce),
    .wre(wre),
    .data(data),
    .write_done_ram(write_done_ram)
    );
    
    always #5 clk = ~clk;
    
    initial
begin
    // -------------------------
    // INITIAL RESET
    // -------------------------
    clk  = 0;
    rst  = 0;
    req  = 0;
    rw   = 0;
    addr = 8'h00;
    wdata = 8'h00;

    #10;
    rst = 1;

    // =========================================================
    // TEST 1: NORMAL WRITE
    // =========================================================
    $display("TEST 1: NORMAL WRITE");

    req   = 1;
    rw    = 1;             // write
    addr  = 8'h00;
    wdata = 8'h01;

    #10;
    req = 0;

    #10;

    // =========================================================
    // TEST 2: NORMAL READ
    // =========================================================
    $display("TEST 2: NORMAL READ");

    req  = 1;
    rw   = 0;              // read
    addr = 8'h00;

    #10;
    req = 0;

    #20;

    // =========================================================
    // TEST 3: CORRUPT ONE BIT
    // =========================================================
    $display("TEST 3: CORRUPTING SRAM BIT");

    force uut1.mem[0][0] = 1'b0;

    #10;

    // =========================================================
    // TEST 4: READ CORRUPTED DATA
    // Controller should detect parity error and retry
    // =========================================================
    $display("TEST 4: READING CORRUPTED DATA");

    req  = 1;
    rw   = 0;
    addr = 8'h00;

    #10;
    req = 0;

    // Give enough time for retries
    #100;

    // =========================================================
    // TEST 5: RESTORE SRAM
    // =========================================================
    $display("TEST 5: REMOVING CORRUPTION");

    release uut1.mem[0][0];

    #10;

    // =========================================================
    // TEST 6: READ AGAIN
    // Should now pass parity
    // =========================================================
    $display("TEST 6: READING RESTORED DATA");

    req  = 1;
    rw   = 0;
    addr = 8'h00;

    #10;
    req = 0;

    #40;

    // =========================================================
    // TEST 7: WRITE DIFFERENT DATA
    // =========================================================
    $display("TEST 7: WRITING DIFFERENT DATA");

    req   = 1;
    rw    = 1;
    addr  = 8'h01;
    wdata = 8'hA5;

    #10;
    req = 0;

    #20;

    // =========================================================
    // TEST 8: READ DIFFERENT ADDRESS
    // =========================================================
    $display("TEST 8: READING ADDRESS 01");

    req  = 1;
    rw   = 0;
    addr = 8'h01;

    #10;
    req = 0;

    #30;

    // =========================================================
    // END
    // =========================================================
    $display("ALL TESTS COMPLETED");

    $finish;
end
endmodule
