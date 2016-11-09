#include <linux/module.h>
#include <rdma/ib_verbs.h>

static int modinit(void)
{
	return IB_DEVICE_SG_GAPS_REG == 0;
}

module_init(modinit);
