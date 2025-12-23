//===- RISCVInstrInfoSIMT.td - Custom SIMT Instructions ---*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the instructions for the Custom SIMT extension.
// All instructions use opcode 0x0B (CUSTOM_0).
//
// The feature is defined in RISCVFeatures.td as FeatureVendorXCustomSIMT.
// Use HasVendorXCustomSIMT as the predicate for all SIMT instructions.
//
//===----------------------------------------------------------------------===//

include "RISCVInstrFormatsSIMT.td"
include "RISCVSystemOperandsSIMT.td"

//===----------------------------------------------------------------------===//
// Predicate Register Class
//===----------------------------------------------------------------------===//

// Define a specialized 3-bit encoding predicate register type
// Separate from GPR to allow independent register allocation for i1 values
class SIMTPredReg<bits<3> Enc, string n> : Register<n> {
  let Namespace = "RISCV";
  let HWEncoding{2-0} = Enc;
}

// Predicate registers p0-p7 (8 registers, 1-bit per lane, warp-wide 32-bit view)
let Namespace = "RISCV" in {
  def P0 : SIMTPredReg<0, "p0">;
  def P1 : SIMTPredReg<1, "p1">;
  def P2 : SIMTPredReg<2, "p2">;
  def P3 : SIMTPredReg<3, "p3">;
  def P4 : SIMTPredReg<4, "p4">;
  def P5 : SIMTPredReg<5, "p5">;
  def P6 : SIMTPredReg<6, "p6">;
  def P7 : SIMTPredReg<7, "p7">;
}

// Predicate Register Class - uses i1 type for proper register allocation
// Reference: NVPTX B1 and AArch64 PPR design
// Note: Although each lane is 1-bit, warp-wide view is 32-bit for spill/reload
def PR : RegisterClass<"RISCV", [i1], 8,
    (add P0, P1, P2, P3, P4, P5, P6, P7)> {
  let Size = 32;          // Warp-wide view is 32-bit for spill
  let CopyCost = 2;       // PR copy requires 2 instructions (via GPR)
  let isAllocatable = 1;  // Enable independent allocation
}

// Predicate register operand (3-bit encoding, p0-p7)
def PROperand : RegisterOperand<PR>;

//===----------------------------------------------------------------------===//
// SIMT Instructions - All instructions are in the SIMT predicate block
//===----------------------------------------------------------------------===//

