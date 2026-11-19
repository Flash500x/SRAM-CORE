`timescale 1ns / 1ps

package axi_txn_pkg;
    import config_pkg::*;

    // One AXI transaction: what the generator asks for, what the driver drives,
    // and (in a second object) what the monitor saw.

    typedef enum {WR, RD} kind_e;

    typedef enum {
        W_NONE,              // well behaved write
        W_EARLY_WLAST,       // WLAST on beat w_err_beat, before the last beat
        W_MISSING_WLAST,     // no WLAST on the last beat, extra_beats more beats follow, the last has WLAST
        W_TIMEOUT_NO_DATA,   // AW only, the W beats come after the B response
        W_TIMEOUT_MID        // w_err_beat beats, stall past the timeout, the rest after the B response
    } werr_e;

    typedef enum {ECC_NONE, ECC_SINGLE, ECC_DOUBLE} ecc_e;

    localparam bit [1:0] B_FIXED = 2'b00, B_INCR = 2'b01, B_WRAP = 2'b10, B_RSVD = 2'b11;
    localparam bit [1:0] RESP_OKAY = 2'b00, RESP_SLVERR = 2'b10;
    localparam int       MEM_DEPTH = 1 << ADDRESS_WIDTH;

    class axi_txn;
        static int next_num = 0;
        int num;                                  // transaction number, for the report
        string phase = "random";                 // directed / random / sweep

        // ---------------- request ----------------
        // the weighted choices are made in pick() (called from pre_randomize) with plain $urandom,
        // which gives the same mix on every simulator; the dependent fields below are rand
        kind_e                         kind;
        bit [ADDRESS_WIDTH-1:0]        addr;
        bit [BURST_LENGTH-1:0]         len;       // AxLEN, beats = len + 1
        bit [1:0]                      burst;
        rand bit [ID_WIDTH-1:0]        id;
        bit                            fixed_req;    // directed: kind/burst/len/addr/werr/ecc set by the caller

        // ---------------- error injection ----------------
        werr_e                         werr;
        rand int unsigned              w_err_beat;   // early WLAST beat / beats sent before the stall
        rand int unsigned              extra_beats;  // missing WLAST: beats after the last one
        ecc_e                          ecc;          // read: SRAM word corrupted before the read
        rand int unsigned              ecc_beat;     // which beat's word is corrupted
        rand int unsigned              ecc_bit0, ecc_bit1;

        // ---------------- timing ----------------
        int unsigned                   w_gap_max;    // idle cycles between W beats, 0..w_gap_max
        int                            aw_w_skew;    // > 0 W starts later, < 0 W starts first
        int unsigned                   rready_pct;   // chance RREADY is high in a cycle
        int unsigned                   bready_pct;   // chance BREADY is high in a cycle

        // ---------------- filled in post_randomize ----------------
        bit [DATA_WIDTH-1:0]           wdata[$];     // every W beat driven, in order
        bit                            wlast[$];     // WLAST of each driven beat
        int                            pre_b_beats;  // beats driven before the B response, rest after
        bit [CODE_WIDTH-1:0]           ecc_mask;

        // ---------------- observed (monitor object) ----------------
        bit [1:0]                      bresp;
        bit [ID_WIDTH-1:0]             bid;
        bit [DATA_WIDTH-1:0]           rdata[$];
        bit [1:0]                      rresp[$];
        bit [ID_WIDTH-1:0]             rid[$];
        bit                            rlast[$];
        bit                            unexpected;   // response with no matching request
        bit                            drv_hang;     // driver gave up waiting for the response

        // ---------------- constraints on the dependent fields ----------------
        constraint c_werr_beat {
            (werr == W_EARLY_WLAST) -> w_err_beat < len;              // WLAST before the last beat
            (werr == W_TIMEOUT_MID) -> w_err_beat inside {[1:len]};   // at least one beat, not all
            !(werr inside {W_EARLY_WLAST, W_TIMEOUT_MID}) -> w_err_beat == 0;
            extra_beats inside {[1:4]};
        }
        constraint c_ecc_bits {
            ecc_beat <= len;
            ecc_bit0 < CODE_WIDTH;
            ecc_bit1 < CODE_WIDTH;
            ecc_bit0 != ecc_bit1;
        }

        // weighted pick: returns an index into w, chance proportional to w[i]
        static function int wpick(int w[]);
            int total = 0, r;
            foreach (w[i]) total += w[i];
            r = $urandom_range(total - 1, 0);
            foreach (w[i]) begin
                if (r < w[i]) return i;
                r -= w[i];
            end
            return 0;
        endfunction

        // the random mix
        function void pick();
            kind  = wpick('{50, 50}) ? RD : WR;
            case (wpick('{22, 40, 30, 8}))                    // FIXED INCR WRAP reserved
                0: burst = B_FIXED;
                1: burst = B_INCR;
                2: burst = B_WRAP;
                default: burst = B_RSVD;
            endcase
            if (burst == B_WRAP)
                case (wpick('{22, 22, 22, 22, 12}))           // 2 4 8 16 beats, or an illegal length
                    0: len = 1;  1: len = 3;  2: len = 7;  3: len = 15;
                    default: begin                            // any of the 12 illegal lengths
                        int bad_len[12] = '{0, 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14};
                        len = bad_len[$urandom_range(11, 0)];
                    end
                endcase
            else
                case (wpick('{25, 25, 20, 30}))               // 1, 2-4, 5-8, 9-16 beats
                    0: len = 0;
                    1: len = $urandom_range(3, 1);
                    2: len = $urandom_range(7, 4);
                    default: len = $urandom_range(15, 8);
                endcase
            // the top 16 words make INCR bursts run off the end of memory
            addr = wpick('{80, 20}) ? $urandom_range(MEM_DEPTH - 1, MEM_DEPTH - 16)
                                    : $urandom_range(MEM_DEPTH - 17, 0);

            werr = W_NONE;
            if (kind == WR)
                case (wpick('{68, 8, 8, 7, 9}))
                    1: werr = W_EARLY_WLAST;
                    2: werr = W_MISSING_WLAST;
                    3: werr = W_TIMEOUT_NO_DATA;
                    4: werr = W_TIMEOUT_MID;
                    default: werr = W_NONE;
                endcase
            if (len == 0 && werr inside {W_EARLY_WLAST, W_TIMEOUT_MID}) werr = W_NONE;   // needs 2+ beats

            ecc = ECC_NONE;
            if (kind == RD && is_legal())                     // only legal reads touch real SRAM words
                case (wpick('{70, 18, 12}))
                    1: ecc = ECC_SINGLE;
                    2: ecc = ECC_DOUBLE;
                    default: ecc = ECC_NONE;
                endcase

            w_gap_max  = wpick('{55, 25, 20}) == 0 ? 0 : (wpick('{1, 1}) ? $urandom_range(20, 4)
                                                                          : $urandom_range(3, 1));
            case (wpick('{50, 20, 30}))                       // together, W first, AW first
                0: aw_w_skew = 0;
                1: aw_w_skew = -int'($urandom_range(6, 1));
                default: aw_w_skew = $urandom_range(12, 1);
            endcase
            rready_pct = wpick('{60, 40}) ? $urandom_range(90, 20) : 100;
            bready_pct = wpick('{60, 40}) ? $urandom_range(90, 20) : 100;
        endfunction

        function void pre_randomize();
            if (!fixed_req) pick();
        endfunction

        function new();
            num = next_num++;
        endfunction

        function void post_randomize();
            int n_beats;
            wdata.delete();
            wlast.delete();
            case (werr)
                W_EARLY_WLAST:   n_beats = w_err_beat + 1;
                W_MISSING_WLAST: n_beats = len + 1 + extra_beats;
                default:         n_beats = len + 1;
            endcase
            for (int i = 0; i < n_beats; i++) begin
                wdata.push_back($urandom);
                wlast.push_back(i == n_beats - 1);
            end
            case (werr)
                W_TIMEOUT_NO_DATA: pre_b_beats = 0;
                W_TIMEOUT_MID:     pre_b_beats = w_err_beat;
                default:           pre_b_beats = n_beats;
            endcase
            ecc_mask = '0;
            if (ecc != ECC_NONE)   ecc_mask[ecc_bit0] = 1'b1;
            if (ecc == ECC_DOUBLE) ecc_mask[ecc_bit1] = 1'b1;
        endfunction

        // ---------------- helpers ----------------
        function int beats();
            return int'(len) + 1;
        endfunction

        function bit is_legal();
            case (burst)
                B_FIXED: return 1;
                B_INCR:  return int'(addr) + int'(len) <= MEM_DEPTH - 1;
                B_WRAP:  return len inside {1, 3, 7, 15};
                default: return 0;
            endcase
        endfunction

        function string illegal_kind();
            case (burst)
                B_INCR:  return "INCR crosses the top of memory";
                B_WRAP:  return "WRAP length not 2/4/8/16";
                default: return "reserved burst type 2'b11";
            endcase
        endfunction

        // address of beat n
        function bit [ADDRESS_WIDTH-1:0] beat_addr(int n);
            bit [ADDRESS_WIDTH-1:0] mask;
            case (burst)
                B_INCR:  return addr + n;
                B_WRAP: begin
                    mask = len;
                    return (addr & ~mask) | ((addr + n) & mask);
                end
                default: return addr;
            endcase
        endfunction

        function string burst_name();
            case (burst)
                B_FIXED: return "FIXED";
                B_INCR:  return "INCR";
                B_WRAP:  return "WRAP";
                default: return "RSVD";
            endcase
        endfunction

        function string sprint();
            string s;
            s = $sformatf("#%0d %s %s addr=%02h beats=%0d id=%0d", num, kind == WR ? "WRITE" : "READ",
                          burst_name(), addr, beats(), id);
            if (!is_legal()) s = {s, " [illegal]"};
            if (kind == WR && werr != W_NONE) s = {s, " [", werr.name(), "]"};
            if (kind == RD && ecc != ECC_NONE)
                s = {s, $sformatf(" [%s at beat %0d addr %02h mask %h]", ecc.name(), ecc_beat,
                                  beat_addr(ecc_beat), ecc_mask)};
            return s;
        endfunction

    endclass

endpackage
