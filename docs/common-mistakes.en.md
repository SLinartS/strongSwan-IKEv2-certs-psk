1. The following error may occur when switching from ipsec.conf to swanctl.conf settings. This is resolved by clearing the `/etc/ipsec.secrets`ё` file.

```BASH
16[IKE] peer requested virtual IP %any
16[CFG] assigning new lease to 'anything'
16[IKE] assigning virtual IP 10.10.10.1 to peer 'anything'
16[IKE] peer requested virtual IP %any6
16[IKE] no virtual IP found for %any6 requested by 'anything'
```
