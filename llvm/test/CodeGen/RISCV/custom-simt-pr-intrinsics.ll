; RUN: llc -mtriple=riscv32 -mattr=+xcustomsimt,+f < %s -o - | FileCheck %s

; Test SIMT predicate intrinsics with PR register class

declare i1 @llvm.custom.pand(i1, i1)
declare i1 @llvm.custom.por(i1, i1)
declare i1 @llvm.custom.pxor(i1, i1)
declare i1 @llvm.custom.pnot(i1)
declare i32 @llvm.custom.pmov.to.x(i1)
declare i1 @llvm.custom.pmov.from.x(i32)
declare i32 @llvm.custom.psel.i32(i32, i32, i1)

; Test pand intrinsic
; CHECK-LABEL: test_pand:
; CHECK: pand
define i1 @test_pand(i1 %a, i1 %b) {
  %result = call i1 @llvm.custom.pand(i1 %a, i1 %b)
  ret i1 %result
}

; Test por intrinsic  
; CHECK-LABEL: test_por:
; CHECK: por
define i1 @test_por(i1 %a, i1 %b) {
  %result = call i1 @llvm.custom.por(i1 %a, i1 %b)
  ret i1 %result
}

; Test pxor intrinsic
; CHECK-LABEL: test_pxor:
; CHECK: pxor
define i1 @test_pxor(i1 %a, i1 %b) {
  %result = call i1 @llvm.custom.pxor(i1 %a, i1 %b)
  ret i1 %result
}

; Test pnot intrinsic
; CHECK-LABEL: test_pnot:
; CHECK: pnot
define i1 @test_pnot(i1 %a) {
  %result = call i1 @llvm.custom.pnot(i1 %a)
  ret i1 %result
}

; Test pmov.to.x - PR to GPR
; CHECK-LABEL: test_pmov_to_x:
; CHECK: pmov.to.x
define i32 @test_pmov_to_x(i1 %pred) {
  %result = call i32 @llvm.custom.pmov.to.x(i1 %pred)
  ret i32 %result
}

; Test pmov.from.x - GPR to PR
; CHECK-LABEL: test_pmov_from_x:
; CHECK: pmov.from.x
define i1 @test_pmov_from_x(i32 %val) {
  %result = call i1 @llvm.custom.pmov.from.x(i32 %val)
  ret i1 %result
}

; Test psel with i1 condition
; CHECK-LABEL: test_psel_i32:
; CHECK: psel
define i32 @test_psel_i32(i32 %t, i32 %f, i1 %cond) {
  %result = call i32 @llvm.custom.psel.i32(i32 %t, i32 %f, i1 %cond)
  ret i32 %result
}
