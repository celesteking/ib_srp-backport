#ifndef _LINUX_BACKPORT_H_
#define _LINUX_BACKPORT_H_

#include <stdarg.h>           /* va_list */
#include <linux/kernel.h>     /* asmlinkage */
#include <linux/types.h>      /* u32 */
#include <linux/version.h>    /* LINUX_VERSION_CODE */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(2, 6, 37)
#include <linux/printk.h>     /* pr_warn() -- see also commit 968ab18 */
#endif
#if defined(RHEL_MAJOR) && RHEL_MAJOR -0 == 5
#define vlan_dev_vlan_id(dev) (panic("RHEL 5 misses vlan_dev_vlan_id()"),0)
#endif
#if defined(RHEL_MAJOR) && RHEL_MAJOR -0 <= 6
#define __ethtool_get_settings(dev, cmd) (panic("RHEL misses __ethtool_get_settings()"),0)
#endif
#include <linux/rtnetlink.h>
#include <rdma/rdma_cm.h>
#include <scsi/scsi_device.h> /* SDEV_TRANSPORT_OFFLINE */

/* <linux/blkdev.h> */
#if !defined(CONFIG_SUSE_KERNEL) &&				\
	LINUX_VERSION_CODE >= KERNEL_VERSION(3, 7, 0) ||	\
	defined(CONFIG_SUSE_KERNEL) &&				\
	LINUX_VERSION_CODE >= KERNEL_VERSION(3, 8, 0)
/*
 * See also commit 24faf6f6 (upstream kernel 3.7.0). Note: request_fn_active
 * is not present in the openSUSE 12.3 kernel desipite having version number
 * 3.7.10.
 */
#ifndef HAVE_REQUEST_QUEUE_REQUEST_FN_ACTIVE
#define HAVE_REQUEST_QUEUE_REQUEST_FN_ACTIVE
#endif
#endif

#ifndef RQF_QUIET
#define RQF_QUIET REQ_QUIET
#endif

/* <linux/kernel.h> */
#if LINUX_VERSION_CODE < KERNEL_VERSION(2, 6, 29)
#ifndef swap
#define swap(a, b) \
	do { typeof(a) __tmp = (a); (a) = (b); (b) = __tmp; } while (0)
#endif
#endif

#if LINUX_VERSION_CODE < KERNEL_VERSION(2, 6, 39) &&  \
	(!defined(RHEL_MAJOR) || RHEL_MAJOR -0 < 6 || \
	 RHEL_MAJOR -0 == 6 && RHEL_MINOR -0 < 4)
static inline int __must_check kstrtouint(const char *s, unsigned int base,
					  unsigned int *res)
{
	unsigned long lres;
	int ret;

	ret = strict_strtoul(s, base, &lres);
	if (ret == 0)
		*res = lres;
	return ret;
}

static inline int __must_check kstrtoint(const char *s, unsigned int base,
					 int *res)
{
	long lres;
	int ret;

	ret = strict_strtol(s, base, &lres);
	if (ret == 0)
		*res = lres;
	return ret;
}
#endif

/* <linux/inet.h> */
#if LINUX_VERSION_CODE < KERNEL_VERSION(2, 6, 29)
static inline int in4_pton(const char *src, int srclen, u8 *dst, int delim,
			   const char **end)
{
	return -ENOSYS;
}
#endif

/* <linux/lockdep.h> */
#if LINUX_VERSION_CODE < KERNEL_VERSION(2, 6, 32)
#define lockdep_assert_held(lock) do { } while(0)
#endif

/* <linux/printk.h> */
#ifndef pr_warn
#define pr_warn pr_warning
#endif

/* <linux/scatterlist.h> */
#if LINUX_VERSION_CODE <= KERNEL_VERSION(2, 6, 18)
#define for_each_sg(sglist, sg, nr, __i)        \
	for (__i = 0, sg = (sglist); __i < (nr); __i++, (sg)++)
#endif

/* <linux/types.h> */
#if LINUX_VERSION_CODE <= KERNEL_VERSION(2, 6, 18)
typedef unsigned long uintptr_t;
#endif

