# Восстановление и настройка Raspberry Pi как селективного VPN-шлюза (LEGACY)

Этот документ сохранён для истории: это старые заметки/скрипты про восстановление сети после экспериментов с iptables/Xray/dnsmasq.

Если вы пришли за **простым “поставил и работает” решением на Pi-hole + v2rayA (TProxy)** — вам сюда:
- `GITHUB_RELEASE/README.md`

---

# Восстановление и настройка Raspberry Pi как селективного VPN-шлюза

Этот репозиторий содержит скрипты и конфигурации для настройки Raspberry Pi 5 как маршрутизатора с селективным прокси через Xray (VLESS + Reality).

## Проблема

После настройки iptables, Xray TProxy и dnsmasq Raspberry Pi потерял сетевой доступ. SSH не работает.

## Быстрое восстановление

### Если есть физический доступ (монитор + клавиатура):

1. Подключите монитор и клавиатуру к Raspberry Pi
2. Войдите в систему (пользователь `ubuntu`)
3. Скопируйте `reset-network.sh` на Pi (через USB флешку или создайте вручную)
4. Выполните:

```bash
chmod +x reset-network.sh
sudo ./reset-network.sh
```

### Если есть доступ к SD карте (БЕЗ монитора и клавиатуры):

**Самый простой способ - автоматическое восстановление при загрузке:**

1. Выключите Raspberry Pi и извлеките SD карту
2. Вставьте SD карту в кардридер компьютера
3. На Linux (или WSL на Windows):

```bash
# Определите устройство SD карты
lsblk

# Монтируйте root раздел (обычно /dev/sdb2 или /dev/mmcblk0p2)
sudo mkdir -p /mnt/pi-root
sudo mount /dev/sdb2 /mnt/pi-root  # замените на ваше устройство

# Установите автоматическое восстановление
cd <путь_к_этим_файлам>
sudo chmod +x install-auto-recovery.sh
sudo ./install-auto-recovery.sh /mnt/pi-root

# Отмонтируйте
sudo umount /mnt/pi-root
```

4. Вставьте SD карту обратно в Pi и включите
5. Подождите 1-2 минуты - сеть восстановится автоматически

Подробные инструкции:
- Для Linux: [SD_CARD_RECOVERY.md](SD_CARD_RECOVERY.md)
- Для Windows: [WINDOWS_RECOVERY.md](WINDOWS_RECOVERY.md)

## Файлы в репозитории

### Скрипты восстановления

- **`reset-network.sh`** - Скрипт для быстрого отката всех сетевых настроек (ручной запуск)
- **`reset-network-once.sh`** - Автоматический скрипт восстановления при загрузке
- **`auto-recover-network.service`** - Systemd сервис для автозапуска восстановления
- **`install-auto-recovery.sh`** - Скрипт установки автоматического восстановления на SD карту
  - Останавливает Xray и dnsmasq
  - Очищает все правила iptables
  - Восстанавливает стандартную маршрутизацию
  - Перезапускает сетевой интерфейс

### Конфигурации

- **`xray-config.json`** - Конфигурация Xray с TProxy
  - TProxy на порту 12345
  - VLESS + Reality протокол
  - Маршрутизация через ipset `vpnlist`
  - Локальные SOCKS (10808) и HTTP (10809) прокси

- **`xray.service`** - Systemd unit файл для Xray
  - Автозапуск при загрузке
  - Автоматический перезапуск при сбое
  - Запуск от пользователя `nobody` с минимальными правами

- **`dnsmasq-proxy.conf`** - Конфигурация dnsmasq для автоматического добавления IP в ipset
  - Автоматическое добавление IP адресов доменов в ipset
  - Настроенные домены: YouTube, Instagram, WhatsApp, ChatGPT

### Скрипты настройки

- **`xray-tproxy.sh`** - Скрипт настройки iptables для TProxy
  - **ВАЖНО**: SSH порт 22 исключен из правил TProxy
  - Создает ipset для доменов VPN
  - Настраивает TProxy маршрутизацию
  - Настраивает NAT для исходящего трафика
  - Сохраняет правила для перезагрузки

### Документация

- **`RECOVERY_INSTRUCTIONS.md`** - Подробная инструкция по восстановлению доступа
  - Три способа восстановления
  - Пошаговые инструкции
  - Команды для диагностики

