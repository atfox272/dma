module splitter #(
    parameter DATA_W = 32
) (
    input                   clk,
    input                   rst_n,
    // Backward interface
    input   [DATA_W-1:0]    bwd_data,
    input                   bwd_vld,
    output                  bwd_rdy,
    input   [DATA_W-1:0]    rem_data,   // remain data
    input                   rem_flg,    // remain flag
    // Forward interface
    output  [DATA_W-1:0]    fwd_data,
    output                  fwd_vld,
    input                   fwd_rdy
);
    // Internal signals 
    wire                    bwd_hsk;
    wire                    fwd_hsk;
    wire                    data_wr_en;
    reg     [DATA_W-1:0]    data_buf;
    reg                     data_exist;
    // Combinational logic
    assign bwd_rdy      = (~rem_flg & fwd_hsk) | (~data_exist); // (Forwarder sends the last remaining data) or (data does not exist in the splitter)
    assign fwd_data     = data_buf;
    assign fwd_vld      = data_exist;
    assign data_wr_en   = rem_flg ? fwd_hsk : bwd_hsk;
    assign bwd_hsk      = bwd_vld & bwd_rdy;
    assign fwd_hsk      = fwd_vld & fwd_rdy;
    // Flip-flop
    always @(posedge clk) begin
        if(data_wr_en) begin
            data_buf <= (rem_flg) ? rem_data : bwd_data;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            data_exist <= 1'b0;
        end
        else if (bwd_hsk | fwd_hsk) begin
            data_exist <= rem_flg | bwd_hsk;
        end
    end

endmodule
