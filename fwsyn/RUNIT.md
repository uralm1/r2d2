# Fwsyn

Установка супервайзера runit для запуска агента fwsyn на старых системах без systemd или
аналогичных менеджеров.

Загрузите `runit-2.1.2.tar.gz` в `/package` из [smarden.org/runit](smarden.org/runit/runit-2.1.2.tar.gz).

Распаковка дистрибутива:
```
#> cd /package
#> tar xzvf runit-2.1.2.tar.gz
```
Компиляция:
```
#> cd admin/runit-2.1.2
#> package/compile
#> package/check
```
Скрипты установки из дистрибутива runit устанавливают лишь символические ссылки, поэтому
выполняем установку вручную:
```
#> install -m 755 command/{runit*,utmpset} /sbin
#> install -m 755 command/{chpst,runsv*,sv*} /usr/bin
#> install -m 750 etc/2 /sbin/runsvdir-start
#> install -m 644 man/* /usr/man/man8
#> install -d /etc/runit
#> install -d /service
```
Можно также выполнить `strip --strip-unneeded` для исполняемых файлов.

Для запуска супервайзера `runsvdir` добавим в `/etc/inittab`.

```
# runit supervisor
sv:345:respawn:/sbin/runsvdir-start
```

Каталог сервисов: `/etc/runit/`.

Каталог ссылок на активные сервисы: `/service`.

Управление сервисами: `sv {start|stop|restart|status} service_name`

Статья по использованию runit на slackware: [docs.slackware.com](https://docs.slackware.com/howtos:slackware_admin:runit)

