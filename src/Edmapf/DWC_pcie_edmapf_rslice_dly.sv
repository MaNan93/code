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
// ---    $Revision: #9 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_rslice_dly.sv#9 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_rslice_dly
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter    type P_DATATYPE = logic
  ,parameter          P_AUX_CLK = 0
  ,parameter dlyType_e P_STAGES = E_FEED_NONE
  ) 
                                   (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   interface.master_mp               b_dst
  ,interface.slave_mp                b_src
  ,DWC_pcie_edmapf_aclks_if.slave_mp b_clkrst
  );


// SNPS_SysML_CODE_START
  typedef struct packed {
    logic      valid;
    P_DATATYPE data;
  } rslice_s;

  logic aux_clk, main_clk, rstn;

  localparam LP_RAM_DEPTH   = P_AUX_CLK ? 3 :(
                            P_STAGES == E_FEED_NONE ? 2 :(
                            P_STAGES == E_FEED_HALT ? 1 : 0));

  assign main_clk = b_clkrst.w_main_clk;
  assign rstn     = b_clkrst.w_reset_n;
  
  generate

    if (P_AUX_CLK) begin : CLK_MUX_GEN
      assign aux_clk = b_clkrst.w_aux_clk;
    end else begin : NCLK_MUX_GEN
      assign aux_clk = b_clkrst.w_main_clk;
    end


    case ({P_AUX_CLK, P_STAGES})

      {1'b0, E_FEED_ALL} : begin  : FALL_GEN
        assign b_dst.w_valid  = b_src.w_valid;
        assign b_dst.w_data   = b_src.w_data ;
        assign b_src.w_ready  = b_dst.w_ready; 
      end

      {1'b0, E_FEED_HALT} : begin : FHALT_GEN
        rslice_s s_head, r_head;

        always_ff @ (posedge main_clk or negedge rstn) begin : PROC_FF_head
          if (!rstn)
            r_head <= # `TP '0;
          else
            r_head <= # `TP s_head;
        end

        always_comb begin : PROC_CB_head
          s_head = r_head;

          if (b_dst.w_ready || !r_head.valid) begin
            s_head.valid = b_src.w_valid;
            s_head.data  = b_src.w_data;
          end
        end
        
        assign b_src.w_ready = !r_head.valid || b_dst.w_ready;

        assign b_dst.w_valid = r_head.valid;
        assign b_dst.w_data  = r_head.data; 
      end
      
      default : begin          : P_AUX_CLK_FNONE_GEN
        typedef logic[$bits(P_DATATYPE)-1:0]     ram_data_t;
        typedef logic [$clog2(LP_RAM_DEPTH)-1:0] ram_addr_t;

        typedef struct packed {
          ram_data_t data_in;
          ram_data_t data_out;
          logic      wr_n;
          ram_addr_t wr_addr;
          ram_addr_t rd_addr; 
        } ram_st;

        typedef struct packed {
          ram_addr_t wr_addr;
          ram_addr_t rd_addr; 
          logic wr_full;
          logic rd_empty;
        } fifo_ctl_st;

        ram_st ram;
        fifo_ctl_st r_fifo_ctl, s_fifo_ctl;


        // Generates RAM like storage 
        DWC_pcie_ctl_bcm57
         # (
           .DATA_WIDTH ($bits(P_DATATYPE)   )
          ,.DEPTH      (LP_RAM_DEPTH        )
          ,.ADDR_WIDTH ($clog2(LP_RAM_DEPTH))
          ,.MEM_MODE   (0                   ) // no pre or post timming
        ) u_ram (
           .clk       (aux_clk)    
          ,.rst_n     (rstn   )
          ,.wr_n      (ram.wr_n    )
          ,.data_in   (ram.data_in )
          ,.wr_addr   (ram.wr_addr )
          ,.rd_addr   (ram.rd_addr )
          ,.data_out  (ram.data_out)
        );
    
        assign ram.data_in  = ram_data_t'(b_src.w_data);

        assign b_dst.w_data = P_DATATYPE'(ram.data_out);
        assign b_dst.w_valid = !r_fifo_ctl.rd_empty;

        assign b_src.w_ready= !r_fifo_ctl.wr_full;


        assign ram.wr_n     = !(b_src.w_valid && b_src.w_ready);

        assign ram.wr_addr = r_fifo_ctl.wr_addr;
        assign ram.rd_addr = r_fifo_ctl.rd_addr;


        // Dual clock fifo to support missing main clk when P_AUX_CLK is defined
        always_ff @ (posedge aux_clk or negedge rstn) begin : PROC_FF_wr_ctl
          if (!rstn) begin
            r_fifo_ctl.wr_addr <= # `TP '0;
            r_fifo_ctl.wr_full <= # `TP '0;
          end else begin
            r_fifo_ctl.wr_addr <= # `TP s_fifo_ctl.wr_addr;
            r_fifo_ctl.wr_full <= # `TP s_fifo_ctl.wr_full; 
          end
        end

        always_ff @ (posedge main_clk or negedge rstn) begin : PROC_FF_rd_ctl
          if (!rstn) begin
            r_fifo_ctl.rd_addr  <= # `TP '0;
            r_fifo_ctl.rd_empty <= # `TP 1'b1;
          end else begin
            r_fifo_ctl.rd_addr  <= # `TP s_fifo_ctl.rd_addr;
            r_fifo_ctl.rd_empty <= # `TP s_fifo_ctl.rd_empty; 
          end
        end
 
        always_comb begin : PROC_CB_ctl_wr_addr
          s_fifo_ctl.wr_addr = r_fifo_ctl.wr_addr;

          if (b_src.w_valid && !r_fifo_ctl.wr_full) begin
            if (r_fifo_ctl.wr_addr < LP_RAM_DEPTH - 1)
              s_fifo_ctl.wr_addr = r_fifo_ctl.wr_addr + 1;
            else
              s_fifo_ctl.wr_addr = '0;
          end

        end


        if (P_AUX_CLK) begin : P_AUX_GEN

          always_comb begin : PROC_CB_ctl_wr_full
            s_fifo_ctl.wr_full = r_fifo_ctl.wr_full;

            // can go one scenario (write happens) - a simultaneous write read has null effect
            if (b_src.w_valid && b_src.w_ready && s_fifo_ctl.wr_addr == r_fifo_ctl.rd_addr)
              s_fifo_ctl.wr_full = '1;

            // Can go zero scenario (read happens)
            if (s_fifo_ctl.wr_addr != r_fifo_ctl.rd_addr)
              s_fifo_ctl.wr_full = '0;

          end

        end else begin : NP_AUX_GEN

          always_comb begin : PROC_CB_ctl_wr_full
            s_fifo_ctl.wr_full = r_fifo_ctl.wr_full;

            // can go one scenario (write happens) - a simultaneous write read has null effect
            if (b_src.w_valid && b_src.w_ready && s_fifo_ctl.wr_addr == r_fifo_ctl.rd_addr)
              s_fifo_ctl.wr_full = '1;

            // Can go zero scenario (read happens)
            if (b_dst.w_valid && b_dst.w_ready)
              s_fifo_ctl.wr_full = '0;

          end          
        end

        always_comb begin : PROC_CB_ctl_rd_addr
          s_fifo_ctl.rd_addr = r_fifo_ctl.rd_addr;

          // allow the rd pointer to advance when not empty
          if ( b_dst.w_ready && !r_fifo_ctl.rd_empty) begin
            if (r_fifo_ctl.rd_addr < LP_RAM_DEPTH - 1)
              s_fifo_ctl.rd_addr = r_fifo_ctl.rd_addr + 1;
            else
              s_fifo_ctl.rd_addr = '0;
          end

        end

        always_comb begin : PROC_CB_ctl_rd_empty
          s_fifo_ctl.rd_empty = r_fifo_ctl.rd_empty;
 
          //reading into the same position as the write
          if (b_dst.w_valid && b_dst.w_ready && (s_fifo_ctl.rd_addr == r_fifo_ctl.wr_addr || r_fifo_ctl.rd_addr == r_fifo_ctl.wr_addr))
            s_fifo_ctl.rd_empty = '1;

          // if the main clk is absent write event might have been missed
          if (r_fifo_ctl.rd_addr != r_fifo_ctl.wr_addr && r_fifo_ctl.rd_empty)
            s_fifo_ctl.rd_empty = '0;
 
          // can go zero scenario (write happens - this minimizes latency from previous case, making fifo smaller)
          if (s_fifo_ctl.wr_addr != r_fifo_ctl.wr_addr)
            s_fifo_ctl.rd_empty = '0;

          // If full it's not empty
          if (r_fifo_ctl.wr_full)
            s_fifo_ctl.rd_empty = '0;

        end
          
      end
    endcase

  endgenerate


 
// SNPS_SysML_CODE_END

endmodule
