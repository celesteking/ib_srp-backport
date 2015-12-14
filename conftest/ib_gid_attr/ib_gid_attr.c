#include <linux/module.h>
#include <rdma/ib_verbs.h>

static int modinit(void)
{
	return sizeof(struct ib_gid_attr);
}

module_init(modinit);
