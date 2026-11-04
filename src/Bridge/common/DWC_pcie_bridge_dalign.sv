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
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_dalign.sv#8 $
// -------------------------------------------------------------------------
// This block packs AMBA size transactions into data width transactions
// based on input data strobes
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_bridge_dalign (
            clk,
            rst_n,
            init_n,
            data_rdy_in,
            data_vld_in,
            data_size_in,
            data_last_in,
            data_strb_in,
            data_wep_strb_in,
            data_wsilentDrop_strb_in,
            data_wsilentDrop_strb_in_masked,
            data_in,
            data_rdy_out,
            data_vld_out,
            data_last_out,
            data_strb_out,
            data_wep_strb_out,
            data_wsilentDrop_strb_out,
            data_wsilentDrop_strb_out_masked,
            data_out
            );

// External Parameters
parameter DW     =  32 ;                 // Width Of Data In Bits
parameter NC     =   4 ;                 // Number Data Strobes
parameter LS     =   2 ;                 // Log2(Number Data Strobes Per Data)

// Internal Parameters
parameter CW     = DW / NC ;             // Width Data Per Each Strobe
parameter ND     = NC / 4 ;              // Number Of DWORDs
parameter WW     = DW / ND ;             // True DWORD Width
parameter BW     = NC * 8 ;              // All Bytes Width
parameter TB     = BW * 2 ;              // 2 * All Bytes Width

parameter TD     = ND - 1 ;              // Temp Number Of Save DWORDs
parameter SD     = (ND == 1) ? ND : TD ; // Real Number Of Save DWORDs
parameter NS     = SD * 4 ;              // Number Of Save Strobes
parameter SW     = CW * NS ;             // Width Save Data

parameter DC     = (ND == 1)  ? 1 :
                   (ND == 2)  ? 2 :
                   (ND == 4)  ? 3 :
                   (ND == 8)  ? 4 :
                   (ND == 16) ? 5 :
                   (ND == 32) ? 6 : 7 ;  // DWORD Count Width
parameter OD     = ND + SD ;             // Output Shift Number DWORDs
parameter SS     = OD * 4 ;              // Output Shift Strobe Width
parameter OS     = OD * WW ;             // Output Shift Reg Width
parameter RC     = (DC * 2) + 1 ;        // Total Output Shift Count Width
parameter SC     = DC + 2  ;             // Strobe Count Width
parameter CL     = OD + ND ;             // IN + Shift DWORD Length
parameter CD     = CL * WW ;             // IN + Shift Data Length
parameter CS     = CL * 4 ;              // IN + Shift Strobe Length
parameter BC     = LS + 1 ;              // Byte Counter Width
parameter TW     = DW * 2 ;              // Double Data Width For Shifting
parameter TS     = NC * 2 ;              // Double Strobe Width For Shifting
parameter PS     = CL * 32;              // Shift+Out Non Parity Data Width
parameter OB     = OD * 32;              // Output Shift Non Parity Byte Width

parameter PM     = `CX_RAS_PARITY_MODE;

parameter TP     = `TP;

localparam [8:0] BUS_INIT_BYTE = PM ? 9'b100000000 : 9'b000000000;
parameter  RAS_PDW = 8 ; // Input Protected Data Width, number of data bits protected by RAS
localparam RAS_PCW = RAS_PDW + 1; // Input Protected Chunk Width, number of bits protected by RAS (data + parity)

input                 clk;               // Sys Clock
input                 rst_n;             // Async Reset
input                 init_n;            // Sync Init
input                 data_rdy_in;       // Data Ready In
input                 data_vld_in;       // Data Valid In
input [2:0]           data_size_in;      // Data Size In
input                 data_last_in;      // Data Last In
input [NC-1:0]        data_strb_in;      // Data Strobe In
input [NC-1:0]        data_wep_strb_in;  // Data poison Strobe In
input [NC-1:0]        data_wsilentDrop_strb_in;  // Data silent drop Strobe In
input [NC-1:0]        data_wsilentDrop_strb_in_masked;  // Data silent drop Strobe In Masked
input [DW-1:0]        data_in;           // Data In

output                data_rdy_out;      // Data Ready Out
output                data_vld_out;      // Data Valid Out
output                data_last_out;     // Data Last Out
output [NC-1:0]       data_strb_out;     // Data Strobe Out
output [NC-1:0]       data_wep_strb_out;     // Data poison Strobe Out
output [NC-1:0]       data_wsilentDrop_strb_out;     // Data silent drop Strobe Out
output [NC-1:0]       data_wsilentDrop_strb_out_masked;     // Data silent drop Strobe Out Masked
output [DW-1:0]       data_out;          // Data


// Outputs
wire                  data_rdy_out;      // Data Ready Out
wire                  data_vld_nxt;      // Data Valid Out Next
reg                   data_vld_out;      // Data Valid Out
wire [NC-1:0]         data_strb_out;     // Data Strobe Out
wire                  data_last_nxt;     // Data Last Out Next
reg                   data_last_out;     // Data Last Out
wire [DW-1:0]         data_out;          // Data Out

  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam S_WR_IDLE       = 1'b0;
  localparam S_WR_MULTI_BEAT = 1'b1;
  localparam SS_L            = $clog2(SS);
  localparam CS_L            = $clog2(CS);
  localparam LOG2NC          = $clog2(NC);
  localparam LOG2ND          = $clog2(ND)+1;

  // -------------------------------------------------------------------------------------
  // Internal wire/reg
  // -------------------------------------------------------------------------------------
  // Write FSM
  reg                                      s_wr_fsm;
  reg                                      r_wr_fsm;
  reg                                      s_first_beat;

  // Transfer size
  wire                                     s_size_byte, s_size_two_byte, s_size_dword_lrg;
  reg                                      r_size_byte, r_size_two_byte, r_size_dword_lrg;

wire                  size_byte;         // Transfer Size Byte
wire                  size_two_byte;     // Transfer Size Two Bytes
wire                  size_dword_lrg;    // Transfer Size DWORD Or Larger

wire                  no_byte_wr_det;    // 0 Byte Write Detect
wire                  no_byte_nxt;       // 0 Byte Write Next
reg                   no_byte_vld;       // 0 Byte Write  Valid
wire                  data_accepted;     // Data Accepted
wire                  update_data;       // Update Data

wire [LS-1:0]         low_byte_loc;      // Low Byte Location
wire [LS-1:0]         low_twbyte_loc;    // Low Two Byte Location
wire [LS-1:0]         one_two_loc;       // Low One Or Two Byte Location
wire [DC-1:0]         low_dword_loc;     // Low DWORD Location
wire [DC-1:0]         high_dword_loc;    // High DWORD Location