/* <rdma/ib_sa.h> */
#if defined(HAVE_IB_SA_PATH_REC_GET_MASK_ARG)
static inline int ib_sa_path_rec_get_compat(struct ib_sa_client *client,
					    struct ib_device *device,
					    u8 port_num,
					    struct ib_sa_path_rec *rec,
					    ib_sa_comp_mask comp_mask,
					    int timeout_ms, int retries,
					    void (*callback)(int status,
						struct ib_sa_path_rec *resp,
						void *context),
					    void *context,
					    struct ib_sa_query **query)
{
	return ib_sa_path_rec_get(client, device, port_num, rec, comp_mask,
				  timeout_ms, retries, GFP_KERNEL, callback,
				  context, query);
}
#define ib_sa_path_rec_get ib_sa_path_rec_get_compat
#endif

/* <rdma/ib_verbs.h> */
#ifndef HAVE_IB_DMA_MAP_OPS
static inline int ib_dma_mapping_error(struct ib_device *dev, u64 dma_addr)
{
	return dma_mapping_error(dev->dma_device, dma_addr);
}

static inline u64 ib_dma_map_single(struct ib_device *dev,
				    void *cpu_addr, size_t size,
				    enum dma_data_direction direction)
{
	return dma_map_single(dev->dma_device, cpu_addr, size, direction);
}

static inline void ib_dma_unmap_single(struct ib_device *dev,
				       u64 addr, size_t size,
				       enum dma_data_direction direction)
{
	dma_unmap_single(dev->dma_device, addr, size, direction);
}

static inline u64 ib_dma_map_single_attrs(struct ib_device *dev,
					  void *cpu_addr, size_t size,
					  enum dma_data_direction direction,
					  unsigned long dma_attrs)
{
	return dma_map_single_attrs(dev->dma_device, cpu_addr, size,
				    direction, dma_attrs);
}

static inline void ib_dma_unmap_single_attrs(struct ib_device *dev,
					     u64 addr, size_t size,
					     enum dma_data_direction direction,
					     unsigned long dma_attrs)
{
	return dma_unmap_single_attrs(dev->dma_device, addr, size,
				      direction, dma_attrs);
}

static inline u64 ib_dma_map_page(struct ib_device *dev,
				  struct page *page,
				  unsigned long offset,
				  size_t size,
				  enum dma_data_direction direction)
{
	return dma_map_page(dev->dma_device, page, offset, size, direction);
}

static inline void ib_dma_unmap_page(struct ib_device *dev,
				     u64 addr, size_t size,
				     enum dma_data_direction direction)
{
	dma_unmap_page(dev->dma_device, addr, size, direction);
}

static inline int ib_dma_map_sg(struct ib_device *dev,
				struct scatterlist *sg, int nents,
				enum dma_data_direction direction)
{
	return dma_map_sg(dev->dma_device, sg, nents, direction);
}

static inline void ib_dma_unmap_sg(struct ib_device *dev,
				   struct scatterlist *sg, int nents,
				   enum dma_data_direction direction)
{
	dma_unmap_sg(dev->dma_device, sg, nents, direction);
}

static inline int ib_dma_map_sg_attrs(struct ib_device *dev,
				      struct scatterlist *sg, int nents,
				      enum dma_data_direction direction,
				      unsigned long dma_attrs)
{
	return dma_map_sg_attrs(dev->dma_device, sg, nents, direction,
				dma_attrs);
}

static inline void ib_dma_unmap_sg_attrs(struct ib_device *dev,
					 struct scatterlist *sg, int nents,
					 enum dma_data_direction direction,
					 unsigned long dma_attrs)
{
	dma_unmap_sg_attrs(dev->dma_device, sg, nents, direction, dma_attrs);
}

static inline u64 ib_sg_dma_address(struct ib_device *dev,
				    struct scatterlist *sg)
{
	return sg_dma_address(sg);
}

static inline unsigned int ib_sg_dma_len(struct ib_device *dev,
					 struct scatterlist *sg)
{
	return sg_dma_len(sg);
}

static inline void ib_dma_sync_single_for_cpu(struct ib_device *dev,
					      u64 addr,
					      size_t size,
					      enum dma_data_direction dir)
{
	dma_sync_single_for_cpu(dev->dma_device, addr, size, dir);
}

static inline void ib_dma_sync_single_for_device(struct ib_device *dev,
						 u64 addr,
						 size_t size,
						 enum dma_data_direction dir)
{
	dma_sync_single_for_device(dev->dma_device, addr, size, dir);
}