let Predicates = [HasVendorXCustomSIMT] in {

//===----------------------------------------------------------------------===//
// Shuffle Instructions - no side effects, no memory access
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {

// SHFL.IDX - Index shuffle: rd <- lane[rs2].rs1  (funct7=0b0110001)
def SIMT_SHFL_IDX : RVInstSIMT_RRTR<0b0110001, 
    (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
    "shfl.idx", "$rd, $rs1, $rs2", []>;

// SHFL.BFLY - Butterfly shuffle (funct7=0b0110000)
def SIMT_SHFL_BFLY : RVInstSIMT_RRTR<0b0110000,
    (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2),
    "shfl.bfly", "$rd, $rs1, $rs2", []>;

// Float versions - use different funct7 to distinguish from integer versions
// SHFL.IDX.F (funct7=0b0110011)
def SIMT_SHFL_IDX_F : RVInstSIMT_RRTR<0b0110011,
    (outs FPR32:$rd), (ins FPR32:$rs1, GPR:$rs2),
    "shfl.idx.f", "$rd, $rs1, $rs2", []>;

} // hasSideEffects = 0, mayLoad = 0, mayStore = 0

//===----------------------------------------------------------------------===//
// Synchronization Instructions  
//===----------------------------------------------------------------------===//

let hasSideEffects = 1, mayLoad = 0, mayStore = 0 in {

// BAR.SYNC - CTA-level barrier (rs1=0)
def SIMT_BAR_SYNC : RVInstSIMT_CTRL<0b1000000,
    (outs), (ins),
    "bar.sync", "", []> {
  let rs1 = 0;
  let isBarrier = 1;
}

// LMASK.PUSH - Push reconvergence PC to lane stack
def SIMT_LMASK_PUSH : RVInstSIMT_CTRL<0b0100000,
    (outs), (ins GPR:$rs1),
    "lmask.push", "$rs1", []>;

} // hasSideEffects = 1, mayLoad = 0, mayStore = 0

//===----------------------------------------------------------------------===//
// Predicate Compare Instructions - no side effects, no memory access
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {

// Integer compares
def SIMT_PCMP_EQ : RVInstSIMT_RRTP_v2<0b1010000,
    (outs PR:$pd), (ins GPR:$rs1, GPR:$rs2),
    "pcmp.eq", "$pd, $rs1, $rs2", []>;

def SIMT_PCMP_NE : RVInstSIMT_RRTP_v2<0b1010001,
    (outs PR:$pd), (ins GPR:$rs1, GPR:$rs2),
    "pcmp.ne", "$pd, $rs1, $rs2", []>;

def SIMT_PCMP_LT : RVInstSIMT_RRTP_v2<0b1010010,
    (outs PR:$pd), (ins GPR:$rs1, GPR:$rs2),
    "pcmp.lt", "$pd, $rs1, $rs2", []>;

def SIMT_PCMP_LTU : RVInstSIMT_RRTP_v2<0b1010011,
    (outs PR:$pd), (ins GPR:$rs1, GPR:$rs2),
    "pcmp.ltu", "$pd, $rs1, $rs2", []>;

def SIMT_PCMP_LE : RVInstSIMT_RRTP_v2<0b1010100,
    (outs PR:$pd), (ins GPR:$rs1, GPR:$rs2),
    "pcmp.le", "$pd, $rs1, $rs2", []>;

// Floating-point compares
def SIMT_PCMP_F_EQ : RVInstSIMT_RRTP_v2<0b1010101,
    (outs PR:$pd), (ins FPR32:$rs1, FPR32:$rs2),
    "pcmp.f.eq", "$pd, $rs1, $rs2", []>;

def SIMT_PCMP_F_LT : RVInstSIMT_RRTP_v2<0b1010110,
    (outs PR:$pd), (ins FPR32:$rs1, FPR32:$rs2),
    "pcmp.f.lt", "$pd, $rs1, $rs2", []>;

def SIMT_PCMP_F_LE : RVInstSIMT_RRTP_v2<0b1010111,
    (outs PR:$pd), (ins FPR32:$rs1, FPR32:$rs2),
    "pcmp.f.le", "$pd, $rs1, $rs2", []>;

} // hasSideEffects = 0, mayLoad = 0, mayStore = 0

//===----------------------------------------------------------------------===//
// Predicate Select Instructions - no side effects, no memory access
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {

def SIMT_PSEL : RVInstSIMT_RRPTR<0b1011000,
    (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2, PR:$ps),
    "psel", "$rd, $rs1, $rs2, $ps", []>;

def SIMT_PSEL_F : RVInstSIMT_RRPTR<0b1011001,
    (outs FPR32:$rd), (ins FPR32:$rs1, FPR32:$rs2, PR:$ps),
    "psel.f", "$rd, $rs1, $rs2, $ps", []>;

} // hasSideEffects = 0, mayLoad = 0, mayStore = 0

//===----------------------------------------------------------------------===//
// Predicate Logic Instructions - no side effects, no memory access
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {

def SIMT_PAND : RVInstSIMT_PPTP<0b1011010,
    (outs PR:$pd), (ins PR:$ps1, PR:$ps2),
    "pand", "$pd, $ps1, $ps2", []>;

def SIMT_POR : RVInstSIMT_PPTP<0b1011011,
    (outs PR:$pd), (ins PR:$ps1, PR:$ps2),
    "por", "$pd, $ps1, $ps2", []>;

def SIMT_PXOR : RVInstSIMT_PPTP<0b1011100,
    (outs PR:$pd), (ins PR:$ps1, PR:$ps2),
    "pxor", "$pd, $ps1, $ps2", []>;

def SIMT_PNOT : RVInstSIMT_PPTP<0b1011101,
    (outs PR:$pd), (ins PR:$ps1),
    "pnot", "$pd, $ps1", []> {
  let ps2 = 0;
}

def SIMT_PMOV : RVInstSIMT_PPTP<0b1011110,
    (outs PR:$pd), (ins PR:$ps1),
    "pmov", "$pd, $ps1", []> {
  let ps2 = 0;
}

def SIMT_PMOV_TO_X : RVInstSIMT_PPTR<0b1011111,
    (outs GPR:$rd), (ins PR:$ps1),
    "pmov.to.x", "$rd, $ps1", []> {
  let ps2 = 0;
}

def SIMT_PMOV_FROM_X : RVInstSIMT_RRTP_v2<0b1100000,
    (outs PR:$pd), (ins GPR:$rs1),
    "pmov.from.x", "$pd, $rs1", []> {
  let rs2 = 0;
}

} // hasSideEffects = 0, mayLoad = 0, mayStore = 0

//===----------------------------------------------------------------------===//
// Predicated Load Instructions - mayLoad = 1
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 1, mayStore = 0 in {

def SIMT_PLB : RVInstSIMT_RRPTR<0b1100001,
    (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2, PR:$ps),
    "plb", "$rd, $rs1, $rs2, $ps", []>;

def SIMT_PLBU : RVInstSIMT_RRPTR<0b1100010,
    (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2, PR:$ps),
    "plbu", "$rd, $rs1, $rs2, $ps", []>;

def SIMT_PLH : RVInstSIMT_RRPTR<0b1100011,
    (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2, PR:$ps),
    "plh", "$rd, $rs1, $rs2, $ps", []>;

def SIMT_PLHU : RVInstSIMT_RRPTR<0b1100100,
    (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2, PR:$ps),
    "plhu", "$rd, $rs1, $rs2, $ps", []>;

def SIMT_PLW : RVInstSIMT_RRPTR<0b1100101,
    (outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2, PR:$ps),
    "plw", "$rd, $rs1, $rs2, $ps", []>;

def SIMT_PFLW : RVInstSIMT_RRPTR<0b1100110,
    (outs FPR32:$rd), (ins GPR:$rs1, GPR:$rs2, PR:$ps),
    "pflw", "$rd, $rs1, $rs2, $ps", []>;

} // hasSideEffects = 0, mayLoad = 1, mayStore = 0

//===----------------------------------------------------------------------===//
// Predicated Store Instructions - mayStore = 1
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in {

def SIMT_PSB : RVInstSIMT_RRRP<0b1100111,
    (outs), (ins GPR:$rs3, GPR:$rs1, GPR:$rs2, PR:$ps),
    "psb", "$rs3, $rs1, $rs2, $ps", []>;

def SIMT_PSH : RVInstSIMT_RRRP<0b1101000,
    (outs), (ins GPR:$rs3, GPR:$rs1, GPR:$rs2, PR:$ps),
    "psh", "$rs3, $rs1, $rs2, $ps", []>;

def SIMT_PSW : RVInstSIMT_RRRP<0b1101001,
    (outs), (ins GPR:$rs3, GPR:$rs1, GPR:$rs2, PR:$ps),
    "psw", "$rs3, $rs1, $rs2, $ps", []>;

def SIMT_PFSW : RVInstSIMT_RRRP<0b1101010,
    (outs), (ins FPR32:$rs3, GPR:$rs1, GPR:$rs2, PR:$ps),
    "pfsw", "$rs3, $rs1, $rs2, $ps", []>;

} // hasSideEffects = 0, mayLoad = 0, mayStore = 1

} // Predicates = [HasVendorXCustomSIMT]

//===----------------------------------------------------------------------===//
// Pseudo Instructions for Intrinsic Lowering
//===----------------------------------------------------------------------===//

let Predicates = [HasVendorXCustomSIMT] in {
let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {

// Pseudo for reading SIMT CSRs (will be expanded to csrr)
def PseudoReadSIMT_TID_X     : Pseudo<(outs GPR:$rd), (ins), []>;
def PseudoReadSIMT_TID_Y     : Pseudo<(outs GPR:$rd), (ins), []>;
def PseudoReadSIMT_TID_Z     : Pseudo<(outs GPR:$rd), (ins), []>;
def PseudoReadSIMT_NTID_X    : Pseudo<(outs GPR:$rd), (ins), []>;
def PseudoReadSIMT_NTID_Y    : Pseudo<(outs GPR:$rd), (ins), []>;
def PseudoReadSIMT_NTID_Z    : Pseudo<(outs GPR:$rd), (ins), []>;
def PseudoReadSIMT_CTAID_X   : Pseudo<(outs GPR:$rd), (ins), []>;
def PseudoReadSIMT_CTAID_Y   : Pseudo<(outs GPR:$rd), (ins), []>;
def PseudoReadSIMT_CTAID_Z   : Pseudo<(outs GPR:$rd), (ins), []>;
def PseudoReadSIMT_LANEID    : Pseudo<(outs GPR:$rd), (ins), []>;
def PseudoReadSIMT_WARPSIZE  : Pseudo<(outs GPR:$rd), (ins), []>;
def PseudoReadSIMT_LMASK_ACT : Pseudo<(outs GPR:$rd), (ins), []>;

} // hasSideEffects = 0, mayLoad = 0, mayStore = 0

let hasSideEffects = 1, mayLoad = 1, mayStore = 1 in {

// Pseudo for barrier (fence + bar.sync)
def PseudoSIMT_BARRIER : Pseudo<(outs), (ins), []> {
  let isBarrier = 1;
}

// Pseudo for LMASK.PUSH with label target
def PseudoSIMT_LMASK_PUSH_LABEL : Pseudo<(outs), (ins GPR:$target), []>;

} // hasSideEffects = 1, mayLoad = 1, mayStore = 1

//===----------------------------------------------------------------------===//
// Pseudo Instructions for Predicate Operations
// These use GPR to hold i1 values (0 or 1) since RISC-V expands i1 to XLenVT
// The actual SIMT instructions using PR registers require custom lowering
//===----------------------------------------------------------------------===//

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in {

// Pseudo for predicate compare - output to GPR (0 or 1)
// Will be expanded to: PCMP.* pd, rs1, rs2 ; PMOV.TO.X rd, pd
def PseudoSIMT_PCMP_EQ  : Pseudo<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), []>;
def PseudoSIMT_PCMP_NE  : Pseudo<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), []>;
def PseudoSIMT_PCMP_LT  : Pseudo<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), []>;
def PseudoSIMT_PCMP_LTU : Pseudo<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), []>;
def PseudoSIMT_PCMP_LE  : Pseudo<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), []>;

