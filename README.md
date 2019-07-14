ICINGA2 Check Interrupts plugin
======================================

This plugin has been created especially for Icinga2, but it is compatible with Nagios 4 too. Plugin checks interface interrupts. In the "command" directory you find examples of command definitions for both Nagios and Icinga2.

Example of use
--------------

```sh
./check_interrupts.sh -i igb.0 -w 75% -c 90%
```

License
-------

[MIT](https://tldrlegal.com/license/mit-license)

Author
------

[Honza Hommer](https://hommer.cz)
