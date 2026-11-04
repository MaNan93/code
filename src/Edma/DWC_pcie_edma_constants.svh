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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edma/DWC_pcie_edma_constants.svh#4 $
// -------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_EDMA_CONSTANTS__SVH__
`define __GUARD__DWC_PCIE_EDMA_CONSTANTS__SVH__

// *****************************************************************************
// ** (D)esign (C)onstants: DO NOT CHANGE!
// *****************************************************************************

`define DC_N_REQ_CTX       5     // Number of context requesters in the design
`define DC_LOG2_N_REQ_CTX  3     //CEIL(LOG2(DC_N_REQ_CTX))



//** Context request constants
`define DC_CTX_NOREQUEST     3'b000   //No context request
`define DC_CTX_DMA_RD_CH_RD  3'b110   //Context DMA read channel read
`define DC_CTX_DMA_WR_CH_RD  3'b010   //Context DMA write channel read
`define DC_CTX_DMA_RD_CH_WR  3'b111   //Context DMA read channel write
`define DC_CTX_DMA_WR_CH_WR  3'b011   //Context DMA write channel write

//** Context bit mapping
`define DC_CTX_BIT_CB          0
`define DC_CTX_BIT_TCB         1
`define DC_CTX_BIT_LLP         2
`define DC_CTX_BIT_LIE         3
`define DC_CTX_BIT_RIE         4
`define DC_CTX_BIT_CS          6:5
`define DC_CTX_BIT_CCS         8
`define DC_CTX_BIT_LLEN        9
`define DC_CTX_BIT_64S         10
`define DC_CTX_BIT_64D         11
`define DC_CTX_BIT_D_VF        8:1     //Note: this one is on viewport 2
`define DC_CTX_BIT_D_PF        16:12
`define DC_CTX_BIT_D_SN        24
`define DC_CTX_BIT_D_RO        25
`define DC_CTX_BIT_D_TD        26
`define DC_CTX_BIT_D_TC        29:27
`define DC_CTX_BIT_D_ATS       31:30
`define DC_CTX_BIT_XFER_SIZE   63:32
`define DC_CTX_BIT_SAR         127:64
`define DC_CTX_BIT_DAR         191:128
`define DC_CTX_BIT_ELEMENT_PTR 127:64




//** Register Addressing Constants

`define DC_CRGB_ADDR_WIDTH `CC_CRGB_ADDR_WIDTH
`define DC_CRGB_ADDR_BASE 16'h0000

