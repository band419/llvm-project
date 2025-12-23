; RUN: llc -mtriple=riscv32 -mattr=+xcustomsimt < %s | FileCheck %s

; Test that SIMT shuffle intrinsics lower correctly

declare i32 @llvm.custom.shuffle.idx.i32(i32, i32)
declare float @llvm.custom.shuffle.idx.f32(float, i32)
declare i32 @llvm.custom.shuffle.xor.i32(i32, i32)
declare i32 @llvm.custom.shuffle.up.i32(i32, i32)
declare i32 @llvm.custom.shuffle.down.i32(i32, i32)
declare i32 @llvm.custom.lane.id()

; CHECK-LABEL: test_shuffle_idx_i32:
; CHECK: shfl.idx a0, a0, a1
define i32 @test_shuffle_idx_i32(i32 %val, i32 %lane) {
  %result = call i32 @llvm.custom.shuffle.idx.i32(i32 %val, i32 %lane)
  ret i32 %result
}

; CHECK-LABEL: test_shuffle_idx_f32:
; CHECK: shfl.idx.f fa0, fa0, a0
define float @test_shuffle_idx_f32(float %val, i32 %lane) {
  %result = call float @llvm.custom.shuffle.idx.f32(float %val, i32 %lane)
  ret float %result
}

; shuffle_xor(val, mask) -> lane_id XOR mask -> shfl.idx
; CHECK-LABEL: test_shuffle_xor:
; CHECK: csrr [[LANEID:.*]], 0xfe4
; CHECK: xor [[SRC:.*]], [[LANEID]], a1
; CHECK: shfl.idx a0, a0, [[SRC]]
define i32 @test_shuffle_xor(i32 %val, i32 %mask) {
  %result = call i32 @llvm.custom.shuffle.xor.i32(i32 %val, i32 %mask)
  ret i32 %result
}

; shuffle_up(val, delta) -> lane_id - delta -> shfl.idx
; CHECK-LABEL: test_shuffle_up:
; CHECK: csrr [[LANEID:.*]], 0xfe4
; CHECK: sub [[SRC:.*]], [[LANEID]], a1
; CHECK: shfl.idx a0, a0, [[SRC]]
define i32 @test_shuffle_up(i32 %val, i32 %delta) {
  %result = call i32 @llvm.custom.shuffle.up.i32(i32 %val, i32 %delta)
  ret i32 %result
}

; shuffle_down(val, delta) -> lane_id + delta -> shfl.idx
; CHECK-LABEL: test_shuffle_down:
; CHECK: csrr [[LANEID:.*]], 0xfe4
; CHECK: add [[SRC:.*]], [[LANEID]], a1
; CHECK: shfl.idx a0, a0, [[SRC]]
define i32 @test_shuffle_down(i32 %val, i32 %delta) {
  %result = call i32 @llvm.custom.shuffle.down.i32(i32 %val, i32 %delta)
  ret i32 %result
}

; Test butterfly reduction pattern (commonly used for warp reduction)
; CHECK-LABEL: test_butterfly_reduction:
define i32 @test_butterfly_reduction(i32 %val) {
  ; XOR with 16
  %s1 = call i32 @llvm.custom.shuffle.xor.i32(i32 %val, i32 16)
  %r1 = add i32 %val, %s1
  
  ; XOR with 8
  %s2 = call i32 @llvm.custom.shuffle.xor.i32(i32 %r1, i32 8)
  %r2 = add i32 %r1, %s2
  
  ; XOR with 4
  %s3 = call i32 @llvm.custom.shuffle.xor.i32(i32 %r2, i32 4)
  %r3 = add i32 %r2, %s3
  
  ; XOR with 2
  %s4 = call i32 @llvm.custom.shuffle.xor.i32(i32 %r3, i32 2)
  %r4 = add i32 %r3, %s4
  
  ; XOR with 1
  %s5 = call i32 @llvm.custom.shuffle.xor.i32(i32 %r4, i32 1)
  %r5 = add i32 %r4, %s5
  
  ret i32 %r5
}
