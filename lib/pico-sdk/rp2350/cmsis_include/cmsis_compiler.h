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

/*  CMSIS Compiler abstraction layer */
#ifndef __CMSIS_COMPILER_H
#define __CMSIS_COMPILER_H

#include <stdint.h>

/*
 * Arm Compiler 4/5
 */
#if defined(__CC_ARM)
  #include "cmsis_armcc.h"

/*
 * Arm Compiler 6 (armclang)
 */
#elif defined(__ARMCC_VERSION) && (__ARMCC_VERSION >= 6010050)
  #include "cmsis_armclang.h"

/*
 * GNU Compiler
 */
#elif defined(__GNUC__)
  #include "cmsis_gcc.h"

/*
 * IAR Compiler
 */
#elif defined(__ICCARM__)
  #include "cmsis_iccarm.h"

/*
 * TI Arm Compiler
 */
#elif defined(__TI_ARM__)
  #include "cmsis_ccs.h"

/*
 * TASKING Compiler
 */
#elif defined(__TASKING__)
  #include "cmsis_tasking.h"

/*
 * Unknown compiler
 */
#else
  #error Unsupported compiler.
#endif

#endif /* __CMSIS_COMPILER_H */
