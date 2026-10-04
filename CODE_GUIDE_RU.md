# Где смотреть код

Откройте `SymptoPage.xcodeproj` в Xcode. Файлы в проекте ссылаются на исходники в этой папке; копировать их вручную не нужно.

| Файл | Что делает |
|---|---|
| App/SymptoPageApp.swift | Запуск, 3 вкладки, регистрация шрифтов, обновление очереди при возврате, Canvas Preview |
| App/Design.swift | Токены дизайна, карточки, чипы, FlowLayout, логотип, формы, выбор врачей |
| App/WelcomeView.swift | Экран приветствия (дизайн, экран 1) |
| App/HealthService.swift | Чтение Apple Health: дни, сон, тренировки, пульс у симптомов |
| App/StravaService.swift | Strava: вход OAuth, Keychain, загрузка тренировок |
| App/PhoneWatchBridge.swift | Связь iPhone ↔ Apple Watch (WatchConnectivity) |
| App/HealthViews.swift | Карточка «Z zegarka i Strava», графики, экран Integracje |
| Watch/*.swift | Приложение для часов: Teraz, сила, вопрос дня, настроение |
| Core/Health.swift | Модели дней и тренировок, слияние без дублей |
| Core/Strava.swift | Клиент Strava API v3 и разбор ответов |
| Core/WatchMessages.swift | Обмен с часами: контекст и записи |
| App/NotesViews.swift | Заметки о самочувствии: форма и карточка |
| App/TodayView.swift | Вкладка Start: быстрое добавление визита, карусель наблюдений, ежедневный вопрос, Teraz, план лекарств (экраны 2–4) |
| App/CareView.swift | Врачи, наблюдения, визиты, назначения и документы |
| App/CaptureForms.swift | События симптомов и ежедневные оценки |
| App/MedicationViews.swift | Курсы, времена, дни недели, подтверждения |
| App/JournalView.swift | Дневник: единая лента по дням (симптомы, ответы, заметки), фильтры, поиск |
| App/ReportView.swift | Вкладка Raport: период, плитки, PDF, переход в дневник |
| App/SettingsView.swift | Язык, уведомления, резервные копии, восстановление |
| App/AppStore.swift | Состояние интерфейса и транзакции |
| App/NotificationService.swift | Очередь локальных уведомлений iOS |
| Core/Catalog.swift | Каталог симптомов и специальностей, теги, заметки |
| Core/Models.swift | Сущности и EN/PL подписи |
| Core/Persistence.swift | Проверка данных, атомарная запись, миграция Windows |
| Core/MedicationHistory.swift | История назначений с моментом вступления изменений в силу |
| Core/Scheduling.swift | Дни, часовые пояса, планирование доз |
| Core/Report.swift | Содержание отчёта без медицинских выводов |
| Core/PDFRenderer.swift | Оформленный PDF: шапка, плитки, таблица, сетка ответов, страницы |
| Tests/CoreTests.swift | Проверки данных, расписания, миграции и PDF |
| UITests/SymptoPageUITests.swift | Сценарии Simulator: пустой запуск, отмена, сохранение после перезапуска |

В Xcode включите Canvas для `SymptoPageApp.swift`. `SymptoPageCanvas` создаёт отдельный пустой store. Для разработки отдельных экранов используйте тот же AppStore, переданный через environmentObject.

`Package.swift` нужен для проверки ядра и компиляции предпросмотра на Mac. Это не замена iOS application target.

Проект воспроизводимо генерируется командой `python3 scripts/generate_project.py`. Если изменяете настройки сборки, внесите изменение и в генератор. Для ручной работы в Xcode генератор запускать не обязательно; project.pbxproj уже включён.

Проверка «ничего не сломалось»: `bash scripts/check_all.sh`. Скриншоты всех экранов складываются в папку, которую печатает скрипт.
