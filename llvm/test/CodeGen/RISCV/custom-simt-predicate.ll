; RUN: llc -mtriple=riscv32 -mattr=+xcustomsimt,+f < %s | FileCheck %s

; Test SIMT predicate instructions assembly output

; Test predicate compare and select pattern
; CHECK-LABEL: test_psel:
; CHECK: pcmp.lt p0, a0, a1
; CHECK: psel a0, a2, a3, p0
define i32 @test_psel(i32 %a, i32 %b, i32 %c, i32 %d) {
  %cmp = icmp slt i32 %a, %b
  %sel = select i1 %cmp, i32 %c, i32 %d
  ret i32 %sel
}

; Test floating point predicate select
; CHECK-LABEL: test_psel_f:
; CHECK: pcmp.f.lt p0, fa0, fa1
; CHECK: psel.f fa0, fa2, fa3, p0
define float @test_psel_f(float %a, float %b, float %c, float %d) {
  %cmp = fcmp olt float %a, %b
  %sel = select i1 %cmp, float %c, float %d
  ret float %sel
}

; Test conditional load pattern
; CHECK-LABEL: test_masked_load:
; CHECK: pcmp.lt p0,
; CHECK: plw a0, {{.*}}, p0
define i32 @test_masked_load(ptr %p, i32 %idx, i32 %limit) {
  %cmp = icmp slt i32 %idx, %limit
  br i1 %cmp, label %load, label %zero

load:
  %val = load i32, ptr %p
  br label %exit

zero:
  br label %exit

exit:
  %result = phi i32 [ %val, %load ], [ 0, %zero ]
  ret i32 %result
}

; Test conditional store pattern
; CHECK-LABEL: test_masked_store:
; CHECK: pcmp.lt p0,
; CHECK: psw {{.*}}, p0
define void @test_masked_store(ptr %p, i32 %idx, i32 %limit, i32 %val) {
  %cmp = icmp slt i32 %idx, %limit
  br i1 %cmp, label %store, label %exit

store:
  store i32 %val, ptr %p
  br label %exit

exit:
  ret void
}

; Test predicate logic operations
; CHECK-LABEL: test_predicate_and:
; CHECK: pcmp.lt p{{[0-7]}},
; CHECK: pcmp.lt p{{[0-7]}},
; CHECK: pand p{{[0-7]}}, p{{[0-7]}}, p{{[0-7]}}
define i1 @test_predicate_and(i32 %a, i32 %b, i32 %c, i32 %d) {
  %cmp1 = icmp slt i32 %a, %b
  %cmp2 = icmp slt i32 %c, %d
  %and = and i1 %cmp1, %cmp2
  ret i1 %and
}

; CHECK-LABEL: test_predicate_or:
; CHECK: pcmp.lt p{{[0-7]}},
; CHECK: pcmp.lt p{{[0-7]}},
; CHECK: por p{{[0-7]}}, p{{[0-7]}}, p{{[0-7]}}
define i1 @test_predicate_or(i32 %a, i32 %b, i32 %c, i32 %d) {
  %cmp1 = icmp slt i32 %a, %b
  %cmp2 = icmp slt i32 %c, %d
  %or = or i1 %cmp1, %cmp2
  ret i1 %or
}

; CHECK-LABEL: test_predicate_not:
; CHECK: pcmp.lt p{{[0-7]}},
; CHECK: pnot p{{[0-7]}}, p{{[0-7]}}
define i1 @test_predicate_not(i32 %a, i32 %b) {
  %cmp = icmp slt i32 %a, %b
  %not = xor i1 %cmp, true
  ret i1 %not
}

; Test predicate transfer
; CHECK-LABEL: test_pmov_to_x:
; CHECK: pcmp.lt p{{[0-7]}},
; CHECK: pmov.to.x a0, p{{[0-7]}}
define i32 @test_pmov_to_x(i32 %a, i32 %b) {
  %cmp = icmp slt i32 %a, %b
  %ext = zext i1 %cmp to i32
  ret i32 %ext
}
