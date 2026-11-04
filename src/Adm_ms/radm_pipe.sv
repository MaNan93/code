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
// --   RCS information:
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_pipe.sv#3 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
//
// --- Module manages the ras functionality for the formation queue rams.
// --- It removes the data parity from input data qdw and adds the ECC protection for data going towards SRAM.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module  radm_pipe
  import DWC_pcie_core_pkg::QDW_DW;
  import DWC_pcie_core_pkg::QDW_PAR;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import radm_ms_pkg::NQW;
  import radm_ms_pkg::PKT_ORD_WD;
#(
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0,
  parameter RAM_WD            = 145, // bits (per qword) stored in RAM
  parameter RAM_WD_NO_ECC     = 145,
  parameter RAM_DP            = 256, // RAM depth: total hdr + Data credits divided by the number of RAMs
  parameter RAM_PW            = 8,    // the RAM address bit width
  parameter QDW_WRLINE_WD               = 137+PKT_ORD_WD+QDW_PAR,
  parameter QDW_WRLINE_NO_PARITY_WD     = 137+PKT_ORD_WD
)(
  input         [NQW-1:0][QDW_WRLINE_WD-1:0]                    int_ram_qdw_wline,           // write datapath lines to RAM included ctl bits plus parity bits for qdw
  input         [NQW-1:0][RAM_PW-1:0]                           current_ram_waddr,           // write address for the RAM
  input         [NQW-1:0]                                       ram_we,                      // write enable for the RAM 
  input         [NQW-1:0][RAM_PW-1:0]                           ram_raddr,                   // read address for the RAM
  input         [NQW-1:0]                                       ant_ram_pop,                 // read enable for the RAM 
 
  output logic  [NQW*RAM_PW-1:0]                                radm_formqram_addra,         // RAM write address
  output        [NQW-1:0]                                       radm_formqram_ena,           // RAM enable A
  output        [NQW-1:0]                                       radm_formqram_wea,           // RAM write enable A
  output logic  [NQW*RAM_WD-1:0]                                radm_formqram_dina,          // RAM write data A
  output        [NQW*RAM_PW-1:0]                                radm_formqram_addrb,         // RAM read address B
  output        [NQW-1:0]                                       radm_formqram_enb,           // RAM enable B
  input         [NQW*RAM_WD-1:0]                                formqram_radm_doutb,         // RAM read data B
  
  output logic  [NQW-1:0][QDW_WRLINE_WD-1:0]                    int_formqram_radm_doutb_rpipe,

  output ras_dp_err_log_t       [2-1:0]                         ras_dp_err_log,
  output logic                  [2-1:0]                         out_ras_dp_wake_up,
  input  ras_dp_err_inj_t                                       ras_dp_err_inj,
  input                                                         core_clk,                    // Core Clock input
  input                                                         core_rst_n                   // Core clock domain reset input
);

localparam RAM_PROT_RANGE    = `CX_RAS_RAM_PROT_RANGE;
localparam RAM_PROT_WD       = RAM_WD-RAM_WD_NO_ECC; 
localparam RAM_PROT_TYPE     = 0; //`CX_RAS_PROT_TYPE;
localparam RAM_PARITY_MODE   = 0;//`CX_RAS_PARITY_MODE;
localparam PROT_RANGE        = `CX_RAS_PROT_RANGE;
localparam PROT_TYPE         = `CX_RAS_PROT_TYPE;
localparam PROT_WD           = 128/PROT_RANGE; 
localparam PARITY_MODE       = `CX_RAS_PARITY_MODE;
localparam PROT_CORRECT_EN   = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;
localparam RADM_FORMQ_RAM_RD_LATENCY = `CX_RADM_FORMQ_RAM_RD_LATENCY;

//// Local wires and registers
logic  [NQW-1:0][QDW_WRLINE_WD-QDW_PAR-1:0]               int_ram_qdw_wline_no_parity;   //  write datapath lines to RAM included ctl bits 
logic  [NQW-1:0][QDW_WRLINE_WD-QDW_PAR-1:0]               int_radm_formqram_dina;        //  write datapath lines to RAM included ctl bits 
logic  [NQW-1:0][RAM_PROT_WD-1:0]                         int_radm_formqram_dina_prot;
logic  [NQW-1:0][RAM_PW-1:0]                              int_radm_formqram_addra;         // RAM write address
logic  [NQW-1:0][RAM_WD-1:0]                              int_formqram_radm_doutb;
logic  [NQW-1:0][QDW_WRLINE_NO_PARITY_WD-1:0]             formqram_radm_doutb_rpipe;
logic  [NQW-1:0][RAM_PW-1:0]                              unused_formqram_radm_addrb_rpipe;         // RAM read address
logic  [NQW-1:0][16-1:0]                                  qdw_parity_protection;   

 
// parity check module instance without pipeline
ras_dp_err_inj_t                        ras_dp_err_inj_ram_qdw_rline;
ras_dp_err_log_t       [NQW-1:0]        ras_dp_err_log_ram_qdw_rline;              // rasdp error log interface
 
