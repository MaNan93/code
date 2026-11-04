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
// ---    $DateTime: 2023/12/07 19:23:06 $
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_formation_queue_ms.sv#11 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// - Stored received TLPs inside the External RAMs.
// - Removes Errored TLPs from the RAM in case full TLP available within a RAM.
// - Manages prefix qdw removal from the RAM.
// - Read TLP QDWs from external RAM an stores them inside internal reg array.
// - Read TLP from register array in sequence one by one.
// - Place read TLP header and data on separate interfaces.
// - Retunrs header and data credits once TLP leaves the queue.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

 module radm_formation_queue_ms
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NW;
  import DWC_pcie_ctl_pkg::DW;
  import DWC_pcie_ctl_pkg::DCA_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  
  import DWC_pcie_core_pkg::RX_NQDW;
  import DWC_pcie_core_pkg::QDW_DW;
  import DWC_pcie_core_pkg::QDW_PAR;
  import radm_ms_pkg::radm_form_s;
  import radm_ms_pkg::calc_tlp_data_len;
  import radm_ms_pkg::NQW;
  import radm_ms_pkg::NQW_R;
  import radm_ms_pkg::HW;
  import radm_ms_pkg::NHW;
  import radm_ms_pkg::RADM_HDR_PROT_WD;
  import radm_ms_pkg::PKT_ORD_WD;
#(
  parameter DATA_PROT_WD      = `TRGT_DATA_PROT_WD,
  parameter FORMQ_RD_PORTS    = `CX_RADM_FORMQ_N_READ_PORT_VC,
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0,
  parameter RAM_WD            = `RAM_WD_VC0_P,  // bits (per qword) stored in RAM including parity
  parameter RAM_WD_NO_ECC     = `RAM_WD_VC0_P_NO_ECC,
  parameter RAM_DP            = `RAM_DP_VC0_P,  // RAM depth: total hdr + Data credits divided by the number of RAMs
  parameter RAM_PW            = `RAM_PW_VC0_P   // the RAM address bit width
)

                                 (
  //--------------------- inputs --------------------------------------------
  input   [RX_NQDW-1:0][QDW_DW+QDW_PAR-1:0]               hdec_form_nqdw_data,         // Generic data qdword (prefix/hdr/payload) of TLP packet
  input   [RX_NQDW-1:0][4-1:0]                            hdec_form_nqdw_ddwen,        // Dword enable for data dws
  input   [RX_NQDW-1:0][4-1:0]                            hdec_form_nqdw_hdwen,        // Dword enable for header dws(including prefixes)
  input   [RX_NQDW-1:0]                                   hdec_form_nqdw_hv,           // Header valid for qdword
  input   [RX_NQDW-1:0]                                   hdec_form_nqdw_dv,           // Data valid for qdword
  input   [RX_NQDW-1:0]                                   hdec_form_nqdw_eot,          // End of TLP indication
  input   [RX_NQDW-1:0]                                   hdec_form_nqdw_dllp_err,     // TLP End with dllp error.
  input   [RX_NQDW-1:0]                                   hdec_form_nqdw_fm_poisoned,  // TLP end with poisoned flit marker.
  input   [RX_NQDW-1:0]                                   hdec_form_nqdw_fm_nullified, // TLP end with nullified flit marker.
  input   [RX_NQDW-1:0][PKT_ORD_WD-1:0]                   hdec_form_p_pkt_order_num,   // P TLP packet order number     
  input   [RX_NQDW-1:0]                                   hdec_form_prefix_qdw,        // prefix only QDW 
  input                                                   hdec_form_discard_prefixes,  // Discard prefixes from queue. 
  input   [RX_NQDW-1:0]                                   hdec_form_mac_ecrc_qdw,      // mac/pcrc or ECRC only QDW.  
  //----------------------outputs -------------------------------------------
  // Dual port memory interface signals
  output  [NQW*RAM_PW-1:0]                                radm_formqram_addra,         // RAM write address
  output  [NQW-1:0]                                       radm_formqram_ena,           // RAM enable A
  output  [NQW-1:0]                                       radm_formqram_wea,           // RAM write enable A
  output  [NQW*RAM_WD-1:0]                                radm_formqram_dina,          // RAM write data A
  output  [NQW*RAM_PW-1:0]                                radm_formqram_addrb,         // RAM read address B
  output  [NQW-1:0]                                       radm_formqram_enb,           // RAM enable B
  input   [NQW*RAM_WD-1:0]                                formqram_radm_doutb,         // RAM read data B
  //----------------------filter interface signals---------------------------
  output  radm_form_s [FORMQ_RD_PORTS-1:0]                rxq_tlp,                     // FormationQ output TLP interface
  input                                                   filt_form_halt_en,           // formq halt signal
  input                                                   dllp_error_pkt_drop_en,
  //---------------------- Credit release interface signals ------------------
  output  logic [FORMQ_RD_PORTS-1:0]                      radm_rtlh_h_ca,              // Header credit allocated.
  output     [DCA_WD-1:0]                                 radm_rtlh_d_ca,              // Data Credit allocated
  output logic                                            radm_formq_overflow_ms,
  output ras_dp_err_log_t       [3-1:0]                   ras_dp_err_log,              // rasdp error log interface
  output logic                  [3-1:0]                   out_ras_dp_wake_up,
  input  ras_dp_err_inj_t                                 ras_dp_err_inj,              // rasdp error injection
  // ---- inputs (always present) ---------------
  input                                                   flit_mode_en,                // Flit mode operation enable
  input                                                   radm_clk_ug,                 // ungated clock input  
  input                                                   core_clk,                    // Core Clock input
  input                                                   core_rst_n                   // Core clock domain reset input
);
/////////////////////////////////////////////////////////////////////
// Local parameters
/////////////////////////////////////////////////////////////////////
localparam RAM_WPIPE_DP              = `CX_RADM_FORMQ_WR_REGOUT;      // ram write datapath pipe depth
localparam RAM_RPIPE_DP              = `CX_RADM_FORMQ_RD_REGOUT;      // ram read datapath pipe depth
localparam RADM_FORMQ_RAM_RD_LATENCY = `CX_RADM_FORMQ_RAM_RD_LATENCY;
localparam RAM_IW                    = `CX_LOGBASE2(NQW);             // the RAM qw index bit width

localparam HDR_DS                    = `CX_RADM_FORMQ_HDR_DS;         // header-bus data size, including parity bits: 128b + parity bits
localparam DATA_DS                   = `CX_RADM_FORMQ_DATA_DS;        // data-bus data size for one qdword of datapath, including parity bits: 128b + parity bits
localparam QW_DS                     = `CX_RADM_FORMQ_QDW_DS;         // the greater number between header and data datasizes
localparam REG_ARRAY_DP              = 4*NQW;
localparam REG_ARRAY_PTR_WD          = `CX_LOGBASE2(REG_ARRAY_DP);
localparam N_DATA_QDW                = ((NW==32) ? 8 : (NW==16)? 4 : (NW==8)? 2 : 1); // Number of 128-bit quad-dwords data read

localparam QDW_WRLINE_WD           = 137+ 2 + PKT_ORD_WD+QDW_PAR;       // total databits written per memory location with parity bits.
localparam QDW_WRLINE_NO_PARITY_WD = 137+ 2 + PKT_ORD_WD;               // total databits written per memory location without parity bits.
localparam RAM_RD_WR_WD            = (NW >= 16) ? RAM_IW : RAM_IW+1;                                      // bit width for the maximum QDW read and write inside the RAM
localparam REG_ARRAY_RD_WD         = `CX_LOGBASE2(NQW_R+1);                                                 // bit width for register based array access.
localparam FLIT_PREFIX             = 3'b100;    
localparam PRF_QDW                 = (NW >= 8) ? 2 : 1; 

localparam DWEN_POS                = QDW_DW+QDW_PAR;               
localparam HWEN_POS                = DWEN_POS + 2;                 
localparam ERR_POS                 = HWEN_POS + 2;                 
localparam MAC_ECRC_POS            = ERR_POS + 1;
localparam NULLIFIED_POS           = MAC_ECRC_POS  + 1;                 
localparam POISONED_POS            = NULLIFIED_POS + 1;
localparam P_PKT_POS               = POISONED_POS + 1;   
localparam HV_POS                  = P_PKT_POS + PKT_ORD_WD;        
localparam DV_POS                  = HV_POS + 1;                 
localparam EOT_POS                 = DV_POS + 1 ;                
localparam RAM_PROT_WD             = RAM_WD - QDW_WRLINE_NO_PARITY_WD;
localparam PROT_RANGE              = `CX_RAS_PROT_RANGE;
localparam PROT_TYPE               = `CX_RAS_PROT_TYPE;
localparam PROT_WD                 = 128/PROT_RANGE; 
localparam PARITY_MODE             = `CX_RAS_PARITY_MODE;
localparam PROT_CORRECT_EN         = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;

