#HOST=`hostname -f`
HOST=$BMC_HOST

# Please change parameters according to your bare-metal machine
node_id_asus=$( $NOVA_BIN_DIR/nova-bm-manage --config-dir=$BM_CONF  node create --host $HOST  --cpus 1 --memory_mb=4096 --local_gb=60 --pm_address="10.10.30.6" --pm_user=".1.3.6.1.4.1.21728.3.2.1.1.4.0,.1.3.6.1.4.1.21728.3.2.1.1.3.0" --pm_password="savi" --terminal_port=0 --prov_mac_address=08:00:27:C1:CE:BB --type=x86_64)

#node_id_asus=$( $NOVA_BIN_DIR/nova-bm-manage --config-dir=$BM_CONF  node create --host $HOST --cpus 1 --memory_mb=16392 --local_gb=60 --pm_address="10.10.30.6" --pm_user=".1.3.6.1.4.1.21728.3.2.1.1.4.4,.1.3.6.1.4.1.21728.3.2.1.1.3.4" --pm_password="savi" --terminal_port=0 --prov_mac_address=10:bf:48:83:5a:cb --type=x86_64)
#node_id_volume=$( $NOVA_BIN_DIR/nova-bm-manage --config-dir=$BM_CONF  node create --host $HOST --cpus 1 --memory_mb=4096 --local_gb=60 --pm_address="10.10.30.6" --pm_user=".1.3.6.1.4.1.21728.3.2.1.1.4.1,.1.3.6.1.4.1.21728.3.2.1.1.3.1" --pm_password="savi" --terminal_port=0 --prov_mac_address=00:14:22:44:16:22 --type=i686)

# Please change parameters according to your bare-metal machine
#$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BM_CONF  interface create --node_id=$node_id_asus --mac_address=68:05:CA:01:39:C3 --datapath_id=0x0 --port_no=0
$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BM_CONF  interface create --node_id=$node_id_asus --mac_address=08:00:27:A5:BE:3F --datapath_id=0x0 --port_no=0
#$NOVA_BIN_DIR/nova-bm-manage --config-dir=$BM_CONF  interface create --node_id=$node_id_volume --mac_address=00:50:DA:05:E4:D6 --datapath_id=0x0 --port_no=0

