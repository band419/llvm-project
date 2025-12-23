; RUN: llc -mtriple=riscv32 -mattr=+xcustomsimt < %s | FileCheck %s

; Test that SIMT ID intrinsics lower to CSR reads

declare i32 @llvm.custom.tid.x()
declare i32 @llvm.custom.tid.y()
declare i32 @llvm.custom.tid.z()
declare i32 @llvm.custom.ctaid.x()
declare i32 @llvm.custom.ctaid.y()
declare i32 @llvm.custom.ctaid.z()
declare i32 @llvm.custom.ntid.x()
declare i32 @llvm.custom.ntid.y()
declare i32 @llvm.custom.ntid.z()
declare i32 @llvm.custom.lane.id()
declare i32 @llvm.custom.warp.size()

; CHECK-LABEL: test_tid_x:
; CHECK: csrr a0, 0xfc0
define i32 @test_tid_x() {
  %tid = call i32 @llvm.custom.tid.x()
  ret i32 %tid
}

; CHECK-LABEL: test_tid_y:
; CHECK: csrr a0, 0xfc4
define i32 @test_tid_y() {
  %tid = call i32 @llvm.custom.tid.y()
  ret i32 %tid
}

; CHECK-LABEL: test_tid_z:
; CHECK: csrr a0, 0xfc8
define i32 @test_tid_z() {
  %tid = call i32 @llvm.custom.tid.z()
  ret i32 %tid
}

; CHECK-LABEL: test_ctaid_x:
; CHECK: csrr a0, 0xfd8
define i32 @test_ctaid_x() {
  %ctaid = call i32 @llvm.custom.ctaid.x()
  ret i32 %ctaid
}

; CHECK-LABEL: test_ctaid_y:
; CHECK: csrr a0, 0xfdc
define i32 @test_ctaid_y() {
  %ctaid = call i32 @llvm.custom.ctaid.y()
  ret i32 %ctaid
}

; CHECK-LABEL: test_ctaid_z:
; CHECK: csrr a0, 0xfe0
define i32 @test_ctaid_z() {
  %ctaid = call i32 @llvm.custom.ctaid.z()
  ret i32 %ctaid
}

; CHECK-LABEL: test_ntid_x:
; CHECK: csrr a0, 0xfcc
define i32 @test_ntid_x() {
  %ntid = call i32 @llvm.custom.ntid.x()
  ret i32 %ntid
}

; CHECK-LABEL: test_ntid_y:
; CHECK: csrr a0, 0xfd0
define i32 @test_ntid_y() {
  %ntid = call i32 @llvm.custom.ntid.y()
  ret i32 %ntid
}

; CHECK-LABEL: test_ntid_z:
; CHECK: csrr a0, 0xfd4
define i32 @test_ntid_z() {
  %ntid = call i32 @llvm.custom.ntid.z()
  ret i32 %ntid
}

; CHECK-LABEL: test_lane_id:
; CHECK: csrr a0, 0xfe4
define i32 @test_lane_id() {
  %laneid = call i32 @llvm.custom.lane.id()
  ret i32 %laneid
}

; CHECK-LABEL: test_warp_size:
; CHECK: csrr a0, 0xfe8
define i32 @test_warp_size() {
  %warpsize = call i32 @llvm.custom.warp.size()
  ret i32 %warpsize
}

; Combined test: compute global thread ID
; globalId = ctaid * ntid + tid
; CHECK-LABEL: test_global_id:
; CHECK: csrr {{.*}}, 0xfd8
; CHECK: csrr {{.*}}, 0xfcc
; CHECK: mul
; CHECK: csrr {{.*}}, 0xfc0
; CHECK: add
define i32 @test_global_id() {
  %ctaid = call i32 @llvm.custom.ctaid.x()
  %ntid = call i32 @llvm.custom.ntid.x()
  %tid = call i32 @llvm.custom.tid.x()
  %tmp = mul i32 %ctaid, %ntid
  %gid = add i32 %tmp, %tid
  ret i32 %gid
}
