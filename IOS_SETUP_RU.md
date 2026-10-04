# Как поставить SymptoPage на iPhone

## Вариант А — со своего Mac (бесплатный Apple ID подходит)

1. Освободите ~35 ГБ на диске и установите **Xcode** из App Store. Откройте его один раз, согласитесь с условиями.
2. Xcode → Settings → Accounts → «+» → войдите своим Apple ID.
3. На iPhone: Настройки → Конфиденциальность и безопасность → **Режим разработчика** → Вкл. Подключите iPhone кабелем, «Доверять».
4. В Терминале в папке проекта: `bash scripts/install_on_iphone.sh`
   Приложение (и приложение для Apple Watch) установится и откроется. При первом запуске: Настройки → Основные → VPN и управление устройством → доверять своему Apple ID.
   С бесплатным Apple ID приложение работает 7 дней — потом снова запустите команду (данные сохраняются).

## Вариант Б — ссылка TestFlight для себя и других (Apple Developer Program, 99 $/год)

`bash scripts/make_ipa.sh ВАШ_TEAM_ID` — сборка загружается в App Store Connect; в разделе TestFlight добавьте тестировщиков, они ставят приложение по ссылке. Это же путь в App Store (скриншоты: `SymptoPage-AppStore-screenshots`).

## Вариант В — без Xcode на этом Mac

Загрузите папку в репозиторий GitHub: workflow `.github/workflows/ios.yml` соберёт неподписанный `SymptoPage-unsigned.ipa` (подпишите своим Apple ID в Sideloadly) или, при наличии ключа App Store Connect, отправит сборку в TestFlight.


## Посмотреть интерфейс сейчас на этом Mac

1. Откройте `SymptoPage-iOS-Preview.app`, расположенный рядом с папкой `SymptoPage-iOS`.
2. Выберите English или Polski и создайте свой первый визит.
3. Три вкладки, как в макете: Start / Raport / Ustawienia. Дневник и «Lekarze i leki» (врачи и лекарства) открываются плитками на Start; дневник также из вкладки Raport.
4. Приложение запускается без примеров. Можно добавлять врачей, симптомы, назначения и формировать PDF.

Это нативный предпросмотр общего SwiftUI-кода на Mac. Он не устанавливается на iPhone и не заменяет тестирование iOS. Напоминания в нём намеренно не включаются.

## Открыть код и визуальный редактор

Нужен **полный Xcode на Mac**, включая iOS Simulator runtime. Command Line Tools недостаточно. В текущей среде установлен только Swift/Command Line Tools; готового `.ipa` нет.

1. Установите Xcode из официального Mac App Store или Apple Developer Downloads. Первый запуск может потребовать установки компонентов и принятия условий Apple владельцем аккаунта.
2. Откройте файл **SymptoPage.xcodeproj** внутри этой папки. Не создавайте новый пустой проект.
3. В левом дереве откройте **App/SymptoPageApp.swift** — точка входа и Canvas Preview.
4. Для визуального просмотра включите **Editor → Canvas** и нажмите Resume. Предпросмотр использует отдельное временное хранилище.
5. Выберите схему **SymptoPage**, устройство iPhone Simulator и нажмите ▶︎ или Cmd+R.
6. Если устройств нет, установите iOS runtime через Settings → Components / Platforms (название зависит от Xcode).

Минимальная цель приложения — iOS 17. Рекомендуется поддерживаемая версия Xcode с доступным iOS SDK. Xcode 16+ соответствует использованной конфигурации; фактическую iOS-сборку необходимо выполнить на установленном Xcode.

## Запустить на своём iPhone

1. Подключите iPhone к Mac кабелем и подтвердите доверие на устройстве, если оно запрошено.
2. Добавьте свой Apple Account в Xcode → Settings → Apple Accounts.
3. Откройте target **SymptoPage → Signing & Capabilities**.
4. Оставьте **Automatically manage signing**, выберите свою **Team**.
5. При конфликте идентификатора замените `app.symptopage.ios` на уникальный, например `com.yourname.symptopage`. Пароль и ключи подписи в репозиторий не добавляйте.
6. Выберите свой iPhone в списке устройств Xcode.
7. Если Xcode попросит, включите на iPhone **Settings → Privacy & Security → Developer Mode**, перезапустите устройство и подтвердите включение.
8. Нажмите Cmd+R. Приложение появится на телефоне после успешной подписи и сборки.

Личный Apple Account может использоваться для запуска на собственном устройстве с ограничениями personal team. Доступность, срок подписи и ограничения проверяйте в Xcode и официальной документации Apple. TestFlight/App Store — отдельный процесс с Apple Developer Program, архивированием, проверкой и настройками публикации; в этой задаче он не выполнялся.

## Проверить приложение

- Создать двух врачей и два наблюдения.
- Добавить симптом, связанный с обоими; убедиться, что в общем журнале одна запись.
- Перезапустить приложение и проверить сохранность.
- Изменить язык, отредактировать и отменить запись.
- Записать результат визита, приложить PDF/изображение, добавить повторную дату.
- Добавить курс точно по назначению врача, проверить дату окончания и дни недели.
- В Settings включить уведомления и разрешить их в системном запросе.
- Создать тестовое напоминание на несколько минут вперёд; проверить фон, закрытое приложение, запрет уведомлений, изменение расписания и удаление устаревшего напоминания.
- Проверить срок очереди уведомлений в Settings; открытие приложения продлевает её.
- Проверить PDF в Files и системную печать с доступным принтером.
- Экспортировать резервную копию и восстановить её на тестовых данных.

## Если что-то не запускается

- `Signing requires a development team` → выбрать Team.
- `Bundle identifier is not available` → указать собственный уникальный Bundle Identifier.
- `No such module UIKit` → выбран macOS SDK или открыта неправильная схема; для iPhone открывайте `.xcodeproj`, схема SymptoPage.
- Нет Simulator → установить iOS runtime в Xcode.
- Только Command Line Tools → выбрать установленный Xcode в Xcode Settings → Locations → Command Line Tools.
- Нет уведомления → проверить разрешение, Focus, время курса, активность, дни недели и показанный срок очереди. Отправка уведомления не подтверждает приём лекарства.

Для разработчика: `bash scripts/check_ios.sh` запускает core XCTest и UI-тесты на доступном iPhone Simulator. Скрипт заканчивается явной ошибкой, если Xcode/runtime отсутствуют.

Официальные инструкции Apple:
- https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices
- https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device
- https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app

## Apple Watch, Apple Health и Strava

- В Xcode схема **SymptoPage** собирает iPhone-приложение вместе с приложением для часов; схема **SymptoPage Watch** запускает только часы в симуляторе.
- В Signing & Capabilities у обеих целей должна быть включена **HealthKit** (файл прав уже подключён: `Configuration/HealthKit.entitlements`). Нужна команда разработчика Apple.
- Apple Health: Ustawienia → Integracje → «Połącz Apple Health». Дальше данные подтягиваются сами при каждом открытии.
- Strava: на https://www.strava.com/settings/api создайте приложение, в поле **Authorization Callback Domain** укажите `localhost`. Скопируйте Client ID и Client Secret в Integracje и нажмите «Połącz Strava». В Mac-превью Strava тоже работает.
- Часы: записи с часов приходят на iPhone даже если приложение закрыто; повторная доставка не создаёт дублей.
