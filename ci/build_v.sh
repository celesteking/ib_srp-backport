#!/bin/bash

config_disable="				\
CONFIG_BINARY_PRINTF				\
CONFIG_BLK_DEV_IO_TRACE				\
CONFIG_BRANCH_PROFILE_NONE			\
CONFIG_CONTEXT_SWITCH_TRACER			\
CONFIG_DEBUG_STRICT_USER_COPY_CHECKS		\
CONFIG_DYNAMIC_FTRACE				\
CONFIG_EVENT_TRACE_TEST_SYSCALLS		\
CONFIG_EVENT_TRACING				\
CONFIG_FTRACE					\
CONFIG_FTRACE_MCOUNT_RECORD			\
CONFIG_FTRACE_NMI_ENTER				\
CONFIG_FTRACE_SELFTEST				\
CONFIG_FTRACE_STARTUP_TEST			\
CONFIG_FTRACE_SYSCALLS				\
CONFIG_FUNCTION_GRAPH_TRACER			\
CONFIG_FUNCTION_PROFILER			\
CONFIG_FUNCTION_TRACER				\
CONFIG_GENERIC_TRACER				\
CONFIG_HAVE_FTRACE_NMI_ENTER			\
CONFIG_HEADERS_CHECK				\
CONFIG_IRQSOFF_TRACER				\
CONFIG_IWLWIFI_DEVICE_TRACING			\
CONFIG_IWM_TRACING				\
CONFIG_KASAN					\
CONFIG_KVM_MMU_AUDIT				\
CONFIG_MAC80211_DRIVER_API_TRACER		\
CONFIG_MMIOTRACE				\
CONFIG_NET_DROP_MONITOR				\
CONFIG_NOP_TRACER				\
CONFIG_SCHED_TRACER				\
CONFIG_STACK_TRACER				\
CONFIG_STACK_VALIDATION				\
CONFIG_TRACEPOINTS				\
CONFIG_TRACER_MAX_TRACE				\
CONFIG_TRACING					\
CONFIG_UBSAN					\
CONFIG_X86_32					\
CONFIG_X86_X32					\
"

patch_kernel() {
    local v=$1

    case "$v" in
	v4.7|v4.8|v4.9|v4.10)
	    patch -p1 <<EOF
diff --git a/include/linux/fs.h b/include/linux/fs.h
index dd288148a6b1..31733c040839 100644
--- a/include/linux/fs.h
+++ b/include/linux/fs.h
@@ -2650,7 +2650,7 @@ static const char * const kernel_read_file_str[] = {
 
 static inline const char *kernel_read_file_id_str(enum kernel_read_file_id id)
 {
-	if (id < 0 || id >= READING_MAX_ID)
+	if (id >= READING_MAX_ID)
 		return kernel_read_file_str[READING_UNKNOWN];
 
 	return kernel_read_file_str[id];
EOF
	    ;;
	*)
	    ;;
    esac
}

v=$1
(
    # The ib_srp-backport build process needs Modules.symvers. Provide a
    # dummy replacement instead of building 'vmlinux'.
    [ -n "$v" ] &&
	rm -rf "linux-$v" &&
	git clone -n linux-kernel "linux-$v" &&
	cd "linux-$v" &&
	git checkout "$v" -b "linux-$v" &&
	patch_kernel "$v" &&
	make allmodconfig &&
	for c in $config_disable; do
	    sed -i.tmp "s/^$c=[ym]\$/$c=n/" .config
	done &&
	make -s oldconfig </dev/null &>/dev/null &&
	make modules_prepare &&
	touch Modules.symvers &&
	touch Module.symvers
) && {
    make clean &&
	make KDIR="$PWD/linux-$v" W=1 C=2 CF=-D__CHECK_ENDIAN__ KCFLAGS=-Werror
}

rc=$?

rm -rf "linux-$v"

exit $rc
