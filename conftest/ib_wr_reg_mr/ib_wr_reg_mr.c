#include <linux/module.h>
#include <rdma/ib_verbs.h>

static int modinit(void)
{
	return IB_WR_REG_MR == 0;
}

module_init(modinit);
