#!/bin/bash
  
CONF="/etc/balance_irq"
[ -f $CONF ] || touch $CONF

cpu_cnt=$(cat /proc/cpuinfo | grep 'model name' | wc -l)
refs=$(cat /proc/interrupts | grep -E 'virtio.-(input|output)' | awk '{print $NF}')
i=1
for ref in $refs;do
    if awk '{print $1}' $CONF | grep -E "^${ref}$" >/dev/null 2>&1;then
        affinity=$(awk "\$1~/^${ref}$/ {print \$2}" $CONF)
        if [ "${affinity}" -gt "${cpu_cnt}" ];then
            affinity=$((i % cpu_cnt))
            sed -e "/${ref}/d" -i $CONF
            echo "${ref} ${affinity}" >> $CONF
        fi
    else
        affinity=$((i % cpu_cnt))
	[ ${affinity} -eq 0 ] && affinity=$cpu_cnt
        echo "${ref} ${affinity}" >> $CONF
    fi
    let i++
done
