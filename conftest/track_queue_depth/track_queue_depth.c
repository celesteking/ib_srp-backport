#include <linux/module.h>
#include <scsi/scsi_host.h>

static int modinit(void)
{
	struct scsi_host_template t = { .track_queue_depth = 1 };

	return t.track_queue_depth;
}

module_init(modinit);
