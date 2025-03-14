#!/bin/bash
if [ "$1" != "" ]; then
    cmd[0]="$AWS dms describe-replication-instances --filters \"Name=replication-instance-id,Values=$1\""
    pref[0]="ReplicationInstances"
else
    cmd[0]="$AWS dms describe-replication-instances"
    pref[0]="ReplicationInstances"
fi

tft[0]="aws_dms_replication_instance"
idfilt[0]="ReplicationInstanceIdentifier"

#rm -f ${tft[0]}.tf

for c in `seq 0 0`; do
    
    cm=${cmd[$c]}
	ttft=${tft[(${c})]}
	#echo $cm
    awsout=`eval $cm 2> /dev/null`
    if [ "$awsout" == "" ];then
        echo "$cm : You don't have access for this resource"
        exit
    fi
    if [ "$1" != "" ]; then
        count=1
    else
        count=`echo $awsout | jq ".${pref[(${c})]} | length"`
    fi
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        for i in `seq 0 $count`; do
            #echo $i
            cname=$(echo $awsout | jq -r ".${pref[(${c})]}[(${i})].${idfilt[(${c})]}")
            
            echo "$ttft $cname"
            rname=`printf "%s" $cname`
            fn=`printf "%s__%s.tf" $ttft $rname`
            if [ -f "$fn" ] ; then
                echo "$fn exists already skipping"
                continue
            fi
            printf "resource \"%s\" \"%s\" {" $ttft $rname > $ttft.$rname.tf
            printf "}" >> $ttft.$rname.tf
            printf "terraform import %s.%s %s" $ttft $rname $cname > data/import_$ttft_$rname.sh
            terraform import $ttft.$rname "$cname" | grep Import
            terraform state show -no-color $ttft.$rname > t1.txt
            tfa=`printf "%s.%s" $ttft $rname`
            terraform show  -json | jq --arg myt "$tfa" '.values.root_module.resources[] | select(.address==$myt)' > data/$tfa.json
            #echo $awsj | jq . 
            rm -f $ttft.$rname.tf

            file="t1.txt"
            echo $aws2tfmess > $fn
            sgs=()
            subnets=()
            while IFS= read line
            do
				skip=0
                # display $line or do something with $line
                t1=`echo "$line"` 
                if [[ ${t1} == *"="* ]];then
                    tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '` 
                    tt2=`echo "$line" | cut -f2- -d'='`
                    if [[ ${tt1} == "arn" ]];then skip=1; fi                
                    if [[ ${tt1} == "id" ]];then skip=1;fi          
                    if [[ ${tt1} == "role_arn" ]];then skip=1;fi
                    if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                    if [[ ${tt1} == "last_modified" ]];then skip=1;fi
                    if [[ ${tt1} == "invoke_arn" ]];then skip=1;fi
                    if [[ ${tt1} == "replication_instance_arn" ]];then skip=1;fi
                    if [[ ${tt1} == "version" ]];then skip=1;fi
                    if [[ ${tt1} == "type" ]];then skip=1;fi
                    if [[ ${tt1} == "vpc_id" ]]; then
                        vpcid=`echo $tt2 | tr -d '"'`
                        t1=`printf "%s = aws_vpc.%s.id" $tt1 $vpcid`
                        skip=1
                    fi
                    if [[ ${tt1} == "role" ]];then 
                        rarn=`echo $tt2 | tr -d '"'` 
                        skip=0;
                        trole=$(echo $tt2 | rev | cut -f1 -d'/' | rev | tr -d '"')
                                                    
                        t1=`printf "%s = aws_iam_role.%s.arn" $tt1 $trole`
                    fi

                    if [[ ${tt1} == "replication_instance_public_ips" ]];then 
                        tt2=`echo $tt2 | tr -d '"'` 
                        skip=1
                        while [ "$t1" != "]" ] && [ "$tt2" != "[]" ] ;do
                        #while [[ "$t1" != "]" ]] ;do

                            read line
                            t1=`echo "$line"`
                            #echo $t1
                        done
                    fi
                    if [[ ${tt1} == "replication_instance_private_ips" ]];then 
                        tt2=`echo $tt2 | tr -d '"'` 
                        skip=1
                        while [ "$t1" != "]" ] && [ "$tt2" != "[]" ] ;do
                        #while [[ "$t1" != "]" ]] ;do

                            read line
                            t1=`echo "$line"`
                            #echo $t1
                        done
                    fi



                else
                    if [[ "$t1" == *"subnet-"* ]]; then
                        t1=`echo $t1 | tr -d '"|,'`
                        subnets+=`printf "\"%s\" " $t1`
                        t1=`printf "aws_subnet.%s.id," $t1`
                    fi
                    if [[ "$t1" == *"sg-"* ]]; then
                        t1=`echo $t1 | tr -d '"|,'`
                        sgs+=`printf "\"%s\" " $t1`
                        t1=`printf "aws_security_group.%s.id," $t1`
                    fi

                fi
                if [ "$skip" == "0" ]; then
                    #echo $skip $t1
                    echo "$t1" >> $fn
                fi
                
            done <"$file"

            if [ "$trole" != "" ]; then
                ../../scripts/050-get-iam-roles.sh $trole
            fi
            if [ "$vpcid" != "" ]; then
                ../../scripts/100-get-vpc.sh $vpcid
            fi


            for sub in ${subnets[@]}; do
                #echo "therole=$therole"
                sub1=`echo $sub | tr -d '"'`
                echo "calling for $sub1"
                if [ "$sub1" != "" ]; then
                    ../../scripts/105-get-subnet.sh $sub1
                fi
            done

            for sg in ${sgs[@]}; do
                #echo "therole=$therole"
                sg1=`echo $sg | tr -d '"'`
                echo "calling for $sg1"
                if [ "$sg1" != "" ]; then
                    ../../scripts/110-get-security-group.sh $sg1
                fi
            done 

        
        done

    fi
done


rm -f t*.txt

