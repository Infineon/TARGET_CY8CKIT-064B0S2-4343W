################################################################################
# \file bsp.mk
#
# \brief
# Define the CY8CKIT-064B0S2-4343W target.
#
################################################################################
# \copyright
# Copyright 2018-2022 Cypress Semiconductor Corporation (an Infineon company) or
# an affiliate of Cypress Semiconductor Corporation
#
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

# Define default Trusted-Firmware-M usage. TFM must use multi.
ifneq (,$(filter MW_TRUSTED_FIRMWARE_M, $(COMPONENTS)))
SECURE_BOOT_USING_TFM?=True
TRUSTED_FIRMWARE_M_PATH?=$(SEARCH_trusted-firmware-m)
endif
ifeq ($(SECURE_BOOT_USING_TFM), True)
SECURE_BOOT_STAGE?=multi
ifneq ($(SECURE_BOOT_STAGE),multi)
$(error TFM must use multi bootloading.)
endif
else
# Define default type of bootloading method [single, multi]
# single -> CM4 only, multi -> CM0 and CM4
SECURE_BOOT_STAGE?=single
SECURE_BOOT_USING_TFM?=False
endif

# Any additional components to apply when using this board.
BSP_COMPONENTS:=WIFI_INTERFACE_SDIO CY8CKIT-064B0S2-4343W

ifeq ($(SECURE_BOOT_USING_TFM),True)
BSP_COMPONENTS+=TFM_S_FW TFM_NS_INTERFACE
else
BSP_COMPONENTS+=CM0P_SECURE
endif


# Any additional defines to apply when using this board.
# Enable Multi-Client Call feature in TF-M
# TFM supplies it's own prebuilt CM0P image
BSP_DEFINES:=CY_USING_HAL
ifeq ($(SECURE_BOOT_USING_TFM),True)
BSP_DEFINES+=TFM_MULTI_CORE_MULTI_CLIENT_CALL TFM_MULTI_CORE_NS_OS CY_USING_PREBUILT_CM0P_IMAGE
endif

ifeq ($(SECURE_BOOT_USING_TFM),True)
BSP_LINKER_SUFFIX=_tfm
else
ifeq ($(SECURE_BOOT_STAGE),single)
BSP_LINKER_SUFFIX=
else
# In multi-boot, we want the "single" linker script for CM4 because that only links
# in the CM4 image, allowing the CM0 image to be loaded separately.
BSP_LINKER_SUFFIX=$(if $(call mtb_equals,$(MTB_RECIPE__CORE),CM4), _single,)
endif
endif

# Specify the path to the linker script to use
ifeq ($(TOOLCHAIN),GCC_ARM)
	BSP_LINKER_SCRIPT_EXT:=ld
else ifeq ($(TOOLCHAIN),ARM)
	BSP_LINKER_SCRIPT_EXT:=sct
else ifeq ($(TOOLCHAIN),IAR)
	BSP_LINKER_SCRIPT_EXT:=icf
endif

MTB_BSP__LINKER_SCRIPT=$(MTB_TOOLS__TARGET_DIR)/COMPONENT_$(MTB_RECIPE__CORE)/TOOLCHAIN_$(TOOLCHAIN)/linker$(BSP_LINKER_SUFFIX).$(BSP_LINKER_SCRIPT_EXT)
# Python path definition
CY_PYTHON_REQUIREMENT=true


# This only needs to run in the second stage where the CY_PYTHON_PATH gets defined
ifneq ($(CY_PYTHON_PATH),)
CY_SECURE_TOOLS_MAJOR_VERSION=$(word 1, $(subst ., ,$(filter-out , \
							  $(subst cysecuretools==, , \
							  $(shell $(CY_PYTHON_PATH) -m pip freeze | grep cysecuretools)))))
endif

# Policy name based on usage of TFM
ifeq ($(SECURE_BOOT_USING_TFM),True)
CY_SECURE_POLICY_NAME?=policy_multi_CM0_CM4_tfm
else
ifneq ($(strip $(filter 2 1 0,$(CY_SECURE_TOOLS_MAJOR_VERSION))),)
CY_SECURE_POLICY_NAME?=policy_$(SECURE_BOOT_STAGE)_CM0_CM4
else
CY_SECURE_POLICY_NAME?=policy_$(SECURE_BOOT_STAGE)_CM0_CM4_swap
endif
endif


# Define the toolchain path
ifeq ($(TOOLCHAIN),ARM)
TOOLCHAIN_PATH=$(MTB_TOOLCHAIN_ARM__BASE_DIR)
else
TOOLCHAIN_PATH=$(MTB_TOOLCHAIN_GCC_ARM__BASE_DIR)
endif



