`timescale 1ns / 1ps

module top_module_main_tb;

    parameter ADDRESS_WIDTH = 8;
    parameter DATA_WIDTH    = 8;
    parameter BURST_LENGTH  = 4;
    parameter ID_WIDTH      = 2;
    parameter BURST_TYPE    = 2;

    localparam FIXED = 2'b00;
    localparam INCR  = 2'b01;
    localparam WRAP  = 2'b10;
    localparam OKAY   = 2'b00;
    localparam SLVERR = 2'b10;

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
    // DIRECT READ PORT
    //==================================================
    reg                      rd_req;
    reg  [ADDRESS_WIDTH-1:0] rd_addr;
    wire [DATA_WIDTH-1:0]    rd_data;
    wire                     rd_done;
    wire                     rd_busy;

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

        // direct read port
        .rd_req(rd_req),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .rd_done(rd_done),
        .rd_busy(rd_busy)
    );


    //==================================================
    // SCOREBOARD
    //==================================================
    reg [DATA_WIDTH-1:0] model [0:255];    // what the SRAM should hold
    reg [DATA_WIDTH-1:0] r_data [0:255];
    reg [ID_WIDTH-1:0]   r_id   [0:255];
    reg [1:0]            r_resp [0:255];
    reg                  r_last [0:255];
    reg [ID_WIDTH-1:0]   b_id   [0:63];
    reg [1:0]            b_resp [0:63];
    integer rn, bn, pass_n, fail_n;
    integer i, k, n, bad;
    reg rready_random;
    reg r_seen;
    reg [DATA_WIDTH-1:0] r_prev;
    integer r_hold_bad;

    initial begin r_seen = 0; r_hold_bad = 0; end

    always @(posedge ACLK) if (ARST !== 1'b1) r_seen = 0; else begin
        if (!RVALID && r_seen && RDATA !== r_prev) r_hold_bad = r_hold_bad + 1;
        if (RVALID && RREADY) begin
            r_prev = RDATA; r_seen = 1;
            r_data[rn] = RDATA; r_id[rn] = RID; r_resp[rn] = RRESP; r_last[rn] = RLAST;
            rn = rn + 1;
        end
        if (BVALID && BREADY) begin
            b_id[bn] = BID; b_resp[bn] = BRESP;
            bn = bn + 1;
        end
    end

    always @(negedge ACLK) if (rready_random) RREADY = ($random % 4 == 0);

    task check(input cond, input [8*32-1:0] what);
    begin
        if (cond) pass_n = pass_n + 1;
        else begin
            fail_n = fail_n + 1;
            $display("  FAIL at %0t: %0s", $time, what);
        end
    end
    endtask

    // address of beat n of a burst
    function [ADDRESS_WIDTH-1:0] beat_addr(input [ADDRESS_WIDTH-1:0] start, input [BURST_LENGTH-1:0] len,
                                           input [1:0] burst, input integer beat);
    begin
        case (burst)
            INCR:    beat_addr = start + beat;
            WRAP:    beat_addr = (start & ~{{(ADDRESS_WIDTH-BURST_LENGTH){1'b0}}, len}) |
                                 ((start + beat) & {{(ADDRESS_WIDTH-BURST_LENGTH){1'b0}}, len});
            default: beat_addr = start;
        endcase
    end
    endfunction

    function is_legal(input [ADDRESS_WIDTH-1:0] start, input [BURST_LENGTH-1:0] len, input [1:0] burst);
    begin
        case (burst)
            FIXED:   is_legal = 1'b1;
            INCR:    is_legal = ({1'b0, start} + len) <= 9'd255;
            WRAP:    is_legal = (len == 1 || len == 3 || len == 7 || len == 15);
            default: is_legal = 1'b0;
        endcase
    end
    endfunction

    //==================================================
    // MASTER: every VALID holds until its READY
    //==================================================
    task send_aw(input [ADDRESS_WIDTH-1:0] a, input [BURST_LENGTH-1:0] len, input [1:0] burst, input [ID_WIDTH-1:0] id);
    begin
        AWADDR = a; AWLEN = len; AWBURST = burst; AWID = id; AWVALID = 1'b1;
        while (!AWREADY) #10;
        #10;
        AWVALID = 1'b0;
    end
    endtask

    task send_w(input [DATA_WIDTH-1:0] seed, input [BURST_LENGTH-1:0] len, input integer gap);
        integer beat;
    begin
        for (beat = 0; beat <= len; beat = beat + 1) begin
            WDATA = seed + beat; WLAST = (beat == len); WVALID = 1'b1;
            while (!WREADY) #10;
            #10;
            WVALID = 1'b0; WLAST = 1'b0;
            #(gap * 10);
        end
    end
    endtask

    task send_ar(input [ADDRESS_WIDTH-1:0] a, input [BURST_LENGTH-1:0] len, input [1:0] burst, input [ID_WIDTH-1:0] id);
    begin
        ARADDR = a; ARLEN = len; ARBURST = burst; ARID = id; ARVALID = 1'b1;
        while (!ARREADY) #10;
        #10;
        ARVALID = 1'b0;
    end
    endtask

    task update_model(input [ADDRESS_WIDTH-1:0] a, input [BURST_LENGTH-1:0] len, input [1:0] burst, input [DATA_WIDTH-1:0] seed);
        integer beat;
    begin
        if (is_legal(a, len, burst))
            for (beat = 0; beat <= len; beat = beat + 1)
                model[beat_addr(a, len, burst, beat)] = seed + beat;
    end
    endtask

    task wait_b(input integer want);
        integer t;
    begin
        t = 0;
        while (bn < want && t < 3000) begin #10; t = t + 1; end
        check(bn >= want, "B response timeout");
    end
    endtask

    task wait_r(input integer want);
        integer t;
    begin
        t = 0;
        while (rn < want && t < 3000) begin #10; t = t + 1; end
        check(rn >= want, "R beat timeout");
    end
    endtask

    // the whole memory must match, so a stray or runaway write cannot hide
    task check_mem;
    begin
        bad = 0;
        for (i = 0; i < 256; i = i + 1)
            if (dut.u_spsram.mem[i] !== model[i]) begin
                if (bad == 0) $display("  mem[%h]=%h expected %h", i, dut.u_spsram.mem[i], model[i]);
                bad = bad + 1;
            end
        check(bad == 0, "memory contents");
        check(dut.u_axi_slave.w_fifo_empty === 1'b1, "W fifo drained");
    end
    endtask

    // beats from index first onward must be this read, and its RLAST must close it
    task check_r(input integer first, input [ADDRESS_WIDTH-1:0] a, input [BURST_LENGTH-1:0] len,
                 input [1:0] burst, input [ID_WIDTH-1:0] id);
        integer beat;
    begin
        for (beat = 0; beat <= len; beat = beat + 1) begin
            k = first + beat;
            if (is_legal(a, len, burst)) begin
                check(r_data[k] === model[beat_addr(a, len, burst, beat)], "RDATA");
                check(r_resp[k] === OKAY, "RRESP OKAY");
            end
            else
                check(r_resp[k] === SLVERR, "RRESP SLVERR");
            check(r_id[k] === id, "RID");
            check(r_last[k] === (beat == len), "RLAST");
        end
    end
    endtask

    task write_op(input [ADDRESS_WIDTH-1:0] a, input [BURST_LENGTH-1:0] len, input [1:0] burst,
                  input [ID_WIDTH-1:0] id, input [DATA_WIDTH-1:0] seed, input integer gap);
    begin
        bn = 0;
        fork
            send_aw(a, len, burst, id);
            send_w(seed, len, gap);
        join
        update_model(a, len, burst, seed);
        wait_b(1);
        #100;                 // a second response would land here
        check(bn == 1, "exactly one B");
        check(b_id[0] === id, "BID");
        check(b_resp[0] === (is_legal(a, len, burst) ? OKAY : SLVERR), "BRESP");
        check_mem;
    end
    endtask

    task read_op(input [ADDRESS_WIDTH-1:0] a, input [BURST_LENGTH-1:0] len, input [1:0] burst, input [ID_WIDTH-1:0] id);
    begin
        rn = 0;
        send_ar(a, len, burst, id);
        wait_r(len + 1);
        #100;                 // an extra beat would land here
        check(rn == len + 1, "exact R beat count");
        check_r(0, a, len, burst, id);
        check_mem;
    end
    endtask


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

    BREADY  = 1;

    ARADDR  = 0;
    ARID    = 0;
    ARBURST = 0;
    ARLEN   = 0;
    ARVALID = 0;

    RREADY  = 1;

    rd_req  = 0;
    rd_addr = 0;

    rn = 0; bn = 0; pass_n = 0; fail_n = 0;
    rready_random = 0;

    //================================================
    // RESET
    //================================================
    #120;   // past the 100 ns glbl GSR, BUFGCE passes no clock until then
    ARST = 1;
    #10;

    //================================================
    // SINGLE WRITES: queued back to back, the first one
    // comes straight out of reset
    //================================================
    $display("[1] first write after reset, 3 queued single writes");
    bn = 0;
    fork send_aw(8'h01, 0, INCR, 2'd0); send_w(8'hA1, 0, 0); join
    fork send_aw(8'h02, 0, INCR, 2'd1); send_w(8'hA2, 0, 0); join
    fork send_aw(8'h03, 0, INCR, 2'd2); send_w(8'hA3, 0, 0); join
    update_model(8'h01, 0, INCR, 8'hA1);
    update_model(8'h02, 0, INCR, 8'hA2);
    update_model(8'h03, 0, INCR, 8'hA3);
    wait_b(3);
    #100;
    check(bn == 3, "3 B responses");
    for (n = 0; n < 3; n = n + 1) begin
        check(b_id[n] === n[1:0], "BID order");
        check(b_resp[n] === OKAY, "BRESP");
    end
    check_mem;

    $display("[2] single read of 0x03");
    read_op(8'h03, 0, INCR, 2'd2);

    //================================================
    // INCR
    //================================================
    $display("[3] INCR 4 beats at 0x0A, write and read");
    write_op(8'h0A, 3, INCR, 2'd3, 8'hB1, 0);
    read_op (8'h0A, 3, INCR, 2'd3);

    $display("[4] INCR 16 beats at 0x40, write and read");
    write_op(8'h40, 15, INCR, 2'd2, 8'h60, 0);
    read_op (8'h40, 15, INCR, 2'd1);

    $display("[5] INCR ending exactly on 0xFF is legal");
    write_op(8'hFC, 3, INCR, 2'd1, 8'h90, 0);
    read_op (8'hFC, 3, INCR, 2'd1);

    //================================================
    // WRAP: all four lengths, starting inside the window
    //================================================
    $display("[6] WRAP 2 beats at 0x61: 61 60");
    write_op(8'h61, 1, WRAP, 2'd0, 8'h10, 0);
    read_op (8'h61, 1, WRAP, 2'd0);

    $display("[7] WRAP 4 beats at 0x22: 22 23 20 21");
    write_op(8'h22, 3, WRAP, 2'd1, 8'hC1, 0);
    read_op (8'h22, 3, WRAP, 2'd1);
    read_op (8'h20, 3, INCR, 2'd2);       // same window in address order
    check(dut.u_spsram.mem[8'h20] === 8'hC3 && dut.u_spsram.mem[8'h21] === 8'hC4 &&
          dut.u_spsram.mem[8'h22] === 8'hC1 && dut.u_spsram.mem[8'h23] === 8'hC2, "wrap 4 order");

    $display("[8] WRAP 8 beats at 0x75: 75 76 77 70 71 72 73 74");
    write_op(8'h75, 7, WRAP, 2'd2, 8'h20, 0);
    read_op (8'h75, 7, WRAP, 2'd2);

    $display("[9] WRAP 16 beats at 0x8E: 8E 8F 80 .. 8D");
    write_op(8'h8E, 15, WRAP, 2'd3, 8'h30, 0);
    read_op (8'h8E, 15, WRAP, 2'd3);

    $display("[10] WRAP window at the top of memory, 4 beats at 0xFE: FE FF FC FD");
    write_op(8'hFE, 3, WRAP, 2'd1, 8'h48, 0);
    read_op (8'hFE, 3, WRAP, 2'd1);

    //================================================
    // FIXED
    //================================================
    $display("[11] FIXED 2 beats at 0x90: last beat stays, next address untouched");
    write_op(8'h90, 1, FIXED, 2'd2, 8'hE1, 0);
    check(dut.u_spsram.mem[8'h90] === 8'hE2, "fixed keeps last beat");
    read_op (8'h90, 3, FIXED, 2'd2);

    //================================================
    // ILLEGAL BURSTS: SLVERR, memory untouched, every beat still answered
    //================================================
    $display("[12] INCR past 0xFF: 4 beats at 0xFE gets SLVERR");
    write_op(8'hFE, 3, INCR, 2'd3, 8'h55, 0);
    read_op (8'hFE, 3, INCR, 2'd3);

    $display("[13] WRAP with 3 beats gets SLVERR");
    write_op(8'hA8, 2, WRAP, 2'd1, 8'h66, 0);
    read_op (8'hA8, 2, WRAP, 2'd1);

    $display("[14] reserved burst type gets SLVERR");
    write_op(8'hA8, 3, 2'b11, 2'd2, 8'h77, 0);
    read_op (8'hA8, 3, 2'b11, 2'd2);

    //================================================
    // BACK-PRESSURE
    //================================================
    $display("[15] slow master W: INCR, WRAP and FIXED");
    write_op(8'hB0, 3, INCR, 2'd3, 8'h70, 10);
    write_op(8'hC2, 3, WRAP, 2'd1, 8'h80, 7);
    write_op(8'hC8, 2, FIXED, 2'd2, 8'hF0, 6);

    $display("[16] WREADY drops: 16 beats hold until accepted");
    write_op(8'hD0, 15, INCR, 2'd0, 8'h01, 0);

    $display("[17] RREADY low 1 us during a 16 beat read");
    rn = 0;
    RREADY = 0;
    send_ar(8'h40, 15, INCR, 2'd2);
    #1000;
    check(rn == 0, "no beat taken while low");
    RREADY = 1;
    wait_r(16);
    #100;
    check(rn == 16, "16 beats after release");
    check_r(0, 8'h40, 15, INCR, 2'd2);

    $display("[18] random RREADY on a 16 beat WRAP read");
    rn = 0;
    rready_random = 1;
    send_ar(8'h8E, 15, WRAP, 2'd1);
    wait_r(16);
    rready_random = 0;
    RREADY = 1;
    #100;
    check(rn == 16, "16 beats random");
    check_r(0, 8'h8E, 15, WRAP, 2'd1);

    $display("[19] two queued 4 beat reads, RREADY low");
    rn = 0;
    RREADY = 0;
    send_ar(8'h40, 3, INCR, 2'd1);
    #300;
    send_ar(8'h44, 3, INCR, 2'd2);
    #300;
    RREADY = 1;
    wait_r(8);
    #100;
    check(rn == 8, "8 beats");
    check_r(0, 8'h40, 3, INCR, 2'd1);
    check_r(4, 8'h44, 3, INCR, 2'd2);

    $display("[20] 8 writes with BREADY low: no response lost");
    bn = 0;
    BREADY = 0;
    fork
        for (n = 0; n < 8; n = n + 1) send_aw(8'hE0 + n, 0, INCR, n[1:0]);
        for (k = 0; k < 8; k = k + 1) send_w(8'hD0 + k, 0, 0);
    join
    for (n = 0; n < 8; n = n + 1) update_model(8'hE0 + n, 0, INCR, 8'hD0 + n);
    #400;
    check(bn == 0, "no B while low");
    BREADY = 1;
    wait_b(8);
    #100;
    check(bn == 8, "8 B responses");
    for (n = 0; n < 8; n = n + 1) check(b_id[n] === n[1:0], "BID order under stall");
    check_mem;

    $display("[20a] 6 back to back single reads, RREADY low: none lost as the R fifo fills");
    rn = 0;
    RREADY = 0;
    for (n = 0; n < 6; n = n + 1) send_ar(8'h40 + n, 0, INCR, n[1:0]);
    #300;
    RREADY = 1;
    wait_r(6);
    #100;
    check(rn == 6, "6 single reads");
    for (n = 0; n < 6; n = n + 1) check_r(n, 8'h40 + n, 0, INCR, n[1:0]);

    $display("[20b] R fifo full: a write still completes");
    rn = 0;
    RREADY = 0;
    for (n = 0; n < 4; n = n + 1) begin send_ar(8'h40 + n, 0, INCR, 2'd1); #100; end
    write_op(8'h58, 0, INCR, 2'd2, 8'h5A, 0);
    RREADY = 1;
    wait_r(4);
    #100;
    check(rn == 4, "4 reads after the write");
    for (n = 0; n < 4; n = n + 1) check_r(n, 8'h40 + n, 0, INCR, 2'd1);

    $display("[20c] B fifo full: a read still completes");
    bn = 0;
    BREADY = 0;
    fork
        for (n = 0; n < 5; n = n + 1) send_aw(8'h5A + n, 0, INCR, n[1:0]);
        for (k = 0; k < 5; k = k + 1) send_w(8'hC8 + k, 0, 0);
    join
    #300;
    rn = 0;
    send_ar(8'h40, 0, INCR, 2'd3);
    wait_r(1);
    #50;
    check(rn == 1, "read while B is full");
    check_r(0, 8'h40, 0, INCR, 2'd3);
    for (n = 0; n < 5; n = n + 1) update_model(8'h5A + n, 0, INCR, 8'hC8 + n);
    BREADY = 1;
    wait_b(5);
    #100;
    check(bn == 5, "5 B responses");
    for (n = 0; n < 5; n = n + 1) check(b_id[n] === n[1:0], "BID order B full");
    check_mem;

    //================================================
    // READ AND WRITE TOGETHER
    //================================================
    $display("[21] read and write queued together keep their own IDs");
    bn = 0; rn = 0;
    fork
        send_aw(8'h50, 3, WRAP, 2'd1);
        send_w(8'h31, 3, 2);
        send_ar(8'h40, 7, INCR, 2'd3);
    join
    update_model(8'h50, 3, WRAP, 8'h31);
    wait_b(1);
    wait_r(8);
    #100;
    check(bn == 1 && b_id[0] === 2'd1 && b_resp[0] === OKAY, "write keeps ID 1");
    check(rn == 8, "8 read beats");
    check_r(0, 8'h40, 7, INCR, 2'd3);
    check_mem;

    //================================================
    // DIRECT READ PORT
    //================================================
    $display("[22] direct read port returns stored data");
    rd_addr = 8'h41;
    rd_req  = 1'b1;
    #10;
    rd_req  = 1'b0;
    n = 0;
    while (!rd_done && n < 20) begin #10; n = n + 1; end
    #10;
    check(rd_data === model[8'h41], "rd_data");

    //================================================
    // SECOND RESET: first transaction is now a read
    //================================================
    $display("[23] first read after reset");
    ARST = 0;
    #20;
    ARST = 1;
    #10;
    read_op(8'h41, 0, INCR, 2'd3);

    //================================================
    // FINISH
    //================================================
    check(r_hold_bad == 0, "RDATA holds between beats");
    $display("========================================");
    if (fail_n == 0) $display("ALL TESTS PASSED: %0d checks", pass_n);
    else             $display("TESTS FAILED: %0d of %0d checks", fail_n, pass_n + fail_n);
    $display("========================================");

    $finish;

end

    initial begin
        #200000;
        $display("TIMEOUT: testbench did not finish");
        $finish;
    end

endmodule
