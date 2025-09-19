#!/usr/bin/env bash
i=0
total_cpu_R=0
total_mem_R=0

for node in $(kubectl get nodes | cut -f1 -d " " | tail -n +2) ; do
  extracted_txt=$(kubectl describe node ${node} | grep -A 5 "Allocated resources:" | tail -n +5)

  cpu_r=$(echo ${extracted_txt} | cut -f 3 -d" " | sed 's|[()%]||g')
  cpu_l=$(echo ${extracted_txt} | cut -f 5 -d" " | sed 's|[()%]||g')
  mem_r=$(echo ${extracted_txt} | cut -f 8 -d" " | sed 's|[()%]||g')
  mem_l=$(echo ${extracted_txt} | cut -f 10 -d" " | sed 's|[()%]||g')

  echo -e "${node}\t${cpu_r}\t${cpu_l}\t${mem_r}\t${mem_l}"

  total_cpu_R=$(($total_cpu_R + $cpu_r))
  total_mem_R=$(($total_mem_R + $mem_r))
  i=$(($i+1))
done

a=$(($total_cpu_R / $i))
b=$(($total_mem_R / $i))
echo "Total cpu requested: ${a}%"
echo "Total mem requested: ${b}%"
