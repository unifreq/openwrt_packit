#!/bin/sh

echo "$$" > /tmp/time_access.pid
program_id=${0##*/}
if ps | grep $program_id | grep -v grep | grep -v $$ >/dev/null;then
	echo "已有其它实例在运行中"
	exit 0
fi

# rules 配置文件格式
# ip地址(或mac地址)|通网时长(单位:秒)|断网时长(单位:秒)|是否启用(Y or N)
rules_file="/etc/time_access.rules"

rule_prefix="Drop_"
log_file="/tmp/time_access.log"
log_maxlines=200
control_file="/tmp/time_access.ctl"

ip_drop_forward() {
	local ip=$1
	local begin_sec=$2
	comment=$(iptables -nL | grep "${rule_prefix}${ip}_" | awk '{print $7}')
	# 如果规则不存在，就新增规则
	if [ "$comment" == "" ];then
		iptables -I FORWARD -s ${ip}/32 -j DROP -m comment --comment "${rule_prefix}${ip}_${begin_sec}"
	fi
}

ip_allow_forward() {
	local ip=$1
	comment=$(iptables -nL | grep "${rule_prefix}${ip}_" | awk '{print $7}')
	# 如果规则已存在，就删掉规则
	if [ "$comment" != "" ];then
		local begin_sec=$(echo $comment | awk -F '_' '{print $3}')
		iptables -D FORWARD -s ${ip}/32 -j DROP -m comment --comment "${rule_prefix}${ip}_${begin_sec}"
	fi
}

ip_get_fw_status() {
	local ip=$1
	local ret=$(iptables -t filter -nL | grep "${rule_prefix}${ip}_" | wc -l)
	if [ $ret -eq 0 ];then
		echo "allowed"
	else
		echo "banned"
	fi
}

ip_get_ping_status() {
	local ip=$1
	local ret=$(ping -c 3 ${ip} | tail -n1 | awk '{print $7}')
	if [ "$ret" == "100%" ];then
		echo "offline"
	else  
		echo "online"
	fi
}

execute_rule() {
	local ip=$1
	local max_online_secs=$2
	local max_offline_secs=$3

	# 截断日志
	[ ! -f $log_file ] &&  touch $log_file
	local log_lines=$(wc -l < $log_file)
	[ $log_lines -gt $log_maxlines ] && >$log_file

	# 当前时间
	cur_date=$(date '+%Y-%m-%d %H:%M:%S')
	# 当前秒数累计
	local cur_sec=$(date '+%s')

	ping_status=$(ip_get_ping_status $ip)
	# 如果 ip 不在线, 则直接返回
	if [ "$ping_status" == "offline" ];then
		echo "$cur_date : $ip : $ping_status" | tee -a $log_file
		return
	fi

	local last_msg=$(cat ${control_file} | grep "${ip}_" | tail -n1)
	# 如果找不到最近的状态, 则生成一条新状态
	if [ "$last_msg" == "" ];then
		# 放行该ip
		ip_allow_forward ${ip}

		# 更新状态
		echo "${ip}_allow_${cur_sec}" >> ${control_file}

		# 记录日志
		echo "$cur_date : Allow this ip [${ip}] to connect the network." >> $log_file
		return
	fi

	local last_rule=$(echo $last_msg | awk -F '_' {'print $2'})
	local last_start_sec=$(echo $last_msg | awk -F '_' '{print $3}')
  
	if [ "$last_rule" == "allow" ];then
		# 如果当前是允许上网的
		local online_secs=$(( cur_sec - last_start_sec ))
		# 如果上网时长已超过规定值
		if [ ${online_secs} -ge ${max_online_secs} ];then
			# 禁止该ip
			ip_drop_forward $ip ${cur_sec}

			# 更新状态
			sed -e "/${ip}_/d" -i ${control_file}
			echo "${ip}_drop_${cur_sec}" >> ${control_file}

			# 记录日志
			echo "$cur_date : This ip [${ip}] is not allowed to connect to the network." >> $log_file
			return
		else
			# 时间没到，继续允许上网
			local cur_fw_status=$(ip_get_fw_status ${ip})
			[ "$cur_fw_status" == "banned" ] && ip_allow_forward $ip
		fi
	else
		# 如果当前是禁止上网的
		local offline_secs=$(( cur_sec - last_start_sec ))
		# 如果断网时长已超过规定值
		if [ ${offline_secs} -ge ${max_offline_secs} ];then
			# 放行该ip
			ip_allow_forward $ip

			# 更新状态
			sed -e "/${ip}_/d" -i ${control_file}
			echo "${ip}_allow_${cur_sec}" >> ${control_file}

			# 记录日志
			echo "$cur_date : Allow this ip [${ip}] to connect the network." >> $log_file
			return
		else
			# 时间没到，继续断网
			local cur_fw_status=$(ip_get_fw_status ${ip})
			[ "$cur_fw_status" == "allowed" ] && ip_drop_forward $ip
		fi
	fi
}

init() {
	if [ -f "${rules_file}" ];then
		RULES=$(cat ${rules_file})
	else
		cat <<EOF
规则文件 ${rules_file} 不存在，请先创建一个！
格式：
ip地址或mac地址|通网时长(单位:秒)|断网时长(单位:秒)|是否启用(Y or N)
EOF
		exit 1
	fi

	rm -f $log_file $control_file
	touch $log_file $control_file 
	#放行所有ip
	for rule in $RULES;do
		ip_or_mac=$(echo $rule | awk -F '|' '{print $1}')
		ip=$(mac2ip $ip_or_mac)
		if [ "$ip" == "unknown" ];then
			cur_date=$(date '+%Y-%m-%d %H:%M:%S')
			echo "$cur_date : [${ip_or_mac}] ip地址不规范或 mac 地址找不到对应的 ip 地址" | tee -a $log_file
			continue
		fi
		ip_allow_forward $ip
	done
}

on_trap_exit() {
	echo "程序被中断，现在将放行所有 ip 地址 ..."
	#放行所有ip
	for rule in $RULES;do
		ip_or_mac=$(echo $rule | awk -F '|' '{print $1}')
		ip=$(mac2ip $ip_or_mac)
		if [ "$ip" == "unknown" ];then
			cur_date=$(date '+%Y-%m-%d %H:%M:%S')
			echo "$cur_date : [${ip_or_mac}] ip地址不规范或 mac 地址找不到对应的 ip 地址" | tee -a $log_file
			continue
		fi
		echo "放行 $ip"
		ip_allow_forward $ip
	done
	echo "下次再见"
	exit 0
}

mac2ip() {
	local ip_or_mac=$1
	local ip
	if echo $ip_or_mac | grep -o -E '^[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}$' > /dev/null ;then
		ip=$(grep "$ip_or_mac" /proc/net/arp | awk '$3~/0x2/ {print $1}' | head -n1)
		if [ "$ip" == "" ];then
			ip="unknown"
		fi
	elif echo $ip_or_mac | grep -o -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' > /dev/null;then
		ip=$ip_or_mac
	else
		ip="unknown"
	fi
	echo $ip
}

# 初始化
init
trap "on_trap_exit" 2 3 15

loop1_sleep=5
loop2_sleep=1
# 主循环 永远
while : ;do
	# 刷新规则
	if [ -f "${rules_file}" ];then
		RULES=$(cat ${rules_file})
	else
		echo "规则文件 ${rules_file} 被删除了？"
		exit 1
	fi
	# 第二重循环 每个ip地址执行一次
	for rule in $RULES;do
		ip_or_mac=$(echo $rule | awk -F '|' '{print $1}' | tr 'A-Z' 'a-z')
		ip=$(mac2ip $ip_or_mac)
		if [ "$ip" == "unknown" ];then
			cur_date=$(date '+%Y-%m-%d %H:%M:%S')
			echo "$cur_date : [${ip_or_mac}] ip地址不规范或 mac 地址找不到对应的 ip 地址" | tee -a $log_file
			continue
		fi
		online_secs=$(echo $rule | awk -F '|' '{print $2}')
		offline_secs=$(echo $rule | awk -F '|' '{print $3}')
		rule_enabled=$(echo $rule | awk -F '|' '{print $4}')

		# 如果该规则已禁用，则允许 ip 联网
		if [ "$rule_enabled" == "N" ] || [ "$rule_enabled" == "n" ];then
			ip_allow_forward $ip
		else
			# 执行预定规则
			execute_rule $ip $online_secs $offline_secs
		fi
		sleep $loop2_sleep
	done
	sleep $loop1_sleep
done
