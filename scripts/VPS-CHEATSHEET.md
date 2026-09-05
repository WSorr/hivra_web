# Hivra VPS: шпаргалка

## Актуальный сервер

- Провайдер: netcup, KVM
- IP: `45.142.176.16`
- Пользователь: `root`
- ОС: Debian 13 (trixie)
- SSH-ключ на Mac: `~/.ssh/hivra_vps_ed25519`
- Сайт: `/var/www/hivra.space`
- Amnezia: контейнер `amnezia-awg2`, текущий UDP-порт `40480`

Все команды ниже выполняются из корня проекта:

```sh
cd /Volumes/Dev/projects/hivra_web
```

## Вход и проверка

Проверить доступ без интерактивной сессии:

```sh
./scripts/run.sh vps test
```

Открыть SSH-сессию с keepalive:

```sh
./scripts/run.sh vps login
```

Прямая команда, если скрипт недоступен:

```sh
ssh -o ConnectTimeout=12 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes -o IdentitiesOnly=yes -i ~/.ssh/hivra_vps_ed25519 root@45.142.176.16
```

Состояние сервера и Amnezia:

```sh
./scripts/run.sh vps status
./scripts/run.sh vps audit
./scripts/run.sh amnezia status
```

## Перезагрузка

Обычная перезагрузка по SSH:

```sh
./scripts/run.sh vps reboot CONFIRM
```

Прямая команда:

```sh
ssh -o IdentitiesOnly=yes -i ~/.ssh/hivra_vps_ed25519 root@45.142.176.16 'systemctl reboot'
```

Если SSH не отвечает, открыть netcup Server Control Panel (SCP), выбрать сервер и использовать раздел `Control`. Сначала пробовать обычный reboot/power cycle. Принудительный reset использовать только если обычное выключение не сработало.

## Полная переустановка ОС

Переустановка полностью удалит сайт, сертификаты, контейнеры Amnezia и все данные на системном диске. Запустить её по SSH нельзя: используется панель netcup.

Перед переустановкой:

1. Сохранить сайт, нужные конфиги и данные вне VPS.
2. В SCP сохранить публичный SSH-ключ `~/.ssh/hivra_vps_ed25519.pub`, чтобы выбрать его при установке.
3. При необходимости создать offline snapshot в `Media -> Snapshots`.

Установка чистой ОС:

1. Войти в netcup Server Control Panel и выбрать VPS `45.142.176.16`.
2. Открыть `Media -> Images`.
3. Выбрать актуальный Debian, вариант `Minimal`.
4. Выбрать большую корневую партицию на весь диск.
5. Добавить сохранённый SSH-ключ.
6. Нажать `Install` и подтвердить удаление всех данных паролем SCP.
7. Дождаться письма netcup об окончании установки.
8. Удалить старую запись host key на Mac и подключиться заново:

```sh
ssh-keygen -R 45.142.176.16
ssh -o IdentitiesOnly=yes -i ~/.ssh/hivra_vps_ed25519 root@45.142.176.16
```

После переустановки старые Amnezia-профили работать не будут. Сервер нужно заново защитить, установить Docker/nginx/Certbot, развернуть сайт и создать новые профили Amnezia.

Официальная инструкция netcup: <https://www.netcup.com/en/helpcenter/documentation/server/media>

## Сайт

Проверить nginx:

```sh
./scripts/run.sh vps nginx
```

Сначала посмотреть, какие файлы изменятся на сервере:

```sh
./scripts/run.sh vps deploy-preview
```

Развернуть сайт только после проверки preview:

```sh
./scripts/run.sh vps deploy CONFIRM
```

## Docker-мусор

Сначала смотреть, что занято:

```sh
ssh -o IdentitiesOnly=yes -i ~/.ssh/hivra_vps_ed25519 root@45.142.176.16 'docker system df'
```

Не запускать `docker system prune -a`, пока не проверены контейнеры и образы: команда может удалить заготовки, нужные для следующего запуска. На 24 августа 2026 года подтверждены как неиспользуемые `dart:3.11.0` и старый build cache, но текущий `amnezia-awg2` трогать нельзя.
