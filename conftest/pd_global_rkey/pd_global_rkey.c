#include <linux/module.h>
#include <rdma/ib_verbs.h>

static int modinit(void)
{
	struct ib_pd pd = { .unsafe_global_rkey = 0x123456fe };

	return pd.unsafe_global_rkey;
}

module_init(modinit);
