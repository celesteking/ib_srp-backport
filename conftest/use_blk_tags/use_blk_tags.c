#include <linux/module.h>
#include <scsi/scsi_host.h>

static int modinit(void)
{
	struct scsi_host_template t = { .use_blk_tags = 1 };

	return t.use_blk_tags;
}

module_init(modinit);
