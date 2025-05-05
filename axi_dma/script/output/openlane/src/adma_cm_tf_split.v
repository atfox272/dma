module adma_cm_tf_split
#(
    // Queue
    parameter DMA_DESC_DEPTH    = 4,    // The maximum number of descriptors in each channel
    // Descriptor 
    parameter SRC_ADDR_W        = 32,
    parameter DST_ADDR_W        = 32,
    parameter DMA_LENGTH_W      = 16,
    // Do not modify
    parameter DMA_XFER_ID_W     = $clog2(DMA_DESC_DEPTH) 
) (
    input                       clk,
    input                       rst_n,
    // Transfer informarion in process
    input   [DMA_XFER_ID_W-1:0] xfer_id,
    input   [SRC_ADDR_W-1:0]    src_addr,
    input   [DST_ADDR_W-1:0]    dst_addr,
    input   [DMA_LENGTH_W-1:0]  xfer_xlen,
    input   [DMA_LENGTH_W-1:0]  xfer_ylen,
    input   [DMA_LENGTH_W-1:0]  src_stride,
    input   [DMA_LENGTH_W-1:0]  dst_stride,
    input                       xfer_vld,
    output                      xfer_rdy,
    input   [1:0]               atx_src_burst,  
    input   [1:0]               atx_dst_burst,  
    // Transaction information
    output  [SRC_ADDR_W-1:0]    tx_src_addr,
    output  [DST_ADDR_W-1:0]    tx_dst_addr,
    output  [DMA_LENGTH_W-1:0]  tx_len,
    output                      tx_vld,
    input                       tx_rdy,
    // Transaction control
    input                       tx_done,
    // Transfer control
    output  [DMA_DESC_DEPTH-1:0]xfer_done_set
);
    // Local parameters
    localparam DESC_INFO_W  = DMA_XFER_ID_W + SRC_ADDR_W + DST_ADDR_W + DMA_LENGTH_W + DMA_LENGTH_W + DMA_LENGTH_W + DMA_LENGTH_W;
    localparam BURST_FIX    = 2'b00;
    localparam BURST_INCR   = 2'b01;
    
    // Internal variables
    genvar  xfer_idx;

    // Internal signals
    wire                        bwd_xfer_hsk;   // Backward transfer handshaking
    wire                        fwd_tx_hsk;     // Forward transaction handshaking
    wire    [DMA_XFER_ID_W-1:0] rem_i_xfer_id;
    wire    [SRC_ADDR_W-1:0]    rem_i_src_addr;
    wire    [DST_ADDR_W-1:0]    rem_i_dst_addr;
    wire    [DMA_LENGTH_W-1:0]  rem_i_xfer_xlen;
    wire    [DMA_LENGTH_W-1:0]  rem_i_xfer_ylen;
    wire    [DMA_LENGTH_W-1:0]  rem_i_src_stride;
    wire    [DMA_LENGTH_W-1:0]  rem_i_dst_stride;
    wire                        rem_i_xfer_vld;
    wire    [DMA_XFER_ID_W-1:0] rem_o_xfer_id;
    wire    [SRC_ADDR_W-1:0]    rem_o_src_addr;
    wire    [DST_ADDR_W-1:0]    rem_o_dst_addr;
    wire    [DMA_LENGTH_W-1:0]  rem_o_xfer_xlen;
    wire    [DMA_LENGTH_W-1:0]  rem_o_xfer_ylen;
    wire    [DMA_LENGTH_W-1:0]  rem_o_src_stride;
    wire    [DMA_LENGTH_W-1:0]  rem_o_dst_stride;
    wire                        rem_o_xfer_vld;
    wire                        rem_o_xfer_rdy;
    wire    [DMA_XFER_ID_W-1:0] new_xfer_id;
    wire    [SRC_ADDR_W-1:0]    new_src_addr;
    wire    [DST_ADDR_W-1:0]    new_dst_addr;
    wire    [DMA_LENGTH_W-1:0]  new_xfer_xlen;
    wire    [DMA_LENGTH_W-1:0]  new_xfer_ylen;
    wire    [DMA_LENGTH_W-1:0]  new_src_stride;
    wire    [DMA_LENGTH_W-1:0]  new_dst_stride;
    wire                        new_xfer_vld;
    wire                        new_xfer_rdy;

    reg     [DMA_LENGTH_W-1:0]  proc_tx_num;
    reg     [DMA_LENGTH_W-1:0]  done_tx_num;

    // Module instantiation
    // -- Remainder of the Transfer
    sync_fifo #(
        .FIFO_TYPE      (1),// Normal type
        .DATA_WIDTH     (DESC_INFO_W),
        .FIFO_DEPTH     (2) // Max usage depth is 2
    ) rem_xfer (
        .clk            (clk),
        .data_i         ({rem_i_xfer_id, rem_i_src_addr, rem_i_dst_addr, rem_i_xfer_xlen, rem_i_xfer_ylen, rem_i_src_stride, rem_i_dst_stride}),
        .wr_valid_i     (rem_i_xfer_vld),
        .wr_ready_o     (),     // Read and Write occur in same cycle -> Never full
        .data_o         ({rem_o_xfer_id, rem_o_src_addr, rem_o_dst_addr, rem_o_xfer_xlen, rem_o_xfer_ylen, rem_o_src_stride, rem_o_dst_stride}),
        .rd_valid_i     (rem_o_xfer_rdy),
        .rd_ready_o     (rem_o_xfer_vld),
        .empty_o        (),
        .full_o         (),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );

    // Combinational logic
    // -- Before splitting
    assign bwd_xfer_hsk     = xfer_vld & xfer_rdy;  // Backward transfer handshaking
    assign fwd_tx_hsk       = tx_vld & tx_rdy;
    assign new_xfer_id      = rem_o_xfer_vld ? rem_o_xfer_id    : xfer_id;
    assign new_src_addr     = rem_o_xfer_vld ? rem_o_src_addr   : src_addr;
    assign new_dst_addr     = rem_o_xfer_vld ? rem_o_dst_addr   : dst_addr;
    assign new_xfer_xlen    = rem_o_xfer_vld ? rem_o_xfer_xlen  : xfer_xlen;
    assign new_xfer_ylen    = rem_o_xfer_vld ? rem_o_xfer_ylen  : xfer_ylen;
    assign new_src_stride   = rem_o_xfer_vld ? rem_o_src_stride : src_stride;
    assign new_dst_stride   = rem_o_xfer_vld ? rem_o_dst_stride : dst_stride;
    assign new_xfer_vld     = rem_o_xfer_vld ? rem_o_xfer_vld   : (xfer_vld & (~|proc_tx_num));   // "xfer_vld & (~|proc_tx_num)" - The first TX has been sent --> when the MUX turns back to processed XFER register, the valid signal whould be LOW  
    assign new_xfer_rdy     = tx_rdy;
    // -- After splitting
    assign rem_i_xfer_id    = new_xfer_id;
    assign rem_i_xfer_xlen  = new_xfer_xlen;
    assign rem_i_src_stride = new_src_stride;
    assign rem_i_dst_stride = new_dst_stride;
    assign rem_i_dst_addr   = new_dst_addr + (rem_i_dst_stride & {DMA_LENGTH_W{~|(atx_dst_burst^BURST_INCR)}}); // If (in burst increment mode) -> new_dst_addr = old_dst_addr + dst_stride
    assign rem_i_src_addr   = new_src_addr + (rem_i_src_stride & {DMA_LENGTH_W{~|(atx_src_burst^BURST_INCR)}}); // If (in burst increment mode) -> new_src_addr = old_src_addr + src_stride
    assign rem_i_xfer_ylen  = new_xfer_ylen - 1'b1;
    assign rem_i_xfer_vld   = (|new_xfer_ylen) & new_xfer_vld; // Asssert if (y_length != 0) & (new sub-xfer is valid)
    assign rem_o_xfer_rdy   = new_xfer_rdy & rem_o_xfer_vld;
    // -- Transaction gen
    assign tx_src_addr      = new_src_addr;
    assign tx_dst_addr      = new_dst_addr;
    assign tx_len           = new_xfer_xlen;
    assign tx_vld           = new_xfer_vld;
    // -- Backward Transfer
    assign xfer_rdy         = ~|(proc_tx_num^(done_tx_num+1'b1)) & tx_done; //  The last TX has been done -> Pop transfer when the (Transfer done completely) 
generate
for(xfer_idx = 0; xfer_idx < DMA_DESC_DEPTH; xfer_idx = xfer_idx + 1) begin : XFER_DONE_LOGIC
    assign xfer_done_set[xfer_idx] = (xfer_idx == new_xfer_id) & xfer_rdy;  // Map to the corresponding ID of TRANSFER_DONE register 
end
endgenerate
    
    // Flip-flop 
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            proc_tx_num <= {DMA_LENGTH_W{1'b0}};
        end
        else begin
            if(bwd_xfer_hsk) begin
                proc_tx_num <= {DMA_LENGTH_W{1'b0}};
            end
            else begin
                proc_tx_num <= proc_tx_num + fwd_tx_hsk;    // Increases when TX handshakes
            end
        end
    end 
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            done_tx_num <= {DMA_LENGTH_W{1'b0}};
        end
        else begin
            if(bwd_xfer_hsk) begin
                done_tx_num <= {DMA_LENGTH_W{1'b0}};
            end
            else begin
                done_tx_num <= done_tx_num + tx_done;    // Increases when TX done
            end
        end
    end
endmodule