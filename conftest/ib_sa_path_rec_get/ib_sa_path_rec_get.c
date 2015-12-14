#include <linux/module.h>
#include <rdma/ib_sa.h>

static int modinit(void)
{
	return ib_sa_path_rec_get(NULL, NULL, 0, NULL, 0, 0, 0, 0, NULL, NULL,
				  NULL) != 0;
}

module_init(modinit);
