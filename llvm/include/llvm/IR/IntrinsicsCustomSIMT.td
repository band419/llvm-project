//===- IntrinsicsCustomSIMT.td - Defines Custom SIMT intrinsics -*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines all of the Custom SIMT-specific intrinsics for the
// Vector core based on RISC-V with SIMT extensions.
//
// These intrinsics are used by Triton's custom backend pipeline and lowered
// to RISC-V + custom opcode 0x0B instructions.
//
//===----------------------------------------------------------------------===//

let TargetPrefix = "riscv" in {

//===----------------------------------------------------------------------===//
// Thread/Block ID Intrinsics
//===----------------------------------------------------------------------===//

// Thread ID within block (threadIdx.x/y/z)
def int_riscv_simt_tid_x : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;
def int_riscv_simt_tid_y : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;
def int_riscv_simt_tid_z : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;

// Block dimension (blockDim.x/y/z)
def int_riscv_simt_ntid_x : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;
def int_riscv_simt_ntid_y : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;
def int_riscv_simt_ntid_z : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;

// Block ID within grid (blockIdx.x/y/z) - also known as program_id
def int_riscv_simt_ctaid_x : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;
def int_riscv_simt_ctaid_y : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;
def int_riscv_simt_ctaid_z : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;

// Grid dimension (gridDim.x/y/z)
def int_riscv_simt_nctaid_x : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;
def int_riscv_simt_nctaid_y : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;
def int_riscv_simt_nctaid_z : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;

// Lane ID within warp (0 to warp_size-1)
def int_riscv_simt_lane_id : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;

// Warp size (typically 32)
def int_riscv_simt_warp_size : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrSpeculatable, IntrWillReturn]>;

// Active lane mask (current execution mask)
def int_riscv_simt_activemask : DefaultAttrsIntrinsic<[llvm_i32_ty], [],
    [IntrNoMem, IntrConvergent]>;

//===----------------------------------------------------------------------===//
// Synchronization Intrinsics
//===----------------------------------------------------------------------===//

// CTA-level barrier with memory fence
// Semantics: sync all threads in CTA + full memory fence
def int_riscv_simt_barrier : DefaultAttrsIntrinsic<[], [],
    [IntrConvergent, IntrWillReturn, IntrNoCallback, IntrNoFree]>;

// Warp-level barrier (sync active threads in warp)
// Semantics: sync active lanes in warp + warp-level fence
def int_riscv_simt_warp_barrier : DefaultAttrsIntrinsic<[], [],
    [IntrConvergent, IntrWillReturn, IntrNoCallback, IntrNoFree]>;

//===----------------------------------------------------------------------===//
// Shuffle Intrinsics (Cross-lane data exchange)
//===----------------------------------------------------------------------===//

// All shuffle operations are convergent (require synchronized execution)

