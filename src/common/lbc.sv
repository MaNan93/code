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
// ---    $DateTime: 2024/02/01 13:53:24 $
// ---    $Revision: #42 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/lbc.sv#42 $
// -------------------------------------------------------------------------
//
// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//  This module is used in endpoint applications
//  Its main functions are :
//     (1) Process all configuration requests
//     (2) Process memory and IO requests to external application blocks
//     (3) Since RADM has the queue for all requests, This block takes one
//     tlp at a time to process and its latency is dependent upon
//     application or CDM's local bus reply time. The local bus interface
//     is not designed to have the fastest performance based on its nature.
//     (4) This module supports two memory BAR design and one ROM range.
//     For memory rd/wr requests within in the BAR range, this block will
//     output an external local bus interface called lbc_ext*. It can
//     address any internal registers mapped into the BAR range.
//     (5) This module also supports an outband access to internal
//     registers like CDM or others.
//     (6) An interface signal called lbc_cdm_dbi to indicate that current
//     local bus cycle is initiated from outband interface such as dbi
//     (7) An interface signal called lbc_ext_rom_access to indicate that
//     current external local bus access is targetted to ROM base.
//     (8) Total supported memory map range is 4 GB for either BAR0 or
//     BAR1. 2 BARs are supported
//     (9) Both 32bit and 64 bit memory access are supported for 2 BARs.
//     (10) IO access was indicated to external local bus interface through
//     lbc_ext_io_access
//     (11) This block also handles the posted interface from RADM. It
//     sends out to a slave interface when a posted and some types of
//     nonposted requests have targetted to external completer. The
//     requests asserted into the slave interface is expected to be
//     completed by external completer. This module will not be responsible
//     to these requests.
//     (14) lock read will be returned as non supported read request
//     (15) Configuration Intercept Feature
//        - Interrupt to Application when config request is received
//        - provide halt interface to pend proceed config request
//        - provide override interface to modify config write data and read data for config read request
//
// -----------------------------------------------------------------------------

//    Notes:
//         When the application only wants to support one bar, then it should go
//         through this code beneath to delete anything todo with Bar0 so that you
//         can save gates on large comparator etc.
//         The same applies to IO and expansion ROM support. If the design does not support
//         these two, then deletion of the related code is recommendated.

// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"

 module lbc
   (
    // -- inputs --
    core_clk,
    core_rst_n,
    cfg_pbus_num,
    cfg_pbus_dev_num,
    device_type,
    cfg_bar0_mask,
    cfg_bar1_mask,
    cfg_bar2_mask,
    cfg_bar3_mask,
    cfg_bar4_mask,
    cfg_bar5_mask,

    radm_data,
    radm_hdr,
    radm_dv,
    radm_hv,
    radm_fm_np_rsvd,
    radm_eot,
    radm_abort,
    radm_trgt0_pending,


    // local bus interface with external registers,
    ext_lbc_override_en,
    ext_lbc_ack,
    ext_lbc_din,

    // from cdm,
    cdm_lbc_din,
    cdm_lbc_ack,
    cxl_2_0_comp_reg_offset,
    cxl_mbar0_enable,
    cxl_link_enable,
    rcrb_mbar0_base_addr,
    rcrb_base_addr,

    // from  XADM,
    xadm_cpl_halt,

    dbi_addr,
    dbi_din,
    dbi_cs,
    dbi_cs2,
    dbi_wr,
    dbi_ro_wr_en,
    dbi_func_num,
    dbi_rom_access,
    dbi_io_access,
    dbi_bar_num,


    cfg_config_limit,

    ras_err_inj_en_array,
    ras_err_inj_mask,
    //---------- outputs -------------------------,
    ras_err_inj_done,
    lbc_dbi_ack,
    lbc_dbi_dout,
    // to XADM as completion request of device local bus read or write,
    lbc_cpl_hv,
    lbc_cpl_dv,
    lbc_cpl_data,
    lbc_cpl_hdr,
    lbc_cpl_eot,
    // local bus interface with cdm to read registers locally,
    lbc_cdm_addr,
    lbc_cdm_data,
    lbc_cdm_cs,
    lbc_cdm_wr,
    lbc_cdm_dbi,
    lbc_cdm_dbi2,
    lbc_cdm_unroll,
    lbc_cdm_rcrb_wire,
    lbc_cdm_rcrb_mbar0_wire,
    lbc_cdm_rcrb_dbi,
    lbc_cdm_rcrb_mbar0_dbi,

    lbc_xmt_cpl_ca,

    // local bus interface with external registers,
    lbc_ext_addr,
    lbc_ext_dout,
    lbc_ext_valid,
    lbc_ext_cs,
    lbc_ext_dbi_access,
    lbc_ext_cxl_mbar0_access,
    lbc_mbar0_link_cap_access,
    lbc_ext_wr,
    lbc_ext_rd,
    lbc_ext_rom_access,
    lbc_ext_bar_num,
    lbc_ext_io_access,


    pm_l1_aspm_entr,
    rtfcgen_ph_diff,
    lbc_deadlock_det,
    // radm block interface control signal to allow back pressure applied,
    // to radm queues.,
    //,
    trgt0_radm_halt,
    lbc_active

    ,b_cfgi_lbc_pcie
    ,b_cfgi_lbc_cxl
    );
parameter   INST    = 0;            // The uniquifying parameter for each port logic instance.
parameter   NW      = `CX_NW;       // Number of 32-bit dwords handled by the datapath each clock.
parameter   NF      = `CX_NFUNC;    // Number of functions
parameter   NVC     = `CX_NVC;      // Max number of Virtual Channels
parameter   DW      = (32*NW);      // Width of datapath in bits.
parameter   TP      = `TP;          // Clock to Q delay (simulator insurance)
parameter BUSNUM_WD = `CX_BUSNUM_WD;               // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD = `CX_DEVNUM_WD;               // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.



// ----------------------------------------------------------------------------
// --- Parameters
// ----------------------------------------------------------------------------
parameter   LBC_DW               = 32;
parameter   LBC_NW               = `CX_LBC_NW;
parameter   ELBI_WD              = `CX_LBC_NW*32;
parameter   LBC_INT_WD           = `CX_LBC_INT_WD;    // LBC - XADM data bus width can be 32, 64 or 128
parameter   LBC_EXT_AW           = `CX_LBC_EXT_AW;
parameter   LBC_IDLE             = 3'b000;
parameter   LBC_NP_ASSERT        = 3'b010;
parameter   LBC_IN_CPL_REQ       = 3'b011;
parameter   LBC_EXT_DBI_REQ      = 3'b100;
parameter   LBC_RETURN_ERR       = 3'b101;
parameter   RADM_P_HWD           = `RADM_P_HWD;       // Header width
parameter   DATA_PAR_WD          = `TRGT_DATA_PROT_WD;
parameter   ST_HDR               = `ST_HDR;
parameter   HDR_PROT_WD          = 0  
                                   + `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD //extended heade ecc/parity protection width
                                   ;
parameter   RAS_PROT_RANGE       = `CX_RAS_PROT_RANGE;
parameter   RAS_PROT_TYPE        = `CX_RAS_PROT_TYPE;
parameter   RAS_PARITY_MODE      = `CX_RAS_PARITY_MODE;
parameter   ERROR_INJ_EN_WD      = `CX_RAS_ERROR_INJ_EN_WD;
parameter   ERROR_INJ_MASK_WD    = `CX_RAS_ERROR_INJ_MASK_WD;
parameter   DEVICE_TYPE          = `CX_DEVICE_TYPE;
parameter   NFUNC_WD             = `CX_NFUNC_WD;
localparam ATTR_WD               = `FLT_Q_ATTR_WIDTH;
localparam PCI_CONFIG_MAX        = 10'h03f;

localparam SPIF_NCFG             = `CX_SPIF_NCFG;

localparam TAG_SIZE              = `CX_TAG_SIZE;
localparam SRIOV_EN              = 0;
localparam IDE_EN                = 0;

//         32 Bit Address Decode             b0000_0000_0000_0XXX_0000_XXXX_XXXX_XX00
localparam SPIF_CFG_CDM_ACCESS_MASK     = 32'b1111_1111_1111_1000_1111_0000_0000_0011;
localparam SPIF_CFG_CDM_ACCESS_DECODE   = 32'b0000_0000_0000_0000_0000_0000_0000_0000;


// -------------------------------- Inputs ------------------------------------
input                        core_clk;                   // Core clock
input                        core_rst_n;                 // Core reset
input    [BUSNUM_WD -1:0]    cfg_pbus_num;
input    [DEVNUM_WD -1:0]    cfg_pbus_dev_num;
input    [3:0]    device_type;
input [(64*NF)-1:0]          cfg_bar0_mask;              // BAR0 mask register
input [(32*NF)-1:0]          cfg_bar1_mask;              // BAR1 mask register
input [(64*NF)-1:0]          cfg_bar2_mask;              // BAR2 mask register
input [(32*NF)-1:0]          cfg_bar3_mask;              // BAR3 mask register
input [(64*NF)-1:0]          cfg_bar4_mask;              // BAR4 mask register
input [(32*NF)-1:0]          cfg_bar5_mask;              // BAR5 mask register


input [DW-1:0]               radm_data;                  // Received request TLP data from RADM
input [RADM_P_HWD-1:0]       radm_hdr;                   // Received request TLP data from RADM
input                        radm_dv;                    // Received TLP data valid
input                        radm_hv;                    // Received TLP data valid
input                        radm_fm_np_rsvd;            // Flit Mode NP Reserved TLP
input                        radm_eot;                   // Received TLP EOT
input                        radm_abort;                 // Received TLP EOT with abort
input                        radm_trgt0_pending;         // TLP enroute from RADM prevent DBI access

input                        ext_lbc_override_en;        // Override Enable from external register access
input [NF-1:0]               ext_lbc_ack;                // ACK from external register access
input [(ELBI_WD*NF) -1:0]    ext_lbc_din;                // Data Input from external register access
input [(LBC_DW * NF)-1:0]    cdm_lbc_din;                // Data Input from CDM register access
input [NF-1:0]               cdm_lbc_ack;                // ACK from CDM register access
input                        cxl_link_enable;           // Link is up in CXL mode
input [63:0]                 cxl_2_0_comp_reg_offset;      // Offset of CXL 2.0 MEMBAR0 in Func0, BAR0
input                        cxl_mbar0_enable;             // Indicates CXL Component registers allocated in a standard BAR
input [63:0]                 rcrb_mbar0_base_addr;      // RCRB MEMBAR base address
input [63:12]                rcrb_base_addr;            // The RCRB base address snooped by RADM 
input                        xadm_cpl_halt;              // XADM halts CPL from LBC
// internal configuration register values of this port for HBC

input [LBC_DW -1:0]          dbi_addr;                   // External DBI interface address
input [LBC_DW -1:0]          dbi_din;                    // external DBI interface Data input
input                        dbi_cs;                 // external DBI interface chip select
input                        dbi_cs2;                    // external DBI interface chip select
input [3:0]                  dbi_wr;                     // external DBI write enable
input                        dbi_ro_wr_en;               // Enable DBI Write in Read-Only Registers

input   [NFUNC_WD-1:0]       dbi_func_num;               // Function number of the DBI access
input                        dbi_rom_access;
input                        dbi_io_access;
input [2:0]                  dbi_bar_num;
input                        pm_l1_aspm_entr;
input [7:0]                  rtfcgen_ph_diff;



input [9:0]                  cfg_config_limit;

input   [ERROR_INJ_EN_WD  -1:0] ras_err_inj_en_array;
input   [ERROR_INJ_MASK_WD-1:0] ras_err_inj_mask;
//----------- outputs -------------------------
output                       ras_err_inj_done;
// external outband Local bus access interface
output [LBC_DW -1:0]         lbc_dbi_dout;               // Data out to external DBI
output                       lbc_dbi_ack;                // ACk to external DBI

output                       lbc_cpl_hv;                 // LBC generated CPL request
output                       lbc_cpl_dv;
output [DW+DATA_PAR_WD-1:0]  lbc_cpl_data;               // LBC generated CPL data
output [ST_HDR+HDR_PROT_WD-1:0]lbc_cpl_hdr;