generate
    for (genvar k = 0; k < NQW; k++)begin : g_pipe_chk_before_ram
            ras_dp_pipe
             #(
                .PIPELINE_TYPE           (0),             // No pipeline only checker instance
                .RESETVAL                (0),             // Reset value set to 0
                .N_STAGES                (0),             // No pipeline delay from module
                .CAN_STALL               (0),             // No stalling
                .RESET_STALL             (0),             // Stall reset value set to 0.
                .BUS_PROTECT_GEN_EN      (0),             // No generator
                .BUS_PROTECT_CHK_EN      (1),             // Checker enabled
                .PROT_TYPE               (PROT_TYPE),             // Parity check enabled
                .PROT_RANGE              (PROT_RANGE),    // cc
                .PROT_WD                 (PROT_WD),
                .PARITY_MODE             (PARITY_MODE),             // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),             // No correction
                .TOTAL_WIDTH             (128),           //  
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+k),
                .PIPE_RAS_DP_ERR_LOG     (1)
            ) u_ras_dp_pipe (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (ram_we[k]                  ),
                .din      (int_ram_qdw_wline[k][QDW_DW-1:0] ),
                .din_prot (int_ram_qdw_wline[k][QDW_DW+QDW_PAR-1:QDW_DW]),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(                   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  (ras_dp_err_log_ram_qdw_rline[k])
                ,
                .ras_dp_err_inj  (ras_dp_err_inj_ram_qdw_rline)
                );
    end
endgenerate

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N (NQW)
) u_ras_dp_err_mgr_ram_qdw_wline (
    .clk                (core_clk),
    .rst_n              (core_rst_n),
    .out_ras_dp_wake_up (out_ras_dp_wake_up[0]),
    .in_ras_dp_err_inj  (ras_dp_err_inj),
    .out_ras_dp_err_inj (ras_dp_err_inj_ram_qdw_rline),
    .in_ras_dp_err_log  (ras_dp_err_log_ram_qdw_rline),
    .out_ras_dp_err_log (ras_dp_err_log[0])
);



// qdw_wrline without parity bit inclusion.
always @(*) begin : ram_qdw_wline_enc_ctl_PROC1
    int v;
    for(v=0; v<NQW; v++) begin
        int_ram_qdw_wline_no_parity[v] = {int_ram_qdw_wline[v][QDW_WRLINE_WD-1:QDW_DW+QDW_PAR],int_ram_qdw_wline[v][QDW_DW-1:0]};  
    end
end

