#!/bin/bash

sleep 60

for i in `ip addr  | grep eth | grep mtu | awk -F ':' '{print $2}' | awk '{print $1}'`;do
    ifconfig $i mtu 8240 2>/dev/null 1>/dev/null
    queue=`ethtool -l $i | grep -i Pre -A 5 | grep Combined | awk '{print $2}'` 2>/dev/null 1>/dev/null
    ethtool -L $i combined $queue 2>/dev/null 1>/dev/null
done

cpu_count=$(cat /proc/cpuinfo| grep "processor"| wc -l)
srv_cpu=1
cli_cpu=1

while true;do

    #input
    for input_irq in `cat /proc/interrupts | grep input | awk -F " |:" '{print $2}'`;do
        input_cpu=`cat /proc/irq/${input_irq}/smp_affinity_list` 2>&1 > /dev/null

        #echo -e "input_cpu=$input_cpu\tsrv_cpu=$srv_cpu"
        if [ $input_cpu = $srv_cpu ];then
            let srv_cpu=$srv_cpu+1
            let srv_cpu=${srv_cpu}%${cpu_count}
        fi

        for pid in `ps -ef | grep netserver | grep -v grep | awk '{print $2}'`;do
            taskset -pc ${srv_cpu} $pid 2>&1 > /dev/null
        done
        sleep 0.1
    done

    #output
    for output_irq in `cat /proc/interrupts | grep output | awk -F " |:" '{print $2}'`;do
        output_cpu=`cat /proc/irq/${output_irq}/smp_affinity_list` 2>&1 > /dev/null
        #echo -e "output_cpu=$output_cpu\tcli_cpu=$cli_cpu"
        if [ $output_cpu = $cli_cpu ];then
            let cli_cpu=$cli_cpu+1
            let cli_cpu=${cli_cpu}%${cpu_count}

        fi

        for pid in `ps -ef | grep netperf | grep -v grep | awk '{print $2}'`;do
            taskset -pc ${cli_cpu} $pid 2>&1 > /dev/null
        done
        sleep 0.1
    done

    sleep 4
done