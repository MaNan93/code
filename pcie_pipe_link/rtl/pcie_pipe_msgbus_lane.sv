module pcie_pipe_msgbus_lane #(
    parameter int FS_LF_WD       = 6,
    parameter int DIRFEEDBACK_WD = 12,
    parameter int FOMFEEDBACK_WD = 8,
    parameter int TX_COEF_WD     = 18,
    parameter int TX_PSET_WD     = 6
) (
    input  logic                      pclk,
    input  logic                      phy_rst_n,
    input  logic                      clock_ready,
    input  logic [2:0]                rate,
    input  logic [7:0]                mac_phy_messagebus,
    output logic [7:0]                phy_mac_messagebus,

    // Combined / MessageBus-decoded EQ & control signals
    output logic                      msg_rxeqeval,
    output logic                      msg_rxeqinprogress,
    output logic                      msg_invalid_req,
    output logic                      msg_getlocal_pset_coef,
    output logic [TX_PSET_WD-1:0]     msg_local_pset_index,
    output logic [FS_LF_WD-1:0]       msg_fs,
    output logic [FS_LF_WD-1:0]       msg_lf,
    output logic [TX_COEF_WD-1:0]     msg_txdeemph,
    output logic [2:0]                msg_txmargin,
    output logic                      msg_txswing,
    output logic                      msg_rxpolarity,
    output logic                      msg_eq_active,

    // From pcie_pipe_eq_lane
    input  logic [FS_LF_WD-1:0]       localfs,
    input  logic [FS_LF_WD-1:0]       locallf,
    input  logic                      eq_local_tx_coef_valid,
    input  logic [TX_COEF_WD-1:0]     eq_local_tx_pset_coef,
    input  logic                      eq_eval_done,
    input  logic [DIRFEEDBACK_WD-1:0] eq_dirfeedback,
    input  logic [FOMFEEDBACK_WD-1:0] eq_fomfeedback
);
    localparam logic [3:0] CMD_NOP    = 4'b0000;
    localparam logic [3:0] CMD_WR_UC  = 4'b0001;
    localparam logic [3:0] CMD_WR_C   = 4'b0010;
    localparam logic [3:0] CMD_RD     = 4'b0011;
    localparam logic [3:0] CMD_RD_CPL = 4'b0100;
    localparam logic [3:0] CMD_WR_ACK = 4'b0101;

    // -------------------------------------------------------------------------
    // 1. MAC -> PHY MessageBus Slave Receiver (supports sequential frames)
    // -------------------------------------------------------------------------
    logic [3:0]  rx_cmd;
    logic [1:0]  rx_cyc;
    logic [11:0] rx_addr;

    logic [3:0]  dec_cmd;
    logic [11:0] dec_addr;
    logic [7:0]  dec_data;
    logic        rx_is_last;

    assign rx_is_last =
        ((rx_cmd == CMD_WR_UC || rx_cmd == CMD_WR_C) && (rx_cyc == 2'd2)) ||
        ((rx_cmd == CMD_RD    || rx_cmd == CMD_RD_CPL) && (rx_cyc == 2'd1)) ||
        ((rx_cmd == CMD_WR_ACK || rx_cmd == CMD_NOP));

    // Staging registers for uncommitted writes before WR_C commits them
    logic                  stg_rxpolarity;
    logic                  stg_rxeqeval, stg_rxeqinprogress, stg_invalid_req;
    logic [TX_COEF_WD-1:0] stg_txdeemph;
    logic                  stg_getlocal;
    logic [TX_PSET_WD-1:0] stg_pset_idx;
    logic [FS_LF_WD-1:0]   stg_fs, stg_lf;
    logic [2:0]            stg_txmargin;
    logic                  stg_txswing;

    logic                  pending_wr_ack;
    logic                  pending_rd_cpl;
    logic [7:0]            rd_cpl_data;
    logic                  rx_saw_wr_ack;

    always_comb begin
        dec_cmd  = CMD_NOP;
        dec_addr = 12'h000;
        dec_data = 8'h00;
        if (rx_cmd == CMD_WR_ACK && rx_cyc == 2'd0) begin
            // handled directly on transition
        end
        if ((rx_cmd == CMD_WR_UC || rx_cmd == CMD_WR_C) && rx_cyc == 2'd2) begin
            dec_cmd  = rx_cmd;
            dec_addr = rx_addr;
            dec_data = mac_phy_messagebus;
        end else if (rx_cmd == CMD_RD && rx_cyc == 2'd1) begin
            dec_cmd  = CMD_RD;
            dec_addr = {rx_addr[11:8], mac_phy_messagebus};
        end
    end

    // Simple read lookup for MAC reads of PHY registers
    function automatic logic [7:0] read_phy_reg(input logic [11:0] addr);
        case (addr)
            12'h003: return {7'h0, msg_rxpolarity};
            12'h006: return {5'h0, msg_invalid_req, msg_rxeqinprogress, msg_rxeqeval};
            12'h402: return {2'h0, msg_txdeemph[5:0]};
            12'h403: return {2'h0, msg_txdeemph[11:6]};
            12'h404: return {2'h0, msg_txdeemph[17:12]};
            12'h405: return {2'h0, msg_local_pset_index};
            12'h406: return {2'h0, msg_fs};
            12'h407: return {2'h0, msg_lf};
            12'h408: return {4'h0, msg_txswing, msg_txmargin};
            default: return 8'h00;
        endcase
    endfunction

    // -------------------------------------------------------------------------
    // 2. PHY -> MAC Transmit Command Queue (Depth 16 circular buffer)
    // -------------------------------------------------------------------------
    localparam int Q_DEPTH = 16;
    logic [23:0] tx_q_mem [0:Q_DEPTH-1]; // {cmd[3:0], addr[11:0], data[7:0]}
    logic [4:0]  q_wr_ptr, q_rd_ptr;
    logic        q_empty, q_full;

    assign q_empty = (q_wr_ptr == q_rd_ptr);
    assign q_full  = (q_wr_ptr[4] != q_rd_ptr[4]) && (q_wr_ptr[3:0] == q_rd_ptr[3:0]);

    logic [3:0]  init_step;
    logic        init_done;
    logic [3:0]  ready_cnt;
    logic        boot_send_req;

    // FSM for driving phy_mac_messagebus
    logic [3:0]  tx_cmd;
    logic [11:0] tx_addr;
    logic [7:0]  tx_data;
    logic [1:0]  tx_cyc;
    logic        wait_wr_ack;
    logic        during_uc_wr;
    logic        tx_busy;

    assign tx_busy = (tx_cmd != CMD_NOP);

    // Next item push mux (boot sequence vs EQ/local-coef events)
    logic        push_en;
    logic [23:0] push_item;
    logic        coef_pend_0, coef_pend_1, coef_pend_2;
    logic        eval_pend_0, eval_pend_1;
    logic [TX_COEF_WD-1:0]     lat_coef;
    logic [FOMFEEDBACK_WD-1:0] lat_fom;
    logic [DIRFEEDBACK_WD-1:0] lat_dir;
    logic                      lat_eq_g6;

    always_comb begin
        push_en   = 1'b0;
        push_item = 24'h0;
        if (!q_full) begin
            if (boot_send_req && !init_done) begin
                push_en = 1'b1;
                case (init_step)
                    4'd0: push_item = {CMD_WR_UC, 12'h403, {2'b00, localfs}};
                    4'd1: push_item = {CMD_WR_C,  12'h404, {2'b00, locallf}};
                    4'd2: push_item = {CMD_WR_UC, 12'h405, {2'b00, localfs}};
                    4'd3: push_item = {CMD_WR_C,  12'h406, {2'b00, locallf}};
                    4'd4: push_item = {CMD_WR_UC, 12'h00C, {2'b00, localfs}};
                    default: push_item = {CMD_WR_C, 12'h00D, {2'b00, locallf}};
                endcase
            end else if (coef_pend_0) begin
                push_en   = 1'b1;
                push_item = {CMD_WR_UC, 12'h400, {2'b00, lat_coef[5:0]}};
            end else if (coef_pend_1) begin
                push_en   = 1'b1;
                push_item = {CMD_WR_UC, 12'h401, {2'b00, lat_coef[11:6]}};
            end else if (coef_pend_2) begin
                push_en   = 1'b1;
                push_item = {CMD_WR_C,  12'h402, {2'b00, lat_coef[17:12]}};
            end else if (eval_pend_0) begin
                push_en   = 1'b1;
                push_item = {CMD_WR_UC, 12'h00A, lat_eq_g6 ? lat_fom[7:0] : {2'b00, lat_fom[5:0]}};
            end else if (eval_pend_1) begin
                push_en   = 1'b1;
                push_item = {CMD_WR_C,  12'h00B, {2'b00, lat_dir[5:0]}};
            end
        end
    end

    always_ff @(posedge pclk or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            rx_cmd                 <= CMD_NOP;
            rx_cyc                 <= 2'd0;
            rx_addr                <= 12'h000;
            rx_saw_wr_ack          <= 1'b0;
            stg_rxpolarity         <= 1'b0;
            stg_rxeqeval           <= 1'b0;
            stg_rxeqinprogress     <= 1'b0;
            stg_invalid_req        <= 1'b0;
            stg_txdeemph           <= 18'd0;
            stg_getlocal           <= 1'b0;
            stg_pset_idx           <= '0;
            stg_fs                 <= '0;
            stg_lf                 <= '0;
            stg_txmargin           <= 3'd0;
            stg_txswing            <= 1'b0;
            msg_rxpolarity         <= 1'b0;
            msg_rxeqeval           <= 1'b0;
            msg_rxeqinprogress     <= 1'b0;
            msg_invalid_req        <= 1'b0;
            msg_txdeemph           <= 18'd0;
            msg_getlocal_pset_coef <= 1'b0;
            msg_local_pset_index   <= '0;
            msg_fs                 <= '0;
            msg_lf                 <= '0;
            msg_txmargin           <= 3'd0;
            msg_txswing            <= 1'b0;
            msg_eq_active          <= 1'b0;
            pending_wr_ack         <= 1'b0;
            pending_rd_cpl         <= 1'b0;
            rd_cpl_data            <= 8'h00;

            q_wr_ptr               <= '0;
            q_rd_ptr               <= '0;
            ready_cnt              <= '0;
            boot_send_req          <= 1'b0;
            init_step              <= '0;
            init_done              <= 1'b0;

            coef_pend_0            <= 1'b0;
            coef_pend_1            <= 1'b0;
            coef_pend_2            <= 1'b0;
            eval_pend_0            <= 1'b0;
            eval_pend_1            <= 1'b0;
            lat_coef               <= '0;
            lat_fom                <= '0;
            lat_dir                <= '0;
            lat_eq_g6              <= 1'b0;

            tx_cmd                 <= CMD_NOP;
            tx_addr                <= 12'h000;
            tx_data                <= 8'h00;
            tx_cyc                 <= 2'd0;
            wait_wr_ack            <= 1'b0;
            during_uc_wr           <= 1'b0;
            phy_mac_messagebus     <= 8'h00;
        end else begin
            msg_getlocal_pset_coef <= 1'b0;
            rx_saw_wr_ack          <= 1'b0;

            // --- RX Parser ---
            if (rx_is_last) begin
                rx_cmd <= mac_phy_messagebus[7:4];
                if (mac_phy_messagebus[7:4] == CMD_WR_ACK) begin
                    rx_cyc        <= 2'd0;
                    rx_saw_wr_ack <= 1'b1;
                end else if (mac_phy_messagebus[7:4] != CMD_NOP) begin
                    rx_cyc         <= 2'd1;
                    rx_addr[11:8]  <= mac_phy_messagebus[3:0];
                end else begin
                    rx_cyc <= 2'd0;
                end
            end else begin
                rx_cyc <= rx_cyc + 2'd1;
                if (rx_cyc == 2'd1) begin
                    rx_addr[7:0] <= mac_phy_messagebus;
                end
            end

            // Stage/commit incoming MAC register writes
            if (dec_cmd == CMD_WR_UC || dec_cmd == CMD_WR_C) begin
                logic                  n_rxpolarity;
                logic                  n_rxeqeval, n_rxeqinprogress, n_invalid_req;
                logic [TX_COEF_WD-1:0] n_txdeemph;
                logic                  n_getlocal;
                logic [TX_PSET_WD-1:0] n_pset_idx;
                logic [FS_LF_WD-1:0]   n_fs, n_lf;
                logic [2:0]            n_txmargin;
                logic                  n_txswing;

                n_rxpolarity     = stg_rxpolarity;
                n_rxeqeval       = stg_rxeqeval;
                n_rxeqinprogress = stg_rxeqinprogress;
                n_invalid_req    = stg_invalid_req;
                n_txdeemph       = stg_txdeemph;
                n_getlocal       = stg_getlocal;
                n_pset_idx       = stg_pset_idx;
                n_fs             = stg_fs;
                n_lf             = stg_lf;
                n_txmargin       = stg_txmargin;
                n_txswing        = stg_txswing;

                case (dec_addr)
                    12'h003: n_rxpolarity = dec_data[0];
                    12'h006: begin
                        n_rxeqeval       = dec_data[0];
                        n_rxeqinprogress = dec_data[1];
                        n_invalid_req    = dec_data[2];
                    end
                    12'h402: n_txdeemph[5:0]   = dec_data[5:0];
                    12'h403: n_txdeemph[11:6]  = dec_data[5:0];
                    12'h404: n_txdeemph[17:12] = dec_data[5:0];
                    12'h405: begin
                        n_getlocal = dec_data[7];
                        n_pset_idx = dec_data[TX_PSET_WD-1:0];
                    end
                    12'h406: n_fs       = dec_data[FS_LF_WD-1:0];
                    12'h407: n_lf       = dec_data[FS_LF_WD-1:0];
                    12'h408: begin
                        n_txmargin = dec_data[2:0];
                        n_txswing  = dec_data[3];
                    end
                    default: ;
                endcase

                if (dec_cmd == CMD_WR_C) begin
                    pending_wr_ack         <= 1'b1;
                    msg_rxpolarity         <= n_rxpolarity;
                    msg_rxeqeval           <= n_rxeqeval;
                    msg_rxeqinprogress     <= n_rxeqinprogress;
                    msg_invalid_req        <= n_invalid_req;
                    msg_txdeemph           <= n_txdeemph;
                    msg_local_pset_index   <= n_pset_idx;
                    msg_getlocal_pset_coef <= n_getlocal;
                    msg_fs                 <= n_fs;
                    msg_lf                 <= n_lf;
                    msg_txmargin           <= n_txmargin;
                    msg_txswing            <= n_txswing;
                    if (n_rxeqeval || (dec_addr == 12'h006)) begin
                        msg_eq_active <= 1'b1;
                    end
                    stg_getlocal           <= 1'b0;
                    stg_rxpolarity         <= n_rxpolarity;
                    stg_rxeqeval           <= n_rxeqeval;
                    stg_rxeqinprogress     <= n_rxeqinprogress;
                    stg_invalid_req        <= n_invalid_req;
                    stg_txdeemph           <= n_txdeemph;
                    stg_pset_idx           <= n_pset_idx;
                    stg_fs                 <= n_fs;
                    stg_lf                 <= n_lf;
                    stg_txmargin           <= n_txmargin;
                    stg_txswing            <= n_txswing;
                end else begin
                    stg_rxpolarity         <= n_rxpolarity;
                    stg_rxeqeval           <= n_rxeqeval;
                    stg_rxeqinprogress     <= n_rxeqinprogress;
                    stg_invalid_req        <= n_invalid_req;
                    stg_txdeemph           <= n_txdeemph;
                    stg_getlocal           <= n_getlocal;
                    stg_pset_idx           <= n_pset_idx;
                    stg_fs                 <= n_fs;
                    stg_lf                 <= n_lf;
                    stg_txmargin           <= n_txmargin;
                    stg_txswing            <= n_txswing;
                end
            end else if (dec_cmd == CMD_RD) begin
                pending_rd_cpl <= 1'b1;
                rd_cpl_data    <= read_phy_reg(dec_addr);
            end

            // --- Boot-time LocalFS/LF initialization ---
            if (!boot_send_req) begin
                if (clock_ready) begin
                    if (ready_cnt == 4'd8) begin
                        boot_send_req <= 1'b1;
                    end else begin
                        ready_cnt <= ready_cnt + 4'd1;
                    end
                end else begin
                    ready_cnt <= 4'd0;
                end
            end

            // --- Event capture into multi-word pend flags ---
            if (eq_local_tx_coef_valid) begin
                coef_pend_0 <= 1'b1;
                coef_pend_1 <= 1'b1;
                coef_pend_2 <= 1'b1;
                lat_coef    <= eq_local_tx_pset_coef;
            end
            if (eq_eval_done && msg_eq_active) begin
                eval_pend_0 <= 1'b1;
                eval_pend_1 <= 1'b1;
                lat_fom     <= eq_fomfeedback;
                lat_dir     <= eq_dirfeedback;
                lat_eq_g6   <= (rate >= 3'd5);
            end

            // --- Queue Push ---
            if (push_en) begin
                tx_q_mem[q_wr_ptr[3:0]] <= push_item;
                q_wr_ptr                <= q_wr_ptr + 5'd1;
                if (boot_send_req && !init_done) begin
                    if (init_step == 4'd5) init_done <= 1'b1;
                    else                   init_step <= init_step + 4'd1;
                end else if (coef_pend_0) begin
                    coef_pend_0 <= 1'b0;
                end else if (coef_pend_1) begin
                    coef_pend_1 <= 1'b0;
                end else if (coef_pend_2) begin
                    coef_pend_2 <= 1'b0;
                end else if (eval_pend_0) begin
                    eval_pend_0 <= 1'b0;
                end else if (eval_pend_1) begin
                    eval_pend_1 <= 1'b0;
                end
            end

            // Track MAC WR_ACK for our WR_C commands
            if (rx_saw_wr_ack) begin
                wait_wr_ack <= 1'b0;
            end

            // --- TX Output FSM ---
            if (tx_busy) begin
                if (tx_cmd == CMD_WR_ACK) begin
                    tx_cmd             <= CMD_NOP;
                    tx_cyc             <= 2'd0;
                    phy_mac_messagebus <= 8'h00;
                end else if (tx_cmd == CMD_RD_CPL) begin
                    phy_mac_messagebus <= tx_data;
                    tx_cmd             <= CMD_NOP;
                    tx_cyc             <= 2'd0;
                end else begin
                    if (tx_cyc == 2'd0) begin
                        phy_mac_messagebus <= tx_addr[7:0];
                        tx_cyc             <= 2'd1;
                    end else if (tx_cyc == 2'd1) begin
                        phy_mac_messagebus <= tx_data;
                        tx_cmd             <= CMD_NOP;
                        tx_cyc             <= 2'd0;
                        if (tx_cmd == CMD_WR_UC) begin
                            during_uc_wr <= 1'b1;
                        end else if (tx_cmd == CMD_WR_C) begin
                            during_uc_wr <= 1'b0;
                            wait_wr_ack  <= !rx_saw_wr_ack;
                        end
                    end
                end
            end else begin
                if (pending_wr_ack && !during_uc_wr) begin
                    pending_wr_ack     <= 1'b0;
                    tx_cmd             <= CMD_WR_ACK;
                    tx_cyc             <= 2'd0;
                    phy_mac_messagebus <= {CMD_WR_ACK, 4'h0};
                end else if (pending_rd_cpl && !during_uc_wr) begin
                    pending_rd_cpl     <= 1'b0;
                    tx_cmd             <= CMD_RD_CPL;
                    tx_data            <= rd_cpl_data;
                    tx_cyc             <= 2'd0;
                    phy_mac_messagebus <= {CMD_RD_CPL, 4'h0};
                end else if (!wait_wr_ack && !rx_saw_wr_ack && !q_empty) begin
                    logic [23:0] item;
                    item     = tx_q_mem[q_rd_ptr[3:0]];
                    q_rd_ptr <= q_rd_ptr + 5'd1;
                    tx_cmd             <= item[23:20];
                    tx_addr            <= item[19:8];
                    tx_data            <= item[7:0];
                    tx_cyc             <= 2'd0;
                    phy_mac_messagebus <= {item[23:20], item[19:16]};
                end else begin
                    phy_mac_messagebus <= 8'h00;
                end
            end
        end
    end
endmodule
