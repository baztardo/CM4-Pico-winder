/*
 * Copyright (c) 2009-2021 ARM Limited. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the License); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an AS IS BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*  CMSIS Cortex-M GCC compiler specific definitions */
#ifndef __CMSIS_GCC_M_H
#define __CMSIS_GCC_M_H

/* ###########################  Core Function Access  ########################### */

/** \brief  Enable IRQ Interrupts

    This function enables IRQ interrupts by clearing the I-bit in the CPSR.
    Can only be executed in Privileged modes.
 */
__attribute__((always_inline)) __STATIC_INLINE void __enable_irq(void)
{
  __ASM volatile ("cpsie i" : : : "memory");
}

/** \brief  Disable IRQ Interrupts

    This function disables IRQ interrupts by setting the I-bit in the CPSR.
    Can only be executed in Privileged modes.
 */
__attribute__((always_inline)) __STATIC_INLINE void __disable_irq(void)
{
  __ASM volatile ("cpsid i" : : : "memory");
}

/** \brief  Enable FIQ

    This function enables FIQ interrupts by clearing the F-bit in the CPSR.
    Can only be executed in Privileged modes.
 */
__attribute__((always_inline)) __STATIC_INLINE void __enable_fiq(void)
{
  __ASM volatile ("cpsie f" : : : "memory");
}

/** \brief  Disable FIQ

    This function disables FIQ interrupts by setting the F-bit in the CPSR.
    Can only be executed in Privileged modes.
 */
__attribute__((always_inline)) __STATIC_INLINE void __disable_fiq(void)
{
  __ASM volatile ("cpsid f" : : : "memory");
}

