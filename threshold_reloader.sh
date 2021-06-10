#!/bin/bash
#threshold="700M"
#threshold="800M"
#threshold="1.9G"
#threshold="4,5G"
threshold="1,7G"
# Можно задавать фильтр чтобы искать не только роутеры среди юнитов. См. доку grep, чтобы задать несколько фильтров. Наверное так: filter="unit-a\|unit-b" Не проверял.
filter="router"
/usr/bin/date
byte_threshold=`/usr/bin/echo $threshold | numfmt --from=iec`
/usr/bin/echo "Трешолд: "$threshold
/usr/bin/echo "Трешолд в байтах: "$byte_threshold

# В переменной routers - имена юнитов через пробел, например: cassandra-router-1.service cassandra-router-2.service
routers=`/usr/bin/systemctl | /usr/bin/grep $filter | /usr/bin/awk '{print $1}'`
# arr_routers - это routers переконверченный в массив
arr_routers=($routers)

# Оставил, т.к. нашёл расхождение в работе утилиты numfmt при запуске из крона и из консоли.
# В одном случае она использует на входе точку перед дробной частью, в другой - запятую (странно).
# Поэтому, надо писать threshold="1,2G" - из консоли ; threshold="1.2G" - из крона (парадокс, но факт).
Mems=`for i in $routers; do /usr/bin/systemctl status $i | /usr/bin/grep Memory | /usr/bin/awk '{print $2}' | /usr/bin/sed s/\\\./,/ | /usr/bin/sed s/B// | numfmt --from=iec ; done`

# без конверта . в ,
# Mems - это строка, где через пробел содержится занимаемая память каждым юнитом в байтах.
# Из команды systemctl status cassandra-router-1.service (к примеру), берём строку с Memory, в строке берём второе поле 804.4M (К примеру), если в поле есть B, то стираем и прогоняем результат через конвертер в байты
#Mems=`for i in $routers; do /usr/bin/systemctl status $i | /usr/bin/grep Memory | /usr/bin/awk '{print $2}' | /usr/bin/sed s/B// | numfmt --from=iec ; done`

/usr/bin/echo "Занятая память в байтах по всем найденным юнитам по фильтру "\"$filter\"": "$Mems

# Идем по строке Mems с объёмами в байтах через пробел. Один шаг - до следующего пробела. В счетчике cnt хранится номер позиции в Mems (увеличиваем его на каждом шаге), а потом мы по этому номеру обращаемся в arr_routers, где хранятся имена юнитов в соответствующих позициях.

# Цикл for - для рестарта сервисов превышающих трешолд, разом
#cnt=-1
#for i in $Mems
#do
#  cnt=$((cnt+1))
#  if [[ $byte_threshold -lt $i ]]; then
#    /usr/bin/echo "Рестартим: "${arr_routers[$cnt]}
#    /usr/bin/systemctl restart ${arr_routers[$cnt]}
#  fi
#done


# Цикл until - для рестарта сервисов превышающих тершолд, по одному за раз
arr_mems=($Mems)
cnt=0
echo "Длинна массива: "${#arr_mems[@]}
until [ $cnt -ge ${#arr_mems[@]} ]
do
  if [[ $byte_threshold -lt ${arr_mems[$cnt]} ]]; then
    /usr/bin/echo "Рестартим: "${arr_routers[$cnt]}
    /usr/bin/systemctl restart ${arr_routers[$cnt]}
    cnt=${#arr_mems[@]}
  fi
  (( cnt++ ))
done

# Пример цикла while
#while [ $cnt -lt ${#arr_mems[@]} ]
#do
#echo "Элемент массива: "${arr_mems[$cnt]}
#(( cnt++ ))
#done
