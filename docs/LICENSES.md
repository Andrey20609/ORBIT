# Лицензии и происхождение ресурсов

- **Rive runtime**: MIT. Используется локальный runtime из пакета `rive` / `rive_native`; публикация в Rive и платные действия не выполнялись.
- **orbit_mark.riv / orbit_atmosphere.riv и исходники `rive/**/scene.rml`**: собственные процедурно созданные сцены Visual Lab, не ресурсы из чужого коммерческого проекта. `orbit_atmosphere.riv` содержит artboard `OrbitAtmosphere`, state machine `OrbitLoop` и trigger `Pulse`. `rive_mark_preview.png` — кадр фирменного знака.
- **Google Filament**: Apache License 2.0. Android runtime и `matc` закреплены версией 1.79.0.
- **Flutter**: BSD 3-Clause; условия относятся к SDK, а не автоматически к коду приложения.
- **Noto Sans / Noto Serif**: SIL Open Font License 1.1. Полный текст сохранён в `assets/fonts/Noto-OFL.txt`. Локальные `OrbitSans*` и `OrbitSerif*` являются именами family в приложении, а не новыми шрифтами с изменёнными контурными данными.
- **go_router, shared_preferences, intl, clock и transitive packages**: их лицензии находятся в соответствующих пакетах pub и должны быть включены в production attribution при распространении. `clock` используется также для воспроизводимых дат в Today/Calendar и golden-тестах.

Пользовательские визуальные референсы использовались только как ориентир стиля; они не упакованы в приложение как готовые фоновые изображения. Процедурные сцены, mesh и materials созданы в этом проекте.

Перед публикацией production-приложения нужно повторно проверить лицензии фактически закреплённых версий зависимостей и сформировать полный third-party notice.
