`timescale 1ns / 1ps

module tb_ecc_encoder;
  import config_pkg::*;

  logic [DATA_WIDTH-1:0]   data_in;
  logic [CODE_WIDTH-1:0]   code_out;
  logic [CODE_WIDTH-1:0]   code_in;
  logic [DATA_WIDTH-1:0]   data_out;
  logic [PARITY_WIDTH-1:0] syndrome;
  logic                    err_corrected, err_double;
  int errors = 0;
  int n_clean = 0, n_single = 0, n_double = 0;

  ecc_encoder enc (
    .data_in  (data_in),
    .code_out (code_out)
  );

  ecc_decoder dec (
    .code_in       (code_in),
    .data_out      (data_out),
    .syndrome      (syndrome),
    .err_corrected (err_corrected),
    .err_double    (err_double)
  );

  // Apply one data value, print the result, compare with the expected codeword
  task automatic check(input logic [DATA_WIDTH-1:0] data,
                       input logic [CODE_WIDTH-1:0] expected);
    data_in = data;
    #10;
    $display("data = %b  ->  overall = %b parity = %b  code = %h  (expected %h)  %s",
             data_in, code_out[CODE_WIDTH-1], code_out[HAMMING_WIDTH-1:DATA_WIDTH], code_out, expected,
             (code_out === expected) ? "OK" : "FAIL");
    if (code_out !== expected) errors++;
  endtask

  // Decode one corrupted codeword and compare the flags and data
  task automatic dec_check(input logic [CODE_WIDTH-1:0] code, input logic [DATA_WIDTH-1:0] data,
                           input logic exp_corr, input logic exp_dbl, input string what);
    code_in = code;
    #1;
    if (err_corrected !== exp_corr || err_double !== exp_dbl ||
        (!exp_dbl && data_out !== data)) begin
      if (errors < 10)
        $display("FAIL %s: data %h code %h -> out %h syn %0d corr %b dbl %b",
                 what, data, code, data_out, syndrome, err_corrected, err_double);
      errors++;
    end
  endtask

  initial begin
    $display("DATA_WIDTH = %0d, PARITY_WIDTH = %0d, CODE_WIDTH = %0d",
             DATA_WIDTH, PARITY_WIDTH, CODE_WIDTH);

    // Print the masks the encoder uses
    for (int j = 0; j < PARITY_WIDTH; j++)
      $display("MASK[%0d] = %b", j, parity_mask(j));
    $display("");

    // Expected values for DATA_WIDTH = 8 (masks 5B, 6D, 8E, F0), bit 12 = overall parity
    check(8'h00, 13'h0000);   // no 1s           -> all parity 0
    check(8'h01, 13'h1301);   // d0: p0, p1       -> 3 ones, overall 1
    check(8'h80, 13'h1C80);   // d7: p2, p3       -> 3 ones, overall 1
    check(8'hFF, 13'h03FF);   // all 1s          -> parity 0011, 10 ones, overall 0
    check(8'hB6, 13'h1CB6);   // worked example  -> parity 1100, 7 ones, overall 1

    // Exhaustive decoder check: every data value, no error, every single flip, every double flip
    for (int d = 0; d < (1 << DATA_WIDTH); d++) begin
      data_in = d;
      #1;
      dec_check(code_out, d, 1'b0, 1'b0, "clean");
      n_clean++;
      for (int a = 0; a < CODE_WIDTH; a++) begin
        dec_check(code_out ^ (1 << a), d, 1'b1, 1'b0, "single");
        n_single++;
        for (int b = a + 1; b < CODE_WIDTH; b++) begin
          dec_check(code_out ^ (1 << a) ^ (1 << b), d, 1'b0, 1'b1, "double");
          n_double++;
        end
      end
    end
    $display("decoder: %0d clean, %0d single (corrected), %0d double (detected) codewords checked",
             n_clean, n_single, n_double);

    $display("");
    if (errors == 0) $display("PASS");
    else             $display("FAIL: %0d mismatches", errors);
    $finish;
  end

endmodule
