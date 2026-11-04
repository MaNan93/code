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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_ecrc_check.sv#3 $
// -------------------------------------------------------------------------
// Description: 
// --- ECRC checking for 128b/256b/512b/1024b
// --- Additional support for pipelining - CX_CRC_LATENCY cycles ; 1: no pipeline,2: pipeline 
// --- One packet CRC is computed & checked at a time
// --- Last data word i.e. with EOT is treated as recieved CRC and computed CRC is matched against constant expected CRC.
// --- The polynomial used has coefficients expressed as 32'h04C1_1DB7
// --- The seed value (initial value for ECRC storage registers) is 32'hFFFF_FFFF
// --- There are 2 seperate eCRC computation blocks for HDR and Data.
// --- HDR output can be pipelined or fed directly to Data eCRC block. 
// --- HDR_DATA_PIPE parameter is used to define this functionality i.e. if 0 not pipelie b/w HDR and Data computation.
// ---------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
 
module radm_ecrc_check

  import radm_ms_pkg::NHW;
  import radm_ms_pkg::HW;
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NW;
  import DWC_pcie_ctl_pkg::DW;
  import DWC_pcie_ctl_pkg::DATA_WIDTH;



#(
    parameter HDR_DATA_PIPE = 1,  // Can be either 0 or 1. If 1 - One stage pipeline is enabled b/w hdr and data eCRC computation 
    parameter CRC_LATENCY   = 1   // default is 1 (No Pipeline), can be set to 2 for pipelining to ease timing. Defined in module above.
)

(
    input                         core_clk,
    input                         core_rst_n,
    input [HW-1:0]                flt_hdr,            // Filter header decoded data [ HDR + End-to-End Prefix + Local prefix]
    input [NHW-1:0]               flt_hdr_dwen,       // Fliter Header data word enable - LSBs will be zero if data have local prefix 
    input                         flt_hdr_hv,         // Filter header valid
    
    input [DW-1:0]                flt_data,          // Input Filter Data
    input [NW-1:0]                flt_ddwen,         // Input filter Data Bus DW Enable -- Data will be received at the filter level with full data only. Data can be partial only in the clock cycle where EOT is present.
    input                         flt_ddv,           // Input filter Data Bus Valid
    input                         flt_eot,           // Input End of TLP
    input                         flt_ant_1dw_eot,   // Next cycle contains only 1 DW data + eot
    input  [31:0]                 form_filt_ecrc_data,
    input                         form_filt_ecrc_enable,   
 
    output                        tlp_ecrc_match_err // recieved and computed CRC not matched for pkt

);

//adds a clk cycle delay if crc pipeline on; else 0
localparam CRC_LATENCY_M1 = CRC_LATENCY-1;                 
localparam CRC_LATENCY_M2 = (HDR_DATA_PIPE) ? CRC_LATENCY : CRC_LATENCY-1;

// Max DW can be 1024 and NW can extend to 32. Above it will flag an error
// Avoided using clog2 to include this error behaviour
localparam NW_WD  = (NW>16) ? 5 : (NW>8) ? 4 : (NW>4) ? 3 : (NW>2) ? 2 : 1;
localparam NHW_WD = (NHW>8) ? 4 : (NHW>4) ? 3 : (NHW>2) ? 2 : 1;

// The value at location [32*i +: 32] is obtained rolling back a crc state of 32'hFFFFFFFF with a data pattern consisting of (i) dwords of all 0's.
// This is useful when checking the ECRC rx side and sot[i] = 1. Location [31:0] correspond to rolling back 0 bits when sot[0] = 1.
wire [511:0] ecrc_rx_init_value  = 512'hDF27BB8271C48353082FBB794191AF83869D3834E2265DB9CD55919B0D0E66733AA01F608E3D684D5FE50C641470E51CD61C3A65F50B27F746AF6449FFFFFFFF;
// wire [1023:0] ecrc_rx_init_value = 1024'h57C3764A2DFF0C2A7C7213F9D33FC690CEC67954922846E0B901392C5AC8FA4A35C169402BF2DBB44925C7AFF45E3D8E0F4FA27377A72F83FB4F5CA0E1242DB9DF27BB8271C48353082FBB794191AF83869D3834E2265DB9CD55919B0D0E66733AA01F608E3D684D5FE50C641470E51CD61C3A65F50B27F746AF6449FFFFFFFF;

