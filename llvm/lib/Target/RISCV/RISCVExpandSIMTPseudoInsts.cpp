//===- RISCVExpandSIMTPseudoInsts.cpp - Expand SIMT pseudo instrs --------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains a pass that expands Custom SIMT pseudo instructions
// into their corresponding machine instructions.
//
// Expansions:
// - PseudoReadSIMT_TID_X -> csrr rd, 0xFC0
// - PseudoReadSIMT_LANEID -> csrr rd, 0xFE4
// - PseudoSIMT_BARRIER -> fence rw,rw ; bar.sync
// - PseudoSIMT_LMASK_PUSH_LABEL -> auipc+addi ; lmask.push
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"
#include "RISCVSubtarget.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-expand-simt-pseudo"
#define RISCV_EXPAND_SIMT_PSEUDO_NAME "RISC-V Expand SIMT Pseudo Instructions"

namespace {

class RISCVExpandSIMTPseudo : public MachineFunctionPass {
public:
  static char ID;

  RISCVExpandSIMTPseudo() : MachineFunctionPass(ID) {}

  bool runOnMachineFunction(MachineFunction &MF) override;

  StringRef getPassName() const override {
    return RISCV_EXPAND_SIMT_PSEUDO_NAME;
  }

private:
  const RISCVSubtarget *STI = nullptr;
  const RISCVInstrInfo *TII = nullptr;

  bool expandMI(MachineBasicBlock &MBB, MachineBasicBlock::iterator MBBI,
                MachineBasicBlock::iterator &NextMBBI);

  bool expandReadCSRPseudo(MachineBasicBlock &MBB,
                           MachineBasicBlock::iterator MBBI,
                           unsigned CSRAddr);

  bool expandBarrierPseudo(MachineBasicBlock &MBB,
                           MachineBasicBlock::iterator MBBI);

  bool expandLMaskPushLabelPseudo(MachineBasicBlock &MBB,
                                  MachineBasicBlock::iterator MBBI);

  // Predicate pseudo expansion functions
  bool expandPCmpPseudo(MachineBasicBlock &MBB,
                        MachineBasicBlock::iterator MBBI,
                        unsigned PCmpOpcode);
  bool expandPSelPseudo(MachineBasicBlock &MBB,
                        MachineBasicBlock::iterator MBBI,
                        unsigned PSelOpcode);
  bool expandPLogicPseudo(MachineBasicBlock &MBB,
                          MachineBasicBlock::iterator MBBI,
                          unsigned PLogicOpcode);
  bool expandPMovPseudo(MachineBasicBlock &MBB,
                        MachineBasicBlock::iterator MBBI,
                        bool ToGPR);
  bool expandPLoadPseudo(MachineBasicBlock &MBB,
                         MachineBasicBlock::iterator MBBI,
                         unsigned PLoadOpcode);
  bool expandPStorePseudo(MachineBasicBlock &MBB,
                          MachineBasicBlock::iterator MBBI,
                          unsigned PStoreOpcode);
  // PR register spill/reload expansion
  bool expandPRSpillPseudo(MachineBasicBlock &MBB,
                           MachineBasicBlock::iterator MBBI);
  bool expandPRReloadPseudo(MachineBasicBlock &MBB,
                            MachineBasicBlock::iterator MBBI);
};

} // end anonymous namespace

char RISCVExpandSIMTPseudo::ID = 0;

INITIALIZE_PASS(RISCVExpandSIMTPseudo, DEBUG_TYPE,
                RISCV_EXPAND_SIMT_PSEUDO_NAME, false, false)

bool RISCVExpandSIMTPseudo::runOnMachineFunction(MachineFunction &MF) {
  STI = &MF.getSubtarget<RISCVSubtarget>();
  
  // Only run if custom SIMT is enabled
  if (!STI->hasVendorXCustomSIMT())
    return false;

  TII = STI->getInstrInfo();
  bool Modified = false;

  for (MachineBasicBlock &MBB : MF) {
    MachineBasicBlock::iterator MBBI = MBB.begin(), E = MBB.end();
    while (MBBI != E) {
      MachineBasicBlock::iterator NextMBBI = std::next(MBBI);
      Modified |= expandMI(MBB, MBBI, NextMBBI);
      MBBI = NextMBBI;
    }
  }

  return Modified;
}

