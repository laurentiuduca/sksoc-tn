/****************************************************************************
 * arch/risc-v/src/qemu-rv/qemu_rv_head.S
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.  The
 * ASF licenses this file to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 ****************************************************************************/

/****************************************************************************
 * Included Files
 ****************************************************************************/

#include <nuttx/config.h>

#include <arch/arch.h>
#include <arch/irq.h>

#include "chip.h"
#include "riscv_internal.h"
#include "riscv_macros.S"

/****************************************************************************
 * Public Symbols
 ****************************************************************************/

  /* Exported Symbols */
.section ".tohost","aw",@progbits
.align 4
.globl tohost
tohost: .dword 0
.align 4
.globl fromhost
fromhost: .dword 0

  .section .text
  .global __start

__start:

  # show '1' at console
  nop
  lui     t3,0x40004
  li      t4,0x31
  sw      t4,0xc(t3)

  # laur
  # have each core add 0x31 to tohost
  la a1, tohost
  sw x0, (a1)
  //li a3, 0
  
  1: lr.w a4, (a1)
  addi a4, a4, 0x31
  //2: addi a3, a3, 10
  //ble a3, t4, 2b
  sc.w a4, a4, (a1)
  bnez a4, 1b
 
  //fence 
  lw t2, (a1)
  sw t2, 0xc(t3)
  label1:j label1

  //1: j 1b

  /* Preserve a1 as it contains the pointer to DTB */
  /* Load mhartid (cpuid) */

#ifndef CONFIG_ARCH_USE_S_MODE
  csrr a0, CSR_MHARTID
#endif

  /* Load the number of CPUs that the kernel supports */
  li   t1, CONFIG_SMP_NCPUS

  /* If a0 (mhartid) >= t1 (the number of CPUs), stop here */

  blt  a0, t1, 2f
  csrw CSR_IE, zero
  wfi

2:
  /* Set stack pointer to the idle thread stack */
  riscv_set_inital_sp QEMU_RV_IDLESTACK_BASE, SMP_STACK_SIZE, a0

  /* Disable all interrupts (i.e. timer, external) in mie */

  csrw CSR_IE, zero

  la   t0, __trap_vec
  csrw CSR_TVEC, t0

  /* Jump to qemu_rv_start */

  jal  x1, qemu_rv_start

  /* We shouldn't return from _start */

  .global _init
  .global _fini

_init:
_fini:

  /* These don't have to do anything since we use init_array/fini_array. */

  ret
