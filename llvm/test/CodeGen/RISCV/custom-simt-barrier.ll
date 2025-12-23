; RUN: llc -mtriple=riscv32 -mattr=+xcustomsimt < %s | FileCheck %s

; Test that SIMT barrier intrinsic lowers to fence + bar.sync

declare void @llvm.custom.barrier()

; CHECK-LABEL: test_barrier:
; CHECK: fence rw, rw
; CHECK: bar.sync
define void @test_barrier() {
  call void @llvm.custom.barrier()
  ret void
}

; Test that barrier is not reordered with loads/stores
; CHECK-LABEL: test_barrier_ordering:
; CHECK: sw {{.*}}
; CHECK: fence rw, rw
; CHECK: bar.sync
; CHECK: lw {{.*}}
define i32 @test_barrier_ordering(ptr %p, i32 %val) {
  store i32 %val, ptr %p
  call void @llvm.custom.barrier()
  %loaded = load i32, ptr %p
  ret i32 %loaded
}

; Test multiple barriers
; CHECK-LABEL: test_double_barrier:
; CHECK: fence rw, rw
; CHECK: bar.sync
; CHECK: fence rw, rw
; CHECK: bar.sync
define void @test_double_barrier() {
  call void @llvm.custom.barrier()
  call void @llvm.custom.barrier()
  ret void
}
