module adma_dm_data_buf
#(
    // AXI Interface
    parameter ATX_SRC_DATA_W    = 256,
    parameter ATX_DST_DATA_W    = 256
) (
    input                           clk,
    input                           rst_n,
    // Source data
    input   [ATX_SRC_DATA_W-1:0]    src_data,
    input                           src_vld,
    output                          src_rdy,
    // Destination data
    output  [ATX_DST_DATA_W-1:0]    dst_data,
    output                          dst_vld,
    input                           dst_rdy
);
    // TODO: Update later
    // -> Upsizer / Downsizer
    // -> FIFO synchronizer
    // In the first version, I just store and forward the data from source to destination. Therefor, you can bypass this :v 

    sync_fifo #(
        .FIFO_TYPE      (1),    // Normal type
        .DATA_WIDTH     (ATX_SRC_DATA_W),
        .IN_DATA_WIDTH  (ATX_SRC_DATA_W),
        .OUT_DATA_WIDTH (ATX_DST_DATA_W),
        .FIFO_DEPTH     (2)
    ) fwd_buffer (
        .clk            (clk),
        .data_i         (src_data),
        .wr_valid_i     (src_vld),
        .wr_ready_o     (src_rdy),
        .data_o         (dst_data),
        .rd_ready_o     (dst_vld),
        .rd_valid_i     (dst_rdy),
        .empty_o        (),
        .full_o         (),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );
    
endmodule