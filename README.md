# Робот "Развальчик"

Основой данного робота является плата MatrixMini (Arduino Uno R3)

Данный репозиторий содержит несколько проектов:

1. [RemoteByUSB](RemoteByUSB)
2. [RemoteByRPI](RemoteByRPI)

## RemoteByUSB

В данном проекте реализовано управление робот через общение по Serial порту (COM порту) по средством проводного соединения (USB-A <-> USB-B)

[Инструкция по запуску робота](RemoteByUSB/README.md)

Есть несколько вариантов запуска робота:

1. Используя приложение [Flutter](RemoteByUSB/fluttercode/LastBuild/)
2. Используя программный код [python](RemoteByUSB/PythonCode/)

## RemoteByRPI

В данном проекте реализовано управление робот через общение по WebSocket по средством беспроводного соединения к сети Wi-Fi `CamberedBot-{UUID4}` и дальнейшей передаче сообщений роботу через Serial порт (COM порт) [[RemoteByUSB](#remotebyusb)]

[Инструкция по запуску робота](RemoteByUSB/README.md)

Есть несколько вариантов запуска робота:

1. Используя приложение [Flutter](RemoteByUSB/fluttercode/LastBuild/)
2. Используя программный код [python](RemoteByUSB/PythonCode/)
