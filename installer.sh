#!/bin/bash

echo ""
echo -en "\033[37;1;41m Скрипт автоматической настройки IPv6 прокси. \033[0m"
echo ""
echo ""
echo -en "\033[37;1;41m Хостинг VPS серверов - VPSVille.ru \033[0m"
echo -en "\033[37;1;41m Сети IPv6 - /64, /48, /36, /32 под прокси. \033[0m"
echo ""
echo ""
echo -en "\033[37;1;41m ВНИМАНИЕ \033[0m"
echo ""
echo -en "\033[37;1;41m Данный скрипт настраивает в автоматическом режиме IPv6 прокси только на базе системы Debian 8 \033[0m"
echo ""
echo ""

read -p "Нажмите [Enter] для продолжения..."

echo ""
echo "Конфигурация IPv6 прокси"
echo ""

echo "Введите выданную сеть и нажмите [ENTER]:"
read network

if [[ $network == *"::/48"* ]]
then
    mask=48
elif [[ $network == *"::/64"* ]]
then
    mask=64
elif [[ $network == *"::/32"* ]]
then
    mask=32
    echo "Введите сеть /64, это шлюз необходимый для подключения сети /32. Сеть /64 подключена в личном кабинете в разделе - Сеть."
    read network_mask
elif [[ $network == *"::/36"* ]]
then
    mask=36
    echo "Введите сеть /64, это шлюз необходимый для подключения сети /36. Сеть /64 подключена в личном кабинете в разделе - Сеть."
    read network_mask
else
    echo "Неопознанная маска или неверный формат сети, введите сеть с маской /64, /48, /36 или /32"
    exit 1
fi
echo "Введите количество адресов для случайной генерации"
read MAXCOUNT
THREADS_MAX=`sysctl kernel.threads-max|awk '{print $3}'`
MAXCOUNT_MIN=$(( MAXCOUNT-200 ))
if (( MAXCOUNT_MIN > THREADS_MAX )); then
    echo "kernel.threads-max = $THREADS_MAX этого недостаточно для указанного количества адресов!"
fi

echo "Введите логин для прокси"
read proxy_login
echo "Введите пароль для прокси"
read proxy_pass
echo "Введите начальный порт для прокси"
read proxy_port

base_net=`echo $network | awk -F/ '{print $1}'`
base_net1=`echo $network_mask | awk -F/ '{print $1}'`

echo "Настройка прокси для сети $base_net с маской $mask"
sleep 2
echo "Настройка базового IPv6 адреса"
ip -6 addr add ${base_net}2 peer ${base_net}1 dev ens3
sleep 5
ip -6 route add default via ${base_net}1 dev ens3
ip -6 route add local ${base_net}/${mask} dev lo

echo "Проверка IPv6 связности..."
if ping6 -c3 google.com &> /dev/null
then
    echo "Успешно"
else
    echo "Предупреждение: IPv6 связность не работает!"
fi


echo "Копирование исполняемых файлов"

if [ -f /root/3proxy.tar ]; then
   echo "Архив 3proxy.tar уже скачан, продолжаем настройку..."
else
   echo "Архив 3proxy.tar отсутствует, скачиваем..."
   wget --no-check-certificate https://blog.vpsville.ru/uploads/3proxy.tar; tar -xvf 3proxy.tar
fi

if [ -f /root/ndppd.tar ]; then
   echo "Архив ndppd.tar уже скачан, продолжаем настройку..."
else
   echo "Архив ndppd.tar отсутствует, скачиваем..."
   wget --no-check-certificate https://blog.vpsville.ru/uploads/ndppd.tar; tar -xvf ndppd.tar
fi


echo "Настройка ядра"

dpkg -l|grep linux-image|grep "\-4\."
if [ $? -eq 0 ]
then
    echo "Установлено ядро 4.х, продожаем настройку..."
else
    echo "Предупреждение: ядро 4.x не установлено, приступаем к установке..."
