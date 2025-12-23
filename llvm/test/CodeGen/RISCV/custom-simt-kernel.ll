; RUN: llc -mtriple=riscv32 -mattr=+xcustomsimt,+f < %s | FileCheck %s

; Test a complete vector add kernel using SIMT intrinsics
; This mirrors the example from custom-llvm-ir-spec.md

declare i32 @llvm.custom.tid.x()
declare i32 @llvm.custom.ctaid.x()
declare i32 @llvm.custom.ntid.x()
declare void @llvm.custom.barrier()

; CHECK-LABEL: add_kernel:
; Entry: compute global ID
; CHECK: csrr [[TID:.*]], 0xfc0
; CHECK: csrr [[CTAID:.*]], 0xfd8
; CHECK: csrr [[NTID:.*]], 0xfcc
; CHECK: mul [[TMP:.*]], [[CTAID]], [[NTID]]
; CHECK: add [[GID:.*]], [[TMP]], [[TID]]

; Bounds check: if gid >= n, skip
; CHECK: bge

; Load x[gid] and y[gid]
; CHECK: lw
; CHECK: lw

; Add
; CHECK: add

; Store result
; CHECK: sw

define void @add_kernel(ptr %x, ptr %y, ptr %output, i32 %n) #0 {
entry:
    ; Calculate global thread ID
    %tid = call i32 @llvm.custom.tid.x()
    %ctaid = call i32 @llvm.custom.ctaid.x()
    %ntid = call i32 @llvm.custom.ntid.x()
    %tmp = mul i32 %ctaid, %ntid
    %gid = add i32 %tmp, %tid
    
    ; Bounds check
    %cmp = icmp ult i32 %gid, %n
    br i1 %cmp, label %compute, label %exit

compute:
    ; Calculate addresses
    %x_ptr = getelementptr i32, ptr %x, i32 %gid
    %y_ptr = getelementptr i32, ptr %y, i32 %gid
    %out_ptr = getelementptr i32, ptr %output, i32 %gid
    
    ; Load values
    %x_val = load i32, ptr %x_ptr, align 4
    %y_val = load i32, ptr %y_ptr, align 4
    
    ; Compute sum
    %sum = add i32 %x_val, %y_val
    
    ; Store result
    store i32 %sum, ptr %out_ptr, align 4
    br label %exit

exit:
    ret void
}

; CHECK-LABEL: reduce_kernel:
; Test warp-level reduction using shuffles
declare i32 @llvm.custom.shuffle.xor.i32(i32, i32)

define i32 @reduce_kernel(i32 %val) {
entry:
    ; Butterfly reduction pattern
    %s1 = call i32 @llvm.custom.shuffle.xor.i32(i32 %val, i32 16)
    %r1 = add i32 %val, %s1
    
    %s2 = call i32 @llvm.custom.shuffle.xor.i32(i32 %r1, i32 8)
    %r2 = add i32 %r1, %s2
    
    %s3 = call i32 @llvm.custom.shuffle.xor.i32(i32 %r2, i32 4)
    %r3 = add i32 %r2, %s3
    
    %s4 = call i32 @llvm.custom.shuffle.xor.i32(i32 %r3, i32 2)
    %r4 = add i32 %r3, %s4
    
    %s5 = call i32 @llvm.custom.shuffle.xor.i32(i32 %r4, i32 1)
    %r5 = add i32 %r4, %s5
    
    ret i32 %r5
}

; CHECK-LABEL: barrier_kernel:
; Test barrier synchronization
define void @barrier_kernel(ptr %shared, i32 %val) #0 {
entry:
    %tid = call i32 @llvm.custom.tid.x()
    
    ; First phase: write to shared memory
    %write_ptr = getelementptr i32, ptr %shared, i32 %tid
    store i32 %val, ptr %write_ptr, align 4
    
    ; Synchronize
    ; CHECK: fence rw, rw
    ; CHECK: bar.sync
    call void @llvm.custom.barrier()
    
    ; Second phase: read from shared memory
    ; Read from neighbor (tid + 1) % 32
    %neighbor = add i32 %tid, 1
    %neighbor_mod = and i32 %neighbor, 31
    %read_ptr = getelementptr i32, ptr %shared, i32 %neighbor_mod
    %loaded = load i32, ptr %read_ptr, align 4
    
    ; Write result back
    store i32 %loaded, ptr %write_ptr, align 4
    
    ret void
}

attributes #0 = { "kernel" }
