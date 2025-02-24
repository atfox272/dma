module adma_as_tx_stat #(
    // DMA
    parameter DMA_LENGTH_W      = 16,
    parameter ATX_NUM_OSTD      = 4 // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
) (
    input   clk,
    input   rst_n,
    // AXI Transaction control
    input   atx_start,
    input   atx_start_last,
    input   atx_done,
    // Transaction control
    output  tx_done
);
    // Local parameters 
    localparam TX_STAT_AMT = (ATX_NUM_OSTD > 1) ? ATX_NUM_OSTD : 2; // Minimun TX status buffer is 2
    // Internal signal
    wire    [DMA_LENGTH_W-1:0]  atx_done_cnt_nxt;
    wire    [DMA_LENGTH_W-1:0]  atx_start_cnt_nxt;
    wire                        atx_last_hsk;
    wire    [DMA_LENGTH_W-1:0]  tx_stat_num_atx; // Number of ATXs in a TX 
    wire                        tx_stat_vld;
    wire                        tx_stat_rdy;
    reg     [DMA_LENGTH_W-1:0]  atx_start_cnt;
    reg     [DMA_LENGTH_W-1:0]  atx_done_cnt;
    // Module instantiation
    sync_fifo #(
        .FIFO_TYPE      (1),
        .DATA_WIDTH     (DMA_LENGTH_W),
        .FIFO_DEPTH     (TX_STAT_AMT) // The depth of this FIFO must greater than or equal to the number of outstanding transaction (number of outstanding transaction = 2)
    ) tx_stat_buf (
        .clk            (clk),
        .data_i         (atx_start_cnt_nxt),
        .wr_valid_i     (atx_last_hsk), // Record when the all atx of a tx have been started
        .wr_ready_o     (),  // The number of outstanding AXI transaction in Data move is 2, while this buffer can handle up to 4 TXs
        .data_o         (tx_stat_num_atx),
        .rd_valid_i     (tx_done),
        .rd_ready_o     (tx_stat_vld),   // Pop the TX state data if the TX has just been completed
        .empty_o        (),
        .full_o         (),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );
    // Combinational logic
    assign atx_done_cnt_nxt = atx_done_cnt + atx_done;
    assign atx_start_cnt_nxt = atx_start_cnt + atx_start;
    assign atx_last_hsk = atx_start & atx_start_last;
    assign tx_done = ~|(tx_stat_num_atx^atx_done_cnt_nxt) & tx_stat_vld; // The last AXI transaction has been started, and it's done now
    // Flip-flop
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            atx_start_cnt <= {DMA_LENGTH_W{1'b0}};
        end
        else begin
            if(atx_last_hsk) begin
                atx_start_cnt <= {DMA_LENGTH_W{1'b0}};                
            end
            else begin
                atx_start_cnt <= atx_start_cnt_nxt;
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
           atx_done_cnt <= {DMA_LENGTH_W{1'b0}}; 
        end
        else begin
            if(tx_done) begin
                atx_done_cnt <= {DMA_LENGTH_W{1'b0}};                
            end
            else begin
                atx_done_cnt <= atx_done_cnt_nxt;
            end
        end
    end

endmodule