/** \brief  Get FPSCR

    This function returns the current value of the Floating Point Status/Control register.

    \return               Floating Point Status/Control register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_FPSCR(void)
{
#if ((defined (__FPU_PRESENT) && (__FPU_PRESENT == 1U)) && \
     (defined (__FPU_USED   ) && (__FPU_USED    == 1U))     )
  uint32_t result;

  __ASM volatile ("VMRS %0, fpscr" : "=r" (result) );
  return(result);
#else
  return(0U);
#endif
}

/** \brief  Set FPSCR

    This function assigns the given value to the Floating Point Status/Control register.

    \param [in]    fpscr  Floating Point Status/Control register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_FPSCR(uint32_t fpscr)
{
#if ((defined (__FPU_PRESENT) && (__FPU_PRESENT == 1U)) && \
     (defined (__FPU_USED   ) && (__FPU_USED    == 1U))     )
  __ASM volatile ("VMSR fpscr, %0" : : "r" (fpscr) : "vfpcc", "memory");
#endif
}

/** \brief  Get CPSR Register

    This function returns the content of the CPSR Register.

    \return               CPSR Register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_CPSR(void)
{
  uint32_t result;

  __ASM volatile ("MRS %0, cpsr" : "=r" (result) );
  return(result);
}

/** \brief  Set CPSR Register

    This function writes the given value to the CPSR Register.

    \param [in]    cpsr  CPSR Register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_CPSR(uint32_t cpsr)
{
  __ASM volatile ("MSR cpsr, %0" : : "r" (cpsr) : "cc", "memory");
}

/** \brief  Get Mode

    This function returns the current operating mode.

    \return               Mode value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_mode(void)
{
  return (__get_CPSR() & 0x1FU);
}

/** \brief  Set Mode

    This function writes the given value to the Mode bits in CPSR.

    \param [in]    mode  Mode value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_mode(uint32_t mode)
{
  __ASM volatile ("MSR cpsr_c, %0" : : "r" (mode) : "memory");
}

/** \brief  Get Stack Pointer

    This function returns the current value of the Stack Pointer.

    \return               Stack Pointer value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_SP(void)
{
  uint32_t result;

  __ASM volatile ("MOV %0, sp" : "=r" (result) );
  return(result);
}

/** \brief  Set Stack Pointer

    This function assigns the given value to the Stack Pointer.

    \param [in]    stack  Stack Pointer value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_SP(uint32_t stack)
{
  __ASM volatile ("MOV sp, %0" : : "r" (stack) : "memory");
}

/** \brief  Get USR/SYS Stack Pointer

    This function returns the current value of the USR/SYS Stack Pointer.

    \return               USR/SYS Stack Pointer value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_SP_usr(void)
{
  uint32_t cpsr = __get_CPSR();
  uint32_t result;

  __set_mode(0x1FU);
  __ASM volatile ("MOV %0, sp" : "=r" (result) );
  __set_CPSR(cpsr);

  return(result);
}

/** \brief  Set USR/SYS Stack Pointer

    This function assigns the given value to the USR/SYS Stack Pointer.

    \param [in]    topOfProcStack  USR/SYS Stack Pointer value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_SP_usr(uint32_t topOfProcStack)
{
  uint32_t cpsr = __get_CPSR();

  __set_mode(0x1FU);
  __ASM volatile ("MOV sp, %0" : : "r" (topOfProcStack) : "memory");
  __set_CPSR(cpsr);
}

/** \brief  Get FPEXC

    This function returns the current value of the Floating Point Exception Control register.

    \return               Floating Point Exception Control register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_FPEXC(void)
{
#if (__FPU_PRESENT == 1)
  uint32_t result;

  __ASM volatile ("VMRS %0, fpexc" : "=r" (result) );
  return(result);
#else
  return(0U);
#endif
}

/** \brief  Set FPEXC

    This function assigns the given value to the Floating Point Exception Control register.

    \param [in]    fpexc  Floating Point Exception Control register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_FPEXC(uint32_t fpexc)
{
#if (__FPU_PRESENT == 1)
  __ASM volatile ("VMSR fpexc, %0" : : "r" (fpexc) : "memory");
#endif
}

/** \brief  Get ACTLR

    This function returns the current value of the Auxiliary Control register.

    \return               Auxiliary Control register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_ACTLR(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c1, c0, 1" : "=r" (result) );
  return(result);
}

/** \brief  Set ACTLR

    This function assigns the given value to the Auxiliary Control register.

    \param [in]    actlr  Auxiliary Control register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_ACTLR(uint32_t actlr)
{
  __ASM volatile ("MCR p15, 0, %0, c1, c0, 1" : : "r" (actlr) : "memory");
}

/** \brief  Get CPACR

    This function returns the current value of the Coprocessor Access Control register.

    \return               Coprocessor Access Control register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_CPACR(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c1, c0, 2" : "=r" (result) );
  return(result);
}

/** \brief  Set CPACR

    This function assigns the given value to the Coprocessor Access Control register.

    \param [in]    cpacr  Coprocessor Access Control register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_CPACR(uint32_t cpacr)
{
  __ASM volatile ("MCR p15, 0, %0, c1, c0, 2" : : "r" (cpacr) : "memory");
}

/** \brief  Get DFSR

    This function returns the current value of the Data Fault Status Register.

    \return               Data Fault Status Register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_DFSR(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c5, c0, 0" : "=r" (result) );
  return(result);
}

/** \brief  Set DFSR

    This function assigns the given value to the Data Fault Status Register.

    \param [in]    dfsr  Data Fault Status Register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_DFSR(uint32_t dfsr)
{
  __ASM volatile ("MCR p15, 0, %0, c5, c0, 0" : : "r" (dfsr) : "memory");
}

/** \brief  Get IFSR

    This function returns the current value of the Instruction Fault Status Register.

    \return               Instruction Fault Status Register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_IFSR(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c5, c0, 1" : "=r" (result) );
  return(result);
}

/** \brief  Set IFSR

    This function assigns the given value to the Instruction Fault Status Register.

    \param [in]    ifsr  Instruction Fault Status Register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_IFSR(uint32_t ifsr)
{
  __ASM volatile ("MCR p15, 0, %0, c5, c0, 1" : : "r" (ifsr) : "memory");
}

/** \brief  Get ISR

    This function returns the current value of the Interrupt Status Register.

    \return               Interrupt Status Register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_ISR(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c12, c1, 0" : "=r" (result) );
  return(result);
}

/** \brief  Set ISR

    This function assigns the given value to the Interrupt Status Register.

    \param [in]    isr  Interrupt Status Register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_ISR(uint32_t isr)
{
  __ASM volatile ("MCR p15, 0, %0, c12, c1, 0" : : "r" (isr) : "memory");
}

/** \brief  Get CBAR

    This function returns the current value of the Configuration Base Address register.

    \return               Configuration Base Address register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_CBAR(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 4, %0, c15, c0, 0" : "=r" (result) );
  return(result);
}

/** \brief  Set CBAR

    This function assigns the given value to the Configuration Base Address register.

    \param [in]    cbar  Configuration Base Address register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_CBAR(uint32_t cbar)
{
  __ASM volatile ("MCR p15, 4, %0, c15, c0, 0" : : "r" (cbar) : "memory");
}

/** \brief  Get TTBR0

    This function returns the current value of the Translation Table Base Register 0.

    \return               Translation Table Base Register 0 value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_TTBR0(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c2, c0, 0" : "=r" (result) );
  return(result);
}

/** \brief  Set TTBR0

    This function assigns the given value to the Translation Table Base Register 0.

    \param [in]    ttbr0  Translation Table Base Register 0 value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_TTBR0(uint32_t ttbr0)
{
  __ASM volatile ("MCR p15, 0, %0, c2, c0, 0" : : "r" (ttbr0) : "memory");
}

/** \brief  Get DACR

    This function returns the current value of the Domain Access Control Register.

    \return               Domain Access Control Register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_DACR(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c3, c0, 0" : "=r" (result) );
  return(result);
}

/** \brief  Set DACR

    This function assigns the given value to the Domain Access Control Register.

    \param [in]    dacr  Domain Access Control Register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_DACR(uint32_t dacr)
{
  __ASM volatile ("MCR p15, 0, %0, c3, c0, 0" : : "r" (dacr) : "memory");
}

/** \brief  Set SCTLR

    This function assigns the given value to the System Control Register.

    \param [in]    sctlr  System Control Register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_SCTLR(uint32_t sctlr)
{
  __ASM volatile ("MCR p15, 0, %0, c1, c0, 0" : : "r" (sctlr) : "memory");
}

/** \brief  Get SCTLR

    This function returns the current value of the System Control Register.

    \return               System Control Register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_SCTLR(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c1, c0, 0" : "=r" (result) );
  return(result);
}

/** \brief  Set ACTRL

    This function assigns the given value to the Auxiliary Control Register.

    \param [in]    actrl  Auxiliary Control Register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_ACTRL(uint32_t actrl)
{
  __ASM volatile ("MCR p15, 0, %0, c1, c0, 1" : : "r" (actrl) : "memory");
}

/** \brief  Get ACTRL

    This function returns the current value of the Auxiliary Control Register.

    \return               Auxiliary Control Register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_ACTRL(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c1, c0, 1" : "=r" (result) );
  return(result);
}

/** \brief  Set VBAR

    This function assigns the given value to the Vector Base Address Register.

    \param [in]    vbar  Vector Base Address Register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_VBAR(uint32_t vbar)
{
  __ASM volatile ("MCR p15, 0, %0, c12, c0, 0" : : "r" (vbar) : "memory");
}

/** \brief  Get VBAR

    This function returns the current value of the Vector Base Address Register.

    \return               Vector Base Address Register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_VBAR(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c12, c0, 0" : "=r" (result) );
  return(result);
}

/** \brief  Set MVBAR

    This function assigns the given value to the Monitor Vector Base Address Register.

    \param [in]    mvbar  Monitor Vector Base Address Register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_MVBAR(uint32_t mvbar)
{
  __ASM volatile ("MCR p15, 0, %0, c12, c0, 1" : : "r" (mvbar) : "memory");
}

/** \brief  Get MVBAR

    This function returns the current value of the Monitor Vector Base Address Register.

    \return               Monitor Vector Base Address Register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_MVBAR(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c12, c0, 1" : "=r" (result) );
  return(result);
}

/** \brief  Get ITM Base Address

    This function returns the current value of the ITM Base Address register.

    \return               ITM Base Address register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_ITM_BASE(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c14, c1, 0" : "=r" (result) );
  return(result);
}

/** \brief  Set ITM Base Address

    This function assigns the given value to the ITM Base Address register.

    \param [in]    itm_base  ITM Base Address register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_ITM_BASE(uint32_t itm_base)
{
  __ASM volatile ("MCR p15, 0, %0, c14, c1, 0" : : "r" (itm_base) : "memory");
}

/** \brief  Get IID

    This function returns the current value of the Interface Identification register.

    \return               Interface Identification register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_IID(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c0, c0, 0" : "=r" (result) );
  return(result);
}

/** \brief  Get CPU ID

    This function returns the current value of the CPU ID register.

    \return               CPU ID register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_CID(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c0, c0, 0" : "=r" (result) );
  return(result);
}

/** \brief  Save Context

    This function saves the current context.

    \param [in]    ctx  Context to save
 */
