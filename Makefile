#
# Makefile for scsi_transport_srp.ko and ib_srp.ko.
#

ifeq ($(KVER),)
  ifeq ($(KDIR),)
    KVER := $(shell uname -r)
    KDIR := /lib/modules/$(KVER)/build
  else
    ifeq ($(KERNELRELEASE),)
      KVER := $(strip $(shell                                           \
        cat $(KDIR)/include/config/kernel.release 2>/dev/null ||        \
        make -s -C $(KDIR) kernelversion))
    else
      KVER := $(KERNELRELEASE)
    endif
  endif
else
  KDIR := /lib/modules/$(KVER)/build
endif

VERSION := $(shell sed -n 's/Version:[[:blank:]]*//p' ib_srp-backport.spec)

# The file Modules.symvers has been renamed in the 2.6.18 kernel to
# Module.symvers. Find out which name to use by looking in $(KDIR).
MODULE_SYMVERS:=$(shell if [ -e "$(KDIR)/Module.symvers" ]; then \
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
CKVER:=$(shell echo "$(KVER)" | sed 's/^\(\(2\.6\|[3-9]\)\.[0-9]*\).*/\1/')
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

run_conftest = $(shell if [ "0$(V)" -gt 0 ]; then output=/dev/stdout; else output=/dev/null; fi; if $(MAKE) -C $(KDIR) V=$(V) SUBDIRS="$(shell pwd)/conftest/$1" PRE_CFLAGS="-Werror $(OFED_CFLAGS)" 1>&2 2>$${output}; then echo "$2"; else echo "$3"; fi)
run_conftest_bool = $(call run_conftest,$1,-D$(strip $2)=1,-D$(strip $2)=0)

CONFTESTS = $(shell ls -d conftest/*)
CONFTEST_OUTPUTS = $(shell			\
	for t in $(CONFTESTS); do		\
		echo $$t/result-$(KVER).txt;	\
	done)

PRE_CFLAGS = $(OFED_CFLAGS)			\
	-DOFED_FLAVOR=$(OFED_FLAVOR)		\
	$(shell for t in $(CONFTESTS); do 	\
		cat $$t/result-$(KVER).txt 2>/dev/null; \
	done)

all: check drivers/scsi/scsi_transport_srp.ko	\
	drivers/infiniband/ulp/srp/ib_srp.ko

drivers/scsi/$(MODULE_SYMVERS): $(KDIR)/$(MODULE_SYMVERS) $(OFED_MODULE_SYMVERS)
	cat "$(KDIR)/$(MODULE_SYMVERS)" $(OFED_MODULE_SYMVERS) |	   \
	awk '{sym[$$2]=$$0} END {for (s in sym){print sym[s]}}' >"$@"

drivers/infiniband/ulp/srp/$(MODULE_SYMVERS): $(KDIR)/$(MODULE_SYMVERS)	   \
	$(OFED_MODULE_SYMVERS) drivers/scsi/$(MODULE_SYMVERS)
	cat "$(KDIR)/$(MODULE_SYMVERS)" $(OFED_MODULE_SYMVERS)		   \
		"drivers/scsi/$(MODULE_SYMVERS)" |			   \
	awk '{sym[$$2]=$$0} END {for (s in sym){print sym[s]}}' >"$@"

drivers/scsi/scsi_transport_srp.ko: drivers/scsi/$(MODULE_SYMVERS)	   \
	drivers/scsi/scsi_transport_srp.c $(CONFTEST_OUTPUTS)
	CONFIG_SCSI_SRP_ATTRS=m						   \
		$(MAKE) -C $(KDIR) M=$(shell pwd)/drivers/scsi		   \
		PRE_CFLAGS='$(PRE_CFLAGS)' modules

drivers/infiniband/ulp/srp/ib_srp.ko: drivers/scsi/$(MODULE_SYMVERS)	   \
	drivers/infiniband/ulp/srp/$(MODULE_SYMVERS)			   \
	drivers/infiniband/ulp/srp/ib_srp.c $(CONFTEST_OUTPUTS)
	CONFIG_SCSI_SRP_ATTRS=m CONFIG_SCSI_SRP=m CONFIG_INFINIBAND_SRP=m  \
	$(MAKE) -C $(KDIR) M=$(shell pwd)/drivers/infiniband/ulp/srp	   \
	    PRE_CFLAGS='$(PRE_CFLAGS) -DBUILD_CFLAGS='"'"'$(PRE_CFLAGS)'"'"'' \
	    modules

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
	rm -rf ib_srp-backport-$(VERSION) &&			\
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
		 --define="%kdir $(KDIR)"				 \
		 --define="%kversion $(KVER)"				 \
		 -ba $${name}.spec &&					 \
	rm -f ib_srp-backport-$(VERSION).tar.bz2

clean:
	for d in drivers/scsi drivers/infiniband/ulp/srp conftest/*; do	\
	(cd "$$d" &&							\
	rm -rf ./{*.mod.c,*.o,.*.o.d,*.ko,*.o.cmd,*.ko.cmd,.*o.cmd,*.mod,Module*.symvers,modules.order,result-$(KVER).txt,.tmp_versions});	\
	done

extraclean: clean
	rm -f *.orig *.rej

conftest/create_cq/result-$(KVER).txt:				\
	conftest/create_cq/create_cq.c				\
	conftest/create_cq/Makefile
	echo "$(call run_conftest_bool,create_cq,HAVE_IB_CREATE_CQ_ATTR_ARG)" >"$@"

conftest/ib_alloc_cq/result-$(KVER).txt:			\
	conftest/ib_alloc_cq/ib_alloc_cq.c			\
	conftest/ib_alloc_cq/Makefile
	echo "$(call run_conftest_bool,ib_alloc_cq,HAVE_IB_ALLOC_CQ)" >"$@"

conftest/ib_client_remove/result-$(KVER).txt:			\
	conftest/ib_client_remove/ib_client_remove.c		\
	conftest/ib_client_remove/Makefile
	echo "$(call run_conftest_bool,ib_client_remove,	\
		HAVE_IB_CLIENT_REMOVE_CLIENT_ARG)" >"$@"

conftest/ib_cq_init_attr/result-$(KVER).txt:			\
	conftest/ib_cq_init_attr/ib_cq_init_attr.c		\
	conftest/ib_cq_init_attr/Makefile
	echo "$(call run_conftest_bool,ib_cq_init_attr,HAVE_IB_CQ_INIT_ATTR)" >"$@"

conftest/ib_device_sg_gaps_reg/result-$(KVER).txt:		\
	conftest/ib_device_sg_gaps_reg/ib_device_sg_gaps_reg.c	\
	conftest/ib_device_sg_gaps_reg/Makefile
	echo "$(call run_conftest_bool,ib_device_sg_gaps_reg,	\
		HAVE_IB_DEVICE_SG_GAPS_REG)" >"$@"

conftest/ib_dma_map_ops/result-$(KVER).txt:			\
	conftest/ib_dma_map_ops/ib_dma_map_ops.c		\
	conftest/ib_dma_map_ops/Makefile
	echo "$(call run_conftest_bool,ib_dma_map_ops,		\
		HAVE_IB_DMA_MAP_OPS)" >"$@"

conftest/ib_fmr_pool_map_phys/result-$(KVER).txt:		\
	conftest/ib_fmr_pool_map_phys/ib_fmr_pool_map_phys.c	\
	conftest/ib_fmr_pool_map_phys/Makefile
	echo "$(call run_conftest_bool,ib_fmr_pool_map_phys,	\
		HAVE_IB_FMR_POOL_MAP_PHYS_ARG5)" >"$@"

conftest/ib_gid_attr/result-$(KVER).txt:			\
	conftest/ib_gid_attr/ib_gid_attr.c			\
	conftest/ib_gid_attr/Makefile
	echo "$(call run_conftest_bool,ib_gid_attr,		\
		HAVE_STRUCT_IB_GID_ATTR)" >"$@"

conftest/ib_inc_rkey/result-$(KVER).txt:			\
	conftest/ib_inc_rkey/ib_inc_rkey.c			\
	conftest/ib_inc_rkey/Makefile
	echo "$(call run_conftest_bool,ib_inc_rkey,		\
		HAVE_IB_INC_RKEY)" >"$@"

conftest/ib_map_mr_sg/result-$(KVER).txt:			\
	conftest/ib_map_mr_sg/ib_map_mr_sg.c			\
	conftest/ib_map_mr_sg/Makefile
	echo "$(call run_conftest_bool,ib_map_mr_sg,		\
		HAVE_IB_MAP_MR_SG_WITH_OFFSET)" >"$@"

conftest/ib_mr_length/result-$(KVER).txt:			\
	conftest/ib_mr_length/ib_mr_length.c			\
	conftest/ib_mr_length/Makefile
	echo "$(call run_conftest_bool,ib_mr_length,HAVE_IB_MR_LENGTH)" >"$@"

conftest/ib_mr_type_mem_reg/result-$(KVER).txt:			\
	conftest/ib_mr_type_mem_reg/ib_mr_type_mem_reg.c	\
	conftest/ib_mr_type_mem_reg/Makefile
	echo "$(call run_conftest_bool,ib_mr_type_mem_reg,	\
		HAVE_IB_MR_TYPE_MEM_REG)" >"$@"

conftest/ib_query_device/result-$(KVER).txt:			\
	conftest/ib_query_device/ib_query_device.c		\
	conftest/ib_query_device/Makefile
	echo "$(call run_conftest_bool,ib_query_device,		\
		HAVE_IB_QUERY_DEVICE)" >"$@"

conftest/ib_query_gid/result-$(KVER).txt:			\
	conftest/ib_query_gid/ib_query_gid.c			\
	conftest/ib_query_gid/Makefile
	echo "$(call run_conftest_bool,ib_query_gid,		\
		HAVE_IB_QUERY_GID_WITH_ATTR)" >"$@"

conftest/ib_sa_path_rec_get/result-$(KVER).txt:			\
	conftest/ib_sa_path_rec_get/ib_sa_path_rec_get.c	\
	conftest/ib_sa_path_rec_get/Makefile
	echo "$(call run_conftest_bool,ib_sa_path_rec_get,	\
		HAVE_IB_SA_PATH_REC_GET_MASK_ARG)" >"$@"

conftest/ib_wr_reg_mr/result-$(KVER).txt:			\
	conftest/ib_wr_reg_mr/ib_wr_reg_mr.c			\
	conftest/ib_wr_reg_mr/Makefile
	echo "$(call run_conftest_bool,ib_wr_reg_mr,HAVE_IB_WR_REG_MR)" >"$@"

conftest/pd_global_rkey/result-$(KVER).txt:			\
	conftest/pd_global_rkey/pd_global_rkey.c		\
	conftest/pd_global_rkey/Makefile
	echo "$(call run_conftest_bool,pd_global_rkey,		\
		HAVE_PD_GLOBAL_RKEY)" >"$@"

conftest/pd_local_dma_lkey/result-$(KVER).txt:			\
	conftest/pd_local_dma_lkey/pd_local_dma_lkey.c		\
	conftest/pd_local_dma_lkey/Makefile
	echo "$(call run_conftest_bool,pd_local_dma_lkey,	\
		HAVE_PD_LOCAL_DMA_LKEY)" >"$@"

conftest/rdma_create_id_net/result-$(KVER).txt:			\
	conftest/rdma_create_id_net/rdma_create_id_net.c	\
	conftest/rdma_create_id_net/Makefile
	echo "$(call run_conftest_bool,rdma_create_id_net,	\
		RDMA_CREATE_ID_TAKES_NET_ARG)" >"$@"

conftest/scsi_host_use_blk_mq/result-$(KVER).txt:		\
	conftest/scsi_host_use_blk_mq/scsi_host_use_blk_mq.c	\
	conftest/scsi_host_use_blk_mq/Makefile
	echo $(call run_conftest_bool,scsi_host_use_blk_mq,	\
		HAVE_SCSI_HOST_USE_BLK_MQ) >$@

conftest/scsi_mq/result-$(KVER).txt:				\
	conftest/scsi_mq/scsi_mq.c				\
	conftest/scsi_mq/Makefile
	echo "$(call run_conftest_bool,scsi_mq,HAVE_SCSI_MQ)" >"$@"

conftest/scsi_qdepth_reason/result-$(KVER).txt:			\
	conftest/scsi_qdepth_reason/scsi_qdepth_reason.c	\
	conftest/scsi_qdepth_reason/Makefile
	echo "$(call run_conftest_bool,scsi_qdepth_reason,	\
		HAVE_SCSI_QDEPTH_REASON)" >"$@"

conftest/system_long_wq/result-$(KVER).txt:			\
	conftest/system_long_wq/system_long_wq.c		\
	conftest/system_long_wq/Makefile
	echo "$(call run_conftest_bool,system_long_wq,		\
		HAVE_SYSTEM_LONG_WQ)" >"$@"

conftest/track_queue_depth/result-$(KVER).txt:			\
	conftest/track_queue_depth/track_queue_depth.c		\
	conftest/track_queue_depth/Makefile
	echo "$(call run_conftest_bool,track_queue_depth,	\
		HAVE_TRACK_QUEUE_DEPTH)" >"$@"

conftest/use_blk_tags/result-$(KVER).txt:			\
	conftest/use_blk_tags/use_blk_tags.c			\
	conftest/use_blk_tags/Makefile
	echo "$(call run_conftest_bool,use_blk_tags,HAVE_USE_BLK_TAGS)" >"$@"

.PHONY: all check clean dist-gzip extraclean install rpm
