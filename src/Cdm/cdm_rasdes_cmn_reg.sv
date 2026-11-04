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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_rasdes_cmn_reg.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the common block for RAS D.E.S specific register
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_rasdes_cmn_reg
#(
    parameter INST          = 0,                                   // The uniquifying parameter for each port logic instance.
    parameter TP            = `TP,                                 // Clock to Q delay (simulator insurance)
    parameter NF            = `CX_NFUNC                            // Number of Functions
    ,parameter RCRB         = 0                                     // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space
)

                          (
// -------------- Inputs ---------------
    input                              aux_clk,                            // Clock
    input                              sticky_rst_n,                       // Reset sticky registers only
 // --- Register access signals
    input  [31:0]                      lbc_cdm_data,                       // Write Data 
    input                              lbc_cdm_dbi,                        // DBI Access
    input  [4*NF-1:0]                  ecfg_write_pulse,                   // Write Byte Enables
    input  [NF-1:0]                    rasdes_reg_sel,                     // Register select
    input  [(64*NF)-1:0]               rasdes_reg_id,                      // Register access ID
    input                              dbi_ro_wr_en,                       // used to make RW registers look like RO for compliance
 // --- Internal register access
    input  [1:0]                       cdm_ec_ack,                         // Acknowledge from Event counter module
    input  [31:0]                      cdm_ec_rdata,                       // Read Data 
    input  [1:0]                       cdm_ei_ack,                         // Acknowledge from Error Injection debug module
    input  [31:0]                      cdm_ei_rdata,                       // Read Data 
    input  [1:0]                       cdm_sd_ack,                         // Acknowledge from Silicon debug module
    input  [31:0]                      cdm_sd_rdata,                       // Read Data 
    input  [1:0]                       cdm_tba_ack,                        // Acknowledge from Timebase analysis module
    input  [31:0]                      cdm_tba_rdata,                      // Read Data 
    input  [1:0]                       cdm_tf_ack,                         // Acknowledge from Trace FIFO module
    input  [31:0]                      cdm_tf_rdata,                       // Read Data 
 // --- Others
    input                              upstream_port,                      // Device Type is upstream port
    input                              cxl_rcrb_enable,
// -------------- Outputs ---------------
 // --- Register access signals
    output reg                         rasdes_reg_ack,                     // Acknowledge of regsiter access
    output reg [31:0]                  rasdes_reg_data,                    // Read Data
 // --- Internal register access
    output [31:0]                      cdm_reg_wdata,                      // Write Data 
    output [3:0]                       cdm_reg_write_pulse,                // Write Byte Enables
    output [63:0]                      cdm_reg_id                          // Register access ID
) ;

//---------------------------------------------------
//  EC/SD/TB/TF register block interface
//---------------------------------------------------
    reg                                cdm_reg_id_mask ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_reg_id_mask <= #TP 1'b0 ;
        end
        else begin
            if ( !(|rasdes_reg_id) ) begin
                cdm_reg_id_mask <= #TP 1'b0 ;
            end
            else if ( cdm_ec_ack[1] || cdm_ei_ack[1] || cdm_sd_ack[1] || cdm_tba_ack[1] || cdm_tf_ack[1] ) begin
                cdm_reg_id_mask <= #TP 1'b1 ;
            end
        end
    end

    assign cdm_reg_wdata       = lbc_cdm_data ;
    assign cdm_reg_id          = !cdm_reg_id_mask ? get_reg_id (rasdes_reg_id, rasdes_reg_sel) : 64'd0 ;
    assign cdm_reg_write_pulse = get_write_pulse (ecfg_write_pulse, rasdes_reg_sel) ;

    // Function to extract write_pulse from active function
    function automatic [3:0] get_write_pulse;
        input   [(4*NF)-1:0] data;
        input   [NF-1:0]     func;
        reg     [3:0]        result;
        integer bit_loc;
        integer i;
        begin
            result = 4'd0;

            for (bit_loc=0; bit_loc<NF; bit_loc=bit_loc+1)
                if (func[bit_loc])
                    for (i=0; i<4; i=i+1)
                        result[i] = data[bit_loc*4+i];

            get_write_pulse = result;
        end
    endfunction

    // Function to extract ras_reg_id from active function
    function automatic [64-1:0] get_reg_id;
        input   [64*NF-1:0] data;
        input   [NF-1:0]    func;
        reg     [64-1:0]    result;
        integer bit_loc;
        integer i;
        begin
             result = 64'd0;

             for (bit_loc=0; bit_loc<NF; bit_loc=bit_loc+1)
                 if (func[bit_loc])
                     for (i=0; i<64; i=i+1)
                         result[i] = data[bit_loc*64+i];

             get_reg_id = result;
        end
    endfunction

