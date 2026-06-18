#!/data/data/com.termux/files/usr/bin/bash

# Exit when any command fails
set -e

echo "=== SSHLog Termux One-Click Installer ==="

# 1. Install system packages
echo "Installing system packages..."
pkg update
pkg install -y cmake clang make libelf libelf-static zlib zlib-static libcap libcap-static pkg-config binutils python python-pip argp argp-static git libzmq

# 2. Setup standalone bpftool
echo "Setting up bpftool..."
if [ ! -d "bpftool" ]; then
  git clone --recurse-submodules https://github.com/libbpf/bpftool.git bpftool
fi

cd bpftool
# Apply patches to bpftool to make it compile on Android/Termux
# Patch compiler-gcc.h
sed -i 's/#ifndef _LINUX_COMPILER_H_/\/* Bypass compiler guard check *\/\n#if 0/g' include/linux/compiler-gcc.h
sed -i 's/#error "Please don'\''t include <linux\/compiler-gcc.h> directly, include <linux\/compiler.h> instead."/#endif/g' include/linux/compiler-gcc.h

# Patch btf.c to inject qsort_r compatibility
if ! grep -q "qsort_r_wrapper" src/btf.c; then
  sed -i '/#include "main.h"/a \
#ifdef __ANDROID__\nstatic __thread void *qsort_r_ctx;\nstatic __thread int (*qsort_r_compar)(const void *, const void *, void *);\n\nstatic int qsort_r_wrapper(const void *a, const void *b) {\n    return qsort_r_compar(a, b, qsort_r_ctx);\n}\n\nstatic void qsort_r(void *base, size_t nmemb, size_t size,\n                    int (*compar)(const void *, const void *, void *),\n                    void *arg) {\n    void *old_ctx = qsort_r_ctx;\n    int (*old_compar)(const void *, const void *, void *) = qsort_r_compar;\n    qsort_r_ctx = arg;\n    qsort_r_compar = compar;\n    qsort(base, nmemb, size, qsort_r_wrapper);\n    qsort_r_ctx = old_ctx;\n    qsort_r_compar = old_compar;\n}\n#endif' src/btf.c
fi

cd src
make -j$(nproc)
cp bpftool /data/data/com.termux/files/usr/bin/bpftool
cd ../..

# 3. Build libsshlog.so
echo "Building libsshlog..."
mkdir -p build
cd build
cmake ..
make -j$(nproc)
cp libsshlog/libsshlog.so /data/data/com.termux/files/usr/lib/
ln -sf /data/data/com.termux/files/usr/lib/libsshlog.so /data/data/com.termux/files/usr/lib/libsshlog.so.1
cd ..

# 4. Install python dependencies
echo "Installing Python dependencies..."
pip install "blinker==1.7.0" "dataclasses-json==0.6.4" "datadog==0.49.1" "orjson==3.9.15" "prettytable==3.10.0" "PyYAML==6.0.1" "pyzmq==25.1.2" "requests==2.31.0" "syslog-py==0.2.5" "timeago==1.0.16" "Flask==3.0.2" "Flask-SocketIO==5.3.6" "simple-websocket==1.0.0" --break-system-packages

# 5. Create directory structure and copy configs
echo "Setting up directories and configs..."
mkdir -p /data/data/com.termux/files/usr/etc/sshlog/conf.d
mkdir -p /data/data/com.termux/files/usr/etc/sshlog/plugins
mkdir -p /data/data/com.termux/files/usr/etc/sshlog/samples
mkdir -p /data/data/com.termux/files/usr/var/log/sshlog
chmod 700 /data/data/com.termux/files/usr/var/log/sshlog

cp daemon/config_samples/*.yaml /data/data/com.termux/files/usr/etc/sshlog/samples/
cp /data/data/com.termux/files/usr/etc/sshlog/samples/log_all_sessions.yaml /data/data/com.termux/files/usr/etc/sshlog/conf.d/
cp /data/data/com.termux/files/usr/etc/sshlog/samples/log_events.yaml /data/data/com.termux/files/usr/etc/sshlog/conf.d/

# Update paths in sample configs to use Termux prefix
sed -i "s|'/var/log/sshlog/sessions/'|'/data/data/com.termux/files/usr/var/log/sshlog/sessions/'|g" /data/data/com.termux/files/usr/etc/sshlog/conf.d/log_all_sessions.yaml
sed -i "s|/var/log/sshlog/event.log|/data/data/com.termux/files/usr/var/log/sshlog/event.log|g" /data/data/com.termux/files/usr/etc/sshlog/conf.d/log_events.yaml

# 6. Create Wrapper scripts dynamically
echo "Writing wrapper executables..."
SCRIPT_DIR=$(pwd)

cat << EOF > /data/data/com.termux/files/usr/bin/sshlogd
#!/data/data/com.termux/files/usr/bin/bash
export PYTHONPATH=${SCRIPT_DIR}/daemon
exec python3 ${SCRIPT_DIR}/daemon/daemon.py "\$@"
EOF

cat << EOF > /data/data/com.termux/files/usr/bin/sshlog
#!/data/data/com.termux/files/usr/bin/bash
export PYTHONPATH=${SCRIPT_DIR}/daemon
exec python3 ${SCRIPT_DIR}/daemon/client.py "\$@"
EOF

chmod +x /data/data/com.termux/files/usr/bin/sshlogd /data/data/com.termux/files/usr/bin/sshlog

echo "==========================================="
echo "SSHLog successfully installed on Termux!"
echo "Run with 'sshlogd' (as root) and 'sshlog'."
echo "==========================================="