`define DC_CRGB_ADDR_DMA_CTRL_DATA_ARB_PRIOR         `DC_CRGB_ADDR_BASE
`define DC_CRGB_ADDR_DMA_CTRL_CTX_ARB_PRIOR          `DC_CRGB_ADDR_BASE + 12'h004
`define DC_CRGB_ADDR_DMA_CTRL                        `DC_CRGB_ADDR_BASE + 12'h008
`define DC_CRGB_ADDR_DMA_WR_EN                       `DC_CRGB_ADDR_BASE + 12'h00C
`define DC_CRGB_ADDR_DMA_WR_DOORBELL                 `DC_CRGB_ADDR_BASE + 12'h010
`define DC_CRGB_ADDR_DMA_WR_CTRL                     `DC_CRGB_ADDR_BASE + 12'h014
`define DC_CRGB_ADDR_DMA_WR_WEIGHTS_LO               `DC_CRGB_ADDR_BASE + 12'h018
`define DC_CRGB_ADDR_DMA_WR_WEIGHTS_HI               `DC_CRGB_ADDR_BASE + 12'h01C
`define DC_CRGB_ADDR_RESERVED2                       `DC_CRGB_ADDR_BASE + 12'h024
`define DC_CRGB_ADDR_RESERVED3                       `DC_CRGB_ADDR_BASE + 12'h028
`define DC_CRGB_ADDR_DMA_RD_EN                       `DC_CRGB_ADDR_BASE + 12'h02C
`define DC_CRGB_ADDR_DMA_RD_DOORBELL                 `DC_CRGB_ADDR_BASE + 12'h030
`define DC_CRGB_ADDR_DMA_RD_CTRL                     `DC_CRGB_ADDR_BASE + 12'h034
`define DC_CRGB_ADDR_DMA_RD_WEIGHTS_LO               `DC_CRGB_ADDR_BASE + 12'h038
`define DC_CRGB_ADDR_DMA_RD_WEIGHTS_HI               `DC_CRGB_ADDR_BASE + 12'h03C
`define DC_CRGB_ADDR_RESERVED5                       `DC_CRGB_ADDR_BASE + 12'h044
`define DC_CRGB_ADDR_RESERVED6                       `DC_CRGB_ADDR_BASE + 12'h048
`define DC_CRGB_ADDR_DMA_WR_INT_STATUS               `DC_CRGB_ADDR_BASE + 12'h04C
`define DC_CRGB_ADDR_RESERVED7                       `DC_CRGB_ADDR_BASE + 12'h050
`define DC_CRGB_ADDR_DMA_WR_INT_MASK                 `DC_CRGB_ADDR_BASE + 12'h054
`define DC_CRGB_ADDR_DMA_WR_INT_CLEAR                `DC_CRGB_ADDR_BASE + 12'h058
`define DC_CRGB_ADDR_DMA_WR_ERR_STATUS               `DC_CRGB_ADDR_BASE + 12'h05C
`define DC_CRGB_ADDR_DMA_WR_MSGD_INTR_DONE_ADDR_LO   `DC_CRGB_ADDR_BASE + 12'h060
`define DC_CRGB_ADDR_DMA_WR_MSGD_INTR_DONE_ADDR_HI   `DC_CRGB_ADDR_BASE + 12'h064
`define DC_CRGB_ADDR_DMA_WR_MSGD_INTR_ABORT_ADDR_LO  `DC_CRGB_ADDR_BASE + 12'h068
`define DC_CRGB_ADDR_DMA_WR_MSGD_INTR_ABORT_ADDR_HI  `DC_CRGB_ADDR_BASE + 12'h06C
`define DC_CRGB_ADDR_DMA_WR_MSGD_INTR_CH01_DATA      `DC_CRGB_ADDR_BASE + 12'h070
`define DC_CRGB_ADDR_DMA_WR_MSGD_INTR_CH23_DATA      `DC_CRGB_ADDR_BASE + 12'h074
`define DC_CRGB_ADDR_DMA_WR_MSGD_INTR_CH45_DATA      `DC_CRGB_ADDR_BASE + 12'h078
`define DC_CRGB_ADDR_DMA_WR_MSGD_INTR_CH67_DATA      `DC_CRGB_ADDR_BASE + 12'h07C
`define DC_CRGB_ADDR_RESERVED8                       `DC_CRGB_ADDR_BASE + 12'h080
`define DC_CRGB_ADDR_RESERVED9                       `DC_CRGB_ADDR_BASE + 12'h084
`define DC_CRGB_ADDR_RESERVED10                      `DC_CRGB_ADDR_BASE + 12'h088
`define DC_CRGB_ADDR_RESERVED11                      `DC_CRGB_ADDR_BASE + 12'h08C
`define DC_CRGB_ADDR_DMA_WR_INT_LL_ERR_EN            `DC_CRGB_ADDR_BASE + 12'h090
`define DC_CRGB_ADDR_RESERVED12                      `DC_CRGB_ADDR_BASE + 12'h094
`define DC_CRGB_ADDR_RESERVED13                      `DC_CRGB_ADDR_BASE + 12'h098
`define DC_CRGB_ADDR_RESERVED14                      `DC_CRGB_ADDR_BASE + 12'h09C
`define DC_CRGB_ADDR_DMA_RD_INT_STATUS               `DC_CRGB_ADDR_BASE + 12'h0A0
`define DC_CRGB_ADDR_RESERVED15                      `DC_CRGB_ADDR_BASE + 12'h0A4
`define DC_CRGB_ADDR_DMA_RD_INT_MASK                 `DC_CRGB_ADDR_BASE + 12'h0A8
`define DC_CRGB_ADDR_DMA_RD_INT_CLEAR                `DC_CRGB_ADDR_BASE + 12'h0AC
`define DC_CRGB_ADDR_RESERVED16                      `DC_CRGB_ADDR_BASE + 12'h0B0
`define DC_CRGB_ADDR_DMA_RD_ERR_STATUS_LO            `DC_CRGB_ADDR_BASE + 12'h0B4
`define DC_CRGB_ADDR_DMA_RD_ERR_STATUS_HI            `DC_CRGB_ADDR_BASE + 12'h0B8
`define DC_CRGB_ADDR_RESERVED17                      `DC_CRGB_ADDR_BASE + 12'h0BC
`define DC_CRGB_ADDR_RESERVED18                      `DC_CRGB_ADDR_BASE + 12'h0C0
`define DC_CRGB_ADDR_DMA_RD_INT_LL_ERR_EN            `DC_CRGB_ADDR_BASE + 12'h0C4
`define DC_CRGB_ADDR_RESERVED19                      `DC_CRGB_ADDR_BASE + 12'h0C8
`define DC_CRGB_ADDR_DMA_RD_MSGD_INTR_DONE_ADDR_LO   `DC_CRGB_ADDR_BASE + 12'h0CC
`define DC_CRGB_ADDR_DMA_RD_MSGD_INTR_DONE_ADDR_HI   `DC_CRGB_ADDR_BASE + 12'h0D0
`define DC_CRGB_ADDR_DMA_RD_MSGD_INTR_ABORT_ADDR_LO  `DC_CRGB_ADDR_BASE + 12'h0D4
`define DC_CRGB_ADDR_DMA_RD_MSGD_INTR_ABORT_ADDR_HI  `DC_CRGB_ADDR_BASE + 12'h0D8
`define DC_CRGB_ADDR_DMA_RD_MSGD_INTR_CH01_DATA      `DC_CRGB_ADDR_BASE + 12'h0DC
`define DC_CRGB_ADDR_DMA_RD_MSGD_INTR_CH23_DATA      `DC_CRGB_ADDR_BASE + 12'h0E0
`define DC_CRGB_ADDR_DMA_RD_MSGD_INTR_CH45_DATA      `DC_CRGB_ADDR_BASE + 12'h0E4
`define DC_CRGB_ADDR_DMA_RD_MSGD_INTR_CH67_DATA      `DC_CRGB_ADDR_BASE + 12'h0E8
`define DC_CRGB_ADDR_RESERVED20                      `DC_CRGB_ADDR_BASE + 12'h0EC
`define DC_CRGB_ADDR_RESERVED21                      `DC_CRGB_ADDR_BASE + 12'h0F0
`define DC_CRGB_ADDR_RESERVED22                      `DC_CRGB_ADDR_BASE + 12'h0F4
`define DC_CRGB_ADDR_RESERVED23                      `DC_CRGB_ADDR_BASE + 12'h0F8
 // Channel grouping exists only with Unrolled DMA registers