cd /tmp; wget --no-check-certificate https://blog.vpsville.ru/uploads/kernel-4.3/linux-headers-4.3.0-040300_4.3.0-040300.201511020949_all.deb; wget --no-check-certificate https://blog.vpsville.ru/uploads/kernel-4.3/linux-headers-4.3.0-040300-generic_4.3.0-040300.201511020949_amd64.deb; wget --no-check-certificate https://blog.vpsville.ru/uploads/kernel-4.3/linux-image-4.3.0-040300-generic_4.3.0-040300.201511020949_amd64.deb; dpkg -i *.deb;
fi


echo "Конфигурирование ndppd"
mkdir -p /root/ndppd/
rm -f /root/ndppd/ndppd.conf
cat >/root/ndppd/ndppd.conf <<EOL
route-ttl 30000
proxy ens3 {
   router no
   timeout 500   
   ttl 30000
   rule __NETWORK__ {
      static
   }
}
EOL
sed -i "s/__NETWORK__/${base_net}\/${mask}/" /root/ndppd/ndppd.conf

echo "Конфигурирование 3proxy"
rm -f /root/ip.list
echo "Генерация $MAXCOUNT адресов "
array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
count=1
first_blocks=`echo $base_net|awk -F:: '{print $1}'`
rnd_ip_block ()
{
    a=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
    b=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
    c=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
    d=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
    if [[ "x"$mask == "x48" ]]
    then
        e=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
        echo $first_blocks:$a:$b:$c:$d:$e >> /root/ip.list
    elif [[ "x"$mask == "x32" ]]
    then
        e=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
        f=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
        echo $first_blocks:$a:$b:$c:$d:$e:$f >> /root/ip.list
    elif [[ "x"$mask == "x36" ]]
    then
        num_dots=`echo $first_blocks | awk -F":" '{print NF-1}'`
        if [[ x"$num_dots" == "x1" ]]
        then
            #first block
            block_num="0"
            first_blocks_cut=`echo $first_blocks`
        else
            #2+ block
            block_num=`echo $first_blocks | awk -F':' '{print $NF}'`
            block_num="${block_num:0:1}"
            first_blocks_cut=`echo $first_blocks | awk -F':' '{print $1":"$2}'`
        fi
        a=${block_num}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
        e=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
        f=${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}
        echo $first_blocks_cut:$a:$b:$c:$d:$e:$f >> /root/ip.list
    else
        echo $first_blocks:$a:$b:$c:$d >> /root/ip.list
    fi
}
while [ "$count" -le $MAXCOUNT ]
do
        rnd_ip_block
        let "count += 1"
done
echo "Генерация конфига 3proxy"
mkdir -p /root/3proxy
rm /root/3proxy/3proxy.cfg
cat >/root/3proxy/3proxy.cfg <<EOL
#!/bin/bash

daemon
maxconn 10000
nserver 127.0.0.1
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6000
flush
auth strong
users ${proxy_login}:CL:${proxy_pass}
allow ${proxy_login}
EOL

echo >> /root/3proxy/3proxy.cfg
ip4_addr=`ip -4 addr sh dev ens3|grep inet |awk '{print $2}'`
port=${proxy_port}
count=1
for i in `cat /root/ip.list`; do
    echo "proxy -6 -s0 -n -a -p$port -i$ip4_addr -e$i" >> /root/3proxy/3proxy.cfg
    ((port+=1))
    ((count+=1))
done

if grep -q "net.ipv6.ip_nonlocal_bind=1" /etc/sysctl.conf;
then
   echo "Все параметры в sysctl уже были установлены"
else
   echo "Конфигурирование sysctl"
   echo "net.ipv6.conf.ens3.proxy_ndp=1" >> /etc/sysctl.conf
   echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
   echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
   echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
   echo "net.ipv6.ip_nonlocal_bind=1" >> /etc/sysctl.conf
   echo "vm.max_map_count=195120" >> /etc/sysctl.conf
   echo "kernel.pid_max=195120" >> /etc/sysctl.conf
   echo "net.ipv4.ip_local_port_range=1024 65000" >> /etc/sysctl.conf
   sysctl -p