output                       lbc_cpl_eot;                // LBC generated CPL EOT
output [LBC_DW -1:0]         lbc_cdm_addr;               // LBC address to CDM register access
output [LBC_DW -1:0]         lbc_cdm_data;               // LBC data to CDM register access
output [NF-1:0]              lbc_cdm_cs;                 // LBC chip select to CDM register access
output [3:0]                 lbc_cdm_wr;                 // LBC write enable to CDM register access
output                       lbc_cdm_dbi;                // LBC indicates to CDM that register is accessed via DBI
output                       lbc_cdm_dbi2;               // LBC indicates to CDM that register is accessed via DBI
output                       lbc_cdm_unroll;             // LBC indicates to CDM to access to UNROLL registers
output                       lbc_cdm_rcrb_wire;               // LBC indicates to CDM that it is an RCRB wire access
output                       lbc_cdm_rcrb_mbar0_wire;         // LBC indicates to CDM that it is an RCRB MEMBAR wire access
output                       lbc_cdm_rcrb_dbi;                // LBC indicates to CDM that it is an RCRB dbi access
output                       lbc_cdm_rcrb_mbar0_dbi;          // LBC indicates to CDM that it is an RCRB MEMBAR dbi access

output [NF-1:0]              lbc_xmt_cpl_ca;             // LBC indicates to CDM that it send CPL w/ CA

output [LBC_EXT_AW -1:0]     lbc_ext_addr;               // LBC address to external register access
output [ELBI_WD-1:0]         lbc_ext_dout;               // LBC data output to external register access
output [NF-1:0]              lbc_ext_valid;              // LBC valid to external register access
output [NF-1:0]              lbc_ext_cs;                 // LBC cs to external register access
output                       lbc_ext_dbi_access;         // Access to ELBI interface initiated from DBI
output                       lbc_ext_cxl_mbar0_access;   // Access to ELBI mapped region of MEMBAR
output                       lbc_mbar0_link_cap_access;  // Access is to CXL MEMBAR0 Link Layer Cap Reg

output [(LBC_NW*4)-1:0]      lbc_ext_wr;                 // LBC write enable to external register access
output [(LBC_NW*4)-1:0]      lbc_ext_rd;                 // LBC Read enable to external register access
output                       lbc_ext_rom_access;         // LBC inidcates that this access is for rom expansion
output                       lbc_ext_io_access;          // LBC inidcates that this access is for IO
output [2:0]                 lbc_ext_bar_num;            // LBC inidcates which bar this is

output                       lbc_deadlock_det;
output [3*NVC-1:0]           trgt0_radm_halt;            // LBC halts TLP from RADM
output                       lbc_active;                 // LBC may need to send CPL hold L1 timer


    spif_if.cfgi_slave_mp   b_cfgi_lbc_pcie;
    spif_if.cfgi_slave_mp   b_cfgi_lbc_cxl;

//----------- output register -------------------------
wire  [3*NVC-1:0]            int_trgt0_radm_halt;            // LBC halts TLP from RADM
wire  [DW-1:0]               int_radm_data;                  // Received request TLP data from RADM
wire  [ELBI_WD-1:0]          radm_elbi_data;                 // Received request TLP data from RADM for ELBI
wire  [RADM_P_HWD-1:0]       int_radm_hdr;                   // Received request TLP data from RADM
wire                         int_radm_dv;                    // Received TLP data valid
wire                         int_radm_hv;                    // Received TLP data valid
wire                         int_radm_eot;                   // Received TLP EOT
wire                         int_radm_abort;                 // Received TLP EOT with abort
wire                         int_radm_trgt0_pending;

reg                          lbc_cpl_dv;
reg                          lbc_cpl_hv;
wire [DW+DATA_PAR_WD-1:0]    lbc_cpl_data;
wire [ST_HDR+HDR_PROT_WD-1:0]lbc_cpl_hdr;
wire [ST_HDR-1:0]            lbc_cpl_hdr_nxt; 
reg                          lbc_cpl_eot;
wire                          int_dbi_cs;
wire                          int_dbi_cs2;

logic [NF-1:0]                 lbc_cdm_cs;
reg                          next_lbc_cdm_cs;
wire                          lbc_cdm_dbi;
wire                          lbc_cdm_dbi2;
reg [NF-1:0]                 lbc_xmt_cpl_ca;
reg                          next_lbc_cdm_dbi;



//wire                          lbc_deadlock_det;

reg [NF-1:0]                 lbc_ext_cs_int;
wire[NF-1:0]                 lbc_ext_cs;
reg [NF-1:0]                 lbc_ext_valid_int;
wire [NF-1:0]                lbc_ext_valid;
reg [LBC_EXT_AW -1:0]        lbc_ext_addr;               // LBC address to external register access
reg [(LBC_NW*4)-1:0]         lbc_ext_wr;                 // LBC write enable to external register access
reg [(LBC_NW*4)-1:0]         lbc_ext_rd;                 // LBC read enable to external register access
reg                          next_lbc_ext_cs;
reg                          int_lbc_dbi_ack ;
reg  [NF-1:0]                cdm_lbc_ack_d;              // Latched ACK from CDM register access
reg  [NF-1:0]                ext_lbc_ack_d;              // Latched ACK from external register access
wire [NF-1:0]                cdm_lbc_ack_pulse;          // Detects the rising edge of cdm_lbc_ack
wire [NF-1:0]                ext_lbc_ack_pulse;          // Detects the rising edge of ext_lbc_ack
reg                          lbc_arb_halt_radm;          // Signal to halt radm interface and allow DBI access to CDM
wire [LBC_DW -1:0]            lbc_cdm_addr;               // LBC address to external register access
wire [3:0]                    lbc_cdm_wr;                 // LBC write enable to external register access
wire                          mbar0_link_cap_access;
wire                          lbc_cdm_rcrb_wire;
wire                          lbc_cdm_rcrb_mbar0_wire;
wire                          lbc_cdm_rcrb_dbi;
wire                          lbc_cdm_rcrb_mbar0_dbi;
reg                           rcrb_access_wire;            // To indicate RCRB access through MEM RD/WR
reg                           rcrb_access_dbi;             // To indicate RCRB access through DBI
reg                           rcrb_mbar0_access_wire;     // To indicate RCRB MEMBAR access through MEM RD/WR
reg                           rcrb_mbar0_access_dbi;      // To indicate RCRB MEMBAR access through DBI
wire                          rcrb_mbar0_access_wire_ext;     // To indicate RCRB MEMBAR external register access through MEM RD/WR
wire                          rcrb_mbar0_access_dbi_ext;      // To indicate RCRB MEMBAR external register access through DBI
wire                          rcrb_mbar0_access_wire_int;     // To indicate RCRB MEMBAR internal register access through MEM RD/WR
wire                          rcrb_mbar0_access_dbi_int;      // To indicate RCRB MEMBAR internal register access through DBI
reg                           cxl_2_0_mbar0_access_wire;     // To indicate CXL 2.0 MEMBAR access through MEM RD/WR
wire                          cxl_2_0_mbar0_access_wire_int;     // To indicate CXL 2.0 MEMBAR internal register access through MEM RD/WR
wire                          cxl_2_0_mbar0_access_wire_ext;     // To indicate CXL 2.0 MEMBAR internal register access through MEM RD/WR
wire                         radm_halt;

reg                          lbc_ext_rom_access;
reg                          lbc_ext_io_access;   // LBC inidcates that this access is for IO
reg  [2:0]                   lbc_ext_bar_num;     // LBC inidcates which bar this is
wire [LBC_DW -1:0]           lbc_dbi_dout;        // Data out to external DBI

//--------------------------- Internal Signals ------------------

reg [2:0]                    lbc_proc_state;
reg [2:0]                    next_lbc_proc_state;

reg [LBC_INT_WD-1:0]         latchd_lbc_din;
reg [LBC_INT_WD-1:0]         lbc_cpl_data_int;
reg [(LBC_INT_WD*NF)-1:0]    int_lbc_din;
reg [ELBI_WD-1:0]            latchd_data;
reg [ELBI_WD-1:0]            dbi_elbi_din;          // DBI write data targeting ELBI
reg [(LBC_NW*4)-1:0]         dbi_elbi_wr;           // DBI write byte enables targeting ELBI
reg [(LBC_NW*4)-1:0]         dbi_elbi_rd;           // DBI read byte enables targeting ELBI
reg                          latchd_rcvd_len_good;  // indicates when Length field of received TLP is valid
reg [LBC_DW-1:0]             latchd_cdm_data;       // sampled DBI or RADM data targeting CDM

reg [1:0]                    byte_addr;

// TLP decoding


wire [TAG_SIZE-1:0]          rcvd_tag;
wire [15:0]                  rcvd_reqid;
wire                         rcvd_np_rd;
wire [NFUNC_WD-1:0]          rcvd_func_id;
wire [NFUNC_WD-1:0]          access_func_id;
wire                         rcvd_atomic_fas;
wire                         rcvd_atomic_cas;
wire                         rcvd_atomic_req;
wire                         rcvd_memrd_req;
wire                         rcvd_memwr_req;
wire                         rcvd_dmwr_req;
wire                         rcvd_p_req;
wire [6:0]                   lower_addr;
wire                         rcvd_locked_rd;
wire [7:0]                   addr_byte0;
wire [3:0]                   first_be;
wire [3:0]                   last_be;
wire [2:0]                   cpl_status;
wire [LBC_DW -1:0]           int_addr_low;
wire [11:0]                  byte_cnt;
wire                         int_radm_zerobyte;
wire [8:0]                   req_seg_id;
wire                         rcvd_iord_req;
wire                         rcvd_iowr_req;
wire [1:0]                   rcvd_fmt;
wire [4:0]                   rcvd_type;
wire                         rcvd_td;
wire [2:0]                   rcvd_tc;
wire [ATTR_WD-1:0]           rcvd_attr;
wire [7:0]                   rcvd_bus_nmbr;
wire [4:0]                   rcvd_dvc_nmbr;

wire                         status_sc;

reg  [TAG_SIZE-1:0]          latchd_rcvd_tag;
reg  [15:0]                  latchd_rcvd_reqid;
reg  [NFUNC_WD-1:0]          latchd_rcvd_func_id;
reg                          latchd_rcvd_atomic_req;
reg                          latchd_rcvd_dmwr_req;
reg                          latchd_rcvd_np_rd;
reg                          latchd_rcvd_p_req;
reg  [6:0]                   latchd_lower_addr;
reg                          latchd_rcvd_locked_rd;
reg  [2:0]                   latchd_cpl_status;
reg                          latchd_status_sc;
reg  [11:0]                  latchd_byte_cnt;
reg  [2:0]                   latchd_rcvd_tc;
reg  [ATTR_WD-1:0]           latchd_rcvd_attr;
reg                          latchd_rcvd_td;
reg  [9:0]                   latchd_rcvd_tlp_len;
reg  [8:0]                   latchd_req_seg_id;
wire [2:0]                   in_bar_range;
wire                         rom_in_range;
wire                         io_req_in_range;
wire                         rcvd_cfg0rd_req;
wire                         rcvd_cfg0wr_req;
wire                         rcvd_cfg1rd_req;
wire                         rcvd_cfg1wr_req;
wire [NFUNC_WD-1:0]          dbi_rcvd_func_id;
wire [9:0]                   rcvd_tlp_len;
wire                         select_radm;       // when asserted, radm_data (target 0 data) is selected in ELBI and CDM data muxes.
wire                         select_dbi;        // when asserted, dbi_din (DBI data) is selected in ELBI and CDM data muxes.

logic ext_lbc_override_en_nxt, ext_lbc_override_en_ff;
logic lbc_cdm_completed_nxt, lbc_cdm_completed_ff;
logic lbc_ext_completed_nxt, lbc_ext_completed_ff;
logic next_lbc_cdm_cs_int_nxt, next_lbc_cdm_cs_int_ff;
logic next_lbc_ext_cs_int_nxt, next_lbc_ext_cs_int_ff;


wire unroll_dbi_request; 
wire [63:0] unroll_bar_mask;


parameter LBC_CDM_REGOUT = 0
                           ;

parameter LBC_CDM_PIPEWIDTH = LBC_DW 
                           + 1                          // lbc_cdm_unroll
                           + LBC_DW + NF + 1 + 1 + 4    // lbc_cdm_data + lbc_cdm_cs + lbc_cdm_dbi + lbc_cdm_dbi2 + lbc_cdm_wr
                            + 4
                          ;
reg  [LBC_DW-1:0]         lbc_cdm_addr_int;
reg                       lbc_cdm_unroll_int;
wire [LBC_DW-1:0]         lbc_cdm_data_int;
reg  [NF-1:0]             lbc_cdm_cs_int;
reg  [3:0]                lbc_cdm_wr_int;
reg                       lbc_dbi_int;
reg                       lbc_dbi2_int;
wire                      lbc_cdm_dbi_int;
wire                      lbc_cdm_dbi2_int;

logic  [NF-1:0]           lbc_cdm_cs_internal;
logic  [3:0]              lbc_cdm_wr_internal;
assign lbc_cdm_cs    = lbc_cdm_cs_internal;
assign lbc_cdm_wr    = lbc_cdm_wr_internal;
assign lbc_ext_cs    = lbc_ext_cs_int;
assign lbc_ext_valid = lbc_ext_valid_int;