static inline void *ib_dma_alloc_coherent(struct ib_device *dev,
                                          size_t size,
                                          u64 *dma_handle,
                                          gfp_t flag)
{
	dma_addr_t handle;
	void *ret;

	ret = dma_alloc_coherent(dev->dma_device, size, &handle, flag);
	*dma_handle = handle;
	return ret;
}

static inline void ib_dma_free_coherent(struct ib_device *dev,
					size_t size, void *cpu_addr,
					u64 dma_handle)
{
	dma_free_coherent(dev->dma_device, size, cpu_addr, dma_handle);
}
#endif

/* commit ed082d36 */
#ifndef ib_alloc_pd
static inline struct ib_pd *ib_alloc_pd_backport(struct ib_device *device)
{
	return ib_alloc_pd(device);
}
#define ib_alloc_pd(device, flags)				\
	({							\
		(void)(flags), ib_alloc_pd_backport(device);	\
	})
#endif
/* commit 7083e42e */
#if !defined(HAVE_IB_INC_RKEY)
/**
 * ib_inc_rkey - increments the key portion of the given rkey. Can be used
 * for calculating a new rkey for type 2 memory windows.
 * @rkey - the rkey to increment.
 */
static inline u32 ib_inc_rkey(u32 rkey)
{
	const u32 mask = 0x000000ff;
	return ((rkey + 1) & mask) | (rkey & ~mask);
}
#endif

#if !defined(MOFED_MAJOR) && LINUX_VERSION_CODE < KERNEL_VERSION(4, 2, 0) && \
	(!defined(RHEL_MAJOR) || RHEL_MAJOR -0 < 7 ||			\
	 RHEL_MAJOR -0 == 7 && RHEL_MINOR -0 < 2) ||			\
	defined(MOFED_MAJOR) &&						\
	(MOFED_MAJOR -0 < 3 || MOFED_MAJOR -0 == 3 && MOFED_MINOR -0 < 4)
/* See also commit 4139032b */
static inline u8 rdma_start_port(const struct ib_device *device)
{
       return (device->node_type == RDMA_NODE_IB_SWITCH) ? 0 : 1;
}

static inline u8 rdma_end_port(const struct ib_device *device)
{
       return (device->node_type == RDMA_NODE_IB_SWITCH) ?
               0 : device->phys_port_cnt;
}
#endif

#if (LINUX_VERSION_CODE < KERNEL_VERSION(4, 2, 0) &&  \
	(!defined(RHEL_MAJOR) || RHEL_MAJOR -0 < 7 || \
	 RHEL_MAJOR -0 == 7 && RHEL_MINOR -0 < 2))
/* See also commit 569e247f7aa6 */
enum ib_mr_type {
	IB_MR_TYPE_MEM_REG,
	IB_MR_TYPE_SIGNATURE,
};

static inline struct ib_mr *ib_alloc_mr(struct ib_pd *pd,
					enum ib_mr_type mr_type, u32 max_num_sg)
{
	switch (mr_type) {
	case IB_MR_TYPE_MEM_REG:
		return ib_alloc_fast_reg_mr(pd, max_num_sg);
	case IB_MR_TYPE_SIGNATURE:
	default:
		return ERR_PTR(-ENOSYS);
	}
}
#endif

#if (LINUX_VERSION_CODE < KERNEL_VERSION(4, 2, 0) &&  \
	(!defined(RHEL_MAJOR) || RHEL_MAJOR -0 < 7 || \
	 RHEL_MAJOR -0 == 7 && RHEL_MINOR -0 < 2)) || \
	defined(MOFED_MAJOR)
/* See also commit 2b1b5b60 */
static inline const char *__attribute_const__
ib_event_msg(enum ib_event_type event)
{
	return "(?)";
}

static inline const char *__attribute_const__
ib_wc_status_msg(enum ib_wc_status status)
{
	return "(?)";
}
#endif

#if !defined(HAVE_IB_CREATE_CQ_ATTR_ARG)
/* See also commit bcf4c1ea */
#if !defined(HAVE_IB_CQ_INIT_ATTR)
struct ib_cq_init_attr {
	unsigned int	cqe;
	int		comp_vector;
	u32		flags;
};
#endif

static inline struct ib_cq *ib_create_cq_compat(struct ib_device *device,
			ib_comp_handler comp_handler,
			void (*event_handler)(struct ib_event *, void *),
			void *cq_context,
			const struct ib_cq_init_attr *cq_attr)
{
	return ib_create_cq(device, comp_handler, event_handler, cq_context,
			    cq_attr->cqe, cq_attr->comp_vector);
}
#define ib_create_cq ib_create_cq_compat
#endif

