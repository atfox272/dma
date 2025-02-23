module reorder_buffer #(
    parameter FIX_ID        = 0,// Fixed ID with continous value from 0 to (ORD_DEPTH-1)
    parameter ORD_DEPTH     = 4,// Number of different IDs
    parameter BUF_DEPTH     = 16,
    parameter ID_W          = (FIX_ID == 1) ? $clog2(ORD_DEPTH) : 5,
    parameter DATA_W        = 32,
    parameter LEN_W         = 16
) (
    input                   clk,
    input                   rst_n,
    // Backward interface
    input   [ID_W-1:0]      bwd_id,
    input   [DATA_W-1:0]    bwd_data,
    input                   bwd_vld,
    output                  bwd_rdy,
    // Forward interface 
    output  [DATA_W-1:0]    fwd_data,
    output                  fwd_vld,
    input                   fwd_rdy,
    // Order
    input   [ID_W-1:0]      ord_id,
    input   [LEN_W-1:0]     ord_len,    // length = ord_len - 1
    input                   ord_vld,
    output                  ord_rdy,
    // ID list
    input   [ID_W-1:0]      buf_id  [0:ORD_DEPTH-1]
);
    // Local parameters 
    localparam ORD_INFO_W   = ID_W + LEN_W;
    localparam ID_ENC_W     = $clog2(ORD_DEPTH);
    // Internal variables 
    genvar buf_idx;
    // Internal variables
    wire    [ID_ENC_W-1:0]  bwd_id_enc; // Encode to: continous ID
    wire                    bwd_id_ext; // Backwarad ID exists
    wire    [ORD_DEPTH-1:0] db_id_map;
    wire                    db_bwd_vld  [0:ORD_DEPTH-1];
    wire                    db_bwd_rdy  [0:ORD_DEPTH-1];
    
    wire    [DATA_W-1:0]    db_fwd_dat  [0:ORD_DEPTH-1];
    wire                    db_fwd_vld  [0:ORD_DEPTH-1];
    wire                    db_fwd_rdy  [0:ORD_DEPTH-1];
    wire                    fwd_hsk;
    
    wire    [ID_W-1:0]      fwd_ord_id;
    wire    [LEN_W-1:0]     fwd_ord_len;
    wire                    fwd_ord_vld;
    wire                    fwd_ord_rdy;
    wire    [ORD_DEPTH-1:0] fwd_ord_id_map;
    wire    [ID_ENC_W-1:0]  fwd_ord_id_enc; // Encode to: continous ID
    wire                    ord_hsk;
    wire                    fwd_ord_id_ext;
    
    reg     [LEN_W-1:0]     fwd_dat_cnt;
    // Module instantiation
    // -- Order buffer
    sync_fifo #(
        .FIFO_TYPE      (1),    // Normal type
        .DATA_WIDTH     (ORD_INFO_W),
        .FIFO_DEPTH     (BUF_DEPTH)
    ) ord_buf (
        .clk            (clk),
        .data_i         ({ord_id,       ord_len}),
        .wr_valid_i     (ord_vld),
        .wr_ready_o     (ord_rdy),
        .data_o         ({fwd_ord_id,   fwd_ord_len}),
        .rd_valid_i     (fwd_ord_rdy),
        .rd_ready_o     (fwd_ord_vld),
        .empty_o        (),
        .full_o         (),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );
generate
for (buf_idx = 0; buf_idx < ORD_DEPTH; buf_idx++) begin : DATA_BUF
    // -- Data buffer
    sync_fifo #(
        .FIFO_TYPE      (1),    // Normal type
        .DATA_WIDTH     (DATA_W),
        .FIFO_DEPTH     (BUF_DEPTH)
    ) dat_buf (
        .clk            (clk),
        .data_i         (bwd_data),
        .wr_valid_i     (db_bwd_vld[buf_idx]),
        .wr_ready_o     (db_bwd_rdy[buf_idx]),
        .data_o         (db_fwd_dat[buf_idx]),
        .rd_valid_i     (db_fwd_rdy[buf_idx]),
        .rd_ready_o     (db_fwd_vld[buf_idx]),
        .empty_o        (),
        .full_o         (),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );
end
endgenerate
    // Combinational logic
    assign fwd_hsk      = fwd_vld & fwd_rdy;
    assign ord_hsk      = fwd_ord_vld & fwd_ord_rdy;
    assign fwd_ord_rdy  = ~|(fwd_dat_cnt^fwd_ord_len) & fwd_hsk;    // Last data is handshaking -> Pop Order
    assign bwd_rdy      = db_bwd_rdy[bwd_id_enc] & bwd_id_ext;
    assign fwd_data     = db_fwd_dat[fwd_ord_id_enc];
    assign fwd_vld      = db_fwd_vld[fwd_ord_id_enc] & fwd_ord_vld & fwd_ord_id_ext;
    assign bwd_id_ext   = |db_id_map;
    assign fwd_ord_id_ext = |fwd_ord_id_map;
generate
for (buf_idx = 0; buf_idx < ORD_DEPTH; buf_idx++) begin : CTRL_MAP
    assign db_bwd_vld[buf_idx]  = db_id_map[buf_idx] & bwd_vld & bwd_id_ext;
    assign db_fwd_rdy[buf_idx]  = fwd_ord_id_map[buf_idx] & fwd_rdy; 
end
endgenerate
    // Flip-flop
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            fwd_dat_cnt <= {LEN_W{1'b0}};
        end
        else begin
            if(ord_hsk) begin
                fwd_dat_cnt <= {LEN_W{1'b0}};
            end
            else begin
                fwd_dat_cnt <= fwd_dat_cnt + fwd_hsk;
            end
        end
    end

generate
if(FIX_ID == 0) begin : DYNAMICS_ID
    // Module instantiation 
    // -- Backward ID encoder
    onehot_encoder #(
        .INPUT_W        (ORD_DEPTH),
        .OUTPUT_W       (ID_ENC_W)
    ) bwd_id_encoder (
        .i              (db_id_map),
        .o              (bwd_id_enc)
    );
    // -- Order ID encoder
    onehot_encoder #(
        .INPUT_W        (ORD_DEPTH),
        .OUTPUT_W       (ID_ENC_W)
    ) ord_id_encoder (
        .i              (fwd_ord_id_map),
        .o              (fwd_ord_id_enc)
    );
    // Combinational logic
    for (buf_idx = 0; buf_idx < ORD_DEPTH; buf_idx++) begin : ID_MAP
        assign db_id_map[buf_idx]       = (~|(buf_id[buf_idx]^bwd_id));
        assign fwd_ord_id_map[buf_idx]  = (~|(buf_id[buf_idx]^fwd_ord_id));
    end
end
else begin : FIXED_ID
    // Combinational logic
    assign bwd_id_enc       = bwd_id;
    assign fwd_ord_id_enc   = fwd_ord_id;
    for (buf_idx = 0; buf_idx < ORD_DEPTH; buf_idx++) begin : ID_MAP
        assign db_id_map[buf_idx]       = buf_idx == bwd_id;
        assign fwd_ord_id_map[buf_idx]  = buf_idx == fwd_ord_id;
    end
end
endgenerate

endmodule