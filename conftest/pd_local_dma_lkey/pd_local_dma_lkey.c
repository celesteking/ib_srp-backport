#include <linux/module.h>
#include <rdma/ib_verbs.h>

static int modinit(void)
{
	struct ib_pd pd = { .local_dma_lkey = 0x123456fe };

	return pd.local_dma_lkey;
}

module_init(modinit);
