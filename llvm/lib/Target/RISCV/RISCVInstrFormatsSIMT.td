//===- RISCVInstrFormatsSIMT.td - Custom SIMT Instruction Formats -*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the instruction formats for the Custom SIMT extension.
// All SIMT custom instructions use opcode 0x0B (CUSTOM_0).
//
// Instruction Format Types:
//   RRTR   - funct7 | rs2     | rs1     | 0x0  | rd      | 0x0B
//   RRPTR  - funct7 | rs2     | rs1     | ps   | rd      | 0x0B
//   RRTP   - funct7 | rs2     | rs1     | 0x0  | pd      | 0x0B
//   PPTP   - funct7 | ps2     | ps1     | 0x0  | pd      | 0x0B
//   PPTR   - funct7 | ps2     | ps1     | 0x0  | rd      | 0x0B
//   RRRP   - funct7 | rs2     | rs1     | ps   | rs3     | 0x0B
//   CTRL   - funct7 | 0x0     | rs1     | 0x0  | 0x0     | 0x0B
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// SIMT Custom Opcode (0x0B = CUSTOM_0)
//===----------------------------------------------------------------------===//

// The SIMT extension uses CUSTOM_0 opcode (0b0001011 = 0x0B)
// This is already defined as OPC_CUSTOM_0 in RISCVInstrFormats.td

//===----------------------------------------------------------------------===//
// SIMT Instruction Format Classes
//===----------------------------------------------------------------------===//

// Base class for all SIMT instructions
class RVInstSIMT<bits<7> funct7, bits<3> funct3, dag outs, dag ins,
                 string opcodestr, string argstr, list<dag> pattern>
    : RVInst<outs, ins, opcodestr, argstr, pattern, InstFormatOther> {
  bits<5> rs2;
  bits<5> rs1;
  bits<5> rd;
  
  let Inst{31-25} = funct7;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = funct3;
  let Inst{11-7} = rd;
  let Inst{6-0} = OPC_CUSTOM_0.Value;
  
}

//===----------------------------------------------------------------------===//
// RRTR Type: GPR×2 → GPR (e.g., SHFL.IDX)
// funct7 | rs2 | rs1 | 0x0 | rd | 0x0B
//===----------------------------------------------------------------------===//

class RVInstSIMT_RRTR<bits<7> funct7, dag outs, dag ins,
                      string opcodestr, string argstr, list<dag> pattern>
    : RVInstSIMT<funct7, 0b000, outs, ins, opcodestr, argstr, pattern>;

//===----------------------------------------------------------------------===//
// RRPTR Type: GPR×2 + pred → GPR (e.g., PSEL, PLW)
// funct7 | rs2 | rs1 | ps | rd | 0x0B
//===----------------------------------------------------------------------===//

class RVInstSIMT_RRPTR<bits<7> funct7, dag outs, dag ins,
                       string opcodestr, string argstr, list<dag> pattern>
    : RVInst<outs, ins, opcodestr, argstr, pattern, InstFormatOther> {
  bits<5> rs2;
  bits<5> rs1;
  bits<3> ps;  // Predicate source register (p0-p7)
  bits<5> rd;
  
  let Inst{31-25} = funct7;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = ps;
  let Inst{11-7} = rd;
  let Inst{6-0} = OPC_CUSTOM_0.Value;
  
}

//===----------------------------------------------------------------------===//
// RRTP Type: GPR×2 → pred (e.g., PCMP.*)
// funct7 | rs2 | rs1 | 0x0 | pd | 0x0B
//===----------------------------------------------------------------------===//

class RVInstSIMT_RRTP<bits<7> funct7, dag outs, dag ins,
                      string opcodestr, string argstr, list<dag> pattern>
    : RVInst<outs, ins, opcodestr, argstr, pattern, InstFormatOther> {
  bits<5> rs2;
  bits<5> rs1;
  bits<3> pd;  // Predicate destination register (p0-p7)
  
  let Inst{31-25} = funct7;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = 0b000;
  let Inst{11-9} = 0b000;
  let Inst{8-7} = pd{2-1};  // pd encoded in bits [8:7] and [11] 
  // Note: pd is 3 bits, need special encoding
  // For simplicity, encode pd in rd field (bits 11-7), using only bits 9-7
  let Inst{11-7} = {0b00, pd};
  let Inst{6-0} = OPC_CUSTOM_0.Value;
  
}

