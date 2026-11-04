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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/delay_n_w_stalling.sv#6 $
// -------------------------------------------------------------------------
// ---
// --- This block delays the input by n cycles.
// ---
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module delay_n_w_stalling(
    clk,
    rst_n,
    stall,
    clear,
    din,

    stallout,
    dout
);
parameter N         = 0;            // Number of cycles to delay
parameter WD        = 1;            // Width of datapath
parameter CAN_STALL = 0;            // Extra output stage enables stalling
parameter RESETVAL  = {WD{1'b0}};   // Allow for non-zero reset value

input               clk;
input               rst_n;
input               stall; // Stall if not enabled
input               clear; // Synchronus reset
input   [WD-1:0]    din;

output  logic       stallout;
output  [WD-1:0]    dout;

reg     [WD-1:0]    mem[0:N];  
reg     [WD-1:0]    dout_r;
reg                 stall_d;

wire    [WD-1:0]    dout0_w_stall;
// ccx_cond_begin: u_msg_gen.u_ven_msi_delay,u_msg_gen.u_msg_formation.u_vf_index_delay ;;; Redundant code since inputs clear and stall are connected to the same input signals - stall_d is '0' whatever stall value is.
assign dout0_w_stall = stall_d ? dout_r : din;
// ccx_cond_end
wire    [WD-1:0]    dout0_mux;
assign dout0_mux = CAN_STALL ? dout0_w_stall : din;
assign dout     = (N == 0) ? dout0_mux : mem[N];
always_comb stallout = CAN_STALL ? stall_d : stall;

integer i;
always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        for (i=0; i<=N; i=i+1)  mem[i]  <= #(`TP) RESETVAL;
        stall_d     <= #(`TP) 1'b0;
        dout_r      <= #(`TP) RESETVAL;

    end else if (clear) begin
        for (i=0; i<=N; i=i+1)  mem[i]  <= #(`TP) RESETVAL;
        stall_d     <= #(`TP) 1'b0;
        dout_r      <= #(`TP) RESETVAL;

    // With output stalling
    end else if (CAN_STALL) begin
        stall_d     <= #(`TP) stall;
        if (stall & !stall_d) begin             // Start stalling
// ccx_line_begin: u_msg_gen.u_ven_msi_delay,u_msg_gen.u_msg_formation.u_vf_index_delay ;  Redundant code for N=0, Loop never executed for N = 0 (default value of the CX_VEN_MSI_REGIN param).
            for (i=0; i<N; i=i+1) begin
// ccx_line_end
              //mem[i+1]    <= #(`TP) (i==(N-1)) ? mem[i+1] : mem[i];  // Don't let output change
// ccx_line_cond_begin: u_msg_gen.u_ven_msi_delay,u_msg_gen.u_msg_formation.u_vf_index_delay ; Redundant code for N=0, Condition (i==(N-1)) never covered for N = 0 (default value of the CX_VEN_MSI_REGIN param).
                mem[i+1]    <= #(`TP) (i==(N-1)) ? mem[i+1] : (i==0) ? din : mem[i];  // Don't let output change
// ccx_line_cond_end
            end
// ccx_line_begin: u_msg_gen.u_ven_msi_delay,u_msg_gen.u_msg_formation.u_vf_index_delay ;  Redundant code for N=0 (default value of the CX_VEN_MSI_REGIN param), therefore the if statement cannot be applied for mem[(N<2)?N: N-1].
            dout_r      <= #(`TP) (N<2) ? din : mem[(N<2)?N: N-1];     
// ccx_line_end
        end else if (!stall & stall_d) begin    // Unstall
// ccx_line_begin: u_msg_gen.u_ven_msi_delay,u_msg_gen.u_msg_formation.u_vf_index_delay ;  Redundant code since inputs clear and stall are connected to the same input signals - stall_d is '0' whatever stall value is
                mem[N]      <= #(`TP) dout_r;
// ccx_line_end
        end else if (!stall) begin              // Continue
// ccx_line_begin: u_msg_gen.u_msg_formation.u_vf_index_delay ;  Redundant code for N=0, Loop never executed for N = 0 (default value of the CX_VEN_MSI_REGIN param).
            for (i=0; i<N; i=i+1) begin
// ccx_line_end
// ccx_line_cond_begin: u_msg_gen.u_ven_msi_delay,u_msg_gen.u_msg_formation.u_vf_index_delay ; Redundant code for N=0, Loop never executed for N = 0 (default value of the CX_VEN_MSI_REGIN param).
                mem[i+1]    <= #(`TP) (i==0) ? din : mem[i];
// ccx_line_cond_end
            end
            if (N==0) begin
                dout_r      <= #(`TP) dout;    // Always have this ready
            end
        end

    // No output stalling
    end else begin
        if (!stall) begin                       // Stall immediately
// ccx_line_begin: u_msg_gen.u_ven_msi_delay,u_msg_gen.u_msg_formation.u_vf_index_delay ;  Redundant code for N=0, Loop never executed for N = 0 (default value of the CX_VEN_MSI_REGIN param).
            for (i=0; i<N; i=i+1) begin
// ccx_line_end
// ccx_line_cond_begin: u_msg_gen.u_ven_msi_delay,u_msg_gen.u_msg_formation.u_vf_index_delay ; Redundant code for N=0, Loop never executed for N = 0 (default value of the CX_VEN_MSI_REGIN param).
                mem[i+1]    <= #(`TP) (i==0) ? din : mem[i];
// ccx_line_cond_end
            end
        end
    end

endmodule