// Floating-point predicate compare
def PseudoSIMT_PCMP_F_EQ : Pseudo<(outs GPR:$rd), (ins FPR32:$rs1, FPR32:$rs2), []>;
def PseudoSIMT_PCMP_F_LT : Pseudo<(outs GPR:$rd), (ins FPR32:$rs1, FPR32:$rs2), []>;
def PseudoSIMT_PCMP_F_LE : Pseudo<(outs GPR:$rd), (ins FPR32:$rs1, FPR32:$rs2), []>;

// Pseudo for predicate select
// cond is in GPR (0 or 1), will be: PMOV.FROM.X pd, cond ; PSEL rd, rs1, rs2, pd
def PseudoSIMT_PSEL   : Pseudo<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2, GPR:$cond), []>;
def PseudoSIMT_PSEL_F : Pseudo<(outs FPR32:$rd), (ins FPR32:$rs1, FPR32:$rs2, GPR:$cond), []>;

// Pseudo for predicate logic operations
def PseudoSIMT_PAND : Pseudo<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), []>;
def PseudoSIMT_POR  : Pseudo<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), []>;
def PseudoSIMT_PXOR : Pseudo<(outs GPR:$rd), (ins GPR:$rs1, GPR:$rs2), []>;
def PseudoSIMT_PNOT : Pseudo<(outs GPR:$rd), (ins GPR:$rs1), []>;