// The value at location [32*i +: 32] is the expected crc state for a good tlp when eot[i] = 1 and the bits following END are filled in with zeros
wire  [1023:0] ecrc_rx_exp_value = 1024'hC704DD7B6904BB59099C5421552D22C84E26540FFBAC7C3A6811F1FE4A55AF6754B292A97243C868C799DB3E5632EEB0F20F2BCC6D5AEC34EF6EB7DF93394E514A8914F7B522BC0F667AE3F898E73B8E91A8CCD14DE5BD20189B52BC8A59D0A2AC9CEE660BBF07143040C10F424A8227B24C04081BA14563CF8F145746A0EABC >> ((32-NW)*32);
// "C704DD7B" must be aligned to the highest dword for each datapath widths

// --------------------- Logic [reg/wire] Declaration ------------------------------- //
// Delay instance outputs
logic                         flt_hdr_hv_d;
logic                         flt_ddv_d;
logic                         flt_eot_d;
logic                         flt_ant_1dw_eot_d;
logic                         flt_ant_1dw_eot_2d;
logic [HW-1:0]                flt_hdr_d; 
logic [NHW-1:0]               flt_hdr_dwen_d; 
logic [DW-1:0]                flt_data_d;
logic [NW-1:0]                flt_ddwen_d;
// For lcrc unit
logic [31:0]                  icrc_hdr;
logic [31:0]                  ocrc_hdr;
logic [31:0]                  icrc_data;
logic [31:0]                  ocrc;
// Registered variables
logic [31:0]                  ocrc_r;
logic                         flt_hdr_hv_r;
logic [31:0]                  ocrc_hdr_r;
// Initial CRC index
logic [NHW_WD-1:0]            init_crc_index; 
// Signals related for HDR & Data alignment 
logic [HW-1:0]               aligned_hdr_data;
logic [DW-1:0]                aligned_flt_data;
// Other used Signals 
logic                         crc_enable; 
logic [31:0]                  ecrc_exp;

// ---------------------- END of Logic [reg/wire] declaration ---------------------- //

// Extracting Initial CRC state based on DW
// Initial CRC value
logic [HW-1:0] crc_init_value;
assign crc_init_value = ecrc_rx_init_value[HW-1:0];

// The expected crc state for a good tlp when eot[i] = 1 and the bits following END are filled in with zeros
logic [DW-1:0] crc_exp_value;
assign crc_exp_value = ecrc_rx_exp_value[DW-1:0];

// CTRL Path
// one clk cycle delay added if crc pipeline on, else 0 delay
// Data is 1 stage pipelined in extract module
delay_n
 
  #(.N(CRC_LATENCY_M2-1), .WD(1+1)) 
  u_crc_delay_data_ctrl (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({flt_ddv, flt_eot}),
    .dout       ({flt_ddv_d, flt_eot_d})
);

// one clk cycle delay added if crc pipeline on, else 0 delay
delay_n
 
  #(.N(CRC_LATENCY_M1), .WD(1)) 
  u_crc_delay_hdr_ctrl (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (flt_hdr_hv),
    .dout       (flt_hdr_hv_d)
);

//one clk cycle delay added if crc pipeline on, else 0 delay
delay_n_w_enable
 
  #(.N(CRC_LATENCY_M1), .WD(HW+NHW)) 
  u_crc_delay_w_enable_hdr_ctrl (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (flt_hdr_hv),
    .din        ({flt_hdr,flt_hdr_dwen}),
    .dout       ({flt_hdr_d,flt_hdr_dwen_d})
);

//one clk cycle delay added if crc pipeline on, else 0 delay
// Data is 1 stage pipelined in extract module
delay_n_w_enable

  #(.N(CRC_LATENCY_M2-1), .WD(DW+NW)) 
  u_crc_delay_w_enable_data_ctrl (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (flt_ddv),
    .din        ({flt_data, flt_ddwen}),
    .dout       ({flt_data_d, flt_ddwen_d})
);


