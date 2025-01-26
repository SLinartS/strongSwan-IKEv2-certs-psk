1. При переходе с ipsec.conf на swanctl.conf настройки может возникнуть следующая ошибка. Решается очисткой `/etc/ipsec.secrets` файла.

```BASH
16[IKE] peer requested virtual IP %any
16[CFG] assigning new lease to 'anything'
16[IKE] assigning virtual IP 10.10.10.1 to peer 'anything'
16[IKE] peer requested virtual IP %any6
16[IKE] no virtual IP found for %any6 requested by 'anything'
```
