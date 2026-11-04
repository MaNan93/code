// ------------------------------------------------------------------------------
// 
// Copyright 2002 - 2024 Synopsys, INC.
// 
// This Synopsys IP and all associated documentation are proprietary to
// Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
// written license agreement with Synopsys, Inc. All other use, reproduction,
// modification, or distribution of the Synopsys IP or the associated
// documentation is strictly prohibited.
// Inclusivity & Diversity - Visit SolvNetPlus to read the "Synopsys Statement on
//            Inclusivity and Diversity" (Refer to article 000036315 at
//                        https://solvnetplus.synopsys.com)
// 
// Component Name   : DWC_pcie_ctl_cxl
// Component Version: 6.14a-lca02
// Release Type     : LCA
// Build ID         : 69.19.33.11.PCIeParseConfig_1.PCIeSimulate_24.PCIeTbCommon_85.SNPSPHYSetup_21
// ------------------------------------------------------------------------------

// -------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/smlh_margin_slv.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description: Receiver Margining adapter for pipe if and generate the status
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module smlh_margin_slv #(
    parameter INST = 0,
    parameter TP   = `TP,
    parameter NB   = `CX_NB,               // Number of symbols (bytes) per clock cycle
    parameter REGOUT = 0
)
                        (
    // Input
    input               core_clk,
    input               core_rst_n,
    input   [2:0]       current_data_rate,
    input               smlh_in_l0,
    input               smlh_in_rcvryspeed_predetect,
    input               smlh_retimer_pre_detected,
    // Cdm             
    input               cfg_upstream_port,
    input   [15:0]      cfg_margin_control,
    // Cdm Margining Parameter
    input   [5:0]       cfg_margin_num_timing_steps,
    input   [5:0]       cfg_margin_max_timing_offset,
    input   [6:0]       cfg_margin_num_voltage_steps,
    input   [5:0]       cfg_margin_max_voltage_offset,
    input   [5:0]       cfg_margin_sample_rate_voltage,
    input   [5:0]       cfg_margin_sample_rate_timing,
    input   [4:0]       cfg_margin_maxlanes,
    input               cfg_margin_voltage_supported,
    input               cfg_margin_ind_left_right_timing,
    input               cfg_margin_ind_up_down_voltage,
    input               cfg_margin_sample_reporting_method,
    input               cfg_margin_ind_error_sampler,
    input  [3:0]        cfg_rx_message_bus_write_buffer_depth,
    input               power_saving_lanes_active,
    // Rmlh            
    input               rmlh_deskew_datastream,
    input   [15:0]      rmlh_deskew_ctlskp_info,
    input               rmlh_deskew_ctlskp_rcvd,
    input   [4:0]       rmlh_deskew_ctlskp_err,
    // Pipe            
    input               xmtbyte_ctlskip_sent,
    input               rpipe_margin_status ,
    input               rpipe_margin_nak ,
    input   [5:0]       rpipe_margin_error_cnt ,
    input   [6:0]       rpipe_margin_sampl_cnt ,
    // Output
    // LTSSM
    output wire         smlh_margin_pipe_idle,
    // Cdm
    output reg [15:0]   smlh_margin_status,
    output reg          smlh_margin_status_valid,
    // Pipe
    output reg [2:0]    smlh_margin_cmd,
    output reg [6:0]    smlh_margin_offset,
    output reg [1:0]    smlh_margin_clr_error_log,
    output reg          smlh_margin_en,
    // Xmlh
    output reg [15:0]   smlh_ctlskp_info
);

// Margin Cmd param
localparam S_TYPE_NO_COMMAND       = 4'b0111;
localparam S_TYPE_REPORT           = 4'b0001;
localparam S_TYPE_CONTROL          = 4'b0010;
localparam S_TYPE_STEP_MARGIN_TIM  = 4'b0011;
localparam S_TYPE_STEP_MARGIN_VOL  = 4'b0100;
localparam S_TYPE_VENDOR_DEF       = 4'b0101;

// Payload param                   
localparam S_PYLD_NO_COMMAND      = 8'h9C;
localparam S_PYLD_MARGIN_CAP      = 8'h88;
localparam S_PYLD_M_NUMVOLSTEPS   = 8'h89;
localparam S_PYLD_M_NUMTIMSTEPS   = 8'h8A;
localparam S_PYLD_M_MAXTIMOFFSET  = 8'h8B;
localparam S_PYLD_M_MAXVOLOFFSET  = 8'h8C;
localparam S_PYLD_M_SAMPLERATE_VOL= 8'h8D;
localparam S_PYLD_M_SAMPLERATE_TIM= 8'h8E;
localparam S_PYLD_M_SAMPLECOUNT   = 8'h8F;
localparam S_PYLD_M_MAXLANES      = 8'h90;
localparam S_PYLD_M_RESERVED_LOW  = 8'h91;
localparam S_PYLD_M_RESERVED_HIGH = 8'h9F;

localparam S_PYLD_GOTO_NORMAL     = 8'h0F;
localparam S_PYLD_CLEAR_ERRLOG    = 8'h55;

// Receiver Number param
localparam S_BROADCAST     = 3'b000;
localparam S_RECEIVER_A    = 3'b001; // Downstream Port
localparam S_RECEIVER_F    = 3'b110; // Upstream Port

// PIPE commmand
localparam S_CMD_IDLE  = 3'b000;
localparam S_CMD_TIM_L = 3'b001;
localparam S_CMD_TIM_R = 3'b011;
localparam S_CMD_VOL_U = 3'b101;
localparam S_CMD_VOL_D = 3'b111;

// Step Margin Execution Status
localparam S_SETUP_FOR_MARGIN   = 2'b01;
localparam S_MARGIN_IN_PROGRESS = 2'b10;
localparam S_NAK                = 2'b11;
localparam S_TOO_MANY_ERRORS    = 2'b00;

// PIPE Margin Status
localparam S_PIPE_IDLE       = 2'b00;
localparam S_PIPE_WAIT_START = 2'b01;
localparam S_PIPE_IN_PROGREM = 2'b10;
localparam S_PIPE_WAIT_STOP  = 2'b11;

reg  [6:0]  ext_sample_count;        // external sample count
reg  [3:0]  current_my_margin_type_d;       // 1 cycle delay of margin type
reg  [7:0]  current_my_margin_payload_d;    // 1 cycle delay of margin payload
reg  [3:0]  step_margin_type_last;   // last step margin type 
reg  [7:0]  step_margin_payload_last; //  last payload value of the step margin
reg         dataparity_err_d;        // 1cycle delay of the data parity error in control skp os
reg         smlh_in_l0_d;            // 1cycle delay of the smlh_in_l0
// internal error count
reg  [5:0]  int_err_cnt;             // Error Counter
reg         int_err_cnt_limit_over;  // Error Count >= Error Count Limit
// external error count
reg  [5:0]  ext_err_cnt;             // Error Counter
reg         ext_err_cnt_limit_over;  // Error Count >= Error Count Limit

