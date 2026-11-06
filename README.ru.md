<div align="center">

# Cibula

**Бесплатный приватный браузер для iPhone. Каждый запрос идёт через Tor.**

*Слой за слоем, без следов.*

**Cibula — форк [Onion Browser](https://github.com/OnionBrowser/OnionBrowser)** с обновлённым дизайном и без лишнего хлама.

[![Форк Onion Browser](https://img.shields.io/badge/форк-Onion%20Browser-7D4CDB?style=for-the-badge)](https://github.com/OnionBrowser/OnionBrowser)
[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](#требования)
[![Tor](https://img.shields.io/badge/сеть-Tor-7D4CDB?style=for-the-badge&logo=torproject&logoColor=white)](https://www.torproject.org/)
[![Telegram](https://img.shields.io/badge/Telegram-Скачать-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](#скачать)

[English](README.md) · **Русский** · [Українська](README.uk.md)

</div>

---

> **Cibula — форк Onion Browser.** Это независимый проект, он не связан с авторами Onion Browser, Tigas Ventures LLC и The Tor Project и не одобрен ими.

## Скачать

Актуальную готовую версию Cibula можно скачать в нашем Telegram-канале.

[![Скачать в Telegram](https://img.shields.io/badge/Telegram-Скачать%20последнюю%20версию-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](TELEGRAM_LINK)

Cibula нет в App Store. Сборки — это файлы `.ipa`. iOS не устанавливает неподписанные приложения, поэтому, если в посте канала не сказано, что сборка уже подписана, сначала подпишите её своим сертификатом разработчика Apple (см. [Установка](#установка)).

## Возможности

- **Только Tor.** Встроенный Tor — единственный вариант. Без Orbot и лишних выборов.
- **Новый вид.** Тёмно-фиолетовая тема, новый экран приветствия и новый экран «Заходим в сеть Tor».
- **Панели Liquid Glass.** Адресная строка и панель кнопок плавают над страницей в виде скруглённых стеклянных капсул (настоящий Liquid Glass на iOS 26, матовое стекло на более старых версиях).
- **Объединение панелей.** Переключатель в настройках собирает адресную строку и кнопки в одну капсулу внизу, как в Safari (Настройки, раздел «Разное», нужен перезапуск приложения).
- **Вкладки как в Safari.** Высокие карточки в два столбца, удержание и перетаскивание для перестановки, смахивание вверх для закрытия.
- **Меньше лишнего.** Короткий экран настроек, только нужное.
- **Бесплатно.** Без рекламы, подписок и скрытых платежей.

## Требования

iPhone с iOS 17 или новее (встроенному Tor это нужно).

## Установка

1. Скачайте `Cibula.ipa` из [Telegram-канала](#скачать).
2. Подпишите его своим сертификатом и профилем (bundle ID должен совпадать с профилем) и установите на устройство.

## Собрать самому

Без Mac проще всего через файл `codemagic.yaml` из репозитория: подключите репозиторий к [Codemagic](https://codemagic.io/), выберите workflow `cibula-ipa` и запустите сборку. Когда она закончится, скачайте `Cibula-ipa.zip` из артефактов и переименуйте в `Cibula.ipa`.

На Mac можно собрать через Xcode, см. [BUILD.md](BUILD.md).

## Безопасность

Прочитайте [SECURITY.md](SECURITY.md), особенно раздел об известных ограничениях. Tor сам по себе не делает вас анонимным.

## Благодарности

- [Onion Browser](https://github.com/OnionBrowser/OnionBrowser): Майк Тигас, участники проекта и переводчики. Cibula — форк и построен на их работе.
- [Endless](https://github.com/jcs/endless): joshua stein, на нём основан Onion Browser.
- [The Tor Project](https://www.torproject.org/) и открытые библиотеки, которые приносят Tor на iOS.

## Лицензия

См. [LICENSE](LICENSE). Там лежат лицензия Onion Browser и лицензия Endless, они действуют для этого проекта.