// Pseudo for predicate transfer (identity, for explicit control)
def PseudoSIMT_PMOV_TO_X   : Pseudo<(outs GPR:$rd), (ins GPR:$rs1), []>;
def PseudoSIMT_PMOV_FROM_X : Pseudo<(outs GPR:$rd), (ins GPR:$rs1), []>;

} // hasSideEffects = 0, mayLoad = 0, mayStore = 0

// Predicated memory access pseudos
let hasSideEffects = 0, mayLoad = 1, mayStore = 0 in {
def PseudoSIMT_PLW  : Pseudo<(outs GPR:$rd), (ins GPR:$base, GPR:$offset, GPR:$pred), []>;
def PseudoSIMT_PFLW : Pseudo<(outs FPR32:$rd), (ins GPR:$base, GPR:$offset, GPR:$pred), []>;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in {
def PseudoSIMT_PSW  : Pseudo<(outs), (ins GPR:$val, GPR:$base, GPR:$offset, GPR:$pred), []>;
def PseudoSIMT_PFSW : Pseudo<(outs), (ins FPR32:$val, GPR:$base, GPR:$offset, GPR:$pred), []>;
}

//===----------------------------------------------------------------------===//
// Predicate Register Spill/Reload Pseudos
// Note: SIMT_PMOV, SIMT_PMOV_TO_X, SIMT_PMOV_FROM_X are real machine 
// instructions defined above. These pseudos are only for stack spill/reload.
//===----------------------------------------------------------------------===//

// PR spill/reload pseudos
// Spill: PR -> Stack (expands to PMOV.TO.X + SW)
let hasSideEffects = 0, mayLoad = 0, mayStore = 1 in {
def PseudoPRSpill : Pseudo<(outs), (ins PR:$src, GPR:$base, i32imm:$offset), []>;
}

// Reload: Stack -> PR (expands to LW + PMOV.FROM.X)
let hasSideEffects = 0, mayLoad = 1, mayStore = 0 in {
def PseudoPRReload : Pseudo<(outs PR:$dst), (ins GPR:$base, i32imm:$offset), []>;
}

} // Predicates = [HasVendorXCustomSIMT]

