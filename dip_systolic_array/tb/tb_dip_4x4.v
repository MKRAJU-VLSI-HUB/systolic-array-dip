`timescale 1ns/1ps
module tb_dip_4x4;

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

    reg                     wshift;
    reg  [N-1:0]            pe_en;
    reg  [N-1:0]            mul_en;
    reg  [N-1:0]            adder_en;

    dip_systolic_array #(.N(N),.DATA_WIDTH(DATA_WIDTH),.ACC_WIDTH(ACC_WIDTH)) uut (
        .clk(clk), .rst_n(rst_n), .wshift(wshift),
        .pe_en(pe_en), .mul_en(mul_en), .adder_en(adder_en),
        .inputs_flat(inputs_flat), .weights_flat(weights_flat),
        .psum_flat_in(psum_flat_in), .psum_flat_out(psum_flat_out));

    always #5 clk = ~clk;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) cycle_count <= -1; else cycle_count <= cycle_count + 1;

    task drv;
        input                    w;
        input [N-1:0]            pe;
        input [N-1:0]            mu;
        input [N-1:0]            ad;
        input [N*DATA_WIDTH-1:0] wf;
        input [N*DATA_WIDTH-1:0] inf;
        begin
            wshift=w; pe_en=pe; mul_en=mu; adder_en=ad;
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
            if (cycle_count == 18) check_row(1, 0,      9,     13,     -6,     -1);
            if (cycle_count == 19) check_row(1, 1,      1,     10,     21,     18);
            if (cycle_count == 20) check_row(1, 2,     10,     -5,     16,     -5);
            if (cycle_count == 21) check_row(1, 3,      1,     45,    -25,     28);
            if (cycle_count == 28) check_row(2, 0,     40,     34,     23,     13);
            if (cycle_count == 29) check_row(2, 1,     30,     43,     28,     37);
            if (cycle_count == 30) check_row(2, 2,     35,     26,     45,     36);
            if (cycle_count == 31) check_row(2, 3,     13,     46,     29,     28);
        end
    end

    initial begin
        clk=1'b0; rst_n=1'b0; err_count=0; chk_count=0;
        wshift=1'b0; pe_en=0; mul_en=0; adder_en=0;
        inputs_flat=0; weights_flat=0; psum_flat_in=0;
        $display("======================================================");
        $display("   ORIGINAL DiP 4x4  --  3-TILE SELF-CHECKING TB");
        $display("   tile period = 10 cycles (3 exposed weight-reload)");
        $display("======================================================");
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        drv(1'b1, 4'b0000, 4'b0000, 4'b0000, {8'sd2,8'sd2,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 0
        drv(1'b1, 4'b0000, 4'b0000, 4'b0000, {8'sd0,8'sd1,8'sd2,8'sd3}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 1
        drv(1'b1, 4'b0000, 4'b0000, 4'b0000, {8'sd3,8'sd1,8'sd1,8'sd1}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 2
        drv(1'b1, 4'b0001, 4'b0000, 4'b0000, {8'sd4,8'sd5,8'sd4,8'sd2}, {8'sd4,8'sd3,8'sd2,8'sd1}); // cycle 3
        drv(1'b0, 4'b0011, 4'b0001, 4'b0000, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd8,8'sd7,8'sd6,8'sd5}); // cycle 4
        drv(1'b0, 4'b0111, 4'b0011, 4'b0001, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd12,8'sd11,8'sd10,8'sd9}); // cycle 5
        drv(1'b0, 4'b1111, 4'b0111, 4'b0011, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd16,8'sd15,8'sd14,8'sd13}); // cycle 6
        drv(1'b0, 4'b1110, 4'b1111, 4'b0111, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 7
        drv(1'b0, 4'b1100, 4'b1110, 4'b1111, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 8
        drv(1'b0, 4'b1000, 4'b1100, 4'b1110, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 9
        drv(1'b1, 4'b0000, 4'b1000, 4'b1100, {-8'sd3,8'sd5,8'sd3,-8'sd1}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 10
        drv(1'b1, 4'b0000, 4'b0000, 4'b1000, {8'sd0,-8'sd2,8'sd4,8'sd3}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 11
        drv(1'b1, 4'b0000, 4'b0000, 4'b0000, {8'sd4,8'sd0,8'sd2,8'sd2}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 12
        drv(1'b1, 4'b0001, 4'b0000, 4'b0000, {8'sd2,8'sd1,-8'sd1,8'sd1}, {8'sd0,8'sd3,-8'sd1,8'sd2}); // cycle 13
        drv(1'b0, 4'b0011, 4'b0001, 4'b0000, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd4,-8'sd2,8'sd5,8'sd1}); // cycle 14
        drv(1'b0, 4'b0111, 4'b0011, 4'b0001, {8'sd0,8'sd0,8'sd0,8'sd0}, {-8'sd1,8'sd1,8'sd3,8'sd0}); // cycle 15
        drv(1'b0, 4'b1111, 4'b0111, 4'b0011, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd5,8'sd2,-8'sd3,8'sd6}); // cycle 16
        drv(1'b0, 4'b1110, 4'b1111, 4'b0111, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 17
        drv(1'b0, 4'b1100, 4'b1110, 4'b1111, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 18
        drv(1'b0, 4'b1000, 4'b1100, 4'b1110, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 19
        drv(1'b1, 4'b0000, 4'b1000, 4'b1100, {8'sd3,8'sd2,8'sd2,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 20
        drv(1'b1, 4'b0000, 4'b0000, 4'b1000, {8'sd4,8'sd1,8'sd5,8'sd2}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 21
        drv(1'b1, 4'b0000, 4'b0000, 4'b0000, {8'sd0,8'sd2,8'sd1,8'sd1}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 22
        drv(1'b1, 4'b0001, 4'b0000, 4'b0000, {8'sd1,8'sd4,8'sd3,8'sd5}, {8'sd3,8'sd2,8'sd1,8'sd7}); // cycle 23
        drv(1'b0, 4'b0011, 4'b0001, 4'b0000, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd2,8'sd1,8'sd8,8'sd4}); // cycle 24
        drv(1'b0, 4'b0111, 4'b0011, 4'b0001, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd1,8'sd9,8'sd2,8'sd3}); // cycle 25
        drv(1'b0, 4'b1111, 4'b0111, 4'b0011, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd6,8'sd2,8'sd4,8'sd1}); // cycle 26
        drv(1'b0, 4'b1110, 4'b1111, 4'b0111, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 27
        drv(1'b0, 4'b1100, 4'b1110, 4'b1111, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 28
        drv(1'b0, 4'b1000, 4'b1100, 4'b1110, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 29
        drv(1'b0, 4'b0000, 4'b1000, 4'b1100, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 30
        drv(1'b0, 4'b0000, 4'b0000, 4'b1000, {8'sd0,8'sd0,8'sd0,8'sd0}, {8'sd0,8'sd0,8'sd0,8'sd0}); // cycle 31

        drv(1'b0, 0,0,0, {4{8'sd0}}, {4{8'sd0}});
        drv(1'b0, 0,0,0, {4{8'sd0}}, {4{8'sd0}});

        $display("");
        $display("======================================================");
        $display(" Rows checked : %0d  (expected 12)", chk_count);
        if ((err_count==0) && (chk_count==12))
             $display(" SIMULATION PASSED   Errors = 0");
        else $display(" SIMULATION FAILED   Errors = %0d", err_count);
        $display("======================================================");
        $finish;
    end
endmodule