reg  [5:0]  pre_err_cnt_limit;       // Error Count Limit
reg  [5:0]  err_cnt_limit;           // Error Counter Limit set by the MarginCmd=Set Error Count
reg  [2:0]  int_current_my_sts_receiver_num;    // Status - Receiver Number
reg  [7:0]  int_current_my_sts_margin_payload;  // Margin Status to transmit the Command and Status SKP
reg  [3:0]  int_current_my_sts_margin_type;     // Status - Margin Type
reg  [1:0]  int_step_margin_exe_sts; // Step Margin execution status
reg  [1:0]  step_margin_exe_sts; // Step Margin execution status
wire [3:0]  current_my_sts_margin_type;
wire [2:0]  current_my_sts_receiver_num;
wire [7:0]  current_my_sts_margin_payload;
reg [1:0]   pipe_margin_sts; // PIPE Margin Status
reg         step_margin_changed_latch; // latched step_margin_changed
reg [6:0]   smlh_margin_offset_pre; // Previous value of smlh_margin_offset

// selected error count
wire [5:0]  err_cnt;                 // Error Count value
wire        err_cnt_limit_over;      // flag that the core exceeds the Error Count Limit
wire        dataparity_err;
// Margin Status to the Margin Cmd=Step Margin*
wire [7:0]  int_step_margin_sts;
wire        dataparity_err_rose = dataparity_err && !dataparity_err_d;
wire        smlh_in_l0_fell = !smlh_in_l0 && smlh_in_l0_d;
wire [6:0]  sample_count;            // selected M(SampleCount)
wire        sample_reporting_method; // selected M(SampleReportingMethod)
wire [5:0]  sample_rate_voltage;     // selected M(SamplingRateVoltage)
wire [5:0]  sample_rate_timing;      // selected M(SamplingRateTiming)
wire        current_my_margin_cmd_changed;
wire        step_margin_changed;
wire        illegal_setting;
// For internal Error Counter
wire        int_err_cnt_clr;  // internal error count clear
wire        int_err_cnt_incr; // internal error count increment
// For independent Error Counter
wire        ext_err_cnt_clr;
wire        goto_normal_settings;
wire [3:0]  ctlskp_tx_margin_type;     // tx ctl skp value
wire [2:0]  ctlskp_tx_receiver_num;    // tx ctl skp value
wire [7:0]  ctlskp_tx_margin_payload;  // tx ctl skp value

wire [3:0]  current_my_margin_type;     // cdm value
wire [2:0]  current_my_receiver_num;    // cdm value
wire [7:0]  current_my_margin_payload;  // cdm value
  
wire [7:0]  int_cfg_margin_payload = cfg_margin_control[15:8];
wire [3:0]  int_cfg_margin_type    = cfg_margin_control[6:3];
wire [2:0]  int_cfg_receiver_num   = cfg_margin_control[2:0];

wire [7:0]  int_rmlh_margin_payload ;
wire        int_rmlh_usage_model    ;
wire [2:0]  int_rmlh_margin_type    ;
wire [2:0]  int_rmlh_receiver_num   ;

wire        broadcast_w_retimer;
wire        receiver_is_me; // indicates this port is the receiver
wire        receiver_is_type_me;
wire [2:0]  receiver_is_num_me;
wire        tmp_current_data_rate_g4over;
wire        current_data_rate_g4over;
wire [15:0] int_smlh_margin_status;
wire        current_clear_err_log;
wire        next_step_margin_changed_latch;
wire [1:0]  next_smlh_margin_clr_error_log_chg;
wire [1:0]  next_smlh_margin_clr_error_log_clr;
wire        keeping_too_many_errors;

wire   cfg_wu_en ; // write uncommited transaction 

