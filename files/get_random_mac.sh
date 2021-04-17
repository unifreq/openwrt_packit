#!/bin/bash
  
get_random_mac ()
{
    # MAC地址第一段可在 02 06 0A 0E 中任选一个
    if [ "$SHELL" == "/bin/bash" ];then
        #MACADDR=$(printf "%02X:%02X:%02X:%02X:%02X:%02X\n" $[RANDOM%255] $[RANDOM%255] $[RANDOM%255] $[RANDOM%255] $[RANDOM%255] $[RANDOM%255])
        MACADDR=$(printf "06:%02X:%02X:%02X:%02X:%02X\n" $[RANDOM%255] $[RANDOM%255] $[RANDOM%255] $[RANDOM%255] $[RANDOM%255])
    else
        uuid=$(cat /proc/sys/kernel/random/uuid)
        mac1="0E"
        #mac1=${uuid:24:2}
        mac2=${uuid:26:2}
        mac3=${uuid:28:2}
        mac4=${uuid:30:2}
        mac5=${uuid:32:2}
        mac6=${uuid:34:2}
        MACADDR=$(echo "$mac1:$mac2:$mac3:$mac4:$mac5:$mac6" | tr '[a-z]' '[A-Z]')
    fi
}

get_random_mac
echo $MACADDR
