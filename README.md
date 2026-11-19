# Windows 11 Hardcore Optimizer & Latency Suite
**Создано специально для Шефа | Поддержка Windows 11 (включая 24H2)**

---

## 🚀 Обзор проекта

Данный комплекс представляет собой модульный, полностью автоматизированный All-in-One инструмент глубокой оптимизации Windows 11 для киберспортивных игр и максимальной системной отзывчивости.

Он полностью заменяет разрозненный каталог устаревших ссылок (`C:\Users\egorv\Desktop\Windows11\Настройка Windows 11`) на современную интерактивную экосистему с гарантией безопасности:
- **Авто-создание точек восстановления системы (System Restore Point)** перед любыми изменениями.
- **Двухуровневый откат (Rollback)**: покатегорийный возврат исходных ключей реестра из JSON-снимков или полный возврат к заводским дефолтам Windows.
- **Standby RAM Cleaner & WorkingSet Purge**: освобождение оперативной памяти на уровне NT-ядра без сомнительных утилит.
- **Gaming DNS Benchmark & DoH Switcher**: живой замер задержек DNS и включение DNS-over-HTTPS.
- **GPU & Display Powerhouse**: отключение MPO, включение HAGS, оптимизации DirectX для оконных игр, защита видеодрайверов и удаление гигабайтов поврежденного кэша шейдеров.

---

## ⚡ Архитектура и Структура Файлов

```
├── Запустить Оптимизатор.bat        <-- Главный ярлык запуска от Администратора (RU)
├── Start-Optimizer.bat              <-- Альтернативный англоязычный лаунчер
├── Start.bat                        <-- Локальный лаунчер
├── Win11Optimizer.ps1               <-- Главный исполняемый движок (TUI + CLI)
├── Test-Win11Optimizer.ps1          <-- Автоматизированный тестовый набор (28 тестов)
├── README.md                        <-- Данная инженерная документация
├── .gitignore                       <-- Игнорирование бэкапов и логов
└── Modules/
    ├── Safety.psm1                  <-- Точки восстановления и движок снимков/отката
    ├── GamingLatency.psm1           <-- MSI Mode, CPU Scheduling, Standby RAM Cleaner
    ├── NetworkGaming.psm1           <-- Nagle, RSS, DNS Benchmark & DoH Switcher
    ├── GpuDisplay.psm1              <-- MPO, HAGS, DirectX Windowed, HDCP, Очистка кэша GPU
    ├── Debloat.psm1                 <-- Отключение Recall (24H2), Copilot, Bing, Telemetry
    ├── SystemUI.psm1                <-- Classic меню, Проводник, Главная, Пуск, Maintenance
    ├── AppInstaller.psm1            <-- Тихий установщик Winget (замена 170+ ссылок)
    └── Diagnostics.psm1             <-- Аудит 26+ настроек, пинг, DPC/ISR, таймер Win32
```

---

## 🔬 Что изменено по сравнению со старым набором Max.mov

| Старый пак (Настройка Windows 11) | Новый Win11 Optimizer Suite |
| :--- | :--- |
| **171 ручной `.url` файл** (требовалось вручную кликать и скачивать софт) | **Автоматический silent-установщик `winget`**: установка в 1 клик без рекламы и браузера |
| **Timer Resolution.7z** с архивным паролем "Плацебо", вызывающим детекты на VirusTotal | **Безопасная Win32-диагностика таймера**: честный замер через `NtQueryTimerResolution` без сомнительных DLL |
| **Кривой `.bat` скрипт удаления GameBar** с синтаксической ошибкой `"$env:SystemRoot..."`, ломающий реестр | **Чистая хирургическая оптимизация GameDVR**: отключение фоновой записи и FSE-режим без повреждения Xbox/Store |
| **Отсутствие бэкапов и отката**: изменения вносились "навсегда" | **Полный движок отката**: автоматические JSON-снимки до модификации + точки восстановления Windows |
| **Ручные текстовые инструкции**, как кликать в настройках Windows | **Автоматизация через PowerShell API**: все твики применяются за секунды |
| **Забитый кэш шейдеров и статтеры** | **Авто-очистка шейдеров DirectX/OpenGL и Temp (~7+ ГБ)** для устранения дропов FPS |

---

## 🛠 Ключевые Функциональные Блоки