//---------------------------------------------------
//  DBI Register interface
//---------------------------------------------------
    reg                                rasdes_acc_1d ;
    reg                                resp_check ;
    reg                                rasdes_reg_ack_done ;
    reg    [31:0]                      int_rdata ;
    wire                               rasdes_acc ;
    wire                               int_ack ;
    wire                               int_lbc_cdm_dbi ;
    wire                               resp_error ;
    wire                               resp_scheduled ;

    assign rasdes_acc = |rasdes_reg_id ;
    // resp_error : This signal is set to 1 when there are no registers on the requested address.
    // resp_check : Indicate check cycle of ack[0] signals.
    assign resp_error = resp_check & ~( int_ack | cdm_ec_ack[0] | cdm_ei_ack[0] | cdm_sd_ack[0] | cdm_tba_ack[0] | cdm_tf_ack[0] ) ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            rasdes_acc_1d <= #TP 1'b0 ;
            resp_check    <= #TP 1'b0 ;
        end
        else begin
            rasdes_acc_1d <= #TP rasdes_acc ;
            resp_check    <= #TP rasdes_acc && !rasdes_acc_1d ;
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            rasdes_reg_ack      <= #TP 1'b0 ;
            rasdes_reg_data     <= #TP 32'h0000_0000 ;
            rasdes_reg_ack_done <= #TP 1'b0 ;
        end
        else begin
            if ( resp_error ) begin
                rasdes_reg_ack  <= #TP 1'b1 ;
                rasdes_reg_data <= #TP 32'h0000_0000 ;
            end
            else if ( int_ack ) begin
                rasdes_reg_ack  <= #TP 1'b1 ;
                rasdes_reg_data <= #TP int_rdata ;
            end
            else if ( cdm_ec_ack[1] ) begin
                rasdes_reg_ack  <= #TP 1'b1 ;
                rasdes_reg_data <= #TP cdm_ec_rdata ;
            end
            else if ( cdm_ei_ack[1] ) begin
                rasdes_reg_ack  <= #TP 1'b1 ;
                rasdes_reg_data <= #TP cdm_ei_rdata ;
            end
            else if ( cdm_sd_ack[1] ) begin
                rasdes_reg_ack  <= #TP 1'b1 ;
                rasdes_reg_data <= #TP cdm_sd_rdata ;
            end
            else if ( cdm_tba_ack[1] ) begin
                rasdes_reg_ack  <= #TP 1'b1 ;
                rasdes_reg_data <= #TP cdm_tba_rdata ;
            end
            else if ( cdm_tf_ack[1] ) begin
                rasdes_reg_ack  <= #TP 1'b1 ;
                rasdes_reg_data <= #TP cdm_tf_rdata ;
            end
            else if ( rasdes_reg_ack_done ) begin
                rasdes_reg_ack      <= #TP 1'b0 ;
                rasdes_reg_ack_done <= #TP 1'b0 ;
            end
            else if ( rasdes_reg_ack ) begin
                rasdes_reg_ack_done <= #TP 1'b1 ;
            end
        end
    end


