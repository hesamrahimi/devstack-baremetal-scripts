# Please change parameters according to your bare-metal machine
node_id=$( $NOVA_BIN_DIR/nova-bm-manage node create --host `hostname` --cpus 2 --memory_mb=2048 --local_gb=32 --pm_address=10.10.10.223 --pm_user=test --pm_password=password --terminal_port=0 --prov_mac_address=08:00:27:61:C9:F4 )

# Please change parameters according to your bare-metal machine
$NOVA_BIN_DIR/nova-bm-manage interface create --node_id=$node_id --mac_address=08:00:27:4C:AE:A2 --datapath_id=0x0 --port_no=0
#$NOVA_BIN_DIR/nova-bm-manage interface create --node_id=$node_id --mac_address=00:15:17:73:06:83 --datapath_id=0x0 --port_no=0

#0800275BC2F5
#0800274C35B6