`define DC_CRGB_ADDR_DMA_WR_ENG_CHGROUP              `DC_CRGB_ADDR_BASE + 12'h100
`define DC_CRGB_ADDR_DMA_RD_ENG_CHGROUP              `DC_CRGB_ADDR_BASE + 12'h104


// Address below is used by the Sw to identify if this is UNROLL MODE, when
// API Reads from this address, and the DMA returns all F for UNROLL
`define DC_CRGB_ADDR_DMA_CTX_VIEWPORT_SEL            16'hA6C


// DMA Write/Read Channel Power Enable
`define DC_CRGB_ADDR_DMA_WR_CH0_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0128
`define DC_CRGB_ADDR_DMA_WR_CH1_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h012C
`define DC_CRGB_ADDR_DMA_WR_CH2_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0130
`define DC_CRGB_ADDR_DMA_WR_CH3_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0134
`define DC_CRGB_ADDR_DMA_WR_CH4_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0138
`define DC_CRGB_ADDR_DMA_WR_CH5_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h013C
`define DC_CRGB_ADDR_DMA_WR_CH6_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0140
`define DC_CRGB_ADDR_DMA_WR_CH7_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0144
`define DC_CRGB_ADDR_RESERVED28                      `DC_CRGB_ADDR_BASE + 16'h0148
`define DC_CRGB_ADDR_RESERVED29                      `DC_CRGB_ADDR_BASE + 16'h014C
`define DC_CRGB_ADDR_RESERVED30                      `DC_CRGB_ADDR_BASE + 16'h0150
`define DC_CRGB_ADDR_RESERVED31                      `DC_CRGB_ADDR_BASE + 16'h0154
`define DC_CRGB_ADDR_RESERVED32                      `DC_CRGB_ADDR_BASE + 16'h0158
`define DC_CRGB_ADDR_RESERVED33                      `DC_CRGB_ADDR_BASE + 16'h015C
`define DC_CRGB_ADDR_RESERVED34                      `DC_CRGB_ADDR_BASE + 16'h0160
`define DC_CRGB_ADDR_RESERVED35                      `DC_CRGB_ADDR_BASE + 16'h0164
`define DC_CRGB_ADDR_DMA_RD_CH0_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0168
`define DC_CRGB_ADDR_DMA_RD_CH1_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h016C
`define DC_CRGB_ADDR_DMA_RD_CH2_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0170
`define DC_CRGB_ADDR_DMA_RD_CH3_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0174
`define DC_CRGB_ADDR_DMA_RD_CH4_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0178
`define DC_CRGB_ADDR_DMA_RD_CH5_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h017C
`define DC_CRGB_ADDR_DMA_RD_CH6_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0180
`define DC_CRGB_ADDR_DMA_RD_CH7_PWR_EN               `DC_CRGB_ADDR_BASE + 16'h0184
`define DC_CRGB_ADDR_RESERVED36                      `DC_CRGB_ADDR_BASE + 16'h0188
`define DC_CRGB_ADDR_RESERVED37                      `DC_CRGB_ADDR_BASE + 16'h018C
`define DC_CRGB_ADDR_RESERVED38                      `DC_CRGB_ADDR_BASE + 16'h0190
`define DC_CRGB_ADDR_RESERVED39                      `DC_CRGB_ADDR_BASE + 16'h0194
`define DC_CRGB_ADDR_RESERVED40                      `DC_CRGB_ADDR_BASE + 16'h0198
`define DC_CRGB_ADDR_RESERVED41                      `DC_CRGB_ADDR_BASE + 16'h019C
`define DC_CRGB_ADDR_RESERVED42                      `DC_CRGB_ADDR_BASE + 16'h01A0
`define DC_CRGB_ADDR_RESERVED43                      `DC_CRGB_ADDR_BASE + 16'h01A4

