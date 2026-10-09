`timescale 1ns/1ps
// =============================================================================
// tb_stall_free_dip_4x4.v -- self-checking 3-TILE testbench, STALL-FREE DiP 4x4
// RTL: stall_free_dip_array / stall_free_dip_pe  (stall_free_dip_rtl.v)
//
// Uses EXACTLY the same 3 tiles as tb_dip_4x4.v.
//   golden C per tile:
//   tile0 C = [[13,19,24,25],[37,47,60,61],[61,75,96,97],[85,103,132,133]]
//   tile1 C = [[9,13,-6,-1],[1,10,21,18],[10,-5,16,-5],[1,45,-25,28]]
//   tile2 C = [[40,34,23,13],[30,43,28,37],[35,26,45,36],[13,46,29,28]]
// Tiles alternate buffers: tile0 -> A, tile1 -> B, tile2 -> A.
// The next tile's weights shift into the shadow buffer while the active
// buffer still drives the MAC, so the input stream never stops.
//
//   tile period = N = 4 cycles (0 exposed weight reload)
//   T0 = [3, 7, 11] ; shadow-load start = [0, 4, 8] ; last output cycle = 19
//   vs baseline DiP 4x4 : period 10, last output 31
//
// Buffer-reuse safety (tile2 reuses tile0's buffer A):
//   tile0 row r last multiply   = T0[0] + r + N = 3+r+4
//   buffer A row r first rewritten = T0[0] + N + 1 + r = 3+5+r
//   safe by exactly one cycle per row. Because the three tiles carry
//   DIFFERENT weights, this is genuinely tested here.
// =============================================================================
module tb_stall_free_dip_4x4;

    parameter N          = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 32;

    reg  clk;
    reg  rst_n;
    reg  [N*DATA_WIDTH-1:0] inputs_flat;
    reg  [N*DATA_WIDTH-1:0] weights_flat;
    reg  [N*ACC_WIDTH-1:0]  psum_flat_in;
    wire [N*ACC_WIDTH-1:0]  psum_flat_out;

    integer cycle_count;
    integer err_count;
    integer chk_count;

    wire signed [ACC_WIDTH-1:0] o0 = $signed(psum_flat_out[  ACC_WIDTH-1 -: ACC_WIDTH]);
    wire signed [ACC_WIDTH-1:0] o1 = $signed(psum_flat_out[2*ACC_WIDTH-1 -: ACC_WIDTH]);
    wire signed [ACC_WIDTH-1:0] o2 = $signed(psum_flat_out[3*ACC_WIDTH-1 -: ACC_WIDTH]);
    wire signed [ACC_WIDTH-1:0] o3 = $signed(psum_flat_out[4*ACC_WIDTH-1 -: ACC_WIDTH]);

    reg  [N-1:0]            wshift_A;
    reg  [N-1:0]            wshift_B;
    reg                     load_target;
    reg  [N-1:0]            buf_sel;
    reg  [N-1:0]            pe_en;
    reg  [N-1:0]            mul_en;
    reg  [N-1:0]            adder_en;

    stall_free_dip_array #(.N(N),.DATA_WIDTH(DATA_WIDTH),.ACC_WIDTH(ACC_WIDTH)) uut (
        .clk(clk), .rst_n(rst_n),
        .wshift_A(wshift_A), .wshift_B(wshift_B),
        .load_target(load_target), .buf_sel(buf_sel),
        .pe_en(pe_en), .mul_en(mul_en), .adder_en(adder_en),
        .inputs_flat(inputs_flat), .weights_flat(weights_flat),
        .psum_flat_in(psum_flat_in), .psum_flat_out(psum_flat_out));

    always #5 clk = ~clk;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) cycle_count <= -1; else cycle_count <= cycle_count + 1;

    task drv;
        input [N-1:0]            wa;
        input [N-1:0]            wb;
        input                    lt;
        input [N-1:0]            bs;
        input [N-1:0]            pe;
        input [N-1:0]            mu;
        input [N-1:0]            ad;
        input [N*DATA_WIDTH-1:0] wf;
        input [N*DATA_WIDTH-1:0] inf;
        begin
            wshift_A=wa; wshift_B=wb; load_target=lt; buf_sel=bs;
            pe_en=pe; mul_en=mu; adder_en=ad;
            weights_flat=wf; inputs_flat=inf;
            @(negedge clk);
        end
    endtask

    task check_row;
        input integer tile;
        input integer row;
        input integer e0; input integer e1; input integer e2; input integer e3;
        begin
            chk_count = chk_count + 1;
            if ((o0===e0)&&(o1===e1)&&(o2===e2)&&(o3===e3))
                $display("[cyc %0d] PASS  Tile %0d Row %0d = (%0d, %0d, %0d, %0d)",
                         cycle_count, tile, row, o0,o1,o2,o3);
            else begin
                $display("[cyc %0d] FAIL  Tile %0d Row %0d  Got=(%0d,%0d,%0d,%0d)  Exp=(%0d,%0d,%0d,%0d)",
                         cycle_count, tile, row, o0,o1,o2,o3, e0,e1,e2,e3);
                err_count = err_count + 1;
            end
        end
    endtask

    always @(negedge clk) begin
        if (rst_n) begin
            if (cycle_count ==  8) check_row(0, 0,     13,     19,     24,     25);
            if (cycle_count ==  9) check_row(0, 1,     37,     47,     60,     61);
            if (cycle_count == 10) check_row(0, 2,     61,     75,     96,     97);
            if (cycle_count == 11) check_row(0, 3,     85,    103,    132,    133);
            if (cycle_count == 12) check_row(1, 0,      9,     13,     -6,     -1);
            if (cycle_count == 13) check_row(1, 1,      1,     10,     21,     18);
            if (cycle_count == 14) check_row(1, 2,     10,     -5,     16,     -5);
            if (cycle_count == 15) check_row(1, 3,      1,     45,    -25,     28);
            if (cycle_count == 16) check_row(2, 0,     40,     34,     23,     13);
            if (cycle_count == 17) check_row(2, 1,     30,     43,     28,     37);
            if (cycle_count == 18) check_row(2, 2,     35,     26,     45,     36);
            if (cycle_count == 19) check_row(2, 3,     13,     46,     29,     28);
        end
    end

    initial begin
        clk=1'b0; rst_n=1'b0; err_count=0; chk_count=0;
        wshift_A=0; wshift_B=0; load_target=1'b0; buf_sel=0;
        pe_en=0; mul_en=0; adder_en=0;
        inputs_flat=0; weights_flat=0; psum_flat_in=0;
        $display("======================================================");
        $display("   STALL-FREE DiP 4x4  --  3-TILE SELF-CHECKING TB");
        $display("   tile period = 4 cycles (baseline DiP = 10)");
        $display("======================================================");
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        drv(4'b0001, 4'b0000, 1'b0, 4'b0000, 4'b0000, 4'b0000, 4'b0000, {8'sd2,8'sd2,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 0
        drv(4'b0011, 4'b0000, 1'b0, 4'b0000, 4'b0000, 4'b0000, 4'b0000, {8'sd0,8'sd1,8'sd2,8'sd3}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 1
        drv(4'b0111, 4'b0000, 1'b0, 4'b0000, 4'b0000, 4'b0000, 4'b0000, {8'sd3,8'sd1,8'sd1,8'sd1}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 2
        drv(4'b1111, 4'b0000, 1'b0, 4'b0000, 4'b0001, 4'b0000, 4'b0000, {8'sd4,8'sd5,8'sd4,8'sd2}, {8'sd4,8'sd3,8'sd2,8'sd1}); // cycle 3
        drv(4'b0000, 4'b0001, 1'b1, 4'b0000, 4'b0011, 4'b0001, 4'b0000, {-8'sd3,8'sd5,8'sd3,-8'sd1}, {8'sd8,8'sd7,8'sd6,8'sd5}); // cycle 4
        drv(4'b0000, 4'b0011, 1'b1, 4'b0000, 4'b0111, 4'b0011, 4'b0001, {8'sd0,-8'sd2,8'sd4,8'sd3}, {8'sd12,8'sd11,8'sd10,8'sd9}); // cycle 5
        drv(4'b0000, 4'b0111, 1'b1, 4'b0000, 4'b1111, 4'b0111, 4'b0011, {8'sd4,8'sd0,8'sd2,8'sd2}, {8'sd16,8'sd15,8'sd14,8'sd13}); // cycle 6
        drv(4'b0000, 4'b1111, 1'b1, 4'b0001, 4'b1111, 4'b1111, 4'b0111, {8'sd2,8'sd1,-8'sd1,8'sd1}, {8'sd0,8'sd3,-8'sd1,8'sd2}); // cycle 7
        drv(4'b0001, 4'b0000, 1'b0, 4'b0011, 4'b1111, 4'b1111, 4'b1111, {8'sd3,8'sd2,8'sd2,8'sd0}, {8'sd4,-8'sd2,8'sd5,8'sd1}); // cycle 8
        drv(4'b0011, 4'b0000, 1'b0, 4'b0111, 4'b1111, 4'b1111, 4'b1111, {8'sd4,8'sd1,8'sd5,8'sd2}, {-8'sd1,8'sd1,8'sd3,8'sd0}); // cycle 9
        drv(4'b0111, 4'b0000, 1'b0, 4'b1111, 4'b1111, 4'b1111, 4'b1111, {8'sd0,8'sd2,8'sd1,8'sd1}, {8'sd5,8'sd2,-8'sd3,8'sd6}); // cycle 10
        drv(4'b1111, 4'b0000, 1'b0, 4'b1110, 4'b1111, 4'b1111, 4'b1111, {8'sd1,8'sd4,8'sd3,8'sd5}, {8'sd3,8'sd2,8'sd1,8'sd7}); // cycle 11
        drv(4'b0000, 4'b0000, 1'b0, 4'b1100, 4'b1111, 4'b1111, 4'b1111, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd2,8'sd1,8'sd8,8'sd4}); // cycle 12
        drv(4'b0000, 4'b0000, 1'b0, 4'b1000, 4'b1111, 4'b1111, 4'b1111, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd1,8'sd9,8'sd2,8'sd3}); // cycle 13
        drv(4'b0000, 4'b0000, 1'b0, 4'b0000, 4'b1111, 4'b1111, 4'b1111, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd6,8'sd2,8'sd4,8'sd1}); // cycle 14
        drv(4'b0000, 4'b0000, 1'b0, 4'b0000, 4'b1110, 4'b1111, 4'b1111, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 15
        drv(4'b0000, 4'b0000, 1'b0, 4'b0000, 4'b1100, 4'b1110, 4'b1111, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 16
        drv(4'b0000, 4'b0000, 1'b0, 4'b0000, 4'b1000, 4'b1100, 4'b1110, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 17
        drv(4'b0000, 4'b0000, 1'b0, 4'b0000, 4'b0000, 4'b1000, 4'b1100, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 18
        drv(4'b0000, 4'b0000, 1'b0, 4'b0000, 4'b0000, 4'b0000, 4'b1000, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 19

        drv(0,0,1'b0,0,0,0,0, {4{8'sd0}}, {4{8'sd0}});
        drv(0,0,1'b0,0,0,0,0, {4{8'sd0}}, {4{8'sd0}});

        $display("");
        $display("======================================================");
        $display(" Rows checked : %0d  (expected 12)", chk_count);
        if ((err_count==0) && (chk_count==12))
             $display(" SIMULATION PASSED   Errors = 0");
        else $display(" SIMULATION FAILED   Errors = %0d", err_count);
        $display(" period 4 vs baseline 10 ; last output 19 vs 31");
        $display("======================================================");
        $finish;
    end
endmodule