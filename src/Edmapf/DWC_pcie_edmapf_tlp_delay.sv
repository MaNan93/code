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
// ---    $Revision: #10 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_tlp_delay.sv#10 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_rasdp_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_tlp_delay
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter   type P_HEADERTYPE = logic
  ,parameter           P_AUX_CLK = 0
  ,parameter            P_DATAWD = 8
  ,parameter     P_EXT_RAM_DEPTH = 0
  ,parameter bool_e P_RAS_CHK_EN = E_FALSE
  ,parameter bool_e P_RAS_GEN_EN = E_FALSE
  ,parameter  dlyType_e P_STAGES = E_FEED_HALT
  ,parameter     ifType_e P_TYPE = E_TLP_HEADER
  ,parameter       RAS_DP_PROT_CHK_ID = 0
  ) 
                                  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   interface.master_mp                b_dst
  ,interface.slave_mp                 b_src
  ,DWC_pcie_edmapf_aclks_if.slave_mp  b_clkrst
    ,DWC_pcie_edmapf_rasdp_if.master_mp b_ras
  );


// SNPS_SysML_CODE_START
  localparam L_HEADERPROTWD = (($bits(P_HEADERTYPE)-1)/K_RAS_PROT_RANGE+1);
  localparam L_DATAPROTWD   = ((P_DATAWD-1)/K_RAS_PROT_RANGE)+1           ;

  typedef struct packed{
    logic [P_DATAWD-1:0]       data       ;
    P_HEADERTYPE               header     ;
    logic                      hv         ;
    logic                      dv         ;
    logic                      eot        ;
    logic [L_HEADERPROTWD-1:0] headerProt ;
  } tlp_s;

  logic aux_clk, main_clk, rstn;
  tlp_s w_dst;
  tlp_s w_src;

  generate
    if (P_TYPE != E_TLP_HEADER) begin : DATAPATH_GEN
      if (P_RAS_GEN_EN) begin : RAS_GEN_EN_GEN

        P_HEADERTYPE               w_ras_gen_dataout ;
        logic [L_HEADERPROTWD-1:0] w_ras_gen_chkout  ;
        
   // Generator
        ras_dp_pipe
         #(
          .PIPELINE_TYPE              (0                             ), // 0: delay_n
          .RESETVAL                   (0                             ),
          .N_STAGES                   (0                             ),
          .CAN_STALL                  (0                             ),
          .RESET_STALL                (0                             ),
          .BUS_PROTECT_GEN_EN         (1                             ), // 1: Bus Protection Generator is present
          .BUS_PROTECT_CHK_EN         (0                             ), // 0: Bus Protection Checker is not present (ECC/Parity)
          .PROT_TYPE                  (1                             ), // 0=Ecc, 1=Simple Parity
          .PROT_RANGE                 (K_RAS_PROT_RANGE              ), // Number of bits to calculate parity/ECC on
          .PROT_WD                    (L_HEADERPROTWD                ), // Selects the width of the din_prot/dout_prot signals
          .PARITY_MODE                (K_RAS_PARITY_MODE             ), // selects the type of parity: 0=Even, 1=Odd
          .PROT_CORRECT_EN            (/* NC */                      ), // 0: no correction on single-errors, 1: correction on single-errors
          .TOTAL_WIDTH                ($bits(P_HEADERTYPE)           ), 
          .EXCLUDE_PROT_WIDTH         (0                             ),
          .RAS_DP_PROT_CHK_ID_BASE    (/* NC */                      ), // Associates the Bus Protection Checker with a unique identifier
          .ADDR_ECC_PROT_EN           (/* NC */                      ),
          .ADDR_LOG_EN                (/* NC */                      ),
          .ADDR_INDEX                 (/* NC */                      ),
          .ADDR_WD                    (/* NC */                      )
        ) u_ras_gen (
           .clk                       ( aux_clk                      )
          ,.rst_n                     ( rstn                         )
          ,.din                       ( b_src.w_header               )
          ,.din_prot                  ( {L_HEADERPROTWD{1'b0}}       )
          ,.dout                      ( w_ras_gen_dataout            )
          ,.dout_prot                 ( w_ras_gen_chkout             )
          ,.en                        ( 1'b1                         )
          ,.bypass                    ( 1'b0                         )
          ,.stall                     ( 1'b0                         )
          ,.stallout                  ( /* Not Connected */          )
          ,.valid_in                  ( b_src.w_hv                   )
          ,.halt_out                  ( /* Not Connected */          )
          ,.valid_out                 ( /* Not Connected */          )
          ,.halt_in                   ( 1'b0                         )
          ,.ras_dp_err_inband_kbd_in  ( 1'b0                         )
          ,.ras_dp_err_inband_kbd_out ( /* Not Connected */          )
          ,.ras_dp_err_log            ( /* Not Connected */          )
            ,.ras_dp_err_inj          ( '0                           )
          );

        assign w_src.hv         = b_src.w_hv        ;
        assign w_src.data       = b_src.w_data      ;
        assign w_src.dv         = b_src.w_dv        ;
        assign w_src.eot        = b_src.w_eot       ;
        assign w_src.header     = w_ras_gen_dataout ;
        assign w_src.headerProt = w_ras_gen_chkout  ;

      end else begin : NO_RAS_GEN_GEN

        assign w_src.header     = b_src.w_header    ;
        assign w_src.hv         = b_src.w_hv        ;
        assign w_src.data       = b_src.w_data      ;
        assign w_src.dv         = b_src.w_dv        ;
        assign w_src.eot        = b_src.w_eot       ;
        assign w_src.headerProt = b_src.w_headerProt;

      end
      if (P_RAS_CHK_EN) begin : RAS_CHK_EN_GEN
      
   // Checker
        ras_dp_pipe
         #(
          .PIPELINE_TYPE              (0                             ), // 0: delay_n
          .RESETVAL                   (0                             ),
          .N_STAGES                   (0                             ),
          .CAN_STALL                  (0                             ),
          .RESET_STALL                (0                             ),
          .BUS_PROTECT_GEN_EN         (0                             ), // 1: Bus Protection Generator is present
          .BUS_PROTECT_CHK_EN         (1                             ), // 0: Bus Protection Checker is not present (ECC/Parity)
          .PROT_TYPE                  (1                             ), // 0=Ecc, 1=Simple Parity
          .PROT_RANGE                 (K_RAS_PROT_RANGE              ), // Number of bits to calculate parity/ECC on
          .PROT_WD                    (L_HEADERPROTWD                ), // Selects the width of the din_prot/dout_prot signals
          .PARITY_MODE                (K_RAS_PARITY_MODE             ), // selects the type of parity: 0=Even, 1=Odd
          .PROT_CORRECT_EN            (0                             ), // 0: no correction on single-errors, 1: correction on single-errors
          .TOTAL_WIDTH                ($bits(P_HEADERTYPE)           ), 
          .EXCLUDE_PROT_WIDTH         (0                             ),
          .RAS_DP_PROT_CHK_ID_BASE    (RAS_DP_PROT_CHK_ID            ), // Associates the Bus Protection Checker with a unique identifier
          .ADDR_ECC_PROT_EN           (/* NC */                      ),
          .ADDR_LOG_EN                (/* NC */                      ),
          .ADDR_INDEX                 (/* NC */                      ),
          .ADDR_WD                    (/* NC */                      )
        ) u_ras_chk (
           .clk                       ( aux_clk                      )
          ,.rst_n                     ( rstn                         )
          ,.din                       ( w_dst.header                 )
          ,.din_prot                  ( w_dst.headerProt             )
          ,.dout                      ( /* Not Connected */          )
          ,.dout_prot                 ( /* Not Connected */          )
          ,.en                        ( 1'b1                         )
          ,.bypass                    ( 1'b0                         )
          ,.stall                     ( 1'b0                         )
          ,.stallout                  ( /* Not Connected */          )
          ,.valid_in                  ( w_dst.hv                     )
          ,.halt_out                  ( /* Not Connected */          )
          ,.valid_out                 ( /* Not Connected */          )
          ,.halt_in                   ( 1'b0                         )
          ,.ras_dp_err_inband_kbd_in  ( 1'b0                         )
          ,.ras_dp_err_inband_kbd_out ( /* Not Connected */          )
          ,.ras_dp_err_log            ( b_ras.w_ras_dp_err_log       )
            ,.ras_dp_err_inj          ( b_ras.w_ras_dp_err_inj       ) 
          );

        assign b_dst.w_header     = w_dst.header    ;
        assign b_dst.w_headerProt = w_dst.headerProt;
        

        assign b_dst.w_hv         = w_dst.hv        ;
        assign b_dst.w_data       = w_dst.data      ;
        assign b_dst.w_dv         = w_dst.dv        ;
        assign b_dst.w_eot        = w_dst.eot       ;

      end else begin : NO_RAS_CHK_GEN

        assign b_dst.w_header     = w_dst.header    ;
        assign b_dst.w_hv         = w_dst.hv        ;
        assign b_dst.w_data       = w_dst.data      ;
        assign b_dst.w_dv         = w_dst.dv        ;
        assign b_dst.w_eot        = w_dst.eot       ;
        assign b_dst.w_headerProt = w_dst.headerProt;

        always_comb begin : ras_proc
          b_ras.w_ras_dp_err_log = '0;
        end

      end
    end else begin : CONTROL_GEN
      assign w_src.header     = b_src.w_header;
      assign w_src.hv         = b_src.w_hv    ;
      assign w_src.data       = '0            ;
      assign w_src.dv         = '0            ;
      assign w_src.eot        = '0            ;
      //No header protection on non DATAPATH interfaces
      assign w_src.headerProt = '0            ;
      assign b_dst.w_header = w_dst.header;
      assign b_dst.w_hv     = w_dst.hv    ;
      always_comb begin : ras_proc
        b_ras.w_ras_dp_err_log = '0;
      end
    end
  endgenerate
 
  assign main_clk = b_clkrst.w_main_clk;
  assign rstn     = b_clkrst.w_reset_n;

  generate

    if (P_AUX_CLK) begin : AUX_CLK_GEN
      assign aux_clk = b_clkrst.w_aux_clk;
    end else begin : MAIN_CLK_GEN
      assign aux_clk = b_clkrst.w_main_clk;
    end

    if (P_TYPE == E_TLP_HEADER) begin : TLP_HEADER_GEN
      if (P_STAGES == E_FEED_ALL) begin : FEED_ALL_GEN

        assign w_dst.header     = w_src.header    ;
        assign w_dst.hv         = w_src.hv        ;
        assign w_dst.data       = w_src.data      ;
        assign w_dst.dv         = w_src.dv        ;
        assign w_dst.eot        = w_src.eot       ;
        assign w_dst.headerProt = w_src.headerProt;

      end else begin : NOT_FEED_INFO_GEN

        always_ff @(posedge aux_clk, negedge rstn) begin : r_head_PROC
          if (!rstn) begin
            w_dst.header     <= #`TP '0;
            w_dst.hv         <= #`TP '0;
            w_dst.data       <= #`TP '0;
            w_dst.dv         <= #`TP '0;
            w_dst.eot        <= #`TP '0;
              w_dst.headerProt <= #`TP '0;
          end else begin
            w_dst.header     <= #`TP w_src.header    ;
            w_dst.hv         <= #`TP w_src.hv        ;
            w_dst.data       <= #`TP w_src.data      ;
            w_dst.dv         <= #`TP w_src.dv        ;
            w_dst.eot        <= #`TP w_src.eot       ;
            w_dst.headerProt <= #`TP w_src.headerProt;
          end
        end

      end
    end else if (P_TYPE == E_TLP_BYPASS) begin : TLP_BYPASS_GEN
      if (P_STAGES == E_FEED_ALL) begin : FEED_ALL_GEN

        assign w_dst.header = w_src.header;
        assign w_dst.hv     = w_src.hv    ;
        assign w_dst.data   = w_src.data  ;
        assign w_dst.dv     = w_src.dv    ;
        assign w_dst.eot    = w_src.eot   ;
        assign w_dst.headerProt = w_src.headerProt;

      end else begin : NOT_FEED_INFO_GEN

        always_ff @(posedge aux_clk, negedge rstn) begin : r_head_PROC
          if (!rstn) begin
            w_dst.header     <= #`TP '0;
            w_dst.hv         <= #`TP '0;
            w_dst.data       <= #`TP '0;
            w_dst.dv         <= #`TP '0;
            w_dst.eot        <= #`TP '0;
            w_dst.headerProt <= # `TP '0;
          end else begin
            w_dst.header     <= #`TP w_src.header;
            w_dst.hv         <= #`TP w_src.hv    ;
            w_dst.data       <= #`TP w_src.data  ;
            w_dst.dv         <= #`TP w_src.dv    ;
            w_dst.eot        <= #`TP w_src.eot   ;
            w_dst.headerProt <= # `TP w_src.headerProt;
          end
        end

      end
    end else begin : TLP_FULL_GEN
      if (P_STAGES == E_FEED_ALL) begin : FEED_ALL_GEN

        assign w_dst.hv         = b_src.w_hv    ;
        assign w_dst.header     = b_src.w_header;
        assign w_dst.dv         = b_src.w_dv    ;
        assign w_dst.data       = b_src.w_data  ;
        assign w_dst.eot        = b_src.w_eot   ;
        assign b_src.w_halt     = b_dst.w_halt  ;
        assign w_dst.headerProt = b_src.w_headerProt;

      end else begin : NOT_FEED_INFO_GEN

        if (P_STAGES == E_FEED_HALT) begin : FEED_HALT_GEN

          always_ff @ (posedge aux_clk or negedge rstn) begin : FF_SEQ_PROC
            if (!rstn) begin
              w_dst.header     <= #`TP '0;
              w_dst.data       <= #`TP '0;
              w_dst.hv         <= #`TP '0;
              w_dst.dv         <= #`TP '0;
              w_dst.eot        <= #`TP '0;
              w_dst.headerProt <= #`TP '0;
            end else begin
              if (!((w_dst.hv || w_dst.dv) && b_src.w_halt)) begin
                w_dst.header     <= #`TP w_src.header    ;
                w_dst.data       <= #`TP w_src.data      ;
                w_dst.hv         <= #`TP w_src.hv        ;
                w_dst.dv         <= #`TP w_src.dv        ;
                w_dst.eot        <= #`TP w_src.eot       ;
                w_dst.headerProt <= #`TP w_src.headerProt;
              end
            end
          end

          assign b_src.w_halt = (b_dst.w_hv || b_dst.w_dv) && b_dst.w_halt;

        end else begin : FEED_NONE_GEN
          // ******************************************************************
          //
          // ******************************************************************
          localparam LP_RAM_DEPTH   = P_AUX_CLK ? 3+P_EXT_RAM_DEPTH :(
                                      P_STAGES == E_FEED_NONE ? 2 :(
                                      P_STAGES == E_FEED_HALT ? 1 : 0));      


          typedef logic [$bits(tlp_s)-1:0]         ram_data_t;
          typedef logic [$clog2(LP_RAM_DEPTH)-1:0] ram_addr_t;

          typedef struct packed {
            tlp_s      data_in;
            tlp_s      data_out;
            logic      wr_n;
            ram_addr_t wr_addr;
            ram_addr_t rd_addr; 
          } ram_st;

          typedef struct packed {
            ram_addr_t wr_addr;
            ram_addr_t rd_addr;
            ram_addr_t rd_addr_shdw;
            logic wr_full;
            logic rd_empty;
          } fifo_ctl_st;

          ram_st ram;
          fifo_ctl_st r_fifo_ctl, s_fifo_ctl;


          // Generates RAM like storage 
          DWC_pcie_ctl_bcm57
           # (
             .DATA_WIDTH ($bits(tlp_s)        )
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
          
          assign ram.data_in  = ram_data_t'(w_src);
          tlp_s w_ram_data_out_tlp;
          assign w_ram_data_out_tlp = tlp_s'(ram.data_out); 

          assign w_dst.data  = w_ram_data_out_tlp.data;
          assign w_dst.header= w_ram_data_out_tlp.header;
          assign w_dst.headerProt = w_ram_data_out_tlp.headerProt;

          assign w_dst.hv  = !r_fifo_ctl.rd_empty && w_ram_data_out_tlp.hv;
          assign w_dst.dv  = !r_fifo_ctl.rd_empty && w_ram_data_out_tlp.dv;
          assign w_dst.eot = !r_fifo_ctl.rd_empty && w_ram_data_out_tlp.eot;

          assign b_src.w_halt= r_fifo_ctl.wr_full;

          assign ram.wr_n    = !((w_src.hv || w_src.dv) && !r_fifo_ctl.wr_full);

          assign ram.wr_addr = r_fifo_ctl.wr_addr;
          // read address shadow mantains the output when empty, this preserves power
          assign ram.rd_addr = r_fifo_ctl.rd_empty ? r_fifo_ctl.rd_addr_shdw : r_fifo_ctl.rd_addr;


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
              r_fifo_ctl.rd_addr      <= # `TP '0;
              r_fifo_ctl.rd_addr_shdw <= # `TP '0;
              r_fifo_ctl.rd_empty     <= # `TP 1'b1;
            end else begin
              r_fifo_ctl.rd_addr      <= # `TP s_fifo_ctl.rd_addr;
              r_fifo_ctl.rd_addr_shdw <= # `TP s_fifo_ctl.rd_addr_shdw;
              r_fifo_ctl.rd_empty     <= # `TP s_fifo_ctl.rd_empty; 
            end
          end

          assign s_fifo_ctl.rd_addr_shdw = !r_fifo_ctl.rd_empty ? r_fifo_ctl.rd_addr : r_fifo_ctl.rd_addr_shdw;

          always_comb begin : PROC_CB_ctl_wr_addr
            s_fifo_ctl.wr_addr = r_fifo_ctl.wr_addr;

            if ((w_src.hv || w_src.dv) && !r_fifo_ctl.wr_full) begin
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
              if ((w_src.hv || w_src.dv) && !b_src.w_halt && s_fifo_ctl.wr_addr == r_fifo_ctl.rd_addr)
                s_fifo_ctl.wr_full = '1;

              // Can go zero scenario (read happens)
              if (s_fifo_ctl.wr_addr != r_fifo_ctl.rd_addr)
                s_fifo_ctl.wr_full = '0;

            end

          end else begin : NP_AUX_GEN

            always_comb begin : PROC_CB_ctl_wr_full
              s_fifo_ctl.wr_full = r_fifo_ctl.wr_full;

              // can go one scenario (write happens) - a simultaneous write read has null effect
              if ((w_src.hv || w_src.dv) && !b_src.w_halt && s_fifo_ctl.wr_addr == r_fifo_ctl.rd_addr)
                s_fifo_ctl.wr_full = '1;

              // Can go zero scenario (read happens)
              if ((w_dst.hv || w_dst.dv) && !b_dst.w_halt)
                s_fifo_ctl.wr_full = '0;

            end          
          end

          always_comb begin : PROC_CB_ctl_rd_addr
            s_fifo_ctl.rd_addr = r_fifo_ctl.rd_addr;

            // allow the rd pointer to advance when not empty
            if ( !b_dst.w_halt && !r_fifo_ctl.rd_empty) begin
              if (r_fifo_ctl.rd_addr < LP_RAM_DEPTH - 1)
                s_fifo_ctl.rd_addr = r_fifo_ctl.rd_addr + 1;
              else
                s_fifo_ctl.rd_addr = '0;
            end

          end

          always_comb begin : PROC_CB_ctl_rd_empty
            s_fifo_ctl.rd_empty = r_fifo_ctl.rd_empty;

            //reading into the same position as the write
            if ((w_dst.hv || w_dst.dv) && !b_dst.w_halt && (s_fifo_ctl.rd_addr == r_fifo_ctl.wr_addr || r_fifo_ctl.rd_addr == r_fifo_ctl.wr_addr))
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

          // ******************************************************************
          //
          // ****************************************************************** 

        end
      end
    end
  endgenerate


// SNPS_SysML_CODE_END

endmodule
