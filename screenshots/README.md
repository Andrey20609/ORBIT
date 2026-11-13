# Скриншоты Sprint 02

Все девять PNG в этом каталоге имеют источник **Flutter golden test**. Они отрисованы на Linux x64 в Flutter test environment с размером логического кадра 390×844, Eco/Static и отключённым движением. Это не Android emulator screenshots, не physical Android screenshots и не кадры Rive/Filament Android runtime.

| Файл | Поверхность | Источник |
|---|---|---|
| `01_Today_ORBIT_One.png` | Today, ORBIT One | Flutter golden test |
| `02_Today_Atelier.png` | Today, Atelier | Flutter golden test |
| `03_Today_Flow.png` | Today, Flow | Flutter golden test |
| `04_Today_Zen.png` | Today, Zen | Flutter golden test |
| `05_Mail_Inbox.png` | Почта | Flutter golden test |
| `06_Mail_Message.png` | Просмотр письма | Flutter golden test |
| `07_Mail_Compose.png` | Создание письма | Flutter golden test |
| `08_Calendar.png` | Календарь | Flutter golden test |
| `09_Tasks.png` | Задачи | Flutter golden test |

Android screenshots и видео: **NOT RUN**, поскольку online Android device/emulator в среде недоступен. Подготовленный `integration_test/app_test.dart` сохраняет device PNG при фактическом запуске; Static fallback не должен выдаваться за доказанный Filament-кадр.
