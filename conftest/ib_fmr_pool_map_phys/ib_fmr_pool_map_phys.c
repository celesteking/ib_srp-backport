#include <linux/module.h>
#include <rdma/ib_fmr_pool.h>

static int modinit(void)
{
	struct ib_pool_fmr *p;

	p = ib_fmr_pool_map_phys(NULL, NULL, 0, 0, NULL);

	return p != 0;
}

module_init(modinit);