bool RISCVExpandSIMTPseudo::expandMI(MachineBasicBlock &MBB,
                                     MachineBasicBlock::iterator MBBI,
                                     MachineBasicBlock::iterator &NextMBBI) {
  switch (MBBI->getOpcode()) {
  // Thread ID CSRs
  case RISCV::PseudoReadSIMT_TID_X:
    return expandReadCSRPseudo(MBB, MBBI, 0xFC0);
  case RISCV::PseudoReadSIMT_TID_Y:
    return expandReadCSRPseudo(MBB, MBBI, 0xFC4);
  case RISCV::PseudoReadSIMT_TID_Z:
    return expandReadCSRPseudo(MBB, MBBI, 0xFC8);
    
  // Block dimension CSRs
  case RISCV::PseudoReadSIMT_NTID_X:
    return expandReadCSRPseudo(MBB, MBBI, 0xFCC);
  case RISCV::PseudoReadSIMT_NTID_Y:
    return expandReadCSRPseudo(MBB, MBBI, 0xFD0);
  case RISCV::PseudoReadSIMT_NTID_Z:
    return expandReadCSRPseudo(MBB, MBBI, 0xFD4);
    
  // CTA ID CSRs
  case RISCV::PseudoReadSIMT_CTAID_X:
    return expandReadCSRPseudo(MBB, MBBI, 0xFD8);
  case RISCV::PseudoReadSIMT_CTAID_Y:
    return expandReadCSRPseudo(MBB, MBBI, 0xFDC);
  case RISCV::PseudoReadSIMT_CTAID_Z:
    return expandReadCSRPseudo(MBB, MBBI, 0xFE0);
    
  // Lane/Warp CSRs
  case RISCV::PseudoReadSIMT_LANEID:
    return expandReadCSRPseudo(MBB, MBBI, 0xFE4);
  case RISCV::PseudoReadSIMT_WARPSIZE:
    return expandReadCSRPseudo(MBB, MBBI, 0xFE8);
  case RISCV::PseudoReadSIMT_LMASK_ACT:
    return expandReadCSRPseudo(MBB, MBBI, 0xFEC);
    
  // Barrier
  case RISCV::PseudoSIMT_BARRIER:
    return expandBarrierPseudo(MBB, MBBI);
    
  // LMASK.PUSH with label
  case RISCV::PseudoSIMT_LMASK_PUSH_LABEL:
    return expandLMaskPushLabelPseudo(MBB, MBBI);
    
  // Predicate compare pseudos
  case RISCV::PseudoSIMT_PCMP_EQ:
    return expandPCmpPseudo(MBB, MBBI, RISCV::SIMT_PCMP_EQ);
  case RISCV::PseudoSIMT_PCMP_NE:
    return expandPCmpPseudo(MBB, MBBI, RISCV::SIMT_PCMP_NE);
  case RISCV::PseudoSIMT_PCMP_LT:
    return expandPCmpPseudo(MBB, MBBI, RISCV::SIMT_PCMP_LT);
  case RISCV::PseudoSIMT_PCMP_LTU:
    return expandPCmpPseudo(MBB, MBBI, RISCV::SIMT_PCMP_LTU);
  case RISCV::PseudoSIMT_PCMP_LE:
    return expandPCmpPseudo(MBB, MBBI, RISCV::SIMT_PCMP_LE);
  case RISCV::PseudoSIMT_PCMP_F_EQ:
    return expandPCmpPseudo(MBB, MBBI, RISCV::SIMT_PCMP_F_EQ);
  case RISCV::PseudoSIMT_PCMP_F_LT:
    return expandPCmpPseudo(MBB, MBBI, RISCV::SIMT_PCMP_F_LT);
  case RISCV::PseudoSIMT_PCMP_F_LE:
    return expandPCmpPseudo(MBB, MBBI, RISCV::SIMT_PCMP_F_LE);
    
  // Predicate select pseudos
  case RISCV::PseudoSIMT_PSEL:
    return expandPSelPseudo(MBB, MBBI, RISCV::SIMT_PSEL);
  case RISCV::PseudoSIMT_PSEL_F:
    return expandPSelPseudo(MBB, MBBI, RISCV::SIMT_PSEL_F);
    
  // Predicate logic pseudos
  case RISCV::PseudoSIMT_PAND:
    return expandPLogicPseudo(MBB, MBBI, RISCV::SIMT_PAND);
  case RISCV::PseudoSIMT_POR:
    return expandPLogicPseudo(MBB, MBBI, RISCV::SIMT_POR);
  case RISCV::PseudoSIMT_PXOR:
    return expandPLogicPseudo(MBB, MBBI, RISCV::SIMT_PXOR);
  case RISCV::PseudoSIMT_PNOT:
    return expandPLogicPseudo(MBB, MBBI, RISCV::SIMT_PNOT);
    
  // Predicate transfer pseudos
  case RISCV::PseudoSIMT_PMOV_TO_X:
    return expandPMovPseudo(MBB, MBBI, /*ToGPR=*/true);
  case RISCV::PseudoSIMT_PMOV_FROM_X:
    return expandPMovPseudo(MBB, MBBI, /*ToGPR=*/false);
    
  // Predicated load/store pseudos
  case RISCV::PseudoSIMT_PLW:
    return expandPLoadPseudo(MBB, MBBI, RISCV::SIMT_PLW);
  case RISCV::PseudoSIMT_PFLW:
    return expandPLoadPseudo(MBB, MBBI, RISCV::SIMT_PFLW);
  case RISCV::PseudoSIMT_PSW:
    return expandPStorePseudo(MBB, MBBI, RISCV::SIMT_PSW);
  case RISCV::PseudoSIMT_PFSW:
    return expandPStorePseudo(MBB, MBBI, RISCV::SIMT_PFSW);

  // PR register copy/spill/reload pseudos
  case RISCV::PseudoPRSpill:
    return expandPRSpillPseudo(MBB, MBBI);
  case RISCV::PseudoPRReload:
    return expandPRReloadPseudo(MBB, MBBI);
    
  default:
    return false;
  }
}

