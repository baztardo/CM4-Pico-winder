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

/*  ARMv8-M MPU definitions */
#ifndef __ARMV8M_MPU_H
#define __ARMV8M_MPU_H

/* MPU Type Register */
#define MPU_TYPE_RASR_Pos               0U                                            /*!< MPU TYPE: RASR Position */
#define MPU_TYPE_RASR_Msk              (0xFFUL /*<< MPU_TYPE_RASR_Pos*/)             /*!< MPU TYPE: RASR Mask */

#define MPU_TYPE_DREGION_Pos            8U                                            /*!< MPU TYPE: DREGION Position */
#define MPU_TYPE_DREGION_Msk           (0xFFUL << MPU_TYPE_DREGION_Pos)              /*!< MPU TYPE: DREGION Mask */

#define MPU_TYPE_SEPARATED_Pos         0U                                             /*!< MPU TYPE: SEPARATED Position */
#define MPU_TYPE_SEPARATED_Msk        (1UL /*<< MPU_TYPE_SEPARATED_Pos*/)            /*!< MPU TYPE: SEPARATED Mask */

/* MPU Control Register */
#define MPU_CTRL_ENABLE_Pos             0U                                            /*!< MPU CTRL: ENABLE Position */
#define MPU_CTRL_ENABLE_Msk            (1UL /*<< MPU_CTRL_ENABLE_Pos*/)               /*!< MPU CTRL: ENABLE Mask */

#define MPU_CTRL_HFNMIENA_Pos           1U                                            /*!< MPU CTRL: HFNMIENA Position */
#define MPU_CTRL_HFNMIENA_Msk          (1UL << MPU_CTRL_HFNMIENA_Pos)                 /*!< MPU CTRL: HFNMIENA Mask */

#define MPU_CTRL_PRIVDEFENA_Pos         2U                                            /*!< MPU CTRL: PRIVDEFENA Position */
#define MPU_CTRL_PRIVDEFENA_Msk        (1UL << MPU_CTRL_PRIVDEFENA_Pos)               /*!< MPU CTRL: PRIVDEFENA Mask */

/* MPU Region Number Register */
#define MPU_RNR_REGION_Pos              0U                                            /*!< MPU RNR: REGION Position */
#define MPU_RNR_REGION_Msk             (0xFFUL /*<< MPU_RNR_REGION_Pos*/)             /*!< MPU RNR: REGION Mask */

/* MPU Region Base Address Register */
#define MPU_RBAR_BASE_Pos               5U                                            /*!< MPU RBAR: BASE Position */
#define MPU_RBAR_BASE_Msk              (0x7FFFFFFUL << MPU_RBAR_BASE_Pos)             /*!< MPU RBAR: BASE Mask */

#define MPU_RBAR_SH_Pos                3U                                             /*!< MPU RBAR: SH Position */
#define MPU_RBAR_SH_Msk               (0x3UL << MPU_RBAR_SH_Pos)                      /*!< MPU RBAR: SH Mask */

#define MPU_RBAR_AP_Pos                1U                                             /*!< MPU RBAR: AP Position */
#define MPU_RBAR_AP_Msk               (0x3UL << MPU_RBAR_AP_Pos)                      /*!< MPU RBAR: AP Mask */

#define MPU_RBAR_XN_Pos                0U                                             /*!< MPU RBAR: XN Position */
#define MPU_RBAR_XN_Msk               (1UL /*<< MPU_RBAR_XN_Pos*/)                    /*!< MPU RBAR: XN Mask */

/* MPU Region Limit Address Register */
#define MPU_RLAR_LIMIT_Pos              5U                                            /*!< MPU RLAR: LIMIT Position */
#define MPU_RLAR_LIMIT_Msk             (0x7FFFFFFUL << MPU_RLAR_LIMIT_Pos)            /*!< MPU RLAR: LIMIT Mask */

#define MPU_RLAR_AttrIndx_Pos          1U                                             /*!< MPU RLAR: AttrIndx Position */
#define MPU_RLAR_AttrIndx_Msk         (0x7UL << MPU_RLAR_AttrIndx_Pos)                /*!< MPU RLAR: AttrIndx Mask */

#define MPU_RLAR_EN_Pos                0U                                             /*!< MPU RLAR: EN Position */
#define MPU_RLAR_EN_Msk               (1UL /*<< MPU_RLAR_EN_Pos*/)                    /*!< MPU RLAR: EN Mask */

/* MPU Memory Attribute Indirection Register 0 */
#define MPU_MAIR0_Attr0_Pos             0U                                            /*!< MPU MAIR0: Attr0 Position */
#define MPU_MAIR0_Attr0_Msk            (0xFFUL /*<< MPU_MAIR0_Attr0_Pos*/)            /*!< MPU MAIR0: Attr0 Mask */

#define MPU_MAIR0_Attr1_Pos             8U                                            /*!< MPU MAIR0: Attr1 Position */
#define MPU_MAIR0_Attr1_Msk            (0xFFUL << MPU_MAIR0_Attr1_Pos)                /*!< MPU MAIR0: Attr1 Mask */

#define MPU_MAIR0_Attr2_Pos            16U                                            /*!< MPU MAIR0: Attr2 Position */
#define MPU_MAIR0_Attr2_Msk            (0xFFUL << MPU_MAIR0_Attr2_Pos)                /*!< MPU MAIR0: Attr2 Mask */

#define MPU_MAIR0_Attr3_Pos            24U                                            /*!< MPU MAIR0: Attr3 Position */
#define MPU_MAIR0_Attr3_Msk            (0xFFUL << MPU_MAIR0_Attr3_Pos)                /*!< MPU MAIR0: Attr3 Mask */

/* MPU Memory Attribute Indirection Register 1 */
#define MPU_MAIR1_Attr4_Pos             0U                                            /*!< MPU MAIR1: Attr4 Position */
#define MPU_MAIR1_Attr4_Msk            (0xFFUL /*<< MPU_MAIR1_Attr4_Pos*/)            /*!< MPU MAIR1: Attr4 Mask */

#define MPU_MAIR1_Attr5_Pos             8U                                            /*!< MPU MAIR1: Attr5 Position */
#define MPU_MAIR1_Attr5_Msk            (0xFFUL << MPU_MAIR1_Attr5_Pos)                /*!< MPU MAIR1: Attr5 Mask */

#define MPU_MAIR1_Attr6_Pos            16U                                            /*!< MPU MAIR1: Attr6 Position */
#define MPU_MAIR1_Attr6_Msk            (0xFFUL << MPU_MAIR1_Attr6_Pos)                /*!< MPU MAIR1: Attr6 Mask */

#define MPU_MAIR1_Attr7_Pos            24U                                            /*!< MPU MAIR1: Attr7 Position */
#define MPU_MAIR1_Attr7_Msk            (0xFFUL << MPU_MAIR1_Attr7_Pos)                /*!< MPU MAIR1: Attr7 Mask */

#endif /* __ARMV8M_MPU_H */