//---------------------------------------------------
//  Common
//---------------------------------------------------
    wire   [7:0]                       int_reg_0x00, int_reg_0x01, int_reg_0x02, int_reg_0x03 ;  // Read Data Address 0x00-0x03
    wire   [7:0]                       int_reg_0x04, int_reg_0x05, int_reg_0x06, int_reg_0x07 ;  // Read Data Address 0x04-0x07

    assign resp_scheduled  = |cdm_reg_id[1:0] ;
    assign int_ack         = resp_check & resp_scheduled ;
    assign int_lbc_cdm_dbi = lbc_cdm_dbi & dbi_ro_wr_en ;

// -----------------------------------------------------------------------------
// rasdes_reg_id    - 0
// PCIE Offset      - `RAS_DES_PTR + 00h
// length           - 4 byte
// Cfig register    - int_reg_0x03, int_reg_0x02, int_reg_0x01, int_reg_0x00
// register         - PCI Express Extended Capability ID [15:0] : RO
//                  - Capability version [19:16] : RO
//                  - Next Capability Offset [31:20] : RO
// -----------------------------------------------------------------------------
    reg    [15:0]                      int_reg_cap_id ;              // PCI Express Extended Capability ID [15:0]
    reg    [3:0]                       int_reg_cap_ver ;             // Capability Version [19:16]
    reg    [11:0]                      int_reg_next_ptr ;            // Next Capability Offset [31:20]

    reg    [NF-1:0]                    rasdes_next_ptr_updated_nf; // Asserted when RASDES VD Cap header has been changed by a DBI write
    reg    [12*NF-1:0]                 int_reg_next_ptr_nf;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_reg_cap_id  <= #TP `PCIE_RAS_DES_ECAP_ID ;
            int_reg_cap_ver <= #TP `PCIE_RAS_DES_ECAP_VER ;
        end
        else begin
            int_reg_cap_id[7:0]  <= #TP (cdm_reg_id[0] & cdm_reg_write_pulse[0] & int_lbc_cdm_dbi ) ? lbc_cdm_data[7:0]   : int_reg_cap_id[7:0] ;
            int_reg_cap_id[15:8] <= #TP (cdm_reg_id[0] & cdm_reg_write_pulse[1] & int_lbc_cdm_dbi ) ? lbc_cdm_data[15:8]  : int_reg_cap_id[15:8] ;
            int_reg_cap_ver      <= #TP (cdm_reg_id[0] & cdm_reg_write_pulse[2] & int_lbc_cdm_dbi ) ? lbc_cdm_data[19:16] : int_reg_cap_ver ;
        end
    end

    //---------------------------------------------------------
    // Next pointer for each function
    //---------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            for (int FUNC_NUM=0 ; FUNC_NUM<NF ; FUNC_NUM=FUNC_NUM+1 ) begin
          // spyglass disable_block NonConstReset-ML
          // SMD: Invalid reset condition, RHS should be a static value. 
          // SJ: FUNC_NUM is a constant which is used in the definition of RAS_DES_NEXT_PTR. 
                int_reg_next_ptr_nf[12*FUNC_NUM+0 +: 12] <= #TP `RAS_DES_NEXT_PTR ;
          // spyglass enable_block NonConstReset-ML
            end
        end
        else begin
            for (int FUNC_NUM=0 ; FUNC_NUM<NF ; FUNC_NUM=FUNC_NUM+1 ) begin
                if( rasdes_reg_id[64*FUNC_NUM+0] && int_lbc_cdm_dbi ) begin // rasdes_reg_id has 64*NF bit.
                    int_reg_next_ptr_nf[12*FUNC_NUM+0 +: 4]  <= #TP ecfg_write_pulse[4*FUNC_NUM+2] ? lbc_cdm_data[23:20] : int_reg_next_ptr_nf[12*FUNC_NUM+0 +: 4] ;
                    int_reg_next_ptr_nf[12*FUNC_NUM+4 +: 8]  <= #TP ecfg_write_pulse[4*FUNC_NUM+3] ? lbc_cdm_data[31:24] : int_reg_next_ptr_nf[12*FUNC_NUM+4 +: 8] ;
                end
                else if ( !rasdes_next_ptr_updated_nf[FUNC_NUM] ) begin
                    int_reg_next_ptr_nf[12*FUNC_NUM+0 +: 12] <= #TP upstream_port ? cxl_rcrb_enable ? `CXL_RAS_DES_NEXT_PTR :  `RAS_DES_NEXT_PTR :  `DM_RP_RAS_DES_NEXT_PTR ;
                end
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if ( !sticky_rst_n ) begin
            for (int FUNC_NUM=0 ; FUNC_NUM<NF ; FUNC_NUM=FUNC_NUM+1 ) begin
                rasdes_next_ptr_updated_nf[FUNC_NUM] <= #TP 1'b0;
            end
        end
        else begin
            for (int FUNC_NUM=0 ; FUNC_NUM<NF ; FUNC_NUM=FUNC_NUM+1 ) begin
                if (rasdes_reg_id[64*FUNC_NUM+0] && int_lbc_cdm_dbi && |ecfg_write_pulse[4*FUNC_NUM+2 +: 2]) begin
                    rasdes_next_ptr_updated_nf[FUNC_NUM] <= #TP 1'b1;
                end
            end
        end
    end

    always @( * ) begin : for_int_reg_next_ptr
        integer jj ;
        int_reg_next_ptr = int_reg_next_ptr_nf[11:0] ;
        for ( jj=0 ; jj<NF ; jj=jj+1 ) begin
            if ( rasdes_reg_sel[jj] ) begin
                int_reg_next_ptr = int_reg_next_ptr_nf[12*jj +: 12] ;
            end
        end
    end

    assign {int_reg_0x03,int_reg_0x02,int_reg_0x01,int_reg_0x00} = { int_reg_next_ptr              // [31:20]
                                                                   , int_reg_cap_ver               // [19:16]
                                                                   , int_reg_cap_id                // [15:0]
                                                                   } ;

