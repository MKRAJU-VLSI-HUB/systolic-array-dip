// =============================================================================
// dip_rtl.v -- ORIGINAL DiP : dip_pe + dip_systolic_array
// Parameterised in N, so the same file serves the 3x3, 4x4 and 64x64 TBs.
// =============================================================================

module dip_pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         wshift,
    input  wire                         pe_en,
    input  wire                         mul_en,
    input  wire                         adder_en,
    input  wire signed [DATA_WIDTH-1:0] input_in,
    input  wire signed [DATA_WIDTH-1:0] weight_in,
    input  wire signed [ACC_WIDTH-1:0]  psum_in,
    output wire signed [DATA_WIDTH-1:0] input_out,
    output wire signed [DATA_WIDTH-1:0] weight_out,
    output wire signed [ACC_WIDTH-1:0]  psum_out
);
    reg signed [DATA_WIDTH-1:0] weight_reg;
    reg signed [DATA_WIDTH-1:0] input_reg;
    reg signed [ACC_WIDTH-1:0]  mul_reg;
    reg signed [ACC_WIDTH-1:0]  adder_reg;

   
    // to DATA_WIDTH before sign extension.
    wire signed [2*DATA_WIDTH-1:0] product = input_reg * weight_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg <= {DATA_WIDTH{1'b0}};
            input_reg  <= {DATA_WIDTH{1'b0}};
            mul_reg    <= {ACC_WIDTH{1'b0}};
            adder_reg  <= {ACC_WIDTH{1'b0}};
        end else begin
            if (wshift)   weight_reg <= weight_in;
            if (pe_en)    input_reg  <= input_in;
            if (mul_en)   mul_reg    <= {{(ACC_WIDTH-2*DATA_WIDTH){product[2*DATA_WIDTH-1]}}, product};
            if (adder_en) adder_reg  <= mul_reg + psum_in;
        end
    end

    assign input_out  = input_reg;
    assign weight_out = weight_reg;
    assign psum_out   = adder_reg;
endmodule


module dip_systolic_array #(
    parameter N          = 3,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    wshift,
    input  wire [N-1:0]            pe_en,
    input  wire [N-1:0]            mul_en,
    input  wire [N-1:0]            adder_en,
    input  wire [N*DATA_WIDTH-1:0] inputs_flat,
    input  wire [N*DATA_WIDTH-1:0] weights_flat,
    input  wire [N*ACC_WIDTH-1:0]  psum_flat_in,
    output wire [N*ACC_WIDTH-1:0]  psum_flat_out
);
    wire signed [DATA_WIDTH-1:0] pe_input_in   [0:N-1][0:N-1];
    wire signed [DATA_WIDTH-1:0] pe_input_out  [0:N-1][0:N-1];
    wire signed [DATA_WIDTH-1:0] pe_weight_in  [0:N-1][0:N-1];
    wire signed [DATA_WIDTH-1:0] pe_weight_out [0:N-1][0:N-1];
    wire signed [ACC_WIDTH-1:0]  pe_psum_in    [0:N-1][0:N-1];
    wire signed [ACC_WIDTH-1:0]  pe_psum_out   [0:N-1][0:N-1];

    genvar r, c;
    generate
        for (r = 0; r < N; r = r + 1) begin: row_gen
            for (c = 0; c < N; c = c + 1) begin: col_gen

                // diagonal input with wrap-around
                if (r == 0) begin: input_row0
                    assign pe_input_in[r][c] = inputs_flat[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH];
                end else begin: input_diag_shift
                    assign pe_input_in[r][c] = pe_input_out[r-1][(c+1)%N];
                end

                // vertical weight chain
                if (r == 0) begin: top_weight
                    assign pe_weight_in[r][c] = weights_flat[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH];
                end else begin: sub_weight
                    assign pe_weight_in[r][c] = pe_weight_out[r-1][c];
                end

                // vertical psum chain
                if (r == 0) begin: top_psum
                    assign pe_psum_in[r][c] = psum_flat_in[(c+1)*ACC_WIDTH-1 -: ACC_WIDTH];
                end else begin: sub_psum
                    assign pe_psum_in[r][c] = pe_psum_out[r-1][c];
                end

                dip_pe #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe_inst (
                    .clk(clk), .rst_n(rst_n),
                    .wshift(wshift), .pe_en(pe_en[r]),
                    .mul_en(mul_en[r]), .adder_en(adder_en[r]),
                    .input_in(pe_input_in[r][c]),
                    .weight_in(pe_weight_in[r][c]),
                    .psum_in(pe_psum_in[r][c]),
                    .input_out(pe_input_out[r][c]),
                    .weight_out(pe_weight_out[r][c]),
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