localparam QDW_CTRL_BITS           = 3;
localparam QDW_DATA_BITS           = QDW_WRLINE_WD-QDW_CTRL_BITS;
localparam RAM_REG_DEPTH_DIFF = RAM_PW+RAM_IW > REG_ARRAY_PTR_WD ? RAM_PW+RAM_IW - REG_ARRAY_PTR_WD + 1 : 1;
localparam RAM_REG_DEPTH_DIFF_RAM = RAM_PW+RAM_IW < REG_ARRAY_PTR_WD ? REG_ARRAY_PTR_WD - RAM_PW+RAM_IW + 1 : 1;
localparam BUCKET_SIZE            = 13;               // The size of the credit buckets.
localparam INT_WD                 = `CX_LOGBASE2(FORMQ_RD_PORTS);                                      // bit width for interface access.

localparam  P0  = 0; // Port 0 - this will become an actual index when MultiPort will be supported
// 512 NQW = 7, others power of 2
// localparam HALF_FOR = NQW/2 `ifdef ARC_512 - NQW/2 + 4 `endif ;
localparam RADM_PIPE_DELAY = `CX_RADM_FORMATION_QUEUE_WR_PIPE_EN ; //  = (@CX_MULTISTREAM_ARCH && (@CX_NW==32) && (@CX_MAX_CORECLK_FREQ>500)) 
//////////////////////////////////////////////////////////////
// Local wires and registers
/////////////////////////////////////////////////////////////
// Output signals which will get packed into the output struct rxq_tlp
logic [FORMQ_RD_PORTS-1:0]                            form_filt_hv;                // Header Valid out
logic [FORMQ_RD_PORTS-1:0][(HW+RADM_HDR_PROT_WD)-1:0] form_filt_hdr;               // Header out
logic [FORMQ_RD_PORTS-1:0][`CX_NPRFX-1:0]    [31:0]   form_filt_prfx;
logic [FORMQ_RD_PORTS-1:0][`CX_RX_HDW_MS-1:0][31:0]   form_filt_header;
logic [FORMQ_RD_PORTS-1:0][`CX_RX_HDW_MS-1:0]         form_filt_header_dwen;
logic [FORMQ_RD_PORTS-1:0]                            form_filt_dv;                // Data Valid out
logic [FORMQ_RD_PORTS-1:0][(DW+DATA_PROT_WD)-1:0]     form_filt_data;              // Data out
logic [FORMQ_RD_PORTS-1:0]                            form_filt_eot;               // End of TLP
logic [FORMQ_RD_PORTS-1:0][NW-1:0]                    form_filt_ddwen;             // Data Bus DW Enable
logic [FORMQ_RD_PORTS-1:0][NHW-1:0]                   form_filt_hdwen;             // Header Bus DW Enable
logic [FORMQ_RD_PORTS-1:0]                            form_filt_dllp_err;          // TLP with dllp error.
logic [FORMQ_RD_PORTS-1:0][QDW_DW+QDW_PAR-1:0]        form_filt_mac_data;          // mac data interface
logic [FORMQ_RD_PORTS-1:0][2:0]                       form_filt_mac_size;          // mac data interface dw size.   
logic [FORMQ_RD_PORTS-1:0]                            form_filt_poisoned;          // poisoned out
logic [FORMQ_RD_PORTS-1:0][PKT_ORD_WD-1:0]            form_flit_p_pkt_num;         // P TLP packet number 
logic [FORMQ_RD_PORTS-1:0][10:0]                      form_filt_hdr_data_length;   // Data Length
logic [FORMQ_RD_PORTS-1:0]                            radm_formq_not_empty;        // radm not empty indication 

logic  [PRF_QDW-1:0]                                 prefix_qdw_count,prefix_qdw_count_r;                // prefix qdw count  
logic  [RAM_PW+RAM_IW:0]                             ram_occupancy;
logic  [RAM_PW+RAM_IW:0]                             ram_available;
logic  [RX_NQDW-1:0][QDW_WRLINE_WD-1:0]              int_rtlh_radm_qdw_wline;                            // concatenated qdw line with data and control bits
logic  [NQW-1:0][QDW_WRLINE_WD-1:0]                  pkd_input_qdw_wline;                                // Packed input qdw line
logic  [RAM_RD_WR_WD-1:0]                            pkd_input_wsize;                                    // the number of valid qdw in current cycle.
logic  [RAM_RD_WR_WD-1:0]                            pkd_input_wsize_int;
logic  [RAM_RD_WR_WD-1:0]                            pkd_input_wsize_till_valid_eot,pkd_input_wsize_till_valid_eot_r;      
logic  [RAM_RD_WR_WD-1:0]                            pkd_input_wsize_till_errored_eot,pkd_input_wsize_till_errored_eot_r;    
logic  [NQW-1:0][QDW_WRLINE_WD-1:0]                  input_qdw_wline;                                    // registerd packed qdw line information
logic  [RAM_RD_WR_WD-1:0]                            input_wsize,input_wsize_r,input_wsize_r1;                          // registered packed qdw line count
logic  [NQW-1:0][QDW_WRLINE_WD-1:0]                  int_ram_qdw_wline;                                  // write datapath lines to RAM+FF, included ctl bits
logic  [RAM_PW+RAM_IW-1:0]                           ram_raddrx;                                         // extended address, concatenated per-qdword
logic  [NQW-1:0]                                     next_ram_pop;                             // pop command for the indivudual RAMs
logic  [NQW_R:0]                                     acc_eot, acc_dv, acc_hv,acc_mac; 
logic  [NQW_R:0][1:0]                                acc_data_dws;
logic  [NQW_R:0]                                     acc_eot_int, acc_dv_int, acc_hv_int,acc_mac_int; 
logic  [NQW_R:0][1:0]                                acc_data_dws_int;
logic  [RAM_IW-1:0]                                  ram_rindex, next_ram_rindex,ram_rindex_d;
logic  [NQW-1:0][RAM_PW-1:0]                         ram_raddr, next_ram_raddr;
logic  [RAM_PW+RAM_IW-1:0]                           next_ram_raddrx; // extended address, concatenated per-qdword
logic  [NQW-1:0]                                     ant_ram_pop, next_ant_ram_pop; // pop command for the individual RAMs, used to enable the read command
logic  [RAM_IW-1:0]                                  ram_windex, next_ram_windex;
logic  [RAM_PW+RAM_IW-1:0]                           next_ram_waddrx,  int_ram_waddrx; // extended address, concatenated per-qdword
logic  [NQW-1:0]                                     ram_we;
logic  [NQW*RAM_PW-1:0]                              raw_next_ram_raddr  [NQW:0];
logic  [NQW-1:0]                                     raw_next_ram_pop    [NQW:0];
logic  [RAM_IW-1:0]                                  raw_next_ram_rindex [NQW:0];
logic  [RAM_PW+RAM_IW-1:0]                           raw_next_ram_raddrx [NQW:0];
logic  [RAM_IW-1:0]                                  raw_rindex [NQW-1:0][NQW-1:0];
logic  [NQW-1:0]                                     raw_ant_ram_pop        [NQW:0];
logic  [RAM_RD_WR_WD-1:0]                            next_ram_load_rsize,ram_load_rsize_d; 
logic  [RAM_IW-1:0]                                  int_ram_rindex_d; // delayed version to match extra pipeline stages
logic  [RAM_RD_WR_WD-1:0]                            int_ram_load_rsize; 
logic  [REG_ARRAY_PTR_WD-1:0]                        read_in_pipeline;
logic  [REG_ARRAY_DP-1:0][QDW_WRLINE_WD-1:0]         qdw_reg_array;
logic  [REG_ARRAY_PTR_WD-1:0]                        reg_array_wrptr;
logic  [REG_ARRAY_PTR_WD-1:0]                        reg_array_rdptr;
logic  [REG_ARRAY_PTR_WD:0]                          qdw_reg_array_occupancy;
logic  [REG_ARRAY_PTR_WD:0]                          qdw_reg_array_occupancy_actual;
logic  [REG_ARRAY_PTR_WD:0]                          effective_reg_array_wrptr;
logic  [REG_ARRAY_PTR_WD:0]                          qdw_reg_array_avail_space;
logic  [REG_ARRAY_RD_WD-1:0]                         next_load_rsize; // the number of qwords loaded from RAM into the read accumulation register. RAM_IW bits to accomodate max qwords  
logic  [REG_ARRAY_PTR_WD-1:0]                        reg_array_rdindex;
logic  [FORMQ_RD_PORTS-1:0][NQW_R-1:0]               interface_mask;
logic  [FORMQ_RD_PORTS-1:0]                          eot_count;  
logic  [FORMQ_RD_PORTS-1:0][3:0]                     dv_count;
logic  [NQW_R-1:0][QDW_WRLINE_WD-1:0]                acc_qdw_rline;   // accumulated qwords from a read operation
logic  [FORMQ_RD_PORTS-1:0] [127:0]                  extra_qdw_rd_data;
logic  [FORMQ_RD_PORTS-1:0] [15:0]                   extra_qdw_rd_data_parity;
logic  [FORMQ_RD_PORTS-1:0] [3:0]                    extra_qdw_rd_data_dwen;
logic  [FORMQ_RD_PORTS-1:0] [1:0]                    extra_qdw_rd_data_start;

logic  [FORMQ_RD_PORTS-1:0]                          extra_qdw_rd_data_eot;
logic  [FORMQ_RD_PORTS-1:0]                          extra_qdw_rd_data_dllp_err;
logic  [FORMQ_RD_PORTS-1:0]                          extra_qdw_rd_enable;
logic  [FORMQ_RD_PORTS-1:0]                          fm_poisoned_with_overreaddata;
logic  [FORMQ_RD_PORTS-1:0]                          fm_nullified_with_overreaddata;
logic  [FORMQ_RD_PORTS-1:0][PKT_ORD_WD-1:0]          next_form_flit_p_pkt_num;
logic  [FORMQ_RD_PORTS-1:0]                          next_form_filt_hv;
logic  [FORMQ_RD_PORTS-1:0][(HW+RADM_HDR_PROT_WD)-1:0] next_form_filt_hdr;
logic  [FORMQ_RD_PORTS-1:0][`CX_NPRFX-1:0]    [31:0] next_form_filt_prfx;
logic  [FORMQ_RD_PORTS-1:0][`CX_RX_HDW_MS-1:0][31:0] next_form_filt_header;
logic  [FORMQ_RD_PORTS-1:0][`CX_RX_HDW_MS-1:0]       next_form_filt_header_dwen;
logic  [FORMQ_RD_PORTS-1:0]                          next_form_filt_tlp_err; // TODO: needs to be connected (not done yet to keep formal eq).
logic  [FORMQ_RD_PORTS-1:0]                          next_form_filt_dv;
logic  [FORMQ_RD_PORTS-1:0][(DW+DATA_PROT_WD)-1:0]   next_form_filt_data;
logic  [FORMQ_RD_PORTS-1:0]                          next_form_filt_eot;
logic  [FORMQ_RD_PORTS-1:0][NW-1:0]                  next_form_filt_dwen;
logic  [FORMQ_RD_PORTS-1:0][NHW:0]                   next_form_filt_hdwen;
logic  [FORMQ_RD_PORTS-1:0]                          next_form_filt_dllp_err;
logic  [FORMQ_RD_PORTS-1:0]                          next_form_filt_poisoned;
logic  [FORMQ_RD_PORTS-1:0]                          next_form_filt_nullified;
logic  [FORMQ_RD_PORTS-1:0]                          form_filt_nullified;
logic  [REG_ARRAY_RD_WD-1:0]                         int_load_rsize_updated; 
logic  [FORMQ_RD_PORTS-1:0][NQW_R-1:0]               int_interface_mask_delay;
logic  [FORMQ_RD_PORTS-1:0][1:0]                     header_dws_within_qdw;
logic  [FORMQ_RD_PORTS-1:0]                          int_next_form_filt_dv;
logic  [FORMQ_RD_PORTS-1:0][((DW)-1)+128:0]          int_next_form_filt_data;
logic  [FORMQ_RD_PORTS-1:0][(NW-1)+4:0]              int_next_form_filt_dwen;
logic  [FORMQ_RD_PORTS-1:0][((DW)-1)+128:0]          int_next_form_filt_data_packed;
logic  [FORMQ_RD_PORTS-1:0][(NW-1)+4:0]              int_next_form_filt_dwen_packed;
logic  [FORMQ_RD_PORTS-1:0]                          eot_in_current_clock;
logic  [FORMQ_RD_PORTS-1:0]                          dllp_err_in_current_clock;
logic  [FORMQ_RD_PORTS-1:0]                          fm_poisoned_in_current_clock;
logic  [FORMQ_RD_PORTS-1:0]                          fm_nullified_in_current_clock;
logic  [FORMQ_RD_PORTS-1:0][1:0]                     data_dw_start_in_extra_qdw;
logic  [FORMQ_RD_PORTS-1:0]                          form_filt_hv_int;
logic  [FORMQ_RD_PORTS-1:0]                          form_filt_dv_int;
logic  [FORMQ_RD_PORTS-1:0]                          form_filt_eot_int;
logic  [NQW-1:0][RAM_PW-1:0]                         current_ram_waddr;
logic  [NQW-1:0][RAM_PW-1:0]                         current_ram_waddr_r;
logic  [RAM_PW+RAM_IW-1:0]                           ram_waddrx_without_prf;
logic  [RAM_IW-1:0]                                  ram_windex_without_prf, next_ram_windex_without_prf;
logic  [RAM_PW+RAM_IW-1:0]                           next_ram_waddrx_without_prf,  int_ram_waddrx_without_prf,int1_ram_waddrx_without_prf; // extended address, concatenated per-qdword
logic  [NQW-1:0][RAM_PW-1:0]                         current_ram_waddr_without_prf;
logic  [NQW-1:0][RAM_PW-1:0]                         current_ram_waddr_r_without_prf;
logic  [RAM_IW-1:0]                                  ram_windex_with_valid_eot, next_ram_windex_with_valid_eot;
logic  [RAM_PW+RAM_IW-1:0]                           next_ram_waddrx_with_valid_eot,  int_ram_waddrx_with_valid_eot; // extended address, concatenated per-qdword
logic  [NQW-1:0][RAM_PW-1:0]                         current_ram_waddr_with_valid_eot;
logic  [NQW-1:0][RAM_PW-1:0]                         current_ram_waddr_r_with_valid_eot;
logic  [RAM_RD_WR_WD-1:0]                            valid_qdw_start;
logic  [RAM_PW+RAM_IW+1:0]                           tlp_qdw_counts; // Size is kept same as ram space. 
logic  [NQW-1:0][QDW_DATA_BITS-1:0]                  pkd_input_qdw_wline_data;   
logic  [NQW-1:0][QDW_CTRL_BITS-1:0]                  pkd_input_qdw_wline_ctrl;   
logic  [NQW-1:0][QDW_DATA_BITS-1:0]                  input_qdw_wline_data;   
logic  [NQW-1:0][QDW_CTRL_BITS-1:0]                  input_qdw_wline_ctrl;   
logic  [NQW-1:0][QDW_WRLINE_WD-1:0]                  int_formqram_radm_doutb_rpipe, int_formqram_radm_doutb_rpipe_r;
logic  [RAM_REG_DEPTH_DIFF-1:0]                      Padded_bits;
logic  [RAM_REG_DEPTH_DIFF_RAM-1:0]                  Padded_bits_ram_occupancy;
logic  [NQW_R-1:0][QDW_WRLINE_WD-1:0]                qdw_reg_array_read;
logic  [FORMQ_RD_PORTS-1:0][NQW_R-1:0]               interface_mask_delay;
logic  [REG_ARRAY_RD_WD-1:0]                         next_load_rsize_delay; 
logic  [NQW_R-1:0]                                   mac_qdw_read_en;
logic  [NQW_R-1:0]                                   mac_qdw_read_en_r;
logic  [FORMQ_RD_PORTS-1:0][5:0]                     data_dw_count;  
logic  [FORMQ_RD_PORTS-1:0][5:0]                     data_dw_count_latched;  
logic  [FORMQ_RD_PORTS-1:0][5:0]                     data_dw_total_count;  
logic  [INT_WD-1:0]                                  interface_no_with_overread;
logic  [FORMQ_RD_PORTS-1:0][(((NW/4)+1)*16-1):0]     int_next_form_filt_data_parity;
logic  [FORMQ_RD_PORTS-1:0][(((NW/4)+1)*16-1):0]     int_next_form_filt_data_parity_packed;
logic  [FORMQ_RD_PORTS-1:0][(DW)-1:0]                next_form_filt_data_only;
logic  [FORMQ_RD_PORTS-1:0][QDW_DW-1:0]              next_form_filt_mac_data_int;  
logic  [FORMQ_RD_PORTS-1:0][QDW_DW+QDW_PAR-1:0]      next_form_filt_mac_data;    
logic  [FORMQ_RD_PORTS-1:0][2:0]                     next_form_filt_mac_size;         
logic  [FORMQ_RD_PORTS-1:0]                          int_form_filt_dllp_err;
logic  [FORMQ_RD_PORTS-1:0][2:0]                     hdr_prefix_counts;
logic  [BUCKET_SIZE:0]                               avail_data_crd;
logic  [FORMQ_RD_PORTS-1:0][31:0]                    hdr_dw1;
logic  [BUCKET_SIZE-1:0]                             data_credits_consumed;  
logic                                                discard_prefix_qdw_count;        // discard prefix qdws
logic                                                qdw_reg_array_almost_full;
logic                                                discard_previous_tlp;
logic                                                merged_qdw_read;   
logic                                                block_data_read;   
logic                                                qdw_read_blocked;   
logic                                                tlp_end_with_dllp_err;
logic                                                tlp_end_with_dllp_err_r;
logic                                                discard_errored_tlp , discard_errored_tlp_r;
logic                                                radm_formq_full;
logic                                                merged_qdw_read_r;
logic                                                form_filt_reg_en;
logic  [FORMQ_RD_PORTS-1:0]                          form_filt_hdr_reg_en;
logic                                                update_credit_bucket;
logic                                                interface_sel;
logic                                                tlp_read_over;

/////////////////////////////////////////
// prefix QDW management
//
/////////////////////////////////////////
// Counting prefix qdw written inside the ram
always_comb begin  
  prefix_qdw_count =  0;
  for(int i=0;i<RX_NQDW;i++) begin
    if(hdec_form_nqdw_hv[i] & hdec_form_prefix_qdw[i])
      prefix_qdw_count =  prefix_qdw_count + 1;
    else
      if(hdec_form_nqdw_hv[i]) 
        prefix_qdw_count =  0;
  end // for loop
end // always end

// Latching the prefix qdw count values.
always @(posedge core_clk or negedge core_rst_n) begin 
  if(!core_rst_n) begin
    prefix_qdw_count_r <= #TP 0;
  end else begin
    if(prefix_qdw_count != 0)
      prefix_qdw_count_r <= #TP prefix_qdw_count;
    else
      if(hdec_form_discard_prefixes || (|hdec_form_nqdw_hv))
        prefix_qdw_count_r <= #TP 0;
  end // else end
end // always end
// Generating discard prefix condition for queue.
always @(posedge core_clk or negedge core_rst_n) begin 
  if(!core_rst_n) begin
    discard_prefix_qdw_count <= #TP 0;
  end else begin
    discard_prefix_qdw_count <= #TP hdec_form_discard_prefixes && (|prefix_qdw_count_r);
  end