// DMA Channel Write Regiters
`define DMA_CH_CONTROL1_REG_WRCH1                    `DC_CRGB_ADDR_BASE + 16'h0200
`define DMA_CH_CONTROL2_REG_WRCH1                    `DC_CRGB_ADDR_BASE + 16'h0204
`define DMA_TRANSFER_SIZE_REG_WRCH1                  `DC_CRGB_ADDR_BASE + 16'h0208
`define DMA_SAR_LOW_REG_WRCH1                        `DC_CRGB_ADDR_BASE + 16'h020C
`define DMA_SAR_HIGH_REG_WRCH1                       `DC_CRGB_ADDR_BASE + 16'h0210
`define DMA_DAR_LOW_REG_WRCH1                        `DC_CRGB_ADDR_BASE + 16'h0214
`define DMA_DAR_HIGH_REG_WRCH1                       `DC_CRGB_ADDR_BASE + 16'h0218
`define DMA_LLP_LOW_REG_WRCH1                        `DC_CRGB_ADDR_BASE + 16'h021C
`define DMA_LLP_HIGH_REG_WRCH1                       `DC_CRGB_ADDR_BASE + 16'h0220
`define DMA_CH_CONTROL1_REG_WRCH2                    `DC_CRGB_ADDR_BASE + 16'h0400
`define DMA_CH_CONTROL2_REG_WRCH2                    `DC_CRGB_ADDR_BASE + 16'h0404
`define DMA_TRANSFER_SIZE_REG_WRCH2                  `DC_CRGB_ADDR_BASE + 16'h0408
`define DMA_SAR_LOW_REG_WRCH2                        `DC_CRGB_ADDR_BASE + 16'h040C
`define DMA_SAR_HIGH_REG_WRCH2                       `DC_CRGB_ADDR_BASE + 16'h0410
`define DMA_DAR_LOW_REG_WRCH2                        `DC_CRGB_ADDR_BASE + 16'h0414
`define DMA_DAR_HIGH_REG_WRCH2                       `DC_CRGB_ADDR_BASE + 16'h0418
`define DMA_LLP_LOW_REG_WRCH2                        `DC_CRGB_ADDR_BASE + 16'h041C
`define DMA_LLP_HIGH_REG_WRCH2                       `DC_CRGB_ADDR_BASE + 16'h0420
`define DMA_CH_CONTROL1_REG_WRCH3                    `DC_CRGB_ADDR_BASE + 16'h0600
`define DMA_CH_CONTROL2_REG_WRCH3                    `DC_CRGB_ADDR_BASE + 16'h0604
`define DMA_TRANSFER_SIZE_REG_WRCH3                  `DC_CRGB_ADDR_BASE + 16'h0608
`define DMA_SAR_LOW_REG_WRCH3                        `DC_CRGB_ADDR_BASE + 16'h060C
`define DMA_SAR_HIGH_REG_WRCH3                       `DC_CRGB_ADDR_BASE + 16'h0610
`define DMA_DAR_LOW_REG_WRCH3                        `DC_CRGB_ADDR_BASE + 16'h0614
`define DMA_DAR_HIGH_REG_WRCH3                       `DC_CRGB_ADDR_BASE + 16'h0618
`define DMA_LLP_LOW_REG_WRCH3                        `DC_CRGB_ADDR_BASE + 16'h061C
`define DMA_LLP_HIGH_REG_WRCH3                       `DC_CRGB_ADDR_BASE + 16'h0620
`define DMA_CH_CONTROL1_REG_WRCH4                    `DC_CRGB_ADDR_BASE + 16'h0800
`define DMA_CH_CONTROL2_REG_WRCH4                    `DC_CRGB_ADDR_BASE + 16'h0804
`define DMA_TRANSFER_SIZE_REG_WRCH4                  `DC_CRGB_ADDR_BASE + 16'h0808
`define DMA_SAR_LOW_REG_WRCH4                        `DC_CRGB_ADDR_BASE + 16'h080C
`define DMA_SAR_HIGH_REG_WRCH4                       `DC_CRGB_ADDR_BASE + 16'h0810
`define DMA_DAR_LOW_REG_WRCH4                        `DC_CRGB_ADDR_BASE + 16'h0814
`define DMA_DAR_HIGH_REG_WRCH4                       `DC_CRGB_ADDR_BASE + 16'h0818
`define DMA_LLP_LOW_REG_WRCH4                        `DC_CRGB_ADDR_BASE + 16'h081C
`define DMA_LLP_HIGH_REG_WRCH4                       `DC_CRGB_ADDR_BASE + 16'h0820
`define DMA_CH_CONTROL1_REG_WRCH5                    `DC_CRGB_ADDR_BASE + 16'h0A00
`define DMA_CH_CONTROL2_REG_WRCH5                    `DC_CRGB_ADDR_BASE + 16'h0A04
`define DMA_TRANSFER_SIZE_REG_WRCH5                  `DC_CRGB_ADDR_BASE + 16'h0A08
`define DMA_SAR_LOW_REG_WRCH5                        `DC_CRGB_ADDR_BASE + 16'h0A0C
`define DMA_SAR_HIGH_REG_WRCH5                       `DC_CRGB_ADDR_BASE + 16'h0A10
`define DMA_DAR_LOW_REG_WRCH5                        `DC_CRGB_ADDR_BASE + 16'h0A14
`define DMA_DAR_HIGH_REG_WRCH5                       `DC_CRGB_ADDR_BASE + 16'h0A18
`define DMA_LLP_LOW_REG_WRCH5                        `DC_CRGB_ADDR_BASE + 16'h0A1C
`define DMA_LLP_HIGH_REG_WRCH5                       `DC_CRGB_ADDR_BASE + 16'h0A20
`define DMA_CH_CONTROL1_REG_WRCH6                    `DC_CRGB_ADDR_BASE + 16'h0C00
`define DMA_CH_CONTROL2_REG_WRCH6                    `DC_CRGB_ADDR_BASE + 16'h0C04
`define DMA_TRANSFER_SIZE_REG_WRCH6                  `DC_CRGB_ADDR_BASE + 16'h0C08
`define DMA_SAR_LOW_REG_WRCH6                        `DC_CRGB_ADDR_BASE + 16'h0C0C
`define DMA_SAR_HIGH_REG_WRCH6                       `DC_CRGB_ADDR_BASE + 16'h0C10
`define DMA_DAR_LOW_REG_WRCH6                        `DC_CRGB_ADDR_BASE + 16'h0C14
`define DMA_DAR_HIGH_REG_WRCH6                       `DC_CRGB_ADDR_BASE + 16'h0C18
`define DMA_LLP_LOW_REG_WRCH6                        `DC_CRGB_ADDR_BASE + 16'h0C1C
`define DMA_LLP_HIGH_REG_WRCH6                       `DC_CRGB_ADDR_BASE + 16'h0C20
`define DMA_CH_CONTROL1_REG_WRCH7                    `DC_CRGB_ADDR_BASE + 16'h0E00
`define DMA_CH_CONTROL2_REG_WRCH7                    `DC_CRGB_ADDR_BASE + 16'h0E04
`define DMA_TRANSFER_SIZE_REG_WRCH7                  `DC_CRGB_ADDR_BASE + 16'h0E08
`define DMA_SAR_LOW_REG_WRCH7                        `DC_CRGB_ADDR_BASE + 16'h0E0C
`define DMA_SAR_HIGH_REG_WRCH7                       `DC_CRGB_ADDR_BASE + 16'h0E10
`define DMA_DAR_LOW_REG_WRCH7                        `DC_CRGB_ADDR_BASE + 16'h0E14
`define DMA_DAR_HIGH_REG_WRCH7                       `DC_CRGB_ADDR_BASE + 16'h0E18
`define DMA_LLP_LOW_REG_WRCH7                        `DC_CRGB_ADDR_BASE + 16'h0E1C
`define DMA_LLP_HIGH_REG_WRCH7                       `DC_CRGB_ADDR_BASE + 16'h0E20
`define DMA_CH_CONTROL1_REG_WRCH8                    `DC_CRGB_ADDR_BASE + 16'h1000
`define DMA_CH_CONTROL2_REG_WRCH8                    `DC_CRGB_ADDR_BASE + 16'h1004
`define DMA_TRANSFER_SIZE_REG_WRCH8                  `DC_CRGB_ADDR_BASE + 16'h1008
`define DMA_SAR_LOW_REG_WRCH8                        `DC_CRGB_ADDR_BASE + 16'h100C
`define DMA_SAR_HIGH_REG_WRCH8                       `DC_CRGB_ADDR_BASE + 16'h1010
`define DMA_DAR_LOW_REG_WRCH8                        `DC_CRGB_ADDR_BASE + 16'h1014
`define DMA_DAR_HIGH_REG_WRCH8                       `DC_CRGB_ADDR_BASE + 16'h1018
`define DMA_LLP_LOW_REG_WRCH8                        `DC_CRGB_ADDR_BASE + 16'h101C
`define DMA_LLP_HIGH_REG_WRCH8                       `DC_CRGB_ADDR_BASE + 16'h1020
// DMA Channel Read Regiters
`define DMA_TRANSFER_SIZE_REG_RDCH1                  `DC_CRGB_ADDR_BASE + 16'h0308
`define DMA_CH_CONTROL2_REG_RDCH1                    `DC_CRGB_ADDR_BASE + 16'h0304
`define DMA_SAR_LOW_REG_RDCH1                        `DC_CRGB_ADDR_BASE + 16'h030C
`define DMA_CH_CONTROL1_REG_RDCH1                    `DC_CRGB_ADDR_BASE + 16'h0300
`define DMA_SAR_HIGH_REG_RDCH1                       `DC_CRGB_ADDR_BASE + 16'h0310
`define DMA_DAR_LOW_REG_RDCH1                        `DC_CRGB_ADDR_BASE + 16'h0314
`define DMA_DAR_HIGH_REG_RDCH1                       `DC_CRGB_ADDR_BASE + 16'h0318
`define DMA_LLP_LOW_REG_RDCH1                        `DC_CRGB_ADDR_BASE + 16'h031C
`define DMA_LLP_HIGH_REG_RDCH1                       `DC_CRGB_ADDR_BASE + 16'h0320
`define DMA_CH_CONTROL1_REG_RDCH2                    `DC_CRGB_ADDR_BASE + 16'h0500
`define DMA_CH_CONTROL2_REG_RDCH2                    `DC_CRGB_ADDR_BASE + 16'h0504
`define DMA_TRANSFER_SIZE_REG_RDCH2                  `DC_CRGB_ADDR_BASE + 16'h0508
`define DMA_SAR_LOW_REG_RDCH2                        `DC_CRGB_ADDR_BASE + 16'h050C
`define DMA_SAR_HIGH_REG_RDCH2                       `DC_CRGB_ADDR_BASE + 16'h0510
`define DMA_DAR_LOW_REG_RDCH2                        `DC_CRGB_ADDR_BASE + 16'h0514
`define DMA_DAR_HIGH_REG_RDCH2                       `DC_CRGB_ADDR_BASE + 16'h0518
`define DMA_LLP_LOW_REG_RDCH2                        `DC_CRGB_ADDR_BASE + 16'h051C
`define DMA_LLP_HIGH_REG_RDCH2                       `DC_CRGB_ADDR_BASE + 16'h0520
`define DMA_CH_CONTROL1_REG_RDCH3                    `DC_CRGB_ADDR_BASE + 16'h0700
`define DMA_CH_CONTROL2_REG_RDCH3                    `DC_CRGB_ADDR_BASE + 16'h0704
`define DMA_TRANSFER_SIZE_REG_RDCH3                  `DC_CRGB_ADDR_BASE + 16'h0708
`define DMA_SAR_LOW_REG_RDCH3                        `DC_CRGB_ADDR_BASE + 16'h070C
`define DMA_SAR_HIGH_REG_RDCH3                       `DC_CRGB_ADDR_BASE + 16'h0710
`define DMA_DAR_LOW_REG_RDCH3                        `DC_CRGB_ADDR_BASE + 16'h0714
`define DMA_DAR_HIGH_REG_RDCH3                       `DC_CRGB_ADDR_BASE + 16'h0718
`define DMA_LLP_LOW_REG_RDCH3                        `DC_CRGB_ADDR_BASE + 16'h071C
`define DMA_LLP_HIGH_REG_RDCH3                       `DC_CRGB_ADDR_BASE + 16'h0720
`define DMA_CH_CONTROL1_REG_RDCH4                    `DC_CRGB_ADDR_BASE + 16'h0900
`define DMA_CH_CONTROL2_REG_RDCH4                    `DC_CRGB_ADDR_BASE + 16'h0904
`define DMA_TRANSFER_SIZE_REG_RDCH4                  `DC_CRGB_ADDR_BASE + 16'h0908
`define DMA_SAR_LOW_REG_RDCH4                        `DC_CRGB_ADDR_BASE + 16'h090C
`define DMA_SAR_HIGH_REG_RDCH4                       `DC_CRGB_ADDR_BASE + 16'h0910
`define DMA_DAR_LOW_REG_RDCH4                        `DC_CRGB_ADDR_BASE + 16'h0914
`define DMA_DAR_HIGH_REG_RDCH4                       `DC_CRGB_ADDR_BASE + 16'h0918
`define DMA_LLP_LOW_REG_RDCH4                        `DC_CRGB_ADDR_BASE + 16'h091C
`define DMA_LLP_HIGH_REG_RDCH4                       `DC_CRGB_ADDR_BASE + 16'h0920
`define DMA_CH_CONTROL1_REG_RDCH5                    `DC_CRGB_ADDR_BASE + 16'h0B00
`define DMA_CH_CONTROL2_REG_RDCH5                    `DC_CRGB_ADDR_BASE + 16'h0B04
`define DMA_TRANSFER_SIZE_REG_RDCH5                  `DC_CRGB_ADDR_BASE + 16'h0B08
`define DMA_SAR_LOW_REG_RDCH5                        `DC_CRGB_ADDR_BASE + 16'h0B0C
`define DMA_SAR_HIGH_REG_RDCH5                       `DC_CRGB_ADDR_BASE + 16'h0B10
`define DMA_DAR_LOW_REG_RDCH5                        `DC_CRGB_ADDR_BASE + 16'h0B14
`define DMA_DAR_HIGH_REG_RDCH5                       `DC_CRGB_ADDR_BASE + 16'h0B18
`define DMA_LLP_LOW_REG_RDCH5                        `DC_CRGB_ADDR_BASE + 16'h0B1C
`define DMA_LLP_HIGH_REG_RDCH5                       `DC_CRGB_ADDR_BASE + 16'h0B20
`define DMA_CH_CONTROL1_REG_RDCH6                    `DC_CRGB_ADDR_BASE + 16'h0D00
`define DMA_CH_CONTROL2_REG_RDCH6                    `DC_CRGB_ADDR_BASE + 16'h0D04
`define DMA_TRANSFER_SIZE_REG_RDCH6                  `DC_CRGB_ADDR_BASE + 16'h0D08
`define DMA_SAR_LOW_REG_RDCH6                        `DC_CRGB_ADDR_BASE + 16'h0D0C
`define DMA_SAR_HIGH_REG_RDCH6                       `DC_CRGB_ADDR_BASE + 16'h0D10
`define DMA_DAR_LOW_REG_RDCH6                        `DC_CRGB_ADDR_BASE + 16'h0D14
`define DMA_DAR_HIGH_REG_RDCH6                       `DC_CRGB_ADDR_BASE + 16'h0D18
`define DMA_LLP_LOW_REG_RDCH6                        `DC_CRGB_ADDR_BASE + 16'h0D1C
`define DMA_LLP_HIGH_REG_RDCH6                       `DC_CRGB_ADDR_BASE + 16'h0D20
`define DMA_CH_CONTROL1_REG_RDCH7                    `DC_CRGB_ADDR_BASE + 16'h0F00
`define DMA_CH_CONTROL2_REG_RDCH7                    `DC_CRGB_ADDR_BASE + 16'h0F04
`define DMA_TRANSFER_SIZE_REG_RDCH7                  `DC_CRGB_ADDR_BASE + 16'h0F08
`define DMA_SAR_LOW_REG_RDCH7                        `DC_CRGB_ADDR_BASE + 16'h0F0C
`define DMA_SAR_HIGH_REG_RDCH7                       `DC_CRGB_ADDR_BASE + 16'h0F10
`define DMA_DAR_LOW_REG_RDCH7                        `DC_CRGB_ADDR_BASE + 16'h0F14
`define DMA_DAR_HIGH_REG_RDCH7                       `DC_CRGB_ADDR_BASE + 16'h0F18
`define DMA_LLP_LOW_REG_RDCH7                        `DC_CRGB_ADDR_BASE + 16'h0F1C
`define DMA_LLP_HIGH_REG_RDCH7                       `DC_CRGB_ADDR_BASE + 16'h0F20
`define DMA_CH_CONTROL1_REG_RDCH8                    `DC_CRGB_ADDR_BASE + 16'h1100
`define DMA_CH_CONTROL2_REG_RDCH8                    `DC_CRGB_ADDR_BASE + 16'h1104
`define DMA_TRANSFER_SIZE_REG_RDCH8                  `DC_CRGB_ADDR_BASE + 16'h1108
`define DMA_SAR_LOW_REG_RDCH8                        `DC_CRGB_ADDR_BASE + 16'h110C
`define DMA_SAR_HIGH_REG_RDCH8                       `DC_CRGB_ADDR_BASE + 16'h1110
`define DMA_DAR_LOW_REG_RDCH8                        `DC_CRGB_ADDR_BASE + 16'h1114
`define DMA_DAR_HIGH_REG_RDCH8                       `DC_CRGB_ADDR_BASE + 16'h1118
`define DMA_LLP_LOW_REG_RDCH8                        `DC_CRGB_ADDR_BASE + 16'h111C
`define DMA_LLP_HIGH_REG_RDCH8                       `DC_CRGB_ADDR_BASE + 16'h1120


