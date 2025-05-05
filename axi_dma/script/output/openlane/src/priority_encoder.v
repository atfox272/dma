module priority_encoder
#(
    parameter INPUT_W = 8,
    // Do not modify below parameter
    parameter OUTPUT_W = $clog2(INPUT_W)
)
(
    input   [INPUT_W-1:0]   i,
    output  [OUTPUT_W-1:0]  o
);
    // Internal variable
    genvar idx;
    
    // Internal signal declaration
    wire [OUTPUT_W-1:0] mux_seq [INPUT_W-1:0];
    
    // Combinational logic
    generate
        for(idx = 0; idx < INPUT_W; idx = idx + 1) begin : MUX_SEQ_GEN
            if(idx == 0) begin
                assign mux_seq[idx] = (i[idx] == 1'b1) ? idx : {OUTPUT_W{1'b0}};
            end
            else begin
                assign mux_seq[idx] = (i[idx] == 1'b1) ? idx : mux_seq[idx-1];
            end
        end
    endgenerate
    assign o = mux_seq[INPUT_W-1];
endmodule