assign tmp_current_data_rate_g4over = (current_data_rate >= `GEN4_RATE);
assign current_data_rate_g4over = tmp_current_data_rate_g4over 
                              ;

assign goto_normal_settings = (current_my_margin_type==S_TYPE_CONTROL && current_my_margin_payload==S_PYLD_GOTO_NORMAL);

// broadcast command and DSP w retimer
assign broadcast_w_retimer = (int_cfg_receiver_num==S_BROADCAST && 
                              ((int_cfg_margin_type==S_TYPE_CONTROL && int_cfg_margin_payload[7:6]!=2'b11) || int_cfg_margin_type==S_TYPE_NO_COMMAND) && 
                              (!cfg_upstream_port && smlh_retimer_pre_detected));
// Valid Receiver Num
// DSP - RECEIVER_A, BROADCAST
// USP - RECEIVER_F, BROADCAST
assign receiver_is_type_me = (int_cfg_margin_type==S_TYPE_REPORT || int_cfg_margin_type==S_TYPE_CONTROL || int_cfg_margin_type==S_TYPE_STEP_MARGIN_TIM || int_cfg_margin_type==S_TYPE_STEP_MARGIN_VOL || int_cfg_margin_type==S_TYPE_VENDOR_DEF);
assign receiver_is_me = (int_cfg_receiver_num==S_BROADCAST && ((int_cfg_margin_type==S_TYPE_CONTROL && int_cfg_margin_payload[7:6]!=2'b11) || int_cfg_margin_type==S_TYPE_NO_COMMAND)) ||
                        (cfg_upstream_port  && int_cfg_receiver_num==S_RECEIVER_F && receiver_is_type_me) ||
                        (!cfg_upstream_port && int_cfg_receiver_num==S_RECEIVER_A && receiver_is_type_me);
assign receiver_is_num_me = (int_cfg_receiver_num==S_BROADCAST && int_cfg_margin_type==S_TYPE_CONTROL) ? (cfg_upstream_port) ? S_RECEIVER_F : S_RECEIVER_A : int_cfg_receiver_num;

// Rx Control SKP -> Masked by Margin CRC and Margin Parity (-> to Cdm)
assign int_rmlh_margin_payload = rmlh_deskew_ctlskp_info[15:8];
assign int_rmlh_usage_model    = rmlh_deskew_ctlskp_info[6]   ;
assign int_rmlh_margin_type    = rmlh_deskew_ctlskp_info[5:3] ;
assign int_rmlh_receiver_num   = rmlh_deskew_ctlskp_info[2:0] ;

// SKP data parity error
//  detect a data parity mismatch while in L0 and data_stream at 128b/130b operating
assign dataparity_err  = ( |current_data_rate[2:1] && smlh_in_l0 && rmlh_deskew_datastream) ? 
                                                                                         |rmlh_deskew_ctlskp_err[2:0] : 1'b0;
// DSP
// Tx: from Cdm(Control)           to Xmlh
// USP
// Tx: to Xmlh (Alaways transmit No Command)
assign ctlskp_tx_margin_payload = (!cfg_upstream_port && current_data_rate_g4over)? int_cfg_margin_payload: S_PYLD_NO_COMMAND ;
assign ctlskp_tx_margin_type    = (!cfg_upstream_port && current_data_rate_g4over)? int_cfg_margin_type   : S_TYPE_NO_COMMAND ;
assign ctlskp_tx_receiver_num   = (!cfg_upstream_port && current_data_rate_g4over)? int_cfg_receiver_num  : S_BROADCAST ;      

// Margin Command - Target is own Rx
assign current_my_margin_payload = (current_data_rate_g4over && receiver_is_me)? int_cfg_margin_payload : S_PYLD_NO_COMMAND;
assign current_my_margin_type    = (current_data_rate_g4over && receiver_is_me)? int_cfg_margin_type    : S_TYPE_NO_COMMAND;
assign current_my_receiver_num   = (current_data_rate_g4over && receiver_is_me)? receiver_is_num_me     : S_BROADCAST;

// Change flag of the Margin Status
assign int_smlh_margin_status = {current_my_sts_margin_payload, 1'b0, current_my_sts_margin_type, current_my_sts_receiver_num};

// smlh_ctlskp_info - symbol 4*N+2 and 4*N+3 of Control SKP OS
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        // To Xmlh - Control SKP OS
        smlh_ctlskp_info <= #TP {S_PYLD_NO_COMMAND, 1'b0, S_TYPE_NO_COMMAND, S_BROADCAST};
    end else if(!power_saving_lanes_active) begin
        smlh_ctlskp_info <= #TP smlh_ctlskp_info;
    end else if(!current_data_rate_g4over) begin
        smlh_ctlskp_info <= #TP {S_PYLD_NO_COMMAND, 1'b0, S_TYPE_NO_COMMAND, S_BROADCAST};
    end else begin
        smlh_ctlskp_info <= #TP {ctlskp_tx_margin_payload, 1'b0, ctlskp_tx_margin_type, ctlskp_tx_receiver_num};
    end

// smlh_margin_status - Status field of the Lane and Control Register
// smlh_margin_status_valid - Valid cycle of the smlh_marign_status
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        // To CDM  - Lane Margining Control and Status Register - Status Field
        smlh_margin_status <= #TP 0;
        smlh_margin_status_valid <= #TP 0;
    end else if(!power_saving_lanes_active) begin
        smlh_margin_status <= #TP smlh_margin_status;
        smlh_margin_status_valid <= #TP smlh_margin_status_valid;
    end else if(!current_data_rate_g4over) begin
        smlh_margin_status <= #TP 0;
        smlh_margin_status_valid <= #TP 0;
    end else begin
        // for DSP/USP
        if(receiver_is_me && !broadcast_w_retimer) begin
            smlh_margin_status <= #TP int_smlh_margin_status;
            if(smlh_margin_status!=int_smlh_margin_status)
                smlh_margin_status_valid <= #TP 1;
            else
                smlh_margin_status_valid <= #TP 0;
        // for Retimer
        // Ignore if the calcurated margin parity/margin crc mismatch.
        end else if(!cfg_upstream_port && rmlh_deskew_ctlskp_rcvd && rmlh_deskew_ctlskp_err[4:3]==2'b00) begin
            smlh_margin_status <= #TP {int_rmlh_margin_payload, 1'b0, int_rmlh_usage_model , int_rmlh_margin_type, int_rmlh_receiver_num};
            smlh_margin_status_valid <= #TP 1;
        end else begin
            smlh_margin_status <= #TP smlh_margin_status;
            smlh_margin_status_valid <= #TP 0;
        end
    end


// Margin Cmd -> Margin Status
assign int_step_margin_sts = (int_step_margin_exe_sts==S_SETUP_FOR_MARGIN) ? {int_step_margin_exe_sts, 6'd0} : {int_step_margin_exe_sts, err_cnt};

always @(*) begin
    case(current_my_margin_type)
        S_TYPE_NO_COMMAND: begin
            if(current_my_margin_payload==S_PYLD_NO_COMMAND) begin
                // No Command
                int_current_my_sts_receiver_num   = S_BROADCAST;
                int_current_my_sts_margin_type    = S_TYPE_NO_COMMAND;
                int_current_my_sts_margin_payload = S_PYLD_NO_COMMAND;
            end else begin
                // else keeping value
                int_current_my_sts_receiver_num   = smlh_margin_status[2:0];
                int_current_my_sts_margin_type    = smlh_margin_status[6:3];
                int_current_my_sts_margin_payload = smlh_margin_status[15:8];
            end
        end
        S_TYPE_REPORT: begin
            case(current_my_margin_payload)
                S_PYLD_MARGIN_CAP: begin
                    // Report Margin Control Cap
                    // { 3'h0, MIndErrorSampler,, MSampleReportingMethod , MIndLeftRightTiming , MIndUpDownVoltage , MVoltageSupported }
                    int_current_my_sts_margin_payload = {3'h0, cfg_margin_ind_error_sampler, sample_reporting_method, cfg_margin_ind_left_right_timing, cfg_margin_ind_up_down_voltage, cfg_margin_voltage_supported};
                    int_current_my_sts_receiver_num = current_my_receiver_num;
                    int_current_my_sts_margin_type  = current_my_margin_type;
                end
                S_PYLD_M_NUMVOLSTEPS : begin
                    // Report MNumVoltageSteps
                    // Margin Payload[6:0] = MNumVoltageSteps
                    int_current_my_sts_margin_payload = {1'b0, cfg_margin_num_voltage_steps};
                    int_current_my_sts_receiver_num = current_my_receiver_num;
                    int_current_my_sts_margin_type  = current_my_margin_type;
                end
                S_PYLD_M_NUMTIMSTEPS    : begin  
                    // Report MNumTimingSteps
                    // Margin Payload [5:0] =  MNumTimingSteps 
                    int_current_my_sts_margin_payload = {2'b00, cfg_margin_num_timing_steps};
                    int_current_my_sts_receiver_num = current_my_receiver_num;
                    int_current_my_sts_margin_type  = current_my_margin_type;
                end
                S_PYLD_M_MAXTIMOFFSET   : begin  
                    // Report MMaxTimingOffset
                    // Margin Payload[6:0] = MMaxTimingOffset
                    int_current_my_sts_margin_payload = {2'b00, cfg_margin_max_timing_offset};
                    int_current_my_sts_receiver_num = current_my_receiver_num;
                    int_current_my_sts_margin_type  = current_my_margin_type;
                end
                S_PYLD_M_MAXVOLOFFSET   : begin  
                    // Report MMaxVoltageOffset
                    // Margin Payload[6:0] = MMaxVoltageOffset
                    int_current_my_sts_margin_payload = {2'b00, cfg_margin_max_voltage_offset};
                    int_current_my_sts_receiver_num = current_my_receiver_num;
                    int_current_my_sts_margin_type  = current_my_margin_type;
                end
                S_PYLD_M_SAMPLERATE_VOL : begin  
                    // Report Sampling Rate Voltage
                    // Margin Payload[5:0] = { MSamplingRateVoltage [5:0]}
                    int_current_my_sts_margin_payload = {2'b00, sample_rate_voltage};
                    int_current_my_sts_receiver_num = current_my_receiver_num;
                    int_current_my_sts_margin_type  = current_my_margin_type;
                end
                S_PYLD_M_SAMPLERATE_TIM : begin  
                    // Report Sampling Rate Timing
                    int_current_my_sts_margin_payload = {2'b00, sample_rate_timing};
                    int_current_my_sts_receiver_num = current_my_receiver_num;
                    int_current_my_sts_margin_type  = current_my_margin_type;
                end
                S_PYLD_M_SAMPLECOUNT    : begin  
                    // Report SampleCount
                    // Margin Payload[6:0] = MSampleCount
                    int_current_my_sts_margin_payload = {1'b0,sample_count};
                    int_current_my_sts_receiver_num = current_my_receiver_num;
                    int_current_my_sts_margin_type  = current_my_margin_type;
                end
                S_PYLD_M_MAXLANES       : begin  
                    // Report MMaxLanes
                    // Margin Payload[4:0] = MMaxLanes
                    int_current_my_sts_margin_payload = {3'h0,cfg_margin_maxlanes};
                    int_current_my_sts_receiver_num = current_my_receiver_num;
                    int_current_my_sts_margin_type  = current_my_margin_type;
                end
                default : begin
                    // Report Reserved
                    if(current_my_margin_payload >=  S_PYLD_M_RESERVED_LOW && current_my_margin_payload <= S_PYLD_M_RESERVED_HIGH) begin
                        int_current_my_sts_margin_payload = 8'h00;
                        int_current_my_sts_receiver_num = current_my_receiver_num;
                        int_current_my_sts_margin_type  = current_my_margin_type;
                    end else begin
                    // else keeping value
                        int_current_my_sts_receiver_num   = smlh_margin_status[2:0];
                        int_current_my_sts_margin_type    = smlh_margin_status[6:3];
                        int_current_my_sts_margin_payload = smlh_margin_status[15:8];
                    end
                end
            endcase
            
        end
        S_TYPE_CONTROL : begin
            if(current_my_margin_payload==S_PYLD_GOTO_NORMAL) begin
                // Go to Normal Settings waits rpipe_margin_status
                if(!smlh_margin_en) begin
                    int_current_my_sts_receiver_num   = current_my_receiver_num;
                    int_current_my_sts_margin_type    = current_my_margin_type;
                    int_current_my_sts_margin_payload = current_my_margin_payload;
                end else begin
                    int_current_my_sts_receiver_num   = smlh_margin_status[2:0];
                    int_current_my_sts_margin_type    = smlh_margin_status[6:3];
                    int_current_my_sts_margin_payload = smlh_margin_status[15:8];
                end
            end else if((current_my_margin_payload[7:6]==2'b11) || (current_my_margin_payload==S_PYLD_CLEAR_ERRLOG)) begin
                // Set Error Count Limit / Clear Error Log
                int_current_my_sts_receiver_num   = current_my_receiver_num;
                int_current_my_sts_margin_type    = current_my_margin_type;
                int_current_my_sts_margin_payload = current_my_margin_payload;
            end else begin
                // else keeping value
                int_current_my_sts_receiver_num   = smlh_margin_status[2:0];
                int_current_my_sts_margin_type    = smlh_margin_status[6:3];
                int_current_my_sts_margin_payload = smlh_margin_status[15:8];
            end
        end
        S_TYPE_STEP_MARGIN_TIM,
        S_TYPE_STEP_MARGIN_VOL : begin
            // Step Margin to timing/voltage offset to right/left/up/down of default:
            // Margin Status[7:6] = 
            // 11b: NAK (used if software issues an unsupported command such as timing margin going beyond +/- 0.2 UI)
            // 10b: Margining in progress
            // 01b: Set up for margin in progress.  This can be reported only after a new Step Margin command is received and for no more than 100 ms after receiving the Step Margin command.
            // 00b: Too many errors  Receiver autonomously went back to its default settings
            // Margin Status[5:0] = MErrorCount 
            int_current_my_sts_receiver_num   = current_my_receiver_num;
            int_current_my_sts_margin_type    = current_my_margin_type;
            int_current_my_sts_margin_payload = int_step_margin_sts;
        end
        S_TYPE_VENDOR_DEF : begin
            int_current_my_sts_receiver_num   = current_my_receiver_num;
            int_current_my_sts_margin_type    = current_my_margin_type;
            int_current_my_sts_margin_payload = current_my_margin_payload;
        end
        default: begin
            int_current_my_sts_receiver_num   = smlh_margin_status[2:0];
            int_current_my_sts_margin_type    = smlh_margin_status[6:3];
            int_current_my_sts_margin_payload = smlh_margin_status[15:8];
        end
    endcase
end

// PIPE Status and control
// S_PIPE_IDLE       = 2'b00;
// S_PIPE_WAIT_START = 2'b01;
// S_PIPE_IN_PROGREM = 2'b10;
// S_PIPE_WAIT_STOP  = 2'b11;
assign current_clear_err_log = (current_my_margin_cmd_changed && current_my_margin_type==S_TYPE_CONTROL && current_my_margin_payload==S_PYLD_CLEAR_ERRLOG);
assign next_step_margin_changed_latch = (step_margin_changed) ? 1'b1 : step_margin_changed_latch;
assign next_smlh_margin_clr_error_log_chg = (step_margin_changed || step_margin_changed_latch) ? 2'b11 : 2'b00; // [0]error count [1]sample count
assign next_smlh_margin_clr_error_log_clr = (current_clear_err_log) ? 2'b01 : 2'b00; // [0]error count [1]sample count
assign smlh_margin_pipe_idle = (pipe_margin_sts==S_PIPE_IDLE);
// ccx_cond: ; 0; 011+101; REDUNDANT: the step_margin_changed and the step_margin_changed_latch are not set to 1 at same timing.
assign keeping_too_many_errors = (~step_margin_changed && ~step_margin_changed_latch && int_step_margin_exe_sts==S_TOO_MANY_ERRORS);

// The core can use a write_uncommitted transaction if the cfg_rx_message_bus_write_buffer_depth is not 0.
// This means the core should de-assert the smlh_margin_cmd and smlh_margin_offset at the same timing.
assign cfg_wu_en = cfg_rx_message_bus_write_buffer_depth!=4'h0;

always @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        pipe_margin_sts           <= #TP S_PIPE_IDLE;
        smlh_margin_cmd           <= #TP S_CMD_IDLE;
        smlh_margin_offset        <= #TP 7'h0;
        smlh_margin_offset_pre    <= #TP 7'h0;
        smlh_margin_en            <= #TP 1'b0;
        smlh_margin_clr_error_log <= #TP 2'b00;
        step_margin_changed_latch <= #TP 1'b0;
    end else if (!power_saving_lanes_active) begin
        pipe_margin_sts           <= #TP pipe_margin_sts;
        smlh_margin_cmd           <= #TP smlh_margin_cmd;
        smlh_margin_offset        <= #TP smlh_margin_offset;       
        smlh_margin_offset_pre    <= #TP smlh_margin_offset_pre;   
        smlh_margin_en            <= #TP smlh_margin_en;           
        smlh_margin_clr_error_log <= #TP smlh_margin_clr_error_log;
        step_margin_changed_latch <= #TP step_margin_changed_latch;
    end else if (!current_data_rate_g4over) begin
        pipe_margin_sts           <= #TP S_PIPE_IDLE;
        smlh_margin_cmd           <= #TP {S_CMD_IDLE[2],smlh_margin_cmd[1],S_CMD_IDLE[0]};
        smlh_margin_offset        <= #TP smlh_margin_offset;
        smlh_margin_offset_pre    <= #TP 7'h0;
        smlh_margin_en            <= #TP 1'b0;
        smlh_margin_clr_error_log <= #TP 2'b00;
        step_margin_changed_latch <= #TP 1'b0;
    end else begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Using the sequential part (flip-flop description) and combinational part(case construct) of an FSM in the same always block increases complexity of the design thereby reducing the readability. This code is a simple. So, disable SpyGlass from reporting this error.
        case(pipe_margin_sts)
// spyglass enable_block STARC05-2.11.3.1
            S_PIPE_WAIT_START:begin
                if(rpipe_margin_status || rpipe_margin_nak) begin
                    pipe_margin_sts       <= #TP S_PIPE_IN_PROGREM;
                    smlh_margin_en        <= #TP 1'b1;
                end else begin
                    pipe_margin_sts       <= #TP pipe_margin_sts;
                    smlh_margin_en        <= #TP smlh_margin_en;
                end
                    smlh_margin_cmd           <= #TP smlh_margin_cmd;
                    smlh_margin_offset        <= #TP smlh_margin_offset;
                    smlh_margin_offset_pre    <= #TP smlh_margin_offset_pre;
                    smlh_margin_clr_error_log <= #TP next_smlh_margin_clr_error_log_clr;
                    step_margin_changed_latch <= #TP next_step_margin_changed_latch;
            end
            S_PIPE_IN_PROGREM:begin
                if(illegal_setting || goto_normal_settings || err_cnt_limit_over || !current_data_rate_g4over || smlh_in_rcvryspeed_predetect) begin
                    pipe_margin_sts           <= #TP S_PIPE_WAIT_STOP;
                    smlh_margin_cmd           <= #TP {S_CMD_IDLE[2],smlh_margin_cmd[1],S_CMD_IDLE[0]};
                    smlh_margin_offset        <= #TP smlh_margin_offset ;
                    smlh_margin_offset_pre    <= #TP 7'h0;
                    smlh_margin_en            <= #TP smlh_margin_en;
                    smlh_margin_clr_error_log <= #TP 2'b00;
                    step_margin_changed_latch <= #TP 1'b0;
                end else if(!cfg_margin_ind_error_sampler && !smlh_in_l0 && (smlh_margin_offset!=7'h0)) begin // go back to the default sample position
                    pipe_margin_sts           <= #TP S_PIPE_WAIT_START;
                    smlh_margin_cmd           <= #TP smlh_margin_cmd;
                    smlh_margin_offset        <= #TP 7'h0;
                    smlh_margin_offset_pre    <= #TP smlh_margin_offset;
                    smlh_margin_en            <= #TP smlh_margin_en;
                    smlh_margin_clr_error_log <= #TP 2'b00;
                    step_margin_changed_latch <= #TP next_step_margin_changed_latch;
                // ccx_cond: ; 0; 0111; REDUNDANT: When cfg_margin_ind_error_sampler is set to 1, smlh_margin_offset and mlh_margin_offset_pre are same value.
                end else if(!cfg_margin_ind_error_sampler && smlh_in_l0 && (smlh_margin_offset!=smlh_margin_offset_pre) && !step_margin_changed_latch) begin // resume the margin position
                    pipe_margin_sts           <= #TP S_PIPE_WAIT_START;
                    smlh_margin_cmd           <= #TP smlh_margin_cmd;
                    smlh_margin_offset        <= #TP smlh_margin_offset_pre;
                    smlh_margin_offset_pre    <= #TP smlh_margin_offset_pre;
                    smlh_margin_en            <= #TP smlh_margin_en;
                    smlh_margin_clr_error_log <= #TP 2'b00;
                    step_margin_changed_latch <= #TP next_step_margin_changed_latch;
                end else if(smlh_in_l0 && (current_my_margin_type==S_TYPE_STEP_MARGIN_TIM) && (smlh_margin_offset!={1'b0, current_my_margin_payload[5:0]})) begin // Update the margin position
                    // Step Margin Timing
                    pipe_margin_sts           <= #TP S_PIPE_WAIT_START;
                    smlh_margin_cmd           <= #TP smlh_margin_cmd;
                    smlh_margin_offset        <= #TP {1'b0, current_my_margin_payload[5:0]};
                    smlh_margin_offset_pre    <= #TP {1'b0, current_my_margin_payload[5:0]};
                    smlh_margin_en            <= #TP smlh_margin_en;
                    smlh_margin_clr_error_log <= #TP next_smlh_margin_clr_error_log_chg;
                    step_margin_changed_latch <= #TP 1'b0;
                end else if(smlh_in_l0 && (current_my_margin_type==S_TYPE_STEP_MARGIN_VOL) && (smlh_margin_offset!=current_my_margin_payload[6:0])) begin // Update the margin position
                    // Step Margin Voltage
                    pipe_margin_sts           <= #TP S_PIPE_WAIT_START;
                    smlh_margin_cmd           <= #TP smlh_margin_cmd;
                    smlh_margin_offset        <= #TP current_my_margin_payload[6:0];
                    smlh_margin_offset_pre    <= #TP current_my_margin_payload[6:0];
                    smlh_margin_en            <= #TP smlh_margin_en;
                    smlh_margin_clr_error_log <= #TP next_smlh_margin_clr_error_log_chg;
                    step_margin_changed_latch <= #TP 1'b0;
                end else begin
                    pipe_margin_sts           <= #TP pipe_margin_sts;
                    smlh_margin_cmd           <= #TP smlh_margin_cmd;
                    smlh_margin_offset        <= #TP smlh_margin_offset;
                    smlh_margin_offset_pre    <= #TP smlh_margin_offset_pre;
                    smlh_margin_en            <= #TP smlh_margin_en;
                    smlh_margin_clr_error_log <= #TP next_smlh_margin_clr_error_log_clr;
                    step_margin_changed_latch <= #TP next_step_margin_changed_latch;
                end
            end
            S_PIPE_WAIT_STOP:begin
                if(rpipe_margin_status) begin
                    pipe_margin_sts       <= #TP S_PIPE_IDLE;
                    smlh_margin_en        <= #TP 1'b0;
                end else begin
                    pipe_margin_sts       <= #TP pipe_margin_sts;
                    smlh_margin_en        <= #TP smlh_margin_en;
                end
                smlh_margin_cmd           <= #TP smlh_margin_cmd;
                smlh_margin_offset        <= #TP smlh_margin_offset;
                smlh_margin_offset_pre    <= #TP smlh_margin_offset_pre;
                smlh_margin_clr_error_log <= #TP next_smlh_margin_clr_error_log_clr;
                step_margin_changed_latch <= #TP next_step_margin_changed_latch;
            end
            default:begin // S_PIPE_IDLE
                if(illegal_setting || goto_normal_settings || keeping_too_many_errors) begin
                    pipe_margin_sts           <= #TP pipe_margin_sts;
                    smlh_margin_cmd           <= #TP {S_CMD_IDLE[2],smlh_margin_cmd[1],S_CMD_IDLE[0]};
                    smlh_margin_offset        <= #TP smlh_margin_offset;
                    smlh_margin_offset_pre    <= #TP smlh_margin_offset_pre;
                    smlh_margin_clr_error_log <= #TP next_smlh_margin_clr_error_log_clr;
                    step_margin_changed_latch <= #TP 1'b0;
                end else if(smlh_in_l0 && (current_my_margin_type==S_TYPE_STEP_MARGIN_TIM)) begin
                    // Step Margin Timing
                    // Margin Payload[6]=0 : RIGHT
                    //                   1 : LEFT
                    pipe_margin_sts           <= #TP S_PIPE_WAIT_START;
                    if(current_my_margin_payload[6]==1 && cfg_margin_ind_left_right_timing) begin
                        smlh_margin_cmd       <= #TP S_CMD_TIM_L;
                    end else begin
                        smlh_margin_cmd       <= #TP S_CMD_TIM_R;
                    end
                    smlh_margin_offset        <= #TP {1'b0, current_my_margin_payload[5:0]};
                    smlh_margin_offset_pre    <= #TP {1'b0, current_my_margin_payload[5:0]};
                    smlh_margin_en            <= #TP smlh_margin_en;
                    smlh_margin_clr_error_log <= #TP next_smlh_margin_clr_error_log_chg;
                    step_margin_changed_latch <= #TP 1'b0;
                end else if(smlh_in_l0 && (current_my_margin_type==S_TYPE_STEP_MARGIN_VOL)) begin
                    // Step Margin Voltage
                    // Margin Payload[7]=0 : UP
                    //                       DOWN
                    pipe_margin_sts           <= #TP S_PIPE_WAIT_START;
                    if(current_my_margin_payload[7]==1 && cfg_margin_ind_up_down_voltage) begin
                        smlh_margin_cmd       <= #TP S_CMD_VOL_D;
                    end else begin
                        smlh_margin_cmd       <= #TP S_CMD_VOL_U;
                    end
                    smlh_margin_offset        <= #TP current_my_margin_payload[6:0];
                    smlh_margin_offset_pre    <= #TP current_my_margin_payload[6:0];
                    smlh_margin_en            <= #TP smlh_margin_en;
                    smlh_margin_clr_error_log <= #TP next_smlh_margin_clr_error_log_chg;
                    step_margin_changed_latch <= #TP 1'b0;
                end else begin
                    pipe_margin_sts           <= #TP pipe_margin_sts;
                    smlh_margin_cmd           <= #TP {1'b0,smlh_margin_cmd[1],1'b0};
                    smlh_margin_offset        <= #TP smlh_margin_offset;
                    smlh_margin_offset_pre    <= #TP smlh_margin_offset_pre;
                    smlh_margin_en            <= #TP 1'b0;
                    smlh_margin_clr_error_log <= #TP next_smlh_margin_clr_error_log_clr;
                    step_margin_changed_latch <= #TP next_step_margin_changed_latch;
                end
            end
        endcase
    end
end

// Output registering (optional)
// If the timing is critical, set the parameter REGOUT to 1b
parameter N_DELAY_CYLES = REGOUT ? 1 : 0;
parameter DATAPATH_WIDTH = 3 + 4 + 8;
parameter RESET_VALUE = {S_BROADCAST, S_TYPE_NO_COMMAND, S_PYLD_NO_COMMAND}; // Reset value
delay_n

#(N_DELAY_CYLES, DATAPATH_WIDTH, RESET_VALUE) u_delay(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ( {int_current_my_sts_receiver_num, int_current_my_sts_margin_type, int_current_my_sts_margin_payload} ),
    .dout       ( {current_my_sts_receiver_num, current_my_sts_margin_type, current_my_sts_margin_payload} )
);

// Error Count Limit
// default = 4
// Set by Set Error Count Limit command
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        err_cnt_limit <= #TP 4;
        pre_err_cnt_limit <= #TP 4;
    // ccx_cond: ; 0; 011; REDUNDANT: When receiver_is_me is set to 1, current_my_margin_type is not S_TYPE_CONTROL.
    end else if(receiver_is_me && current_my_margin_type==S_TYPE_CONTROL && current_my_margin_payload[7:6]==2'b11) begin
        // Last Margin Command is Step Margin*?
        // Not set until "Go to Normal Settings" is issued.
        if(!smlh_margin_en) begin
            err_cnt_limit <= #TP current_my_margin_payload[5:0];
        end

        pre_err_cnt_limit <= #TP current_my_margin_payload[5:0];
    end else if(!smlh_margin_en || step_margin_changed) begin
        // Set if the Step Margin Command is changed
        err_cnt_limit <= #TP pre_err_cnt_limit;
        pre_err_cnt_limit <= #TP pre_err_cnt_limit;
    end

// NAK condition for the Step Margin Execution Status
assign illegal_setting = (current_my_margin_type==S_TYPE_STEP_MARGIN_TIM && current_my_margin_payload[5:0] > cfg_margin_num_timing_steps) ||
                         (current_my_margin_type==S_TYPE_STEP_MARGIN_VOL && ((current_my_margin_payload[6:0] > cfg_margin_num_voltage_steps) || !cfg_margin_voltage_supported)) ;

// Step Margin Execution Status
// 00: Too many errors, 01: Set up for Margin, 10b: Margining in progress, 11b: NAK
// S_SETUP_FOR_MARGIN   = 2'b01;
// S_MARGIN_IN_PROGRESS = 2'b10;
// S_NAK                = 2'b11;
// S_TOO_MANY_ERRORS    = 2'b00;
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        step_margin_exe_sts <= #TP S_SETUP_FOR_MARGIN;
    end else if (!power_saving_lanes_active) begin
        step_margin_exe_sts <= #TP step_margin_exe_sts;
    end else begin
        step_margin_exe_sts <= #TP int_step_margin_exe_sts;
    end

always @(*)
    if (!current_data_rate_g4over) begin
        int_step_margin_exe_sts = S_SETUP_FOR_MARGIN;
    end else begin
        case(step_margin_exe_sts)
            // Setup for Margin
            S_SETUP_FOR_MARGIN : begin
              if(illegal_setting) begin
                  int_step_margin_exe_sts = S_NAK;
              end else if(smlh_margin_cmd==S_CMD_TIM_L || smlh_margin_cmd==S_CMD_TIM_R || smlh_margin_cmd==S_CMD_VOL_U || smlh_margin_cmd==S_CMD_VOL_D) begin
                if(rpipe_margin_nak)
                    int_step_margin_exe_sts = S_NAK;
                else
                if(rpipe_margin_status)
                    int_step_margin_exe_sts = S_MARGIN_IN_PROGRESS;
                else
                    int_step_margin_exe_sts = S_SETUP_FOR_MARGIN;
              end else begin
                  int_step_margin_exe_sts = S_SETUP_FOR_MARGIN;
              end
            end
            // Margining in Progress
            S_MARGIN_IN_PROGRESS : begin
                // ccx_cond: ; 1; 01; REDUNDANT: When goto_normal_settings is set to 0, smlh_margin_en is set to 1 in this status.
                if((goto_normal_settings && !smlh_margin_en) || step_margin_changed)
                    int_step_margin_exe_sts = S_SETUP_FOR_MARGIN;
                else if(err_cnt_limit_over)
                    int_step_margin_exe_sts = S_TOO_MANY_ERRORS;
                else
                    int_step_margin_exe_sts = S_MARGIN_IN_PROGRESS;
            end
            // NAK
            S_NAK : begin
                if(step_margin_changed)
                    int_step_margin_exe_sts = S_SETUP_FOR_MARGIN;
                else
                    int_step_margin_exe_sts = S_NAK;
            end
            // Too Many Errors
            S_TOO_MANY_ERRORS : begin
                if(step_margin_changed)
                    int_step_margin_exe_sts = S_SETUP_FOR_MARGIN;
                else
                    int_step_margin_exe_sts = S_TOO_MANY_ERRORS;
            end
// ccx_line_begin: ; Redundant code for case default item.
            default : begin
                int_step_margin_exe_sts = S_SETUP_FOR_MARGIN;
            end
// ccx_line_end
        endcase
    end

// Error Count
// RX Margining Independent Error Sampler
// cfg_margin_ind_error_sampler=0, MAC counts Error (Parity Check)
// cfg_margin_ind_error_sampler=1, Phy provides Error Count

// Go to Normal or Step Margin Command is changed
assign int_err_cnt_clr = (smlh_margin_clr_error_log[0] || !current_data_rate_g4over); // Clear Error Log command
assign ext_err_cnt_clr = int_err_cnt_clr; // currently same as internal

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        dataparity_err_d <= #TP 0;
        smlh_in_l0_d <= #TP 0;
    end else if(!power_saving_lanes_active) begin
        dataparity_err_d <= #TP dataparity_err_d;
        smlh_in_l0_d <= #TP smlh_in_l0_d;
    end else if(!current_data_rate_g4over) begin
        dataparity_err_d <= #TP 0;
        smlh_in_l0_d <= #TP 0;
    end else begin
        dataparity_err_d <= #TP dataparity_err;
        smlh_in_l0_d <= #TP smlh_in_l0;
    end

// Error condition for the actual error sampler
// Recovery Entry or 
// Dataparity Error in Control SKP OS at Gen4 or Dataparity Error in Standard SKP OS at Gen3
assign int_err_cnt_incr = (smlh_in_l0_fell || dataparity_err_rose);

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
    // Internal Error Counter
        int_err_cnt <= #TP 0;
        int_err_cnt_limit_over <= #TP 0;
    end else if(int_err_cnt_clr) begin
        int_err_cnt <= #TP 0;
        int_err_cnt_limit_over <= #TP 0;
    end else if(!int_err_cnt_limit_over && step_margin_exe_sts==2'b10) begin
    // valid when step_margin_exe_sts==S_RXM_ACTIVE 
    // incr - independent sample counts up
    //      - no independent sampler -> recovery entry/skip parity error
    // error limit -> stop the count
    // error count is available when the phy's margining status is active.
        if(int_err_cnt_incr && int_err_cnt!=6'b11_1111) begin
            int_err_cnt <= #TP int_err_cnt + 1;
            int_err_cnt_limit_over <= #TP ((int_err_cnt+1)>err_cnt_limit) ? 1 : 0;
        end
    end

// External Error Sampler (Latch only)
//
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        ext_err_cnt <= #TP 0;
        ext_err_cnt_limit_over <= #TP 0;
    end else if(ext_err_cnt_clr) begin
        ext_err_cnt <= #TP 0;
        ext_err_cnt_limit_over <= #TP 0;
    end else if((smlh_margin_cmd==S_CMD_TIM_L || smlh_margin_cmd==S_CMD_TIM_R || smlh_margin_cmd==S_CMD_VOL_U || smlh_margin_cmd==S_CMD_VOL_D) && step_margin_exe_sts==2'b10) begin
    // valid when step_margin_exe_sts==S_RXM_ACTIVE 
        ext_err_cnt <= #TP rpipe_margin_error_cnt;
        ext_err_cnt_limit_over <= #TP (rpipe_margin_error_cnt>err_cnt_limit) ? 1'b1 : 1'b0;
    end

// Error Count Selector
// cfg_margin_ind_error_sampler = 0:int_err_cnt  1:ext_err_cnt
assign err_cnt            = (cfg_margin_ind_error_sampler)? ext_err_cnt : int_err_cnt;
assign err_cnt_limit_over = (cfg_margin_ind_error_sampler)? ext_err_cnt_limit_over : int_err_cnt_limit_over;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        current_my_margin_type_d   <= #TP 4'h0;
        current_my_margin_payload_d <= #TP 8'h0;
        step_margin_type_last <= #TP 4'h0;
        step_margin_payload_last <= #TP 8'h0;
    end else if(!power_saving_lanes_active) begin
        current_my_margin_type_d   <= #TP current_my_margin_type_d;
        current_my_margin_payload_d <= #TP current_my_margin_payload_d;
        step_margin_type_last <= #TP step_margin_type_last;
        step_margin_payload_last <= #TP step_margin_payload_last;
    end else if(goto_normal_settings) begin
        current_my_margin_type_d   <= #TP current_my_margin_type;
        current_my_margin_payload_d <= #TP current_my_margin_payload;
        step_margin_type_last <= #TP 4'h0;
        step_margin_payload_last <= #TP 8'h0;
    end else begin
        current_my_margin_type_d   <= #TP current_my_margin_type;
        current_my_margin_payload_d <= #TP current_my_margin_payload;

        // latch the last Margin Type/Margin Payload for setting the Error Count Limit while in Margining
        if(current_my_margin_cmd_changed) begin
            // store the last step margin command
            if(current_my_margin_type==S_TYPE_STEP_MARGIN_TIM || current_my_margin_type==S_TYPE_STEP_MARGIN_VOL) begin
                step_margin_type_last <= #TP current_my_margin_type;
                step_margin_payload_last <= #TP current_my_margin_payload;
            end
        end
    end

// change flag of the margin command -> asserted whenever the margin command is changed
assign current_my_margin_cmd_changed = ((current_my_margin_type_d!=current_my_margin_type) || (current_my_margin_payload_d!=current_my_margin_payload));
// change flag of the step margin -> asserted when the step margin command is changed
assign step_margin_changed = ( current_my_margin_cmd_changed &&
                              (current_my_margin_type==S_TYPE_STEP_MARGIN_TIM || current_my_margin_type==S_TYPE_STEP_MARGIN_VOL) &&
                              (step_margin_type_last!=current_my_margin_type || step_margin_payload_last!=current_my_margin_payload) );
                    
// Sample Count

// External Sample Count
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        ext_sample_count <= #TP 0;
    end else if(!current_data_rate_g4over || step_margin_changed) begin
        ext_sample_count <= #TP 0;
    end else if(step_margin_exe_sts!=2'b10) begin
        ext_sample_count <= #TP ext_sample_count;
    end else begin
        // Add the diff value because it might be cleared when in Recovery
        ext_sample_count <= #TP rpipe_margin_sampl_cnt;
    end

// Selected Sample Count
// Use Sample Count (MIndErrorSampler=1 and MSampleReportingMethod=0)
assign sample_count = (cfg_margin_ind_error_sampler && !cfg_margin_sample_reporting_method)? ext_sample_count : 0;

// SampleRateTiming/Voltage
// MIndErrorSampler=0 -> Fixed to 3Fh
// Else - cfg_margin_*
assign sample_reporting_method = (!cfg_margin_ind_error_sampler)? 1'b1  :  cfg_margin_sample_reporting_method;
assign sample_rate_voltage     = (!cfg_margin_ind_error_sampler)? 6'h3F :  cfg_margin_sample_rate_voltage    ;
assign sample_rate_timing      = (!cfg_margin_ind_error_sampler)? 6'h3F :  cfg_margin_sample_rate_timing     ;

`ifndef SYNTHESIS
// enum for debug

// receiver number
typedef enum logic [2:0] {
    BROADCAST   = 3'd0,
    RX_A        = 3'd1,
    RX_B        = 3'd2,
    RX_C        = 3'd3,
    RX_D        = 3'd4,
    RX_E        = 3'd5,
    RX_F        = 3'd6,
    RESERVED    = 3'd7
} rx_num_e;

// margin command
typedef enum logic [11:0] {
    NO_COMMAND           ,
    REP_MGN_CONT_CAP     ,
    REP_M_NUM_VOL_STEPS  ,
    REP_M_NUM_TIM_STEPS  ,
    REP_M_MAX_TIM_OFFSET ,
    REP_M_MAX_VOL_OFFSET ,
    REP_SAMPL_RATE_VOL   ,
    REP_SAMPL_RATE_TIM   ,
    REP_M_SAMPL_CNT      ,
    REP_M_MAX_LANES      ,
    SET_ERR_CNT_LIMIT    ,
    GOTO_NORMAL_SETTINGS ,
    CLR_ERR_LOG          ,
    STEP_MGN_TIM_R       ,
    STEP_MGN_TIM_L       ,
    STEP_MGN_VOL_U       ,
    STEP_MGN_VOL_D       ,
    VENDOR_DEFINED
} cmd_e;

// command for the phy if
typedef enum logic [2:0] {
    PIPE_IDLE       = 3'b000,
    PIPE_STEP_MGN_L = 3'b001,
    PIPE_STEP_MGN_R = 3'b011,
    PIPE_STEP_MGN_U = 3'b101,
    PIPE_STEP_MGN_D = 3'b111
} pipe_cmd_e;

// margin command is determined by {usage_model, margin_type, margin_payload}
function automatic cmd_e func_margin_cmd (input [3:0] current_my_margin_type, input [7:0] current_my_margin_payload) ;
  casez({current_my_margin_type, current_my_margin_payload})
    {1'b0, 3'b111, 8'h9C}        :  return NO_COMMAND           ;
    {1'b0, 3'b001, 8'h88}        :  return REP_MGN_CONT_CAP     ;
    {1'b0, 3'b001, 8'h89}        :  return REP_M_NUM_VOL_STEPS  ;
    {1'b0, 3'b001, 8'h8A}        :  return REP_M_NUM_TIM_STEPS  ;
    {1'b0, 3'b001, 8'h8B}        :  return REP_M_MAX_TIM_OFFSET ;
    {1'b0, 3'b001, 8'h8C}        :  return REP_M_MAX_VOL_OFFSET ;
    {1'b0, 3'b001, 8'h8D}        :  return REP_SAMPL_RATE_VOL   ;
    {1'b0, 3'b001, 8'h8E}        :  return REP_SAMPL_RATE_TIM   ;
    {1'b0, 3'b001, 8'h8F}        :  return REP_M_SAMPL_CNT      ;
    {1'b0, 3'b001, 8'h90}        :  return REP_M_MAX_LANES      ;
    {1'b0, 3'b010, 2'b11, 6'h??} :  return SET_ERR_CNT_LIMIT    ;
    {1'b0, 3'b010, 8'h0F}        :  return GOTO_NORMAL_SETTINGS ;
    {1'b0, 3'b010, 8'h55}        :  return CLR_ERR_LOG          ;
    {1'b0, 3'b011, 2'b?0, 6'h??} :  return STEP_MGN_TIM_R       ;
    {1'b0, 3'b011, 2'b?1, 6'h??} :  return STEP_MGN_TIM_L       ;
    {1'b0, 3'b100, 1'b0, 7'h??}  :  return STEP_MGN_VOL_U       ;
    {1'b0, 3'b100, 1'b1, 7'h??}  :  return STEP_MGN_VOL_D       ;
    {1'b0, 3'b101, 8'h??}        :  return VENDOR_DEFINED       ;
    default                      :  return NO_COMMAND           ;
  endcase
endfunction

rx_num_e    MY_RECEIVER_NUMBER;
cmd_e       MY_MARGIN_COMMAND;
pipe_cmd_e  MY_PIPE_COMMAND;

rx_num_e    CFG_RECEIVER_NUMBER;
cmd_e       CFG_MARGIN_COMMAND;
pipe_cmd_e  CFG_PIPE_COMMAND;

assign MY_RECEIVER_NUMBER = rx_num_e'(current_my_receiver_num);
assign MY_MARGIN_COMMAND  = func_margin_cmd(current_my_margin_type, current_my_margin_payload);
assign MY_PIPE_COMMAND    = pipe_cmd_e'(smlh_margin_cmd);

assign CFG_RECEIVER_NUMBER = rx_num_e'(int_cfg_receiver_num);
assign CFG_MARGIN_COMMAND  = func_margin_cmd(int_cfg_margin_type, int_cfg_margin_payload);

`endif // SYNTHESIS

endmodule

