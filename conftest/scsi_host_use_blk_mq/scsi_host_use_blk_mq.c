#include <linux/module.h>
#include <scsi/scsi_host.h>

static int modinit(void)
{
	return ((struct Scsi_Host *)NULL)->use_blk_mq;
}

module_init(modinit);
