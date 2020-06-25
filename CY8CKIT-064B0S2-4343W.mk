################################################################################
# \file CY8CKIT-064B0S2-4343W.mk
#
# \brief
# Define the CY8CKIT-064B0S2-4343W target.
#
################################################################################
# \copyright
# Copyright 2018-2020 Cypress Semiconductor Corporation
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

ifeq ($(WHICHFILE),true)
$(info Processing $(lastword $(MAKEFILE_LIST)))
endif

# MCU device selection
DEVICE:=CYB0644ABZI-S2D44
# Additional devices on the board
ADDITIONAL_DEVICES:=CYW4343WKUBG
# Default target core to CM4 if not already set
CORE?=CM4
# Define default type of bootloading method [single, dual]
# single -> CM4 only, multi -> CM0 and CM4
SECURE_BOOT_STAGE?=single

ifeq ($(CORE),CM4)
# Additional components supported by the target
COMPONENTS+=BSP_DESIGN_MODUS PSOC6HAL 4343W
#Add secure CM0P image in single stage
ifeq ($(SECURE_BOOT_STAGE), single)
COMPONENTS+=CM0P_SECURE
endif

# Use CyHAL
DEFINES+=CY_USING_HAL

ifeq ($(SECURE_BOOT_STAGE),single)
CY_LINKERSCRIPT_SUFFIX=cm4_dual
CY_SECURE_POLICY_NAME?=policy_single_CM0_CM4
else
CY_LINKERSCRIPT_SUFFIX=cm4
CY_SECURE_POLICY_NAME?=policy_multi_CM0_CM4
endif

else
CY_SECURE_POLICY_NAME?=policy_multi_CM0_CM4
endif

# Python path definition
ifeq ($(OS),Windows_NT)
CY_PYTHON_PATH?=python
else
CY_PYTHON_PATH?=python3
endif

# BSP-specific post-build action
# CySecureTools Image ID for CM4 Applications is 16 in case of multi-stage, 1 for single-stage,
# Image ID for CM0 Applications is always 1
ifeq ($(CORE), CM4)
ifeq ($(SECURE_BOOT_STAGE), single)
CY_BSP_POSTBUILD=cysecuretools --target cyb06xxa --policy ./policy/$(CY_SECURE_POLICY_NAME).json sign-image --hex $(CY_CONFIG_DIR)/$(APPNAME).hex --image-id 1
else
# In the multi-stage case, by default,
# 1) The CM0P Secure hex file is copied from the psoc6cm0p asset into the build folder
# 2) The CM0P hex file is signed according to the policy
# 3) The CM4 hex file is signed according to the policy
# 4) The CM0P and CM4 hex files are merged into a single hex file

CY_BSP_POSTBUILD=$(CY_PYTHON_PATH) -c "import cysecuretools; \
	from intelhex import IntelHex;  import shutil; \
	tools = cysecuretools.CySecureTools('cy8ckit-064b0s2-4343w', 'policy/$(CY_SECURE_POLICY_NAME).json'); \
	tools.sign_image('$(CY_CONFIG_DIR)/$(APPNAME).hex',16); \
	shutil.copy2('./libs/psoc6cm0p/COMPONENT_CM0P_SECURE/psoc6_02_cm0p_secure.hex', \
	'$(CY_CONFIG_DIR)/psoc6_02_cm0p_secure.hex'); \
	tools.sign_image('$(CY_CONFIG_DIR)/psoc6_02_cm0p_secure.hex',1); \
	ihex = IntelHex(); \
	ihex.padding = 0x00; \
    ihex.loadfile('$(CY_CONFIG_DIR)/$(APPNAME).hex', 'hex'); \
    ihex.merge(IntelHex('$(CY_CONFIG_DIR)/psoc6_02_cm0p_secure.hex'), 'ignore'); \
    ihex.write_hex_file('$(CY_CONFIG_DIR)/$(APPNAME).hex', write_start_addr=False, byte_count=16);"
endif
else
CY_BSP_POSTBUILD=cysecuretools --target cyb06xxa --policy ./policy/$(CY_SECURE_POLICY_NAME).json sign-image --hex $(CY_CONFIG_DIR)/$(APPNAME).hex --image-id 1
endif

