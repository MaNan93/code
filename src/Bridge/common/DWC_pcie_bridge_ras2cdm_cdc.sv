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
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_ras2cdm_cdc.sv#7 $
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_bridge_ras2cdm_cdc
  #(
    parameter CLKDIFF    = 1,  // 0 - No clock crossing
                               // 1 - Clock crossing
    parameter DATA_WD     = 1, // Data width to be synchronized

    parameter TP          = `TP
    )
   (
    input                clk_s,
    input                rst_s_n,

    input                clk_d,
    input                rst_d_n,

    input                err_pulse_s,
    input [DATA_WD-1:0]  ram_addr_s,

    output               err_pulse_d,
    output [DATA_WD-1:0] ram_addr_d
    );


   //----------------------------------------------
   // Internal wire & params

   reg [DATA_WD-1:0]     r_ram_addr_latch_s;

   reg                   r_pos_edge;

   wire                  cdc_ack;

   localparam            SYNC_DEPTH  = `CX_PCIE_SYNC_DEPTH;

   //----------------------------------------------
   // Internal implementation

   generate
      if (CLKDIFF) begin: PROC_ras2cdm_cdc
         //----------------------------------------------
         // Clock crossing implementation

         always @ (posedge clk_s or negedge rst_s_n) begin : PROC_seq_posedge
            if (!rst_s_n) begin
               r_pos_edge <= #TP 1'b0;
            end else begin
               if (cdc_ack) begin
                 r_pos_edge <= #TP 1'b0;
               end else if (err_pulse_s) begin
                 r_pos_edge <= #TP 1'b1;
               end
            end
         end

         //Latches the addess and keeps it stable while CDC is transferring the data
         always @ (posedge clk_s or negedge rst_s_n) begin : PROC_seq_addr_latch
            if (!rst_s_n) begin
               r_ram_addr_latch_s <= #TP {DATA_WD{1'b0}};
            end else begin
               if (err_pulse_s & !r_pos_edge)
                 r_ram_addr_latch_s <= #TP ram_addr_s;
            end
         end


         DWC_pcie_ctl_bcm25
         
           #(
             .F_SYNC_TYPE (SYNC_DEPTH),
             .R_SYNC_TYPE (SYNC_DEPTH),
             .SEND_MODE (1),     //posedge send_s
             .PEND_MODE (0),     //No buffering
             .WIDTH     (DATA_WD)
             )
         u_cdc
           (
            .clk_s        (clk_s             ),
            .rst_s_n      (rst_s_n           ),
            .init_s_n     (1'b1              ),

            .clk_d        (clk_d             ),
            .rst_d_n      (rst_d_n           ),
            .init_d_n     (1'b1              ),

            .send_s       (r_pos_edge        ),
            .data_s       (r_ram_addr_latch_s),
            .done_s       (cdc_ack           ),
            .empty_s      (),
            .full_s       (),

            .data_d       (ram_addr_d        ),
            .data_avail_d (err_pulse_d       )
            );

      end else begin: PROC_ras2cdm_cdc
         //----------------------------------------------
         // No clock crossing implementation
         assign err_pulse_d = err_pulse_s;
         assign ram_addr_d  = ram_addr_s;

      end // else: !if(CLKDIFF)
   endgenerate

endmodule