// Handling Of DWORD Or Larger Data
wire                  shift_ovrld;       // Detect Shift Overload
wire                  update_shift;      // Update Shift Data
wire [RC-1:0]         shift_cnt_glb;     // Shift Reg Count Global
wire [RC-1:0]         shift_cnt_nxt;     // Shift Reg Count Next
reg [RC-1:0]          shift_cnt;         // Shift Reg Count
wire                  shift_stall;       // Stall Requests When Last
wire [OS-1:0]         data_shift_glb;    // Out Shift Reg Global
wire [OS-1:0]         data_shift_nxt;    // Out Shift Reg Next
reg [OS-1:0]          data_shift;        // Out Shift Reg
wire [SS-1:0]         strb_shift_glb;    // Out Shift Reg Global
wire [SS-1:0]         strb_shift_nxt;    // Out Shift Reg Next
reg [SS-1:0]          strb_shift;        // Out Shift Reg
wire [SS-1:0]         wep_strb_shift_glb;// Out Data poised Strobes Shift Reg Global
wire [SS-1:0]         wep_strb_shift_nxt;// Out Data poised Strobes Shift Reg Next
reg [SS-1:0]          wep_strb_shift;    // Out Data poised Strobes Shift Reg
wire [SS-1:0]         wsilentDrop_strb_shift_glb;// Out Data Silent dropped Strobes Shift Reg Global
wire [SS-1:0]         wsilentDrop_strb_shift_nxt;// Out Data Silent dropped Strobes Shift Reg Next
reg [SS-1:0]          wsilentDrop_strb_shift;    // Out Data Silent dropped Strobes Shift Reg
wire [SS-1:0]         wsilentDropMasked_strb_shift_glb;// Out Data Silent dropped Strobes Shift Reg Global
wire [SS-1:0]         wsilentDropMasked_strb_shift_nxt;// Out Data Silent dropped Strobes Shift Reg Next
reg [SS-1:0]          wsilentDropMasked_strb_shift;    // Out Data Silent dropped Strobes Shift Reg
wire [1:0]            last_shift_glb;    // Shift Last Global
wire [1:0]            last_shift_nxt;    // Shift Last Next
reg [1:0]             last_shift;        // Shift Last
wire                  shift_vld_glb;     // Shift Valid Global
wire                  shift_vld_nxt;     // Shift Valid Next
reg                   shift_vld;         // Shift Valid
wire                  shift_last_glb;    // Shift Valid Global
wire                  shift_last_nxt;    // Shift Valid Next
reg                   shift_last;        // Shift Valid

// Handling Of Byte Or Two Byte Data
wire                  in_det;            // Input Detected

wire                  update_bytes;      // Update Bytes
wire                  bytes_act_nxt;     // Bytes Active Next
reg                   bytes_act;         // Bytes Active
wire                  new_bytes_det;     // New Bytes
wire [DW-1:0]         data_bytes_glb;    // Out Bytes Reg Global
wire [DW-1:0]         data_bytes;        // Out Bytes Reg
wire [NC-1:0]         strb_bytes_glb;    // Out Bytes Reg Global
wire [NC-1:0]         strb_bytes;        // Out Bytes Reg
wire [NC-1:0]         wep_strb_bytes_glb;// Out Poisoned Bytes Reg Global
wire [NC-1:0]         wep_strb_bytes;    // Out Poisoned Bytes Reg
wire [NC-1:0]         wsilentDrop_strb_bytes_glb;// Out Silent dropped Bytes Reg Global
wire [NC-1:0]         wsilentDropMasked_strb_bytes_glb;// Out Silent dropped Bytes Reg Global
wire [NC-1:0]         wsilentDrop_strb_bytes;    // Out Silent dropped Bytes Reg
wire [NC-1:0]         wsilentDropMasked_strb_bytes;    // Out Silent dropped Bytes Reg
wire                  last_bytes_nxt;    // Bytes Last Next
reg                   last_bytes;        // Bytes Last
wire                  bytes_vld_glb;     // Bytes Valid Global
wire                  bytes_vld_nxt;     // Bytes Valid Next
reg                   bytes_vld;         // Bytes Valid

wire                  shift_init_det;    // Shift Init Detect
wire                  shift_adv;         // Shift Accepted Advance

wire [DC-1:0]         idw_total_cnt_tmp; // Shift In DWORD Total Count
wire [NC-1:0]         istrb_shift_tmp;   // Shift In Strobe Temp
wire [NC-1:0]         iwepstrb_shift_tmp;// Shift In Poisoned Strobe Temp
wire [NC-1:0]         iwsilentDropstrb_shift_tmp;// Shift In Silent Dropped Strobe Temp
wire [NC-1:0]         iwsilentDropstrbMasked_shift_tmp;// Shift In Silent Dropped Masked Strobe Temp

// Split Parity From Data
wire [BW-1:0]         inshft_nonp_data;  // In Shift Non Parity Data
wire [NC-1:0]         inshft_par_bits;   // In Shift Parity Bits
wire [BW-1:0]         init_nonp_data;    // Init Non Parity Data
wire [NC-1:0]         init_par_bits;     // Init Parity Bits
wire [NC-1:0]         init_par_bit_b2t;

wire [OB-1:0]         outshft_nonp_data; // Out Shift Non Parity Data
wire [SS-1:0]         outshft_par_bits;  // Out Shift Parity Bits

wire [OB-1:0]         adv_nonp_data;     // Advance Non Parity Data
wire [SS-1:0]         adv_par_bits;      // Advance Parity Bits
wire [SS-1:0]         adv_par_bits_b2t;

wire [OB-1:0]         shifta_nonp_data;  // Empty Adv Non Parity Data
wire [SS-1:0]         shifta_par_bits;   // Empty Adv Parity Bits
wire [SS-1:0]         shifta_par_bits_b2t;

wire [PS-1:0]         nonp_comb_data;    // Combined I/O Non Parity Data
wire [CS-1:0]         par_comb_bits;     // Combined I/O Parity Bits
wire [PS-1:0]         nonp_comb_data2;   // Comb/Shifted Non Parity Data
wire [CS-1:0]         par_comb_bits2;    // Comb/Shifted Parity Bits
wire [CS-1:0]         par_comb_bits2_b2t;
wire [OS-1:0]         par_comb_data2;    // Shift Parity Combine Data