// ECC generate block
generate
    logic [NQW-1:0] stallout_write_unused;
    logic [NQW-1:0] halt_out_write_unused;
    for (genvar k = 0; k < NQW; k++)begin : g_pipe_to_ram
        // data path for ECRC generation 
        ras_dp_pipe
         #(
            .PIPELINE_TYPE           (6),             
            .RESETVAL                (0),             
            .N_STAGES                (1),             
            .CAN_STALL               (1),             
            .RESET_STALL             (0),             
            .BUS_PROTECT_GEN_EN      (1),             
            .BUS_PROTECT_CHK_EN      (0),             
            .PROT_TYPE               (RAM_PROT_TYPE), 
            .PROT_RANGE              (RAM_PROT_RANGE),
            .PROT_WD                 (RAM_PROT_WD),
            .PARITY_MODE             (RAM_PARITY_MODE), 
            .TOTAL_WIDTH             (QDW_WRLINE_WD - QDW_PAR + RAM_PW),            
            .EXCLUDE_PROT_WIDTH      (0),
            .RAS_DP_PROT_CHK_ID_BASE (0),
            .ADDR_ECC_PROT_EN        (1),
            .ADDR_LOG_EN             (1),
            .ADDR_INDEX              (QDW_WRLINE_WD-QDW_PAR),
            .ADDR_WD                 (RAM_PW)
        ) u_ras_dp_pipe (
            .clk                       (core_clk                                                    ),
            .rst_n                     (core_rst_n                                                  ),
            .en                        (ram_we[k]                                                   ),
            .bypass                    (1'b0                                                        ),
            .stall                     (1'b0                                                        ),
            .stallout                  (stallout_write_unused[k]                                    ),
            
            .valid_in                  (ram_we[k]                                                   ),
            .din                       ({      current_ram_waddr[k], int_ram_qdw_wline_no_parity[k]}),
            .din_prot                  ('0                                                          ),
            .halt_out                  (halt_out_write_unused[k]                                    ),
            
            .valid_out                 (radm_formqram_wea[k]                                        ),
            .dout                      ({int_radm_formqram_addra[k], int_radm_formqram_dina[k]}     ),
            .dout_prot                 (int_radm_formqram_dina_prot[k]                              ),
            .halt_in                   (1'b0                                                        ),
            
            .ras_dp_err_inband_kbd_in  (1'b0                                                        ),
            .ras_dp_err_inband_kbd_out (                                                            ),
            .ras_dp_err_log            (                                                            )
            ,
            .ras_dp_err_inj            ('0                                                          )
        );
    end
endgenerate

// assignment to the write ports of the RAMs.
always @(*) begin : ram_ff_qdw_wline_enc_ctl_PROC1
    int v;
    for(v=0; v<NQW; v++) begin
        radm_formqram_dina[v*RAM_WD +: RAM_WD] = { int_radm_formqram_dina_prot[v], int_radm_formqram_dina[v]}; 
        radm_formqram_addra[v*RAM_PW +: RAM_PW] = int_radm_formqram_addra[v];
   
    end
end
assign radm_formqram_ena = radm_formqram_wea;
//////////////////////////////////////////////
// Read block
assign radm_formqram_addrb = ram_raddr;
assign radm_formqram_enb = ant_ram_pop;


// converting input raw data to multidimentional array
always@(*) begin
  int i;
  for(i=0;i<NQW;i++)
    int_formqram_radm_doutb[i] = formqram_radm_doutb[RAM_WD*i +: RAM_WD];
end

logic  [NQW-1:0] radm_formqdata_valid;    

logic  [NQW-1:0][RAM_PW-1:0] int_formqram_radm_addrb;
generate
    for (genvar k = 0; k < NQW; k++)begin : g_pipe_delay_2
        delay_n_w_enable
         #(RADM_FORMQ_RAM_RD_LATENCY , RAM_PW) u_delay_n_write_addr_delay (
            .clk        (core_clk                               ),
            .rst_n      (core_rst_n                             ),
            .clear      (1'b0                                   ),
            .en         (radm_formqram_enb[k]                   ),
            .din        (radm_formqram_addrb[k*RAM_PW +: RAM_PW]),
            .dout       (int_formqram_radm_addrb[k]             ) 
        );
    end
endgenerate

// aligning the read signal with ram read latency for ECC check module.
delay_n
 #(RADM_FORMQ_RAM_RD_LATENCY , NQW) u_delay_n_ram_rd_latency
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (radm_formqram_enb),     
    .dout       (radm_formqdata_valid) 
);

// ECC checker block

ras_dp_err_inj_t                        ras_dp_err_inj_ram_rddata;
ras_dp_err_log_t       [NQW-1:0]        ras_dp_err_log_ram_rddata;              // rasdp error log interface

    ras_dp_err_mgr
     #(
           .BLOCK_RAS_DP_PROT_CHK_N         (NQW),
           .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1)
       ) u_ras_dp_err_mgr_ram_rddata (
           .clk                (core_clk),
           .rst_n              (core_rst_n),
           .out_ras_dp_wake_up (out_ras_dp_wake_up[1]),
           .in_ras_dp_err_inj  (ras_dp_err_inj),
           .out_ras_dp_err_inj (ras_dp_err_inj_ram_rddata),
           .in_ras_dp_err_log  (ras_dp_err_log_ram_rddata),
           .out_ras_dp_err_log (ras_dp_err_log[1])
       );


  generate
    logic [NQW-1:0]                  stallout_read_unused;
    logic [NQW-1:0][RAM_PROT_WD-1:0] dout_prot_read_unused;
    logic [NQW-1:0]                  halt_out_read_unused;
    logic [NQW-1:0]                  valid_out_read_unused;
    for (genvar k = 0; k < NQW; k++)begin : g_pipe_from_ram
        ras_dp_pipe
         #(
            .PIPELINE_TYPE           (6),             
            .RESETVAL                (0),             
            .N_STAGES                (1),             
            .CAN_STALL               (1),             
            .RESET_STALL             (0),             
            .BUS_PROTECT_GEN_EN      (0),             
            .BUS_PROTECT_CHK_EN      (1),             
            .PROT_TYPE               (RAM_PROT_TYPE), 
            .PROT_RANGE              (RAM_PROT_RANGE),
            .PROT_WD                 (RAM_PROT_WD),
            .PARITY_MODE             (RAM_PARITY_MODE),           
            .PROT_CORRECT_EN         (1),
            .TOTAL_WIDTH             (RAM_WD_NO_ECC + RAM_PW),            
            .EXCLUDE_PROT_WIDTH      (0),
            .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+1*NQW+k),
            .ADDR_ECC_PROT_EN        (1),
            .ADDR_LOG_EN             (1),
            .ADDR_INDEX              (RAM_WD_NO_ECC),
            .ADDR_WD                 (RAM_PW),
            .PIPE_RAS_DP_ERR_LOG     (1)
        ) u_ras_dp_pipe (
            .clk                       (core_clk                                                                            ),
            .rst_n                     (core_rst_n                                                                          ),
            .en                        (1'b1                                                                                ),
            .bypass                    (1'b0                                                                                ),
            .stall                     (1'b0                                                                                ),
            .stallout                  (stallout_read_unused[k]                                                             ),
            
            .valid_in                  (radm_formqdata_valid[k]                                                             ),
            .din                       ({         int_formqram_radm_addrb[k], int_formqram_radm_doutb[k][RAM_WD_NO_ECC-1:0]}),
            .din_prot                  (int_formqram_radm_doutb[k][RAM_WD-1:RAM_WD_NO_ECC]                                  ),
            .halt_out                  (halt_out_read_unused[k]                                                             ),
            
            .valid_out                 (valid_out_read_unused[k]                                                            ),
            .dout                      ({unused_formqram_radm_addrb_rpipe[k], formqram_radm_doutb_rpipe[k]}                 ),
            .dout_prot                 (dout_prot_read_unused[k]                                                            ),
            .halt_in                   (1'b0                                                                                ),
            
            .ras_dp_err_inband_kbd_in  (1'b0                                                                                ),
            .ras_dp_err_inband_kbd_out (                                                                                    )
            ,
            .ras_dp_err_log            (ras_dp_err_log_ram_rddata[k]                                                        )
            ,
            .ras_dp_err_inj            (ras_dp_err_inj_ram_rddata                                                           )
        );
   
    end
endgenerate


// parity generate module instance without pipe delay
generate
    for (genvar k = 0; k < NQW; k++)begin : g_pipe_after_ram
 
            ras_dp_pipe
             #(
                .PIPELINE_TYPE           (0),             // No pipeline only checker instance
                .RESETVAL                (0),             // Reset value set to 0
                .N_STAGES                (0),             // No pipeline delay from module
                .CAN_STALL               (0),             // No stalling
                .RESET_STALL             (0),             // Stall reset value set to 0.
                .BUS_PROTECT_GEN_EN      (1),             // No generator
                .BUS_PROTECT_CHK_EN      (0),             // Checker enabled
                .PROT_TYPE               (PROT_TYPE),             // Parity check enabled
                .PROT_RANGE              (PROT_RANGE),    // cc
                .PROT_WD                 (PROT_WD),
                .PARITY_MODE             (PARITY_MODE),             // cc
                .TOTAL_WIDTH             (128),           //  
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (0)
            ) u_ras_dp_pipe (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (1'b1               ),
                .din      (formqram_radm_doutb_rpipe[k][QDW_DW-1:0] ),
                .din_prot ('0                  ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(qdw_parity_protection[k]   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );
    end
endgenerate

// Adding parity following QDW data
always @(*) begin : ram_ff_qdw_wline_enc_ctl_PROC2
    int v;
    for(v=0; v<NQW; v++) begin
      int_formqram_radm_doutb_rpipe[v] = {formqram_radm_doutb_rpipe[v][QDW_WRLINE_NO_PARITY_WD-1:QDW_DW], qdw_parity_protection[v], formqram_radm_doutb_rpipe[v][QDW_DW-1:0] };
    end
end

endmodule

