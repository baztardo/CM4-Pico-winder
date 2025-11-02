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

/*  CMSIS Version definitions */
#ifndef __CMSIS_VERSION_H
#define __CMSIS_VERSION_H

#define __CM_CMSIS_VERSION_MAIN  ( 5U)                                      /*!< [31:16] CMSIS HAL main version */
#define __CM_CMSIS_VERSION_SUB   ( 4U)                                      /*!< [15:0]  CMSIS HAL sub version */
#define __CM_CMSIS_VERSION       ((__CM_CMSIS_VERSION_MAIN << 16U) | \
                                   __CM_CMSIS_VERSION_SUB           )       /*!< CMSIS HAL version number */

#endif