bool RISCVExpandSIMTPseudo::expandReadCSRPseudo(MachineBasicBlock &MBB,
                                                 MachineBasicBlock::iterator MBBI,
                                                 unsigned CSRAddr) {
  MachineInstr &MI = *MBBI;
  DebugLoc DL = MI.getDebugLoc();
  Register DestReg = MI.getOperand(0).getReg();

  // Expand to: csrrs rd, csr, x0
  // CSRRS rd, csr, x0 reads the CSR and writes to rd
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::CSRRS), DestReg)
      .addImm(CSRAddr)
      .addReg(RISCV::X0);

  MI.eraseFromParent();
  return true;
}

bool RISCVExpandSIMTPseudo::expandBarrierPseudo(MachineBasicBlock &MBB,
                                                 MachineBasicBlock::iterator MBBI) {
  MachineInstr &MI = *MBBI;
  DebugLoc DL = MI.getDebugLoc();

  // Barrier lowering: fence rw,rw + bar.sync
  // Per the implementation plan: llvm.custom.barrier() -> fence + bar.sync
  
  // 1. Emit fence rw, rw (FENCE with pred=rw, succ=rw)
  // FENCE encoding: fence pred, succ where pred/succ are 4-bit masks (iorw)
  // rw = 0b0011 (read+write)
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::FENCE))
      .addImm(0b0011)  // pred: rw
      .addImm(0b0011); // succ: rw

  // 2. Emit bar.sync (SIMT_BAR_SYNC)
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_BAR_SYNC));

  MI.eraseFromParent();
  return true;
}

