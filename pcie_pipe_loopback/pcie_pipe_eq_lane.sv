module pcie_pipe_eq_lane #(
    parameter integer EQ_CYCLES = 8
)(
    input logic pclk,
    input logic phy_rst_n,
    input logic [2:0] mac_phy_rate,
    input logic mac_phy_rxeqeval,
    input logic mac_phy_rxeqinprogress,
    input logic mac_phy_invalid_req,
    input logic mac_phy_getlocal_pset_coef,
    input logic [4:0] mac_phy_local_pset_index,
    input logic mac_phy_dirchange,
    input logic [17:0] mac_phy_txdeemph,
    output logic [5:0] phy_mac_localfs,
    output logic [5:0] phy_mac_locallf,
    output logic [5:0] phy_mac_dirfeedback,
    output logic [7:0] phy_mac_fomfeedback,
    output logic [17:0] phy_mac_local_tx_pset_coef,
    output logic phy_mac_local_tx_coef_valid,
    output logic eq_due
);
    function automatic [17:0] preset_coeff(input [4:0] index, input [2:0] rate);
        integer preset, fs, lf, pre, post, main;
        begin
            preset = (rate >= 3 && index != 31) ? index-11 : index;
            fs = (rate >= 3) ? 47 : 48;
            lf = (rate >= 3) ? 15 : 18;
            pre=0; post=0;
            case (preset)
                0: post=(fs+2)/4;
                1: post=(fs+3)/6;
                2: post=(fs+2)/5;
                3: post=(fs+4)/8;
                4: begin pre=0; post=0; end
                5: pre=(fs+5)/10;
                6: pre=(fs+4)/8;
                7: begin pre=(fs+5)/10; post=(fs+2)/5; end
                8: begin pre=(fs+4)/8; post=(fs+4)/8; end
                9: pre=(fs+3)/6;
                10: post=(fs-lf)/2;
                default: begin pre=0; post=0; end
            endcase
            main=(preset >= 0 && preset <= 10) ? fs-pre-post : 0;
            preset_coeff={post[5:0],main[5:0],pre[5:0]};
        end
    endfunction
    localparam integer COUNT_W = (EQ_CYCLES > 1) ? $clog2(EQ_CYCLES) : 1;
    logic eval_q, query_q, eval_busy;
    logic [COUNT_W-1:0] eval_count;
    logic [1:0] query_delay;
    logic [4:0] query_index;
    logic [2:0] query_rate;
    assign phy_mac_localfs = mac_phy_rate >= 3 ? 6'd47 : 6'd48;
    assign phy_mac_locallf = mac_phy_rate >= 3 ? 6'd15 : 6'd18;
    assign phy_mac_dirfeedback = '0;
    // RxEqInProgress, InvalidReq, DirChange and TxDeemph have no separate completion
    // handshake in this parallel PIPE mode. Evaluation always returns an ideal-channel result.
    always @(posedge pclk or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            eval_q <= 0;
            query_q <= 0;
            eval_busy <= 0;
            eval_count <= 0;
            eq_due <= 0;
            query_delay <= 0;
            query_index <= 0;
            query_rate <= 0;
            phy_mac_local_tx_pset_coef <= 0;
            phy_mac_local_tx_coef_valid <= 0;
            phy_mac_fomfeedback <= 0;
        end else begin
            eval_q <= mac_phy_rxeqeval;
            query_q <= mac_phy_getlocal_pset_coef;
            query_delay <= {query_delay[0],mac_phy_getlocal_pset_coef & ~query_q};
            phy_mac_local_tx_coef_valid <= query_delay[1];
            if (mac_phy_getlocal_pset_coef && !query_q) begin
                query_index <= mac_phy_local_pset_index;
                query_rate <= mac_phy_rate;
            end
            if (query_delay[1]) begin
                phy_mac_local_tx_pset_coef <= preset_coeff(query_index,query_rate);
            end
            eq_due <= 0;
            if (mac_phy_rxeqeval && !eval_q) begin
                eval_busy <= 1;
                eval_count <= EQ_CYCLES-1;
            end else if (eval_busy) begin
                if (!mac_phy_rxeqeval || eval_count==0) begin
                    eval_busy <= 0;
                    eq_due <= 1;
                    phy_mac_fomfeedback <= 8'hff;
                end else begin
                    eval_count <= eval_count-1'b1;
                end
            end
        end
    end
endmodule