wire [OS-1:0]         data_shift_tmp;    // Shift Data Temp
reg [RC-1:0]          adv_shift_cnt;     // Shift Adnavce Count
wire [SS-1:0]         strb_shift_tmp;    // Shift Strobe Temp
wire [SS-1:0]         wep_strb_shift_tmp;// Shift Data poisoned Strobe Temp
wire [SS-1:0]         wsilentDrop_strb_shift_tmp;// Shift Data Silent Dropped Strobe Temp
wire [SS-1:0]         wsilentDropMasked_strb_shift_tmp;// Shift Data Silent Dropped Strobe Temp
wire [1:0]            last_shift_tmp;    // Shift Last Temp
wire [RC-1:0]         shift_cnt_tmp;     // Shift Count Temp
reg [RC-1:0]          shift_empty_cnt;   // Shift Empty Count
wire                  shift_reqd;        // Shift Required
wire [SS-1:0]         strb_shift_tmp2;   // Shift Strobe Temp
wire [SS-1:0]         wep_strb_shift_tmp2;// Shift Data Poisoned Strobe Temp
wire [SS-1:0]         wsilentDrop_strb_shift_tmp2;// Shift Data Silent Dropped Strobe Temp
wire [SS-1:0]         wsilentDropMasked_strb_shift_tmp2;// Shift Data Silent Dropped Strobe Temp
wire [CS-1:0]         comb_strb;         // Shift Combine Strobe
wire [CS-1:0]         comb_strb2;        // ShiftCombine Strobe
wire [CS-1:0]         wep_comb_strb;     // Shift Combine Poisoned Strobe
wire [CS-1:0]         wep_comb_strb2;    // Shift Combine Poisoned Strobe
wire [CS-1:0]         wsilentDrop_comb_strb;     // Shift Combine Poisoned Strobe
wire [CS-1:0]         wsilentDrop_comb_strb2; // Shift Combine Silent Dropped Strobe
wire [CS-1:0]         wsilentDropMasked_comb_strb;     // Shift Combine Poisoned Strobe
wire [CS-1:0]         wsilentDropMasked_comb_strb2; // Shift Combine Silent Dropped Strobe
wire [OS-1:0]         data_shift_tmp3;   // Shift Data Temp
wire [SS-1:0]         strb_shift_tmp3;   // Shift Strobe Temp
wire [SS-1:0]         wep_strb_shift_tmp3;// Shift Data Poisoned Strobe Temp
wire [SS-1:0]         wsilentDrop_strb_shift_tmp3;// Shift Data Silent Dropped Strobe Temp
wire [SS-1:0]         wsilentDropMasked_strb_shift_tmp3;// Shift Data Silent Dropped Strobe Temp
wire [RC-1:0]         shift_cnt_tmp2;    // Shift Count Temp
wire                  shift_cnt_zero;    // Shift Count Is Zero
wire [RC-1:0]         shift_msb_cnt;     // Shift MSB Count
wire                  last_ovrfl_det;    // Shift Overflow Detect
wire [1:0]            last_shift_tmp2;   // Shift Last Temp
wire                  shift_last_tmp;    // Shift Last Temp
wire                  shift_vld_tmp;     // Shift Valid Temp


// Updated Bytes
wire [1:0]            lowb_pos;          // Bytes Low Position
wire [LS-1:0]         init_drop_pos;     // Bytes Initial Drop Position
wire [BC-1:0]         bytes_to_add;      // Bytes To Add
wire [BC-1:0]         byte_max_val;      // Bytes Max Value
wire                  bytes_max;         // Bytes Is Max
logic [BC-1:0]        byte_count_nxt;    // Bytes Byte Count Next
reg [BC-1:0]          byte_count;        // Bytes Byte Count
wire [BC-1:0]         bempty_msb;        // Bytes Empty MSB
reg [BC-1:0]          bempty_count;      // Bytes Empty Count

wire [BW-1:0]         nonp_data_ibytes;  // In Bytes Non Parity Data
wire [NC-1:0]         par_bits_ibytes;   // In Bytes Parity Bits
wire [NC-1:0]         par_bits_ibytes_b2t;
wire [BW-1:0]         nonp_data_obytes;  // Out Bytes Non Parity Data
wire [NC-1:0]         par_bits_obytes;   // Out Bytes Parity Bits
wire [NC-1:0]         par_bits_obytes_b2t;
wire [TB-1:0]         nonp_data_dblbytes;// In+Out Bytes Non Parity Data
wire [TS-1:0]         par_bits_dblbytes; // In+Out Bytes Parity Bits
wire [TB-1:0]         nonp_data_shfbytes;// Shifted Bytes Non Parity Data
wire [TS-1:0]         par_bits_shfbytes_b2t;
wire [TS-1:0]         par_bits_shfbytes; // Shifted Bytes Parity Bits
wire                  par_mode;
wire [NC-1:0]         strb_ibytes_tmp;   // Bytes In Strobe
wire [NC-1:0]         strb_obytes_tmp;   // Bytes Out Strobe
wire [TS-1:0]         strb_dblbytes_tmp; // Bytes Double Strobe
wire [TS-1:0]         strb_shfbytes_tmp; // Bytes Shifted Strobe
wire [NC-1:0]         wep_strb_ibytes_tmp;   // Bytes In Poisoned Strobe
wire [NC-1:0]         wep_strb_obytes_tmp;   // Bytes Out Poisoned Strobe
wire [TS-1:0]         wep_strb_dblbytes_tmp; // Bytes Double Poisoned Strobe
wire [TS-1:0]         wep_strb_shfbytes_tmp; // Bytes Shifted Poisoned Strobe
wire [NC-1:0]         wsilentDrop_strb_ibytes_tmp;   // Bytes In Silent Dropped Strobe
wire [NC-1:0]         wsilentDrop_strb_obytes_tmp;   // Bytes Out Silent Dropped Strobe
wire [TS-1:0]         wsilentDrop_strb_dblbytes_tmp; // Bytes Double Silent Dropped Strobe
wire [TS-1:0]         wsilentDrop_strb_shfbytes_tmp; // Bytes Shifted Silent Dropped Strobe
wire [NC-1:0]         wsilentDropMasked_strb_ibytes_tmp;   // Bytes In Silent Dropped Strobe
wire [NC-1:0]         wsilentDropMasked_strb_obytes_tmp;   // Bytes Out Silent Dropped Strobe
wire [TS-1:0]         wsilentDropMasked_strb_dblbytes_tmp; // Bytes Double Silent Dropped Strobe
wire [TS-1:0]         wsilentDropMasked_strb_shfbytes_tmp; // Bytes Shifted Silent Dropped Strobe

  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