bool RISCVExpandSIMTPseudo::expandLMaskPushLabelPseudo(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MBBI) {
  MachineInstr &MI = *MBBI;
  DebugLoc DL = MI.getDebugLoc();
  MachineFunction &MF = *MBB.getParent();
  const MachineOperand &TargetOp = MI.getOperand(0);

  // Get a scratch register for the address
  // In practice, we need proper register allocation. For now use a temp.
  Register ScratchReg = RISCV::X5; // t0 - temporary register

  // Materialize the target address into ScratchReg using auipc + addi
  // This handles PC-relative addressing
  
  if (TargetOp.isMBB()) {
    MachineBasicBlock *TargetMBB = TargetOp.getMBB();
    
    // Create a symbol for the target block if needed
    // For now, emit a two-instruction sequence for PC-relative address
    
    // AUIPC rd, %pcrel_hi(target)
    BuildMI(MBB, MBBI, DL, TII->get(RISCV::AUIPC), ScratchReg)
        .addMBB(TargetMBB, RISCVII::MO_PCREL_HI);
    
    // ADDI rd, rd, %pcrel_lo(target)
    BuildMI(MBB, MBBI, DL, TII->get(RISCV::ADDI), ScratchReg)
        .addReg(ScratchReg)
        .addMBB(TargetMBB, RISCVII::MO_PCREL_LO);
  } else {
    // If it's a direct immediate, just load it
    // This shouldn't happen in normal use
    llvm_unreachable("LMASK.PUSH target must be a basic block");
  }

  // Emit LMASK.PUSH with the address in ScratchReg
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_LMASK_PUSH))
      .addReg(ScratchReg);

  MI.eraseFromParent();
  return true;
}

// Expand predicate compare pseudo:
// PseudoSIMT_PCMP_* rd, rs1, rs2
// ->
// PCMP.* p0, rs1, rs2
// PMOV.TO.X rd, p0
bool RISCVExpandSIMTPseudo::expandPCmpPseudo(MachineBasicBlock &MBB,
                                              MachineBasicBlock::iterator MBBI,
                                              unsigned PCmpOpcode) {
  MachineInstr &MI = *MBBI;
  DebugLoc DL = MI.getDebugLoc();
  Register DestReg = MI.getOperand(0).getReg();
  Register Src1Reg = MI.getOperand(1).getReg();
  Register Src2Reg = MI.getOperand(2).getReg();

  // Use p0 as scratch predicate register
  // TODO: proper predicate register allocation
  Register PredReg = RISCV::P0;

  // 1. PCMP.* p0, rs1, rs2
  BuildMI(MBB, MBBI, DL, TII->get(PCmpOpcode), PredReg)
      .addReg(Src1Reg)
      .addReg(Src2Reg);

  // 2. PMOV.TO.X rd, p0
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_TO_X), DestReg)
      .addReg(PredReg);

  MI.eraseFromParent();
  return true;
}

// Expand predicate select pseudo:
// PseudoSIMT_PSEL rd, rs1, rs2, cond
// ->
// PMOV.FROM.X p0, cond
// PSEL rd, rs1, rs2, p0
bool RISCVExpandSIMTPseudo::expandPSelPseudo(MachineBasicBlock &MBB,
                                              MachineBasicBlock::iterator MBBI,
                                              unsigned PSelOpcode) {
  MachineInstr &MI = *MBBI;
  DebugLoc DL = MI.getDebugLoc();
  Register DestReg = MI.getOperand(0).getReg();
  Register TrueReg = MI.getOperand(1).getReg();
  Register FalseReg = MI.getOperand(2).getReg();
  Register CondReg = MI.getOperand(3).getReg();

  // Use p0 as scratch predicate register
  Register PredReg = RISCV::P0;

  // 1. PMOV.FROM.X p0, cond
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_FROM_X), PredReg)
      .addReg(CondReg);

  // 2. PSEL rd, rs1, rs2, p0
  BuildMI(MBB, MBBI, DL, TII->get(PSelOpcode), DestReg)
      .addReg(TrueReg)
      .addReg(FalseReg)
      .addReg(PredReg);

  MI.eraseFromParent();
  return true;
}

