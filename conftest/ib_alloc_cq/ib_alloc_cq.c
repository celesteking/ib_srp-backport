#include <linux/module.h>
#include <rdma/ib_verbs.h>

static int modinit(void)
{
	return ib_alloc_cq(NULL, NULL, 0, 0, 0) == 0;
}

module_init(modinit);
