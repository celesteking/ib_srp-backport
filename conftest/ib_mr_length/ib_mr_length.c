#include <linux/module.h>
#include <rdma/ib_verbs.h>

static int modinit(void)
{
	return offsetof(struct ib_mr, length);
}

module_init(modinit);