reg                       lbc_mbar0_link_cap_access;
reg                       lbc_cdm_rcrb_wire_int;
reg                       lbc_cdm_rcrb_mbar0_wire_int;
reg                       lbc_cdm_rcrb_dbi_int;
reg                       lbc_cdm_rcrb_mbar0_dbi_int;

reg                       elbi_cpl;   // Asserted when completion data is from ELBI.

wire [12:0]  tlp_byte_len;      // TLP data payload length in bytes
wire  [3:0]  sc_last_be;        // Successful Completion last byte enable field


wire   [DW-1:0]              cic_data;               // Received request TLP data from RADM
wire   [RADM_P_HWD-1:0]      cic_hdr;                // Received request TLP data from RADM
wire                         cic_dv;                 // Received TLP data valid
wire                         cic_hv;                 // Received TLP data valid
wire                         cic_eot;                // Received TLP EOT
wire                         cic_abort;              // Received TLP EOT with abort
wire                         cic_pending;            // TLP enroute from RADM prevent DBI access
wire                         cic_active;

integer                      i;

// SPIF.CFG related signals
wire                         wlbc_wire_access_en;
wire                         wlbc_dbi_access_en;
spif_if                      b_lbc_control_spif_cfg();
reg                          wspif_mem_access_rcbr_membar0;
wire                         wspif_access_wire;
wire                         wspif_access_dbi;

wire                         wspif_cfg_access_wire;
wire                         wspif_cfg_access_dbi;
reg                          wspif_cfg_access;

wire                         wspif_access_cfg_cap_reg;
wire                         wspif_access_cxl_port_reg;
wire                         wspif_access_rcbr_membar0;
reg                          wspif_matched_req;
reg                   [23:0] wspif_req_addr;
reg                    [7:0] wspif_req_pf;
reg                    [7:0] rspif_req_pf_1d;
wire                         wspif_req_we;
wire                   [3:0] wspif_req_be;
reg                    [4:0] wspif_req_dstid;
wire                         wspif_crd_full;
wire                         wpsif_req_fw;

wire            [LBC_DW-1:0] wspif_cpl_pkt_data;
wire            [LBC_DW-1:0] wspif_cpl_pkt_data_or;
reg             [LBC_DW-1:0] rspif_cpl_pkt_data_sample;
wire                         wspif_cpl_pkt_data_p;
wire                         wspif_cpl_pkt_avail_p;
reg                          rspif_cpl_pkt_avail_p_1d;
reg                 [NF-1:0] wspif_cpl_pkt_data_avail;

 assign cic_data        = radm_data;
 assign cic_hdr         = radm_hdr;
 assign cic_dv          = radm_dv;
 assign cic_hv          = radm_hv;
 assign cic_eot         = radm_eot;
 assign cic_abort       = radm_abort;
 assign cic_pending     = radm_trgt0_pending;
 assign cic_active      = 1'b0;
 assign trgt0_radm_halt = int_trgt0_radm_halt;


logic[(LBC_DW*NF)-1:0] cdm_lbc_din_tmp;
logic[(LBC_DW*NF)-1:0] cdm_lbc_din_b_tmp;
logic[NF-1:0] cdm_lbc_ack_tmp;
logic[NF-1:0] lbc_cdm_cs_tmp;
wire[11:0] lbc_cdm_addr_cleaned_from_ide_offset = lbc_cdm_addr[11:0] - `IDE_PTR;
    assign lbc_cdm_cs_internal = lbc_cdm_cs_tmp;
    assign cdm_lbc_din_tmp = (|wspif_cpl_pkt_data_avail) ? {NF{wspif_cpl_pkt_data_or}} : cdm_lbc_din;
    assign cdm_lbc_ack_tmp = cdm_lbc_ack | wspif_cpl_pkt_data_avail;

delay_n

#(LBC_CDM_REGOUT, LBC_CDM_PIPEWIDTH) u_lbc_cdm_pipe(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({lbc_cdm_addr_int[LBC_DW-1:2],2'b00
                  ,lbc_cdm_unroll_int
                ,lbc_cdm_data_int,lbc_cdm_cs_int,lbc_cdm_wr_int,lbc_cdm_dbi_int,lbc_cdm_dbi2_int
                ,lbc_cdm_rcrb_wire_int,lbc_cdm_rcrb_mbar0_wire_int,lbc_cdm_rcrb_dbi_int,lbc_cdm_rcrb_mbar0_dbi_int
                }),
    .dout       ({lbc_cdm_addr
                  ,lbc_cdm_unroll
                ,lbc_cdm_data,lbc_cdm_cs_tmp,lbc_cdm_wr_internal,lbc_cdm_dbi,lbc_cdm_dbi2
                ,lbc_cdm_rcrb_wire,lbc_cdm_rcrb_mbar0_wire,lbc_cdm_rcrb_dbi,lbc_cdm_rcrb_mbar0_dbi
                })
  );


assign int_radm_data = cic_data;

// Invert data received from radm

reg [ELBI_WD-1:0] radm_elbi_data_inv;
assign radm_elbi_data = radm_elbi_data_inv;

always @(*)
begin
    if (int_addr_low[2])
    begin
        radm_elbi_data_inv[63:32] = cic_data[31:0];
        radm_elbi_data_inv[31:0]  = 0;
    end
    else
    begin
        radm_elbi_data_inv = cic_data[ELBI_WD-1:0];
    end
end


    assign int_radm_hdr  = cic_hdr ;
    assign int_radm_dv   = cic_dv ;
    assign int_radm_hv   = cic_hv ;
    assign int_radm_eot  = cic_eot ;
    assign int_radm_abort  = cic_abort ;
    assign int_radm_trgt0_pending  = cic_pending ;
//Detects possible deadlock
assign lbc_deadlock_det = 0;
assign int_trgt0_radm_halt = {3*NVC{radm_halt}};
assign  rcvd_fmt                = int_radm_hdr[ `RADM_Q_FMT_RANGE];
assign  rcvd_type               = int_radm_hdr[ `RADM_Q_TYPE_RANGE];
assign  rcvd_td                 = int_radm_hdr[ `RADM_NPQ_TD_RANGE];


assign  rcvd_tag                = int_radm_hdr[ `RADM_Q_TAG_RANGE];
assign  rcvd_reqid              = int_radm_hdr[ `RADM_Q_REQID_RANGE];
   assign  rcvd_func_id            = int_radm_hdr[ `RADM_Q_FUNC_NMBR_RANGE]; 

assign  rcvd_np_rd              = ((({rcvd_fmt,rcvd_type} == `IORD)    ||
                                   ({rcvd_fmt,rcvd_type} == `CFGRD0)  ||
                                   ({rcvd_fmt,rcvd_type} == `CFGRD1)  ||
                                   ({rcvd_fmt,rcvd_type} == `MRD32) ||
                                   ({rcvd_fmt,rcvd_type} == `MRD64)   ||
                                   ({rcvd_fmt,rcvd_type} == `MRDLK32) ||
                                   ({rcvd_fmt,rcvd_type} == `MRDLK64)) && !radm_fm_np_rsvd);

assign  rcvd_locked_rd          = ((({rcvd_fmt,rcvd_type} == `MRDLK32) ||
                                   ({rcvd_fmt,rcvd_type} == `MRDLK64)) && !radm_fm_np_rsvd);

assign  first_be                = int_radm_hdr[ `RADM_PQ_FRSTDW_BE_RANGE];

assign  sc_last_be              = int_radm_hdr[                                  `RADM_PQ_LSTDW_BE_RANGE];
assign  last_be                 = status_sc ? sc_last_be : int_radm_hdr[ `RADM_PQ_UNSC_LSTDW_BE_RANGE];
assign  addr_byte0              = int_addr_low[7:0];

assign  rcvd_tlp_len            = int_radm_hdr[`RADM_PQ_DW_LENGTH_RANGE];

