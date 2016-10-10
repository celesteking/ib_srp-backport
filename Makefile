#
# Makefile for scsi_transport_srp.ko and ib_srp.ko.
#

ifeq ($(KVER),)
  ifeq ($(KDIR),)
    KVER = $(shell uname -r)
    KDIR ?= /lib/modules/$(KVER)/build
  else
    KVER = $$KERNELRELEASE
  endif
else
  KDIR ?= /lib/modules/$(KVER)/build
endif

VERSION := $(shell sed -n 's/Version:[[:blank:]]*//p' ib_srp-backport.spec)

# The file Modules.symvers has been renamed in the 2.6.18 kernel to
# Module.symvers. Find out which name to use by looking in $(KDIR).
MODULE_SYMVERS:=$(shell if [ -e $(KDIR)/Module.symvers ]; then \
		       echo Module.symvers; else echo Modules.symvers; fi)

# Name of the OFED kernel RPM.
OFED_KERNEL_IB_RPM:=$(shell for r in mlnx-ofa_kernel compat-rdma kernel-ib; do rpm -q $$r 2>/dev/null | grep -q "^$$r" && echo $$r && break; done)

# Name of the OFED kernel development RPM.
OFED_KERNEL_IB_DEVEL_RPM:=$(shell for r in mlnx-ofa_kernel-devel compat-rdma-devel kernel-ib-devel; do rpm -q $$r 2>/dev/null | grep -q "^$$r" && echo $$r && break; done)

OFED_FLAVOR=$(shell if [ -e /usr/bin/ofed_info ]; then /usr/bin/ofed_info 2>/dev/null | head -n1 | sed -n 's/^\(MLNX_OFED\|OFED-internal\).*/MOFED/p;s/^OFED-.*/OFED/p'; else echo in-tree; fi)

ifneq ($(OFED_KERNEL_IB_RPM),)
ifeq ($(OFED_KERNEL_IB_RPM),compat-rdma)
# OFED 3.x
OFED_KERNEL_DIR:=/usr/src/compat-rdma
OFED_CFLAGS:=-I$(OFED_KERNEL_DIR)/include
else
ifeq ($(OFED_FLAVOR),MOFED)
# Mellanox OFED with or without kernel-ib RPM. Since several MOFED backport
# header files use the LINUX_BACKPORT() macro without including
# <linux/compat-2.6.h>, include that header file explicitly.
OFED_KERNEL_DIR:=/usr/src/ofa_kernel/default
OFED_VERS=$(shell rpm -q --qf '%{version}\n' mlnx-ofa_kernel-devel 2>/dev/null)
OFED_CFLAGS:=-I$(OFED_KERNEL_DIR)/include -include "linux/compat-2.6.h"
OFED_CFLAGS+=-DMOFED_MAJOR=$(shell echo $(OFED_VERS) | cut -f1 -d.)
OFED_CFLAGS+=-DMOFED_MINOR=$(shell echo $(OFED_VERS) | cut -f2 -d.)
else
# OFED 1.5
OFED_KERNEL_DIR:=/usr/src/ofa_kernel
include $(OFED_KERNEL_DIR)/config.mk
OFED_CFLAGS:=$(BACKPORT_INCLUDES) -I$(OFED_KERNEL_DIR)/include
endif
endif
# Any OFED version
OFED_MODULE_SYMVERS:=$(OFED_KERNEL_DIR)/$(MODULE_SYMVERS)
endif

INSTALL_MOD_DIR ?= extra

