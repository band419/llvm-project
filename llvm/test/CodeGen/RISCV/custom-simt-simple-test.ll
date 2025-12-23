; Simple test for custom SIMT backend
; RUN: llc -mtriple=riscv32 -mattr=+xcustomsimt < %s | FileCheck %s

; Declare intrinsics
declare i32 @llvm.custom.tid.x()
declare i32 @llvm.custom.ctaid.x()
declare i32 @llvm.custom.ntid.x()
declare void @llvm.custom.barrier()

; A simple vector add kernel pattern
; CHECK-LABEL: simple_add_kernel:
; CHECK: csrr {{a[0-9]+}}, 0xfc0
; CHECK: csrr {{a[0-9]+}}, 0xfd8
; CHECK: csrr {{a[0-9]+}}, 0xfcc
define void @simple_add_kernel(ptr %a, ptr %b, ptr %c, i32 %n) #0 {
entry:
  ; Get thread ID
  %tid = call i32 @llvm.custom.tid.x()
  ; Get block ID
  %ctaid = call i32 @llvm.custom.ctaid.x()
  ; Get block size
  %ntid = call i32 @llvm.custom.ntid.x()
  
  ; Compute global index: gid = ctaid * ntid + tid
  %tmp = mul i32 %ctaid, %ntid
  %gid = add i32 %tmp, %tid
  
  ; Bounds check
  %inbounds = icmp ult i32 %gid, %n
  br i1 %inbounds, label %body, label %exit

body:
  ; Load a[gid]
  %aptr = getelementptr float, ptr %a, i32 %gid
  %aval = load float, ptr %aptr
  
  ; Load b[gid]
  %bptr = getelementptr float, ptr %b, i32 %gid
  %bval = load float, ptr %bptr
  
  ; c[gid] = a[gid] + b[gid]
  %cval = fadd float %aval, %bval
  %cptr = getelementptr float, ptr %c, i32 %gid
  store float %cval, ptr %cptr
  
  br label %exit

exit:
  ret void
}

; Test barrier lowering
; CHECK-LABEL: test_barrier:
; CHECK: fence rw, rw
define void @test_barrier() {
  call void @llvm.custom.barrier()
  ret void
}

attributes #0 = { "kernel" }
