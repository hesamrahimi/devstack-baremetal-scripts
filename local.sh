set -x

TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/stackrc
source $TOP_DIR/functions
DEST=${DEST:-/opt/stack}
source $TOP_DIR/openrc

NOVA_DIR=$DEST/nova
if [ -d $NOVA_DIR/bin ] ; then
    NOVA_BIN_DIR=$NOVA_DIR/bin
else
    NOVA_BIN_DIR=/usr/local/bin
fi
MYSQL_USER=${MYSQL_USER:-root}
BM_PXE_INTERFACE=${BM_PXE_INTERFACE:-eth1}
BM_PXE_PER_NODE=`trueorfalse False $BM_PXE_PER_NODE`

$NOVA_BIN_DIR/nova-manage instance_type create --name=baremetal.small --cpu=2 --memory=2048 --root_gb=40 --ephemeral_gb=20 --swap=2048 --rxtx_factor=1
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=baremetal.small --key cpu_arch --value x86_64

$NOVA_BIN_DIR/nova-manage instance_type create --name=baremetal.medium --cpu=1 --memory=4096 --root_gb=40 --ephemeral_gb=20 --swap=2048 --rxtx_factor=1
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=baremetal.medium --key cpu_arch --value x86_64

$NOVA_BIN_DIR/nova-manage instance_type create --name=baremetal.minimum --cpu=1 --memory=1 --root_gb=40 --ephemeral_gb=0 --swap=2048 --rxtx_factor=1
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=baremetal.minimum --key cpu_arch --value x86_64

$NOVA_BIN_DIR/nova-manage instance_type create --name=baremetal32.minimum --cpu=1 --memory=1 --root_gb=40 --ephemeral_gb=0 --swap=2048 --rxtx_factor=1
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=baremetal32.minimum --key cpu_arch --value i686

$NOVA_BIN_DIR/nova-manage instance_type set_key --name=m1.tiny --key cpu_arch --value virtual
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=m1.small --key cpu_arch --value virtual
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=m1.medium --key cpu_arch --value virtual
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=m1.large --key cpu_arch --value virtual
$NOVA_BIN_DIR/nova-manage instance_type set_key --name=m1.xlarge --key cpu_arch --value virtual

apt_get install dnsmasq syslinux ipmitool qemu-kvm open-iscsi snmp

apt_get install busybox tgt

BMIB_REPO=https://github.com/hesamrahimi/baremetal-initrd-builder.git
BMIB_DIR=$DEST/barematal-initrd-builder
BMIB_BRANCH=silver
git_clone $BMIB_REPO $BMIB_DIR $BMIB_BRANCH

KERNEL=~/deploy_kernel
RAMDISK=~/deploy_ramdisk

if [ ! -f "$RAMDISK" ]; then
(
        KERNEL_VER=`uname -r`
        KERNEL_=/boot/vmlinuz-$KERNEL_VER
        sudo cp "$KERNEL_" "$KERNEL"
        sudo chmod a+r "$KERNEL"
	cd "$BMIB_DIR"
        ./baremetal-mkinitrd.sh "$RAMDISK" "$KERNEL_VER"
)
fi

GLANCE_HOSTPORT=${GLANCE_HOSTPORT:-$GLANCE_HOST:9292}

TOKEN=$(keystone  token-get | grep ' id ' | get_field 2)
KERNEL_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-deployment-kernel" --public --container-format aki --disk-format aki < "$KERNEL" | grep ' id ' | get_field 2)
echo "$KERNEL_ID"

RAMDISK_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-deployment-ramdisk" --public --container-format ari --disk-format ari < "$RAMDISK" | grep ' id ' | get_field 2)
echo "$RAMDISK_ID"

echo "building ubuntu image"
IMG=$DEST/ubuntu.img

./build-ubuntu-image.sh "$IMG" "$DEST"

REAL_KERNEL_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-real-kernel" --public --container-format aki --disk-format aki < "$DEST/kernel" | grep ' id ' | get_field 2)

REAL_RAMDISK_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-real-ramdisk" --public --container-format ari --disk-format ari < "$DEST/initrd" | grep ' id ' | get_field 2)

glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "Ubuntu" --public --container-format bare --disk-format raw --property kernel_id=$REAL_KERNEL_ID --property ramdisk_id=$REAL_RAMDISK_ID < "$IMG"


KERNEL_32=~/kernel32
RAMDISK_32=~/ramdisk32
IMG_32=~/ubuntu32.img

REAL_KERNEL_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-32-real-kernel" --public --container-format aki --disk-format aki < "$KERNEL_32" | grep ' id ' | get_field 2)

REAL_RAMDISK_ID=$(glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "baremetal-32-real-ramdisk" --public --container-format ari --disk-format ari < "$RAMDISK_32" | grep ' id ' | get_field 2)

glance --os-auth-token $TOKEN --os-image-url http://$GLANCE_HOSTPORT image-create --name "Ubuntu32" --public --container-format bare --disk-format raw --property kernel_id=$REAL_KERNEL_ID --property ramdisk_id=$REAL_RAMDISK_ID < "$IMG_32"



