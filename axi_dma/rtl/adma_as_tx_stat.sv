module adma_as_tx_stat #(
    // DMA
    parameter DMA_LENGTH_W      = 16
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
    // Internal signal
    wire    [DMA_LENGTH_W-1:0]  atx_done_cnt_nxt;
    reg     [DMA_LENGTH_W-1:0]  atx_start_cnt;
    reg                         atx_last_flg;
    reg     [DMA_LENGTH_W-1:0]  atx_done_cnt;
    // Combinational logic
    assign atx_done_cnt_nxt = atx_done_cnt + atx_done;
    assign tx_done = ~|(atx_start_cnt^atx_done_cnt_nxt) & atx_last_flg; // The last AXI transaction has been started, and it's done now
    // Flip-flop
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            atx_start_cnt <= {DMA_LENGTH_W{1'b0}};
        end
        else begin
            if(tx_done) begin
                atx_start_cnt <= {DMA_LENGTH_W{1'b0}};                
            end
            else begin
                atx_start_cnt <= atx_start_cnt + atx_start;
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            atx_last_flg <= 1'b0;
        end
        else begin
            if(tx_done) begin
                atx_last_flg <= 1'b0;
            end
            else if(atx_start) begin
                atx_last_flg <= atx_start_last;
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
                if(tx_done) begin
                    atx_done_cnt <= {DMA_LENGTH_W{1'b0}};                
                end
                else begin
                    atx_done_cnt <= atx_done_cnt_nxt;
                end
            end
        end
    end

endmodule