assign  lower_addr              = (rcvd_memrd_req || rcvd_locked_rd) ? {addr_byte0[6:2], byte_addr} : 7'b0;
assign  byte_cnt                = (rcvd_memrd_req || rcvd_locked_rd) ? get_byte_count(first_be, last_be, rcvd_tlp_len)     :
                                  (rcvd_atomic_fas)                  ? get_byte_count(4'hf,4'hf,rcvd_tlp_len)              :
                                  (rcvd_atomic_cas)                  ? get_byte_count(4'hf,4'hf,{1'b0,rcvd_tlp_len[9:1]})  :
                                  12'h004;
assign  req_seg_id              = int_radm_hdr[`FLT_PQ_REQ_SEG_RANGE];
assign  cpl_status              = int_radm_hdr[ `RADM_Q_CPL_STATUS_RANGE];
assign  status_sc               = (cpl_status == `SU_CPL_STATUS);  // Successful  Completion

assign  rcvd_iord_req           = ( {rcvd_fmt,rcvd_type} == `IORD) && !radm_fm_np_rsvd;
assign  rcvd_iowr_req           = ( {rcvd_fmt,rcvd_type} == `IOWR) && !radm_fm_np_rsvd;
assign  io_req_in_range         = int_radm_hdr[ `RADM_PQ_IO_REQ_IN_RANGE_RANGE];

assign  in_bar_range            = int_radm_hdr[ `RADM_PQ_IN_MEMBAR_RANGE_RANGE];

assign  rom_in_range            = int_radm_hdr[ `RADM_PQ_ROM_IN_RANGE_RANGE];

assign  rcvd_cfg0rd_req         = ( {rcvd_fmt,rcvd_type} == `CFGRD0) && !radm_fm_np_rsvd;
assign  rcvd_cfg0wr_req         = ( {rcvd_fmt,rcvd_type} == `CFGWR0) && !radm_fm_np_rsvd;
assign  rcvd_cfg1rd_req         = ( {rcvd_fmt,rcvd_type} == `CFGRD1) && !radm_fm_np_rsvd;
assign  rcvd_cfg1wr_req         = ( {rcvd_fmt,rcvd_type} == `CFGWR1) && !radm_fm_np_rsvd;
//assign  int_radm_dwlenEq1           = (int_radm_hdr[`RADM_PQ_DW_LENGTH_RANGE] == 10'b00000001);
assign  int_radm_zerobyte           = (int_radm_hdr[ `RADM_PQ_FRSTDW_BE_RANGE] == 4'b0) ;

assign  rcvd_memrd_req           = ((({rcvd_fmt,rcvd_type} == `MRD32) ||
                                   ({rcvd_fmt,rcvd_type} == `MRD64)) && !radm_fm_np_rsvd);

assign  rcvd_atomic_fas          = ((({rcvd_fmt,rcvd_type} == `FETCHADD32) ||
                                   ({rcvd_fmt,rcvd_type} == `FETCHADD64) ||
                                   ({rcvd_fmt,rcvd_type} == `SWAP32)     ||
                                   ({rcvd_fmt,rcvd_type} == `SWAP64)) && !radm_fm_np_rsvd);

assign  rcvd_atomic_cas          = ((({rcvd_fmt,rcvd_type} == `CAS32) ||
                                   ({rcvd_fmt,rcvd_type} == `CAS64)) && !radm_fm_np_rsvd);

assign  rcvd_atomic_req          = rcvd_atomic_cas || rcvd_atomic_fas;

assign  rcvd_memwr_req           = ((({rcvd_fmt,rcvd_type} == `MWR32)   ||
                                   ({rcvd_fmt,rcvd_type} == `MWR64)) && !radm_fm_np_rsvd);

assign  rcvd_dmwr_req            = ((({rcvd_fmt,rcvd_type} == `DMWR32)   ||
                                   ({rcvd_fmt,rcvd_type} == `DMWR64)) && !radm_fm_np_rsvd);

assign  rcvd_p_req               = ((({rcvd_fmt,rcvd_type} == `MWR32)   ||
                                   ({rcvd_fmt,rcvd_type} == `MWR64)   ||
                                   ({rcvd_fmt,rcvd_type[4:3]} == `MSG_4) ||
                                   ({rcvd_fmt,rcvd_type[4:3]} == `MSGD_4)) && !radm_fm_np_rsvd);
  assign  dbi_rcvd_func_id         = dbi_func_num;

parameter FLT_Q_ADDR_WIDTH = `FLT_Q_ADDR_WIDTH;
reg [FLT_Q_ADDR_WIDTH-1:0] int_addr;
always @(*) begin : EXTRACT_ADDR
  int_addr = 0;
  int_addr[0 +: FLT_Q_ADDR_WIDTH] = int_radm_hdr[ `RADM_PQ_ADDR_RANGE   ];
  
end 
assign int_addr_low = int_addr[LBC_DW-1:0];

assign  rcvd_bus_nmbr            = int_radm_hdr[`RADM_PQ_BUS_NMBR_RANGE];
assign  rcvd_dvc_nmbr            = int_radm_hdr[`RADM_PQ_DEV_NMBR_RANGE];

assign  rcvd_tc                  = int_radm_hdr[ `RADM_Q_TC_RANGE];
assign  rcvd_attr                = int_radm_hdr[ `RADM_Q_ATTR_RANGE];


always @(first_be)
    casez(first_be)
        4'b0000:     byte_addr = 2'b00;
        4'b???1:     byte_addr = 2'b00;
        4'b??10:     byte_addr = 2'b01;
        4'b?100:     byte_addr = 2'b10;
        4'b1000:     byte_addr = 2'b11;
    endcase



assign access_func_id = rcvd_func_id;


always @(posedge core_clk or negedge core_rst_n)
begin:  HEADER_INFO
    if(!core_rst_n) begin
        latchd_rcvd_tag          <= #TP 0;
        latchd_rcvd_reqid        <= #TP 0;
        latchd_rcvd_func_id      <= #TP 0;
        latchd_rcvd_atomic_req   <= #TP 0;
        latchd_rcvd_dmwr_req     <= #TP 0;
        latchd_rcvd_np_rd        <= #TP 0;
        latchd_rcvd_p_req        <= #TP 0;
        latchd_lower_addr        <= #TP 0;
        latchd_rcvd_locked_rd    <= #TP 0;
        latchd_cpl_status        <= #TP 0;
        latchd_status_sc         <= #TP 0;
        latchd_byte_cnt          <= #TP 0;
        latchd_rcvd_tc           <= #TP 0;
        latchd_req_seg_id        <= #TP 0;
        latchd_rcvd_attr         <= #TP 0;
        latchd_rcvd_td           <= #TP 0;
        latchd_rcvd_tlp_len      <= #TP 0;
    end else if (int_radm_hv & ~radm_halt) begin
        latchd_rcvd_tag          <= #TP rcvd_tag;
        latchd_rcvd_reqid        <= #TP rcvd_reqid;
        latchd_rcvd_func_id      <= #TP rcvd_func_id;
        latchd_rcvd_atomic_req   <= #TP rcvd_atomic_req;
        latchd_rcvd_dmwr_req     <= #TP rcvd_dmwr_req;
        latchd_rcvd_np_rd        <= #TP rcvd_np_rd;
        latchd_rcvd_p_req        <= #TP rcvd_p_req;
        latchd_lower_addr        <= #TP lower_addr;
        latchd_rcvd_locked_rd    <= #TP rcvd_locked_rd;
        latchd_cpl_status        <= #TP cpl_status;
        latchd_status_sc         <= #TP status_sc;
        latchd_byte_cnt          <= #TP byte_cnt;
        latchd_rcvd_tc           <= #TP rcvd_tc;
        latchd_req_seg_id        <= #TP req_seg_id;
        latchd_rcvd_attr         <= #TP rcvd_attr;
        latchd_rcvd_td           <= #TP rcvd_td;
        latchd_rcvd_tlp_len      <= #TP rcvd_tlp_len;
    end
end


// only support memory mapped request for the register access

// --------------------  Received TLP processing --------------------------------
//  lbc processing state is designed to walk through the sequential
//  event of a local bus tlp request:  decode, local bus access and completion request
//
//wire  good_hv  = int_radm_hv && int_radm_eot && !int_radm_abort;
wire  good_hv;
    assign good_hv  = (NW == 1) ? ((int_radm_hv | latchd_rcvd_len_good) & int_radm_eot & ~int_radm_abort) : (int_radm_hv & int_radm_eot & ~int_radm_abort);

// Determine if length field of TLP is allowable:
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
    begin
        latchd_rcvd_len_good <= #TP  0;
    end
    else
    begin
        latchd_rcvd_len_good <= #TP  (rcvd_tlp_len <= LBC_NW);
    end

// Used separately for handling malformed TLPs. If unsupported operand size is used i.e., the requests should be handled and a completion should be sent.
wire good_atomic_req;
assign good_atomic_req = latchd_rcvd_atomic_req && int_radm_eot && !int_radm_abort;
wire good_dmwr_req;
assign good_dmwr_req = latchd_rcvd_dmwr_req && int_radm_eot && !int_radm_abort;

wire lbc_return_err;
assign lbc_return_err = ((dbi_rcvd_func_id >=NF ) && (int_dbi_cs && !good_hv  & !int_radm_hv && !int_radm_trgt0_pending)
                        && !(good_hv && status_sc && !int_radm_zerobyte)
                        && !(good_hv && !rcvd_p_req));






always_comb 
begin: CDM_EXT_COMPLETED_COMB

    case (lbc_proc_state)
        LBC_IDLE:
            begin
                ext_lbc_override_en_nxt = 1'b0;
                lbc_cdm_completed_nxt   = 1'b0;
                lbc_ext_completed_nxt   = 1'b0;
                next_lbc_cdm_cs_int_nxt =  next_lbc_cdm_cs;
                next_lbc_ext_cs_int_nxt =  next_lbc_ext_cs;
            end

        default:
            begin
                ext_lbc_override_en_nxt = ext_lbc_override_en_ff;
                lbc_cdm_completed_nxt   = lbc_cdm_completed_ff;
                lbc_ext_completed_nxt   = lbc_ext_completed_ff;
                next_lbc_cdm_cs_int_nxt =  next_lbc_cdm_cs_int_ff;
                next_lbc_ext_cs_int_nxt =  next_lbc_ext_cs_int_ff;

                if (ext_lbc_override_en)
                    ext_lbc_override_en_nxt = 1'b1;
                if (!next_lbc_cdm_cs_int_ff || (|cdm_lbc_ack_tmp))
                    lbc_cdm_completed_nxt = 1'b1;
                if ((!next_lbc_ext_cs_int_ff && !ext_lbc_override_en && (|cdm_lbc_ack_tmp)) || (|ext_lbc_ack))
                    lbc_ext_completed_nxt = 1'b1;
            end
    endcase // case(lbc_proc_state)

end: CDM_EXT_COMPLETED_COMB


always_ff @(posedge core_clk or negedge core_rst_n)
begin: CDM_EXT_COMPLETED_REG
    if(!core_rst_n)
    begin
        ext_lbc_override_en_ff <= #TP 1'b0;
        lbc_cdm_completed_ff   <= #TP 1'b0;
        lbc_ext_completed_ff   <= #TP 1'b0;
        next_lbc_cdm_cs_int_ff <= #TP 1'b0;
        next_lbc_ext_cs_int_ff <= #TP 1'b0;
    end
    else 
    begin
        ext_lbc_override_en_ff <= #TP ext_lbc_override_en_nxt; 
        lbc_cdm_completed_ff   <= #TP lbc_cdm_completed_nxt; 
        lbc_ext_completed_ff   <= #TP lbc_ext_completed_nxt; 
        next_lbc_cdm_cs_int_ff <= #TP next_lbc_cdm_cs_int_nxt; 
        next_lbc_ext_cs_int_ff <= #TP next_lbc_ext_cs_int_nxt; 
    end
end: CDM_EXT_COMPLETED_REG




always @(posedge core_clk or negedge core_rst_n)
begin: TLP_RECEPTION_PROCESS
integer                      i;
    if(!core_rst_n)
    begin
        lbc_cdm_cs_int         <= #TP  0;
        lbc_ext_cs_int         <= #TP  0;
        lbc_ext_valid_int      <= #TP  0;
        lbc_dbi_int            <= #TP  0;
        lbc_dbi2_int           <= #TP  0;
    end
    else if (lbc_proc_state == LBC_IDLE)
    begin

        for (i = 0; i<NF; i = i+1)
            if (((access_func_id == i) && good_hv && status_sc && !int_radm_zerobyte)
                | ((dbi_rcvd_func_id == i) && (int_dbi_cs && !good_hv  & !int_radm_hv && !int_radm_trgt0_pending)
                     && !(good_hv && status_sc && !int_radm_zerobyte)
                     && !(good_hv && !rcvd_p_req)) && (~wspif_matched_req)) begin
                lbc_cdm_cs_int[i] <= #TP next_lbc_cdm_cs;
                lbc_ext_cs_int[i] <= #TP next_lbc_ext_cs;
                lbc_ext_valid_int[i]  <= #TP (next_lbc_cdm_cs | next_lbc_ext_cs);
            end else begin
                lbc_cdm_cs_int[i] <= #TP 1'b0;
                lbc_ext_cs_int[i] <= #TP 1'b0;
                lbc_ext_valid_int[i]  <= #TP 1'b0;
            end

        lbc_dbi_int            <= #TP next_lbc_cdm_dbi & ((!int_dbi_cs2) | rcrb_access_dbi | rcrb_mbar0_access_dbi );
        lbc_dbi2_int           <= #TP next_lbc_cdm_dbi & int_dbi_cs2 & !rcrb_access_dbi & !rcrb_mbar0_access_dbi;
    end
    else begin
        if(lbc_cdm_completed_nxt) begin
            lbc_cdm_cs_int         <= #TP  0;
        end
        if(lbc_ext_completed_nxt) begin
            lbc_ext_cs_int         <= #TP  0;
            lbc_ext_valid_int          <= #TP  0;
            lbc_dbi_int            <= #TP  0;
            lbc_dbi2_int           <= #TP  0;
        end
    end
end

logic dbi_rcvd_func_is_zero;

assign dbi_rcvd_func_is_zero = (dbi_rcvd_func_id == '0) ;

always @(posedge core_clk or negedge core_rst_n)
begin
  if(!core_rst_n)
    begin
        lbc_cdm_rcrb_wire_int       <= #TP 0; 
        lbc_cdm_rcrb_mbar0_wire_int <= #TP 0; 
        lbc_cdm_rcrb_dbi_int        <= #TP 0; 
        lbc_cdm_rcrb_mbar0_dbi_int  <= #TP 0; 
        lbc_mbar0_link_cap_access   <= #TP 0;
    end
    else if (lbc_proc_state == LBC_IDLE)
    begin

            if (((rcvd_func_id == 0) && good_hv && status_sc && !int_radm_zerobyte)
                | (dbi_rcvd_func_is_zero && (int_dbi_cs && !good_hv & !int_radm_hv && !int_radm_trgt0_pending) && !(good_hv && status_sc && !int_radm_zerobyte)
                       && !(good_hv && !rcvd_p_req))) begin
              lbc_cdm_rcrb_wire_int       <= #TP rcrb_access_wire;
              lbc_cdm_rcrb_mbar0_wire_int <= #TP rcrb_mbar0_access_wire || cxl_2_0_mbar0_access_wire;
              lbc_cdm_rcrb_dbi_int        <= #TP rcrb_access_dbi;
              lbc_cdm_rcrb_mbar0_dbi_int  <= #TP rcrb_mbar0_access_dbi;
              lbc_mbar0_link_cap_access   <= #TP mbar0_link_cap_access;
            end else begin
              lbc_cdm_rcrb_wire_int       <= #TP 0;
              lbc_cdm_rcrb_mbar0_wire_int <= #TP 0;
              lbc_cdm_rcrb_dbi_int        <= #TP 0;
              lbc_cdm_rcrb_mbar0_dbi_int  <= #TP 0;
              lbc_mbar0_link_cap_access   <= #TP 0;
            end 
    end
    else if(lbc_cdm_completed_nxt & lbc_ext_completed_nxt)
    begin
        lbc_cdm_rcrb_wire_int       <= #TP 0;
        lbc_cdm_rcrb_mbar0_wire_int <= #TP 0;
        lbc_cdm_rcrb_dbi_int        <= #TP 0;
        lbc_cdm_rcrb_mbar0_dbi_int  <= #TP 0;
        lbc_mbar0_link_cap_access   <= #TP 0;
    end
end

assign lbc_cdm_dbi_int  = lbc_dbi_int  & (|lbc_cdm_cs_int);
assign lbc_cdm_dbi2_int = lbc_dbi2_int & (|lbc_cdm_cs_int);
assign lbc_ext_dbi_access = (lbc_dbi_int | lbc_dbi2_int )  & (|lbc_ext_valid);         // Access to ELBI interface initiated from DBI
assign lbc_ext_cxl_mbar0_access = (lbc_cdm_rcrb_mbar0_wire_int | lbc_cdm_rcrb_mbar0_dbi_int) & lbc_ext_cs[0]; // Access to ELBI mapped region of MEMBAR



always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        lbc_proc_state     <= #TP  LBC_IDLE;
    else
        lbc_proc_state     <= #TP next_lbc_proc_state;




wire rcvd_memrd_or_mrdlk_req;
assign rcvd_memrd_or_mrdlk_req = rcvd_memrd_req | rcvd_locked_rd;

wire lbc_ack_d_nd;

wire              dbi_elbi_2;
assign dbi_elbi_2          = dbi_cs2 & dbi_cs & dbi_addr[0] & ~dbi_addr[23] & dbi_addr[22];

// CXL 2.0 Component Registers are mapped to Function 0, BAR 0

wire              cxl_2_0_mbar0_func_bar_match;   // CXL 2.0 Component Specific Register Function and BAR match for Wire accesses
logic             dbi_cxl_comp_reg_func_match;
wire [63:0]       cxl_2_0_mbar0_mask;             // Mask for Function 0, BAR0
wire              cxl_2_0_mbar0_range;            // Address within range of CXL 2.0 Component Specific Registers 
wire              cxl_2_0_mbar0_access; 
wire [LBC_DW-1:0] cxl_2_0_mbar0_addr;             // Offset of the register being accessed relative to the MEMBAR0 offset in BAR0
wire              cxl_2_0_mbar0_dbi;              // CXL 2.0 component specific register access through DBI
reg [63:0] cxl_2_0_comp_reg_offset_reg;

always @(posedge core_clk or negedge core_rst_n)
begin
    if(!core_rst_n)
    begin
        cxl_2_0_comp_reg_offset_reg <= #TP  0;
    end
    else 
    begin
        cxl_2_0_comp_reg_offset_reg <= #TP cxl_2_0_comp_reg_offset; 
    end
end



assign cxl_2_0_mbar0_func_bar_match = (int_radm_hdr[`RADM_Q_FUNC_NMBR_RANGE] == `CX_CXL_2_0_COMP_REG_FUNC_NUM) && (in_bar_range == `CX_CXL_2_0_COMP_REG_BAR_NUM);
assign cxl_2_0_mbar0_mask           = cfg_bar0_mask[63:0];
assign cxl_2_0_mbar0_range          = ((int_addr[63:16] & cxl_2_0_mbar0_mask[63:16]) == cxl_2_0_comp_reg_offset_reg[63:16]);
assign cxl_2_0_mbar0_access         = ((rcvd_memrd_or_mrdlk_req | rcvd_memwr_req) && cxl_2_0_mbar0_func_bar_match && cxl_2_0_mbar0_range);

assign cxl_2_0_mbar0_addr           = (int_addr_low[LBC_DW-1:0] & cxl_2_0_mbar0_mask[LBC_DW-1:0]);

assign dbi_cxl_comp_reg_func_match  = (dbi_func_num == `CX_CXL_2_0_COMP_REG_FUNC_NUM) ;

assign cxl_2_0_mbar0_dbi   = dbi_elbi_2 && (dbi_bar_num == `CX_CXL_2_0_COMP_REG_BAR_NUM) && dbi_cxl_comp_reg_func_match && ({{45{1'b0}},dbi_addr[18:16]} == cxl_2_0_comp_reg_offset_reg[63:16]);


assign lbc_ack_d_nd =(lbc_cdm_completed_nxt & lbc_ext_completed_nxt) ;
                          
always @(*)
begin
    // set when a new TLP has being taken, clear when ack comes. dbi_addr
    // set has priority over clear
    case (lbc_proc_state)
        LBC_IDLE:
            if (good_hv && status_sc && !int_radm_zerobyte ) begin
                next_lbc_proc_state      = LBC_NP_ASSERT;

                next_lbc_cdm_cs          =  ((rcvd_cfg0rd_req | rcvd_cfg0wr_req) && 
                                             ((int_addr_low[11:2] <= cfg_config_limit && int_addr_low[11:2]>PCI_CONFIG_MAX) || 
                                               ~|int_addr_low[11:8] && int_addr_low[7:2] <= `PCI_CONFIG_LIMIT)
                                            )
                                          || ( rcrb_access_wire | rcrb_mbar0_access_wire_int) || cxl_2_0_mbar0_access_wire_int
                                           // allow type 1 transactions into the cdm when in SRIOV mode or IDE is enabled 
                                          || ((SRIOV_EN || IDE_EN) && ( (rcvd_cfg1rd_req | rcvd_cfg1wr_req) && 
                                              (int_addr_low[11:2] <= cfg_config_limit ||
                                              ~|int_addr_low[11:8] && int_addr_low[7:2] <= `PCI_CONFIG_LIMIT)))
 && (!wspif_access_wire)
                                             ;

                next_lbc_ext_cs          =  ~next_lbc_cdm_cs && (!wspif_access_wire);

                next_lbc_cdm_dbi         = 1'b0;
            // good_hv accounts for all requests including atomic requests. However, AtomicOp requests should handle packets whose length is not equal to the architected value i.e.Malformed TLPs#
            // So AtomicOp requests should be handled separately. Limitation - The controller rejects AtomicOps that target the ELBI, and returns a completion with CA status (3.21 databook)
            end else if (((good_atomic_req || good_dmwr_req) && !rcvd_p_req) || (good_hv && !rcvd_p_req)) begin    // for anything non posted, we need to completion. Here we can only receive memory write as a posted because messages are terminated at demux
                next_lbc_proc_state      = LBC_IN_CPL_REQ;
                next_lbc_ext_cs          = 1'b0;
                next_lbc_cdm_cs          = 1'b0;
                next_lbc_cdm_dbi         = 1'b0;
            end else if (int_dbi_cs && !good_hv & !int_radm_hv && !int_radm_trgt0_pending)  begin // This is to make sure that there is no tlp in progress from np or p interface
                
                next_lbc_cdm_dbi         = 1'b1;
                next_lbc_ext_cs          =
                                           (((dbi_addr[0] && ~int_dbi_cs2) || dbi_elbi_2) && ~rcrb_mbar0_access_dbi_int) | rcrb_mbar0_access_dbi_ext && (!wspif_access_dbi);
                next_lbc_cdm_cs          = 
                                           ((!dbi_addr[0]) || (int_dbi_cs2 & ~dbi_elbi_2) || rcrb_mbar0_access_dbi_int) && !lbc_return_err && !rcrb_mbar0_access_dbi_ext && (!wspif_access_dbi);

                next_lbc_proc_state      =                                                 lbc_return_err ? LBC_RETURN_ERR : LBC_EXT_DBI_REQ;
            end else begin
                next_lbc_proc_state     = LBC_IDLE;
                next_lbc_ext_cs         = 1'b0;
                next_lbc_cdm_cs         = 1'b0;
                next_lbc_cdm_dbi        = 1'b0;
            end
        LBC_NP_ASSERT:  begin
            next_lbc_cdm_dbi            = 1'b0;
            next_lbc_cdm_cs             = 1'b0;
            next_lbc_ext_cs             = 1'b0;
            if ((lbc_cdm_completed_nxt & lbc_ext_completed_nxt) & (!latchd_rcvd_p_req)) begin
                next_lbc_proc_state     = LBC_IN_CPL_REQ;
                next_lbc_cdm_cs         = 0;
                next_lbc_ext_cs         = 0;
            end else if (lbc_ack_d_nd & latchd_rcvd_p_req) begin
                next_lbc_proc_state     = LBC_IDLE;
                next_lbc_cdm_cs         = 0;
                next_lbc_ext_cs         = 0;
            end else begin
                next_lbc_proc_state     = LBC_NP_ASSERT;
            end
        end
        LBC_EXT_DBI_REQ:  begin
            next_lbc_cdm_dbi            = 1'b0;
            next_lbc_cdm_cs             = 1'b0;
            next_lbc_ext_cs             = 1'b0;
            if (lbc_cdm_completed_ff & lbc_ext_completed_ff) begin
                next_lbc_proc_state     = LBC_IDLE;
                next_lbc_cdm_cs         = 1'b0;
                next_lbc_cdm_dbi        = 1'b0;

            end else begin

                next_lbc_proc_state     = LBC_EXT_DBI_REQ;
            end
        end
        LBC_IN_CPL_REQ: begin
            next_lbc_cdm_dbi            = 1'b0;
            next_lbc_cdm_cs             = 1'b0;
            next_lbc_ext_cs             = 1'b0;
            next_lbc_proc_state         = LBC_IDLE;

        end
        LBC_RETURN_ERR: begin
            next_lbc_cdm_dbi            = 1'b0;
            next_lbc_cdm_cs             = 1'b0;
            next_lbc_ext_cs             = 1'b0;
            next_lbc_proc_state         = LBC_IDLE;
            next_lbc_cdm_cs             = 1'b0;
            next_lbc_cdm_dbi            = 1'b0;
        end
        default:
            begin
                next_lbc_proc_state     = LBC_IDLE;
                next_lbc_cdm_dbi        = 1'b0;
                next_lbc_cdm_cs         = 1'b0;
                next_lbc_ext_cs         = 1'b0;
            end
    endcase // case(lbc_proc_state)
end // always @ (...

always@(*)
begin
    case (lbc_proc_state)
        LBC_IDLE:
            if (good_hv && status_sc && !int_radm_zerobyte ) begin
             rcrb_access_wire           = ((rcvd_memrd_or_mrdlk_req | rcvd_memwr_req) && (int_addr[63:12] == rcrb_base_addr) && cxl_link_enable); 
             rcrb_mbar0_access_wire     = ((rcvd_memrd_or_mrdlk_req | rcvd_memwr_req) &&  (int_addr[63:16] == rcrb_mbar0_base_addr[63:16]) && cxl_link_enable);
             cxl_2_0_mbar0_access_wire  = ( cxl_2_0_mbar0_access && cxl_mbar0_enable);
             rcrb_access_dbi            = 1'b0; 
             rcrb_mbar0_access_dbi      = 1'b0; 
            end else if (int_dbi_cs && !good_hv & !int_radm_hv && !int_radm_trgt0_pending) begin
             rcrb_access_dbi       = (dbi_cs2 & dbi_cs & dbi_addr[0] & ~dbi_addr[30] & dbi_addr[23] & ~dbi_addr[22]);
             rcrb_mbar0_access_dbi = (dbi_cs2 & dbi_cs & dbi_addr[0] & ~dbi_addr[30] & dbi_addr[23] & dbi_addr[22]) || (cxl_2_0_mbar0_dbi && cxl_mbar0_enable);
             rcrb_access_wire        = 1'b0; 
             rcrb_mbar0_access_wire  = 1'b0;  
             cxl_2_0_mbar0_access_wire = 1'b0;

            end else begin
             rcrb_access_wire       = 1'b0;
             rcrb_mbar0_access_wire = 1'b0;
             cxl_2_0_mbar0_access_wire = 1'b0;
             rcrb_access_dbi        = 1'b0; 
             rcrb_mbar0_access_dbi  = 1'b0;   
           end  
        default:
           begin
             rcrb_access_wire       = 1'b0;
             rcrb_mbar0_access_wire = 1'b0;
             cxl_2_0_mbar0_access_wire = 1'b0;
             rcrb_access_dbi        = 1'b0; 
             rcrb_mbar0_access_dbi  = 1'b0;  
           end
    endcase // case(lbc_proc_state)           
end

// Offset 0x1110 to 0x1147 contains the Link Layer Cap Structure. With the Link Layer Cap sitting parallel to the ELBI, this offset range should not be mapped on to CDM but instead should be mapped to the ELBI.
assign rcrb_mbar0_access_wire_int = rcrb_mbar0_access_wire & ((int_addr[15:0] >= 16'h1000 && int_addr[15:0] <= 16'h100F) || (int_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_RAS_CAP_PTR) && int_addr[15:0] < (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR)) || (int_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 16'h0038) && int_addr[15:0] <= 16'h11FF) || (int_addr[15:0] >= 16'hE000 && int_addr[15:0] <= 16'hE3FF));      
assign rcrb_mbar0_access_wire_ext = rcrb_mbar0_access_wire & ~rcrb_mbar0_access_wire_int;

assign cxl_2_0_mbar0_access_wire_int = cxl_2_0_mbar0_access_wire & ((cxl_2_0_mbar0_addr[15:0] >= 16'h1000 && cxl_2_0_mbar0_addr[15:0] <= 16'h100F) || (cxl_2_0_mbar0_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_RAS_CAP_PTR) && cxl_2_0_mbar0_addr[15:0] < (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR)) || (cxl_2_0_mbar0_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 16'h0038) && cxl_2_0_mbar0_addr[15:0] <= 16'h11FF) || (cxl_2_0_mbar0_addr[15:0] >= 16'hE000 && cxl_2_0_mbar0_addr[15:0] <= 16'hE3FF));

assign cxl_2_0_mbar0_access_wire_ext = cxl_2_0_mbar0_access_wire & ~cxl_2_0_mbar0_access_wire_int;   

assign rcrb_mbar0_access_dbi_int = rcrb_mbar0_access_dbi & ((dbi_addr[15:0] >= 16'h1000 && dbi_addr[15:0] <= 16'h100F) || (dbi_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_RAS_CAP_PTR) && dbi_addr[15:0] < (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR)) || (dbi_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 16'h0038) && dbi_addr[15:0] <= 16'h11FF) || (dbi_addr[15:0] >= 16'hE000 && dbi_addr[15:0] <= 16'hE3FF));
assign rcrb_mbar0_access_dbi_ext = rcrb_mbar0_access_dbi & ~rcrb_mbar0_access_dbi_int;

assign mbar0_link_cap_access = ((rcrb_mbar0_access_wire & (int_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR) && int_addr[15:0] < (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 16'h0038))) || (rcrb_mbar0_access_dbi & (dbi_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR) && dbi_addr[15:0] < (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 16'h0038))) || (cxl_2_0_mbar0_access_wire & (cxl_2_0_mbar0_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR) && cxl_2_0_mbar0_addr[15:0] < (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 16'h0038))));


always @(posedge core_clk or negedge core_rst_n)
begin : LATCH_ACK_SIGNALS
  if (!core_rst_n)
    begin
      cdm_lbc_ack_d <= {NF{1'b0}};
      ext_lbc_ack_d <= {NF{1'b0}};
    end
  else begin
    cdm_lbc_ack_d <= cdm_lbc_ack_tmp;
    ext_lbc_ack_d <= ext_lbc_ack;
  end
end

assign cdm_lbc_ack_pulse = cdm_lbc_ack_tmp & ~cdm_lbc_ack_d;
assign ext_lbc_ack_pulse = ext_lbc_ack & ~ext_lbc_ack_d;

// When local bus access returned the data of read
// we will latch it for the later completion tlp formation
always @(posedge core_clk or negedge core_rst_n)
begin : MUX_OUTPUTS
integer i,j;

    if (!core_rst_n)
    begin
        elbi_cpl <= #TP 0;
        latchd_lbc_din <= #TP 0;

    end
    else
        if ((|cdm_lbc_ack_tmp) & (!ext_lbc_override_en_nxt) & (!(|lbc_cdm_wr_int)))
        begin
            elbi_cpl <= #TP 0;     // Completion is via CDM
            latchd_lbc_din[LBC_INT_WD-1:32] <= #TP 0;
            for (i = 0; i<NF; i = i+1)
                if (cdm_lbc_ack_pulse[i])
                    for (j=0; j<32; j=j+1) begin
                        latchd_lbc_din[j] <= #TP cdm_lbc_din_tmp[i*32+j];
                    end
        end
        else
        begin
            if ((|ext_lbc_ack) & (!(|lbc_ext_wr)))
            begin
                elbi_cpl <= #TP 1;     // Completion is via ELBI
                for (i = 0; i<NF; i = i+1)
                    if (ext_lbc_ack_pulse[i])
                      for (j=0; j<LBC_INT_WD; j=j+1) begin
                            latchd_lbc_din[j] <= #TP int_lbc_din[i*LBC_INT_WD+j];
                      end
            end
        end
end

always @(*)
begin : INT_LBC_DIN_MUX
    int_lbc_din = ext_lbc_din;
end

// ------------------------ Completion Generation Section -----------
// all read requests and non posted write requests required completions.
// completion state machine is designed to drive 32 bits completion bus to
// xadm for the transmission of tlp
//


wire [6:0] tmp_type;
assign tmp_type  =   (latchd_status_sc & latchd_rcvd_np_rd & latchd_rcvd_locked_rd) ? `CPLDLK
                         : (latchd_status_sc & latchd_rcvd_np_rd & !latchd_rcvd_locked_rd) ? `CPLD
                         : (latchd_rcvd_locked_rd) ? `CPLLK
                         : `CPL ;
wire [15:0]   cmpltr_vf_rid;

wire [15:0]   cmpltr_id;
assign cmpltr_id     = {cfg_pbus_num, cfg_pbus_dev_num, latchd_rcvd_func_id};

assign     tlp_byte_len = elbi_cpl ? {1'b0, latchd_rcvd_tlp_len, 2'b0} : 13'h0004; // Length = 1 or 2 DW if ELBI completion, else 1 DW.

assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_ADDR     ] = {57'b0, latchd_lower_addr[6:0]}; // low address is overlayed on the regular address location
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_FMT      ] = tmp_type[6:5];
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_TYPE     ] = tmp_type[4:0];
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_TC       ] = latchd_rcvd_tc;
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_TD       ] = 1'b0;
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_EP       ] = 1'b0;
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_ATTR     ] = latchd_rcvd_attr;
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_BYTE_LEN ] = (latchd_rcvd_np_rd & latchd_status_sc) ? tlp_byte_len : 13'h0000;
assign     lbc_cpl_hdr_nxt[`F_HDR_TLP_TAG      ] = latchd_rcvd_tag;
assign     lbc_cpl_hdr_nxt[`F_HDR_CPL_REQ_ID   ] = latchd_rcvd_reqid[15:0];
assign     lbc_cpl_hdr_nxt[`F_HDR_CPL_BYTE_CNT ] = latchd_byte_cnt[11:0];
assign     lbc_cpl_hdr_nxt[`F_HDR_CPL_BCM      ] = 1'b0;
assign     lbc_cpl_hdr_nxt[`F_HDR_CPL_STATUS   ] = latchd_cpl_status[2:0];
assign     lbc_cpl_hdr_nxt[`F_HDR_REQ_ID   ]     = cmpltr_id;
assign     lbc_cpl_hdr_nxt[`F_HDR_BYTE_EN      ] = 0;
assign     lbc_cpl_hdr_nxt[`F_HDR_ADDR_ALIGN_EN] = 1'b1;
assign     lbc_cpl_hdr_nxt[`F_HDR_REQ_SEG_ID   ] = latchd_req_seg_id;


assign     lbc_cpl_data_int                  = (elbi_cpl & lbc_ext_addr[2]) ? {32'd0, latchd_lbc_din[63:32]} : latchd_lbc_din;

wire [DW-1:0] rasdp_cpl_data_int;
assign rasdp_cpl_data_int = {{(DW-LBC_INT_WD){1'b0}}, lbc_cpl_data_int};

wire [ST_HDR+HDR_PROT_WD-1:0] rasdp_lbc_cpl_hdr_out;
wire [DW+DATA_PAR_WD-1:0]     rasdp_lbc_cpl_data_out;
reg  [ST_HDR+HDR_PROT_WD-1:0] lbc_cpl_hdr_reg;
reg  [DW+DATA_PAR_WD-1:0]     lbc_cpl_data_reg;

//Since the LBC can process DBI requests and a NP TLP at the same time (multi-threading),
//the CPL data/hdr/prfx signals and the CPL pf/vf signals must be latched when it is ready (i.e. The current state is LBC_IN_CPL_REQ).
//This avoids corrupting the CPL data/hdr/prfx and the DBI read data. 

always @(posedge core_clk or negedge core_rst_n) begin : LATCH_CPL_DATA
  if (!core_rst_n) begin
    lbc_cpl_data_reg <= #TP {(DW+DATA_PAR_WD){1'b0}};
    lbc_cpl_hdr_reg  <= #TP {(ST_HDR+HDR_PROT_WD){1'b0}};
  end
  else begin
    if (lbc_proc_state == LBC_IN_CPL_REQ) begin
      lbc_cpl_data_reg <= #TP rasdp_lbc_cpl_data_out;
      lbc_cpl_hdr_reg  <= #TP rasdp_lbc_cpl_hdr_out;
    end
  end
end

assign lbc_cpl_hdr  = lbc_cpl_hdr_reg ;  
assign lbc_cpl_data = lbc_cpl_data_reg;

//Before multithreading, lbc_cdm_pf/vf were passed exactly the same to CDM and XADM modules.
//After multithreading, lbc_cdm_pf/vf are passed to CDM only and lbc_cpl_pf/vf are passed to XADM only.
//The main difference between lbc_cdm_pf/vf and lbc_cpl_pf/vf is that:
//1) lbc_cdm_pf/vf: 
//   - Changes whenever there is a new RADM request or a new DBI request.
//   - RADM or DBI requests can update it.
//   - If there is a new DBI request, can be updated even if there is a pending CPL.
//2) lbc_cpl_pf/vf: 
//   - Changes whenever there is a new RADM request only. 
//   - Only RADM request can update it. DBI requests can never update it.
//   - Can never be updated if there is a pending CPL or not.


 wire   ras_err_inj_data_done;
 assign ras_err_inj_done = ras_err_inj_data_done


                           ;
// wire [DW-1:0] rasdp_cpl_data_int;
// `ifdef CX_NW_GTR_1
// assign rasdp_cpl_data_int = {{(DW-LBC_INT_WD){1'b0}}, lbc_cpl_data_int};
// `else
// assign rasdp_cpl_data_int = lbc_cpl_data_int;
// `endif
 bus_protect_gen
  #(
  .PROT_TYPE  (RAS_PROT_TYPE),
  .PROT_RANGE (RAS_PROT_RANGE),
  .PROT_WD    (DATA_PAR_WD),
  .DATA_WD    (DW         ),
  .PARITY_MODE( RAS_PARITY_MODE     ) 
  ) 
  u_lbc_data_gen(
    .gen        (1'b1),
    .datain     (rasdp_cpl_data_int),
      .core_clk              (core_clk  ),
      .core_rst_n            (core_rst_n),
      .error_inj_mask        (ras_err_inj_mask[DATA_PAR_WD+DW-1:0]),
      .error_inj_en          (ras_err_inj_en_array[10]),
      .error_inj_data_valid  (lbc_proc_state == LBC_IN_CPL_REQ),
      .error_inj_eot         (lbc_proc_state == LBC_IN_CPL_REQ),
      .error_inj_done        (ras_err_inj_data_done),  
//---------- Outputs --------------
    .chkout     (rasdp_lbc_cpl_data_out[DATA_PAR_WD+DW-1:DW]),
    .dataout    (rasdp_lbc_cpl_data_out[DW-1:0])
  );

  bus_protect_gen
   #(
    .PROT_TYPE  ( RAS_PROT_TYPE        ),
    .PROT_RANGE ( RAS_PROT_RANGE       ),
    .PROT_WD    ( HDR_PROT_WD          ),
    .DATA_WD    ( ST_HDR               ),
    .PARITY_MODE( RAS_PARITY_MODE      )
    )
    u_lbc_cpl_hdr_gen(
      .gen        ( 1'b1                             ),
      .datain     ( lbc_cpl_hdr_nxt                  ),
      .core_clk              (core_clk  ),
      .core_rst_n            (core_rst_n),
      .error_inj_mask        (ras_err_inj_mask[HDR_PROT_WD+ST_HDR-1:0]),
      .error_inj_en          (ras_err_inj_en_array[11]),
      .error_inj_data_valid  (lbc_proc_state == LBC_IN_CPL_REQ),
      .error_inj_eot         (lbc_proc_state == LBC_IN_CPL_REQ),
      .error_inj_done        (ras_err_inj_hdr_done),
      .chkout     ( rasdp_lbc_cpl_hdr_out[ST_HDR +: HDR_PROT_WD] ),
      .dataout    ( rasdp_lbc_cpl_hdr_out[ST_HDR-1:0]           ))
     ;


always @(posedge core_clk or negedge core_rst_n)
begin: GEN_CPL_HDR
    if (!core_rst_n)
    begin
        lbc_cpl_hv      <= #TP 0;
        lbc_cpl_dv      <= #TP 0;
        lbc_cpl_eot     <= #TP 0;
    end
    else
    begin
        // when it is a read request, it will have completion with
        // data
        // 1. when we are in CPL processing state, then we will set
        // request
        // 2. when a completion has been acknowledged, then will
        // deassert the request, a completion can have 3 hdr and
        // 1 data if it is a read
        // NOte: When a Read Completion is received with a Completion Status other than successful CPL:
        // - No data is included with the CPL, the CPL (or CPLLK) encoding is used instead of CPLD (CPLDLK)

        if (( lbc_proc_state == LBC_IN_CPL_REQ) & !lbc_cpl_hv) begin
         lbc_cpl_dv       <= #TP latchd_rcvd_np_rd && latchd_status_sc;
         lbc_cpl_hv       <= #TP 1'b1;
         lbc_cpl_eot      <= #TP 1'b1;
       end else if (!xadm_cpl_halt) begin
         lbc_cpl_dv       <= #TP 1'b0;
         lbc_cpl_hv       <= #TP 1'b0;
         lbc_cpl_eot      <= #TP 1'b0;
       end
    end
end // block: GEN_CPL_HDR

// Sending CPL w/ CA.
// Needed for error reporting when core internally generate CPL w/ CA.
assign lbc_xmt_cpl_ca = {{(NF-1){1'b0}} , ((cmpltr_id[NFUNC_WD-1:0] == 0)          &
                                            lbc_cpl_hv                             &
                                            !xadm_cpl_halt                         &
                                            (latchd_cpl_status == `CA_CPL_STATUS))
                                                                                   };

// output process for external dbi interface

     reg   dbi_data_sel;

     assign lbc_dbi_dout = dbi_data_sel ? latchd_lbc_din[63:32] : latchd_lbc_din[31:0];

     always @(posedge core_clk or negedge core_rst_n)
     begin
         if (!core_rst_n)
              dbi_data_sel   <= #TP 0;
         else
              dbi_data_sel   <= #TP dbi_addr[2] & ~(|cdm_lbc_ack_tmp & ~ext_lbc_override_en_nxt & ~(|lbc_cdm_wr_int)) ? 1'b1 : 1'b0;
     end


always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
         int_lbc_dbi_ack    <= #TP 0;
    else
         int_lbc_dbi_ack    <= #TP ((lbc_proc_state == LBC_EXT_DBI_REQ) & (((|cdm_lbc_ack_tmp) & !ext_lbc_override_en_nxt) || (|ext_lbc_ack))) ||
                               (next_lbc_proc_state == LBC_RETURN_ERR);
end

// To ensure fairness between the DBI requester and the RADM requester,
// BLock the RADM interface if one the following conditions are met:
//   (1) When the LBC has just completed processing a NP request.
//   (2) When the LBC has just completed processing a  P request and there is a pending DBI request.
// The RADM blocking is de-asserted if one of the following conditions are met:
//   (1) When the XADM halt is de-asserted and there is a CPL ready to be transmitted.
//   (2) When the LBC has just completed processing a DBI request and there is no CPL ready to be transmitted.
 
always @(posedge core_clk or negedge core_rst_n)
begin
  if (!core_rst_n) begin
    lbc_arb_halt_radm <= #TP 1'b0;
  end
  else begin
    if( (lbc_proc_state == LBC_IN_CPL_REQ                                               ) | 
        (lbc_proc_state == LBC_NP_ASSERT  & next_lbc_proc_state == LBC_IDLE & int_dbi_cs) 
      ) begin
      lbc_arb_halt_radm <= #TP 1'b1;
    end
    else begin
      if ( ( !xadm_cpl_halt & lbc_cpl_hv ) | ( lbc_proc_state == LBC_EXT_DBI_REQ  & next_lbc_proc_state == LBC_IDLE & !lbc_cpl_hv ) ) begin
        lbc_arb_halt_radm <= #TP 1'b0;
      end
    end
  end
end

// Halt can be generated from lbc and slave states to control the np and
// p interface with RADM independently. This is due to the memory read and
// write access can go through to lbc or slave interface
//
//Since we latchd the request transaction for better timing, then we halt
//under following conditions:
//1. when lbc proc state is not idle
//2. when lbc proc state is idle and the request is being latchd
//3. When LBC is completing a RADM CPL and DBI Req is Pending
assign  radm_halt = (lbc_proc_state != LBC_IDLE) | lbc_arb_halt_radm | wspif_crd_full;

// external lbc interface output drives
assign  lbc_ext_dout      = latchd_data;
assign  lbc_cdm_data_int  = latchd_cdm_data;

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        lbc_ext_rom_access       <= #TP 0;
        lbc_ext_io_access        <= #TP 0;
        lbc_ext_bar_num          <= #TP `RADM_OUTSIDE_MEMBAR;
        lbc_ext_wr               <= #TP 0;
        lbc_ext_rd               <= #TP 0;
        lbc_ext_addr             <= #TP 0;
    end
    else
    begin
        if (int_radm_hv & !radm_halt) begin
            lbc_ext_rom_access   <= #TP rom_in_range    && (rcvd_memrd_req || rcvd_memwr_req);
            lbc_ext_io_access    <= #TP io_req_in_range && (rcvd_iord_req  || rcvd_iowr_req );
            lbc_ext_bar_num      <= #TP in_bar_range;

            lbc_ext_wr           <= #TP rcvd_np_rd ? 0 : int_addr_low[2] ? {first_be, last_be} : {last_be, first_be};
            lbc_ext_rd           <= #TP rcvd_np_rd ? int_addr_low[2] ? {first_be, last_be} : {last_be, first_be} : 0;


            lbc_ext_addr         <= #TP int_addr_low[LBC_EXT_AW-1:0];
        end else if (!radm_halt || (int_dbi_cs & lbc_proc_state == LBC_IDLE)) begin

            lbc_ext_rom_access   <= #TP dbi_rom_access;
            lbc_ext_io_access    <= #TP dbi_io_access;
            lbc_ext_bar_num      <= #TP dbi_bar_num;
            lbc_ext_wr           <= #TP dbi_elbi_wr;
            lbc_ext_rd           <= #TP dbi_elbi_rd;
            lbc_ext_addr         <= #TP {dbi_addr[LBC_EXT_AW-1:1], 1'b0};
        end

    end
end


assign select_radm = (cic_hv & cic_dv & ~radm_halt) | (cic_dv & cic_eot & ~cic_hv & latchd_rcvd_len_good);
assign select_dbi  = int_dbi_cs & (lbc_proc_state==LBC_IDLE);

// Data bus output process
always @(posedge core_clk or negedge core_rst_n)
begin:  DBI_REGS
    if(!core_rst_n) begin
        latchd_data              <= #TP 0;
    end
    else if (select_radm)
    begin
        latchd_data              <= #TP radm_elbi_data;
    end
    else if (select_dbi)
    begin
        latchd_data              <= #TP dbi_elbi_din;          // park on dbi interface
    end
end


// Select DBI data

always @(*)
begin:  SELECT_DBI_DIN_64
    if (dbi_addr[2])
    begin
        dbi_elbi_din[63:32] = dbi_din;
        dbi_elbi_din[31:0]  = 0;
        dbi_elbi_wr[7:4]    = dbi_wr;
        dbi_elbi_wr[3:0]    = 0;
        dbi_elbi_rd[7:4]    = dbi_cs && ~(|dbi_wr) ? 4'hf : 0;
        dbi_elbi_rd[3:0]    = 0;
    end
    else
    begin
        dbi_elbi_din[63:32] = 0;
        dbi_elbi_din[31:0]  = dbi_din;
        dbi_elbi_wr[7:4]    = 0;
        dbi_elbi_wr[3:0]    = dbi_wr;
        dbi_elbi_rd[7:4]    = 0;
        dbi_elbi_rd[3:0]    = dbi_cs && ~(|dbi_wr) ? 4'hf : 0;
    end
end


always @(posedge core_clk or negedge core_rst_n)
begin:  DBI_REGS_TO_CDM
    if(!core_rst_n) begin
        latchd_cdm_data      <= #TP 0;
    end
    else if (select_radm)
    begin
        latchd_cdm_data      <= #TP int_radm_data[LBC_DW-1:0];
    end
    else if (int_dbi_cs & lbc_proc_state==LBC_IDLE)
    begin
        latchd_cdm_data  <= #TP dbi_din[LBC_DW-1:0];          // park on dbi interface
    end
end



//UNROLL Request from dbi

assign unroll_dbi_request =                            ( dbi_addr[31:22] == 10'b0000000000   & dbi_addr[0] & int_dbi_cs2);


//UNROLL BAR MASK      
case (`UNROLL_BAR_NUM)
  0: begin: UNROLL_BAR_NUM_0 assign unroll_bar_mask = cfg_bar0_mask [64*`UNROLL_FUNC_NUM +: 64]; end
  1: begin: UNROLL_BAR_NUM_1 assign unroll_bar_mask = {{32{1'b0}},cfg_bar1_mask [32*`UNROLL_FUNC_NUM +: 32]}; end
  2: begin: UNROLL_BAR_NUM_2 assign unroll_bar_mask = cfg_bar2_mask [64*`UNROLL_FUNC_NUM +: 64]; end
  3: begin: UNROLL_BAR_NUM_3 assign unroll_bar_mask = {{32{1'b0}},cfg_bar3_mask [32*`UNROLL_FUNC_NUM +: 32]}; end
  4: begin: UNROLL_BAR_NUM_4 assign unroll_bar_mask = cfg_bar4_mask [64*`UNROLL_FUNC_NUM +: 64]; end
  5: begin: UNROLL_BAR_NUM_5 assign unroll_bar_mask = {{32{1'b0}},cfg_bar5_mask [32*`UNROLL_FUNC_NUM +: 32]}; end
  default:begin: UNROLL_BAR_NUM_dflt assign unroll_bar_mask = cfg_bar0_mask [64*`UNROLL_FUNC_NUM +: 64]; end
endcase






always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        lbc_cdm_wr_int               <= #TP 0;
        lbc_cdm_addr_int         <= #TP 0;
        lbc_cdm_unroll_int       <= #TP 0;
    end
    else if (int_radm_hv & !radm_halt)
    begin
        lbc_cdm_wr_int           <= #TP rcvd_np_rd ? 4'b0 : first_be;

              if (rcrb_access_wire | rcrb_mbar0_access_wire) begin
                lbc_cdm_addr_int[LBC_DW-1:00]  <= #TP int_addr_low[LBC_DW-1:0];
                lbc_cdm_unroll_int             <= #TP 1'b0;
              end 
              else if (cxl_2_0_mbar0_access_wire) begin
                lbc_cdm_addr_int[LBC_DW-1:00]  <= #TP cxl_2_0_mbar0_addr[LBC_DW-1:0];
                lbc_cdm_unroll_int             <= #TP 1'b0;
              end
              else
              begin
                lbc_cdm_addr_int         <= #TP {rcvd_bus_nmbr,rcvd_dvc_nmbr,{(3 - NFUNC_WD) {1'b0}},access_func_id,4'h0,int_addr_low[11:0]};
                lbc_cdm_unroll_int       <= #TP 1'b0;
              end

    end
    else if (int_dbi_cs & lbc_proc_state == LBC_IDLE)
    begin
        lbc_cdm_wr_int               <= #TP dbi_wr   ;
        
        lbc_cdm_unroll_int           <= #TP unroll_dbi_request;  


          lbc_cdm_addr_int             <= #TP {dbi_addr[LBC_DW-1:1],1'b0};

        
    end
end





  assign int_dbi_cs  = dbi_cs;
  assign int_dbi_cs2 = dbi_cs2;
  assign lbc_dbi_ack = int_lbc_dbi_ack;






// SPIF.CFG Interface ------------------------------------------------------------------------------------------------------------------------------------------

assign wlbc_wire_access_en = good_hv && status_sc && !int_radm_zerobyte;
assign wlbc_dbi_access_en  = int_dbi_cs && !good_hv & !int_radm_hv && !int_radm_trgt0_pending;

// Decoding each destination when in WIRE access
// MEM Access related
// CFG Access related
assign wspif_cfg_access_wire       = rcvd_cfg0rd_req | rcvd_cfg0wr_req;

// Decoding each destination when in DBI access
// MEM Access related
// CFG Access related
assign wspif_cfg_access_dbi        = dbi_cs && (!dbi_cs2) && ((dbi_addr & SPIF_CFG_CDM_ACCESS_MASK  ) == SPIF_CFG_CDM_ACCESS_DECODE  );

// These two signals are only for disable the CS of LBC_CDM interface
assign wspif_access_wire = 1'b0;
assign wspif_access_dbi  = 1'b0;

// Get the target SPIF.CFG destination
always @(posedge core_clk or negedge core_rst_n) begin : sspif_access_PROC
  if (!core_rst_n) begin
    wspif_mem_access_rcbr_membar0 <= 1'b0;
    wspif_cfg_access              <= 1'b0;
  end else begin
    case (lbc_proc_state)
    LBC_IDLE : begin
      if ((rcvd_func_id == {NFUNC_WD{1'b0}}) && wlbc_wire_access_en) begin // Wire Access
          // MEM Access related
          wspif_mem_access_rcbr_membar0 <= rcrb_mbar0_access_wire_int || cxl_2_0_mbar0_access_wire_int;
          // CFG Access related
          wspif_cfg_access              <= wspif_cfg_access_wire;
      end else begin
        if (wlbc_dbi_access_en) begin // DBI Access
          // MEM Access related
          wspif_mem_access_rcbr_membar0 <= rcrb_mbar0_access_dbi_int;
          // CFG Access related
          wspif_cfg_access              <= wspif_cfg_access_dbi;
        end else begin
          wspif_mem_access_rcbr_membar0 <= 1'b0;
          wspif_cfg_access              <= 1'b0;
        end
      end
    end

    default : begin
      wspif_mem_access_rcbr_membar0 <= 1'b0;
      wspif_cfg_access              <= 1'b0;
    end
    endcase
  end
end // sspif_access_PROC

// Address filtering for SPIF.CFG access
assign wspif_access_cfg_cap_reg  = wspif_cfg_access &&
                                   1'b0; // No Register is used by SPIF.CFG Interface

assign wspif_access_cxl_port_reg = wspif_cfg_access &&
                                   1'b0; // No Register is used by SPIF.CFG Interface

assign wspif_access_rcbr_membar0 = wspif_mem_access_rcbr_membar0 &&
                                   1'b0; // No Register is used by SPIF.CFG Interface

// DSTID header field definition
// Only use the two MSb for distinguish each destination.
always @(*) begin : cspif_dstid_PROC
  case (1)
    wspif_access_cfg_cap_reg  : {wspif_matched_req,wspif_req_dstid} = {1'b1,5'b00_000};
    wspif_access_cxl_port_reg ,
    wspif_access_rcbr_membar0 : {wspif_matched_req,wspif_req_dstid} = {1'b1,5'b01_000};
    default                   : {wspif_matched_req,wspif_req_dstid} = {1'b0,5'b00_000};
  endcase
end // cspif_dstid_PROC

assign wpsif_req_fw = lbc_cdm_dbi2_int & dbi_ro_wr_en;

// SPIF.CFG Address manipulation
// Some Destinations require the address to be within a specific range.
always @(*) begin : cspif_req_addr_PROC
  case (1)
    wspif_access_cfg_cap_reg  : wspif_req_addr = lbc_cdm_addr_int[23:0];
    wspif_access_cxl_port_reg : wspif_req_addr = lbc_cdm_addr_int[23:0];
    wspif_access_rcbr_membar0 : wspif_req_addr = {12'b1111_0000_0000, lbc_cdm_addr_int[11:0]};
    default                   : wspif_req_addr = lbc_cdm_addr_int[23:0];
  endcase
end // cspif_req_addr_PROC

// Physical Function definition
generate
  if (NFUNC_WD >= 8) begin

    always @(*) begin
      if (wspif_cfg_access) begin
        // For CFG access use the Function provided by DBI or WIRE
        if (wlbc_wire_access_en) begin
          wspif_req_pf = access_func_id;
        end else begin
          if (wlbc_dbi_access_en) begin
            wspif_req_pf = dbi_rcvd_func_id;
          end else begin
            wspif_req_pf = 8'b0;
          end
        end
      end else begin
        // For non-CFG access set Function to 0 to prevent non-valid values to be sampled
        wspif_req_pf = 8'b0;
      end
    end

  end else begin

    always @(*) begin
      if (wspif_cfg_access) begin
        // For CFG access use the Function provided by DBI or WIRE
        if (wlbc_wire_access_en) begin
          wspif_req_pf = {{(8-NFUNC_WD){1'b0}}, access_func_id[NFUNC_WD-1:0]};
        end else begin
          if (wlbc_dbi_access_en) begin
            wspif_req_pf = {{(8-NFUNC_WD){1'b0}}, dbi_rcvd_func_id[NFUNC_WD-1:0]};
          end else begin
            wspif_req_pf = 8'b0;
          end
        end
      end else begin
        // For non-CFG access set Function to 0 to prevent non-valid values to be sampled
        wspif_req_pf = 8'b0;
      end
    end

  end
endgenerate

always @(posedge core_clk or negedge core_rst_n) begin : sspif_req_pf_1d_PROC
  if (!core_rst_n) begin
    rspif_req_pf_1d <= #TP 8'b0;
  end else begin
    if (wspif_matched_req) begin
      rspif_req_pf_1d <= #TP wspif_req_pf;
    end
  end
end // sspif_req_pf_1d_PROC

assign wspif_req_we = (|lbc_cdm_wr_int);
assign wspif_req_be = wspif_req_we ? lbc_cdm_wr_int : 4'b1111;

// SPIF.CFG Control Module
spif_cfg_control
 #(
  .MP_SPIF_DW   (LBC_DW   ), // Data Width
  .MP_SPIF_NCFG (SPIF_NCFG), // Width of SPIF Configuration Interface data (*_cfg_data)
  .MP_SPIF_CRD  (1        )  // Available credits of SPIF.CFG Interface
  )
  u_spif_cfg_control(
    .core_clk            (core_clk                             ),
    .core_rst_n          (core_rst_n                           ),
    .ispif_req_trigger_p (wspif_matched_req                    ),
    .ispif_req_data      (lbc_cdm_data_int                     ),
    .ispif_req_addr      (wspif_req_addr                       ),
    .ispif_req_pf        (wspif_req_pf                         ),
    .ispif_req_vf        (9'b0                                 ),
    .ispif_req_we        (wspif_req_we                         ),
    .ispif_req_be        (wspif_req_be                         ),
    .ispif_req_fw        (wpsif_req_fw                         ),
    .ispif_req_sh        (lbc_cdm_dbi2_int                     ),
    .ispif_req_type      (wspif_cfg_access                     ),
    .ispif_req_dstid     (wspif_req_dstid                      ),
    .ospif_req_crd_full  (wspif_crd_full                       ),
    .ispif_pl_cfg_vld    (b_lbc_control_spif_cfg.s_pl_cfg_vld  ),
    .ispif_pl_cfg_data   (b_lbc_control_spif_cfg.s_pl_cfg_data ),
    .ospif_cpl_data      (wspif_cpl_pkt_data                   ),
    .ospif_cpl_data_p    (wspif_cpl_pkt_data_p                 ),
    .ospif_cpl_avail_p   (wspif_cpl_pkt_avail_p                ),
    .ospif_cpl_err       (                                     ), //TODO_SPIF_CFG - Connect Error status to XADM
    .ospif_lp_cfg_vld    (b_lbc_control_spif_cfg.s_lp_cfg_vld  ),
    .ospif_lp_cfg_data   (b_lbc_control_spif_cfg.s_lp_cfg_data )
);

// The DBI Interface needs the ACK signal to be high during two clock cycles.
// Sample the data and data_avail to fullfil this requirement.
always @(posedge core_clk or negedge core_rst_n) begin : sspif_cpl_pkt_data_sample_PROC
  if (!core_rst_n) begin
    rspif_cpl_pkt_data_sample <= {LBC_DW{1'b0}};
  end else begin
    if (wspif_cpl_pkt_avail_p & wspif_cpl_pkt_data_p) begin
      rspif_cpl_pkt_data_sample <= wspif_cpl_pkt_data;
    end else begin
      rspif_cpl_pkt_data_sample <= {LBC_DW{1'b0}};
    end
  end
end // sspif_cpl_pkt_data_PROC

assign wspif_cpl_pkt_data_or = wspif_cpl_pkt_data_p ? wspif_cpl_pkt_data : rspif_cpl_pkt_data_sample;

always @(posedge core_clk or negedge core_rst_n) begin : sspif_cpl_pkt_data_avail_PROC
  if (!core_rst_n) begin
    rspif_cpl_pkt_avail_p_1d <= 1'b0;
  end else begin
    rspif_cpl_pkt_avail_p_1d <= wspif_cpl_pkt_avail_p;
  end
end // sspif_cpl_pkt_data_PROC

always @(*) begin : cspif_cpl_pkt_data_avail_PROC
  for (i = 0; i < NF; i = i + 1) begin
    if (rspif_req_pf_1d == i) begin
      wspif_cpl_pkt_data_avail[i] = rspif_cpl_pkt_avail_p_1d || wspif_cpl_pkt_avail_p;
    end else begin
      wspif_cpl_pkt_data_avail[i] = 1'b0;
    end
  end
end // cspif_cpl_pkt_data_avail_PROC

// SPIF.CFG Multiplexer Module
spif_cfg_mux
 #(
  .MP_SPIF_NCFG (SPIF_NCFG) // Data Width
  )
  u_spif_cfg_mux(
    .core_clk               (core_clk                             ),
    .core_rst_n             (core_rst_n                           ),
    .ispif_lp_cfg_vld_cpl   (b_lbc_control_spif_cfg.s_lp_cfg_vld  ),
    .ispif_lp_cfg_data_cpl  (b_lbc_control_spif_cfg.s_lp_cfg_data ),
    .ospif_pl_cfg_vld_cpl   (b_lbc_control_spif_cfg.s_pl_cfg_vld  ),
    .ospif_pl_cfg_data_cpl  (b_lbc_control_spif_cfg.s_pl_cfg_data ),
    .ispif_pl_cfg_vld_req0  (b_cfgi_lbc_pcie.s_pl_cfg_vld         ),
    .ispif_pl_cfg_data_req0 (b_cfgi_lbc_pcie.s_pl_cfg_data        ),
    .ospif_lp_cfg_vld_req0  (b_cfgi_lbc_pcie.s_lp_cfg_vld         ),
    .ospif_lp_cfg_data_req0 (b_cfgi_lbc_pcie.s_lp_cfg_data        ),
    .ispif_pl_cfg_vld_req1  (b_cfgi_lbc_cxl.s_pl_cfg_vld          ),
    .ispif_pl_cfg_data_req1 (b_cfgi_lbc_cxl.s_pl_cfg_data         ),
    .ospif_lp_cfg_vld_req1  (b_cfgi_lbc_cxl.s_lp_cfg_vld          ),
    .ospif_lp_cfg_data_req1 (b_cfgi_lbc_cxl.s_lp_cfg_data         ),
    .ispif_pl_cfg_vld_req2  (1'b0                                 ),
    .ispif_pl_cfg_data_req2 ({SPIF_NCFG{1'b0}}                    ),
    .ospif_lp_cfg_vld_req2  (/*UNCONNECTED*/                      ),
    .ospif_lp_cfg_data_req2 (/*UNCONNECTED*/                      )
);

// Detect when the LBC is processing a request
// This signal is intended to be used by the PM control to stop the L1
// idle_timer.
// Entering L1 when there is a NP request in the LBC causes a potential
// deadlock since the completion cannot be sent when entering L1 and single
// threaded nature of the LBC means that posted requests cannot be accepted
// until the current NP request completes.
// Entering L1 when there is a P request means there is a potential that the
// clock will be removed when that request is still active
// If posted requests cannot be accepted then it is possible that credits
// become exhausted and the link partner cannot send an active state Nak
// causing deadlock.
wire lbc_active;
assign lbc_active = lbc_proc_state == LBC_NP_ASSERT ||
    lbc_proc_state == LBC_IN_CPL_REQ ||
    cic_active || lbc_cpl_hv;

function automatic [11:0] get_byte_count;
    input   [3:0]   first_dwen;
    input   [3:0]   last_dwen;
    input   [9:0]   latchd_dwlen;

    reg     [11:0]  f_length_times4;
    reg     [11:0]  f_bytelength;
    reg     [2 :0]  f_subend;
begin

    f_length_times4 = {latchd_dwlen, 2'b0};
    f_subend = 3'b0;

    if (last_dwen == 0) begin
        case (first_dwen)
            4'b1001, 4'b1011, 4'b1101, 4'b1111 : f_bytelength = 4;
            4'b0101, 4'b0111, 4'b1010, 4'b1110 : f_bytelength = 3;
            4'b0011, 4'b0110, 4'b1100          : f_bytelength = 2;
            default                            : f_bytelength = 1;
        endcase
    end else begin
        if (first_dwen[0])
            f_subend = 0;
        else if (first_dwen[1])
            f_subend = 1;
        else if (first_dwen[2])
            f_subend = 2;
        else
            f_subend = 3;

        if (last_dwen[3])
            f_subend = f_subend + 0;
        else if (last_dwen[2])
            f_subend = f_subend + 1;
        else if (last_dwen[1])
            f_subend = f_subend + 2;
        else
            f_subend = f_subend + 3;
// spyglass disable_block W484
// SMD: Possible loss of carry or borrow due to addition or subtraction
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        f_bytelength = 12'(f_length_times4 - f_subend);
// spyglass enable_block W484
    end

    get_byte_count = f_bytelength;

end
endfunction


//VCS coverage off
`ifndef SYNTHESIS
//----------------------------------------------------------------------------------
wire    [15*8:0]         LBC_STATE;
assign  LBC_STATE   =        (lbc_proc_state  == LBC_IDLE ) ? "LBC_IDLE"   :
                             ((lbc_proc_state  == LBC_EXT_DBI_REQ  ) ? "LBC_EXT_DBI_REQ" :
                             ((lbc_proc_state  == LBC_IN_CPL_REQ   ) ? "LBC_IN_CPL_REQ" :
                             ((lbc_proc_state  == LBC_EXT_AW       ) ? "LBC_EXT_AW" :
                             ((lbc_proc_state  == LBC_NP_ASSERT    ) ? "LBC_NP_ASSERT" :
                             ((lbc_proc_state  == LBC_DW           ) ? "LBC_DW" : "ERR")))));
//----------------------------------------------------------------------------------
`endif // SYNTHESIS
//VCS coverage on

endmodule
 
