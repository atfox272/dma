module adma_cm_xfer_stat
#(
    parameter DMA_DESC_DEPTH    = 4    // The maximum number of descriptors in each channel 
) (
    input                           clk,
    input                           rst_n,
    // Transfer control
    input   [DMA_DESC_DEPTH-1:0]    xfer_done_clear,
    input   [DMA_DESC_DEPTH-1:0]    xfer_done_set,
    output  [DMA_DESC_DEPTH-1:0]    xfer_done,
    // Transfer mode
    input                           chn_xfer_cyclic
);
    // Local parameters
    localparam  DONE_ST     = 1'b1;
    localparam  NOT_DONE_ST = 1'b0;

    // Internal variables 
    genvar xfer_idx;

    // Internal signal
    wire    [DMA_DESC_DEPTH-1:0]    xfer_done_clr_in;
    reg     [DMA_DESC_DEPTH-1:0]    xfer_stat;

    // Combinational logic
    assign xfer_done        = xfer_stat;
    assign xfer_done_clr_in = xfer_done_clear | chn_xfer_cyclic; // In Cyclic mode, the done_clear signal always assert -> To generate interrupt/done signals when the transfer is repeated
generate
for (xfer_idx = 0; xfer_idx < DMA_DESC_DEPTH; xfer_idx = xfer_idx + 1) begin : XFER_STAT_GEN
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            xfer_stat[xfer_idx] <= NOT_DONE_ST;
        end
        else begin
            if (xfer_done_set[xfer_idx]) begin  // done_set signal must have HIGHER priority -> Because done_clear always HIGH in Cyclic mode
                xfer_stat[xfer_idx] <= DONE_ST;
            end
            else if (xfer_done_clr_in[xfer_idx]) begin
                xfer_stat[xfer_idx] <= NOT_DONE_ST;
            end
        end
    end
end
endgenerate
endmodule