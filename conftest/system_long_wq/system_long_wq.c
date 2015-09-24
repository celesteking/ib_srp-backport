#include <linux/module.h>
#include <linux/workqueue.h>

static int modinit(void)
{
	return !!system_long_wq;
}

module_init(modinit);
