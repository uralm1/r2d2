# Dhcpsyn

Агент для управления зарезервированными адресами Windows Dhcp серверов.

## Инструкция по установке.

Т.к. Dhcpsyn предполагается к использованию на Windows, его исключительно сложно
установить. :cursing_face:

1. Заранее перед установкой создайте установочный tarball `Dhcpsyn-VERSION.tar.gz`
командой `make dist`. Если `Makefile` отсутствует, его можно создать командой
`perl Makefile.PL`.

2. На Windows, куда устанавливается агент создайте каталог
`mkdir c:\Utils\Dhcpsyn`.
Скопируйте в каталог `c:\Utils\Dhcpsyn` файлы:
* `Dhcpsyn-VERSION.tar.gz`
* `_i.cmd`
* `_i_deps.cmd`
* `_i_srv.cmd`
* `Minion.patch`
* `Minion-Jobs.patch`

3. Загрузите с [strawberryperl.com](https://strawberryperl.com) подходящий дистрибутив perl и установите
в `c:\Strawberry`.

4. Перейдите в каталог `c:\Utils\Dhcpsyn`.
Выполните `_i_deps.cmd`, команда загрузит и установит необходимые зависимости.
Команда cpanm будет собирать устанавливаемые модули в каталоге `%USERPROFILE%\.cpanm`. Можно по завершению
очистить данный каталог.

5. Выполните `_i.cmd`, команда установит программные файлы агента. Команда установки использует
программы `ptar` и `gmake` из комплекта Strawberry Perl.

6. Скопируйте `Dhcpsyn.conf-empty` в `Dhcpsyn.conf` и проверьте настройки в данном файле.

7. Агент на данном этапе уже можно запускать вручную:
* `script\dhcpsyn threaded` или `script\dhcpsyn daemon` - демон агента,
* `script\dhcpsyn minion worker -j 1` - исполнительный демон.

8. Установка сервисов. Загрузите с [nssm.cc](https://nssm.cc) дистрибутив nssm и извлеките подходящий
исполняемый файл `nssm` в `c:\Utils\Dhcpsyn`. Для установки сервисов запустите из окна командной строки
с повышенными привилегиями администратора команду `_i_srv.cmd`.

