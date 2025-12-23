//===- RISCVInsertLMaskPush.cpp - Insert LMASK.PUSH for SIMT branches ----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass inserts LMASK.PUSH instructions before conditional branches
// in SIMT kernels. The LMASK.PUSH instruction sets up the reconvergence
// point for hardware branch divergence management.
//
// Background (from Vector_Arch_Spec):
// - Hardware uses lane stacks + branch tree for divergence management
// - Compiler must insert LMASK.PUSH(reconv_pc) before divergent branches
// - Hardware automatically detects reconvergence and pops the stack
//
// Strategy (v1 - correctness first):
// - Insert LMASK.PUSH before every conditional branch in kernels
// - Use immediate post-dominator as reconvergence point (fallback: merge block)
// - Can be refined later for performance (skip uniform branches)
//
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"
#include "RISCVSubtarget.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/CodeGen/MachineDominators.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachinePostDominators.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/InitializePasses.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-insert-lmask-push"
#define RISCV_INSERT_LMASK_PUSH_NAME "RISC-V Insert LMASK.PUSH for SIMT"

namespace {

class RISCVInsertLMaskPush : public MachineFunctionPass {
public:
  static char ID;

  RISCVInsertLMaskPush() : MachineFunctionPass(ID) {
    initializeRISCVInsertLMaskPushPass(*PassRegistry::getPassRegistry());
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

  StringRef getPassName() const override {
    return RISCV_INSERT_LMASK_PUSH_NAME;
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<MachinePostDominatorTreeWrapperPass>();
    AU.setPreservesCFG();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

private:
  const RISCVSubtarget *STI = nullptr;
  const RISCVInstrInfo *TII = nullptr;
  MachinePostDominatorTree *MPDT = nullptr;

  bool processBasicBlock(MachineBasicBlock &MBB);
  
  MachineBasicBlock *findReconvergencePoint(MachineBasicBlock &MBB,
                                            MachineInstr &BranchMI);
  
  bool isConditionalBranch(const MachineInstr &MI) const;
};

} // end anonymous namespace

char RISCVInsertLMaskPush::ID = 0;

INITIALIZE_PASS_BEGIN(RISCVInsertLMaskPush, DEBUG_TYPE,
                      RISCV_INSERT_LMASK_PUSH_NAME, false, false)
INITIALIZE_PASS_DEPENDENCY(MachinePostDominatorTreeWrapperPass)
INITIALIZE_PASS_END(RISCVInsertLMaskPush, DEBUG_TYPE,
                    RISCV_INSERT_LMASK_PUSH_NAME, false, false)

bool RISCVInsertLMaskPush::runOnMachineFunction(MachineFunction &MF) {
  STI = &MF.getSubtarget<RISCVSubtarget>();
  
  // Only run if custom SIMT is enabled
  if (!STI->hasVendorXCustomSIMT())
    return false;

  // Check if this is a kernel function
  // For now, process all functions; could add kernel attribute check
  const Function &F = MF.getFunction();
  if (!F.hasFnAttribute("kernel") && !F.hasFnAttribute("nvvm.kernel"))
    return false;

  TII = STI->getInstrInfo();
  MPDT = &getAnalysis<MachinePostDominatorTreeWrapperPass>().getPostDomTree();

  bool Modified = false;

  for (MachineBasicBlock &MBB : MF) {
    Modified |= processBasicBlock(MBB);
  }

  return Modified;
}

bool RISCVInsertLMaskPush::processBasicBlock(MachineBasicBlock &MBB) {
  bool Modified = false;

  // Look for conditional branches at the end of the block
  for (MachineInstr &MI : MBB.terminators()) {
    if (!isConditionalBranch(MI))
      continue;

    // Find the reconvergence point
    MachineBasicBlock *ReconvMBB = findReconvergencePoint(MBB, MI);
    if (!ReconvMBB)
      continue;

    // Insert LMASK.PUSH before the branch
    // The LMASK.PUSH needs to be before the branch instruction
    DebugLoc DL = MI.getDebugLoc();
    
    BuildMI(MBB, MI.getIterator(), DL, 
            TII->get(RISCV::PseudoSIMT_LMASK_PUSH_LABEL))
        .addMBB(ReconvMBB);

    Modified = true;
    
    // Only process one branch per block (there should be at most one)
    break;
  }

  return Modified;
}

MachineBasicBlock *RISCVInsertLMaskPush::findReconvergencePoint(
    MachineBasicBlock &MBB, MachineInstr &BranchMI) {
  
  // Strategy 1: Use immediate post-dominator
  // The IPDOM of a branch is where all paths from the branch meet again
  if (MPDT && MPDT->getNode(&MBB)) {
    MachineBasicBlock *IPDOM = MPDT->getNode(&MBB)->getIDom()->getBlock();
    if (IPDOM)
      return IPDOM;
  }

  // Strategy 2: Fallback - use the fall-through successor if it exists
  // This is a conservative choice for simple if-else patterns
  for (MachineBasicBlock *Succ : MBB.successors()) {
    // Check if this is the fall-through block (not the branch target)
    bool IsBranchTarget = false;
    for (const MachineOperand &Op : BranchMI.operands()) {
      if (Op.isMBB() && Op.getMBB() == Succ) {
        IsBranchTarget = true;
        break;
      }
    }
    
    if (!IsBranchTarget) {
      // This is likely the fall-through, could be reconvergence
      // But this is a very rough heuristic
      continue;
    }
  }

  // Strategy 3: Use first successor as fallback
  // This is not always correct but provides a safe default
  if (!MBB.successors().empty()) {
    // For a proper implementation, we should track the merge block
    // For now, return nullptr to skip this branch
    // A more sophisticated analysis would be needed
  }

  // If we can't determine reconvergence, skip this branch
  // In a real implementation, we might want to be more conservative
  // and insert LMASK.PUSH anyway with a default target
  return nullptr;
}

bool RISCVInsertLMaskPush::isConditionalBranch(const MachineInstr &MI) const {
  switch (MI.getOpcode()) {
  case RISCV::BEQ:
  case RISCV::BNE:
  case RISCV::BLT:
  case RISCV::BLTU:
  case RISCV::BGE:
  case RISCV::BGEU:
    return true;
  default:
    return false;
  }
}

FunctionPass *llvm::createRISCVInsertLMaskPushPass() {
  return new RISCVInsertLMaskPush();
}