end 
////////////////////////////////////////
// ram status check logic 
//
//////////////////////////////////////// 
// check for RAM occupancy level.
assign ram_occupancy = (ram_waddrx_without_prf > ram_raddrx) ? {1'b0, (ram_waddrx_without_prf - ram_raddrx)} :
                       (ram_waddrx_without_prf < ram_raddrx) ? (RAM_DP*NQW - {1'b0, (ram_raddrx - ram_waddrx_without_prf)}) : 0;

assign ram_available   = RAM_DP*NQW - ram_occupancy - (RADM_PIPE_DELAY == 1 ? input_wsize_r1 : '0) -input_wsize_r - input_wsize - 1'b1;
assign radm_formq_full = (ram_available == '0);

// queue not empty logic
always @(posedge core_clk or negedge core_rst_n) begin 
  if(!core_rst_n) begin
    radm_formq_not_empty <= #TP 1'b0;
  end else begin
    radm_formq_not_empty <= #TP (|pkd_input_wsize) || (|input_wsize) || (|input_wsize_r) || (|input_wsize_r1) ||
                                (ram_occupancy != 0) || (qdw_reg_array_occupancy != 0) || 
                                |(form_filt_hv | form_filt_dv | next_form_filt_hv | next_form_filt_dv | next_form_filt_hv | next_form_filt_dv);  
  end // else end
end // always end

assign pkd_input_wsize_int = radm_formq_full ? '0 : ( !(|ram_available[RAM_PW+RAM_IW:RAM_RD_WR_WD]) && (pkd_input_wsize > ram_available[RAM_RD_WR_WD-1:0]) ) ? ram_available[RAM_RD_WR_WD-1:0] : pkd_input_wsize;

// queue overflow logic
always @(posedge core_clk or negedge core_rst_n) begin 
  if(!core_rst_n) begin
    radm_formq_overflow_ms <= #TP 1'b0;
  end else begin
    if(pkd_input_wsize != '0)
      radm_formq_overflow_ms <= #TP (ram_available == '0) || ( !(|ram_available[RAM_PW+RAM_IW:RAM_RD_WR_WD]) && (pkd_input_wsize > ram_available[RAM_RD_WR_WD-1:0]) ) ;
  end // else end
end // always end
///////////////////////////////////////////////////
// preparing the write line for the memory write.
//
///////////////////////////////////////////////////
always_comb begin : assemble_qdw_wline_PROC
    for(int i=0; i<RX_NQDW; i++) begin
        int_rtlh_radm_qdw_wline[i]  = {
                                      hdec_form_nqdw_eot[i], hdec_form_nqdw_dv[i], hdec_form_nqdw_hv[i],
                                      hdec_form_p_pkt_order_num[i],
                                      hdec_form_nqdw_fm_poisoned[i],  // Indicates last tlp ends with poisoned flit marker
                                      hdec_form_nqdw_fm_nullified[i], // Indicates last tlp ends with nullified flit marker
                                      hdec_form_mac_ecrc_qdw[i],
                                      hdec_form_nqdw_dllp_err[i],
                                      header_dw_count(hdec_form_nqdw_hdwen[i][4-1:0]), 
                                      data_dw_counts(hdec_form_nqdw_ddwen[i][4-1:0]), 
                                      hdec_form_nqdw_data[i][QDW_DW+QDW_PAR-1:0]
                                      };

    end
end

////////////////////////////////////////////////////
// logic to decide errored TLP drop within queue.
//
////////////////////////////////////////////////////
logic  [RAM_PW+RAM_IW+1:0]                           tlp_qdw_counts_int;   

always_comb begin :tlp_qdw_counts_PROC
   tlp_qdw_counts_int = tlp_qdw_counts;
   for(int i = 0; i< RX_NQDW ; i++) begin
     if(int_rtlh_radm_qdw_wline[i][EOT_POS])
        tlp_qdw_counts_int = 4*RX_NQDW;                  // We need thresold value before the actual tlp comparision with ram occupancy because of pipeline stage delays. Taken on safer side 1 extra value now.
     else
       if(int_rtlh_radm_qdw_wline[i][HV_POS] || int_rtlh_radm_qdw_wline[i][DV_POS])
        tlp_qdw_counts_int = tlp_qdw_counts_int + 1'b1;
   end  
end    
// latching TLP QDW information
always @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
      tlp_qdw_counts  <= #TP 4*RX_NQDW;                  // We need thresold value before the actual tlp comparision with ram occupancy because of pipeline stage delays. Taken on safer side 1 extra value now.
    end else begin
      tlp_qdw_counts  <= #TP tlp_qdw_counts_int;
    end
end    


// Detection of the TLP end with dllp abort
assign     tlp_end_with_dllp_err = (|(hdec_form_nqdw_dllp_err & hdec_form_nqdw_eot) );
// Condition to decide whether TLP can disacarded from memory or not.
assign     discard_errored_tlp = dllp_error_pkt_drop_en ? ({1'b0,ram_occupancy} > tlp_qdw_counts) : 1'b0;  
//////////////////////////////////////////////////////////////
// Pack the data to eliminate gaps and determine size of input.
//
//////////////////////////////////////////////////////////////
always_comb begin : pack_qdw_wline_PROC
    logic [RAM_IW-1:0] j;
    logic [RAM_RD_WR_WD-1:0] k;
    j=0;  
    k=0;
    pkd_input_qdw_wline = 0;
    // assemble the write data by inspecting hv and dv along the datapath
    for(int i=0; i<RX_NQDW; i++) begin
        if( int_rtlh_radm_qdw_wline[i][HV_POS] | 
            int_rtlh_radm_qdw_wline[i][DV_POS]) begin
            pkd_input_qdw_wline[j] = int_rtlh_radm_qdw_wline[i];
            j = j + 1'b1;
            k = k + 1'b1;
        end 
    end
    pkd_input_wsize = k;
end

// counting QDW till valid TLP end within current clock cycle. 
always_comb begin : pkd_input_wsize_till_valid_eot_PROC
    logic [RAM_RD_WR_WD-1:0] k;
    k=0;
    for(int i=NQW-1; i>=0; i--) begin
        if(pkd_input_qdw_wline[i][EOT_POS] && (k == 0))
            k = i+1;
    end
    pkd_input_wsize_till_valid_eot = k;
end

// counting QDW till errored TLP end within a current clock cycle.
always_comb begin : pkd_input_wsize_till_errored_eot_PROC
    logic [RAM_RD_WR_WD-1:0] k;
    k=0;
    for(int i=0; i<NQW; i++) begin
        if(pkd_input_qdw_wline[i][EOT_POS] && pkd_input_qdw_wline[i][ERR_POS] && (k == 0))
            k = i+1;
    end
    pkd_input_wsize_till_errored_eot = k;
end


// separating data and control bits within a packed line.
// control bits used to data for register gating operation.
always_comb begin : data_ctrl_split_proc
  for(int i=0;i<NQW;i++) begin
    pkd_input_qdw_wline_data[i] = pkd_input_qdw_wline[i][QDW_DATA_BITS-1:0];
    pkd_input_qdw_wline_ctrl[i] = pkd_input_qdw_wline[i][QDW_WRLINE_WD-1:QDW_DATA_BITS];
  end
end

localparam RAM_IPIPE_WD_CTRL  = (NQW*QDW_CTRL_BITS) + RAM_RD_WR_WD + RAM_RD_WR_WD + RAM_RD_WR_WD + 1 + 1;
delay_n
 #(1, RAM_IPIPE_WD_CTRL) u_delay_n_input_pipe_ctrl
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({pkd_input_qdw_wline_ctrl, pkd_input_wsize_int , pkd_input_wsize_till_valid_eot  , pkd_input_wsize_till_errored_eot  , tlp_end_with_dllp_err  , discard_errored_tlp}),
    .dout       ({input_qdw_wline_ctrl,     input_wsize , pkd_input_wsize_till_valid_eot_r, pkd_input_wsize_till_errored_eot_r, tlp_end_with_dllp_err_r, discard_errored_tlp_r})
);

//localparam RAM_IPIPE_WD_DATA  = (QDW_DATA_BITS);
generate
    for (genvar k = 0; k < NQW; k++)begin : g_pipe_delay_w_enable
delay_n_w_enable
 #(1, QDW_DATA_BITS) u_delay_n_input_pipe_data
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .en         (|pkd_input_qdw_wline_ctrl[k]), 
    .clear      (1'b0),
    .din        (pkd_input_qdw_wline_data[k]),
    .dout       (input_qdw_wline_data[k])
);
    end
endgenerate

always_comb begin : data_ctrl_merge_proc
  for(int i=0;i<NQW;i++) begin
    input_qdw_wline[i] = {input_qdw_wline_ctrl[i], input_qdw_wline_data[i]};
  end
end

// Condition to take decision about the TLP packet removal
assign discard_previous_tlp = tlp_end_with_dllp_err_r && discard_errored_tlp_r;
// Condition indicates the TLP end without error within a current clock cycle.
logic       good_tlp_end;
assign good_tlp_end         = |pkd_input_wsize_till_valid_eot_r;
// Condiion to decide the first QDW which will be written inside the RAM while there is a TLP end with error in current clock.
assign valid_qdw_start = discard_previous_tlp ? pkd_input_wsize_till_errored_eot_r : {RAM_RD_WR_WD{1'b0}} ;
//////////////////////////////////////////////////////////////////////////////
// RAM write address and index initialization and registering of the updated info.
//
//////////////////////////////////////////////////////////////////////////////
always @(posedge core_clk or negedge core_rst_n) begin : push_logic_state_PROC
    if(!core_rst_n) begin
        ram_windex          <= #TP 0;
        int_ram_waddrx      <= #TP 0;
        current_ram_waddr_r <= #TP 0;
    end else begin
        ram_windex          <= #TP next_ram_windex;
        int_ram_waddrx      <= #TP next_ram_waddrx;
        current_ram_waddr_r <= #TP current_ram_waddr;

    end
end

always_comb begin : push_logic_calc_next_PROC
    logic  [RAM_IW-1:0]           tmp_windex;
    logic  [RAM_IW-1:0]           tmp_windex2;
    logic  [RAM_RD_WR_WD-1:0]     size_mid; // RAM_RD_WR_WD = RAM_IW/RAM_IW+1 Spyglass width mismatch
    logic  [RAM_PW+RAM_IW-1:0]    tmp_next_ram_waddrx;
    logic  [RAM_PW+RAM_IW-1:0]    tmp_current_ram_waddrx, tmp_current_ram_waddrx2;
    // Assign the input to the various RAMs starting from current windex
    tmp_current_ram_waddrx  = 0;
    tmp_current_ram_waddrx2 = 0;
    tmp_windex = discard_previous_tlp ? ram_windex_with_valid_eot : discard_prefix_qdw_count ? ram_windex_without_prf : ram_windex;                            
    int_ram_qdw_wline = input_qdw_wline;
    ram_we = 0;
    // Mux assignment based on the TLP discard and prefix discard condition.
    next_ram_windex     = discard_previous_tlp ? ram_windex_with_valid_eot          : discard_prefix_qdw_count ? ram_windex_without_prf          : ram_windex;
    tmp_next_ram_waddrx = discard_previous_tlp ? int_ram_waddrx_with_valid_eot      : discard_prefix_qdw_count ? int_ram_waddrx_without_prf      : int_ram_waddrx;
    current_ram_waddr   = discard_previous_tlp ? current_ram_waddr_r_with_valid_eot : discard_prefix_qdw_count ? current_ram_waddr_r_without_prf : current_ram_waddr_r;
    next_ram_waddrx     = int_ram_waddrx;

    // precalc mid
    size_mid = 0;
    tmp_windex2 = discard_previous_tlp ? ram_windex_with_valid_eot : discard_prefix_qdw_count ? ram_windex_without_prf : ram_windex;
    if((NQW/2<input_wsize) && (NQW/2>valid_qdw_start) ) begin 
      size_mid    = (NQW/2 - valid_qdw_start);
      tmp_windex2 = ({1'b0, tmp_windex} + size_mid) % NQW;
    end else if((NQW/2>=input_wsize) && (NQW/2>=valid_qdw_start) && (valid_qdw_start < input_wsize)) begin
      //size_mid    = (input_wsize-valid_qdw_start);
      tmp_windex2 = ({1'b0, tmp_windex} + (input_wsize-valid_qdw_start)) % NQW;
    end

    for(int i=0; i<NQW/2; i++) begin
      // taking qdw lines with errored tlp qdw removal
      if((i<input_wsize) && (i>=valid_qdw_start) ) begin 
        int_ram_qdw_wline[tmp_windex] = input_qdw_wline[i];
        //next_ram_waddr[tmp_windex % NQW] = incr_plus_1(tmp_next_ram_waddr[tmp_windex % NQW]);

        // spyglass disable_block W164a
        // SMD: LHS width is less than the RHS width in assignment.
        // SJ: Right side addition value cannot be more than left side.
        tmp_current_ram_waddrx = ((tmp_next_ram_waddrx + i - valid_qdw_start) < RAM_DP*NQW) ? (tmp_next_ram_waddrx + i - valid_qdw_start) : (tmp_next_ram_waddrx + i - valid_qdw_start) - RAM_DP*NQW;
        // spyglass enable_block W164a
        current_ram_waddr[tmp_windex % NQW] = tmp_current_ram_waddrx/NQW ; 
        ram_we[tmp_windex] = 1'b1;
        tmp_windex = (tmp_windex + 1) % NQW;
      end 
    end

    for(int i=NQW/2; i<NQW; i++) begin
      // taking qdw lines with errored tlp qdw removal
      if((i<input_wsize) && (i>=valid_qdw_start) ) begin 
        int_ram_qdw_wline[tmp_windex2] = input_qdw_wline[i];
        // spyglass disable_block W164a
        // SMD: LHS width is less than the RHS width in assignment.
        // SJ: Right side addition value cannot be more than left side.
        tmp_current_ram_waddrx2 = ((tmp_next_ram_waddrx + i - valid_qdw_start) < RAM_DP*NQW) ? (tmp_next_ram_waddrx + i - valid_qdw_start) : (tmp_next_ram_waddrx + i - valid_qdw_start) - RAM_DP*NQW;
        // spyglass enable_block W164a
        current_ram_waddr[tmp_windex2 % NQW] = tmp_current_ram_waddrx2/NQW ;
        ram_we[tmp_windex2] = 1'b1;
        tmp_windex2 = (tmp_windex2 + 1) % NQW;
      end 
    end

    // assigning ram write index calculated above
    next_ram_windex = tmp_windex2; 
    // calculate next ram waddr index
    next_ram_waddrx = add_mod_ram_dp_nqw(tmp_next_ram_waddrx, (input_wsize-valid_qdw_start));
  end

////////////////////////////////////////////////////////////////////////
// holding copy of the ram wraddress and indexes without prefix qdw written
////////////////////////////////////////////////////////////////////////
always @(posedge core_clk or negedge core_rst_n) begin : push_logic_state_without_prf_PROC
    if(!core_rst_n) begin
        ram_windex_without_prf          <= #TP 0;
        int_ram_waddrx_without_prf      <= #TP 0;
        current_ram_waddr_r_without_prf <= #TP 0;
        input_wsize_r <= #TP '0;
    end else begin
        input_wsize_r <= #TP input_wsize;
        if(input_wsize>0) begin
          ram_windex_without_prf          <= #TP next_ram_windex_without_prf;
          int_ram_waddrx_without_prf      <= #TP next_ram_waddrx_without_prf;
          current_ram_waddr_r_without_prf <= #TP current_ram_waddr_without_prf;
        end
    end
end

// write ram i/f pipeline 
localparam RAM_WPIPE_WD = (RAM_PW+RAM_IW) ; // ram write datapath pipe width: NQW*(addr+data+we)+ram_waddrx
delay_n
 #(RADM_PIPE_DELAY, RAM_WPIPE_WD+RAM_RD_WR_WD) u_delay_n_ram_wpipe
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({ int_ram_waddrx_without_prf , input_wsize_r   }),
    .dout       ({ int1_ram_waddrx_without_prf, input_wsize_r1  })
);

delay_n
 #(RAM_WPIPE_DP, RAM_WPIPE_WD) u_delay_n_ram_wpipe_1
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({ int1_ram_waddrx_without_prf }),
    .dout       ({ ram_waddrx_without_prf      })
);

always_comb begin : push_logic_calc_next_without_prf_PROC
    logic  [RAM_IW-1:0]           tmp_windex2_without_prf;
    logic  [RAM_RD_WR_WD-1:0]     size_mid; // RAM_RD_WR_WD = RAM_IW/RAM_IW+1 Spyglass width mismatch
    logic  [RAM_RD_WR_WD-1:0]     pseudo_input_wsize;
    logic [RAM_IW-1:0] tmp_windex_without_prf;
    logic  [RAM_PW+RAM_IW-1:0]    tmp_current_ram_waddrx_without_prf, tmp_current_ram_waddrx_without_prf2;
    logic  [RAM_PW+RAM_IW-1:0]    temp_next_ram_waddrx_without_prf;
    tmp_current_ram_waddrx_without_prf  = 0;
    tmp_current_ram_waddrx_without_prf2 = 0;
    tmp_windex_without_prf           = discard_previous_tlp ? ram_windex_with_valid_eot : discard_prefix_qdw_count ? ram_windex_without_prf     : ram_windex;            
    next_ram_windex_without_prf      = discard_previous_tlp ? ram_windex_with_valid_eot : discard_prefix_qdw_count ? ram_windex_without_prf     : ram_windex;
    temp_next_ram_waddrx_without_prf = discard_previous_tlp ? int_ram_waddrx_with_valid_eot : discard_prefix_qdw_count ? int_ram_waddrx_without_prf : int_ram_waddrx;
    current_ram_waddr_without_prf    = discard_previous_tlp ? current_ram_waddr_r_with_valid_eot : discard_prefix_qdw_count ? current_ram_waddr_r_without_prf : current_ram_waddr_r;
    next_ram_waddrx_without_prf      = int_ram_waddrx_without_prf;

    // precalc mid
    size_mid = 0;
    tmp_windex2_without_prf = discard_previous_tlp ? ram_windex_with_valid_eot : discard_prefix_qdw_count ? ram_windex_without_prf     : ram_windex;
    pseudo_input_wsize = input_wsize-prefix_qdw_count_r;
    if((NQW/2<pseudo_input_wsize) && (NQW/2>valid_qdw_start) ) begin 
      size_mid    = (NQW/2 - valid_qdw_start);
      tmp_windex2_without_prf = ({1'b0, tmp_windex_without_prf} + size_mid) % NQW;
    end else if((NQW/2>=pseudo_input_wsize) && (NQW/2>=valid_qdw_start) && (valid_qdw_start < pseudo_input_wsize)) begin
      //size_mid    = (pseudo_input_wsize-valid_qdw_start);
      tmp_windex2_without_prf = ({1'b0, tmp_windex_without_prf} + (pseudo_input_wsize-valid_qdw_start)) % NQW;
    end 
    
    for(int i=0; i<NQW/2; i++) begin
      if((i<(input_wsize-prefix_qdw_count_r)) && (i>=valid_qdw_start)) begin
        //next_ram_waddr_without_prf[tmp_windex_without_prf % NQW] = incr_plus_1(ram_waddr_without_prf[tmp_windex_without_prf % NQW]);

        // spyglass disable_block W164a
        // SMD: LHS width is less than the RHS width in assignment.
        // SJ: Right side addition value cannot be more than left side.
        tmp_current_ram_waddrx_without_prf = ((temp_next_ram_waddrx_without_prf + i - valid_qdw_start) < RAM_DP*NQW) ? (temp_next_ram_waddrx_without_prf + i - valid_qdw_start) : (temp_next_ram_waddrx_without_prf + i - valid_qdw_start) - RAM_DP*NQW;
        // spyglass enable_block W164a
        current_ram_waddr_without_prf[tmp_windex_without_prf % NQW] = (tmp_current_ram_waddrx_without_prf)/NQW ;
        tmp_windex_without_prf = (tmp_windex_without_prf + 1) % NQW ;
      end
    end

    for(int i=NQW/2; i<NQW; i++) begin
      if((i<(input_wsize-prefix_qdw_count_r)) && (i>=valid_qdw_start)) begin
        // spyglass disable_block W164a
        // SMD: LHS width is less than the RHS width in assignment.
        // SJ: Right side addition value cannot be more than left side.
        tmp_current_ram_waddrx_without_prf2 = ((temp_next_ram_waddrx_without_prf + i - valid_qdw_start) < RAM_DP*NQW) ? (temp_next_ram_waddrx_without_prf + i - valid_qdw_start) : (temp_next_ram_waddrx_without_prf + i - valid_qdw_start) - RAM_DP*NQW;
        // spyglass enable_block W164a
        current_ram_waddr_without_prf[tmp_windex2_without_prf % NQW] = (tmp_current_ram_waddrx_without_prf2)/NQW ;
        tmp_windex2_without_prf = (tmp_windex2_without_prf + 1) % NQW ;
      end
    end


    next_ram_windex_without_prf = tmp_windex2_without_prf;
    next_ram_waddrx_without_prf = add_mod_ram_dp_nqw(temp_next_ram_waddrx_without_prf, (input_wsize-prefix_qdw_count_r-valid_qdw_start));
end

/////////////////////////////////////////////////////////////////////////////////
// holding copy of the ram wraddress and indexes with last valid TLP written inside the RAM
/////////////////////////////////////////////////////////////////////////////////
always @(posedge core_clk or negedge core_rst_n) begin : push_logic_state_for_valid_tlp_PROC
    if(!core_rst_n) begin
        ram_windex_with_valid_eot          <= #TP 0;
        int_ram_waddrx_with_valid_eot      <= #TP 0;
        current_ram_waddr_r_with_valid_eot <= #TP 0;
    end else begin
        if(input_wsize>0) begin
          ram_windex_with_valid_eot          <= #TP next_ram_windex_with_valid_eot;
          int_ram_waddrx_with_valid_eot      <= #TP next_ram_waddrx_with_valid_eot;
          current_ram_waddr_r_with_valid_eot <= #TP current_ram_waddr_with_valid_eot;
        end
    end
end

always_comb begin : push_logic_calc_next_with_valid_eot_PROC
    logic  [RAM_IW-1:0]           tmp_windex2_with_valid_eot;
    logic  [RAM_RD_WR_WD-1:0]     size_mid; // RAM_RD_WR_WD = RAM_IW/RAM_IW+1 Spyglass width mismatch
    logic  [RAM_IW-1:0]           tmp_windex_with_valid_eot;
    logic  [RAM_PW+RAM_IW-1:0]    tmp_current_ram_waddrx_with_valid_eot, tmp_current_ram_waddrx_with_valid_eot2;
    logic  [RAM_PW+RAM_IW-1:0]    temp_next_ram_waddrx_with_valid_eot;
    tmp_current_ram_waddrx_with_valid_eot  = 0;
    tmp_current_ram_waddrx_with_valid_eot2 = 0;
    tmp_windex_with_valid_eot           = (discard_previous_tlp || (!good_tlp_end) ) ? ram_windex_with_valid_eot     : ram_windex ;
    next_ram_windex_with_valid_eot      = (discard_previous_tlp || (!good_tlp_end) ) ? ram_windex_with_valid_eot     : ram_windex ;
    temp_next_ram_waddrx_with_valid_eot = (discard_previous_tlp || (!good_tlp_end) ) ? int_ram_waddrx_with_valid_eot : int_ram_waddrx ; 
    current_ram_waddr_with_valid_eot    = (discard_previous_tlp || (!good_tlp_end) ) ? current_ram_waddr_r_with_valid_eot : current_ram_waddr_r ;
    next_ram_waddrx_with_valid_eot      =  int_ram_waddrx_with_valid_eot;

    // precalc mid
    size_mid = 0;
    tmp_windex2_with_valid_eot = (discard_previous_tlp || (!good_tlp_end) ) ? ram_windex_with_valid_eot     : ram_windex ;
    if((NQW/2<pkd_input_wsize_till_valid_eot_r) && (NQW/2>valid_qdw_start) ) begin 
      size_mid    = (NQW/2 - valid_qdw_start);
      tmp_windex2_with_valid_eot = ({1'b0, tmp_windex_with_valid_eot} + size_mid) % NQW;
    end else if((NQW/2>=pkd_input_wsize_till_valid_eot_r) && (NQW/2>=valid_qdw_start) && (valid_qdw_start < pkd_input_wsize_till_valid_eot_r)) begin
      //size_mid    = (pkd_input_wsize_till_valid_eot_r-valid_qdw_start);
      tmp_windex2_with_valid_eot = ({1'b0, tmp_windex_with_valid_eot} + (pkd_input_wsize_till_valid_eot_r-valid_qdw_start)) % NQW;
    end

    for(int i=0; i<NQW/2; i++) begin
      if((i<pkd_input_wsize_till_valid_eot_r) && (i>=valid_qdw_start)) begin
        // spyglass disable_block W164a
        // SMD: LHS width is less than the RHS width in assignment.
        // SJ: Right side addition value cannot be more than left side.
        tmp_current_ram_waddrx_with_valid_eot = ((temp_next_ram_waddrx_with_valid_eot + i - valid_qdw_start) < RAM_DP*NQW) ? (temp_next_ram_waddrx_with_valid_eot + i - valid_qdw_start) : (temp_next_ram_waddrx_with_valid_eot + i - valid_qdw_start) - RAM_DP*NQW;
        // spyglass enable_block W164a
        current_ram_waddr_with_valid_eot[tmp_windex_with_valid_eot % NQW] = (tmp_current_ram_waddrx_with_valid_eot)/NQW ;
        tmp_windex_with_valid_eot = (tmp_windex_with_valid_eot + 1) % NQW ;
      end
    end

    for(int i=NQW/2; i<NQW; i++) begin
      if((i<pkd_input_wsize_till_valid_eot_r) && (i>=valid_qdw_start)) begin
        // spyglass disable_block W164a
        // SMD: LHS width is less than the RHS width in assignment.
        // SJ: Right side addition value cannot be more than left side.
        tmp_current_ram_waddrx_with_valid_eot2 = ((temp_next_ram_waddrx_with_valid_eot + i - valid_qdw_start) < RAM_DP*NQW) ? (temp_next_ram_waddrx_with_valid_eot + i - valid_qdw_start) : (temp_next_ram_waddrx_with_valid_eot + i - valid_qdw_start) - RAM_DP*NQW;
        // spyglass enable_block W164a
        current_ram_waddr_with_valid_eot[tmp_windex2_with_valid_eot % NQW] = (tmp_current_ram_waddrx_with_valid_eot2)/NQW ;
        tmp_windex2_with_valid_eot = (tmp_windex2_with_valid_eot + 1) % NQW ;
      end
    end

    next_ram_windex_with_valid_eot = tmp_windex2_with_valid_eot;
    next_ram_waddrx_with_valid_eot = add_mod_ram_dp_nqw(temp_next_ram_waddrx_with_valid_eot, (pkd_input_wsize_till_valid_eot_r-valid_qdw_start)  );
  end

logic [NQW-1:0][QDW_WRLINE_WD-1:0]  int_ram_qdw_wline_d;           // write datapath lines to RAM included ctl bits plus parity bits for qdw
logic [NQW-1:0][RAM_PW-1:0]         current_ram_waddr_d;           // write address for the RAM
logic [NQW-1:0]                     ram_we_d;                      // write enable for the RAM 
logic [NQW-1:0][RAM_PW-1:0]         ram_raddr_d;                   // read address for the RAM
logic [NQW-1:0]                     ant_ram_pop_d;                 // read enable for the RAM 


localparam RADM_PIPE_WD    = NQW * (QDW_WRLINE_WD + RAM_PW + 1);
delay_n
 #(RADM_PIPE_DELAY, RADM_PIPE_WD) u_delay_n_radm_pipe
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({int_ram_qdw_wline,   current_ram_waddr,   ram_we    }),   // current_ram_waddr_r already exits
    .dout       ({int_ram_qdw_wline_d, current_ram_waddr_d, ram_we_d  })
);

/////////////////////////////////////////////////////
// Write operation within a RAM instance
////////////////////////////////////////////////////
// radm pipe instance manages the write operation within external ram with management of the RASDP
radm_pipe
 
  #(   
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE),
   .RAM_WD(RAM_WD),
   .RAM_WD_NO_ECC(RAM_WD_NO_ECC),
   .RAM_DP(RAM_DP),
   .RAM_PW(RAM_PW),
   .QDW_WRLINE_WD(QDW_WRLINE_WD),
   .QDW_WRLINE_NO_PARITY_WD(QDW_WRLINE_NO_PARITY_WD)
   ) u_radm_formq_ras_pipe
   (
    .int_ram_qdw_wline                  (int_ram_qdw_wline_d), 
    .current_ram_waddr                  (current_ram_waddr_d),
    .ram_we                             (ram_we_d),

    .radm_formqram_addra                (radm_formqram_addra), 
    .radm_formqram_ena                  (radm_formqram_ena), 
    .radm_formqram_wea                  (radm_formqram_wea), 
    .radm_formqram_dina                 (radm_formqram_dina), 
    .radm_formqram_addrb                (radm_formqram_addrb), 
    .radm_formqram_enb                  (radm_formqram_enb), 
    .formqram_radm_doutb                (formqram_radm_doutb), 

    .ram_raddr                          (ram_raddr),
    .ant_ram_pop                        (ant_ram_pop),
    .int_formqram_radm_doutb_rpipe      (int_formqram_radm_doutb_rpipe),

    .ras_dp_err_log                     (ras_dp_err_log[2-1:0]) ,
    .out_ras_dp_wake_up                 (out_ras_dp_wake_up[2-1:0]),
    .ras_dp_err_inj                     (ras_dp_err_inj),
    .core_clk                           (core_clk), 
    .core_rst_n                         (core_rst_n) 
);

//////////////////////////////////////////////////////////////////////////////
//
//------------------------------Read Logic------------------------------------
//
//////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////
// Initializing the RAM read adress and read index and 
// latching the updated innformation based on the number of QDW reads from memory
//
//////////////////////////////////////////////////////////////////////////////////
always @(posedge core_clk or negedge core_rst_n) begin : pop_logic_state_PROC
    if(!core_rst_n) begin
        ram_rindex         <= #TP 0;
        ram_raddr          <= #TP 0;
        ram_raddrx         <= #TP 0;
        ant_ram_pop        <= #TP 0;
    end else begin
        ram_rindex         <= #TP next_ram_rindex;
        ram_raddr          <= #TP next_ram_raddr;
        ram_raddrx         <= #TP next_ram_raddrx;
        ant_ram_pop        <= #TP next_ant_ram_pop;
    end
end

///////////////////////////////////////////////////////////
// Pre-calculate a constant array of vertical indexes to ease timing.
//
///////////////////////////////////////////////////////////
always_comb begin : raw_rindex_PROC
    for(int tmp_rindex=0; tmp_rindex<NQW; tmp_rindex++) begin
        for(int i=0; i<NQW; i++) begin
            raw_rindex[tmp_rindex][i] = (tmp_rindex + i) % NQW;
        end
    end
end

///////////////////////////////////////////////////////////
// Determine the read address to pop from the RAM.
// Pre-calculate raw read addresses for each possible
// next_ram_load_rsize (i.e. from 0 to NQW) in order to ease timing.
//
///////////////////////////////////////////////////////////
always_comb begin : raw_next_ram_raddr_calc_PROC
    logic [RAM_RD_WR_WD-1:0]          cast_next_load_rsize;
    logic [RAM_IW-1:0]          tmp_rindex;
    logic [NQW-1:0][RAM_PW-1:0] tmp_next_ram_raddr;
    logic [NQW-1:0]             tmp_next_ram_pop;
    raw_next_ram_raddr[0] = ram_raddr;
    raw_next_ram_pop[0]    = 0;
    raw_next_ram_rindex[0] = ram_rindex;
    raw_next_ram_raddrx[0] = ram_raddrx;
    for(int tmp_next_load_rsize=1; tmp_next_load_rsize<=NQW; tmp_next_load_rsize++) begin
        cast_next_load_rsize = tmp_next_load_rsize;
        tmp_rindex = ram_rindex;
        tmp_next_ram_raddr = ram_raddr;
        tmp_next_ram_pop = 0;
        for(int i=0; i<NQW; i++) begin
            if(i<tmp_next_load_rsize) begin
                tmp_next_ram_raddr[tmp_rindex % NQW] = incr_plus_1(ram_raddr[tmp_rindex % NQW]);
                tmp_next_ram_pop[tmp_rindex] = 1'b1;
                tmp_rindex = (tmp_rindex + 1) % NQW;
            end
        end
        raw_next_ram_raddr[tmp_next_load_rsize]  = tmp_next_ram_raddr;
        raw_next_ram_pop[tmp_next_load_rsize]    = tmp_next_ram_pop;
        raw_next_ram_rindex[tmp_next_load_rsize] = tmp_rindex;
        raw_next_ram_raddrx[tmp_next_load_rsize] = add_mod_ram_dp_nqw(ram_raddrx, cast_next_load_rsize);
    end
end
///////////////////////////////////////////////////////////////////////////////////////
// Enable the pop command for each RAM only if the location was already written (i.e. ram not empty)
//
///////////////////////////////////////////////////////////////////////////////////////
always_comb begin : raw_ant_ram_pop_calc_PROC
    logic                     tmp_not_empty;
    logic [RAM_RD_WR_WD-1:0]        cast_i;
    logic [RAM_IW-1:0]        tmp_rindex;
    logic [NQW-1:0]           tmp_ant_ram_pop;
    logic [RAM_PW+RAM_IW-1:0] tmp_ram_raddrx;
    for(int tmp_next_load_rsize=0; tmp_next_load_rsize<=NQW; tmp_next_load_rsize++) begin
        tmp_not_empty = 1'b1;
        tmp_ant_ram_pop = 0;
        tmp_rindex = raw_next_ram_rindex[tmp_next_load_rsize];
        for(int i=0; i<NQW; i++) begin
            cast_i = i;
            tmp_ram_raddrx = add_mod_ram_dp_nqw(raw_next_ram_raddrx[tmp_next_load_rsize], cast_i);
            tmp_not_empty = (tmp_not_empty==1'b0)? 0 : (RAM_WPIPE_DP==1) ? (int1_ram_waddrx_without_prf != tmp_ram_raddrx) : (next_ram_waddrx != tmp_ram_raddrx);
            tmp_ant_ram_pop[tmp_rindex] = tmp_not_empty;
            tmp_rindex = (tmp_rindex + 1) % NQW;
        end
        raw_ant_ram_pop[tmp_next_load_rsize] = tmp_ant_ram_pop;
    end
end
////////////////////////////////////////////////////////////////////////////////////
// Assign the proper raw read address according to the actual next_ram_load_rsize
//
////////////////////////////////////////////////////////////////////////////
always_comb begin : next_ram_raddr_calc_PROC
    next_ram_raddr   = raw_next_ram_raddr[next_ram_load_rsize];
    next_ram_pop     = raw_next_ram_pop[next_ram_load_rsize];
    next_ram_rindex  = raw_next_ram_rindex[next_ram_load_rsize];
    next_ram_raddrx  = raw_next_ram_raddrx[next_ram_load_rsize];
    next_ant_ram_pop = raw_ant_ram_pop[next_ram_load_rsize];
    //next_ram_not_empty = raw_next_ram_not_empty[next_ram_load_rsize];
end
////////////////////////////////////////////////////////////////////////////
// delay to compensate the read data latency and
// align data from RAM
//
////////////////////////////////////////////////////////////////////////////
// qdw_reg_array comb logic before reg ~ 250ps . Too much with ECC insertion...
// Aligning ctrl signals to REG[int_formqram_radm_doutb_rpipe]
localparam RAM_RPIPE_DATA_DELAY     = `CX_RADM_FORMATION_QUEUE_RD_PIPE_EN ; // = (@CX_MULTISTREAM_ARCH && (@CX_NW==32) && (@CX_MAX_CORECLK_FREQ>500) && (@CX_RASDP_EN==1))
localparam RAM_DELAY_RD_LATENCY_WD  =  RAM_RD_WR_WD+RAM_IW; // +load_rsize_d+ram_rindex
delay_n
 #(RAM_RPIPE_DATA_DELAY+RADM_FORMQ_RAM_RD_LATENCY , RAM_DELAY_RD_LATENCY_WD) u_delay_n_ram_rd_latency
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({next_ram_load_rsize, ram_rindex }),     
    .dout       ({ram_load_rsize_d   , ram_rindex_d}) 
);

localparam PIPE_WD  = RAM_RD_WR_WD+RAM_IW ;     //  +load_rsize_d + ram_rindex
delay_n
 #(RAM_RPIPE_DP, PIPE_WD) u_delay_n_ram_rpipe
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({ ram_load_rsize_d , ram_rindex_d}),
    .dout       ({ int_ram_load_rsize , int_ram_rindex_d})
);
///////////////////////////////////////////////////////////////////
// internal register based array storage management logic 
//
///////////////////////////////////////////////////////////////////
// logic to figure out the data in pipeline stage after read operation.
always @(posedge core_clk or negedge core_rst_n) begin : read_load_in_pipeline_PROC
    if(!core_rst_n) begin
      read_in_pipeline <= #TP 0;
    end else begin
    // spyglass disable_block W164a
    // SMD: LHS width is less than the RHS width in assignment.
    // SJ: Right side value can not go beyond the left side supported value with bits. Logic keeps track of the read QDW which has been read
    //     from ram to store wihtin a register based arrray. We limit the read operation of the QDW at below logic such that it will never full the QDW register. 
        read_in_pipeline <= #TP read_in_pipeline + next_ram_load_rsize - int_ram_load_rsize;
    // spyglass enable_block W164a
     end
end

// Effective reg array write pointern is current wrptr + read in pipeline.
assign effective_reg_array_wrptr = {1'b0,reg_array_wrptr} + {1'b0,read_in_pipeline};
assign qdw_reg_array_occupancy = (effective_reg_array_wrptr > {1'b0,reg_array_rdptr}) ? (effective_reg_array_wrptr - {1'b0,reg_array_rdptr}) :
                                 (effective_reg_array_wrptr < {1'b0,reg_array_rdptr}) ? (REG_ARRAY_DP - ({1'b0,reg_array_rdptr} - effective_reg_array_wrptr)) : 0;

// Actual reg array occupancy status after write operation within a register array.
assign qdw_reg_array_occupancy_actual = (reg_array_wrptr > reg_array_rdptr) ? {1'b0, (reg_array_wrptr - reg_array_rdptr)} :
                                        (reg_array_wrptr < reg_array_rdptr) ? (REG_ARRAY_DP - {1'b0, (reg_array_rdptr - reg_array_wrptr)}) : 0;

// Actual write pointer increment based on the data read from RAM.
always @(posedge core_clk or negedge core_rst_n) begin : reg_array_wrptr_PROC
    if(!core_rst_n) begin
      reg_array_wrptr <= #TP 0;
    end else begin
      reg_array_wrptr <= #TP (reg_array_wrptr + int_ram_load_rsize) % REG_ARRAY_DP;
    end
end

// registering the data in case of the RAS ENABLE. 
// qdw_reg_array comb logic before reg ~ 250ps . Too much with ECC insertion...
delay_n
 #(RAM_RPIPE_DATA_DELAY, NQW*QDW_WRLINE_WD) u_delay_n_ram_rpipe_data
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (int_formqram_radm_doutb_rpipe),
    .dout       (int_formqram_radm_doutb_rpipe_r)
);

// Logic to store the QDWs inside the register based array storage.
always @(posedge core_clk or negedge core_rst_n) begin : qdw_reg_array_PROC
    if(!core_rst_n) begin
      for(int i=0;i<REG_ARRAY_DP;i++) begin
        qdw_reg_array[i]      <= #TP 0;
      end  
    end else begin
      for(int i=0;i<REG_ARRAY_DP ;i++) begin
        if(i<int_ram_load_rsize)
          qdw_reg_array[(reg_array_wrptr+i) % REG_ARRAY_DP] <= #TP int_formqram_radm_doutb_rpipe_r[(int_ram_rindex_d + i) % NQW];
      end  
    end
end

// Checking the status of the QDW register based storage for available space and full status.
assign qdw_reg_array_avail_space   = REG_ARRAY_DP - qdw_reg_array_occupancy-1;
assign qdw_reg_array_almost_full   = qdw_reg_array_occupancy == REG_ARRAY_DP - 1'b1;

// Padding bit to manage lint warning only within a next read load logic.
assign Padded_bits = {RAM_REG_DEPTH_DIFF{1'b0}};
assign Padded_bits_ram_occupancy = {RAM_REG_DEPTH_DIFF_RAM{1'b0}};

// Logic to decide about the next read load from the memory to internal storage.
always_comb begin
  next_ram_load_rsize = 0;
  if(qdw_reg_array_almost_full)       
    next_ram_load_rsize = 0;
  else
    if(ram_occupancy==0)
      next_ram_load_rsize = 0;
    else
      if({Padded_bits_ram_occupancy,ram_occupancy} > {Padded_bits,qdw_reg_array_avail_space})           
        next_ram_load_rsize = qdw_reg_array_avail_space > NQW ? NQW : qdw_reg_array_avail_space[RAM_RD_WR_WD-1:0];
      else
        next_ram_load_rsize = ram_occupancy > NQW ? NQW : ram_occupancy[RAM_RD_WR_WD-1:0]; 
end
///////////////////////////////////////////////////////////
// Read logic to read QDW from register based array
//
///////////////////////////////////////////////////////////
// reg array rdptr increment logic.
always @(posedge core_clk or negedge core_rst_n) begin : reg_array_rdptr_PROC
  if(!core_rst_n) begin
    reg_array_rdptr <= #TP 0;
  end else begin
    reg_array_rdptr <= #TP (reg_array_rdptr + next_load_rsize) % REG_ARRAY_DP;
  end
end

// Extracting the HV DV and EOT information from the reg array
always_comb  begin : ff_array_read_PROC
  reg_array_rdindex = '0;
  for(int i=0; i<=NQW_R; i++) begin
    if((qdw_reg_array_occupancy_actual - next_load_rsize) > i ) begin
      reg_array_rdindex =  (reg_array_rdptr +  next_load_rsize + i) % REG_ARRAY_DP;
      acc_hv_int[i]  =  qdw_reg_array[reg_array_rdindex][HV_POS];
      acc_dv_int[i]  =  qdw_reg_array[reg_array_rdindex][DV_POS];
      acc_eot_int[i] =  qdw_reg_array[reg_array_rdindex][EOT_POS];
      acc_mac_int[i] =  qdw_reg_array[reg_array_rdindex][MAC_ECRC_POS];
      acc_data_dws_int[i]  =  qdw_reg_array[reg_array_rdindex][DWEN_POS+:2];
    end
    else begin
      acc_hv_int[i]  =  1'b0;
      acc_dv_int[i]  =  1'b0;
      acc_eot_int[i] =  1'b0;
      acc_mac_int[i] =  1'b0;
      acc_data_dws_int[i]  =  2'b00;     
    end
  end  
end

// latching information of hv,dv and eot
always @(posedge core_clk or negedge core_rst_n)  begin : ff_array_read_PROC_f
  if(!core_rst_n) begin
      acc_hv  <= #TP '0;
      acc_dv  <= #TP '0;
      acc_eot <= #TP '0;
      acc_mac <= #TP '0;
      acc_data_dws <= #TP '0;   
  end
  else begin
      acc_hv  <= #TP acc_hv_int;
      acc_dv  <= #TP acc_dv_int;
      acc_eot <= #TP acc_eot_int;
      acc_mac <= #TP acc_mac_int;
      acc_data_dws  <= #TP acc_data_dws_int;   
  end  
end

// latching the qdw information from register array to reduce manage timing path
always @(posedge core_clk or negedge core_rst_n) begin : QDW_REG_ARRAY_READ_PROC
  if(!core_rst_n) begin
    qdw_reg_array_read <= #TP 0;
  end else begin
  if(!filt_form_halt_en) begin
     for(int i=0; i<NQW_R; i++) begin
       qdw_reg_array_read[i] <= #TP qdw_reg_array[(reg_array_rdptr + i) % REG_ARRAY_DP]; 
     end
  end // if end   
  end
end

// registered information for next stage combinational logic drive related to data split on header and data interface.
delay_n_w_enable
 #(1 , FORMQ_RD_PORTS*NQW_R + REG_ARRAY_RD_WD +  NQW_R ) u_delay_n_mask
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (!filt_form_halt_en),
    .din        ({interface_mask,next_load_rsize, mac_qdw_read_en  } ),
    .dout       ({interface_mask_delay, next_load_rsize_delay, mac_qdw_read_en_r  } )
);
  //////////////////////////////////////////////////////////////////////////////
  // logic to control the read opeation of the qdw register array.
  //
  //////////////////////////////////////////////////////////////////////////////
  // latching the data dw read more than data interface in the previous clock cycle
  // used to take decision about the read opeartion from qdw reg array
  always @(posedge core_clk or negedge core_rst_n) begin : Mem_Read_Block_r_PROC_new
    if(!core_rst_n) begin
      for(int i=0; i<FORMQ_RD_PORTS; i++)
        data_dw_count_latched[i]  <= #TP '0;
    end else begin
      if(merged_qdw_read && (eot_count == 0))
        data_dw_count_latched[0] <= #TP (data_dw_count[0] > 4*N_DATA_QDW) ? (data_dw_count[0] - 4*N_DATA_QDW) : 0;
      else
        // in case of EOT read there will be no extra data read
        if(eot_count != 0) begin
          for(int i=0; i<FORMQ_RD_PORTS; i++)
            data_dw_count_latched[i]  <= #TP '0;
        end  
    end
  end 
  // Condition to block the read opearation on the next clock cycle to pass data dw which has been read in previous clock cycle.
  always @(posedge core_clk or negedge core_rst_n) begin : Mem_Read_Block_PROC
    if(!core_rst_n) begin
      qdw_read_blocked  <= #TP 0;
    end else begin
      if(!filt_form_halt_en)
        qdw_read_blocked  <= #TP (merged_qdw_read || merged_qdw_read_r) && (data_dw_total_count[0] > 4*N_DATA_QDW) && (eot_count != 0);   
    end
  end   
  
  always @(posedge core_clk or negedge core_rst_n) begin : Mem_Read_Block_r_PROC
    if(!core_rst_n) begin
      merged_qdw_read_r  <= #TP 0;
    end else begin
      if(!filt_form_halt_en) begin
        if(qdw_read_blocked)
          merged_qdw_read_r <= #TP 1'b1;
        else     
          if(merged_qdw_read)
            merged_qdw_read_r <= #TP 1'b1;
      end    
    end
  end 

  ////////////////////////////////////////////////////////////////////////////////
  // Determine how much data can be shifted out of the accumulation register, 
  // according to the rules of the serialization algorithm.
  //
  // The rule implemented here is one/two packets per cycle based on the configuration. 
  // 
  // Two parallel header can be placed on the output interface with maximum data read 
  // according to the link configuration.
  //
  // Header is placed with data only on the output interface in case of the non availability of EOT.
  //
  ////////////////////////////////////////////////////////////////////////////////
  always_comb begin : next_load_rsize_calc_PROC
  int i,j,k,dv_counts;
    dv_counts = 0; 
    interface_mask = 0;
    for(i=0; i<NQW_R; i++) begin
       if(acc_dv[i] && !acc_hv[i])
         dv_counts = dv_counts + 1;
    end
    block_data_read   = 0;
    next_load_rsize = 0;
    eot_count       = 0;
    dv_count        = 0;
    merged_qdw_read   = 0;
    tlp_read_over   = 0;
    interface_sel   = 0;
    data_dw_count   = 0;
    mac_qdw_read_en = 0;
    data_dw_total_count = '0;

    // Stop partial read of the data to avoid bubble on data interface.
    block_data_read = ((|acc_eot) == 0) && (dv_counts< N_DATA_QDW);
    
    // No read from array in case of halt or read block or unavailability of data inside the array.
    if(block_data_read || qdw_read_blocked || filt_form_halt_en || (qdw_reg_array_occupancy_actual==0)) begin  
      next_load_rsize = 0;
    end 
    // All are data QDWs.
    else if((|acc_eot)==0 && (|acc_hv)==0) begin 
      for(j=0;j<N_DATA_QDW;j=j+1) begin
        interface_mask[0][j] = 1'b1;
        next_load_rsize =  N_DATA_QDW ; 
      end   
    end 
    else begin   

    for(i=0; i<NQW_R; i++) begin
    if(!tlp_read_over) begin 
     // Counting Data QDWs. Limit data QDW read till data interface width for interface 0. 
     if((!acc_hv[i]) && acc_dv[i] && (eot_count==interface_sel) && (dv_count[interface_sel] <=N_DATA_QDW)) 
       dv_count[interface_sel] = dv_count[interface_sel] + 1;

     if(acc_dv[i] && (eot_count==interface_sel) && (dv_count[interface_sel] <=N_DATA_QDW)) 
       data_dw_count[interface_sel] = data_dw_count[interface_sel] + (acc_dv[i] ? (acc_data_dws[i] == 0) ? 3'h4 : acc_data_dws[i] : 0) ;
    
     // Enabel mask for header + Data QDWs for interfaces.    
     if((eot_count==interface_sel) && (dv_count[interface_sel]<=N_DATA_QDW)) 
       interface_mask[interface_sel][i] = 1'b1;  
     
   
      tlp_read_over =  ((eot_count==interface_sel) && (dv_count[interface_sel]>N_DATA_QDW));
      
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ:  By design "data_dw_total_count" cannot overflow. RHD side values are limited to maximum 35 as we do not read more data from ram.
      data_dw_total_count[interface_sel] = data_dw_count[interface_sel]+data_dw_count_latched[interface_sel];
// spyglass enable_block W164a

     if(tlp_read_over && (acc_eot[i] && acc_mac[i]) && ( data_dw_total_count[interface_sel] <= N_DATA_QDW*4) )
       mac_qdw_read_en[i] = 1'b1;


     // Enabel mask for header + Data QDWs for interfaces.    
     if(mac_qdw_read_en[i])
       interface_mask[interface_sel][i] = 1'b1;  

     if((acc_hv[i] || acc_dv[i]) &&  (eot_count <FORMQ_RD_PORTS) && (tlp_read_over ~^ mac_qdw_read_en[i]) )
       next_load_rsize = next_load_rsize + 1;

     if(acc_eot[i] && (eot_count <FORMQ_RD_PORTS) && (tlp_read_over ~^ mac_qdw_read_en[i]) )      
       eot_count = eot_count + 1;

     if(acc_eot[i] && eot_count <FORMQ_RD_PORTS)
       interface_sel = interface_sel + 1;
       
     if((acc_hv[i]) && acc_dv[i])
       merged_qdw_read = 1'b1;
    
    end // if condition  
    end // for loop end
   end // else end for first condition 
  end // always end   

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// Placing of the data from register array to accumulated qdw readline.
//
////////////////////////////////////////////////////
localparam  QDW_PROT_WD = 128/PROT_RANGE;
// parity generation for overread QDW
logic    [FORMQ_RD_PORTS-1:0][QDW_PROT_WD-1:0]       extra_dws_parity;

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
                .PROT_WD                 (QDW_PROT_WD),
                .PARITY_MODE             (PARITY_MODE),                 // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),                 // No correction
                .TOTAL_WIDTH             (128),                //  
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (0)
            ) u_ras_dp_pipe_overread_qdw (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (1'b1                  ),
                .din      (extra_qdw_rd_data[interface_no_with_overread] ),
                .din_prot ('0                 ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(extra_dws_parity[0] ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );

always_comb begin : acc_qdw_rline_PROC
    interface_no_with_overread = 0;
    for(int j=0; j<FORMQ_RD_PORTS; j++) begin
      if(extra_qdw_rd_enable[j])
        interface_no_with_overread = j;
    end  
    // placement of extra qdw data on the first place.
    if(|extra_qdw_rd_enable) begin
      acc_qdw_rline             = 0;
      acc_qdw_rline[0]          = 
                                  {
                                   extra_qdw_rd_data_eot[interface_no_with_overread],             // EOT
                                   1'b1,                                                          // DV 
                                   1'b0,                                                          // HV
                                    {PKT_ORD_WD{1'b0}},                                           // No need to latch is as we pass pkt number with header only.
                                   fm_poisoned_with_overreaddata[interface_no_with_overread],
                                   fm_nullified_with_overreaddata[interface_no_with_overread],
                                   1'b0, // mac_ecrc flag can never be in overread state
                                   extra_qdw_rd_data_dllp_err[interface_no_with_overread],        // dllp error
                                   extra_qdw_rd_data_start[interface_no_with_overread],           // Location for the DW start based on the DW position within Header QDW. 
                                   data_dw_counts(extra_qdw_rd_data_dwen[interface_no_with_overread]),   // DWEN for data
                                   extra_dws_parity[interface_no_with_overread],
                                   extra_qdw_rd_data[interface_no_with_overread]                   // Data
                                   };
    
       acc_qdw_rline[NQW_R-1:1] = qdw_reg_array_read[NQW_R-2:0];
    end else begin
       acc_qdw_rline = qdw_reg_array_read;
    end
end
ras_dp_err_inj_t                        ras_dp_err_inj_acc_qdw_rline;
ras_dp_err_log_t       [NQW_R-1:0]      ras_dp_err_log_acc_qdw_rline;              // rasdp error log interface
 
// DPP checker for acc_qdw_rline
generate
    for (genvar k = 0; k < NQW_R; k++)begin : g_rasdp_qdw_rline
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
                .TOTAL_WIDTH             (QDW_DW),           //  
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+2*NQW+k),
                .PIPE_RAS_DP_ERR_LOG     (1)
            ) u_ras_dp_pipe (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (acc_qdw_rline[k][HV_POS] || acc_qdw_rline[k][DV_POS] ),
                .din      (acc_qdw_rline[k][QDW_DW-1:0] ),
                .din_prot (acc_qdw_rline[k][QDW_DW+QDW_PAR-1:QDW_DW]),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(                   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  (ras_dp_err_log_acc_qdw_rline[k] )
                ,
                .ras_dp_err_inj  (ras_dp_err_inj_acc_qdw_rline)
                );
    end
endgenerate

// ras dp err mgr for NQW_R.  This itself can go upto 16 with 2 interface output per queue into 1024 bit interface.
ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N         (NQW_R),
    .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1)
) u_ras_dp_err_mgr_acc_qdw_rline (
    .clk                (core_clk),
    .rst_n              (core_rst_n),
    .out_ras_dp_wake_up (out_ras_dp_wake_up[2]),
    .in_ras_dp_err_inj  (ras_dp_err_inj),
    .out_ras_dp_err_inj (ras_dp_err_inj_acc_qdw_rline),
    .in_ras_dp_err_log  (ras_dp_err_log_acc_qdw_rline),
    .out_ras_dp_err_log (ras_dp_err_log[2])
);
//////////////////////////////////////////////////////////////////////////////
// Update of the load size value and mask based on the extra read data
//
//////////////////////////////////////////////////////////////////////////////
assign int_load_rsize_updated      = |extra_qdw_rd_enable && ((next_load_rsize_delay != 0)||(extra_qdw_rd_data_eot[0])) ? next_load_rsize_delay + 1  : next_load_rsize_delay;

  assign int_interface_mask_delay[0] = |extra_qdw_rd_enable && ((next_load_rsize_delay != 0)||(extra_qdw_rd_data_eot[0])) ? {interface_mask_delay[0][NQW_R-2:0],1'b1} : interface_mask_delay[0];

logic  [FORMQ_RD_PORTS-1:0][(HW+RADM_HDR_PROT_WD)-1:0] next_form_filt_hdr_int;

 always_comb begin : next_form_filt_header_PROC
  logic[FORMQ_RD_PORTS-1:0][1:0] h; 
  logic[FORMQ_RD_PORTS-1:0][1:0] mid_index;
  for(int j=0; j<FORMQ_RD_PORTS; j++)begin
      next_form_flit_p_pkt_num[j] = form_flit_p_pkt_num[j];
      next_form_filt_hv[j]    = '0;
      next_form_filt_hdwen[j] = '0;
      next_form_filt_hdr_int[j]   = '0;
      h[j]=0;
      mid_index[j] = 0;
      header_dws_within_qdw[j] = '0;

      for(int i=0; i<NQW_R/2; i++) begin 
          if( i < int_load_rsize_updated ) begin 
            if(int_interface_mask_delay[j][i]) begin
              if(acc_qdw_rline[i][HV_POS]) begin
                 mid_index[j]=mid_index[j]+1;
              end
            end // end for if interface check  
          end // if for load size
      end // for loop end for i
   end   

  for(int j=0; j<FORMQ_RD_PORTS; j++)begin
     
      for(int i=0; i<NQW_R/2; i++) begin 
          if( i < int_load_rsize_updated ) begin 
            if(int_interface_mask_delay[j][i]) begin
              if(acc_qdw_rline[i][HV_POS]) begin
                next_form_flit_p_pkt_num[j] = acc_qdw_rline[i][P_PKT_POS +: PKT_ORD_WD]; 
                next_form_filt_hv[j] = 1'b1;
                next_form_filt_hdr_int[j][h[j]*QW_DS +: HDR_DS]  = acc_qdw_rline[i][HDR_DS-1:0];
                next_form_filt_hdwen[j][h[j]*4 +: 4] = header_dwen_map(acc_qdw_rline[i][HWEN_POS +: 2]);
                h[j]=h[j]+1;    
              end
              if(acc_qdw_rline[i][HV_POS +: 1] && acc_qdw_rline[i][DV_POS +: 1])
                header_dws_within_qdw[j] = acc_qdw_rline[i][HWEN_POS +: 2]; 
            end // end for if interface check  
          end // if for load size
      end // for loop end for i
  
      for(int i=NQW_R/2; i<NQW_R; i++) begin 
          if( i < int_load_rsize_updated ) begin 
            if(int_interface_mask_delay[j][i]) begin
              if(acc_qdw_rline[i][HV_POS]) begin
                next_form_flit_p_pkt_num[j] = acc_qdw_rline[i][P_PKT_POS +: PKT_ORD_WD]; 
                next_form_filt_hv[j] = 1'b1;
                next_form_filt_hdr_int[j][mid_index[j]*QW_DS +: HDR_DS]  = acc_qdw_rline[i][HDR_DS-1:0];
                next_form_filt_hdwen[j][mid_index[j]*4 +: 4] = header_dwen_map(acc_qdw_rline[i][HWEN_POS +: 2]);
                mid_index[j]=mid_index[j]+1;    
              end
              if(acc_qdw_rline[i][HV_POS +: 1] && acc_qdw_rline[i][DV_POS +: 1])
                header_dws_within_qdw[j] = acc_qdw_rline[i][HWEN_POS +: 2]; 
            end // end for if interface check  
          end // if for load size
      end // for loop end for i

    end // for loop end for J
 end // for always block 

always_comb begin : hdr_dw_reset_PROC
  next_form_filt_hdr = '0;
     for(int i=0; i<FORMQ_RD_PORTS; i++)begin
     for(int j=0; j<NHW; j++)begin
       if(next_form_filt_hdwen[i][j]) 
         next_form_filt_hdr[i][j*32 +:32] = next_form_filt_hdr_int[i][j*32 +:32]; 
       else
         next_form_filt_hdr[i][j*32 +:32] = '0;
     end
     end
end


localparam HDR_PROT_WD = HW/PROT_RANGE;
logic  [FORMQ_RD_PORTS-1:0][HDR_PROT_WD-1:0]      next_form_filt_hdr_prot;
// parity generate module instance without pipe delay
generate
    for (genvar k = 0; k < FORMQ_RD_PORTS; k++)begin : g_rasdp_hdr
 
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
                .PROT_WD                 (HDR_PROT_WD),
                .PARITY_MODE             (PARITY_MODE),             // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),             // No correction
                .TOTAL_WIDTH             (HW),           //  
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (0)
            ) u_ras_dp_pipe (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (next_form_filt_hv[k]   ),
                .din      (next_form_filt_hdr[k][HW-1:0] ),
                .din_prot ('0                 ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(next_form_filt_hdr_prot[k]   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );
    end
endgenerate

// mapping of data dws from read QDW 
always_comb begin : int_next_form_filt_data_PROC
    logic[FORMQ_RD_PORTS-1:0][RAM_IW-1:0] d; 
 for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    int_next_form_filt_dv[j] = 0;
    int_next_form_filt_dwen[j] = 0;
    int_next_form_filt_data[j] = 0;
    int_next_form_filt_data_parity[j] = 0;
    d[j]=0;
 end   
    for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    for(int i=0; i<NQW_R; i++) begin 
        if( i < int_load_rsize_updated ) begin // use a delayed "load" to match the read latency on the data from the ram
          if(int_interface_mask_delay[j][i]) begin
            if(acc_qdw_rline[i][DV_POS +: 1] && (!(mac_qdw_read_en_r[i] ))) begin
                int_next_form_filt_dv[j] = 1'b1;
                int_next_form_filt_data[j][d[j]*QW_DS +: DATA_DS] = acc_qdw_rline[i][DATA_DS-1:0];
                int_next_form_filt_dwen[j][d[j]*4 +: 4] = data_dwen_map(acc_qdw_rline[i][HWEN_POS +: 2],acc_qdw_rline[i][DWEN_POS +: 2]);
                int_next_form_filt_data_parity[j][d[j]*16 +: 16] = acc_qdw_rline[i][DATA_DS+16-1:DATA_DS];
                d[j]++;
              end
          end // end for if interface check  
        end // if for load size
    end // for loop end for i
    end // for loop end for J
  end // for always block  

// Packing of the data for output data interface
always_comb begin
  for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    int_next_form_filt_data_packed[j] = int_next_form_filt_data[j];
    int_next_form_filt_dwen_packed[j] = int_next_form_filt_dwen[j];
    int_next_form_filt_data_parity_packed[j] = int_next_form_filt_data_parity[j];
    casez(int_next_form_filt_dwen[j][3:0]) 
      4'b??10    : begin 
                  int_next_form_filt_data_packed[j] = {32'h0,int_next_form_filt_data[j][((DW)-1)+128:32]};
                  int_next_form_filt_dwen_packed[j] = {1'b0,int_next_form_filt_dwen[j][(NW-1)+4:1]};
                  int_next_form_filt_data_parity_packed[j] = {4'h0, int_next_form_filt_data_parity[j][(((NW/4)+1)*16-1):4]};
                  end
                
      4'b?100    : begin 
                  int_next_form_filt_data_packed[j] = {64'h0,int_next_form_filt_data[j][((DW)-1)+128:64]};
                  int_next_form_filt_dwen_packed[j] = {2'b00,int_next_form_filt_dwen[j][(NW-1)+4:2]};
                  int_next_form_filt_data_parity_packed[j] = {8'h0, int_next_form_filt_data_parity[j][(((NW/4)+1)*16-1):8]};
                 end
                 
      4'b1000    : begin 
                  int_next_form_filt_data_packed[j] = {96'h0,int_next_form_filt_data[j][((DW)-1)+128:96]};
                  int_next_form_filt_dwen_packed[j] = {3'b000,int_next_form_filt_dwen[j][(NW-1)+4:3]};
                  int_next_form_filt_data_parity_packed[j] = {12'h0, int_next_form_filt_data_parity[j][(((NW/4)+1)*16-1):12]};
                 end
      default : begin 
                  int_next_form_filt_data_packed[j] = int_next_form_filt_data[j];
                  int_next_form_filt_dwen_packed[j] = int_next_form_filt_dwen[j];
                  int_next_form_filt_data_parity_packed[j] = int_next_form_filt_data_parity[j];
                  end    
    endcase
    
  end
end

// start of the data DW within merged QDW.
always_comb begin
  for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    data_dw_start_in_extra_qdw[j] = |header_dws_within_qdw[j] ? header_dws_within_qdw[j] : extra_qdw_rd_data_start[j];  
  end
end

always @(posedge core_clk or negedge core_rst_n) begin : Local_QDW_PROC
  if(!core_rst_n) begin
  for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    extra_qdw_rd_data[j]              <= #TP 0;
    extra_qdw_rd_data_parity[j]       <= #TP 0;
    extra_qdw_rd_data_dwen[j]         <= #TP 0;   
    extra_qdw_rd_data_start[j]        <= #TP 0;
    extra_qdw_rd_data_eot[j]          <= #TP 0;
    extra_qdw_rd_enable[j]                    <= #TP 0;  
    extra_qdw_rd_data_dllp_err[j]     <= #TP 0;
    fm_poisoned_with_overreaddata[j]  <= #TP 0;
    fm_nullified_with_overreaddata[j] <= #TP 0;
  end  
  end else begin
  for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    // need to hold the updates for overreaddata in case there is halt or no read from retister array in next clock
    if(!filt_form_halt_en && ((next_load_rsize_delay != 0) || (extra_qdw_rd_data_eot[j])) ) begin
      extra_qdw_rd_enable[j]                   <= #TP (|int_next_form_filt_dwen_packed[j][(NW-1)+4:NW]);   
      extra_qdw_rd_data[j]             <= #TP eot_in_current_clock[j] ? int_next_form_filt_data_packed[j][((DW)-1)+128:(DW)] :
                                                                (int_next_form_filt_data_packed[j][((DW)-1)+128:(DW)] << (data_dw_start_in_extra_qdw[j]*32));
      extra_qdw_rd_data_parity[j]      <= #TP eot_in_current_clock[j] ? int_next_form_filt_data_parity_packed[j][(((NW/4)+1)*16-1):((NW/4)*16)] :
                                                                  (int_next_form_filt_data_parity_packed[j][(((NW/4)+1)*16-1):((NW/4)*16)] << (data_dw_start_in_extra_qdw[j]*4));
      extra_qdw_rd_data_dwen[j]        <= #TP eot_in_current_clock[j] ? int_next_form_filt_dwen_packed[j][(NW-1)+4:NW] :
                                                                (int_next_form_filt_dwen_packed[j][(NW-1)+4:NW] << data_dw_start_in_extra_qdw[j])  ; 
      extra_qdw_rd_data_start[j]       <= #TP eot_in_current_clock[j] ? 0 : (|header_dws_within_qdw[j] ? header_dws_within_qdw[j] : extra_qdw_rd_data_start[j]);    
      extra_qdw_rd_data_eot[j]         <= #TP eot_in_current_clock[j];
      extra_qdw_rd_data_dllp_err[j]    <= #TP dllp_err_in_current_clock[j];
      fm_poisoned_with_overreaddata[j] <= #TP fm_poisoned_in_current_clock[j];
      fm_nullified_with_overreaddata[j]<= #TP fm_nullified_in_current_clock[j];
    end // if hold condition end
  end // for loop end
 end // always else end
end // always end    

// mapping of data for the output interfaces
always_comb begin : next_form_filt_data_PROC
 for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    next_form_filt_data_only[j] = 0;
    next_form_filt_dv[j]   =   int_next_form_filt_dv[j];
    next_form_filt_data_only[j] = int_next_form_filt_data_packed[j][(DW)-1:0];
    next_form_filt_dwen[j] =   int_next_form_filt_dwen_packed[j][NW-1:0];
 end   
end // for always block  


// map eot and dllp errors for output interfaces.
always_comb begin : next_form_filt_eot_PROC
 for(int j=0; j<FORMQ_RD_PORTS; j++)begin
   eot_in_current_clock[j]        = 0;
   next_form_filt_eot[j]          = 0;
   next_form_filt_dllp_err[j] = 0;
   next_form_filt_poisoned[j] = 0;
   next_form_filt_nullified[j] = 0;
   dllp_err_in_current_clock[j] = 0;
   fm_poisoned_in_current_clock[j] = 0;
   fm_nullified_in_current_clock[j] = 0;     
 end  
    for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    for(int i=0; i<NQW_R; i++) begin 
      if( i < int_load_rsize_updated ) begin 
        if(int_interface_mask_delay[j][i]) begin
          if(acc_qdw_rline[i][EOT_POS +: 1]) begin
             eot_in_current_clock[j] = 1'b1;
             dllp_err_in_current_clock[j] = acc_qdw_rline[i][ERR_POS];
             fm_poisoned_in_current_clock[j] = acc_qdw_rline[i][POISONED_POS];
             fm_nullified_in_current_clock[j] = acc_qdw_rline[i][NULLIFIED_POS];    
             // Need to postpone the EOT and dllp_err by 1 clock when memory overread 
             // is done and there is pending data to transmit on next clock cycle
             next_form_filt_eot[j]       = (|int_next_form_filt_dwen_packed[j][(NW-1)+4:NW]) ? 1'b0 : 1'b1;
             next_form_filt_dllp_err[j]  = (|int_next_form_filt_dwen_packed[j][(NW-1)+4:NW]) ? 1'b0 : acc_qdw_rline[i][ERR_POS];
             next_form_filt_poisoned[j]  = (|int_next_form_filt_dwen_packed[j][(NW-1)+4:NW]) ? 1'b0 : acc_qdw_rline[i][POISONED_POS];
             next_form_filt_nullified[j] = (|int_next_form_filt_dwen_packed[j][(NW-1)+4:NW]) ? 1'b0 : acc_qdw_rline[i][NULLIFIED_POS];
            end
          end // end for if interface check  
        end // if for load size
      end // for loop end for i
    end // for loop end for J
end // for always block  
///////////////////////////////////////////////////////////////////////////
// Pipeline stages before output to the next stage filters.
//
///////////////////////////////////////////////////////////////////////////
// ctrl output pipeline
localparam CTRL_OUTPUT_PIPE_WD  = (3+PKT_ORD_WD) * FORMQ_RD_PORTS; // pkt_no + hv + dv + eot
localparam VFINDEX_REGOUT = 0;

delay_n_w_enable
 #(1, CTRL_OUTPUT_PIPE_WD) u_delay_n_ctrl_output_pipe
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         ((!filt_form_halt_en) ), 
    .din        ({next_form_flit_p_pkt_num, next_form_filt_hv, next_form_filt_dv, next_form_filt_eot  }),
    .dout       ({form_flit_p_pkt_num,     form_filt_hv_int,      form_filt_dv_int,      form_filt_eot_int })
);

assign form_filt_hv = form_filt_hv_int ; 
assign form_filt_dv = form_filt_dv_int ;
assign form_filt_eot = form_filt_eot_int;

////////////////////////////////////////////////////
// parity generation for data

logic  [FORMQ_RD_PORTS-1:0][DATA_PROT_WD-1:0]      next_form_filt_data_prot;
// parity generate module instance without pipe delay
generate
    for (genvar k = 0; k < FORMQ_RD_PORTS; k++)begin : g_rasdp_data
 
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
                .PROT_WD                 (DATA_PROT_WD),
                .PARITY_MODE             (PARITY_MODE),                 // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),                 // No correction
                .TOTAL_WIDTH             (DW),                //  
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (0)
            ) u_ras_dp_pipe (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (next_form_filt_dv[k]                  ),
                .din      (next_form_filt_data_only[k][DW-1:0] ),
                .din_prot ('0                 ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(next_form_filt_data_prot[k]   ),
                .halt_in  (1'b0                  ),
                .ras_dp_err_inband_kbd_in(1'b0   ),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );
    end
endgenerate

// mapping of data for the output interfaces
always_comb begin : next_form_filt_data_PROC_1
 for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    next_form_filt_data[j] = { next_form_filt_data_prot[j] , next_form_filt_data_only[j]};
 end   
end // for always block  
///////////////////////////////////////////////
// MAC , PCRC or ECRC data interface mapping
//

// mapping of mac qdw on output interface.
always_comb begin : next_form_filt_header_PROC1
 for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    next_form_filt_mac_data_int[j] = 0;
    next_form_filt_mac_size[j] = 0;
 end   
  for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    for(int i=0; i<NQW_R; i++) begin 
        if( i < int_load_rsize_updated ) begin 
          if(int_interface_mask_delay[j][i]) begin
            if(mac_qdw_read_en_r[i] ) begin
              next_form_filt_mac_data_int[j] = acc_qdw_rline[i][HDR_DS-1:0]; 
              next_form_filt_mac_size[j] = acc_qdw_rline[i][DWEN_POS +: 2] == 0 ? 3'h4 : {1'b0, acc_qdw_rline[i][DWEN_POS +: 2]} ;
            end // end for if condition  
          end // end for if interface check  
        end // if for load size
    end // for loop end for i
    end // for loop end for J
  end // for always block  


logic  [FORMQ_RD_PORTS-1:0][QDW_PAR-1:0]               next_form_filt_mac_data_prot;
// parity generate module instance for mac data
generate
    for (genvar k = 0; k < FORMQ_RD_PORTS; k++)begin : g_rasdp_mac_data
 
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
                .PROT_WD                 (QDW_PAR),
                .PARITY_MODE             (PARITY_MODE),                 // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),                 // No correction
                .TOTAL_WIDTH             (QDW_DW),                //  
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (0)
            ) u_ras_dp_pipe (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (|next_form_filt_mac_size[k]         ),
                .din      (next_form_filt_mac_data_int[k]      ),
                .din_prot ('0                 ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(next_form_filt_mac_data_prot[k]   ),
                .halt_in  (1'b0                  ),
                .ras_dp_err_inband_kbd_in(1'b0   ),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );
    end
endgenerate

// mapping of data for the output interfaces
always_comb begin : next_form_filt_mac_data_PROC_1
 for(int j=0; j<FORMQ_RD_PORTS; j++)begin
    next_form_filt_mac_data[j] = { next_form_filt_mac_data_prot[j] , next_form_filt_mac_data_int[j]};
 end   
end // for always block  

// output pipeline
localparam OUTPUT_PIPE_WD  = FORMQ_RD_PORTS*(DW+DATA_PROT_WD) +   // next_form_filt_data
                             FORMQ_RD_PORTS*NW +   // next_form_filt_dwen
                             FORMQ_RD_PORTS        // next_form_filt_dllp_err
                             + FORMQ_RD_PORTS      // next_form_filt_poisoned
                             + FORMQ_RD_PORTS      // next_form_filt_nullified
                             + FORMQ_RD_PORTS*(QDW_DW+QDW_PAR)
                             + FORMQ_RD_PORTS*3
                             ;

assign form_filt_reg_en = ((|next_form_filt_hv) || (|next_form_filt_dv)) && (!filt_form_halt_en) ; 

delay_n_w_enable

 #(1, OUTPUT_PIPE_WD ) u_delay_n_output_pipe
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (form_filt_reg_en),
    .din        ({ next_form_filt_data, next_form_filt_dwen,  next_form_filt_dllp_err , next_form_filt_poisoned, next_form_filt_nullified ,next_form_filt_mac_data, next_form_filt_mac_size}),
    .dout       ({ form_filt_data, form_filt_ddwen, int_form_filt_dllp_err , form_filt_poisoned, form_filt_nullified, form_filt_mac_data, form_filt_mac_size })
);

assign form_filt_dllp_err = int_form_filt_dllp_err  | form_filt_nullified ;

localparam HDR_OUTPUT_PIPE_WD  = (HW+RADM_HDR_PROT_WD) + // next_form_filt_hdr
                                 NHW                   + // next_form_filt_hwen
                                 `CX_NPRFX*32          + // next_form_filt_prfx
                                 `CX_RX_HDW_MS*32      + // next_form_filt_header
                                 `CX_RX_HDW_MS           // next_form_filt_header_dwen
                                 ;

always_comb begin : hdr_info_reg_PROC
  for(int i=0;i<FORMQ_RD_PORTS;i++) begin
    form_filt_hdr_reg_en[i] = next_form_filt_hv[i] && (!filt_form_halt_en) ; 
  end
end


generate
    for (genvar i = 0; i < FORMQ_RD_PORTS; i++)begin : g_header_pipe
delay_n_w_enable

 #(1, HDR_OUTPUT_PIPE_WD ) u_delay_n_hdr_out_pipe
(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (form_filt_hdr_reg_en[i]),

    .din        ({ next_form_filt_prfx[i], next_form_filt_header[i], next_form_filt_header_dwen[i], next_form_filt_hdr_prot[i], next_form_filt_hdr[i][HW-1:0], next_form_filt_hdwen[i][NHW-1:0]}),
    .dout       ({      form_filt_prfx[i],      form_filt_header[i],      form_filt_header_dwen[i],                                                               form_filt_hdr[i],              form_filt_hdwen[i]         })
);
end
endgenerate


/////////////////////////////////////////////////////
// Data length decoding for TLP packet.
//
/////////////////////////////////////////////////////
always_comb begin : hdr_prefix_count_PROC
  for(int i=0;i<FORMQ_RD_PORTS;i++) begin
    hdr_prefix_counts[i] = check_prefixes(flit_mode_en,next_form_filt_hdr[i][256-1 : 0]);  // Maximum of 7 prefixes are supported
  end
end  

always_comb begin : hdr_dw1_PROC
  for(int i=0;i<FORMQ_RD_PORTS;i++) begin
    hdr_dw1[i] = next_form_filt_hdr[i][hdr_prefix_counts[i]*32 +:32];
  end
end

logic   [FORMQ_RD_PORTS-1:0][3:0]    hdwe_count;
always_comb begin : HDR_DWEN_COUNT_PROC
  hdwe_count = '0;
  for(int i=0; i<FORMQ_RD_PORTS ; i++)
    for(int j=0;j<NHW;j++)
      if(next_form_filt_hdwen[i][j])
        hdwe_count[i] = hdwe_count[i] + 1'b1;
end 

logic [FORMQ_RD_PORTS-1:0] no_hdr_dws;
always_comb begin : no_hdr_dw_PROC
  no_hdr_dws = '0;
  for(int i=0; i<FORMQ_RD_PORTS ; i++)
    no_hdr_dws[i] = (hdwe_count[i] == {1'b0,hdr_prefix_counts[i]});
end 

// Extract type and len fields from first header DW
logic [FORMQ_RD_PORTS-1:0][7:0]  f_type; // Header type
logic [FORMQ_RD_PORTS-1:0][9:0]  f_len;  // Length
always_comb begin  
  for(int i=0;i<FORMQ_RD_PORTS;i++) begin
    f_type[i] = (flit_mode_en)? hdr_dw1[i][7:0] : hdr_dw1[i][7:0]; // in NON Flit mode added FMT[2] also. FMT[2] bit is considered in Filter and radm_pkt_adj module to calculate creadits
    f_len[i]  = {hdr_dw1[i][17:16], hdr_dw1[i][31:24]};
  end  
end  

// Data length decoding
logic [FORMQ_RD_PORTS-1:0][10:0] form_filt_hdr_data_length_int;
generate
  for (genvar i=0; i<FORMQ_RD_PORTS; i++) begin : data_len_gen
    assign form_filt_hdr_data_length_int[i] = calc_tlp_data_len(f_type[i], f_len[i], flit_mode_en);
  end
endgenerate


logic  [FORMQ_RD_PORTS-1:0]   rsvd_tlp; 
always @(posedge core_clk or negedge core_rst_n) begin  
  if(!core_rst_n) begin
    form_filt_hdr_data_length <= #TP '0;
    rsvd_tlp                  <= #TP '0;
  end else begin
    for(int i=0;i<FORMQ_RD_PORTS;i++) begin
      if(form_filt_hdr_reg_en[i]) begin
        form_filt_hdr_data_length[i] <= #TP no_hdr_dws[i] ? '0 : form_filt_hdr_data_length_int[i];
        rsvd_tlp[i]                  <= #TP no_hdr_dws[i] ? 1'b1 : flit_mode_en ? 1'b0 : (hdr_dw1[i][7:5] == 3'b111);
      end
    end
  end  
end  

/////////////////////////////////////////////////////
// Credit Release Management for the Formation queue.
//
/////////////////////////////////////////////////////
localparam DCA = (NW/4); // Max number of data credits that can be returned in one cycle

always @(posedge radm_clk_ug or negedge core_rst_n)
if(!core_rst_n)
  radm_rtlh_h_ca <= #TP '0;
else begin
  for(int i=0;i<FORMQ_RD_PORTS;i++) begin
    radm_rtlh_h_ca[i] <= #TP form_filt_eot[i] &&  (~int_form_filt_dllp_err[i] ) && (~filt_form_halt_en)  && (~rsvd_tlp[i]); 
  end
end

logic  [FORMQ_RD_PORTS-1:0][10:0]          interface_data_credits;  
always_comb begin : interface_data_credits_PROC
  for(int i=0;i<FORMQ_RD_PORTS;i++) begin
    interface_data_credits[i] = form_filt_hdr_data_length[i][10:2] + (|form_filt_hdr_data_length[i][1:0] ? 1 : 0) ;
  end
end

always_comb begin : data_credits_consumed_PROC
  data_credits_consumed = '0;
  for(int i=0;i<FORMQ_RD_PORTS;i++) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: data_credits_consumed size is more than required by 1 bit. So possibility of overflow.  
    data_credits_consumed = data_credits_consumed + interface_data_credits[i];
  end
// spyglass enable_block W164a
end

// SMD: LHS width is greater than the RHS width 
// SJ: LHS is oversized when avail_pd_crd is less than 1 but there is no functional issue.
// spyglass disable_block W164b
assign  radm_rtlh_d_ca           =  (avail_data_crd >= DCA) ? DCA : |avail_data_crd ;
// spyglass enable_block W164b

assign  update_credit_bucket = form_filt_eot[0] && (~int_form_filt_dllp_err[0]) && (~filt_form_halt_en) && (~rsvd_tlp[0]);

// credits that can be returned
always @(posedge radm_clk_ug or negedge core_rst_n)
if(!core_rst_n)
  avail_data_crd <= #TP  0;
else
  begin
  case({|radm_rtlh_d_ca,update_credit_bucket})
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ:  By design "avail_data_crd" cannot overflow. credits
// are returned for the previous TLP while the credits are added for the current TLP.
    2'b01  : avail_data_crd <= #TP avail_data_crd + data_credits_consumed ;
    2'b10  : avail_data_crd <= #TP avail_data_crd - radm_rtlh_d_ca;
    2'b11  : avail_data_crd <= #TP avail_data_crd - radm_rtlh_d_ca + data_credits_consumed ;
// spyglass enable_block W164a
    2'b00  : avail_data_crd <= #TP avail_data_crd ;
  endcase
end

///////////////////////////////////////////////////////
// Pack ouputs for the Formation to Filter Interface
///////////////////////////////////////////////////////
assign rxq_tlp[P0].tlp.hdr.hv          = form_filt_hv;
assign rxq_tlp[P0].tlp.hdr.hdr         = form_filt_hdr;
assign rxq_tlp[P0].tlp.hdr.dwen        = form_filt_hdwen;
assign rxq_tlp[P0].tlp.hdr.prfx        = form_filt_prfx;
assign rxq_tlp[P0].tlp.hdr.header      = form_filt_header;
assign rxq_tlp[P0].tlp.hdr.header_dwen = form_filt_header_dwen;
assign rxq_tlp[P0].tlp.hdr.prot        = {{(RADM_HDR_PROT_WD-(`CX_RX_HDW_MS*4)){1'b0}}, form_filt_hdr[P0][HW +: `CX_RX_HDW_MS*4]};
assign rxq_tlp[P0].tlp.hdr.p_pkt_num   = form_flit_p_pkt_num;
assign rxq_tlp[P0].tlp.data.dv         = form_filt_dv;
assign rxq_tlp[P0].tlp.data.data       = form_filt_data;
assign rxq_tlp[P0].tlp.data.dwen       = form_filt_ddwen;
assign rxq_tlp[P0].tlp.ctl.eot         = form_filt_eot;
assign rxq_tlp[P0].tlp.ctl.dllp_err    = form_filt_dllp_err;
assign rxq_tlp[P0].tlp.ctl.tlp_err     = 1'b0;
assign rxq_tlp[P0].tlp.ctl.fm_poisoned = form_filt_poisoned;
assign rxq_tlp[P0].mac_data            = form_filt_mac_data;
assign rxq_tlp[P0].mac_size            = form_filt_mac_size;
assign rxq_tlp[P0].hdr_data_length     = form_filt_hdr_data_length[P0];
assign rxq_tlp[P0].q_not_empty         = radm_formq_not_empty;

// Driven in the IDE wrapper

///////////////////////////////////////////////////////
// Common Functions
///////////////////////////////////////////////////////

function automatic [RAM_IW-1:0] mod_nqw(input [RAM_IW-1:0] data);
    begin
        mod_nqw = data % NQW; 
    end
endfunction

// function to decode prefixes before first header dw 
function  automatic [2:0] check_prefixes;
  input               flit_mode_en;
  input   [256-1:0]   data;                // Input QDWs data
  integer             p;
  reg     [7:0]       tlp_types_in_qdw;    // type field decoding from header DW  
  reg     [2:0]       prefix_count;        // prefix received count within QDW
  reg                 prf_chk_end;         // prefix check is disabled within QDW once there is no decoding of the prefix from LSB side. To avoid wrong detection of prefix for header DW.
  reg                 prefix_detected;

  begin
    prefix_count   = 3'b000;
    check_prefixes = 2'b00;
    prf_chk_end    = 1'b0;
    for(p=0;p<8;p=p+1) begin
      tlp_types_in_qdw = data[(p*32) +:8] ;
      prefix_detected =  flit_mode_en ? ((tlp_types_in_qdw[7:5] == FLIT_PREFIX) && !tlp_types_in_qdw[4]) :
                                         (tlp_types_in_qdw[7:5] == FLIT_PREFIX);
       if(prefix_detected && !prf_chk_end) 
         prefix_count = prefix_count + 3'b001; 
      else
        prf_chk_end  = 1'b1;
    end  
    check_prefixes = prefix_count;
  end
endfunction


function automatic [RAM_PW-1:0] incr_plus_1(input [RAM_PW-1:0] addr);
    begin
        incr_plus_1 = (addr == (RAM_DP-1'b1)) ? 0 : (addr+1'b1);
    end
endfunction

// adder modulo ram depth
function automatic [RAM_PW+RAM_IW-1:0] add_mod_ram_dp_nqw(input [RAM_PW+RAM_IW-1:0] addrx, input [RAM_RD_WR_WD-1:0] incr_size);
    begin
        logic [RAM_PW+RAM_IW:0] addrx_tmp; 
        addrx_tmp = {1'b0,addrx} + { {RAM_PW+1{1'b0}}, incr_size};
        addrx_tmp = (addrx_tmp<RAM_DP*NQW) ?  addrx_tmp : addrx_tmp - RAM_DP*NQW;
        add_mod_ram_dp_nqw = addrx_tmp[RAM_PW+RAM_IW-1:0];
    end
endfunction

// header dw counts from header dw enable.
function  automatic [1:0] header_dw_count;
input    [3:0]    Dwen;
// hdwen can be 0 on the MSB side and never on lsb side.   
case(Dwen)
  4'b0001 : header_dw_count = 2'b01;
  4'b0011 : header_dw_count = 2'b10;
  4'b0111 : header_dw_count = 2'b11;
  default : header_dw_count = 2'b00;
endcase
endfunction

// data dw counts from data dw enable.
function  automatic [1:0] data_dw_counts;
input    [3:0]    Dwen;
// dwen can be 0 on the MSB side with independent data QDW and on the LSB side when mixed with header QDW.
case(Dwen)
  4'b0001 : data_dw_counts = 2'b01;   // QDW as 000D with EOT. 
  4'b0010 : data_dw_counts = 2'b01;   // QDW as 00DH with EOT.
  4'b0100 : data_dw_counts = 2'b01;   // QDW as 0DHH with EOT.
  4'b1000 : data_dw_counts = 2'b01;   // QDW as DHHH with or without EOT.

  4'b0011 : data_dw_counts = 2'b10;   // QDW as 00DD with Eot
  4'b0110 : data_dw_counts = 2'b10;   // QDW as 0DDH with EOT.
  4'b1100 : data_dw_counts = 2'b10;   // QDW as DDHH with or without EOT.

  4'b0111 : data_dw_counts = 2'b11;   // QDW as 0DDD with Eot
  4'b1110 : data_dw_counts = 2'b11;   // QDW as DDDH with or without EOT. 
  default : data_dw_counts = 2'b00;   // QDW as DDDD with or without EOT.
endcase
endfunction

// header dwen conversion from binary to onehot
function  automatic [3:0] header_dwen_map;
input    [1:0]    header_dw_count;
// hdwen can be 0 on the MSB side and never on lsb side.   
case(header_dw_count)
  2'b01 : header_dwen_map   = 4'b0001;
  2'b10 : header_dwen_map   = 4'b0011;
  2'b11 : header_dwen_map   = 4'b0111;
  default : header_dwen_map = 4'b1111;
endcase
endfunction

// Data dwen conversion from binary to onehot
function  automatic [3:0] data_dwen_map;
input    [1:0]    header_dw_count; 
input    [1:0]    DataDws;
case(DataDws)
  2'b01 : case(header_dw_count)
            2'b01   : data_dwen_map = 4'b0010; // QDW as 00DH with EOT.
            2'b10   : data_dwen_map = 4'b0100; // QDW as 0DHH with EOT.
            2'b11   : data_dwen_map = 4'b1000; // QDW as DHHH with or without EOT. 
            default : data_dwen_map = 4'b0001; // QDW as 000D with EOT.
          endcase 
  2'b10 : case(header_dw_count)
            2'b01   : data_dwen_map = 4'b0110; // QDW as 0DDH with EOT.
            2'b10   : data_dwen_map = 4'b1100; // QDW as DDHH with EOT.
            default : data_dwen_map = 4'b0011; // QDW as 00DD with EOT.
          endcase 
  2'b11 : case(header_dw_count)
            2'b01   : data_dwen_map = 4'b1110; // QDW as DDDH with EOT.
            default : data_dwen_map = 4'b0111; // QDW as 0DDD with EOT.
          endcase 
  default : data_dwen_map = 4'b1111;
endcase
endfunction


logic [FORMQ_RD_PORTS-1:0][NHW-1:0] maybe_prfx;
always_comb begin : raw_type_PROC
    maybe_prfx  = '0;
    for(int i=0; i<FORMQ_RD_PORTS; i++)begin
        for(int j=0; j<NHW; j++)begin
            maybe_prfx[i][j] = pcie_pkg::f_decode_prfx_type(next_form_filt_hdr_int[i][j*32 +:8], flit_mode_en);
        end
    end
end

always_comb begin : prefix_header_PROC
    reg header_found;
    reg prfx_overflow;
    reg header_overflow;
    reg prfx_full;
    reg header_full;
    reg [`CX_LOGBASE2(NHW)-1:0] i_prfx;
    reg [`CX_LOGBASE2(NHW)-1:0] i_header;

    next_form_filt_prfx        = '0;
    next_form_filt_header      = '0;
    next_form_filt_header_dwen = '0;
    next_form_filt_tlp_err     = '0;
    for(int i=0; i<FORMQ_RD_PORTS; i++)begin
        header_found = 1'b0;
        i_prfx = 0;
        i_header = 0;
        prfx_full = 0;
        header_full = 0;
        prfx_overflow = 0;
        header_overflow = 0;
        // NHW=15
        for(int j=0; j<NHW; j++)begin
            if(next_form_filt_hdwen[i][j]) begin
                if (maybe_prfx[i][j] && !header_found) begin
                    if (i_prfx < `CX_NPRFX) begin
                       next_form_filt_prfx[i][i_prfx[`CX_LOGBASE2(`CX_NPRFX)-1:0]] = next_form_filt_hdr_int[i][j*32 +:32];
                    end
                    i_prfx = i_prfx + 1'b1;
                end else begin
                    if (i_header < `CX_RX_HDW_MS) begin
                       next_form_filt_header[i][i_header[`CX_LOGBASE2(`CX_RX_HDW_MS)-1:0]]      = next_form_filt_hdr_int[i][j*32 +:32];
                       next_form_filt_header_dwen[i][i_header[`CX_LOGBASE2(`CX_RX_HDW_MS)-1:0]] = 1'b1;
                    end  
                    i_header = i_header + 1'b1;
                    header_found = 1'b1;
                end
            end
        end // for NHW

        if (i_prfx >= `CX_NPRFX-1)
           prfx_full = 1'b1;
        if (i_prfx >  `CX_NPRFX-1)
           prfx_overflow = 1'b1;

        // CX_RX_HDW_MS = 8
        if (i_header >= `CX_RX_HDW_MS-1)
            header_full = 1'b1;
        if (i_header >  `CX_RX_HDW_MS-1) 
            header_overflow = 1'b1;
        
        next_form_filt_tlp_err[i] = ~header_found  ||
                                    prfx_overflow  ||
                                    header_overflow; // ToBeConfirmed: maybe radm_filter need a differend flag for FM reserved types
    end // for FORMQ_RD_PORTS
end


endmodule