GOALS:=$(if $(MAKECMDGOALS),$(MAKECMDGOALS),all)
OTHER_GOALS:=$(foreach goal,$(MAKECMDGOALS),$(subst all,,$(goal)))
# echo:=$(shell echo 'GOALS = $(GOALS)' >&2)
# echo:=$(shell echo 'OTHER_GOALS = $(OTHER_GOALS)' >&2)
ifneq ("$(GOALS)","$(OTHER_GOALS)")
HAVE_IB_CQ_INIT_ATTR := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/ib_cq_init_attr PRE_CFLAGS="$(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_IB_CQ_INIT_ATTR)
HAVE_IB_CREATE_CQ_ATTR_ARG := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/create_cq PRE_CFLAGS="$(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_IB_CREATE_CQ_ATTR_ARG)
HAVE_IB_FMR_POOL_MAP_PHYS_ARG5 := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/ib_fmr_pool_map_phys PRE_CFLAGS="$(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_IB_FMR_POOL_MAP_PHYS_ARG5)
HAVE_IB_INC_RKEY := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/ib_inc_rkey PRE_CFLAGS="$(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_IB_INC_RKEY)
HAVE_IB_QUERY_GID_WITH_ATTR := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/ib_query_gid PRE_CFLAGS="$(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_IB_QUERY_GID_WITH_ATTR)
HAVE_IB_SA_PATH_REC_GET_MASK_ARG := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/ib_sa_path_rec_get PRE_CFLAGS="$(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_IB_SA_PATH_REC_GET_MASK_ARG)
HAVE_PD_LOCAL_DMA_LKEY := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/pd_local_dma_lkey PRE_CFLAGS="-Werror $(OFED_CFLAGS)" >/dev/null 2>&1; echo -DHAVE_PD_LOCAL_DMA_LKEY=$$(($$? ? 0 : 1)))
HAVE_SCSI_MQ := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/scsi_mq PRE_CFLAGS="$(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_SCSI_MQ)
HAVE_SCSI_QDEPTH_REASON := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/scsi_qdepth_reason PRE_CFLAGS="-Werror $(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_SCSI_QDEPTH_REASON)
HAVE_STRUCT_IB_GID_ATTR := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/ib_gid_attr PRE_CFLAGS="$(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_STRUCT_IB_GID_ATTR)
HAVE_SYSTEM_LONG_WQ := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/system_long_wq PRE_CFLAGS="-Werror $(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_SYSTEM_LONG_WQ)
HAVE_TRACK_QUEUE_DEPTH := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/track_queue_depth PRE_CFLAGS="$(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_TRACK_QUEUE_DEPTH)
HAVE_USE_BLK_TAGS := $(shell $(MAKE) -C $(KDIR) SUBDIRS=$(shell pwd)/conftest/use_blk_tags PRE_CFLAGS="$(OFED_CFLAGS)" >/dev/null 2>&1 && echo -DHAVE_USE_BLK_TAGS)
PRE_CFLAGS := $(OFED_CFLAGS) $(HAVE_IB_CQ_INIT_ATTR)			\
	$(HAVE_IB_CREATE_CQ_ATTR_ARG) $(HAVE_IB_INC_RKEY)		\
	$(HAVE_IB_CREATE_CQ_ATTR_ARG) $(HAVE_IB_FMR_POOL_MAP_PHYS_ARG5)	\
	$(HAVE_IB_INC_RKEY) $(HAVE_IB_QUERY_GID_WITH_ATTR)		\
	$(HAVE_IB_SA_PATH_REC_GET_MASK_ARG)				\
	$(HAVE_PD_LOCAL_DMA_LKEY) $(HAVE_SCSI_MQ)			\
	$(HAVE_SCSI_QDEPTH_REASON)					\
	$(HAVE_STRUCT_IB_GID_ATTR)					\
	$(HAVE_SYSTEM_LONG_WQ)						\
	$(HAVE_TRACK_QUEUE_DEPTH) $(HAVE_USE_BLK_TAGS)			\
	-DOFED_FLAVOR=$(OFED_FLAVOR)
endif

all: check
	@m="$(shell pwd)/drivers/scsi/$(MODULE_SYMVERS)";	   	   \
	cat "$(KDIR)/$(MODULE_SYMVERS)" $(OFED_MODULE_SYMVERS) |	   \
	awk '{sym[$$2]=$$0} END {for (s in sym){print sym[s]}}' >"$$m";    \
	CONFIG_SCSI_SRP_ATTRS=m						   \
		$(MAKE) -C $(KDIR) M=$(shell pwd)/drivers/scsi		   \
		PRE_CFLAGS='$(PRE_CFLAGS)' modules
	@m="$(shell pwd)/drivers/infiniband/ulp/srp/$(MODULE_SYMVERS)";	   \
	cat "$(KDIR)/$(MODULE_SYMVERS)" $(OFED_MODULE_SYMVERS)		   \
		"$(shell pwd)/drivers/scsi/$(MODULE_SYMVERS)" |		   \
	awk '{sym[$$2]=$$0} END {for (s in sym){print sym[s]}}' >"$$m";	   \
	CONFIG_SCSI_SRP_ATTRS=m CONFIG_SCSI_SRP=m CONFIG_INFINIBAND_SRP=m  \
	$(MAKE) -C $(KDIR) M=$(shell pwd)/drivers/infiniband/ulp/srp	   \
	    PRE_CFLAGS='$(PRE_CFLAGS) -DBUILD_CFLAGS='"'"'$(PRE_CFLAGS)'"'"'' modules