### 1. Жёсткая оптимизация и Standby RAM (Gaming Latency)
- **Standby RAM Cleaner & WorkingSet Purge**: Высокопроизводительный C# P/Invoke хелпер, запрашивающий `SeProfileSingleProcessPrivilege` и вызывающий `NtSetSystemInformation` (`SystemMemoryListInformation = 80`, `MemoryPurgeStandbyList = 4` и `MemoryEmptyWorkingSets = 2`). Мгновенно освобождает сотни мегабайт и гигабайты забитого кэша оперативной памяти без ошибок `STATUS_PRIVILEGE_NOT_HELD`.
- **MSI Mode (Message Signaled Interrupts)**: Сканирует шину PCI, находит видеокарту (RTX/GTX/Radeon), сетевую карту и звуковой контроллер, переключает их в высокоскоростной MSI-режим с наивысшим приоритетом прерываний (`DevicePriority = 3 / High`). Это минимизирует DPC/ISR лаги и устраняет микрофризы в соревновательных играх (CS2, Valorant, Dota 2, Apex Legends).
- **CPU Scheduling (Win32PrioritySeparation = 38 / 0x26)**: Переменные короткие кванты с 3-кратным приоритетом активного игрового процесса.
- **Power Throttling Off & Core Parking Off**: 100% ядер процессора всегда активны без падения частот.
- **SystemResponsiveness = 0**: 100% ресурсов процессора отдаются игре без 20% системной брони Windows.
- **Тумблер VBS / HVCI**: Возможность отключения изоляции ядра для слабых или старых CPU для прироста 5–15% FPS.

### 2. GPU, Дисплей и Кэш шейдеров (GpuDisplay.psm1)
- **MPO Toggle (Multi-Plane Overlay)**: Установка `OverlayTestMode = 5` в DWM. Полностью устраняет мерцания экрана, черные экраны и статтеры при одновременной работе игр с Discord, OBS Studio и браузерами.
- **HAGS (Hardware-Accelerated GPU Scheduling)**: Активация аппаратного планировщика GPU (`HwSchMode = 2`), необходимого для генерации кадров DLSS 3 / FSR 3 и уменьшения задержки ввода.
- **Оптимизации оконных игр DirectX**: Активация `DirectXUserGlobalSettings = "AutoPlayMode=1;"` для borderless/оконных игр с поддержкой переменной частоты обновления (VRR / G-Sync).
- **Защита видеодрайвера от Windows Update**: Блокировка автоматической перезаписи кастомных стабильных драйверов GPU (`ExcludeWUDriversInQualityUpdate = 1`).
- **Динамический NVIDIA HDCP DRM Killer**: Автоматический поиск видеокарт NVIDIA на шине PCI и отключение DRM рукопожатий HDCP (`RMHdcpKeyglobZero = 1`) для устранения микро-задержек рендеринга.
- **Очистка кэша шейдеров и Temp (7+ ГБ)**: Безопасное удаление устаревших и битых файлов компиляции шейдеров (`NVIDIA DXCache`, `GLCache`, `D3DSCache`, `AMD DxCache`, `TEMP`, `SoftwareDistribution\Download`).

### 3. Киберспортивный сетевой стек и DNS Switcher (Network Stack)
- **Gaming DNS Benchmark**: Живое тестирование времени отклика (Query Latency + ICMP Ping) к ведущим провайдерам Anycast DNS:
  - Cloudflare (`1.1.1.1` / `1.0.0.1` + DoH)
  - Quad9 (`9.9.9.9` / `149.112.112.112` + DoH)
  - AdGuard (`94.140.14.14` / `94.140.15.15` + DoH с блокировкой рекламы)
  - Google (`8.8.8.8` / `8.8.4.4` + DoH)
  - Текущий DNS провайдера / роутера
- **1-Click DoH Switcher**: Переключение DNS с автоматической регистрацией и включением шифрования DNS-over-HTTPS в Windows 11.
- **Сброс на DHCP**: Мгновенный возврат к автоматическим настройкам роутера.
- **Отключение алгоритма Нейгла (`TcpAckFrequency = 1`, `TCPNoDelay = 1`, `TcpDelAckTicks = 0`)**: Пакеты ввода отправляются немедленно.
- **NetworkThrottlingIndex = 0xFFFFFFFF**: Полное снятие ограничения скорости не-мультимедийного сетевого трафика.
- **Receive Side Scaling (RSS = enabled)**: Распределение сетевых очередей по нескольким ядрам CPU.

### 4. Smart Modern Debloat (Windows 11 24H2)
- **Отключение AI Recall (24H2)**: Блокировка фонового анализа активности.
- **Отключение Microsoft Copilot**: Полное скрытие кнопки и отключение процессов Windows Copilot.
- **Отключение Bing Search в меню Пуск**: Меню Пуск моментально находит только локальные файлы.
- **Отключение виджетов и ленты новостей** на панели задач.
- **Блокировка телеметрии**: Остановка и отключение служб `DiagTrack` и `dmwappushservice`.
- **Безопасное удаление UWP Bloatware** с жестким сохранением Microsoft Store, Xbox, Калькулятора, Блокнота и Ножниц.

