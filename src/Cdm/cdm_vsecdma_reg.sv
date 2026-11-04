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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_vsecdma_reg.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the DMA VSEC Extended Capability
// --- registers. This module is instantiated once and shared across all functions.
// --- 
// --- 
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_vsecdma_reg
#(
    parameter INST          = 0,                                    // The uniquifying parameter for each port logic instance.
    parameter NF            = `CX_NFUNC,                            // Number of Functions
    parameter NR_REGS       = 6                                     // Number of registers (4 bytes)
    ,parameter RCRB         = 0                                     // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space
)

                       (
    // -------------- Inputs ----------------
    input                             core_clk,                    // Core Clock
    input                             non_sticky_rst_n,            // Non-Sticky Reset 
    input                             sticky_rst_n,                // Sticky Reset (that is, asserted for cold reset only)

    input  [31:0]                     lbc_cdm_data,                // Write Data 
    input                             lbc_cdm_dbi,                 // DBI Access

    input  [4*NF-1:0]                 vsecdma_write_pulse,         // Write Byte Enable
    input  [(NR_REGS*NF)-1:0]         vsecdma_reg_id,              // DMA VSEC Register ID
    input  [NF-1:0]                   vsecdma_reg_sel,             // Function accessing DMA registers
    input                             dbi_ro_wr_en,                // used to make RW registers look like RO for compliance

    input                              upstream_port,               // Device Type is upstream port
    input                              cxl_rcrb_enable,

    // -------------- Outputs --------------
    output reg [31:0]                 vsecdma_reg_data                 // PTM Register Read Data
);

localparam TP = `TP;

// -------------- Internal Signals --------------

wire    [7:0]        vsecdma_reg_03, vsecdma_reg_02, vsecdma_reg_01, vsecdma_reg_00;
wire    [7:0]        vsecdma_reg_07, vsecdma_reg_06, vsecdma_reg_05, vsecdma_reg_04;
wire    [7:0]        vsecdma_reg_11, vsecdma_reg_10, vsecdma_reg_09, vsecdma_reg_08;
wire    [7:0]        vsecdma_reg_15, vsecdma_reg_14, vsecdma_reg_13, vsecdma_reg_12;
wire    [7:0]        vsecdma_reg_19, vsecdma_reg_18, vsecdma_reg_17, vsecdma_reg_16;
wire    [7:0]        vsecdma_reg_23, vsecdma_reg_22, vsecdma_reg_21, vsecdma_reg_20;

wire    [3:0]        int_write_pulse;        // Internal Write Pulse
wire    [5:0]        int_reg_id;             // Internal Register ID


assign int_lbc_cdm_dbi    = lbc_cdm_dbi & dbi_ro_wr_en;

// Extract write_pulse and reg_id for active function
assign int_write_pulse    = get_write_pulse(vsecdma_write_pulse, vsecdma_reg_sel);
assign int_reg_id         = get_reg_id(vsecdma_reg_id, vsecdma_reg_sel);