// Expand predicate logic pseudo:
// PseudoSIMT_PAND/POR/PXOR rd, rs1, rs2
// ->
// PMOV.FROM.X p0, rs1
// PMOV.FROM.X p1, rs2
// PAND/POR/PXOR p0, p0, p1
// PMOV.TO.X rd, p0
bool RISCVExpandSIMTPseudo::expandPLogicPseudo(MachineBasicBlock &MBB,
                                                MachineBasicBlock::iterator MBBI,
                                                unsigned PLogicOpcode) {
  MachineInstr &MI = *MBBI;
  DebugLoc DL = MI.getDebugLoc();
  Register DestReg = MI.getOperand(0).getReg();
  Register Src1Reg = MI.getOperand(1).getReg();
  
  // Use p0, p1 as scratch predicate registers
  Register Pred0Reg = RISCV::P0;
  Register Pred1Reg = RISCV::P1;

  // 1. PMOV.FROM.X p0, rs1
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_FROM_X), Pred0Reg)
      .addReg(Src1Reg);

  // Check if it's PNOT (unary) or binary operation
  if (PLogicOpcode == RISCV::SIMT_PNOT) {
    // PNOT pd, ps1
    BuildMI(MBB, MBBI, DL, TII->get(PLogicOpcode), Pred0Reg)
        .addReg(Pred0Reg);
  } else {
    Register Src2Reg = MI.getOperand(2).getReg();
    
    // 2. PMOV.FROM.X p1, rs2
    BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_FROM_X), Pred1Reg)
        .addReg(Src2Reg);

    // 3. PAND/POR/PXOR p0, p0, p1
    BuildMI(MBB, MBBI, DL, TII->get(PLogicOpcode), Pred0Reg)
        .addReg(Pred0Reg)
        .addReg(Pred1Reg);
  }

  // 4. PMOV.TO.X rd, p0
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_TO_X), DestReg)
      .addReg(Pred0Reg);

  MI.eraseFromParent();
  return true;
}

// Expand predicate transfer pseudo:
// PseudoSIMT_PMOV_TO_X rd, rs1 (rs1 is GPR with 0/1)
// PseudoSIMT_PMOV_FROM_X rd, rs1
bool RISCVExpandSIMTPseudo::expandPMovPseudo(MachineBasicBlock &MBB,
                                              MachineBasicBlock::iterator MBBI,
                                              bool ToGPR) {
  MachineInstr &MI = *MBBI;
  DebugLoc DL = MI.getDebugLoc();
  Register DestReg = MI.getOperand(0).getReg();
  Register SrcReg = MI.getOperand(1).getReg();

  Register PredReg = RISCV::P0;

  if (ToGPR) {
    // PMOV.FROM.X p0, src ; PMOV.TO.X dest, p0
    BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_FROM_X), PredReg)
        .addReg(SrcReg);
    BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_TO_X), DestReg)
        .addReg(PredReg);
  } else {
    // Same as above - round-trip through predicate
    BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_FROM_X), PredReg)
        .addReg(SrcReg);
    BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_TO_X), DestReg)
        .addReg(PredReg);
  }

  MI.eraseFromParent();
  return true;
}

// Expand predicated load pseudo:
// PseudoSIMT_PLW rd, base, offset, pred
// ->
// PMOV.FROM.X p0, pred
// PLW rd, base, offset, p0
bool RISCVExpandSIMTPseudo::expandPLoadPseudo(MachineBasicBlock &MBB,
                                               MachineBasicBlock::iterator MBBI,
                                               unsigned PLoadOpcode) {
  MachineInstr &MI = *MBBI;
  DebugLoc DL = MI.getDebugLoc();
  Register DestReg = MI.getOperand(0).getReg();
  Register BaseReg = MI.getOperand(1).getReg();
  Register OffsetReg = MI.getOperand(2).getReg();
  Register PredGPR = MI.getOperand(3).getReg();

  Register PredReg = RISCV::P0;

  // 1. PMOV.FROM.X p0, pred
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_FROM_X), PredReg)
      .addReg(PredGPR);

  // 2. PLW rd, base, offset, p0
  BuildMI(MBB, MBBI, DL, TII->get(PLoadOpcode), DestReg)
      .addReg(BaseReg)
      .addReg(OffsetReg)
      .addReg(PredReg);

  MI.eraseFromParent();
  return true;
}