// fill in zeros after eot
assign aligned_flt_data = datatransform_eot(flt_data_d, flt_ddwen_d, flt_eot_d); 

// Initial SEED value is fed through index from constant vector
assign icrc_hdr         = flt_hdr_hv_d ? crc_init_value[32*init_crc_index +: 32] : 32'd0;

// only outputs the final state so that we can pick the correct expected value 
DWC_pcie_ctl_bcm48_sv
 
  #(.DATA_WIDTH (HW), .POLY_SIZE (32), .POLY_COEF0 (32'h1DB7), .POLY_COEF1 (32'h04C1))
  u_ecrc_hdr (
    .data_in  (hw_flipbits(aligned_hdr_data)),
    .crc_i    (icrc_hdr),
    .crc_j    (ocrc_hdr)
  );

// Initial CRC value for data is fed through output of HDR eCRC computation unit
// For long packets, CRC is loopback to compute final CRC value
assign icrc_data = /*flt_hdr_hv_r ? ocrc_hdr_r :*/ ocrc_r;

// If Parameter is '1' then pipeline stage is added b/w HDR and DATA eCRC computation to relax the timing path
generate 
  if (HDR_DATA_PIPE == 1) begin
    always_ff @(posedge core_clk or negedge core_rst_n) begin : hdr_data_pipe_seq_PROC
      if (!core_rst_n) begin
        flt_hdr_hv_r      <= #TP 0;
        ocrc_hdr_r        <= #TP 0;
      end else begin
        flt_hdr_hv_r      <= #TP flt_hdr_hv_d;
        if (flt_hdr_hv_d) 
          ocrc_hdr_r      <= #TP ocrc_hdr;
      end
    end
  end else begin
    assign ocrc_hdr_r   = ocrc_hdr;
    assign flt_hdr_hv_r = flt_hdr_hv_d;
  end

endgenerate

// only outputs the final state so that we can pick the correct expected value depending on eot when checking
DWC_pcie_ctl_bcm48_sv
 
  #(.DATA_WIDTH (DW), .POLY_SIZE (32), .POLY_COEF0 (32'h1DB7), .POLY_COEF1 (32'h04C1))
  u_ecrc_data (
   .data_in  (dw_flipbits(aligned_flt_data)),
   .crc_i    (icrc_data),
   .crc_j    (ocrc)
  );

// CRC output latch enable 
assign crc_enable = flt_ddv_d;

// Output register for loop. Need continuous loopback for larger packets
// Recieved eCRC registered for comparision
always_ff @(posedge core_clk or negedge core_rst_n) begin : oreg_seq_PROC
  if (!core_rst_n) begin
    ocrc_r             <= #TP 0;
    flt_ant_1dw_eot_d  <= #TP 0;
    flt_ant_1dw_eot_2d <= #TP 0;
  end else begin
    flt_ant_1dw_eot_d  <= #TP flt_ant_1dw_eot;
    flt_ant_1dw_eot_2d <= #TP flt_ant_1dw_eot_d;
    

      if(flt_hdr_hv_d)
      ocrc_r    <= #TP ocrc_hdr;
      else 
      if ( crc_enable ) 
      ocrc_r    <= #TP ocrc;    
  end
end

// select expected crc value to be used in the crc matching logic
assign ecrc_exp = ( flt_eot_d & flt_ddv_d ) ? extract_exp_ecrc(crc_exp_value, flt_ddwen_d) : 1'b0;

// Always pipeline is required  b/w HDR & DATA to meet timing


