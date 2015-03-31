# KVM make targets, for Libreswan
#
# Copyright (C) 2015 Andrew Cagney <cagney@gnu.org>
# 
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.  See <http://www.fsf.org/copyleft/gpl.txt>.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.

# XXX: GNU Make doesn't let you combine pattern targets (e.x.,
# kvm-install-%: kvm-reboot-%) with .PHONY.  Consequently, so that
# patterns can be used, any targets with dependencies are not marked
# as .PHONY.  Sigh!

# XXX: For compatibility
abs_top_srcdir ?= $(abspath ${LIBRESWANSRCDIR})

KVM_RUNKVM_COMMAND ?= $(abs_top_srcdir)/testing/utils/runkvm.py
KVM_MOUNTS_COMMAND ?= $(abs_top_srcdir)/testing/utils/kvmmounts.sh
KVM_SWANTEST_COMMAND ?= $(abs_top_srcdir)/testing/utils/swantest

KVM_HOSTS = east west road north

# NOTE: Use this from make rules only.  Determines the KVM path to
# $(abs_top_srcdir).  If broken, override using Makefile.inc.local
KVM_HOST = $(lastword $(subst -, ,$@))
KVM_BUILD_MOUNT ?= $(shell $(KVM_MOUNTS_COMMAND) $(1) swansource)
KVM_BUILD_SUBDIR ?= $(subst $(call KVM_BUILD_MOUNT,$(1)),,$(abs_top_srcdir))
KVM_TARGET_SOURCEDIR ?= $(patsubst %/,%,/source/$(patsubst /%,%,$(call KVM_BUILD_SUBDIR,$(1))))
KVM_SOURCEDIR ?= $(call KVM_TARGET_SOURCEDIR,$(KVM_HOST))
KVM_EASTDIR ?= $(call KVM_TARGET_SOURCEDIR,east)

KVM_PRINT_TARGETS = $(patsubst %,kvm-print-%,$(KVM_HOSTS))
.PHONY: $(KVM_PRINT_TARGETS)
$(KVM_PRINT_TARGETS): kvm-print
	: $@:
	:   KVM_HOST: $(KVM_HOST)
	:   KVM_BUILD_MOUNT: $(call KVM_BUILD_MOUNT,$(KVM_HOST))
	:   KVM_BUILD_SUBDIR: $(call KVM_BUILD_SUBDIR,$(KVM_HOST))
	:   KVM_TARGET_SOURCEDIR: $(call KVM_TARGET_SOURCEDIR,$(KVM_HOST))
	:   KVM_SOURCEDIR: $(KVM_SOURCEDIR)
.PHONY: kvm-print
kvm-print:
	: $@:
	:   PWD: $(PWD)
	:   KVM_HOSTS: $(KVM_HOSTS)
	:   KVM_PRINT_TARGETS: $(KVM_PRINT_TARGETS)
	:   KVM_EASTDIR: $(KVM_EASTDIR)

KVM_RUN_TARGETS = $(patsubst %,kvm-run-%,$(KVM_HOSTS))
.PHONY: $(KVM_RUN_TARGETS)
$(KVM_RUN_TARGETS):
	: RUN: '$(RUN)'
	: KVM_SOURCEDIR: $(KVM_SOURCEDIR)
	: KVM_HOST: $(KVM_HOST)
	test '$(RUN)' != ""
	$(KVM_RUNKVM_COMMAND) --sourcedir $(KVM_SOURCEDIR) $(KVM_HOST) '$(RUN)'
.PHONY: kvm-run
kvm-run: $(KVM_RUN_TARGETS)

KVM_REBOOT_TARGETS = $(patsubst %,kvm-reboot-%,$(KVM_HOSTS))
.PHONY: $(KVM_REBOOT_TARGETS)
$(KVM_REBOOT_TARGETS):
	$(KVM_RUNKVM_COMMAND) --sourcedir $(KVM_SOURCEDIR) --reboot $(KVM_HOST)

KVM_BUILD_TARGETS = $(patsubst %,kvm-build-%,$(KVM_HOSTS))
#.PHONY: $(KVM_BUILD_TARGETS)
#$(KVM_BUILD_TARGETS):
kvm-build-%: kvm-print-% kvm-reboot-%
	$(KVM_RUNKVM_COMMAND) --sourcedir $(KVM_SOURCEDIR) $(KVM_HOST) ./testing/guestbin/swan-build

KVM_INSTALL_TARGETS = $(patsubst %,kvm-install-%,$(KVM_HOSTS))
#.PHONY: $(KVM_INSTALL_TARGETS)
#$(KVM_INSTALL_TARGETS):
kvm-install-%: kvm-print-% kvm-reboot-%
	$(KVM_RUNKVM_COMMAND) --sourcedir $(KVM_SOURCEDIR) $(KVM_HOST) ./testing/guestbin/swan-install

.PHONY: kvm-update
kvm-update: kvm-build-east | $(KVM_INSTALL_TARGETS)

KVM_EXCLUDE = bad|wip|incomplete
KVM_EXCLUDE_FLAG = $(if $(KVM_EXCLUDE),--exclude '$(KVM_EXCLUDE)')
KVM_INCLUDE =
KVM_INCLUDE_FLAG = $(if $(KVM_INCLUDE),--include '$(KVM_INCLUDE)')
.PHONY: kvm-check
kvm-check: kvm-print
	: $@:
	:   KVM_EXCLUDE: '$(KVM_EXCLUDE)'
	:     KVM_EXCLUDE_FLAG: $(KVM_EXCLUDE_FLAG)
	:   KVM_INCLUDE: '$(KVM_INCLUDE)'
	:     KVM_INCLUDE_FLAG: $(KVM_INCLUDE_FLAG)
	cd testing/pluto && $(KVM_SWANTEST_COMMAND) --testingdir $(KVM_EASTDIR)/testing $(KVM_INCLUDE_FLAG) $(KVM_EXCLUDE_FLAG)
	cd testing/pluto && $(KVM_SWANTEST_COMMAND) --testingdir $(KVM_EASTDIR)/testing --scancwd