fi

echo "Конфигурирование rc.local"
rm /etc/rc.local

if [ "$mask" = "64" ]; then
echo -e '#!/bin/bash \n'  >> /etc/rc.local
echo "ulimit -n 600000" >> /etc/rc.local
echo "ulimit -u 600000" >> /etc/rc.local
echo "ulimit -i 20000" >> /etc/rc.local
echo "ip -6 addr add ${base_net}2 peer ${base_net}1 dev ens3" >> /etc/rc.local
echo "sleep 5" >> /etc/rc.local
echo "ip -6 route add default via ${base_net}1 dev ens3" >> /etc/rc.local
echo "ip -6 route add local ${base_net}/${mask} dev lo" >> /etc/rc.local
echo "/root/ndppd/ndppd -d -c /root/ndppd/ndppd.conf" >> /etc/rc.local
echo "/root/3proxy/bin/3proxy /root/3proxy/3proxy.cfg" >> /etc/rc.local
echo -e "\nexit 0\n" >> /etc/rc.local
/bin/chmod +x /etc/rc.local
fi

if [ "$mask" = "48" ]; then
echo -e '#!/bin/bash \n'  >> /etc/rc.local
echo "ulimit -n 600000" >> /etc/rc.local
echo "ulimit -u 600000" >> /etc/rc.local
echo "ulimit -i 20000" >> /etc/rc.local
echo "ip -6 addr add ${base_net}2 peer ${base_net}1 dev ens3" >> /etc/rc.local
echo "sleep 5" >> /etc/rc.local
echo "ip -6 route add default via ${base_net}1 dev ens3" >> /etc/rc.local
echo "ip -6 route add local ${base_net}/${mask} dev lo" >> /etc/rc.local
echo "/root/ndppd/ndppd -d -c /root/ndppd/ndppd.conf" >> /etc/rc.local
echo "/root/3proxy/bin/3proxy /root/3proxy/3proxy.cfg" >> /etc/rc.local
echo -e "\nexit 0\n" >> /etc/rc.local
/bin/chmod +x /etc/rc.local
fi

if [ "$mask" = "36" ]; then
echo -e '#!/bin/bash \n'  >> /etc/rc.local
echo "ulimit -n 600000" >> /etc/rc.local
echo "ulimit -u 600000" >> /etc/rc.local
echo "ulimit -i 20000" >> /etc/rc.local
echo "ip -6 addr add ${base_net1}2/64 dev ens3" >> /etc/rc.local
echo "ip -6 route add default via ${base_net1}1" >> /etc/rc.local
echo "ip -6 route add local ${base_net}/${mask} dev lo" >> /etc/rc.local
echo "/root/ndppd/ndppd -d -c /root/ndppd/ndppd.conf" >> /etc/rc.local
echo "/root/3proxy/bin/3proxy /root/3proxy/3proxy.cfg" >> /etc/rc.local
echo -e "\nexit 0\n" >> /etc/rc.local
/bin/chmod +x /etc/rc.local
fi

if [ "$mask" = "32" ]; then
echo -e '#!/bin/bash \n'  >> /etc/rc.local
echo "ulimit -n 600000" >> /etc/rc.local
echo "ulimit -u 600000" >> /etc/rc.local
echo "ulimit -i 20000" >> /etc/rc.local
echo "ip -6 addr add ${base_net1}2/64 dev ens3" >> /etc/rc.local
echo "ip -6 route add default via ${base_net1}1" >> /etc/rc.local
echo "ip -6 route add local ${base_net}/${mask} dev lo" >> /etc/rc.local
echo "/root/ndppd/ndppd -d -c /root/ndppd/ndppd.conf" >> /etc/rc.local
echo "/root/3proxy/bin/3proxy /root/3proxy/3proxy.cfg" >> /etc/rc.local
echo -e "\nexit 0\n" >> /etc/rc.local
/bin/chmod +x /etc/rc.local
fi

echo -en "\033[37;1;41m Конфигурация завершена, необходима перезагрузка \033[0m"
exit 0

