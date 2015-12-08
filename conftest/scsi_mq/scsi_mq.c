#include <linux/module.h>
#include <scsi/scsi_host.h>

static int modinit(void)
{
	return offsetof(struct Scsi_Host, nr_hw_queues);
}

module_init(modinit);
