# StrongSwan IKEv2/IPsec VPN setup

## Описание
Этот репозиторий содержит несколько скриптов, которые вы можете использовать для развертывания вашего IKEv2/IPsec VPN-сервера с использованием сертификатов или PSK-ключа с помощью [Strongswan](https://github.com/strongswan/strongswan). StrongSwan - это VPN-решение с открытым исходным кодом на базе IPsec, обеспечивающее безопасное взаимодействие через Интернет.

Я потратил много времени на поиск информации о подключении с помощью swanctl.conf, так как готовых руководств по новой версии конфига очень мало. Надеюсь, это кому-нибудь поможет.

## Содействие
Скрипты не идеальны, я не часто пишу на bash. Не стесняйтесь форкать репозиторий, вносить изменения и отправлять запросы на слияние.

## Использованые материалы
 - [Digital Ocean туториал для Ubuntu-16-04](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-ikev2-vpn-server-with-strongswan-on-ubuntu-16-04)
 - [Strongswan официальная документация](https://docs.strongswan.org/docs/latest/index.html)
 - [Репозиторий, на основе которого я собрал скрипт для старой версии конфига (спасибо!)](https://github.com/truemetal/ikev2_vpn/tree/master)

### Развёртывание с использованием сертификатов(+ username/password auth) и Pre Shared Key (PSK)

Этот скрипт генерирует PSK и выводит его в консоль, где вы можете скопировать его и нажать Enter, чтобы продолжить.

Отключена проверка сертификатов со стороны клиента, что может быть менее безопасно, но подключение становится проще. Для подключения вам понадобится только сертификат Центра Сертификации (ca-cert.pem) на устройстве клиента.

После подключения к серверу по ssh просто выполните эту команду (перед этим измените значения {your_server_default_eth_interface} {vpn_имя_пользователя} {vpn_пароль_пользователя} на свои собственные):

#### Для новой версии конфига (/etc/swanctl/swanctl.conf): 
```BASH
curl -L https://raw.githubusercontent.com/SLinartS/strongswan-vpn-IKEv2-certs-psk/main/ikev2_ipsec_vpn_strongswan_swanctl_vpn_ubuntu.sh -o ~/deploy.sh && sudo chmod +x ~/deploy.sh && sudo ~/deploy.sh {your_server_default_eth_interface} {vpn_user_name} {vpn_user_password}
```

#### Для старой версии конфига (/etc/ipsec.conf): 
```BASH
curl -L https://raw.githubusercontent.com/SLinartS/strongswan-vpn-IKEv2-certs-psk/main/ikev2_ipsec_vpn_strongswan_ipsecconf_vpn_ubuntu.sh -o ~/deploy.sh && sudo chmod +x ~/deploy.sh && sudo ~/deploy.sh {your_server_default_eth_interface} {vpn_user_name} {vpn_user_password}
```

### Пример готовой команды 
(оно может вам не подойти, проверяйте сетевой интерфейс через `ip route show default`) 
```BASH
curl -L https://raw.githubusercontent.com/SLinartS/strongswan-vpn-IKEv2-certs-psk/main/ikev2_ipsec_vpn_strongswan_swanctl_vpn_ubuntu.sh -o ~/deploy.sh && sudo chmod +x ~/deploy.sh && sudo ~/deploy.sh enp4s0 SharlizUser SharlizQwerty123
```
### Подключение
Скрипт создаёт возможность подключения и через использование сертификтов и с помощью Pre Shared Key (PSK)
На каждой системе настройки могут отличаться, ищите найды в инетернете

#### Сертификаты:
Вам понадобится 
- содержимое ca-cert.pem (выводится перед предложением о перезагрузке устройства)
- {vpn_user_name} и {vpn_user_password}, которые Вы ввели при запуске скрипта.
- gateway ip (публичный статичный ip адрес вашего сервера)

#### PSK:
- PSK (выводится в самом начале выполнения скрипта)
- gateway ip (публичный статичный ip адрес вашего сервера)