TFTPROOT=$DEST/tftproot

if [ -d "$TFTPROOT" ]; then
    rm -r "$TFTPROOT"
fi
mkdir "$TFTPROOT"
cp /usr/lib/syslinux/pxelinux.0 "$TFTPROOT"
mkdir $TFTPROOT/pxelinux.cfg

DNSMASQ_PID=/dnsmasq.pid
if [ -f "$DNSMASQ_PID" ]; then
    sudo kill `cat "$DNSMASQ_PID"`
    sudo rm "$DNSMASQ_PID"
fi
sudo /etc/init.d/dnsmasq stop
sudo sudo update-rc.d dnsmasq disable
if [ "$BM_PXE_PER_NODE" = "False" ]; then
    sudo dnsmasq --conf-file= --port=0 --enable-tftp --tftp-root=$TFTPROOT --dhcp-boot=pxelinux.0 --bind-interfaces --pid-file=$DNSMASQ_PID --interface=$BM_PXE_INTERFACE --dhcp-range=10.10.41.150,10.10.41.254
fi

mkdir -p $NOVA_DIR/baremetal/console
mkdir -p $NOVA_DIR/baremetal/dnsmasq

OWNER=`whoami`
BM_CONF=/etc/nova-bm

if [ -d "$BM_CONF" ]; then
 echo "nova-bm conf dir exist"
 sudo rm "$BM_CONF" -rf
fi

sudo mkdir $BM_CONF
sudo chown $OWNER:root $BM_CONF -R

sudo cp -p /etc/nova/* $BM_CONF -rf

inicomment $BM_CONF/nova.conf DEFAULT firewall_driver

function iso() {
    iniset /etc/nova/nova.conf DEFAULT "$1" "$2"
}

function is() {
    iniset $BM_CONF/nova.conf DEFAULT "$1" "$2"
}

BMC_HOST=`hostname -f`
BMC_HOST=bmc-$BMC_HOST

is baremetal_sql_connection mysql://$MYSQL_USER:$MYSQL_PASSWORD@127.0.0.1/nova_bm
is compute_driver nova.virt.baremetal.driver.BareMetalDriver
is baremetal_driver nova.virt.baremetal.pxe.PXE
#is power_manager nova.virt.baremetal.ipmi-fake.Ipmi
#comment the above line and uncomment the next line if you want to use netbooter
is power_manager nova.virt.baremetal.snmp.SnmpNetBoot
is instance_type_extra_specs cpu_arch:x86_64
is baremetal_tftp_root $TFTPROOT
#is baremetal_term /usr/local/bin/shellinaboxd
is baremetal_deploy_kernel $KERNEL_ID
is baremetal_deploy_ramdisk $RAMDISK_ID
is scheduler_host_manager nova.scheduler.baremetal_host_manager.BaremetalHostManager
iso scheduler_host_manager nova.scheduler.baremetal_host_manager.BaremetalHostManager
is baremetal_pxe_vlan_per_host $BM_PXE_PER_NODE
is baremetal_pxe_parent_interface $BM_PXE_INTERFACE
is firewall_driver ""
is host $BMC_HOST
iso host `hostname -f`

mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'DROP DATABASE IF EXISTS nova_bm;'
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e 'CREATE DATABASE nova_bm CHARACTER SET latin1;'

# workaround for invalid compute_node that non-bare-metal nova-compute has left
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD nova -e 'DELETE FROM compute_nodes;'

$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BM_CONF db sync
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BM_CONF pxe_ip create --cidr 10.10.41.0/24

if [ -f ./bm-nodes.sh ]; then
    . ./bm-nodes.sh
fi

NL=`echo -ne '\015'`

echo "restarting nova-scheduler"
screen -S stack -p n-sch -X kill
screen -S stack -X screen -t n-sch
sleep 1.5
screen -S stack -p n-sch -X stuff "cd $NOVA_DIR && $NOVA_BIN_DIR/nova-scheduler --config-dir=$BM_CONF $NL"
sleep 5

echo "restarting nova-compute"
screen -S stack -p n-cpu -X kill
screen -S stack -X screen -t n-cpu
sleep 1.5
screen -S stack -p n-cpu -X stuff "cd $NOVA_DIR && sg libvirtd \"$NOVA_BIN_DIR/nova-compute --config-dir=/etc/nova\" $NL"

echo "starting bm_deploy_server"
screen -S stack -p n-bmd -X kill
screen -S stack -X screen -t n-bmd
sleep 1.5
screen -S stack -p n-bmd -X stuff "cd $NOVA_DIR && $NOVA_BIN_DIR/bm_deploy_server --config-dir=$BM_CONF $NL"

echo "starting baremetal nova-compute"
screen -S stack -p n-cpu-bm -X kill
screen -S stack -X screen -t n-cpu-bm
sleep 1.5
screen -S stack -p n-cpu-bm -X stuff "cd $NOVA_DIR && sg libvirtd \"$NOVA_BIN_DIR/nova-compute --config-dir=$BM_CONF\" $NL"

echo "done baremetal local.sh"
