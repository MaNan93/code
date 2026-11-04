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
// ---    $DateTime: 2023/06/26 08:32:07 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_tph_reg.sv#7 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the TPH capability registers.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_tph_reg (
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    cdm_clk_g,
    lbc_cdm_data,
    lbc_cdm_dbi,
    lbc_cdm_dbi2,
    tph_write_pulse,
    tph_read_pulse,
    tph_reg_id,
    dbi_ro_wr_en,
    device_type,
    cxl_rcrb_enable,

// -- outputs --
    cfg_tph_req_en,
    cfg_tph_st_mode,

    tph_reg_data
);

parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM      = 0;                    // Physical Function Number
parameter VF_IMPL       = 0;                    // 0: PF impl. 1: VF impl.
parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)
parameter RCRB          = 0;                            // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space

// Next Capability Pointer. Capabilities such as LTR should not be visible to a DM product in Root Port mode; hence,
// when rc_device is true then the next pointer is in a smaller linked list:
localparam TPH_IVEC             = `TPH_IVEC;
localparam TPH_DS               = `TPH_DS;
localparam TPH_EXT_TPH          = `CX_EXT_TPH_ENABLE_VALUE;
localparam TPH_ST_TABLE_LOC     = `TPH_ST_TABLE_LOC;
localparam TPH_ST_TABLE_SIZE_MINUS_1    = VF_IMPL ? `VF_TPH_ST_TABLE_SIZE-1  : `TPH_ST_TABLE_SIZE-1;
localparam TPH_ST_TABLE_DEPTH           = VF_IMPL ? `VF_TPH_ST_TABLE_DEPTH   : `TPH_ST_TABLE_DEPTH;
localparam TPH_ST_TABLE_DEPTH_MINUS_1   = VF_IMPL ? `VF_TPH_ST_TABLE_DEPTH-1   : `TPH_ST_TABLE_DEPTH-1;
localparam LOCAL_NEXT_PTR               = VF_IMPL ? `VF_TPH_NEXT_PTR : ((FUNC_NUM==0) ? `TPH_NEXT_PTR_0 : `TPH_NEXT_PTR_N);

// -------------- Inputs ---------------
input                               core_clk;
input                               non_sticky_rst_n;
input                               sticky_rst_n;
input                               cdm_clk_g;                    // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input    [31:0]                     lbc_cdm_data;                   // Data for write
input                               lbc_cdm_dbi;
input                               lbc_cdm_dbi2;
input    [3:0]                      tph_write_pulse;
input                               tph_read_pulse;
input    [2+TPH_ST_TABLE_DEPTH:0]   tph_reg_id;
input                               dbi_ro_wr_en;
input    [3:0]                      device_type;                 // used to indicate if device is RP
input                               cxl_rcrb_enable;             // Indicates that the CXL 1.1 Link is up for USP supporting RCRB

//
// -------------- Outputs --------------
output   [1:0]  cfg_tph_req_en;                 // TPH Requester Enable
output   [2:0]  cfg_tph_st_mode;
output  [31:0]  tph_reg_data;                   // Read Data back from the core

reg  [31:0]  tph_reg_data;                   // Read data back from core

wire    [7:0]   cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0;
wire    [7:0]   cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4;
wire    [7:0]   cfg_reg_11, cfg_reg_10, cfg_reg_9, cfg_reg_8;

wire            dbi_ro_wr_en;
wire            int_lbc_cdm_dbi = lbc_cdm_dbi & ~lbc_cdm_dbi2 & dbi_ro_wr_en;
wire            int_lbc_cdm_dbi2 = lbc_cdm_dbi2 & dbi_ro_wr_en;

wire            rc_device;
wire            pcie_sw_down;

// Determine when Root Port is implemented - relevant for DM product in RP
// mode.
assign rc_device = (device_type == `PCIE_RC) ? 1'b1 : 1'b0;
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);


// =============================================================================
// TPH Capability Structure
// =============================================================================
// TPH Requester Extended CAP Header
// tph_reg_id       - 0
// PCIE Offset      - `TPH_PTR
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0
// -----------------------------------------------------------------------------

