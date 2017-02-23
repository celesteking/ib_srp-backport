#include <linux/module.h>
#include <rdma/ib_verbs.h>

static int modinit(void)
{
	return IB_MR_TYPE_MEM_REG == 0;
}

module_init(modinit);