#if !defined(HAVE_IB_QUERY_GID_WITH_ATTR)
#if !defined(HAVE_STRUCT_IB_GID_ATTR)
struct ib_gid_attr {
};
#endif
/* See also commit 55ee3ab2e49a9ead850722ef47698243dd226d16 */
static inline int ib_query_gid_compat(struct ib_device *device,
				      u8 port_num, int index,
				      union ib_gid *gid,
				      struct ib_gid_attr *attr)
{
	memset(attr, 0, sizeof(*attr));
	return ib_query_gid(device, port_num, index, gid);
}
#define ib_query_gid ib_query_gid_compat
#endif

/* <rdma/rdma_cm.h> */
/*
 * commit b26f9b9 (RDMA/cma: Pass QP type into rdma_create_id())
 */
#if LINUX_VERSION_CODE < KERNEL_VERSION(3, 0, 0) && \
	!(defined(RHEL_MAJOR) && RHEL_MAJOR -0 >= 6)
struct rdma_cm_id *rdma_create_id_compat(rdma_cm_event_handler event_handler,
					 void *context,
					 enum rdma_port_space ps,
					 enum ib_qp_type qp_type)
{
	return rdma_create_id(event_handler, context, ps);
}
#define rdma_create_id rdma_create_id_compat
#endif

/* <scsi/scsi.h> */
#if LINUX_VERSION_CODE < KERNEL_VERSION(2, 6, 35) && !defined(FAST_IO_FAIL)
/*
 * commit 2f2eb58 ([SCSI] Allow FC LLD to fast-fail scsi eh by introducing new
 * eh return)
 */
#define FAST_IO_FAIL FAILED
#endif
#if LINUX_VERSION_CODE <= KERNEL_VERSION(2, 6, 18)
#define SCSI_MAX_SG_CHAIN_SEGMENTS (PAGE_SIZE / sizeof(void*))
#endif

/* See also commit 65e8617fba17 */
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 7, 0)
#define SG_MAX_SEGMENTS SCSI_MAX_SG_CHAIN_SEGMENTS
#endif

/* <scsi/scsi_device.h> */
/* See also commit 5d9fb5cc */
#if LINUX_VERSION_CODE < KERNEL_VERSION(3, 5, 0) && \
	!defined(SDEV_TRANSPORT_OFFLINE)
#define SDEV_TRANSPORT_OFFLINE SDEV_OFFLINE
#endif

/* See also commit 1d64508810d8 */
#if (!defined(CONFIG_SUSE_KERNEL) &&				\
	LINUX_VERSION_CODE < KERNEL_VERSION(4, 7, 0)) ||	\
	LINUX_VERSION_CODE < KERNEL_VERSION(4, 4, 0)

#if 	(!defined(RHEL_MAJOR) || (RHEL_MAJOR -0 == 7 && RHEL_MINOR -0 < 3))
enum scsi_scan_mode {
	SCSI_SCAN_INITIAL = 0,
	SCSI_SCAN_RESCAN,
	SCSI_SCAN_MANUAL,
};
#endif
#endif

static inline void scsi_target_unblock_compat(struct device *dev,
					      enum scsi_device_state new_state)
{
#if LINUX_VERSION_CODE < KERNEL_VERSION(3, 5, 0) &&	\
	!defined(CONFIG_SUSE_KERNEL) ||			\
	LINUX_VERSION_CODE < KERNEL_VERSION(3, 0, 76)
	scsi_target_unblock(dev);
#else
	/*
	 * In upstream kernel 3.5.0 and in SLES 11 SP3 and later
	 * scsi_target_unblock() takes two arguments.
	 */
	scsi_target_unblock(dev, new_state);
#endif
}

#define scsi_target_unblock scsi_target_unblock_compat

/* <scsi/scsi_host.h> */
#ifndef HAVE_SCSI_QDEPTH_REASON
/*
 * See also commit e881a172 (modify change_queue_depth to take in reason why it
 * is being called).
 */
enum {
	SCSI_QDEPTH_DEFAULT,	/* default requested change, e.g. from sysfs */
	SCSI_QDEPTH_QFULL,	/* scsi-ml requested due to queue full */
	SCSI_QDEPTH_RAMP_UP,	/* scsi-ml requested due to threshold event */
};
#endif

#endif