//===----------------------------------------------------------------------===//
// Instruction Selection Patterns
// The intrinsics are defined in llvm/IR/IntrinsicsCustomSIMT.td with
// TargetPrefix = "custom", included via Intrinsics.td
//===----------------------------------------------------------------------===//

let Predicates = [HasVendorXCustomSIMT] in {

// Thread ID intrinsics
def : Pat<(int_riscv_simt_tid_x), (PseudoReadSIMT_TID_X)>;
def : Pat<(int_riscv_simt_tid_y), (PseudoReadSIMT_TID_Y)>;
def : Pat<(int_riscv_simt_tid_z), (PseudoReadSIMT_TID_Z)>;

// Block dimension intrinsics
def : Pat<(int_riscv_simt_ntid_x), (PseudoReadSIMT_NTID_X)>;
def : Pat<(int_riscv_simt_ntid_y), (PseudoReadSIMT_NTID_Y)>;
def : Pat<(int_riscv_simt_ntid_z), (PseudoReadSIMT_NTID_Z)>;

// Block ID intrinsics
def : Pat<(int_riscv_simt_ctaid_x), (PseudoReadSIMT_CTAID_X)>;
def : Pat<(int_riscv_simt_ctaid_y), (PseudoReadSIMT_CTAID_Y)>;
def : Pat<(int_riscv_simt_ctaid_z), (PseudoReadSIMT_CTAID_Z)>;

// Lane and warp info
def : Pat<(int_riscv_simt_lane_id), (PseudoReadSIMT_LANEID)>;
def : Pat<(int_riscv_simt_warp_size), (PseudoReadSIMT_WARPSIZE)>;
def : Pat<(int_riscv_simt_activemask), (PseudoReadSIMT_LMASK_ACT)>;

// Barrier
def : Pat<(int_riscv_simt_barrier), (PseudoSIMT_BARRIER)>;

// Shuffle intrinsics
def : Pat<(int_riscv_simt_shuffle_idx_i32 GPR:$val, GPR:$lane),
          (SIMT_SHFL_IDX GPR:$val, GPR:$lane)>;

def : Pat<(int_riscv_simt_shuffle_idx_f32 FPR32:$val, GPR:$lane),
          (SIMT_SHFL_IDX_F FPR32:$val, GPR:$lane)>;

//===----------------------------------------------------------------------===//
// SIMT Predicate Instruction Selection Patterns
//
// Strategy:
// 1. PCMP.* instructions output to PR registers (warp-wide 32-bit mask)
// 2. PSEL uses PR as condition to select between two values
// 3. We define pseudo instructions that use GPR for i1 conditions,
//    then expand them to actual PCMP/PSEL sequences
//
// For now, we focus on intrinsic-based lowering rather than automatic
// pattern matching of setcc/select, because:
// - The PR register class uses i32 type (warp-wide view)
// - RISC-V setcc produces XLenVT (i32), not i1
// - Mixing these requires careful type handling
//
// Future work: Add custom ISelLowering to automatically lower
// select(icmp, a, b) -> PCMP + PSEL sequences
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Shuffle XOR/UP/DOWN lowering
// These need to compute the source lane from lane_id first
//===----------------------------------------------------------------------===//

// shuffle_xor: src_lane = lane_id ^ mask
def : Pat<(int_riscv_simt_shuffle_xor_i32 GPR:$val, GPR:$mask),
          (SIMT_SHFL_IDX GPR:$val, 
            (XOR (PseudoReadSIMT_LANEID), GPR:$mask))>;

// shuffle_up: src_lane = lane_id - delta  
def : Pat<(int_riscv_simt_shuffle_up_i32 GPR:$val, GPR:$delta),
          (SIMT_SHFL_IDX GPR:$val,
            (SUB (PseudoReadSIMT_LANEID), GPR:$delta))>;

// shuffle_down: src_lane = lane_id + delta
def : Pat<(int_riscv_simt_shuffle_down_i32 GPR:$val, GPR:$delta),
          (SIMT_SHFL_IDX GPR:$val,
            (ADD (PseudoReadSIMT_LANEID), GPR:$delta))>;

// Float versions
def : Pat<(int_riscv_simt_shuffle_xor_f32 FPR32:$val, GPR:$mask),
          (SIMT_SHFL_IDX_F FPR32:$val,
            (XOR (PseudoReadSIMT_LANEID), GPR:$mask))>;

def : Pat<(int_riscv_simt_shuffle_up_f32 FPR32:$val, GPR:$delta),
          (SIMT_SHFL_IDX_F FPR32:$val,
            (SUB (PseudoReadSIMT_LANEID), GPR:$delta))>;

def : Pat<(int_riscv_simt_shuffle_down_f32 FPR32:$val, GPR:$delta),
          (SIMT_SHFL_IDX_F FPR32:$val,
            (ADD (PseudoReadSIMT_LANEID), GPR:$delta))>;

//===----------------------------------------------------------------------===//
// Predicate Intrinsics Patterns
// Note: i1 types are expanded to XLenVT (i32) by RISC-V, so intrinsics
// returning i1 will have their results in GPR (0 or 1)
//===----------------------------------------------------------------------===//

// Predicate compare intrinsics -> Pseudo instructions
def : Pat<(i32 (zext (int_riscv_simt_pcmp_eq GPR:$a, GPR:$b))),
          (PseudoSIMT_PCMP_EQ GPR:$a, GPR:$b)>;
def : Pat<(i32 (zext (int_riscv_simt_pcmp_ne GPR:$a, GPR:$b))),
          (PseudoSIMT_PCMP_NE GPR:$a, GPR:$b)>;
def : Pat<(i32 (zext (int_riscv_simt_pcmp_lt GPR:$a, GPR:$b))),
          (PseudoSIMT_PCMP_LT GPR:$a, GPR:$b)>;
def : Pat<(i32 (zext (int_riscv_simt_pcmp_ltu GPR:$a, GPR:$b))),
          (PseudoSIMT_PCMP_LTU GPR:$a, GPR:$b)>;
def : Pat<(i32 (zext (int_riscv_simt_pcmp_le GPR:$a, GPR:$b))),
          (PseudoSIMT_PCMP_LE GPR:$a, GPR:$b)>;

// Float predicate compare
def : Pat<(i32 (zext (int_riscv_simt_pcmp_f_eq FPR32:$a, FPR32:$b))),
          (PseudoSIMT_PCMP_F_EQ FPR32:$a, FPR32:$b)>;
def : Pat<(i32 (zext (int_riscv_simt_pcmp_f_lt FPR32:$a, FPR32:$b))),
          (PseudoSIMT_PCMP_F_LT FPR32:$a, FPR32:$b)>;
def : Pat<(i32 (zext (int_riscv_simt_pcmp_f_le FPR32:$a, FPR32:$b))),
          (PseudoSIMT_PCMP_F_LE FPR32:$a, FPR32:$b)>;

// Predicate select intrinsics
// psel(true_val, false_val, cond) where cond is i1
// The i1 condition now maps to PR register class
def : Pat<(int_riscv_simt_psel_i32 GPR:$t, GPR:$f, PR:$c),
          (SIMT_PSEL GPR:$t, GPR:$f, PR:$c)>;
def : Pat<(int_riscv_simt_psel_f32 FPR32:$t, FPR32:$f, PR:$c),
          (SIMT_PSEL_F FPR32:$t, FPR32:$f, PR:$c)>;

// Predicate logic intrinsics - i1 values use PR register class
def : Pat<(int_riscv_simt_pand PR:$a, PR:$b),
          (SIMT_PAND PR:$a, PR:$b)>;
def : Pat<(int_riscv_simt_por PR:$a, PR:$b),
          (SIMT_POR PR:$a, PR:$b)>;
def : Pat<(int_riscv_simt_pxor PR:$a, PR:$b),
          (SIMT_PXOR PR:$a, PR:$b)>;
def : Pat<(int_riscv_simt_pnot PR:$a),
          (SIMT_PNOT PR:$a)>;

// Patterns with zext for returning i32 from i1 operations
def : Pat<(i32 (zext (int_riscv_simt_pand PR:$a, PR:$b))),
          (SIMT_PMOV_TO_X (SIMT_PAND PR:$a, PR:$b))>;
def : Pat<(i32 (zext (int_riscv_simt_por PR:$a, PR:$b))),
          (SIMT_PMOV_TO_X (SIMT_POR PR:$a, PR:$b))>;
def : Pat<(i32 (zext (int_riscv_simt_pxor PR:$a, PR:$b))),
          (SIMT_PMOV_TO_X (SIMT_PXOR PR:$a, PR:$b))>;
def : Pat<(i32 (zext (int_riscv_simt_pnot PR:$a))),
          (SIMT_PMOV_TO_X (SIMT_PNOT PR:$a))>;
// zext of pmov_from_x
def : Pat<(i32 (zext (int_riscv_simt_pmov_from_x GPR:$a))),
          (SIMT_PMOV_TO_X (SIMT_PMOV_FROM_X GPR:$a))>;

// Predicate transfer intrinsics - convert between GPR and PR
def : Pat<(int_riscv_simt_pmov_to_x PR:$a),
          (SIMT_PMOV_TO_X PR:$a)>;
def : Pat<(int_riscv_simt_pmov_from_x GPR:$a),
          (SIMT_PMOV_FROM_X GPR:$a)>;

// Predicated memory access intrinsics
// plw(base, offset, pred) -> load if pred else 0
// pred is now i1 in PR register class
def : Pat<(int_riscv_simt_plw GPR:$base, GPR:$offset, PR:$pred),
          (SIMT_PLW GPR:$base, GPR:$offset, PR:$pred)>;
def : Pat<(int_riscv_simt_pflw GPR:$base, GPR:$offset, PR:$pred),
          (SIMT_PFLW GPR:$base, GPR:$offset, PR:$pred)>;

// psw(val, base, offset, pred) -> store if pred
def : Pat<(int_riscv_simt_psw GPR:$val, GPR:$base, GPR:$offset, PR:$pred),
          (SIMT_PSW GPR:$val, GPR:$base, GPR:$offset, PR:$pred)>;
def : Pat<(int_riscv_simt_pfsw FPR32:$val, GPR:$base, GPR:$offset, PR:$pred),
          (SIMT_PFSW FPR32:$val, GPR:$base, GPR:$offset, PR:$pred)>;

} // Predicates = [HasVendorXCustomSIMT]