// *****************************************************************************
//** Register Set default values
// *****************************************************************************

`define DC_RST_VAL_XARB_RD_IMSG_XALI       3'd0 // Read engine MSI (MWr), highest priority
`define DC_RST_VAL_XARB_WR_IMSG_XALI       3'd1 // Write engine MSI (MWr)
`define DC_RST_VAL_XARB_AXALI              3'd2 // Bridge MWr/MRd,
`define DC_RST_VAL_XARB_RD_TGEN_XALI       3'd3 // Read engine MRd,
`define DC_RST_VAL_XARB_CPLDMWR_XALI       3'd4 // Write engine MWr, lowest priority

`define DC_RST_VAL_TARB_RD_BUFF_TRGT       3'd3 //Lowest priority
`define DC_RST_VAL_TARB_RD_TGEN_TRGT       3'd2
`define DC_RST_VAL_TARB_WR_TGEN_TRGT       3'd1
`define DC_RST_VAL_TARB_RTRGT              3'd0 //Highest priority

`define DC_RST_VAL_SRAM_ARB_CTX            3'd1 //Highest priority
`define DC_RST_VAL_SRAM_ARB_OUT            3'd2 //Lowest priority

`define DC_RST_VAL_DMA_W_P_DEADLK_TMR_DIS  1'b0
`define MPCIE_DC_RST_VAL_DMA_W_P_DEADLK_TMR_ADJ  12'd7  // 30 usec
`define DC_RST_VAL_DMA_W_P_DEADLK_TMR_ADJ        12'd14 // 30 usec

