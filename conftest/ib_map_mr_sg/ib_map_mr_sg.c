#include <linux/module.h>
#include <rdma/ib_verbs.h>

static int modinit(void)
{
	return ib_map_mr_sg(NULL, NULL, 0, NULL, 0) == 0;
}

module_init(modinit);
