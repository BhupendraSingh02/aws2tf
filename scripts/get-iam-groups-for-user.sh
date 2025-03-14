#!/bin/bash
if [ "$1" != "" ]; then
    cmd[0]="$AWS iam list-groups-for-user --user-name $1"
else
    echo "Must specify a user exiting..."
    exit
fi

pref[0]="Groups"
tft[0]="aws_iam_user_group_membership"

for c in `seq 0 0`; do
    
    cm=${cmd[$c]}
    #echo "role command = $cm"
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

            cname=`echo $awsout | jq ".${pref[(${c})]}[(${i})].GroupName" | tr -d '"'`
            ocname=`echo $cname`
            cname=${cname//./_}
            echo "$ttft $cname"
            fn=`printf "%s__%s.tf" $ttft $1__$cname`
            if [ -f "$fn" ] ; then
                echo "$fn exists already skipping"
                continue
            fi


            printf "resource \"%s\" \"%s\" {" $ttft $cname > $ttft.$cname.tf
            printf "}" >> $ttft.$cname.tf
            terraform import $ttft.$cname "$1/$cname" | grep Import
            terraform state show -no-color $ttft.$cname > t1.txt
            rm -f $ttft.$cname.tf

            file="t1.txt $1/$cname"
            echo "lines in t1" 
            wc -l tx.txt

            echo $aws2tfmess > $fn
            while IFS= read line
            do
                skip=0
                # display $line or do something with $line
                t1=`echo "$line"`
                if [[ ${t1} == *"="* ]];then
                    tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '`
                    tt2=`echo "$line" | cut -f2- -d'='`
                    if [[ ${tt1} == *":"* ]];then
                        tt1=`echo $tt1 | tr -d '"'`
                        t1=`printf "\"%s\"=%s" $tt1 $tt2`
                    fi
                    if [[ ${tt1} == "arn" ]];then skip=1; fi
                    if [[ ${tt1} == "id" ]];then skip=1; fi
                    if [[ ${tt1} == "role_arn" ]];then skip=1;fi
                    if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                    if [[ ${tt1} == "association_id" ]];then skip=1;fi
                    if [[ ${tt1} == "unique_id" ]];then skip=1;fi
                    if [[ ${tt1} == "create_date" ]];then skip=1;fi
                    #if [[ ${tt1} == "public_ip" ]];then skip=1;fi
                    if [[ ${tt1} == "private_ip" ]];then skip=1;fi
                    if [[ ${tt1} == "accept_status" ]];then skip=1;fi
                    #if [[ ${tt1} == "default_network_acl_id" ]];then skip=1;fi
                    #if [[ ${tt1} == "ipv6_association_id" ]];then skip=1;fi
                    #if [[ ${tt1} == "ipv6_cidr_block" ]];then skip=1;fi
                fi
                if [ "$skip" == "0" ]; then
                    #echo $skip $t1
                    echo "$t1" >> $fn
                fi
                
            done <"$file"   # done while
            
        done # done for i
        # Get attached role policies       

    fi
done

rm -f t*.txt