// Alternative RRTP that uses full rd position for pd
class RVInstSIMT_RRTP_v2<bits<7> funct7, dag outs, dag ins,
                         string opcodestr, string argstr, list<dag> pattern>
    : RVInst<outs, ins, opcodestr, argstr, pattern, InstFormatOther> {
  bits<5> rs2;
  bits<5> rs1;
  bits<5> pd;  // Use 5 bits but only 3 are meaningful (p0-p7)
  
  let Inst{31-25} = funct7;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = 0b000;
  let Inst{11-7} = pd;
  let Inst{6-0} = OPC_CUSTOM_0.Value;
  
}

//===----------------------------------------------------------------------===//
// PPTP Type: pred×2 → pred (e.g., PAND, POR, PXOR)
// funct7 | ps2 | ps1 | 0x0 | pd | 0x0B
//===----------------------------------------------------------------------===//

class RVInstSIMT_PPTP<bits<7> funct7, dag outs, dag ins,
                      string opcodestr, string argstr, list<dag> pattern>
    : RVInst<outs, ins, opcodestr, argstr, pattern, InstFormatOther> {
  bits<5> ps2;  // 5 bits field, but only 3 bits used for p0-p7
  bits<5> ps1;
  bits<5> pd;
  
  let Inst{31-25} = funct7;
  let Inst{24-20} = ps2;
  let Inst{19-15} = ps1;
  let Inst{14-12} = 0b000;
  let Inst{11-7} = pd;
  let Inst{6-0} = OPC_CUSTOM_0.Value;
  
}

//===----------------------------------------------------------------------===//
// PPTR Type: pred×2 → GPR (e.g., PMOV.TO.X)
// funct7 | ps2 | ps1 | 0x0 | rd | 0x0B
//===----------------------------------------------------------------------===//

class RVInstSIMT_PPTR<bits<7> funct7, dag outs, dag ins,
                      string opcodestr, string argstr, list<dag> pattern>
    : RVInst<outs, ins, opcodestr, argstr, pattern, InstFormatOther> {
  bits<5> ps2;
  bits<5> ps1;
  bits<5> rd;
  
  let Inst{31-25} = funct7;
  let Inst{24-20} = ps2;
  let Inst{19-15} = ps1;
  let Inst{14-12} = 0b000;
  let Inst{11-7} = rd;
  let Inst{6-0} = OPC_CUSTOM_0.Value;
  
}

//===----------------------------------------------------------------------===//
// RRRP Type: GPR×2 + pred → store (e.g., PSW)
// funct7 | rs2 | rs1 | ps | rs3 | 0x0B
//===----------------------------------------------------------------------===//

class RVInstSIMT_RRRP<bits<7> funct7, dag outs, dag ins,
                      string opcodestr, string argstr, list<dag> pattern>
    : RVInst<outs, ins, opcodestr, argstr, pattern, InstFormatOther> {
  bits<5> rs2;  // offset
  bits<5> rs1;  // base address
  bits<3> ps;   // predicate source
  bits<5> rs3;  // store data
  
  let Inst{31-25} = funct7;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = ps;
  let Inst{11-7} = rs3;
  let Inst{6-0} = OPC_CUSTOM_0.Value;
  
}

//===----------------------------------------------------------------------===//
// CTRL Type: Control instructions (e.g., LMASK.PUSH, BAR.SYNC)
// funct7 | 0x0 | rs1 | 0x0 | 0x0 | 0x0B
//===----------------------------------------------------------------------===//

class RVInstSIMT_CTRL<bits<7> funct7, dag outs, dag ins,
                      string opcodestr, string argstr, list<dag> pattern>
    : RVInst<outs, ins, opcodestr, argstr, pattern, InstFormatOther> {
  bits<5> rs1;  // For LMASK.PUSH: reconv_pc; For BAR.SYNC: 0
  
  let Inst{31-25} = funct7;
  let Inst{24-20} = 0b00000;
  let Inst{19-15} = rs1;
  let Inst{14-12} = 0b000;
  let Inst{11-7} = 0b00000;
  let Inst{6-0} = OPC_CUSTOM_0.Value;
  
}

//===----------------------------------------------------------------------===//
// funct7 Values for SIMT Instructions
// Names must be <= 10 characters for RISCVOpcodesList table
//===----------------------------------------------------------------------===//

// Lane Mask Control
def SIMT_FUNCT7_LMASK_PUSH : RISCVOpcode<"LMSK_PUSH", 0b0100000>;  // 0x20

