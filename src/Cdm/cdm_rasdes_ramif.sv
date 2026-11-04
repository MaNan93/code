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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_rasdes_ramif.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module is RAM event counter top for RAS D.E.S.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_rasdes_ramif
#(
    parameter INST     = 0,                                                // The uniquifying parameter for each port logic instance.
    parameter TP       = `TP,                                              // Clock to Q delay (simulator insurance)
    parameter RASDES_EC_RAM_DATA_WIDTH = `CX_RAS_DES_EC_RAM_DATA_WIDTH,    // RAM data width
    parameter RASDES_EC_RAM_ADDR_WIDTH = `CX_RAS_DES_EC_RAM_ADDR_WIDTH,    // RAM address data width
    parameter RASDES_TBA_RAM_DATA_WIDTH = `CX_RAS_DES_TBA_RAM_DATA_WIDTH,  // RAM data width
    parameter RASDES_TBA_RAM_ADDR_WIDTH = `CX_RAS_DES_TBA_RAM_ADDR_WIDTH   // RAM address data width
)
(
// -------------- Inputs ---------------
    input                                          aux_clk,               // Clock
    input                                          sticky_rst_n           // Reset sticky registers only
                                                               ,
    //---- RAM I/F -----------------------
    input        [RASDES_EC_RAM_DATA_WIDTH-1:0]    cdm_ras_des_ec_ram_dataout,

    //---- Internal connection -----------------------
    input                                          ec_ram_ena,
    input                                          ec_ram_wea,
    input        [RASDES_EC_RAM_ADDR_WIDTH-1:0]    ec_ram_addra,
    input        [RASDES_EC_RAM_DATA_WIDTH-1:0]    ec_ram_datain,
    input                                          ec_ram_enb,
    input        [RASDES_EC_RAM_ADDR_WIDTH-1:0]    ec_ram_addrb
                                                               ,
    //---- RAM I/F -----------------------
    input        [RASDES_TBA_RAM_DATA_WIDTH-1:0]   cdm_ras_des_tba_ram_dataout,

    //---- Internal connection -----------------------
    input                                          tba_ram_ena,
    input                                          tba_ram_wea,
    input        [RASDES_TBA_RAM_ADDR_WIDTH-1:0]   tba_ram_addra,
    input        [RASDES_TBA_RAM_DATA_WIDTH-1:0]   tba_ram_datain,
    input                                          tba_ram_enb,
    input        [RASDES_TBA_RAM_ADDR_WIDTH-1:0]   tba_ram_addrb
    //---- Register read/write access

// -------------- Outputs ---------------
                                                               ,
    //---- RAM I/F -----------------------
    output reg                                     cdm_ras_des_ec_ram_ena,
    output reg                                     cdm_ras_des_ec_ram_wea,
    output reg   [RASDES_EC_RAM_ADDR_WIDTH-1:0]    cdm_ras_des_ec_ram_addra,
    output reg   [RASDES_EC_RAM_DATA_WIDTH-1:0]    cdm_ras_des_ec_ram_datain,
    output reg                                     cdm_ras_des_ec_ram_enb,
    output reg   [RASDES_EC_RAM_ADDR_WIDTH-1:0]    cdm_ras_des_ec_ram_addrb,
    //---- Internal connection -----------------------
    output reg   [RASDES_EC_RAM_DATA_WIDTH-1:0]    ec_ram_dataout
                                                                 ,
    //---- RAM I/F -----------------------
    output reg                                     cdm_ras_des_tba_ram_ena,
    output reg                                     cdm_ras_des_tba_ram_wea,
    output reg   [RASDES_TBA_RAM_ADDR_WIDTH-1:0]   cdm_ras_des_tba_ram_addra,
    output reg   [RASDES_TBA_RAM_DATA_WIDTH-1:0]   cdm_ras_des_tba_ram_datain,
    output reg                                     cdm_ras_des_tba_ram_enb,
    output reg   [RASDES_TBA_RAM_ADDR_WIDTH-1:0]   cdm_ras_des_tba_ram_addrb,
    //---- Internal connection -----------------------
    output reg   [RASDES_TBA_RAM_DATA_WIDTH-1:0]   tba_ram_dataout
) ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_ec_ram_ena    <= #TP 1'b0 ;
            cdm_ras_des_ec_ram_wea    <= #TP 1'b0 ;
            cdm_ras_des_ec_ram_addra  <= #TP {RASDES_EC_RAM_ADDR_WIDTH{1'b0}} ;
            cdm_ras_des_ec_ram_datain <= #TP {RASDES_EC_RAM_DATA_WIDTH{1'b0}} ;
            cdm_ras_des_ec_ram_enb    <= #TP 1'b0 ;
            cdm_ras_des_ec_ram_addrb  <= #TP {RASDES_EC_RAM_ADDR_WIDTH{1'b0}} ;
            ec_ram_dataout            <= #TP {RASDES_EC_RAM_DATA_WIDTH{1'b0}} ;
            cdm_ras_des_tba_ram_ena    <= #TP 1'b0 ;
            cdm_ras_des_tba_ram_wea    <= #TP 1'b0 ;
            cdm_ras_des_tba_ram_addra  <= #TP {RASDES_TBA_RAM_ADDR_WIDTH{1'b0}} ;
            cdm_ras_des_tba_ram_datain <= #TP {RASDES_TBA_RAM_DATA_WIDTH{1'b0}} ;
            cdm_ras_des_tba_ram_enb    <= #TP 1'b0 ;
            cdm_ras_des_tba_ram_addrb  <= #TP {RASDES_TBA_RAM_ADDR_WIDTH{1'b0}} ;
            tba_ram_dataout            <= #TP {RASDES_TBA_RAM_DATA_WIDTH{1'b0}} ;
        end
        else begin
            cdm_ras_des_ec_ram_ena    <= #TP ec_ram_ena ;
            cdm_ras_des_ec_ram_wea    <= #TP ec_ram_wea ;
            cdm_ras_des_ec_ram_addra  <= #TP ec_ram_addra ;
            cdm_ras_des_ec_ram_datain <= #TP ec_ram_datain ;
            cdm_ras_des_ec_ram_enb    <= #TP ec_ram_enb ;
            cdm_ras_des_ec_ram_addrb  <= #TP ec_ram_addrb ;
            ec_ram_dataout            <= #TP cdm_ras_des_ec_ram_dataout ;
            cdm_ras_des_tba_ram_ena    <= #TP tba_ram_ena ;
            cdm_ras_des_tba_ram_wea    <= #TP tba_ram_wea ;
            cdm_ras_des_tba_ram_addra  <= #TP tba_ram_addra ;
            cdm_ras_des_tba_ram_datain <= #TP tba_ram_datain ;
            cdm_ras_des_tba_ram_enb    <= #TP tba_ram_enb ;
            cdm_ras_des_tba_ram_addrb  <= #TP tba_ram_addrb ;
            tba_ram_dataout            <= #TP cdm_ras_des_tba_ram_dataout ;
        end
    end

endmodule //cdm_rasdes_ramif 