// Expand predicated store pseudo:
// PseudoSIMT_PSW val, base, offset, pred
// ->
// PMOV.FROM.X p0, pred
// PSW val, base, offset, p0
bool RISCVExpandSIMTPseudo::expandPStorePseudo(MachineBasicBlock &MBB,
                                                MachineBasicBlock::iterator MBBI,
                                                unsigned PStoreOpcode) {
  MachineInstr &MI = *MBBI;
  DebugLoc DL = MI.getDebugLoc();
  Register ValReg = MI.getOperand(0).getReg();
  Register BaseReg = MI.getOperand(1).getReg();
  Register OffsetReg = MI.getOperand(2).getReg();
  Register PredGPR = MI.getOperand(3).getReg();

  Register PredReg = RISCV::P0;

  // 1. PMOV.FROM.X p0, pred
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_FROM_X), PredReg)
      .addReg(PredGPR);

  // 2. PSW val, base, offset, p0
  BuildMI(MBB, MBBI, DL, TII->get(PStoreOpcode))
      .addReg(ValReg)
      .addReg(BaseReg)
      .addReg(OffsetReg)
      .addReg(PredReg);

  MI.eraseFromParent();
  return true;
}

//===----------------------------------------------------------------------===//
// PR Register Spill/Reload Pseudo Expansion
//===----------------------------------------------------------------------===//

// Expand PR spill:
// PseudoPRSpill pr, base, offset
// ->
// pmov.to.x tmp, pr
// sw tmp, offset(base)
bool RISCVExpandSIMTPseudo::expandPRSpillPseudo(MachineBasicBlock &MBB,
                                                 MachineBasicBlock::iterator MBBI) {
  MachineInstr &MI = *MBBI;
  DebugLoc DL = MI.getDebugLoc();
  Register SrcReg = MI.getOperand(0).getReg();
  Register BaseReg = MI.getOperand(1).getReg();
  int64_t Offset = MI.getOperand(2).getImm();

  // Use X31 (t6) as temporary GPR
  Register TmpGPR = RISCV::X31;

  // 1. PMOV.TO.X tmp, pr
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_TO_X), TmpGPR)
      .addReg(SrcReg, getKillRegState(MI.getOperand(0).isKill()));

  // 2. SW tmp, offset(base)
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SW))
      .addReg(TmpGPR, RegState::Kill)
      .addReg(BaseReg)
      .addImm(Offset);

  MI.eraseFromParent();
  return true;
}

// Expand PR reload:
// PseudoPRReload pr, base, offset
// ->
// lw tmp, offset(base)
// pmov.from.x pr, tmp
bool RISCVExpandSIMTPseudo::expandPRReloadPseudo(MachineBasicBlock &MBB,
                                                  MachineBasicBlock::iterator MBBI) {
  MachineInstr &MI = *MBBI;
  DebugLoc DL = MI.getDebugLoc();
  Register DestReg = MI.getOperand(0).getReg();
  Register BaseReg = MI.getOperand(1).getReg();
  int64_t Offset = MI.getOperand(2).getImm();

  // Use X31 (t6) as temporary GPR
  Register TmpGPR = RISCV::X31;

  // 1. LW tmp, offset(base)
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::LW), TmpGPR)
      .addReg(BaseReg)
      .addImm(Offset);

  // 2. PMOV.FROM.X pr, tmp
  BuildMI(MBB, MBBI, DL, TII->get(RISCV::SIMT_PMOV_FROM_X), DestReg)
      .addReg(TmpGPR, RegState::Kill);

  MI.eraseFromParent();
  return true;
}

FunctionPass *llvm::createRISCVExpandSIMTPseudoPass() {
  return new RISCVExpandSIMTPseudo();
}
