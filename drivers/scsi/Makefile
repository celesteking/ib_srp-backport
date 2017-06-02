LINUXINCLUDE := $(PRE_CFLAGS) $(LINUXINCLUDE)
ccflags-y += -DDRV_VERSION="\"$$(sed -n -e 's/^PACKAGE_VERSION=[[:blank:]]*\([^[:blank:]]*\).*/\1/p' $(KBUILD_EXTMOD)/../../dkms.conf)\""

obj-$(CONFIG_SCSI_SRP_ATTRS)	+= scsi_transport_srp.o
