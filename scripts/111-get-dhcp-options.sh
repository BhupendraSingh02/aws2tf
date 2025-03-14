#!/bin/bash
if [ "$1" != "" ]; then
    cmd[0]="$AWS ec2 describe-dhcp-options --dhcp-options-ids $1" 
else
    cmd[0]="$AWS ec2 describe-dhcp-options"
fi

pref[0]="DhcpOptions"
tft[0]="aws_vpc_dhcp_options"
#echo ${cmd[0]}

for c in `seq 0 0`; do
    cm=${cmd[$c]}
	ttft=${tft[(${c})]}
	#echo $cm
    awsout=`eval $cm 2> /dev/null`
    if [ "$awsout" == "" ];then
        echo "$cm : You don't have access for this resource"
        exit
    fi
    count=`echo $awsout | jq ".${pref[(${c})]} | length"`
    #echo "count=$count"
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        for i in `seq 0 $count`; do
            #echo $i
            cname=`echo $awsout | jq ".${pref[(${c})]}[(${i})].DhcpOptionsId" | tr -d '"'`
            rname=${cname//:/_} && rname=${rname//./_} && rname=${rname//\//_}
            echo "$ttft $cname import"
            fn=`printf "%s__%s.tf" $ttft $rname`
            if [ -f "$fn" ] ; then echo "$fn exists already skipping" && continue; fi       
            printf "resource \"%s\" \"%s\" {}" $ttft $rname > $fn

            terraform import $ttft.$rname "$cname" | grep Import
            terraform state show -no-color $ttft.$rname > t1.txt
            rm -f $fn
   
            file="t1.txt"

            echo $aws2tfmess > $fn
            while IFS= read line
            do
				skip=0
                # display $line or do something with $line
                t1=`echo "$line"`
                if [[ ${t1} == *"="* ]];then
                    tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '` 
                    tt2=`echo "$line" | cut -f2- -d'='`
                    if [[ ${tt1} == "arn" ]];then skip=1; fi                
                    if [[ ${tt1} == "id" ]];then skip=1; fi          
                    if [[ ${tt1} == "role_arn" ]];then skip=1;fi
                    if [[ ${tt1} == "allocated_capacity" ]];then skip=1;fi
                    if [[ ${tt1} == "dhcp_options_id" ]];then skip=1;fi
                    if [[ ${tt1} == "main_route_table_id" ]];then skip=1;fi
                    if [[ ${tt1} == "default_security_group_id" ]];then skip=1;fi
                    if [[ ${tt1} == "default_route_table_id" ]];then skip=1;fi
                    if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                    if [[ ${tt1} == "default_network_acl_id" ]];then skip=1;fi
                    if [[ ${tt1} == "ipv6_association_id" ]];then skip=1;fi
                    if [[ ${tt1} == "ipv6_cidr_block" ]];then skip=1;fi
                fi
                if [ "$skip" == "0" ]; then
                    #echo $skip $t1
                    echo "$t1" >> $fn
                fi
                
            done <"$file"
            
        done
    fi
done

rm -f t*.txt

#