assign par_mode = PM;
  // -------------------------------------------------------------------------------------
  // Write FSM
  always @(*) begin : proc_comb_wr_fsm
    // Initialise
    s_wr_fsm     = r_wr_fsm;
    s_first_beat = 1'b0;

    if (data_rdy_out) begin
      case (r_wr_fsm)
        S_WR_IDLE : begin
          s_first_beat = data_vld_in;
          if (data_vld_in && !data_last_in) begin
            s_wr_fsm = S_WR_MULTI_BEAT;
          end
        end
        S_WR_MULTI_BEAT : begin
          s_first_beat = 1'b0;
          if (data_last_in) begin
            s_wr_fsm = S_WR_IDLE;
          end
        end
      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin : proc_seq_wr_fsm
    if (!rst_n) begin
     r_wr_fsm <= # TP S_WR_IDLE;
    end else if (data_rdy_out) begin
     r_wr_fsm <= # TP s_wr_fsm;
    end
  end

  // -------------------------------------------------------------------------------------
  // Determine Transfer Size
  assign s_size_byte      = (data_size_in == 3'b000);
  assign s_size_two_byte  = (data_size_in == 3'b001);
  assign s_size_dword_lrg = !(s_size_byte || s_size_two_byte);

  always @(posedge clk or negedge rst_n) begin : proc_seq_size_info
    if (!rst_n) begin
      r_size_byte      <= # TP 1'b0;
      r_size_two_byte  <= # TP 1'b0;
      r_size_dword_lrg <= # TP 1'b0;
    end else if (s_first_beat) begin
      r_size_byte      <= # TP s_size_byte;
      r_size_two_byte  <= # TP s_size_two_byte;
      r_size_dword_lrg <= # TP s_size_dword_lrg;
    end
  end

  assign size_byte      = s_first_beat ? s_size_byte      : r_size_byte;
  assign size_two_byte  = s_first_beat ? s_size_two_byte  : r_size_two_byte;
  assign size_dword_lrg = s_first_beat ? s_size_dword_lrg : r_size_dword_lrg;

  // -------------------------------------------------------------------------------------
  // Detect Data out Accepted
  assign data_accepted = (data_vld_out && data_rdy_in);

// Ready To Accept Data
assign data_rdy_out = (!shift_stall &&
                       (!data_vld_out || data_accepted));

// Update Data
assign update_data = (data_vld_in && data_rdy_out);

// Locate Low Byte
assign low_byte_loc = get_lsb_pos(data_strb_in);

// Locate Low Byte
assign low_twbyte_loc = get_lstb_pos(data_strb_in);

// Locate Lowest Populated DWORD
assign low_dword_loc = get_lsd_pos(data_strb_in);

// Locate Highest Populated DWORD
assign high_dword_loc = get_msd_pos(data_strb_in);

// Begin Handling Of DWORD Size Or Larger


// Detect Shift Init
assign shift_init_det = ((data_vld_in == 1'b0) ||
                         (shift_stall == 1'b1));

// Detect Shift Advance
assign shift_adv = (shift_vld && data_rdy_in);

// Initialize Inputs
assign idw_total_cnt_tmp = shift_init_det ? {DC{1'b0}} :
                           ((high_dword_loc + 1'b1) - low_dword_loc);
assign istrb_shift_tmp   = shift_init_det ? {NC{1'b0}} :
                           (data_strb_in >> ({low_dword_loc,2'b00}));
assign iwepstrb_shift_tmp   = shift_init_det ? {NC{1'b0}} :
                           (data_wep_strb_in >> ({low_dword_loc,2'b00}));
assign iwsilentDropstrb_shift_tmp   = shift_init_det ? {NC{1'b0}} :
                           (data_wsilentDrop_strb_in >> ({low_dword_loc,2'b00}));
assign iwsilentDropstrbMasked_shift_tmp   = shift_init_det ? {NC{1'b0}} :
                           (data_wsilentDrop_strb_in_masked >> ({low_dword_loc,2'b00}));

// Initialize Shift Input Data
// Extract Input Data & Parity To Get Through Shifters
// Without Multipliers
assign inshft_nonp_data = get_data_bits(data_in);
assign inshft_par_bits  = get_parity_bits(data_in);

assign init_nonp_data   = shift_init_det ? {BW{1'b0}} :
                          (inshft_nonp_data  >> ({low_dword_loc,5'b00000}));
assign init_par_bit_b2t = bin2therm_nc({{(RC-DC){1'b0}},low_dword_loc,2'b00}, 1'b0);
assign init_par_bits    = shift_init_det ? {NC{par_mode}} :
                          (inshft_par_bits >> ({low_dword_loc,2'b00})) | init_par_bit_b2t;

// Get New Shift Count If Advanced Count
always @(shift_cnt) begin : adv_shift_cnt_PROC
reg [31:0]  tmp_cnt;

    if (shift_cnt < ND) begin
        tmp_cnt = 32'b0;
    end
    else begin
        tmp_cnt = (shift_cnt - ND);
    end

    adv_shift_cnt = tmp_cnt[RC-1:0];
end

// Shift Used Locations & Reduce Counts
assign strb_shift_tmp = shift_adv ? (strb_shift >> NC) : strb_shift;
assign wep_strb_shift_tmp = shift_adv ? (wep_strb_shift >> NC) : wep_strb_shift;
assign wsilentDrop_strb_shift_tmp = shift_adv ? (wsilentDrop_strb_shift >> NC) : wsilentDrop_strb_shift;
assign wsilentDropMasked_strb_shift_tmp = shift_adv ? (wsilentDropMasked_strb_shift >> NC) : wsilentDropMasked_strb_shift;
assign last_shift_tmp = shift_adv ? (last_shift >> 1)  : last_shift;
assign shift_cnt_tmp  = shift_adv ? adv_shift_cnt : shift_cnt;

// Extract Input Data & Parity To Get Through Shifters
// Without Multipliers
assign outshft_nonp_data = get_outshft_data_bits(data_shift);
assign outshft_par_bits  = get_outshft_parity_bits(data_shift);

// Shift Out Last Transfer
assign adv_nonp_data  = shift_adv ? (outshft_nonp_data >> BW) : outshft_nonp_data;
assign adv_par_bits_b2t = bin2therm_ss(NC, 1'b0);
assign adv_par_bits   = shift_adv ? ((outshft_par_bits >> NC) | adv_par_bits_b2t): outshft_par_bits;


// Shift Empty Count
always @(shift_cnt_tmp) begin : shift_empty_cnt_PROC
reg [31:0]  tmp_cnt;

    tmp_cnt = 32'b0;
    if (shift_cnt_tmp <= OD) begin
        tmp_cnt = (OD - shift_cnt_tmp);
    end

    shift_empty_cnt = tmp_cnt[RC-1:0];
end


// Data Shift Dependent On Configuration
// Bypassed For 32 Bit Slave Bus
assign shift_reqd = ((update_shift == 1'b1) &&
                     (shift_stall == 1'b0) &&  (ND > 1));

// Empty Spaces To Left
assign shifta_nonp_data = (adv_nonp_data << ({shift_empty_cnt,5'b00000}));
assign shifta_par_bits_b2t = bin2therm_ss({shift_empty_cnt,2'b00}, 1'b1);

assign shifta_par_bits  = (adv_par_bits << ({shift_empty_cnt,2'b00})) | shifta_par_bits_b2t;
assign strb_shift_tmp2  = (strb_shift_tmp << ({shift_empty_cnt,2'b00}));
assign wep_strb_shift_tmp2  = (wep_strb_shift_tmp << ({shift_empty_cnt,2'b00}));
assign wsilentDrop_strb_shift_tmp2  = (wsilentDrop_strb_shift_tmp << ({shift_empty_cnt,2'b00}));
assign wsilentDropMasked_strb_shift_tmp2  = (wsilentDropMasked_strb_shift_tmp << ({shift_empty_cnt,2'b00}));


// Combine In & Shift
assign nonp_comb_data = {init_nonp_data,shifta_nonp_data};
assign par_comb_bits = {init_par_bits,shifta_par_bits};
assign comb_strb = {istrb_shift_tmp,strb_shift_tmp2};
assign wep_comb_strb = {iwepstrb_shift_tmp,wep_strb_shift_tmp2};
assign wsilentDrop_comb_strb = {iwsilentDropstrb_shift_tmp,wsilentDrop_strb_shift_tmp2};
assign wsilentDropMasked_comb_strb = {iwsilentDropstrbMasked_shift_tmp,wsilentDropMasked_strb_shift_tmp2};

// Now Shift Combined Data & Strobes Back
assign nonp_comb_data2 = (nonp_comb_data >> ({shift_empty_cnt,5'b00000}));
assign par_comb_bits2_b2t = bin2therm_cs({shift_empty_cnt,2'b00}, 1'b0);
assign par_comb_bits2 = (par_comb_bits >> ({shift_empty_cnt,2'b00})) | par_comb_bits2_b2t;

// Put Data & Parity Back Together
assign par_comb_data2 = assm_outshft_parity_data(nonp_comb_data2[OB-1:0],par_comb_bits2[SS-1:0]);
assign data_shift_tmp  = assm_outshft_parity_data(adv_nonp_data,adv_par_bits);
assign data_shift_tmp3 = shift_reqd ? par_comb_data2 :
                         (ND > 1) ? data_shift_tmp :
                         {{SW{1'b0}},data_in};
assign comb_strb2 = (comb_strb >> ({shift_empty_cnt,2'b00}));
assign wep_comb_strb2 = (wep_comb_strb >> ({shift_empty_cnt,2'b00}));
assign wsilentDrop_comb_strb2 = (wsilentDrop_comb_strb >> ({shift_empty_cnt,2'b00}));
assign wsilentDropMasked_comb_strb2 = (wsilentDropMasked_comb_strb >> ({shift_empty_cnt,2'b00}));



// Connect Shifter Output
assign strb_shift_tmp3 = shift_reqd ? comb_strb2[SS-1:0] :
                         (ND > 1) ? strb_shift_tmp :
                         {{NS{1'b0}},data_strb_in};

assign wep_strb_shift_tmp3 = shift_reqd ? wep_comb_strb2[SS-1:0] :
                             (ND > 1) ? wep_strb_shift_tmp :
                             {{NS{1'b0}},data_wep_strb_in};

assign wsilentDrop_strb_shift_tmp3 = shift_reqd ? wsilentDrop_comb_strb2[SS-1:0] :
                                     (ND > 1) ? wsilentDrop_strb_shift_tmp :
                                     {{NS{1'b0}},data_wsilentDrop_strb_in};

assign wsilentDropMasked_strb_shift_tmp3 = shift_reqd ? wsilentDropMasked_comb_strb2[SS-1:0] :
                                     (ND > 1) ? wsilentDropMasked_strb_shift_tmp :
                                     {{NS{1'b0}},data_wsilentDrop_strb_in_masked};

// Next Shift Count
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign shift_cnt_tmp2 = size_dword_lrg ? (shift_cnt_tmp + idw_total_cnt_tmp) :
                        {RC{1'b0}};
// spyglass enable_block W164a

// Detect Shift Counter = 0
assign shift_cnt_zero = (shift_cnt_tmp2 == {RC{1'b0}});

// Detect Shift MSB Populated
assign shift_msb_cnt = shift_cnt_zero ? {RC{1'b0}} :
                       (shift_cnt_tmp2 - 1'b1);

// Detect Last In Overflow
assign last_ovrfl_det = (shift_msb_cnt > (ND - 1));

// Shift Last Out
assign last_shift_tmp2 = shift_cnt_zero ? 2'b00 :
                         (last_ovrfl_det &&
                          (data_vld_in && data_last_in && !shift_stall)) ? 2'b10 :
                         (data_vld_in && data_last_in && !shift_stall) ? 2'b01 :
                         last_shift_tmp;

// Determine Shift Last Output
assign shift_last_tmp = last_shift_tmp2[0];

// Stall Requests When Overloaded Shifter Contains Last
assign shift_stall = (last_shift == 2'b10);

// Shift Data Valid Out
assign shift_vld_tmp = ((shift_cnt_tmp2 >= ND) ||
                        (shift_last_tmp == 1'b1));

// Final Shifter Selections
assign data_shift_glb = data_shift_tmp3;
assign strb_shift_glb = strb_shift_tmp3;
assign wep_strb_shift_glb = wep_strb_shift_tmp3;
assign wsilentDrop_strb_shift_glb = wsilentDrop_strb_shift_tmp3;
assign wsilentDropMasked_strb_shift_glb = wsilentDropMasked_strb_shift_tmp3;
assign last_shift_glb = last_shift_tmp2;
assign shift_cnt_glb  = shift_cnt_tmp2;
assign shift_last_glb = shift_last_tmp;
assign shift_vld_glb  = shift_vld_tmp;


// End Handling Of DWORD Size Or Larger


// Begin Handling Of One Or Two Byte Size Only

// Detect Bytes Input
assign in_det = update_bytes;

// Detect Bytes Request Active
assign bytes_act_nxt = in_det ? 1'b1 :
                       data_accepted ? 1'b0 : bytes_act;

// Detect New Bytes Request
assign new_bytes_det = (in_det &&
                        (!bytes_act || last_bytes));

// Get Input Position Of First Byte
assign lowb_pos = get_lsb_map(data_strb_in);

// To Cover Warnings For All Configs
assign init_drop_pos = size_byte ? ({LS{1'b0}} + lowb_pos) :
                       ({LS{1'b0}} + {lowb_pos[1],1'b0});

// Bytes To Add
assign bytes_to_add = size_byte ? ({BC{1'b0}} + 2'b01) :
                      ({BC{1'b0}} + 2'b10);

// Max Bytes Count Value
assign byte_max_val = {1'b1,{(BC-1){1'b0}}};

// Detect Max Count
assign bytes_max = (byte_count == byte_max_val);


// Count Output Byte Locations To Drop Data
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation.
// This is the expected behavior
always_comb begin : byte_count_nxt_PROC
  if (update_bytes) begin

    if (data_last_in || bytes_max) begin
      byte_count_nxt = '0 ;
    end else begin
      if (new_bytes_det) begin
        byte_count_nxt = bytes_to_add + init_drop_pos ;
      end else begin
        byte_count_nxt = bytes_to_add + byte_count ;
      end
    end

  end else begin
    byte_count_nxt = byte_count ;
  end
end
// spyglass enable_block W164a

// Output MSb
assign bempty_msb = new_bytes_det ? {{(BC-LS){1'b0}},init_drop_pos} : byte_count;

// Get Output Empty Count
always @(bempty_msb) begin : bempty_count_PROC
reg [31:0]  tmp_cnt;

    if (bempty_msb > NC) begin
        tmp_cnt = 32'b0;
    end
    else begin
        tmp_cnt = (NC - bempty_msb);
    end

    bempty_count = tmp_cnt[BC-1:0];
end

// Select One Or Two Byte Location To Shift By
assign one_two_loc = size_byte ? low_byte_loc : low_twbyte_loc;


// Get Input Data & Shift Empty Out
assign nonp_data_ibytes = (inshft_nonp_data >> ({one_two_loc,3'b000}));
assign par_bits_ibytes_b2t = bin2therm_nc({{(RC-LS+2){1'b0}},one_two_loc}, 1'b0);
assign par_bits_ibytes  = (inshft_par_bits >> (one_two_loc)) | par_bits_ibytes_b2t;

//assign strb_ibytes_tmp = (data_strb_in >> (low_byte_loc));
assign strb_ibytes_tmp = (data_strb_in >> (one_two_loc));
assign wep_strb_ibytes_tmp = (data_wep_strb_in >> (one_two_loc));
assign wsilentDrop_strb_ibytes_tmp = (data_wsilentDrop_strb_in >> (one_two_loc));
assign wsilentDropMasked_strb_ibytes_tmp = (data_wsilentDrop_strb_in_masked >> (one_two_loc));

// Get Output Data & Shift Empty Out
assign nonp_data_obytes = (outshft_nonp_data[BW-1:0] << ({bempty_count,3'b000}));
assign par_bits_obytes_b2t = bin2therm_nc({{RC-BC+2{1'b0}},bempty_count}, 1'b1);

assign par_bits_obytes  = (outshft_par_bits[NC-1:0] << (bempty_count)) | par_bits_obytes_b2t;
assign strb_obytes_tmp = (strb_bytes << (bempty_count));
assign wep_strb_obytes_tmp = (wep_strb_bytes << (bempty_count));
assign wsilentDrop_strb_obytes_tmp = (wsilentDrop_strb_bytes << (bempty_count));
assign wsilentDropMasked_strb_obytes_tmp = (wsilentDropMasked_strb_bytes << (bempty_count));

// Conacatenate Data & Strobes
assign nonp_data_dblbytes = {nonp_data_ibytes,nonp_data_obytes};
assign par_bits_dblbytes  = {par_bits_ibytes,par_bits_obytes};
assign strb_dblbytes_tmp = {strb_ibytes_tmp,strb_obytes_tmp};
assign wep_strb_dblbytes_tmp = {wep_strb_ibytes_tmp,wep_strb_obytes_tmp};
assign wsilentDrop_strb_dblbytes_tmp = {wsilentDrop_strb_ibytes_tmp,wsilentDrop_strb_obytes_tmp};
assign wsilentDropMasked_strb_dblbytes_tmp = {wsilentDropMasked_strb_ibytes_tmp,wsilentDropMasked_strb_obytes_tmp};

// Combine & Shift Back Into Output
assign nonp_data_shfbytes = (nonp_data_dblbytes >> ({bempty_count,3'b000}));

assign par_bits_shfbytes_b2t = bin2therm_ts({{RC-BC+2{1'b0}},bempty_count}, 1'b0);

assign par_bits_shfbytes = (par_bits_dblbytes >> (bempty_count)) | par_bits_shfbytes_b2t;
assign strb_shfbytes_tmp = (strb_dblbytes_tmp >> (bempty_count));
assign wep_strb_shfbytes_tmp = (wep_strb_dblbytes_tmp >> (bempty_count));
assign wsilentDrop_strb_shfbytes_tmp = (wsilentDrop_strb_dblbytes_tmp >> (bempty_count));
assign wsilentDropMasked_strb_shfbytes_tmp = (wsilentDropMasked_strb_dblbytes_tmp >> (bempty_count));

// Connect New Next Output
assign data_bytes_glb = assm_parity_data(nonp_data_shfbytes[BW-1:0],par_bits_shfbytes[NC-1:0]);
assign strb_bytes_glb = strb_shfbytes_tmp[NC-1:0];
assign wep_strb_bytes_glb = wep_strb_shfbytes_tmp[NC-1:0];
assign wsilentDrop_strb_bytes_glb = wsilentDrop_strb_shfbytes_tmp[NC-1:0];
assign wsilentDropMasked_strb_bytes_glb = wsilentDropMasked_strb_shfbytes_tmp[NC-1:0];

// Detect Next Valid Out
assign bytes_vld_glb = (update_bytes &&
                        ((byte_count_nxt == byte_max_val) ||
                         (data_last_in == 1'b1)));

// Detect 0 Byte Write
assign no_byte_wr_det = (data_last_in &&
                         (data_strb_in == {NC{1'b0}}));

// 0 Byte Write Valid
assign no_byte_nxt = (data_vld_in && no_byte_wr_det && data_rdy_out) ? 1'b1 :
                     data_accepted ? 1'b0 : no_byte_vld;

// Data Shift Global Saves
assign shift_ovrld = (strb_shift[SS-1:NC] != {NS{1'b0}});

assign update_shift   = ((size_dword_lrg || (data_vld_out && data_last_out && data_accepted)) &&
                         ((data_vld_in || shift_ovrld) && (!shift_vld || (shift_vld && data_rdy_in)))
                        );

assign shift_vld_nxt  = shift_vld_glb ? 1'b1 :
                        data_accepted ? 1'b0 : shift_vld;

assign last_shift_nxt = update_shift ? last_shift_glb :
                        data_accepted ? {2{1'b0}} : last_shift;
assign shift_cnt_nxt  = update_shift ? shift_cnt_glb :
                        data_accepted ? {RC{1'b0}} : shift_cnt;
assign shift_last_nxt = update_shift ? shift_last_glb :
                        data_accepted ? 1'b0 : shift_last;

// Main Output Data & Strobe Register For All Datapaths
assign data_shift_nxt = update_shift ? data_shift_glb :
                        update_bytes ? {{SD*4{BUS_INIT_BYTE}},data_bytes_glb} :
                        data_accepted ? {OD*4{BUS_INIT_BYTE}} : data_shift;

assign strb_shift_nxt = //(no_byte_vld && data_rdy_out) ? {SS{1'b0}} :
// dnolan: solves false shifting of strobes when data transfer followed by zero byte transfer
                        update_shift ? strb_shift_glb :
                        update_bytes ? {{NS{1'b0}},strb_bytes_glb} :
                        data_accepted ? {SS{1'b0}} : strb_shift;

assign wep_strb_shift_nxt = update_shift ? wep_strb_shift_glb :
                            update_bytes ? {{NS{1'b0}},wep_strb_bytes_glb} :
                            data_accepted ? {SS{1'b0}} : wep_strb_shift;

assign wsilentDrop_strb_shift_nxt = update_shift ? wsilentDrop_strb_shift_glb :
                                    update_bytes ? {{NS{1'b0}},wsilentDrop_strb_bytes_glb} :
                                    data_accepted ? {SS{1'b0}} : wsilentDrop_strb_shift;

assign wsilentDropMasked_strb_shift_nxt = update_shift ? wsilentDropMasked_strb_shift_glb :
                                    update_bytes ? {{NS{1'b0}},wsilentDropMasked_strb_bytes_glb} :
                                    data_accepted ? {SS{1'b0}} : wsilentDropMasked_strb_shift;

// Data Bytes Global Saves
assign update_bytes = (!size_dword_lrg && update_data);

assign bytes_vld_nxt  = bytes_vld_glb ? 1'b1 :
                        data_accepted ? 1'b0 : bytes_vld;

assign data_bytes = data_shift[DW-1:0];
assign strb_bytes = strb_shift[NC-1:0];
assign wep_strb_bytes = wep_strb_shift[NC-1:0];
assign wsilentDrop_strb_bytes = wsilentDrop_strb_shift[NC-1:0];
assign wsilentDropMasked_strb_bytes = wsilentDropMasked_strb_shift[NC-1:0];

assign last_bytes_nxt = (data_accepted &&
                         !(bytes_vld_nxt &&
                           data_last_in && update_bytes)) ? 1'b0 :
                        (bytes_vld_nxt &&
                         data_last_in && update_bytes) ? 1'b1 :
                        last_bytes;

// Data Valid Out
assign data_vld_nxt = (no_byte_nxt ||
                       bytes_vld_nxt || shift_vld_nxt) ? 1'b1 :
                      data_accepted ? 1'b0 : data_vld_out;

// Data Last Next
assign data_last_nxt = (no_byte_nxt ||
                        (shift_vld_nxt && shift_last_nxt) ||
                        (bytes_vld_nxt && last_bytes_nxt)) ? 1'b1 :
                       data_accepted ? 1'b0 : data_last_out;


// Data & Strobes Shared Between All
assign data_out = data_shift[DW-1:0];
assign data_strb_out = strb_shift[NC-1:0];
assign data_wep_strb_out = wep_strb_shift[NC-1:0];
assign data_wsilentDrop_strb_out = wsilentDrop_strb_shift[NC-1:0];
assign data_wsilentDrop_strb_out_masked = wsilentDropMasked_strb_shift[NC-1:0];

// Main Sequential Process
always @(posedge clk or negedge rst_n) begin : data_align_seq_PROC
    if (rst_n == 1'b0) begin
        shift_cnt                    <= # TP {RC{1'b0}};
        data_shift                   <= # TP {OD*4{BUS_INIT_BYTE}};
        strb_shift                   <= # TP {SS{1'b0}};
        wep_strb_shift               <= # TP {SS{1'b0}};
        wsilentDrop_strb_shift       <= # TP {SS{1'b0}};
        wsilentDropMasked_strb_shift <= # TP {SS{1'b0}};
        last_shift                   <= # TP {2{1'b0}};
        shift_vld                    <= # TP 1'b0;
        shift_last                   <= # TP 1'b0;
        bytes_act                    <= # TP 1'b0;
        byte_count                   <= # TP {LS{1'b0}};
        last_bytes                   <= # TP 1'b0;
        bytes_vld                    <= # TP 1'b0;
        no_byte_vld                  <= # TP 1'b0;
        data_vld_out                 <= # TP 1'b0;
        data_last_out                <= # TP 1'b0;
    end
    else begin
        shift_cnt                    <= # TP ({RC{init_n}} & shift_cnt_nxt);
        data_shift                   <= # TP init_n ? data_shift_nxt : {OD*4{BUS_INIT_BYTE}};
        strb_shift                   <= # TP ({SS{init_n}} & strb_shift_nxt);
        wep_strb_shift               <= # TP ({SS{init_n}} & wep_strb_shift_nxt);
        wsilentDrop_strb_shift       <= # TP ({SS{init_n}} & wsilentDrop_strb_shift_nxt);
        wsilentDropMasked_strb_shift <= # TP ({SS{init_n}} & wsilentDropMasked_strb_shift_nxt);
        last_shift                   <= # TP ({2{init_n}} & last_shift_nxt);
        shift_vld                    <= # TP (init_n && shift_vld_nxt);
        shift_last                   <= # TP (init_n && shift_last_nxt);
        bytes_act                    <= # TP (init_n && bytes_act_nxt);
        byte_count                   <= # TP ({1'b0,{LS{init_n}}} & byte_count_nxt);
        last_bytes                   <= # TP (init_n && last_bytes_nxt);
        bytes_vld                    <= # TP (init_n && bytes_vld_nxt);
        no_byte_vld                  <= # TP (init_n && no_byte_nxt);
        data_vld_out                 <= # TP (init_n && data_vld_nxt);
        data_last_out                <= # TP (init_n && data_last_nxt);
    end
end


function automatic logic [LS-1:0] get_lsb_pos(input logic [NC-1:0] a);
  logic found = 1'b0;
  get_lsb_pos = '0;
  for (int i=0; i<NC; i++) begin
    if (!found && a[i]) begin
      get_lsb_pos = (LOG2NC)'(i);
      found = 1'b1;
    end
  end
  return get_lsb_pos;
endfunction

function automatic logic [LS-1:0] get_lstb_pos(input logic [NC/2-1:0][1:0] a);
  logic found = 1'b0;
  get_lstb_pos = '0;
  for (int i=0; i<NC/2; i++) begin
    if (!found && |a[i]) begin
      get_lstb_pos =  2*i;
      found = 1'b1;
    end
  end
  return get_lstb_pos;
endfunction

function automatic logic [DC-1:0] get_lsd_pos(input logic [ND-1:0][3:0] a);
  logic found = 1'b0;
  get_lsd_pos = '0;
  for (int i=0; i<ND; i++) begin
    if (!found && |a[i]) begin
      get_lsd_pos = (LOG2ND)'(i);
      found = 1'b1;
    end
  end
  return get_lsd_pos;
endfunction

function automatic logic [DC-1:0] get_msd_pos(input logic [ND-1:0][3:0] a);
  logic found = 1'b0;
  get_msd_pos = '0;
  for (int i=ND-1; i>=0; i--) begin
    if (!found && |a[i]) begin
      get_msd_pos = (LOG2ND)'(i);
      found = 1'b1;
    end
  end
  return get_msd_pos;
endfunction

function automatic logic [1:0] get_lsb_map(input logic [NC-1:0] a);
  logic found = 1'b0;
  get_lsb_map = '0;
  for (int i=0; i<NC; i++) begin
    if (!found && a[i]) begin
      get_lsb_map = (2)'(i);
      found = 1'b1;
    end
  end
  return get_lsb_map;
endfunction

function automatic logic [NC-1:0] get_parity_bits(input logic [NC-1:0][8:0] a);
  foreach (get_parity_bits[i]) begin
    get_parity_bits[i] = a[i][8];
  end
endfunction

function automatic logic [NC-1:0][7:0] get_data_bits(input logic [NC-1:0][8:0] a);
  foreach (get_data_bits[i]) begin
    get_data_bits[i] = a[i][7:0];
  end
endfunction

function automatic logic [NC-1:0][8:0] assm_parity_data(input logic [NC-1:0][7:0] a, input logic [NC-1:0] parity);
  foreach (assm_parity_data[i]) begin
    assm_parity_data[i] = {parity[i],a[i]};
  end
endfunction

function automatic logic [SS-1:0] get_outshft_parity_bits(input logic [SS-1:0][8:0] a);
  foreach (get_outshft_parity_bits[i]) begin
    get_outshft_parity_bits[i] = a[i][8];
  end
endfunction

function automatic logic [SS-1:0][7:0] get_outshft_data_bits(input logic [SS-1:0][8:0] a);
  foreach (get_outshft_data_bits[i]) begin
    get_outshft_data_bits[i] = a[i][7:0];
  end
endfunction

function automatic logic [SS-1:0][8:0] assm_outshft_parity_data(input logic [SS-1:0][7:0] a, input logic [SS-1:0] parity);
  foreach (assm_outshft_parity_data[i]) begin
    assm_outshft_parity_data[i] = {parity[i],a[i]};
  end
endfunction


function automatic logic [NC-1:0] bin2therm_nc(input logic [RC+1:0] inval, input logic sleft);
  if (inval == '0 || PM == '0) begin
    bin2therm_nc = '0;
  end else begin
    logic [-1:NC-1] tmp;
    logic  [LS-1:0] tmp_aux;
    tmp = {{NC-1{1'b0}},1'b1} << inval;
    tmp -= 1'b1;
    if (sleft) begin
      foreach (tmp[i]) begin
        if (i>=0) begin
          tmp_aux = {LS{NC-1-i}};
          bin2therm_nc[tmp_aux] = tmp[i];
        end
      end
    end else begin
      foreach (bin2therm_nc[i]) begin
        bin2therm_nc[i] = tmp[i];
      end
    end
  end
endfunction

function automatic logic [TS-1:0] bin2therm_ts(input logic [RC+1:0] inval, input logic sleft);
  if (inval == '0 || PM == '0) begin
    bin2therm_ts = '0;
  end else begin
    logic [-1:TS-1] tmp;
    logic  [BC-1:0] tmp_aux;
    tmp = {{TS-1{1'b0}},1'b1} << inval;
    tmp -= 1'b1;
    if (sleft) begin
      foreach (tmp[i]) begin
        if (i>=0) begin
          tmp_aux = {BC{TS-1-i}};
          bin2therm_ts[tmp_aux] = tmp[i];
        end
      end
    end else begin
      foreach (bin2therm_ts[i]) begin
        bin2therm_ts[i] = tmp[i];
      end
    end
  end
endfunction

function automatic logic [SS-1:0] bin2therm_ss(input logic [RC+1:0] inval, input logic sleft);
  if (inval == '0 || PM == '0) begin
    bin2therm_ss = '0;
  end else begin
    logic  [-1:SS-1] tmp;
    logic [SS_L-1:0] tmp_aux;
    tmp = {{SS-1{1'b0}},1'b1} << inval;
    tmp -= 1'b1;
    if (sleft) begin
      foreach (tmp[i]) begin
        if (i>=0) begin
          tmp_aux = {SS_L{SS-1-i}};
          bin2therm_ss[tmp_aux] = tmp[i];
        end
      end
    end else begin
      foreach (bin2therm_ss[i]) begin
        bin2therm_ss[i] = tmp[i];
      end
    end
  end
endfunction

function automatic logic [CS-1:0] bin2therm_cs(input logic [RC+1:0] inval, input logic sleft);
  if (inval == '0 || PM == '0) begin
    bin2therm_cs = '0;
  end else begin
    logic  [-1:CS-1] tmp;
    logic [CS_L-1:0] tmp_aux;
    tmp = {{CS-1{1'b0}},1'b1} << inval;
    tmp -= 1'b1;
    if (sleft) begin
      foreach (tmp[i]) begin
        if (i>=0) begin
          tmp_aux = {CS_L{CS-1-i}};
          bin2therm_cs[tmp_aux] = tmp[i];
        end
      end
    end else begin
      foreach (bin2therm_cs[i]) begin
        bin2therm_cs[i] = tmp[i];
      end
    end
  end
endfunction

endmodule
