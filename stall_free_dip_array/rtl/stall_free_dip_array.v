// =============================================================================
// stall_free_dip_rtl.v -- STALL-FREE DiP : stall_free_dip_pe + stall_free_dip_array
//
// Same diagonal input path, same vertical psum path and same 2-stage MAC as
// the original DiP. The ONLY change is the weight supply:
//
//              +-> Buffer A -+
// Weight Load -+             +-> Select(buf_sel_reg) -> MAC
//              +-> Buffer B -+
//
// Two independent weight shift chains with independent enables (wshift_A,
// wshift_B). load_target steers the incoming weight bus into one chain at
// row 0; the two chains never cross. buf_sel is per row and is pipelined
// alongside the input it applies to, so the A/B swap stays aligned with the
// diagonal wave.
//
// Parameterised in N, so the same file serves the 3x3, 4x4 and 64x64 TBs.
// =============================================================================

module stall_free_dip_pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         wshift_A,
    input  wire                         wshift_B,
    input  wire                         buf_sel,
    input  wire                         pe_en,
    input  wire                         mul_en,
    input  wire                         adder_en,
    input  wire signed [DATA_WIDTH-1:0] input_in,
    input  wire signed [DATA_WIDTH-1:0] weight_in_A,
    input  wire signed [DATA_WIDTH-1:0] weight_in_B,
    input  wire signed [ACC_WIDTH-1:0]  psum_in,
    output wire signed [DATA_WIDTH-1:0] input_out,
    output wire signed [DATA_WIDTH-1:0] weight_out_A,
    output wire signed [DATA_WIDTH-1:0] weight_out_B,
    output wire signed [ACC_WIDTH-1:0]  psum_out
);
    reg signed [DATA_WIDTH-1:0] weight_reg_A;
    reg signed [DATA_WIDTH-1:0] weight_reg_B;
    reg signed [DATA_WIDTH-1:0] input_reg;
    reg signed [ACC_WIDTH-1:0]  mul_reg;
    reg signed [ACC_WIDTH-1:0]  adder_reg;
    reg                         buf_sel_reg;

    // Full-precision product on an explicit wide signed wire (see dip_rtl.v note)
    wire signed [DATA_WIDTH-1:0]   active_weight = buf_sel_reg ? weight_reg_B : weight_reg_A;
    wire signed [2*DATA_WIDTH-1:0] product       = input_reg * active_weight;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg_A <= {DATA_WIDTH{1'b0}};
            weight_reg_B <= {DATA_WIDTH{1'b0}};
            input_reg    <= {DATA_WIDTH{1'b0}};
            mul_reg      <= {ACC_WIDTH{1'b0}};
            adder_reg    <= {ACC_WIDTH{1'b0}};
            buf_sel_reg  <= 1'b0;
        end else begin
            if (wshift_A) weight_reg_A <= weight_in_A;
            if (wshift_B) weight_reg_B <= weight_in_B;
            if (pe_en) begin
                input_reg   <= input_in;
                buf_sel_reg <= buf_sel;
            end
            if (mul_en)   mul_reg   <= {{(ACC_WIDTH-2*DATA_WIDTH){product[2*DATA_WIDTH-1]}}, product};
            if (adder_en) adder_reg <= mul_reg + psum_in;
        end
    end

    assign input_out    = input_reg;
    assign weight_out_A = weight_reg_A;
    assign weight_out_B = weight_reg_B;
    assign psum_out     = adder_reg;
endmodule


module stall_free_dip_array #(
    parameter N          = 3,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire [N-1:0]            wshift_A,
    input  wire [N-1:0]            wshift_B,
    input  wire                    load_target,   // 0 = load chain A, 1 = load chain B
    input  wire [N-1:0]            buf_sel,
    input  wire [N-1:0]            pe_en,
    input  wire [N-1:0]            mul_en,
    input  wire [N-1:0]            adder_en,
    input  wire [N*DATA_WIDTH-1:0] inputs_flat,
    input  wire [N*DATA_WIDTH-1:0] weights_flat,
    input  wire [N*ACC_WIDTH-1:0]  psum_flat_in,
    output wire [N*ACC_WIDTH-1:0]  psum_flat_out
);
    wire signed [DATA_WIDTH-1:0] pe_input_in     [0:N-1][0:N-1];
    wire signed [DATA_WIDTH-1:0] pe_input_out    [0:N-1][0:N-1];
    wire signed [DATA_WIDTH-1:0] pe_weight_in_A  [0:N-1][0:N-1];
    wire signed [DATA_WIDTH-1:0] pe_weight_out_A [0:N-1][0:N-1];
    wire signed [DATA_WIDTH-1:0] pe_weight_in_B  [0:N-1][0:N-1];
    wire signed [DATA_WIDTH-1:0] pe_weight_out_B [0:N-1][0:N-1];
    wire signed [ACC_WIDTH-1:0]  pe_psum_in      [0:N-1][0:N-1];
    wire signed [ACC_WIDTH-1:0]  pe_psum_out     [0:N-1][0:N-1];

    genvar r, c;
    generate
        for (r = 0; r < N; r = r + 1) begin: row_gen
            for (c = 0; c < N; c = c + 1) begin: col_gen

                // diagonal input with wrap-around (unchanged from DiP)
                if (r == 0) begin: input_row0
                    assign pe_input_in[r][c] = inputs_flat[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH];
                end else begin: input_diag_shift
                    assign pe_input_in[r][c] = pe_input_out[r-1][(c+1)%N];
                end

                // two independent vertical weight chains, steered at row 0
                if (r == 0) begin: top_weight
                    assign pe_weight_in_A[r][c] = (load_target == 1'b0) ?
                        weights_flat[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH] : {DATA_WIDTH{1'b0}};
                    assign pe_weight_in_B[r][c] = (load_target == 1'b1) ?
                        weights_flat[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH] : {DATA_WIDTH{1'b0}};
                end else begin: sub_weight
                    assign pe_weight_in_A[r][c] = pe_weight_out_A[r-1][c];
                    assign pe_weight_in_B[r][c] = pe_weight_out_B[r-1][c];
                end

                // vertical psum chain (unchanged from DiP)
                if (r == 0) begin: top_psum
                    assign pe_psum_in[r][c] = psum_flat_in[(c+1)*ACC_WIDTH-1 -: ACC_WIDTH];
                end else begin: sub_psum
                    assign pe_psum_in[r][c] = pe_psum_out[r-1][c];
                end

                stall_free_dip_pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe_inst (
                    .clk(clk), .rst_n(rst_n),
                    .wshift_A(wshift_A[r]), .wshift_B(wshift_B[r]),
                    .buf_sel(buf_sel[r]), .pe_en(pe_en[r]),
                    .mul_en(mul_en[r]), .adder_en(adder_en[r]),
                    .input_in(pe_input_in[r][c]),
                    .weight_in_A(pe_weight_in_A[r][c]),
                    .weight_in_B(pe_weight_in_B[r][c]),
                    .psum_in(pe_psum_in[r][c]),
                    .input_out(pe_input_out[r][c]),
                    .weight_out_A(pe_weight_out_A[r][c]),
                    .weight_out_B(pe_weight_out_B[r][c]),
                    .psum_out(pe_psum_out[r][c]));
            end
        end
    endgenerate

    generate
        for (c = 0; c < N; c = c + 1) begin: output_mapping
            assign psum_flat_out[(c+1)*ACC_WIDTH-1 -: ACC_WIDTH] = pe_psum_out[N-1][c];
        end
    endgenerate
endmodule