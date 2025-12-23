//===- RISCVSystemOperandsSIMT.td - Custom SIMT CSRs -----*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines the CSRs (Control and Status Registers) for the
// Custom SIMT Vector core extension.
//
// CSR Address Map (from Vector_Arch_Spec.md):
//   CSR_SIMT_TID_X     = 0xFC0  (threadIdx.x)
//   CSR_SIMT_TID_Y     = 0xFC4  (threadIdx.y)
//   CSR_SIMT_TID_Z     = 0xFC8  (threadIdx.z)
//   CSR_SIMT_NTID_X    = 0xFCC  (blockDim.x)
//   CSR_SIMT_NTID_Y    = 0xFD0  (blockDim.y)
//   CSR_SIMT_NTID_Z    = 0xFD4  (blockDim.z)
//   CSR_SIMT_CTAID_X   = 0xFD8  (blockIdx.x / program_id.x)
//   CSR_SIMT_CTAID_Y   = 0xFDC  (blockIdx.y)
//   CSR_SIMT_CTAID_Z   = 0xFE0  (blockIdx.z)
//   CSR_SIMT_LANEID    = 0xFE4  (lane ID, 0..warp_size-1)
//   CSR_SIMT_WARPSIZE  = 0xFE8  (warp size, typically 32)
//   CSR_SIMT_LMASK_ACT = 0xFEC  (active lane mask, read-only)
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Custom SIMT CSR Definitions
//===----------------------------------------------------------------------===//

// Thread ID CSRs (within CTA/Block)
def : SysReg<"simt_tid_x", 0xFC0>;
def : SysReg<"simt_tid_y", 0xFC4>;
def : SysReg<"simt_tid_z", 0xFC8>;

// Block Dimension CSRs (CTA size)
def : SysReg<"simt_ntid_x", 0xFCC>;
def : SysReg<"simt_ntid_y", 0xFD0>;
def : SysReg<"simt_ntid_z", 0xFD4>;

// CTA/Block ID CSRs (within Grid)
def : SysReg<"simt_ctaid_x", 0xFD8>;
def : SysReg<"simt_ctaid_y", 0xFDC>;
def : SysReg<"simt_ctaid_z", 0xFE0>;

// Lane and Warp CSRs
def : SysReg<"simt_laneid", 0xFE4>;
def : SysReg<"simt_warpsize", 0xFE8>;

// Active Lane Mask (read-only)
def : SysReg<"simt_lmask_act", 0xFEC>;

//===----------------------------------------------------------------------===//
// CSR Address Constants (for use in lowering)
//===----------------------------------------------------------------------===//

// These can be used in instruction patterns and lowering code
// via RISCVSIMTCSRs namespace

class SIMTCSRAddress<bits<12> addr> {
  bits<12> Address = addr;
}

def SIMT_TID_X     : SIMTCSRAddress<0xFC0>;
def SIMT_TID_Y     : SIMTCSRAddress<0xFC4>;
def SIMT_TID_Z     : SIMTCSRAddress<0xFC8>;
def SIMT_NTID_X    : SIMTCSRAddress<0xFCC>;
def SIMT_NTID_Y    : SIMTCSRAddress<0xFD0>;
def SIMT_NTID_Z    : SIMTCSRAddress<0xFD4>;
def SIMT_CTAID_X   : SIMTCSRAddress<0xFD8>;
def SIMT_CTAID_Y   : SIMTCSRAddress<0xFDC>;
def SIMT_CTAID_Z   : SIMTCSRAddress<0xFE0>;
def SIMT_LANEID    : SIMTCSRAddress<0xFE4>;
def SIMT_WARPSIZE  : SIMTCSRAddress<0xFE8>;
def SIMT_LMASK_ACT : SIMTCSRAddress<0xFEC>;