### 5. Интерфейс и система (System UI)
- **Скрытие блока "Рекомендуем" в меню Пуск**: Включение режима `IsEducationEnvironment = 1` и `HideRecommendedSection = 1` для полного скрытия секции на Windows 11 Pro/Home.
- **Скрытие раздела "Главная" (Home)**: Удаление из левой навигационной панели Проводника.
- **Отключение автоматического обслуживания Windows**: Блокировка фоновой дефрагментации и сканирования диска (`MaintenanceDisabled = 1`) во время игр.
- **Классическое контекстное меню Windows 10**: Возврат полного меню без кнопки *"Показать дополнительные параметры"*.
- **Оптимизация Проводника**: Расширения файлов, скрытые файлы, открытие *"Этот компьютер"*, компактный вид.
- **Активация быстрого Просмотра Фотографий Windows (`photoviewer.dll`)**.
- **Отключение энергосбережения USB**: Защита от микродропов мыши и клавиатуры.

### 6. Менеджер пакетов (`winget`)
Интерактивное меню тихой установки проверенного софта (игры, утилиты, лаунчеры, браузеры, рантаймы C++).

### 7. Проверка оптимизации компьютера (Health-Check & Рекомендации)
- **Аудит 26 ключевых параметров системы**:
  - 🟢 **ЭТИ НАСТРОЙКИ В НОРМЕ**
  - 🔴 **ЭТИ НАСТРОЙКИ НУЖНО ВЫПОЛНИТЬ** (с рекомендацией и точным номером меню)
- **Индикатор оптимизации (%) и вердикт**.
- **Быстрое действие**: клавиша `1` для применения супер-буста в один клик.

---

## 🎮 Как запускать

### Способ 1: Интерактивное меню
Дважды щелкните на:
`Запустить Оптимизатор.bat` (или `Start.bat`)

```
  ГЛАВНОЕ МЕНЮ ОПТИМИЗАЦИИ:
  [1]   🔎  ПРОВЕРИТЬ ОПТИМИЗАЦИЮ ПК (Аудит 26 настроек [✓] / [!])
  [2]   🚀  ИГРОВОЙ СУПЕР-БУСТ (MSI, CPU, GPU, MPO, HAGS, Сеть, RAM, UI)
  [3]   ⚡  ЖЁСТКАЯ ОПТИМИЗАЦИЯ (MSI Mode, CPU Scheduling, RAM Cleaner, VBS)
  [4]   🌐  ИГРОВОЙ СЕТЕВОЙ СТЕК (Nagle Off, RSS, DNS Benchmark & DoH Switcher)
  [5]   🎮  GPU, ДИСПЛЕЙ И КЭШ ШЕЙДЕРОВ (MPO, HAGS, HDCP, Очистка 7+ ГБ кэша)
  [6]   🛡  SMART DEBLOAT (Recall 24H2, Copilot, Bing, Telemetry, Safe UWP)
  [7]   🎨  ИНТЕРФЕЙС И СИСТЕМА (Classic Меню, Проводник, Главная, Пуск, Maintenance)
  [8]   📦  МЕНЕДЖЕР ПРИЛОЖЕНИЙ WINGET (Замена 170+ устаревших веб-ссылок)
  [9]   📊  ДИАГНОСТИКА ЗАДЕРЖЕК (Замер пинга, Live DPC/ISR, таймер Windows)
  [10]  🔄  ОТКАТ И ВОССТАНОВЛЕНИЕ (Восстановление исходных параметров Windows)
  [0]   🚪  Выход
```

### Способ 2: Запуск из PowerShell (CLI Режимы)
```powershell
# Запуск быстрой проверки оптимизации компьютера
powershell -ExecutionPolicy Bypass -File .\Win11Optimizer.ps1 -Mode HealthCheck

# Полный игровой супер-буст
powershell -ExecutionPolicy Bypass -File .\Win11Optimizer.ps1 -Mode AutoGaming

# Очистка Standby RAM кэша
powershell -ExecutionPolicy Bypass -File .\Win11Optimizer.ps1 -Mode RamClean

# Тест игровых DNS серверов
powershell -ExecutionPolicy Bypass -File .\Win11Optimizer.ps1 -Mode DnsBenchmark

# Применение только твиков GPU и дисплея (MPO, HAGS, DirectX)
powershell -ExecutionPolicy Bypass -File .\Win11Optimizer.ps1 -Mode GpuOnly

# Просмотр изменений без их применения (Dry-Run режим)
powershell -ExecutionPolicy Bypass -File .\Win11Optimizer.ps1 -Mode AutoGaming -DryRun
```

### Способ 3: Откат (Rollback)
В главном меню выберите пункт `[10] ОТКАТ И ВОССТАНОВЛЕНИЕ`, либо запустите:
```powershell
powershell -ExecutionPolicy Bypass -File .\Win11Optimizer.ps1 -Mode Rollback
```

---

## 🛡 Проверка целостности и тесты
Для запуска встроенного набора автоматических тестов:
```powershell
powershell -ExecutionPolicy Bypass -File .\Test-Win11Optimizer.ps1
```
*(Все 28 тестов завершаются со статусом `[PASS]` и Exit Code 0).*
