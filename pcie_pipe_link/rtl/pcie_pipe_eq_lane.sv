module pcie_pipe_eq_lane #(
    parameter int FS_LF_WD       = 6,
    parameter int DIRFEEDBACK_WD = 12,
    parameter int FOMFEEDBACK_WD = 8,
    parameter int TX_COEF_WD     = 18,
    parameter int TX_PSET_WD     = 6,
    parameter int RX_PSET_WD     = 3,
    parameter int EQ_CYCLES      = 8,
    parameter logic [FS_LF_WD-1:0] FS_VALUE = 6'd47,
    parameter logic [FS_LF_WD-1:0] LF_VALUE = 6'd15
) (
    input  logic                      pclk,
    input  logic                      phy_rst_n,
    input  logic [2:0]                rate,
    input  logic                      rxeqeval,
    input  logic                      rxeqinprogress,
    input  logic                      invalid_req,
    input  logic                      getlocal_pset_coef,
    input  logic [TX_PSET_WD-1:0]     local_pset_index,
    input  logic                      dirchange,
    input  logic [TX_COEF_WD-1:0]     txdeemph,
    input  logic [FS_LF_WD-1:0]       fs,
    input  logic [FS_LF_WD-1:0]       lf,
    input  logic [RX_PSET_WD-1:0]     rxpresethint,
    output logic [FS_LF_WD-1:0]       localfs,
    output logic [FS_LF_WD-1:0]       locallf,
    output logic [DIRFEEDBACK_WD-1:0] dirfeedback,
    output logic [FOMFEEDBACK_WD-1:0] fomfeedback,
    output logic [TX_COEF_WD-1:0]     local_tx_pset_coef,
    output logic                      local_tx_coef_valid,
    output logic                      phystatus_eq
);
    localparam int CNT_W = (EQ_CYCLES > 1) ? $clog2(EQ_CYCLES + 1) : 2;

    logic                 rxeqeval_d;
    logic                 eval_busy;
    logic [CNT_W-1:0]     eval_cnt;
    logic [FOMFEEDBACK_WD-1:0] fom_base;

    assign localfs  = FS_VALUE;
    assign locallf  = LF_VALUE;
    assign fom_base = (rate >= 3'd5) ? {{(FOMFEEDBACK_WD-8){1'b0}}, 8'h38} :
                                       {{(FOMFEEDBACK_WD-8){1'b0}}, 8'h20};

    // Standard PCIe Gen3..Gen6 Tx preset-to-{c+1, c0, c-1} lookup.
    function automatic logic [TX_COEF_WD-1:0] preset_to_coef(
        input logic [TX_PSET_WD-1:0] pset,
        input logic [FS_LF_WD-1:0]   fs_val
    );
        int unsigned fs_i;
        int unsigned cm1;
        int unsigned cp1;
        int unsigned c0;
        fs_i = int'(fs_val);
        case (pset[3:0])
            4'd0: begin cm1 = 0;                 cp1 = (fs_i + 2) / 4; end
            4'd1: begin cm1 = 0;                 cp1 = (fs_i + 3) / 6; end
            4'd2: begin cm1 = 0;                 cp1 = (fs_i + 2) / 5; end
            4'd3: begin cm1 = 0;                 cp1 = (fs_i + 4) / 8; end
            4'd4: begin cm1 = 0;                 cp1 = 0;              end
            4'd5: begin cm1 = (fs_i + 5) / 10;   cp1 = 0;              end
            4'd6: begin cm1 = (fs_i + 4) / 8;    cp1 = 0;              end
            4'd7: begin cm1 = (fs_i + 5) / 10;   cp1 = (fs_i + 2) / 5; end
            4'd8: begin cm1 = (fs_i + 4) / 8;    cp1 = (fs_i + 4) / 8; end
            4'd9: begin cm1 = (fs_i + 3) / 6;    cp1 = 0;              end
            default: begin cm1 = 0;              cp1 = (fs_i + 1) / 3; end
        endcase
        c0 = (fs_i > (cm1 + cp1)) ? (fs_i - cm1 - cp1) : 0;
        return {cp1[5:0], c0[5:0], cm1[5:0]};
    endfunction

    logic [TX_COEF_WD-1:0] unused_txdeemph;
    logic [FS_LF_WD-1:0]   unused_fs, unused_lf;
    logic [RX_PSET_WD-1:0] unused_rxpresethint;
    logic                  unused_misc;
    assign unused_txdeemph     = txdeemph;
    assign unused_fs           = fs;
    assign unused_lf           = lf;
    assign unused_rxpresethint = rxpresethint;
    assign unused_misc         = invalid_req ^ dirchange;

    always_ff @(posedge pclk or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            rxeqeval_d          <= 1'b0;
            eval_busy           <= 1'b0;
            eval_cnt            <= '0;
            dirfeedback         <= '0;
            fomfeedback         <= '0;
            local_tx_pset_coef  <= '0;
            local_tx_coef_valid <= 1'b0;
            phystatus_eq        <= 1'b0;
        end else begin
            rxeqeval_d          <= rxeqeval;
            local_tx_coef_valid <= 1'b0;
            phystatus_eq        <= 1'b0;

            if (getlocal_pset_coef) begin
                local_tx_pset_coef  <= preset_to_coef(local_pset_index, FS_VALUE);
                local_tx_coef_valid <= 1'b1;
            end

            if (!rxeqinprogress) begin
                eval_busy   <= 1'b0;
                eval_cnt    <= '0;
                dirfeedback <= '0;
                fomfeedback <= '0;
            end else if (!eval_busy && rxeqeval && !rxeqeval_d) begin
                if (EQ_CYCLES <= 1) begin
                    dirfeedback  <= {{(DIRFEEDBACK_WD-6){1'b0}}, 6'b00_00_00};
                    fomfeedback  <= fom_base;
                    phystatus_eq <= 1'b1;
                end else begin
                    eval_busy <= 1'b1;
                    eval_cnt  <= CNT_W'(EQ_CYCLES - 1);
                end
            end else if (eval_busy) begin
                if (eval_cnt == '0) begin
                    eval_busy    <= 1'b0;
                    dirfeedback  <= {{(DIRFEEDBACK_WD-6){1'b0}}, 6'b00_00_00};
                    fomfeedback  <= fom_base;
                    phystatus_eq <= 1'b1;
                end else begin
                    eval_cnt <= eval_cnt - CNT_W'(1);
                end
            end
        end
    end
endmodule