// -----------------------------------------------------------------------------
// DMA VSEC Extended Capability Header Register
// -----------------------------------------------------------------------------
// vsecdma_reg_id   - 0
// PCIE Offset      - `VSECDMA_PTR
// length           - 4 byte
// Cfig register    - vsecdma_reg_03, vsecdma_reg_02, vsecdma_reg_01, vsecdma_reg_00
// register         - PCI Express Extended Capability ID [15:0] : RO
//                  - Capability Version [19:16] : RO
//                  - Next Capability Offset [31:20] : RO
// -----------------------------------------------------------------------------

    reg    [15:0]                      vsecdma_cap_id ;                     // PCI Express Extended Capability ID [15:0]
    reg    [3:0]                       vsecdma_cap_ver ;                    // Capability Version [19:16]
    reg    [11:0]                      vsecdma_next_ptr ;                   // Next Capability Offset [31:20]
    reg    [NF-1:0]                    vsecdma_next_ptr_updated_nf;     // Asserted when DMA VSEC Capability header has been changed by a DBI write

    reg    [(12*NF)-1:0]               int_reg_next_ptr_nf;

    always @(posedge core_clk or negedge sticky_rst_n) begin : vsecdma_reg0_PROC
        if (!sticky_rst_n) begin
            vsecdma_cap_id     <= #TP `PCIE_VSECDMA_ECAP_ID ;
            vsecdma_cap_ver    <= #TP `PCIE_VSECDMA_ECAP_VER ;
        end
        // Read-Only registers, but writable through DBI
        else begin
                vsecdma_cap_id[7:0]   <= #TP (int_reg_id[0] & int_write_pulse[0] & int_lbc_cdm_dbi ) ? lbc_cdm_data[7:0]   : vsecdma_cap_id[7:0] ;
                vsecdma_cap_id[15:8]  <= #TP (int_reg_id[0] & int_write_pulse[1] & int_lbc_cdm_dbi ) ? lbc_cdm_data[15:8]  : vsecdma_cap_id[15:8] ;
                vsecdma_cap_ver       <= #TP (int_reg_id[0] & int_write_pulse[2] & int_lbc_cdm_dbi ) ? lbc_cdm_data[19:16] : vsecdma_cap_ver ;
        end
    end


    // ----------------------------------------------------------------
    // Next pointer for each function
    // ---------------------------------------------------------------

    always @(posedge core_clk or negedge sticky_rst_n) begin : int_reg_next_ptr_PROC
      if (!sticky_rst_n) begin
        for(int FUNC_NUM = 0; FUNC_NUM < NF; FUNC_NUM++)
          // spyglass disable_block NonConstReset-ML
          // SMD: Invalid reset condition, RHS should be a static value. 
          // SJ: FUNC_NUM is a constant which is used in the definition of VSECDMA_NEXT_PTR.
          int_reg_next_ptr_nf[12*FUNC_NUM + 0 +: 12] <= #TP `VSECDMA_NEXT_PTR ;
          // spyglass enable_block NonConstReset-ML 
      end else begin
        for(int FUNC_NUM = 0; FUNC_NUM < NF; FUNC_NUM++) begin

          if( vsecdma_reg_id[NR_REGS*FUNC_NUM + 0] && int_lbc_cdm_dbi ) begin //vsecdma_reg_id has NR_REGS*NF bit
            int_reg_next_ptr_nf[12*FUNC_NUM + 0 +: 4]    <= #TP vsecdma_write_pulse[4*FUNC_NUM+2] ? lbc_cdm_data[23:20] : int_reg_next_ptr_nf[12*FUNC_NUM + 0 +: 4];
            int_reg_next_ptr_nf[12*FUNC_NUM + 4 +: 8]    <= #TP vsecdma_write_pulse[4*FUNC_NUM+3] ? lbc_cdm_data[31:24] : int_reg_next_ptr_nf[12*FUNC_NUM + 4 +: 8] ;
          end else if( !vsecdma_next_ptr_updated_nf[FUNC_NUM] ) begin
            int_reg_next_ptr_nf[12*FUNC_NUM + 0 +: 12] <= #TP upstream_port ?  cxl_rcrb_enable ? `CXL_VSECDMA_NEXT_PTR :  `VSECDMA_NEXT_PTR :  `DM_RP_VSECDMA_NEXT_PTR;
          end

        end
      end
    end    
    
    always @(posedge core_clk or negedge sticky_rst_n) begin : vsecdma_next_ptr_updated_PROC
      if (!sticky_rst_n) begin
        vsecdma_next_ptr_updated_nf  <= #TP '0;
      end
      else begin
        foreach(vsecdma_next_ptr_updated_nf [FUNC_NUM]) begin
          if( vsecdma_reg_id[NR_REGS*FUNC_NUM+0] && int_lbc_cdm_dbi && |vsecdma_write_pulse[4*FUNC_NUM + 2 +: 2] ) begin
            vsecdma_next_ptr_updated_nf [FUNC_NUM] <= #TP 1'b1;
          end
        end
      end
    end 

    always @(*) begin: for_int_reg_next_ptr
      integer jj;
      vsecdma_next_ptr = {11'b0,int_reg_next_ptr_nf[0]};
      for ( jj=0 ; jj<NF ; jj=jj+1 ) begin
        if (vsecdma_reg_sel[jj] ) begin
          vsecdma_next_ptr = int_reg_next_ptr_nf[12*jj +: 12];
        end
      end
    end

    assign {vsecdma_reg_03,vsecdma_reg_02,vsecdma_reg_01,vsecdma_reg_00} = {vsecdma_next_ptr
                                                                           ,vsecdma_cap_ver
                                                                           ,vsecdma_cap_id
                                                                           };

// -----------------------------------------------------------------------------
// DMA VSEC Capabilities Register
// -----------------------------------------------------------------------------
// vsecdma_reg_id   - 1
// PCIE Offset      - `VSECDMA_PTR + 04h
// length           - 4 byte
// Cfig register    - vsecdma_reg_07, vsecdma_reg_06, vsecdma_reg_05, vsecdma_reg_04
// register         - VSEC Vendor ID [15:0] : RO
//                  - VSEC Revision [19:16] : RO
//                  - VSEC length [31:20]   : RO
// -----------------------------------------------------------------------------

    wire [11:0] vsecdma_vsec_length;
    wire [3:0]  vsecdma_vsec_rev;
    wire [15:0] vsecdma_vsec_id;

    assign vsecdma_vsec_length  = `DEFAULT_VSECDMA_LENGTH;
    assign vsecdma_vsec_rev     = `DEFAULT_VSECDMA_REV;
    assign vsecdma_vsec_id      = `DEFAULT_VSECDMA_ID;

    assign {vsecdma_reg_07,vsecdma_reg_06,vsecdma_reg_05,vsecdma_reg_04} = {vsecdma_vsec_length
                                                                           ,vsecdma_vsec_rev
                                                                           ,vsecdma_vsec_id
                                                                           };

// -----------------------------------------------------------------------------
// DMA VSEC Capabilities Register
// -----------------------------------------------------------------------------
// vsecdma_reg_id   - 2
// PCIE Offset      - `VSECDMA_PTR + 08h
// length           - 4 byte
// Cfig register    - vsecdma_reg_11, vsecdma_reg_10, vsecdma_reg_09, vsecdma_reg_08
// register         - Map Format                         [02:00] : RO
// register         - reserved                           [07:03] : RO
// register         - BARN                               [10:08] : RO
// register         - PFN                                [15:11] : RO
// register         - Channel Address Separation         [18:16] : RO
// register         - AXI_POPULATED                      [19:19] : RO
// register         - Master Bus Width                   [22:20] : RO
// register         - Master Burst Length                [25:23] : RO
// register         - Master Page Boundary Pointer Width [29:26] : RO
// register         - rsvd1                              [31:30] : RO
// -----------------------------------------------------------------------------

wire [02:00] vsecdma_map_format                         ;
wire [07:03] vsecdma_rsvd0                              ;
wire [10:08] vsecdma_barn                               ;
wire [15:11] vsecdma_pfn                                ;
wire [18:16] vsecdma_channel_separation                 ;
wire [19:19] vsecdma_axi                                ;
wire [22:20] vsecdma_master_bus_width                   ;
wire [25:23] vsecdma_master_burst_length                ;
wire [29:26] vsecdma_master_page_boundary_pointer_width ;
wire [31:30] vsecdma_rsvd1                              ;

assign vsecdma_map_format                         = `CC_VSECDMA_MAP_VERSION;
assign vsecdma_rsvd0                              = 0;
assign vsecdma_barn                               = `UNROLL_BAR_NUM;
assign vsecdma_pfn                                = `UNROLL_FUNC_NUM;
assign vsecdma_channel_separation                 = `CX_DMAREG_CHADDR_SPACE;
assign vsecdma_axi                                = `AXI_POPULATED_VALUE;
assign vsecdma_master_bus_width                   = `MASTER_BUS_DATA_WIDTH_REG;
assign vsecdma_master_burst_length                = `CC_MSTR_BURST_LEN_REG;
assign vsecdma_master_page_boundary_pointer_width = `CC_MSTR_PAGE_BOUNDARY_PW;
assign vsecdma_rsvd1                              = 0;

assign {vsecdma_reg_11, vsecdma_reg_10, vsecdma_reg_09, vsecdma_reg_08} = {vsecdma_rsvd1                              
                                                                          ,vsecdma_master_page_boundary_pointer_width 
                                                                          ,vsecdma_master_burst_length                
                                                                          ,vsecdma_master_bus_width                   
                                                                          ,vsecdma_axi                                
                                                                          ,vsecdma_channel_separation                 
                                                                          ,vsecdma_pfn                                
                                                                          ,vsecdma_barn                               
                                                                          ,vsecdma_rsvd0                              
                                                                          ,vsecdma_map_format                         
                                                                          };



// -----------------------------------------------------------------------------
// DMA VSEC Capabilities Register
// -----------------------------------------------------------------------------
// vsecdma_reg_id   - 3
// PCIE Offset      - `VSECDMA_PTR + 0Ch
// length           - 4 byte
// Cfig register    - vsecdma_reg_15, vsecdma_reg_14, vsecdma_reg_13, vsecdma_reg_12
// register         - NUM_DMA_WR_CHAN [10:00] : RO
//                  - RSVD2           [15:11] : RO
//                  - NUM_DMA_RD_CHAN [26:16] : RO
//                  - RSVD3           [31:27] : RO
// -----------------------------------------------------------------------------

wire [10:00] vsecdma_num_dma_wr_chan ;
wire [15:11] vsecdma_rsvd2 ;
wire [26:16] vsecdma_num_dma_rd_chan ;
wire [31:27] vsecdma_rsvd3 ;

assign vsecdma_num_dma_wr_chan = `CC_NUM_DMA_WR_CHAN;
assign vsecdma_rsvd2           = '0;
assign vsecdma_num_dma_rd_chan = `CC_NUM_DMA_RD_CHAN;
assign vsecdma_rsvd3           = '0;

assign {vsecdma_reg_15,vsecdma_reg_14,vsecdma_reg_13,vsecdma_reg_12} = {vsecdma_rsvd3
                                                                       ,vsecdma_num_dma_rd_chan
                                                                       ,vsecdma_rsvd2
                                                                       ,vsecdma_num_dma_wr_chan
                                                                       };


// -----------------------------------------------------------------------------
// DMA VSEC Capabilities Register
// -----------------------------------------------------------------------------
// vsecdma_reg_id   - 4
// PCIE Offset      - `VSECDMA_PTR + 10h
// length           - 4 byte
// Cfig register    - vsecdma_reg_19, vsecdma_reg_18, vsecdma_reg_17, vsecdma_reg_16
// register         - UNROLL_ADDR_OFFSET_LOW [31:0] : RO

// Read Only from the Wire.
// -----------------------------------------------------------------------------


wire [31:0] vsecdma_unroll_addr_offset_low;

assign vsecdma_unroll_addr_offset_low[31:0] = `UNROLL_DMA_OFFSET_BAR_LOW;

assign {vsecdma_reg_19, vsecdma_reg_18, vsecdma_reg_17, vsecdma_reg_16} = {vsecdma_unroll_addr_offset_low
                                                                          };



// -----------------------------------------------------------------------------
// DMA VSEC Capabilities Register
// -----------------------------------------------------------------------------
// vsecdma_reg_id   - 5
// PCIE Offset      - `VSECDMA_PTR + 14h
// length           - 4 byte
// Cfig register    - vsecdma_reg_23, vsecdma_reg_22, vsecdma_reg_21, vsecdma_reg_20
// register         - UNROLL_ADDR_OFFSET_HIGH [31:0] : RO
// Read Only from the Wire.
// -----------------------------------------------------------------------------

wire [31:0] vsecdma_unroll_addr_offset_high;

assign vsecdma_unroll_addr_offset_high[31:0] = `UNROLL_DMA_OFFSET_BAR_HIGH;

assign {vsecdma_reg_23, vsecdma_reg_22, vsecdma_reg_21, vsecdma_reg_20} = {vsecdma_unroll_addr_offset_high
                                                                          };
// =============================================================================
// Register Read Operation
// =============================================================================

always @(*) begin : read_data_PROC
     case (int_reg_id)
        6'b000001 : vsecdma_reg_data = {vsecdma_reg_03, vsecdma_reg_02, vsecdma_reg_01, vsecdma_reg_00};
        6'b000010 : vsecdma_reg_data = {vsecdma_reg_07, vsecdma_reg_06, vsecdma_reg_05, vsecdma_reg_04};
        6'b000100 : vsecdma_reg_data = {vsecdma_reg_11, vsecdma_reg_10, vsecdma_reg_09, vsecdma_reg_08};
        6'b001000 : vsecdma_reg_data = {vsecdma_reg_15, vsecdma_reg_14, vsecdma_reg_13, vsecdma_reg_12};
        6'b010000 : vsecdma_reg_data = {vsecdma_reg_19, vsecdma_reg_18, vsecdma_reg_17, vsecdma_reg_16};
        6'b100000 : vsecdma_reg_data = {vsecdma_reg_23, vsecdma_reg_22, vsecdma_reg_21, vsecdma_reg_20};
        default        :    vsecdma_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end

// Function to extract write_pulse from active function
function automatic [3:0] get_write_pulse;
    input   [(4*NF)-1:0] data;
    input   [NF-1:0]     func;
    reg     [3:0]        result;
    integer bit_loc;
    integer i;
begin
    result = 4'h0;

    for (bit_loc=0; bit_loc<NF; bit_loc=bit_loc+1)
        if (func[bit_loc])
            for (i=0; i<4; i=i+1)
                result[i] = data[bit_loc*4+i];

    get_write_pulse = result;
end
endfunction

// Function to extract dma_reg_id from active function
function automatic [NR_REGS-1:0] get_reg_id;
    input   [(NR_REGS*NF)-1:0] data;
    input   [NF-1:0]         func;
    reg     [NR_REGS-1:0]    result;
    integer bit_loc;
    integer i;
begin
    result = 0;

    for (bit_loc=0; bit_loc<NF; bit_loc=bit_loc+1)
        if (func[bit_loc])
            for (i=0; i<NR_REGS; i=i+1)
                result[i] = data[bit_loc*NR_REGS+i];

    get_reg_id = result;
end
endfunction


endmodule //cdm_vsecdma_reg 
