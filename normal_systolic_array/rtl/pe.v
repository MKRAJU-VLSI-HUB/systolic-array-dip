`timescale 1ns / 1ps
`default_nettype none

module pe #(
    parameter integer DATA_WIDTH = 8,
    parameter integer ACC_WIDTH  = 32
) (
    input  wire                          clk,
    input  wire                          rst_n,   // active-low synchronous-ish reset
    input  wire                          en,      // accumulate enable
    input  wire                          clear,   // synchronous accumulator clear
    input  wire signed [DATA_WIDTH-1:0]  a_in,
    input  wire signed [DATA_WIDTH-1:0]  b_in,
    output reg  signed [DATA_WIDTH-1:0]  a_out,   // a_in delayed by one cycle
    output reg  signed [DATA_WIDTH-1:0]  b_out,   // b_in delayed by one cycle
    output wire signed [ACC_WIDTH-1:0]   c_out    // current accumulator value
);

    reg signed [ACC_WIDTH-1:0] acc;
    assign c_out = acc;

    // Sign-extended product, sized to avoid truncation before accumulation.
    wire signed [2*DATA_WIDTH-1:0] product = a_in * b_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc   <= {ACC_WIDTH{1'b0}};
            a_out <= {DATA_WIDTH{1'b0}};
            b_out <= {DATA_WIDTH{1'b0}};
        end else begin
            if (clear)
                acc <= {ACC_WIDTH{1'b0}};
            else if (en)
                acc <= acc + product;     // accumulate this cycle's MAC

            // operands march one PE per clock (systolic propagation)
            a_out <= a_in;
            b_out <= b_in;
        end
    end

endmodule

`default_nettype wire