// Shuffle Instructions
def SIMT_FUNCT7_SHFL_BFLY  : RISCVOpcode<"SHFL_BFLY", 0b0110000>;  // 0x30
def SIMT_FUNCT7_SHFL_IDX   : RISCVOpcode<"SHFL_IDX",  0b0110001>;  // 0x31
def SIMT_FUNCT7_SHFL_WIDTH : RISCVOpcode<"SHFL_WID",  0b0110010>;  // 0x32

// Synchronization
def SIMT_FUNCT7_BAR_SYNC   : RISCVOpcode<"BAR_SYNC",  0b1000000>;  // 0x40

// Predicate Compare (Integer)
def SIMT_FUNCT7_PCMP_EQ    : RISCVOpcode<"PCMP_EQ",   0b1010000>;  // 0x50
def SIMT_FUNCT7_PCMP_NE    : RISCVOpcode<"PCMP_NE",   0b1010001>;  // 0x51
def SIMT_FUNCT7_PCMP_LT    : RISCVOpcode<"PCMP_LT",   0b1010010>;  // 0x52
def SIMT_FUNCT7_PCMP_LTU   : RISCVOpcode<"PCMP_LTU",  0b1010011>;  // 0x53
def SIMT_FUNCT7_PCMP_LE    : RISCVOpcode<"PCMP_LE",   0b1010100>;  // 0x54

// Predicate Compare (Floating-point)
def SIMT_FUNCT7_PCMP_F_EQ  : RISCVOpcode<"PCMP_FEQ",  0b1010101>;  // 0x55
def SIMT_FUNCT7_PCMP_F_LT  : RISCVOpcode<"PCMP_FLT",  0b1010110>;  // 0x56
def SIMT_FUNCT7_PCMP_F_LE  : RISCVOpcode<"PCMP_FLE",  0b1010111>;  // 0x57

// Predicate Select
def SIMT_FUNCT7_PSEL       : RISCVOpcode<"PSEL",      0b1011000>;  // 0x58
def SIMT_FUNCT7_PSEL_F     : RISCVOpcode<"PSEL_F",    0b1011001>;  // 0x59

// Predicate Logic
def SIMT_FUNCT7_PAND       : RISCVOpcode<"PAND",      0b1011010>;  // 0x5A
def SIMT_FUNCT7_POR        : RISCVOpcode<"POR",       0b1011011>;  // 0x5B
def SIMT_FUNCT7_PXOR       : RISCVOpcode<"PXOR",      0b1011100>;  // 0x5C
def SIMT_FUNCT7_PNOT       : RISCVOpcode<"PNOT",      0b1011101>;  // 0x5D

// Predicate Transfer
def SIMT_FUNCT7_PMOV       : RISCVOpcode<"PMOV",      0b1011110>;  // 0x5E
def SIMT_FUNCT7_PMOV_TO_X  : RISCVOpcode<"PMOV_TO_X", 0b1011111>;  // 0x5F
def SIMT_FUNCT7_PMOV_FROM_X: RISCVOpcode<"PMOV_FR_X", 0b1100000>;  // 0x60

// Predicated Load
def SIMT_FUNCT7_PLB        : RISCVOpcode<"PLB",       0b1100001>;  // 0x61
def SIMT_FUNCT7_PLBU       : RISCVOpcode<"PLBU",      0b1100010>;  // 0x62
def SIMT_FUNCT7_PLH        : RISCVOpcode<"PLH",       0b1100011>;  // 0x63
def SIMT_FUNCT7_PLHU       : RISCVOpcode<"PLHU",      0b1100100>;  // 0x64
def SIMT_FUNCT7_PLW        : RISCVOpcode<"PLW",       0b1100101>;  // 0x65
def SIMT_FUNCT7_PFLW       : RISCVOpcode<"PFLW",      0b1100110>;  // 0x66

// Predicated Store
def SIMT_FUNCT7_PSB        : RISCVOpcode<"PSB",       0b1100111>;  // 0x67
def SIMT_FUNCT7_PSH        : RISCVOpcode<"PSH",       0b1101000>;  // 0x68
def SIMT_FUNCT7_PSW        : RISCVOpcode<"PSW",       0b1101001>;  // 0x69
def SIMT_FUNCT7_PFSW       : RISCVOpcode<"PFSW",      0b1101010>;  // 0x6A