// *****************************************************************************
//** Register field widths
// *****************************************************************************
`define DC_DMA_W_P_DEADLK_TMR_ADJ_WD 12

// *****************************************************************************
//** Register field position
// *****************************************************************************
`define DC_DMA_W_P_DEADLK_TMR_DIS_MSB 15
`define DC_DMA_W_P_DEADLK_TMR_ADJ_MSB 11
`define DC_DMA_W_P_DEADLK_TMR_ADJ_LSB 0

// *****************************************************************************
//** TLP packet values
// *****************************************************************************
`define DC_PKT_TYPE_CPL             5'b01010
`define DC_PKT_TYPE_CPL_LOCK        5'b01011
`define DC_PKT_FMT_DATA             2'b10
`define DC_PKT_CPL_STATUS_SUCCESS   3'b000
`define DC_LINKED_LIST_PKT_BYTE_CNT 12'd24


// *****************************************************************************
//** DMA requests both in the target and client interface
// *****************************************************************************
// DMA request type width - defined in CC constant file
`define DC_DMA_REQ_BYPASS        3'b000 //Non-eDMA inbound requests
`define DC_DMA_REQ_BYPASS_CPL    3'b010 //Non-EDMA inbound completions
`define DC_DMA_REQ_WRCH_READ     3'b001 //eDMA Write memory read request (DMA to bridge interfaces)
`define DC_DMA_REQ_WRCH_WRITE    3'b001 //eDMA Write memory transaction (DMA to core interfaces)
`define DC_DMA_REQ_RDCH_WRITE    3'b011 //eDMA Read memory write request (DMA to bridge interfaces)
`define DC_DMA_REQ_RDCH_READ     3'b011 //eDMA Read memory read request (DMA to core interfaces)
`define DC_DMA_REQ_WRCH_LLREAD   3'b101 //eDMA Write Linked List Element memory read request
`define DC_DMA_REQ_RDCH_LLREAD   3'b111 //eDMA Read Linked List Element memory read request
`define DC_DMA_REQ_WRCH_INT      3'b100 //eDMA Read channel interrupt
`define DC_DMA_REQ_RDCH_INT      3'b110 //eDMA Write channel interrupt


// *****************************************************************************
//** Completion to Memory Write report status
// *****************************************************************************
`define DC_CPLD_STATUS_IDLE           3'b000 //Idle, no data reveived from Bridge client0
`define DC_CPLD_STATUS_SUCCESS_TNEND  3'b001 //Success transfer Not End, one completion was sent to PCIe core
`define DC_CPLD_STATUS_SUCCESS_TEND   3'b101 //Success Transfer End, all completions received was sent to PCIe core
`define DC_CPLD_STATUS_ERROR          3'b010 //Completion error, completion not converted.
`define DC_CPLD_STATUS_STOP           3'b011 //Doorbell stop, completion not converted.
`define DC_BRIDGE_CPLD_STATUS_ERROR   3'b111 //Completion was sent to the bridge, but an AMBA error was detected

// *****************************************************************************
//** Context Processing to Status Handler Linked List report status
// *****************************************************************************
`define DC_LL_STATUS_IDLE          2'b00 // Idle, linked list is stopped or is processing
`define DC_LL_STATUS_SUCCESS_NEND  2'b01 // Success processing transfer list end
`define DC_LL_STATUS_SUCCESS_END   2'b10 // Success processing transfer list not end
`define DC_LL_STATUS_ERROR         2'b11 // Completion error, when fetched an element an AMBA error was detected

// *****************************************************************************
//** Context Channel Status
// *****************************************************************************
`define DC_CTX_CS_DISABLE  2'b00 // Disable
`define DC_CTX_CS_RUNNING  2'b01 // Running
`define DC_CTX_CS_HALTED   2'b10 // Halted
`define DC_CTX_CS_STOPPED  2'b11 // Stopped

// *****************************************************************************
//** Registers definition of channel controller
// *****************************************************************************
`define DC_CTRL_CH_IN_PROGRESS 1 // Channel in progress: indication if local context (ctrl) is valid or not [3], and channel number [2:0]
`define DC_CTRL_CH_CONTROL_LO  2 // Current channel control 1 register
`define DC_CTRL_CH_CONTROL_HI  3 // Current channel control 2 register
`define DC_CTRL_CH_XFERSIZE    4 // Current channel transfer size
`define DC_CTRL_CH_SAR_PTR     5 // Current channel source address data buffer pointer
`define DC_CTRL_CH_DAR_PTR     6 // Current channel destination address data buffer pointer
`define DC_CTRL_CH_EL_PTR      7 // Current channel sourece element list ponter

// *****************************************************************************
// Channel number definition
// *****************************************************************************
`define DC_CHANNEL_1 0
`define DC_CHANNEL_2 1
`define DC_CHANNEL_3 2
`define DC_CHANNEL_4 3
`define DC_CHANNEL_5 4
`define DC_CHANNEL_6 5
`define DC_CHANNEL_7 6
`define DC_CHANNEL_8 7

// *****************************************************************************
// DMA P Watchdog timer
// *****************************************************************************
`define DC_DMA_P_WDG_TMR_ADJ_VALUE_WD 12

// *****************************************************************************
// DMA Handshake counter width
// *****************************************************************************
`define DMA_HSHAKE_CNT_WD 5

`endif // __GUARD__DWC_PCIE_EDMA_CONSTANTS__SVH__