__attribute__((always_inline)) __STATIC_INLINE void __save_context(uint32_t ctx)
{
  __ASM volatile ("STMDB sp!, {%0}" : : "r" (ctx) : "memory");
}

/** \brief  Restore Context

    This function restores the current context.

    \param [out]   ctx  Context to restore
 */
__attribute__((always_inline)) __STATIC_INLINE void __restore_context(uint32_t ctx)
{
  __ASM volatile ("LDMIA sp!, {%0}" : "=r" (ctx) : : "memory");
}

/** \brief  Get CONTROL Register

    This function returns the current value of the CONTROL register.

    \return               CONTROL register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_CONTROL(void)
{
  uint32_t result;

  __ASM volatile ("MRC p15, 0, %0, c1, c0, 0" : "=r" (result) );
  return(result);
}

/** \brief  Set CONTROL Register

    This function assigns the given value to the CONTROL register.

    \param [in]    control  CONTROL register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_CONTROL(uint32_t control)
{
  __ASM volatile ("MCR p15, 0, %0, c1, c0, 0" : : "r" (control) : "memory");
}

/** \brief  Get IPSR Register

    This function returns the current value of the IPSR register.

    \return               IPSR register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_IPSR(void)
{
  uint32_t result;

  __ASM volatile ("MRS %0, ipsr" : "=r" (result) );
  return(result);
}

/** \brief  Get APSR Register

    This function returns the current value of the APSR register.

    \return               APSR register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_APSR(void)
{
  uint32_t result;

  __ASM volatile ("MRS %0, apsr" : "=r" (result) );
  return(result);
}

/** \brief  Get xPSR Register

    This function returns the current value of the xPSR register.

    \return               xPSR register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_xPSR(void)
{
  uint32_t result;

  __ASM volatile ("MRS %0, xpsr" : "=r" (result) );
  return(result);
}

/** \brief  Get Process Stack Pointer

    This function returns the current value of the Process Stack Pointer (PSP).

    \return               PSP register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_PSP(void)
{
  uint32_t result;

  __ASM volatile ("MRS %0, psp" : "=r" (result) );
  return(result);
}

/** \brief  Set Process Stack Pointer

    This function assigns the given value to the Process Stack Pointer (PSP).

    \param [in]    topOfProcStack  Process Stack Pointer value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_PSP(uint32_t topOfProcStack)
{
  __ASM volatile ("MSR psp, %0" : : "r" (topOfProcStack) : "memory");
}

/** \brief  Get Main Stack Pointer

    This function returns the current value of the Main Stack Pointer (MSP).

    \return               MSP register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_MSP(void)
{
  uint32_t result;

  __ASM volatile ("MRS %0, msp" : "=r" (result) );
  return(result);
}

/** \brief  Set Main Stack Pointer

    This function assigns the given value to the Main Stack Pointer (MSP).

    \param [in]    topOfMainStack  Main Stack Pointer value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_MSP(uint32_t topOfMainStack)
{
  __ASM volatile ("MSR msp, %0" : : "r" (topOfMainStack) : "memory");
}

/** \brief  Get Priority Mask

    This function returns the current value of the Priority Mask register.

    \return               Priority Mask register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_PRIMASK(void)
{
  uint32_t result;

  __ASM volatile ("MRS %0, primask" : "=r" (result) );
  return(result);
}

/** \brief  Set Priority Mask

    This function assigns the given value to the Priority Mask register.

    \param [in]    priMask  Priority Mask value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_PRIMASK(uint32_t priMask)
{
  __ASM volatile ("MSR primask, %0" : : "r" (priMask) : "memory");
}

/** \brief  Get Base Priority

    This function returns the current value of the Base Priority register.

    \return               Base Priority register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_BASEPRI(void)
{
  uint32_t result;

  __ASM volatile ("MRS %0, basepri" : "=r" (result) );
  return(result);
}

/** \brief  Set Base Priority

    This function assigns the given value to the Base Priority register.

    \param [in]    basePri  Base Priority value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_BASEPRI(uint32_t basePri)
{
  __ASM volatile ("MSR basepri, %0" : : "r" (basePri) : "memory");
}

/** \brief  Get Fault Mask

    This function returns the current value of the Fault Mask register.

    \return               Fault Mask register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_FAULTMASK(void)
{
  uint32_t result;

  __ASM volatile ("MRS %0, faultmask" : "=r" (result) );
  return(result);
}

/** \brief  Set Fault Mask

    This function assigns the given value to the Fault Mask register.

    \param [in]    faultMask  Fault Mask value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_FAULTMASK(uint32_t faultMask)
{
  __ASM volatile ("MSR faultmask, %0" : : "r" (faultMask) : "memory");
}

/** \brief  Get FPSCR

    This function returns the current value of the Floating Point Status/Control register.

    \return               Floating Point Status/Control register value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_FPSCR(void)
{
#if ((defined (__FPU_PRESENT) && (__FPU_PRESENT == 1U)) && \
     (defined (__FPU_USED   ) && (__FPU_USED    == 1U))     )
  uint32_t result;

  __ASM volatile ("VMRS %0, fpscr" : "=r" (result) );
  return(result);
#else
  return(0U);
#endif
}

/** \brief  Set FPSCR

    This function assigns the given value to the Floating Point Status/Control register.

    \param [in]    fpscr  Floating Point Status/Control register value to set
 */
__attribute__((always_inline)) __STATIC_INLINE void __set_FPSCR(uint32_t fpscr)
{
#if ((defined (__FPU_PRESENT) && (__FPU_PRESENT == 1U)) && \
     (defined (__FPU_USED   ) && (__FPU_USED    == 1U))     )
  __ASM volatile ("VMSR fpscr, %0" : : "r" (fpscr) : "vfpcc", "memory");
#endif
}

/** \brief  Get SVC Number

    This function returns the current value of the SVC number.

    \return               SVC number value
 */
__attribute__((always_inline)) __STATIC_INLINE uint32_t __get_SVC(void)
{
  uint32_t result;

  __ASM volatile ("MRS %0, ipsr" : "=r" (result) );
  return(result);
}

#endif /* __CMSIS_GCC_M_H */