## Правильная настройка после восстановления

### 1. Установка Xray

```bash
# Скачайте Xray для ARM64
cd /tmp
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip Xray-linux-64.zip
sudo mkdir -p /opt/xray
sudo cp xray /opt/xray/
sudo chmod +x /opt/xray/xray
```

### 2. Копирование конфигураций

```bash
# Скопируйте все файлы на Raspberry Pi (через SCP или USB)
# Затем на Pi выполните:

sudo cp xray-config.json /opt/xray/config.json
sudo cp xray.service /etc/systemd/system/
sudo cp xray-tproxy.sh /usr/local/bin/
sudo cp reset-network.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/xray-tproxy.sh
sudo chmod +x /usr/local/bin/reset-network.sh
```

### 3. Настройка dnsmasq (опционально)

```bash
sudo cp dnsmasq-proxy.conf /etc/dnsmasq.d/proxy.conf
# ВАЖНО: Отредактируйте /etc/dnsmasq.conf и убедитесь, что DHCP не конфликтует с роутером
sudo systemctl restart dnsmasq
```

### 4. Запуск Xray

```bash
sudo systemctl daemon-reload
sudo systemctl enable xray
sudo systemctl start xray
sudo systemctl status xray
```

### 5. Настройка iptables (правильно, с защитой SSH)

```bash
sudo /usr/local/bin/xray-tproxy.sh
```

## Как это работает

1. **dnsmasq** резолвит домены (youtube.com, instagram.com и т.д.) и автоматически добавляет их IP адреса в ipset `vpnlist`
2. **iptables** маркирует пакеты, направленные на IP из ipset, и перенаправляет их на Xray TProxy (порт 12345)
3. **Xray** получает помеченные пакеты через TProxy и отправляет их через VPN (VLESS + Reality)
4. **Остальной трафик** идет напрямую через роутер
5. **SSH порт 22** полностью исключен из всех правил TProxy для безопасности

## Домены, идущие через VPN

- YouTube: `youtube.com`, `youtu.be`, `googlevideo.com`, `ytimg.com`
- Instagram: `instagram.com`, `cdninstagram.com`, `fbcdn.net`
- WhatsApp: `whatsapp.com`, `whatsapp.net`
- ChatGPT: `openai.com`, `chatgpt.com`

Для добавления новых доменов отредактируйте `/etc/dnsmasq.d/proxy.conf` и перезапустите dnsmasq.

## Критические моменты

1. **SSH порт 22 всегда должен быть исключен из TProxy правил**
2. **Не используйте dnsmasq DHCP на том же интерфейсе, где работает основной роутер**
3. **Проверяйте сеть после каждого изменения iptables**
4. **Имейте физический доступ или консольный доступ для восстановления**
5. **Сохраняйте резервные копии конфигураций**

## Диагностика

### Проверка сети

```bash
ip addr show eth0
ip route show
ping -c 3 8.8.8.8
```

### Проверка iptables

```bash
sudo iptables -t mangle -L -v -n
sudo iptables -t nat -L -v -n
```

### Проверка ipset

```bash
sudo ipset list vpnlist
```

### Проверка сервисов

```bash
sudo systemctl status xray
sudo systemctl status dnsmasq
sudo journalctl -u xray -f
```

### Быстрый откат

```bash
sudo /usr/local/bin/reset-network.sh
```

## Индикаторы Ethernet на Raspberry Pi

На Raspberry Pi 4/5 обычно есть два индикатора рядом с Ethernet портом:
- **Активность** (Activity) - мигает при передаче данных
- **Связь/Скорость** (Link/Speed) - зеленый/желтый при подключении

Если оба не горят - кабель не подключен или нет линка. Если горят, но нет сети - проблема в настройках.

## Поддержка

Если что-то не работает:
1. Выполните `sudo /usr/local/bin/reset-network.sh` для отката
2. Проверьте логи: `sudo journalctl -u xray -n 50`
3. Проверьте iptables: `sudo iptables -t mangle -L -v -n`
4. См. [RECOVERY_INSTRUCTIONS.md](RECOVERY_INSTRUCTIONS.md) для подробных инструкций


