# Проверка SSH в Umbrel OS

## Способ 1: Через SD карту (если нет доступа к Pi)

### Шаг 1: Извлеките SD карту
1. Выключите Raspberry Pi
2. Извлеките SD карту
3. Вставьте в кардридер компьютера

### Шаг 2: Проверьте boot раздел

**Boot раздел** будет виден в Windows (FAT32, обычно диск `E:` или `F:`)

**Проверьте наличие файла `ssh`:**
- В корне boot раздела должен быть файл `ssh` (без расширения)
- Если файла нет - SSH не включен

**Создайте файл `ssh` для включения SSH:**
1. В корне boot раздела создайте пустой файл с именем `ssh`
2. На Windows: создайте текстовый файл и переименуйте в `ssh` (уберите расширение `.txt`)
3. На Linux: `touch /mnt/boot/ssh`

### Шаг 3: Вставьте SD карту обратно и загрузите Pi

SSH будет включен при следующей загрузке.

## Способ 2: Через сеть (если есть доступ)

Если вы можете подключиться к Pi (через веб-интерфейс Umbrel или другой способ):

### Проверка статуса SSH:

```bash
# Проверка, запущен ли SSH сервис
sudo systemctl status ssh

# Или
sudo systemctl status sshd
```

### Проверка порта:

```bash
# Проверка, слушает ли SSH на порту 22
sudo netstat -tlnp | grep :22

# Или
sudo ss -tlnp | grep :22
```

### Проверка конфигурации:

```bash
# Проверка файла конфигурации SSH
cat /etc/ssh/sshd_config | grep -E "^Port|^PermitRootLogin|^PasswordAuthentication"
```

## Способ 3: Проверка через веб-интерфейс Umbrel

1. Откройте веб-интерфейс Umbrel: `http://umbrel.local` или `http://<IP_адрес>`
2. Зайдите в настройки (Settings)
3. Найдите раздел "SSH" или "Terminal Access"
4. Проверьте, включен ли SSH

## Способ 4: Проверка через сканер портов

Если Pi подключен к сети, но вы не знаете, включен ли SSH:

### На Windows:
```powershell
# Используйте скрипт find-umbrel.ps1
.\find-umbrel.ps1
```

Скрипт покажет открытые порты, включая порт 22 (SSH).

### Или вручную:
```powershell
# Проверка конкретного IP на порт 22
Test-NetConnection -ComputerName <IP_адрес_Pi> -Port 22
```

## Способ 5: Автоматическая проверка через скрипт

Создайте файл на SD карте для автоматической проверки при загрузке.

## Включение SSH, если он отключен

### Через SD карту:
1. Создайте файл `ssh` в корне boot раздела (см. Способ 1)

### Через веб-интерфейс Umbrel:
1. Зайдите в Settings → SSH
2. Включите SSH

### Через командную строку (если есть доступ):
```bash
# Включить SSH сервис
sudo systemctl enable ssh
sudo systemctl start ssh

# Или
sudo systemctl enable sshd
sudo systemctl start sshd
```

## Проверка подключения

После включения SSH попробуйте подключиться:

```bash
# Стандартное подключение
ssh umbrel@<IP_адрес_Pi>

# Или с указанием пользователя
ssh umbrel@umbrel.local

# Если не знаете пользователя, попробуйте:
ssh root@<IP_адрес_Pi>
ssh ubuntu@<IP_адрес_Pi>
```

## Полезные команды для диагностики

```bash
# Проверка всех сетевых портов
sudo netstat -tlnp

# Проверка процессов SSH
ps aux | grep ssh

# Проверка логов SSH
sudo journalctl -u ssh -n 50

# Проверка конфигурации
sudo sshd -T | grep -E "port|permitrootlogin|passwordauthentication"
```