install: all
	for d in drivers/scsi drivers/infiniband/ulp/srp; do	   	   \
	  $(MAKE) -C $(KDIR) SUBDIRS="$(shell pwd)/$$d"			   \
          $$([ -n "$(INSTALL_MOD_PATH)" ] && echo DEPMOD=true)		   \
	  modules_install;			   			   \
	done

uninstall:
	for m in scsi_transport_srp.ko ib_srp.ko; do			       \
	  rm -f $(INSTALL_MOD_PATH)/lib/modules/$(KVER)/$(INSTALL_MOD_DIR)/$$m;\
	done
	if [ -z "$(INSTALL_MOD_PATH)" ]; then	\
	  /sbin/depmod -a $(KVER);			\
	fi

check:
	@if [ -n "$(OFED_KERNEL_IB_RPM)" ]; then                            \
	  if [ -z "$(OFED_KERNEL_IB_DEVEL_RPM)" ]; then                     \
	    echo "Error: the OFED package $(OFED_KERNEL_IB_RPM)-devel has"  \
	         "not yet been installed.";                                 \
	    false;                                                          \
	  else                                                              \
	    echo "  Building against $(OFED_FLAVOR) $(OFED_KERNEL_IB_RPM)"  \
	         "InfiniBand kernel headers.";                              \
	  fi                                                                \
	else                                                                \
	  if [ -n "$(OFED_KERNEL_IB_DEVEL_RPM)" ]; then                     \
	    echo "Error: the OFED kernel package has not yet been"          \
	         "installed.";                                              \
	    false;                                                          \
	  else                                                              \
	    echo "  Building against in-tree InfiniBand kernel headers.";   \
	  fi;                                                               \
	fi

dist-gzip:
	mkdir ib_srp-backport-$(VERSION) &&			\
	{							\
	  {							\
	    git ls-tree --name-only -r HEAD 2>/dev/null	||	\
	    hg manifest;					\
	  } |							\
	  tar -T- -cf- |					\
	  tar -C ib_srp-backport-$(VERSION) -xf-; } &&		\
	rm -f ib_srp-backport-$(VERSION).tar.bz2 &&		\
	tar --owner=root --group=root				\
	    -cjf ib_srp-backport-$(VERSION).tar.bz2		\
		ib_srp-backport-$(VERSION) &&			\
	rm -rf ib_srp-backport-$(VERSION)

# Build an RPM either for the running kernel or for kernel version $KVER.
rpm:
	name=ib_srp-backport &&						 \
	rpmtopdir="$$(if [ $$(id -u) = 0 ]; then echo /usr/src/packages; \
		      else echo $$PWD/rpmbuilddir; fi)" &&		 \
	$(MAKE) dist-gzip &&						 \
	rm -rf $${rpmtopdir} &&						 \
	for d in BUILD RPMS SOURCES SPECS SRPMS; do			 \
	  mkdir -p $${rpmtopdir}/$$d;					 \
	done &&								 \
	cp $${name}-$(VERSION).tar.bz2 $${rpmtopdir}/SOURCES &&		 \
	rpmbuild --define="%_topdir $${rpmtopdir}"			 \
		 -ba $${name}.spec &&					 \
	rm -f ib_srp-backport-$(VERSION).tar.bz2

clean:
	$(MAKE) -C $(KDIR) M=$(shell pwd)/drivers/scsi clean
	$(MAKE) -C $(KDIR) M=$(shell pwd)/drivers/infiniband/ulp/srp clean
	rm -f Modules.symvers Module.symvers Module.markers modules.order

extraclean: clean
	rm -f *.orig *.rej

.PHONY: all check clean dist-gzip extraclean install rpm