// -----------------------------------------------------------------------------
// rasdes_reg_id    - 1
// PCIE Offset      - `RAS_DES_PTR + 04h
// length           - 4 byte
// Cfig register    - int_reg_0x07, int_reg_0x06, int_reg_0x05, int_reg_0x04
// register         - VSEC ID [15:0] : RO
//                  - VSEC Rev [19:16] : RO
//                  - VSEC Length [31:20] : RO
// -----------------------------------------------------------------------------
    logic   [15:0]                      int_reg_vsec_id ;              // VSEC ID [15:0]
    logic   [3:0]                       int_reg_vsec_rev ;             // VSEC Rev [19:16]
    logic   [11:0]                      int_reg_vsec_len ;             // VSEC Length [31:20]

    assign int_reg_vsec_id  = `PCIE_RAS_DES_VSEC_ID ;
    assign int_reg_vsec_rev = `PCIE_RAS_DES_VSEC_REV ;
    assign int_reg_vsec_len = {3'd0, `RAS_DES_SIZE} ;

    assign {int_reg_0x07,int_reg_0x06,int_reg_0x05,int_reg_0x04} = { int_reg_vsec_len              // [31:20]
                                                                   , int_reg_vsec_rev              // [19:16]
                                                                   , int_reg_vsec_id               // [15:0]
                                                                   } ;

// =============================================================================
// Register Read Operation
// =============================================================================

always @(*) begin : read_data_PROC
    unique case (1'b1)
        cdm_reg_id[0]  : int_rdata = {int_reg_0x03, int_reg_0x02, int_reg_0x01, int_reg_0x00};
        cdm_reg_id[1]  : int_rdata = {int_reg_0x07, int_reg_0x06, int_reg_0x05, int_reg_0x04};
        default        : int_rdata = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule //cdm_rasdes_cmn_reg 