// Shuffle XOR: exchange with lane (current_lane XOR mask)
def int_riscv_simt_shuffle_xor_i32 : DefaultAttrsIntrinsic<
    [llvm_i32_ty], [llvm_i32_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_xor_i64 : DefaultAttrsIntrinsic<
    [llvm_i64_ty], [llvm_i64_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_xor_f32 : DefaultAttrsIntrinsic<
    [llvm_float_ty], [llvm_float_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_xor_f64 : DefaultAttrsIntrinsic<
    [llvm_double_ty], [llvm_double_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;

// Shuffle Up: read from lane (current_lane - delta)
def int_riscv_simt_shuffle_up_i32 : DefaultAttrsIntrinsic<
    [llvm_i32_ty], [llvm_i32_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_up_i64 : DefaultAttrsIntrinsic<
    [llvm_i64_ty], [llvm_i64_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_up_f32 : DefaultAttrsIntrinsic<
    [llvm_float_ty], [llvm_float_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_up_f64 : DefaultAttrsIntrinsic<
    [llvm_double_ty], [llvm_double_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;

// Shuffle Down: read from lane (current_lane + delta)
def int_riscv_simt_shuffle_down_i32 : DefaultAttrsIntrinsic<
    [llvm_i32_ty], [llvm_i32_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_down_i64 : DefaultAttrsIntrinsic<
    [llvm_i64_ty], [llvm_i64_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_down_f32 : DefaultAttrsIntrinsic<
    [llvm_float_ty], [llvm_float_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_down_f64 : DefaultAttrsIntrinsic<
    [llvm_double_ty], [llvm_double_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;

// Shuffle Index: read from specified lane
def int_riscv_simt_shuffle_idx_i32 : DefaultAttrsIntrinsic<
    [llvm_i32_ty], [llvm_i32_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_idx_i64 : DefaultAttrsIntrinsic<
    [llvm_i64_ty], [llvm_i64_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_idx_f32 : DefaultAttrsIntrinsic<
    [llvm_float_ty], [llvm_float_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;
def int_riscv_simt_shuffle_idx_f64 : DefaultAttrsIntrinsic<
    [llvm_double_ty], [llvm_double_ty, llvm_i32_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;

//===----------------------------------------------------------------------===//
// Vote/Ballot Intrinsics
//===----------------------------------------------------------------------===//

// Ballot: collect predicates from all lanes, return 32-bit mask
def int_riscv_simt_ballot : DefaultAttrsIntrinsic<
    [llvm_i32_ty], [llvm_i1_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;

// All: return true if all active lanes have predicate=true
def int_riscv_simt_all : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i1_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;

// Any: return true if any active lane has predicate=true
def int_riscv_simt_any : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i1_ty],
    [IntrNoMem, IntrConvergent, IntrWillReturn]>;

//===----------------------------------------------------------------------===//
// Lane Mask Stack Intrinsics (for branch divergence handling)
//===----------------------------------------------------------------------===//

// Push reconvergence point to lane mask stack
// rs1 = reconvergence PC address
def int_riscv_simt_lmask_push : DefaultAttrsIntrinsic<
    [], [llvm_ptr_ty],
    [IntrConvergent, IntrWillReturn, IntrNoCallback, IntrNoFree]>;

//===----------------------------------------------------------------------===//
// Predicate Intrinsics
//
// These intrinsics provide explicit access to SIMT predicate instructions.
// They are used when the compiler needs precise control over predicate
// register usage, rather than relying on automatic lowering of icmp/select.
//===----------------------------------------------------------------------===//

// Predicate compare - integer comparisons
// Returns i1 (will be lowered to PR register)
def int_riscv_simt_pcmp_eq : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i32_ty, llvm_i32_ty],
    [IntrNoMem, IntrWillReturn]>;
def int_riscv_simt_pcmp_ne : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i32_ty, llvm_i32_ty],
    [IntrNoMem, IntrWillReturn]>;
def int_riscv_simt_pcmp_lt : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i32_ty, llvm_i32_ty],
    [IntrNoMem, IntrWillReturn]>;
def int_riscv_simt_pcmp_ltu : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i32_ty, llvm_i32_ty],
    [IntrNoMem, IntrWillReturn]>;
def int_riscv_simt_pcmp_le : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i32_ty, llvm_i32_ty],
    [IntrNoMem, IntrWillReturn]>;

// Predicate compare - floating point comparisons
def int_riscv_simt_pcmp_f_eq : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_float_ty, llvm_float_ty],
    [IntrNoMem, IntrWillReturn]>;
def int_riscv_simt_pcmp_f_lt : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_float_ty, llvm_float_ty],
    [IntrNoMem, IntrWillReturn]>;
def int_riscv_simt_pcmp_f_le : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_float_ty, llvm_float_ty],
    [IntrNoMem, IntrWillReturn]>;

// Predicate select - select based on predicate
def int_riscv_simt_psel_i32 : DefaultAttrsIntrinsic<
    [llvm_i32_ty], [llvm_i32_ty, llvm_i32_ty, llvm_i1_ty],
    [IntrNoMem, IntrWillReturn]>;
def int_riscv_simt_psel_f32 : DefaultAttrsIntrinsic<
    [llvm_float_ty], [llvm_float_ty, llvm_float_ty, llvm_i1_ty],
    [IntrNoMem, IntrWillReturn]>;

// Predicate logic operations
def int_riscv_simt_pand : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i1_ty, llvm_i1_ty],
    [IntrNoMem, IntrWillReturn]>;
def int_riscv_simt_por : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i1_ty, llvm_i1_ty],
    [IntrNoMem, IntrWillReturn]>;
def int_riscv_simt_pxor : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i1_ty, llvm_i1_ty],
    [IntrNoMem, IntrWillReturn]>;
def int_riscv_simt_pnot : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i1_ty],
    [IntrNoMem, IntrWillReturn]>;

// Predicate transfer - convert between predicate and GPR
def int_riscv_simt_pmov_to_x : DefaultAttrsIntrinsic<
    [llvm_i32_ty], [llvm_i1_ty],
    [IntrNoMem, IntrWillReturn]>;
def int_riscv_simt_pmov_from_x : DefaultAttrsIntrinsic<
    [llvm_i1_ty], [llvm_i32_ty],
    [IntrNoMem, IntrWillReturn]>;

// Predicated load - load with predicate mask
// If predicate is false, returns 0
def int_riscv_simt_plw : DefaultAttrsIntrinsic<
    [llvm_i32_ty], [llvm_ptr_ty, llvm_i32_ty, llvm_i1_ty],
    [IntrReadMem, IntrWillReturn]>;
def int_riscv_simt_pflw : DefaultAttrsIntrinsic<
    [llvm_float_ty], [llvm_ptr_ty, llvm_i32_ty, llvm_i1_ty],
    [IntrReadMem, IntrWillReturn]>;

// Predicated store - store with predicate mask
// If predicate is false, store is not performed
def int_riscv_simt_psw : DefaultAttrsIntrinsic<
    [], [llvm_i32_ty, llvm_ptr_ty, llvm_i32_ty, llvm_i1_ty],
    [IntrWriteMem, IntrWillReturn]>;
def int_riscv_simt_pfsw : DefaultAttrsIntrinsic<
    [], [llvm_float_ty, llvm_ptr_ty, llvm_i32_ty, llvm_i1_ty],
    [IntrWriteMem, IntrWillReturn]>;

} // TargetPrefix = "riscv"
