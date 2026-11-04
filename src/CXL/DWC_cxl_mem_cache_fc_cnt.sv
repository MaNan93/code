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
// --- RCS information:
// ---   $DateTime: 2023/06/26 08:32:07 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_fc_cnt.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Flow Control Counters used to control the transmit interface based on the
// remote receive queues resource availability.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_fc_cnt
    import DWC_cxl_pkg::*;
#(
    parameter PROT  = 0,   // Protocol: 0 - CXL.cache; 1 - CXL.mem 
    parameter CHNUM = 1,   // Number of message channels the credit pool is shared between
    parameter TP    = `TP
)
                                   (
// Inputs ------------------------------------------------------------------------------
    input                                 core_clk,            // Core Clock
    input                                 core_rst_n,          // Core Reset
    input                                 cfg_enable_i,        // Enable Credit FC counter
    input  [TX_CRDIF_WIDTH-1:0]           tx_msg_vld_i,        // Number of messages consumed by the Flit Packer (packed in the flit)
    input  [(CHNUM*FLIT_CRD_WD)-1:0]      rx_crd_ret_i,        // RX Credit Return in 68B Flit Mode - received with 32-bit Flit Header
    input                                 cxl_device_mode,     // 0 - Endpoint; 1 - Root Complex Device
    input                                 cxl_pcie_flit_mode,  // CXL 256B Flit Mode
    input  [(CHNUM*5)-1:0]                rx_crd_ret_256B_i,   // RX Credit Return in 256B Flit Mode - received with 2B CRD field
// Outputs -----------------------------------------------------------------------------
    output logic                          rsvd_crd_enc_error_o,
    output [TX_CREDIT_WD-1:0]             fc_crd_o,            // CXL Link Layer TX Credit Status Register
    output [TX_CRDIF_WIDTH-1:0]           fc_gnt_o             // Number of credits grant to the Flit Packer
);

parameter COUNT_VALID_WIDTH = $clog2(TX_CRDIF_WIDTH);

logic [(CHNUM*FLIT_CRD_WD)-1:0] rx_crd_ret_sel_s;           // RX Credit Return selected for a given channel (68B Flit)
logic [(CHNUM*5)-1:0]           rx_crd_ret_sel_256B_s;      // RX Credit Return selected for a given channel (256B Flit)
logic [DEC_CRD_WD-1:0]          rx_crd_ret_s;               // RX Credit Return
logic                           rx_crd_ret_ovflw_s;         // RX Credit Return (resolves spyglass issue)
logic [TX_CREDIT_WD-1:0]        fc_crd_cnt_r, fc_crd_cnt_s; // FC Credit Counter
logic [TX_CRDIF_WIDTH-1:0]      fc_crd_gnt_r, fc_crd_gnt_s; // FC Credit Grant Register
logic [DEC_CRD_WD:0]            dec_rx_crd_256byte_s;
logic [TX_CREDIT_WD-1:0]        fc_crd_s;                   // Axillary Signal For fc_crd_cnt_s
logic                           saturation_flag_s;          // if 1, Remote Parttener Sends Credit Return more than RX_Counter of the Local Parttener Can Count.  

assign fc_crd_o = fc_crd_cnt_r;
assign fc_gnt_o = fc_crd_gnt_r;


always_comb begin
  saturation_flag_s = '0;
  {saturation_flag_s, fc_crd_s} = {1'b0, fc_crd_cnt_r} + rx_crd_ret_s - count_valid(tx_msg_vld_i);
  if(saturation_flag_s)
     fc_crd_cnt_s = '1;
  else 
     fc_crd_cnt_s = fc_crd_s;
end 

assign fc_crd_gnt_s = credit_gnt(fc_crd_cnt_s);

always_comb begin : crd_ret_proc
    {rx_crd_ret_ovflw_s, rx_crd_ret_s} = '0;
    rsvd_crd_enc_error_o ='0;
    if (cfg_enable_i) begin
        for (int i = 0; i < CHNUM; i++) begin
            if (cxl_pcie_flit_mode) begin
                rx_crd_ret_sel_256B_s = rx_crd_ret_256B_i >> (i*5);
                dec_rx_crd_256byte_s = dec_rx_crd_256byte(rx_crd_ret_sel_256B_s[4:0], PROT, cxl_device_mode);
                {rx_crd_ret_ovflw_s, rx_crd_ret_s} = {1'b0, rx_crd_ret_s} + dec_rx_crd_256byte_s[DEC_CRD_WD-1:0];
                rsvd_crd_enc_error_o = dec_rx_crd_256byte_s[DEC_CRD_WD];
            end
            else
            begin
                rx_crd_ret_sel_s = rx_crd_ret_i >> (i*FLIT_CRD_WD);
                {rx_crd_ret_ovflw_s, rx_crd_ret_s} = {1'b0, rx_crd_ret_s} + dec_credit(rx_crd_ret_sel_s[FLIT_CRD_WD-1:0]);
            end
        end
    end
end : crd_ret_proc

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        fc_crd_cnt_r <= # TP '0;
        fc_crd_gnt_r <= # TP '0;
    end else begin
        fc_crd_cnt_r <= # TP fc_crd_cnt_s;
        fc_crd_gnt_r <= # TP fc_crd_gnt_s;
    end
end

// -------------------------------------------------------------------------------------
// Decode Credit Return for 68B Flit Format
// -------------------------------------------------------------------------------------
function automatic [DEC_CRD_WD-1:0] dec_credit (
  input [FLIT_CRD_WD-1:0] credit_return
);
  begin
    if (credit_return[FLIT_CRD_WD-1] == PROT) begin
        unique case (credit_return[FLIT_CRD_WD-2:0])
          3'b000 : dec_credit = 'd0;
          3'b001 : dec_credit = 'd1;
          3'b010 : dec_credit = 'd2;
          3'b011 : dec_credit = 'd4;
          3'b100 : dec_credit = 'd8;
          3'b101 : dec_credit = 'd16;
          3'b110 : dec_credit = 'd32;
          3'b111 : dec_credit = 'd64;
        endcase
    end
    else dec_credit = 'd0;
  end
  return dec_credit;
endfunction
// -------------------------------------------------------------------------------------
/*   
        //device_type = 1                            //device_type = 0
////////////////////////////////////      //////////////////////////////////// 
//             Host               //      //             Device             // 
//          Root-Complex          //      //            Endpoint            // 
////////////////////////////////////      ////////////////////////////////////
                                     
////////////////////////////////////      //////////////////////////////////// 
//    TX : Host (Root-Complex)    //      //   RX : Device (Endpoint)       //
//                                //      ////////////////////////////////////
////////////////////////////////////      //                                //
//                                //      //////////////// //////////////// // 
// ////////////////////////////// //      //// RX Queue // //  CDR RX    // // 
// //   CDR TX   //   CDR TX   // //      //////////////// //  decoder   // // 
// //   encoder  //   decoder  // //      //// receive  // //(D2H & S2M) // // 
// // (D2H & S2M)// (D2H & S2M)// // >>>> ////H2D + M2S // //  of the    // // 
// //   of the   // overflow of// //      //// messages // // Host queue // // 
// // Host queue // Host queue // //      //////////////// //////////////// // 
// /////////////////////////////////      //                                // 
////////////////////////////////////      ////////////////////////////////////
                                     
////////////////////////////////////      ////////////////////////////////////
//    RX : Host (Root-Complex)    //      //     TX : Device (Endpoint)     //
////////////////////////////////////      //                                //
//                                //      //////////////////////////////////// 
//////////////// //////////////// //      //                                // 
//// RX Queue // //  CDR RX    // //      // ////////////////////////////// // 
//////////////// //  decoder   // //      // //   CDR TX   //   CDR TX   // // 
//// receive  // //(H2D & M2S) // // <<<< // //   encoder  //   decoder  // // 
////D2H + S2M // //  of the    // //      // // (H2D & M2S)// (H2D & M2S)// // 
//// messages // //Device queue// //      // //   of the   //overflow of // // 
//////////////// //////////////// //      // //Device queue//Device queue// // 
//                                //      // /////////////////////////////////
////////////////////////////////////      //////////////////////////////////// 
*/
// -------------------------------------------------------------------------------------
// Decode Credit Return for 256B Flit Format
// -------------------------------------------------------------------------------------
function automatic [DEC_CRD_WD:0] dec_rx_crd_256byte (
    input [4:0] credit_return, // Credit Return field from 2B CRD field
    input       protocol_type, // 0 - CXL.cache, 1 - CXL.mem
    input       device_type    // 0 - Endpoint, 1 - Root-Complex
);
  begin
    // Preset dec_rx_crd_256byte 
    dec_rx_crd_256byte = '0;
    // CXL.cache decode
    if (!protocol_type) begin
        // Root-Complex
        if (device_type) begin
            case (credit_return) // H2D Request/H2D Data/H2D Response
                5'h04  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd1 ;
                5'h05  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd4 ;
                5'h06  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd8 ;
                5'h07  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd12;
                5'h08  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd16;
                default: dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd0 ;
            endcase
        end
        // Endpoint
        else begin
            case (credit_return) // D2H Request/D2H Data/D2H Response
                5'h09  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd1 ;
                5'h0A  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd4 ;
                5'h0B  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd8 ;
                5'h0C  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd12;
                5'h0D  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd16;
                default: dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd0 ;
            endcase
        end
    end
    // CXL.mem decode 
    else begin
        // Root-Complex
        if (device_type) begin
            case (credit_return) // M2S Request/M2S Data/M2S BI-Response
                5'h14  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd1 ;
                5'h15  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd4 ;
                5'h16  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd8 ;
                5'h17  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd12;
                5'h18  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd16;
                default: dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd0 ;
            endcase
        end
        // Endpoint
        else begin
            case (credit_return) // S2M BI-Snoop/S2M Data/S2M Response
                5'h19  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd1 ;
                5'h1A  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd4 ;
                5'h1B  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd8 ;
                5'h1C  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd12;
                5'h1D  : dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd16;
                default: dec_rx_crd_256byte[DEC_CRD_WD-1:0] = 'd0 ; 
            endcase
        end
    end // protocol_type
    // Reserved Encoding Credit Return  
    casez (credit_return)
        5'h?2  ,
        5'h?3  ,
        5'h?E  ,
        5'h?F  ,
        5'h10  ,
        5'h11  : dec_rx_crd_256byte[DEC_CRD_WD] = 1'd1; // Reserved Encoding Error
        default: dec_rx_crd_256byte[DEC_CRD_WD] = 1'd0 ; 
    endcase
    //credit
  end
  return dec_rx_crd_256byte;
endfunction
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Count valid inputs
// -------------------------------------------------------------------------------------
function automatic [COUNT_VALID_WIDTH:0] count_valid (
  input [TX_CRDIF_WIDTH-1:0] valid
);
  begin
    integer a;
    count_valid = 'd0;
    for (a = 0; a < TX_CRDIF_WIDTH; a = a + 1) begin
      if (valid[a])
        count_valid = count_valid + 'd1;
    end
  end
  return count_valid;
endfunction
// -------------------------------------------------------------------------------------

function automatic [TX_CRDIF_WIDTH-1:0] credit_gnt (
  input [(TX_CREDIT_WD - 1) : 0] credit_count
);
  begin
    credit_gnt = ~({TX_CREDIT_WD{1'b1}} << credit_count);

    return credit_gnt;
  end
endfunction

endmodule