/* If SRIOV is configured, then use VF linked list to calculate next
   pointer; else if an RC device, use RP linked list; else use linked
   list for all other devices */
reg         tph_next_ptr_wr_updated;    // Asserted when TPH Capability header has been changed by a DBI write
reg  [11:0] cfg_tph_next_ptr;
reg  [15:0] cfg_tph_id;
reg   [3:0] cfg_tph_ver;

assign {cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0} = {cfg_tph_next_ptr,cfg_tph_ver,cfg_tph_id};

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
    cfg_tph_id[15:0]    <= #TP `PCIE_TPH_ECAP_ID;      // Capability ID
    cfg_tph_ver[3:0]    <= #TP `PCIE_TPH_ECAP_VER;     // Capability version
  end else begin
    // Read-Only register, but writable through DBI
    cfg_tph_id[7:0]        <= #TP (tph_reg_id[0] & tph_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_tph_id[7:0];
    cfg_tph_id[15:8]       <= #TP (tph_reg_id[0] & tph_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_tph_id[15:8];
    cfg_tph_ver[3:0]       <= #TP (tph_reg_id[0] & tph_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_tph_ver[3:0];
  end
end

// LMD: Do not assign signal/variable to asynchronous set/reset
// LJ: reset value is a wire assigned to a parameter (= constant when compiled), but not worked out by Leda in this instance.
// leda FM_1_4 off
always @(posedge core_clk or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
    cfg_tph_next_ptr    <= #TP LOCAL_NEXT_PTR;
  end else if (tph_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
    // Read-Only register, but writable through DBI
    cfg_tph_next_ptr[3:0]  <= #TP tph_write_pulse[2] ? lbc_cdm_data[23:20]  : cfg_tph_next_ptr[3:0];
    cfg_tph_next_ptr[11:4] <= #TP tph_write_pulse[3] ? lbc_cdm_data[31:24]  : cfg_tph_next_ptr[11:4];
  end else if ((rc_device || pcie_sw_down) && !tph_next_ptr_wr_updated ) begin
    cfg_tph_next_ptr    <= #TP `DM_RP_TPH_NEXT_PTR ;      // If RP or downstream port of SW, then use smaller linked list.
  end else if (!tph_next_ptr_wr_updated ) begin
    cfg_tph_next_ptr    <= #TP (cxl_rcrb_enable && (VF_IMPL == 0)) ? `CXL_TPH_NEXT_PTR : LOCAL_NEXT_PTR ;             // If RP or upstream port of SW, then use full linked list. Device type could change if crosslink enable is true.
  end
end
// leda FM_1_4 on

// If next pointer is modified by a DBI write, then only the Application
// (via another DBI write) is allowed any further update.
always @( posedge core_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        tph_next_ptr_wr_updated <= #TP 1'b0;
    end else if (tph_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |tph_write_pulse[3:2]) begin
        tph_next_ptr_wr_updated <= #TP 1'b1;
    end
end

// -----------------------------------------------------------------------------
// TPH Requester Capability Register
// tph_reg_id       - 1
// PCIE Offset      - `TPH_PTR + 04h
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4
// -----------------------------------------------------------------------------
reg         cfg_tph_ivec;
reg         cfg_tph_ds;
reg         cfg_tph_ext_tph;
reg   [1:0] cfg_tph_st_tab_loc;
reg  [10:0] cfg_tph_st_tab_size;
reg         cfg_tph_ivec2;
reg         cfg_tph_ds2;
reg   [1:0] cfg_tph_st_tab_loc2;
reg  [10:0] cfg_tph_st_tab_size2;
wire        cfg_tph_no_st;
reg         cfg_tph_ext_tph2;
wire [31:0] cfg_tph_req_cap_reg2;

assign cfg_tph_no_st = 1'b1;
assign {cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4} = VF_IMPL              ? 32'h0000_0000 :
                                                                            {5'd0,cfg_tph_st_tab_size,5'd0,cfg_tph_st_tab_loc,cfg_tph_ext_tph,5'd0,cfg_tph_ds,cfg_tph_ivec,cfg_tph_no_st};
                                                       
assign cfg_tph_req_cap_reg2 = {5'd0,cfg_tph_st_tab_size2,5'd0,cfg_tph_st_tab_loc2,cfg_tph_ext_tph2,5'd0,cfg_tph_ds2,cfg_tph_ivec2,cfg_tph_no_st};

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
      cfg_tph_ivec         <= #TP TPH_IVEC;
      cfg_tph_ds           <= #TP TPH_DS;
      cfg_tph_ext_tph      <= #TP TPH_EXT_TPH;
      cfg_tph_st_tab_loc   <= #TP TPH_ST_TABLE_LOC;
      cfg_tph_st_tab_size  <= #TP TPH_ST_TABLE_SIZE_MINUS_1;
      cfg_tph_ivec2        <= #TP TPH_IVEC;
      cfg_tph_ds2          <= #TP TPH_DS;
      cfg_tph_ext_tph2     <= #TP TPH_EXT_TPH;
      cfg_tph_st_tab_loc2  <= #TP TPH_ST_TABLE_LOC;
      cfg_tph_st_tab_size2 <= #TP `VF_TPH_ST_TABLE_SIZE - 1;
    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      cfg_tph_ivec               <= #TP (int_lbc_cdm_dbi  & tph_write_pulse[0] & tph_reg_id[1]) ? lbc_cdm_data[1]                                                     : cfg_tph_ivec;
      cfg_tph_ds                 <= #TP (int_lbc_cdm_dbi  & tph_write_pulse[0] & tph_reg_id[1]) ? lbc_cdm_data[2]                                                     : cfg_tph_ds;
      cfg_tph_ext_tph            <= #TP (int_lbc_cdm_dbi  & tph_write_pulse[1] & tph_reg_id[1]) ? lbc_cdm_data[8]                                                     : cfg_tph_ext_tph;
      cfg_tph_st_tab_loc[0]      <= #TP (int_lbc_cdm_dbi  & tph_write_pulse[1] & tph_reg_id[1]) ? lbc_cdm_data[9]                                                     : cfg_tph_st_tab_loc[0];
      cfg_tph_st_tab_loc[1]      <= #TP (int_lbc_cdm_dbi  & tph_write_pulse[1] & tph_reg_id[1]) ? lbc_cdm_data[10] & `MSIX_CAP_ENABLE                                 : cfg_tph_st_tab_loc[1];
      cfg_tph_st_tab_size[7:0]   <= #TP (int_lbc_cdm_dbi  & tph_write_pulse[2] & tph_reg_id[1]) ? lbc_cdm_data[23:16]                                                 : cfg_tph_st_tab_size[7:0];
      cfg_tph_st_tab_size[10:8]  <= #TP (int_lbc_cdm_dbi  & tph_write_pulse[3] & tph_reg_id[1]) ? lbc_cdm_data[26:24]                                                 : cfg_tph_st_tab_size[10:8];
      cfg_tph_ivec2              <= #TP (int_lbc_cdm_dbi2 & tph_write_pulse[0] & tph_reg_id[1]) ? lbc_cdm_data[1]                                                     : cfg_tph_ivec2;
      cfg_tph_ds2                <= #TP (int_lbc_cdm_dbi2 & tph_write_pulse[0] & tph_reg_id[1]) ? lbc_cdm_data[2]                                                     : cfg_tph_ds2;
      cfg_tph_ext_tph2           <= #TP (int_lbc_cdm_dbi2 & tph_write_pulse[1] & tph_reg_id[1]) ? lbc_cdm_data[8]                                                     : cfg_tph_ext_tph2;
      cfg_tph_st_tab_loc2[0]     <= #TP (int_lbc_cdm_dbi2 & tph_write_pulse[1] & tph_reg_id[1]) ? lbc_cdm_data[9]                                                     : cfg_tph_st_tab_loc2[0];
      cfg_tph_st_tab_loc2[1]     <= #TP (int_lbc_cdm_dbi2 & tph_write_pulse[1] & tph_reg_id[1]) ? lbc_cdm_data[10] & (`VF_MSIX_CAP_ENABLE | `EXT_VF_MSIX_CAP_ENABLE)  : cfg_tph_st_tab_loc2[1];
      cfg_tph_st_tab_size2[7:0]  <= #TP (int_lbc_cdm_dbi2 & tph_write_pulse[2] & tph_reg_id[1]) ? lbc_cdm_data[23:16]                                                 : cfg_tph_st_tab_size2[7:0];
      cfg_tph_st_tab_size2[10:8] <= #TP (int_lbc_cdm_dbi2 & tph_write_pulse[3] & tph_reg_id[1]) ? lbc_cdm_data[26:24]                                                 : cfg_tph_st_tab_size2[10:8];
    end
end

// -----------------------------------------------------------------------------
// TPH Requester Control Register
// tph_reg_id       - 2
// PCIE Offset      -`TPH_PTR + 08h
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_11,  cfg_reg_10,  cfg_reg_9,  cfg_reg_8
// -----------------------------------------------------------------------------
reg     [2:0]  cfg_tph_st_mode;
reg     [1:0]  cfg_tph_req_en;

assign {cfg_reg_11,cfg_reg_10,cfg_reg_9,cfg_reg_8} = {22'd0,cfg_tph_req_en,5'd0,cfg_tph_st_mode};

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
  if(!non_sticky_rst_n) begin
    cfg_tph_st_mode  <= #TP 3'b000;
    cfg_tph_req_en   <= #TP 2'b00;
  end else begin  
    // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      // if TPH_IVEC_n and TPH_DS_n both false then "ST Mode Select" bit should be RO (all zeros)
    cfg_tph_st_mode  <= #TP (TPH_IVEC==0 & TPH_DS==0) ? 3'b000 : (tph_write_pulse[0] & tph_reg_id[2]) ? lbc_cdm_data[2:0]  : cfg_tph_st_mode;
    cfg_tph_req_en   <= #TP (tph_write_pulse[1] & tph_reg_id[2]) ? lbc_cdm_data[9:8]  : cfg_tph_req_en;
  end
end

// -----------------------------------------------------------------------------
// TPH ST Table
// tph_reg_id       - 3
// PCIE Offset      - TPH_PTR + 0Ch
// Length           - 1 bytes * `TPH_ST_TABLE_SIZE
// Default value    -
// Cfig register    - cfg_reg_15, cfg_reg_14, cfg_reg_13, cfg_reg_12
// -----------------------------------------------------------------------------

genvar st_tab_size;
generate
//if (VF_IMPL || (TPH_ST_TABLE_LOC == 1))
if (TPH_ST_TABLE_DEPTH > 0)
begin : gen_ST_TABLE_REGISTERS

  reg  [7:0]   st_reg_i[0:(TPH_ST_TABLE_DEPTH_MINUS_1*2)+1];    // array size must always be even for ST_TABLE_REG_IN_proc
  reg  [7:0]   st_reg[0:(TPH_ST_TABLE_DEPTH_MINUS_1*2)+1];
  reg  [7:0]   st_reg_st_upper_i[0:(TPH_ST_TABLE_DEPTH_MINUS_1*2)+1];    // array size must always be even for ST_TABLE_REG_IN_proc
  reg  [7:0]   st_reg_st_upper[0:(TPH_ST_TABLE_DEPTH_MINUS_1*2)+1];
  reg  [31:0]  cfg_reg_st_tab[0:TPH_ST_TABLE_DEPTH_MINUS_1];

  // generate the input values for each ST register
  // Note: ST_Upper is only RW if Extended TPH Requester Supported bit (= cfg_reg_5[0]) is set. Otherwise, it's RsvdP.
  always@(*)
  begin : ST_TABLE_REG_IN_proc
  integer table_depth;
  integer i;
    for ( table_depth=0; table_depth < TPH_ST_TABLE_DEPTH; table_depth=table_depth+1) begin
      for ( i=0; i<=1; i=i+1) begin : gen_ST_TABLE_REG
          // LMD: Range index out of bound
          // LJ: The index of the signal lbc_cdm_data never passes the boundary because i only take two values 0 and 1
          // leda E267 off
          st_reg_i[2*table_depth+i] = (tph_write_pulse[2*i] & tph_reg_id[3+table_depth]) ? lbc_cdm_data[(16*i) +: 8] : st_reg[2*table_depth+i];
          st_reg_st_upper_i[2*table_depth+i] = (tph_write_pulse[(2*i)+1] & tph_reg_id[3+table_depth] & cfg_reg_5[0]) ? lbc_cdm_data[(16*i)+8 +: 8] : st_reg_st_upper[2*table_depth+i];
          // leda E267 on
      end
    end
  end

  // Generate the ST registers and assign them the input values
  for(st_tab_size = 0; st_tab_size <= (TPH_ST_TABLE_DEPTH_MINUS_1*2)+1; st_tab_size = st_tab_size + 1) begin : ST_REG_ASSIGN_proc
    always@(posedge core_clk or negedge non_sticky_rst_n)
    begin
      if(!non_sticky_rst_n) begin
        st_reg[st_tab_size]  <= #TP 0;
        st_reg_st_upper[st_tab_size]  <= #TP 0;
      end else begin
        st_reg[st_tab_size]  <= #TP st_reg_i[st_tab_size];
        st_reg_st_upper[st_tab_size]  <= #TP st_reg_st_upper_i[st_tab_size];
      end
    end
  end

  // Map the ST registers into the TPH capability structure
  always@(*)
  begin : ST_TAB_CAP_MAP_proc
  integer table_depth;
    for ( table_depth=0; table_depth < TPH_ST_TABLE_DEPTH; table_depth=table_depth+1) begin
      cfg_reg_st_tab[table_depth] = {st_reg_st_upper[(table_depth*2)+1],st_reg[(table_depth*2)+1],st_reg_st_upper[table_depth*2],st_reg[table_depth*2]};
    end
  end

  // =============================================================================
  // CFG Register Read Operation
  // =============================================================================


  integer st_tab_sel;

  reg [31:0] tph_fixed_reg_data;
  reg [31:0] tph_st_reg_data;

  // capture the register information from the Fixed fields of teh TPH Cap
  // structure
  always @(*)
  begin
    unique case (1'b1)
      tph_reg_id[0] : tph_fixed_reg_data = {cfg_reg_3,  cfg_reg_2,  cfg_reg_1,  cfg_reg_0};
      tph_reg_id[1] : tph_fixed_reg_data = {cfg_reg_7,  cfg_reg_6,  cfg_reg_5,  cfg_reg_4};
      tph_reg_id[2] : tph_fixed_reg_data = {cfg_reg_11, cfg_reg_10, cfg_reg_9,  cfg_reg_8};
      default:        tph_fixed_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
  end

  // Capture the values from the ST table portion of the TPH Cap structure
  always@(*)
  begin
    tph_st_reg_data = `PCIE_UNUSED_RESPONSE;

    for(st_tab_sel=0; st_tab_sel < TPH_ST_TABLE_DEPTH; st_tab_sel=st_tab_sel+1) begin : gen_RD_ST_TABLE
      if(tph_reg_id[3+st_tab_sel] == 1'b1)
        tph_st_reg_data = cfg_reg_st_tab[st_tab_sel];
    end
  end

  // Mux out the fixed or ST data on the read data bus depending
  // upon when the reg_id falls
  always@(*)
  begin
    if(|tph_reg_id[2:0])
      tph_reg_data = tph_fixed_reg_data;
    else if (|tph_reg_id[2+TPH_ST_TABLE_DEPTH:3])
      tph_reg_data = tph_st_reg_data;
    else
      tph_reg_data = `PCIE_UNUSED_RESPONSE;
  end
end
else begin : gen_NO_ST_TABLE_READ_MUX
  always @(*)
  begin
    unique case (1'b1)
      tph_reg_id[0] : tph_reg_data = {cfg_reg_3,  cfg_reg_2,  cfg_reg_1,  cfg_reg_0};
      tph_reg_id[1] : tph_reg_data = {cfg_reg_7,  cfg_reg_6,  cfg_reg_5,  cfg_reg_4};
      tph_reg_id[2] : tph_reg_data = {cfg_reg_11, cfg_reg_10, cfg_reg_9,  cfg_reg_8};
      default:        tph_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
  end
end
endgenerate



endmodule // cdm_tph_reg
