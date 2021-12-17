#!/bin/bash

HOSTAPDCLI_FILE=`mktemp /tmp/802.1x_handlerXXXXXXX.sh`
interfaces="";
conffiles="";
i=0;

echo $HOSTAPDCLI_FILE
cat <<EOF > $HOSTAPDCLI_FILE
#!/bin/bash

IF=\$1
ACTION=\$2
MAC=\$3

if [[ \$ACTION == "AP-STA-CONNECTED" ]]
then
echo "connected"
tc filter add block 1 ingress prio 92 flower skip_sw src_mac \$MAC indev \$IF action pass
fi

if [[ \$ACTION == "AP-STA-DISCONNECTED" ]]
then
echo "disconnected"
tc filter delete block 1 ingress prio 92 flower skip_sw src_mac \$MAC indev \$IF action pass
fi
EOF

for interface in "$@"
do
        if [[ $i == 0 ]]
        then
        interfaces="$interface";
        conffiles="/etc/hostapd.conf.$interface";
        else
        interfaces="$interfaces,$interface";
        conffiles="$conffiles /etc/hostapd.conf.$interface";
        fi
        i+=1;
        echo "Adding $interface to tc block processing..."
        tc qdisc add dev $interface ingress_block 1 ingress
done

tc filter add block 1 parent ffff: prio 93 flower skip_sw action drop
tc filter add block 1 parent ffff: prio 91 protocol 0x888e flower skip_sw dst_mac 01:80:c2:00:00:03 action trap
tc filter add block 1 parent ffff: prio 90 protocol 0x888e flower skip_sw action trap

hostapd -i $interfaces $conffiles -S
hostapd_cli -B -a $HOSTAPDCLI_FILE

tc filter del block 1 parent ffff: prio 93 flower skip_sw action drop
tc filter del block 1 parent ffff: prio 91 protocol 0x888e flower skip_sw dst_mac 01:80:c2:00:00:03 action trap
tc filter del block 1 parent ffff: prio 90 protocol 0x888e flower skip_sw action trap

for interface in "$@"
do
        echo "Removing $interface from tc block processing..."
        tc qdisc del dev $interface ingress_block 1 ingress
done

rm $HOSTAPDCLI_FILE