# If TFM, use tfm_s.hex as CMO+ image
ifeq ($(SECURE_BOOT_USING_TFM),True)
POST_BUILD_CM0_NAME?=tfm_s
POST_BUILD_CM0_LIB_PATH?=$(TRUSTED_FIRMWARE_M_PATH)/COMPONENT_CY8CKIT-064B0S2-4343W/COMPONENT_TFM_S_FW
POST_BUILD_POLICY_PATH?=./imports/trusted-firmware-m/security/COMPONENT_CY8CKIT-064B0S2-4343W/policy
POST_BUILD_POLICY_PATH_ABS?=$(call mtb_path_normalize,$(POST_BUILD_POLICY_PATH))
POST_BUILD_POLICY_PATH_SWITCH?=--policy-path $(POST_BUILD_POLICY_PATH_ABS)
else 
# Secure boot for non-TFM
POST_BUILD_CM0_NAME?=psoc6_02_cm0p_secure
POST_BUILD_CM0_LIB_PATH?=$(SEARCH_cat1cm0p)/COMPONENT_CAT1A/COMPONENT_CM0P_SECURE
POST_BUILD_POLICY_PATH_SWITCH?=
endif

POST_BUILD_BSP_LIB_PATH_INTERNAL=$(SEARCH_TARGET_$(TARGET))
POST_BUILD_BSP_LIB_PATH=$(call mtb_path_normalize,$(POST_BUILD_BSP_LIB_PATH_INTERNAL))
POST_BUILD_CM0_LIB_PATH_ABS?=$(call mtb_path_normalize,$(POST_BUILD_CM0_LIB_PATH))

# BSP-specific post-build action
CY_BSP_POSTBUILD=$(CY_PYTHON_PATH) $(POST_BUILD_BSP_LIB_PATH)/psoc64_postbuild.py \
				--core $(MTB_RECIPE__CORE) \
				--secure-boot-stage $(SECURE_BOOT_STAGE) \
				$(POST_BUILD_POLICY_PATH_SWITCH) \
				--policy $(CY_SECURE_POLICY_NAME) \
				--target cyb06xxa \
				--toolchain-path $(TOOLCHAIN_PATH) \
				--toolchain $(TOOLCHAIN) \
				--build-dir $(MTB_TOOLS__OUTPUT_CONFIG_DIR) \
				--app-name $(APPNAME) \
				--cm0-app-path $(POST_BUILD_CM0_LIB_PATH_ABS) \
				--cm0-app-name $(POST_BUILD_CM0_NAME)

################################################################################
# ALL ITEMS BELOW THIS POINT ARE AUTO GENERATED BY THE BSP ASSISTANT TOOL.
# DO NOT MODIFY DIRECTLY. CHANGES SHOULD BE MADE THROUGH THE BSP ASSISTANT.
################################################################################

# Board device selection. MPN_LIST tracks what was selected in the BSP Assistant
# All other variables are derived by BSP Assistant based on the MPN_LIST.
MPN_LIST:=CYB0644ABZI-S2D44 LBEE5KL1DX
DEVICE:=CYB0644ABZI-S2D44
ADDITIONAL_DEVICES:=CYW4343WKUBG
DEVICE_COMPONENTS:=4343W CAT1 CAT1A HCI-UART MURATA-1DX PSOC6_02
DEVICE_CYB0644ABZI-S2D44_CORES:=CORE_NAME_CM0P_0 CORE_NAME_CM4_0
DEVICE_CYB0644ABZI-S2D44_DIE:=PSoC6A2M
DEVICE_CYB0644ABZI-S2D44_FEATURES:=SecureBoot
DEVICE_CYB0644ABZI-S2D44_FLASH_KB:=1856
DEVICE_CYB0644ABZI-S2D44_SRAM_KB:=1024
DEVICE_CYW4343WKUBG_DIE:=4343A1
DEVICE_CYW4343WKUBG_FLASH_KB:=0
DEVICE_CYW4343WKUBG_SRAM_KB:=512
DEVICE_LIST:=CYB0644ABZI-S2D44 CYW4343WKUBG
DEVICE_TOOL_IDS:=bsp-assistant bt-configurator capsense-configurator capsense-tuner device-configurator dfuh-tool library-manager lin-configurator ml-configurator project-creator qspi-configurator secure-policy-configurator seglcd-configurator smartio-configurator usbdev-configurator
RECIPE_DIR:=$(SEARCH_recipe-make-cat1a)
