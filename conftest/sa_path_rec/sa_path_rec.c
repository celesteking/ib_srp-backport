#include <linux/stddef.h>
#include <linux/module.h>
#include <rdma/ib_sa.h>

static int modinit(void)
{
	return offsetof(struct sa_path_rec, sgid);
}

module_init(modinit);