logic   [31:0]                    form_filt_ecrc_data_r;
logic                             form_filt_ecrc_enable_r;   
logic   [31:0]                    calculated_ecrc ;
logic   [31:0]                    received_ecrc;

 
// Pipeline delay to match with data delay.
delay_n_w_enable

  #(.N(CRC_LATENCY_M2) , .WD(33)) 
  u_crc_delay_w_enable_flop (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (1'b1),
    .din        ({form_filt_ecrc_data,form_filt_ecrc_enable}),
    .dout       ({form_filt_ecrc_data_r,form_filt_ecrc_enable_r})
);

assign calculated_ecrc = flipbits32(~ocrc);
assign  received_ecrc = (form_filt_ecrc_enable_r !=0) ? form_filt_ecrc_data_r[31:0] : flt_data[31:0];   

// Compare eCRC - Final output is send at EoT without registering
assign tlp_ecrc_match_err = ((flt_ddv & flt_ant_1dw_eot_d) || (form_filt_ecrc_enable_r !=0)) ? received_ecrc  != calculated_ecrc : ( flt_ddv_d & flt_eot_d & ~flt_ant_1dw_eot_2d) ? (ocrc != ecrc_exp) : 1'b0;

// INFO Assertion just to check the packet received with valid eCRC

// HDR align always block are generated based on DW and HW combination
always_comb begin
  aligned_hdr_data   = 0;
  init_crc_index     = 0;
  if (flt_hdr_hv_d) begin
    aligned_hdr_data = flt_hdr_d << (32*((NHW-1)-count_one(flt_hdr_dwen_d)));
    init_crc_index   = (NHW-1)-count_one(flt_hdr_dwen_d);
  end
end

// ------------------------- Function Declaration / Defination --------------------- //
// Reflect the bits of 32 bit word
function automatic logic[31:0] flipbits32 (logic[31:0] a);
    for (int i=0; i<32; i=i+1) flipbits32[i] = a[31-i];
endfunction

// reflect the bits in the full datapath word
function automatic [DW-1:0] dw_flipbits(input [DW-1:0] data);
  integer i;
  begin
      for (i=0; i<DW; i=i+1) dw_flipbits[i] = data[DW-1-i];
  end
endfunction

// reflect the bits in the full datapath word
function automatic [HW-1:0] hw_flipbits(input [HW-1:0] data);
  integer i;
  begin
      for (i=0; i<HW; i=i+1) hw_flipbits[i] = data[HW-1-i];
  end
endfunction

// count one in array -- useful when data is one hot encoded
function automatic [NHW_WD:0] count_one(input [NHW-1:0] count_one_data);
  integer i;
  logic [31:0] intermediate_bits;
  begin
    count_one = 0;
    intermediate_bits = 0;
    for (i=0; i<NHW; i=i+1) begin
      if (count_one_data[i]) begin
        intermediate_bits = i;
      end
    end
    count_one = intermediate_bits[NHW_WD:0];
  end
endfunction

// convert one-hot to binary
function automatic [NW_WD-1:0] one_hot_to_bin(input [NW-1:0] one_hot_data);
  integer i;
  logic [31:0] intermediate_bits;
  begin
    one_hot_to_bin    = 0;
    intermediate_bits = 0;
    if(NW>1) begin
      for (i=0; i<NW; i=i+1) begin
        if (one_hot_data[i]) begin
          intermediate_bits = i;
        end
      end
      one_hot_to_bin = intermediate_bits[NW_WD-1:0];
    end
  end
endfunction

// select the crc expected result to use to calculate match/mismatch
function automatic [31:0] extract_exp_ecrc (input [DW-1:0] data, input [NW-1:0] dwen);
  logic [NW_WD-1:0] index;
  begin
    extract_exp_ecrc = 0;
    if( dwen != 0 ) begin
      index = one_hot_to_bin(dwen);
      extract_exp_ecrc = data[32*index +: 32];
    end
  end
endfunction

// transform the data by setting to 32'b0 dwords after to eot based on dwen
function automatic [DW-1:0] datatransform_eot(input [DW-1:0] data, input [NW-1:0] dwen, input eot);
  integer i;
  reg [NW_WD-1:0] index;
  begin
    datatransform_eot = data;
    if( dwen != 0 && eot ) begin
      index = one_hot_to_bin(dwen);
      for (i=0; i<NW; i=i+1) begin
        if(i>index)
          datatransform_eot[32*i +: 32] = 0;
      end
    end
  end
endfunction

// -------------------------End of Function Declaration / Defination --------------------- //

endmodule
