<div align="center">

# Cibula

**Безкоштовний приватний браузер для iPhone. Кожен запит іде через Tor.**

*Шар за шаром, без слідів.*

**Cibula — форк [Onion Browser](https://github.com/OnionBrowser/OnionBrowser)** з оновленим дизайном і без зайвого мотлоху.

[![Форк Onion Browser](https://img.shields.io/badge/форк-Onion%20Browser-7D4CDB?style=for-the-badge)](https://github.com/OnionBrowser/OnionBrowser)
[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](#вимоги)
[![Tor](https://img.shields.io/badge/мережа-Tor-7D4CDB?style=for-the-badge&logo=torproject&logoColor=white)](https://www.torproject.org/)
[![Telegram](https://img.shields.io/badge/Telegram-Завантажити-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](#завантажити)

[English](README.md) · [Русский](README.ru.md) · **Українська**

</div>

---

> **Cibula — форк Onion Browser.** Це незалежний проєкт, він не пов'язаний з авторами Onion Browser, Tigas Ventures LLC та The Tor Project і не схвалений ними.

## Завантажити

Актуальну готову версію Cibula можна завантажити в нашому Telegram-каналі.

[![Завантажити в Telegram](https://img.shields.io/badge/Telegram-Завантажити%20останню%20версію-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](TELEGRAM_LINK)

Cibula немає в App Store. Збірки — це файли `.ipa`. iOS не встановлює непідписані застосунки, тому, якщо в дописі каналу не сказано, що збірка вже підписана, спочатку підпишіть її власним сертифікатом розробника Apple (див. [Встановлення](#встановлення)).

## Можливості

- **Тільки Tor.** Вбудований Tor — єдиний варіант.
- **Новий вигляд.** Темно-фіолетова тема, новий екран привітання та новий екран «Заходимо в мережу Tor».
- **Панелі Liquid Glass.** Адресний рядок і панель кнопок плавають над сторінкою у вигляді заокруглених скляних капсул (справжній Liquid Glass на iOS 26, матове скло на старіших версіях).
- **Об'єднання панелей.** Перемикач у налаштуваннях збирає адресний рядок і кнопки в одну капсулу внизу, як у Safari (Налаштування, розділ «Різне», потрібен перезапуск застосунку).
- **Вкладки як у Safari.** Високі картки у два стовпці, утримуйте й перетягуйте для зміни порядку, змахніть угору, щоб закрити.
- **Менше зайвого.** Короткий екран налаштувань, лише потрібне.
- **Безкоштовно.** Без реклами, підписок і прихованих платежів.

## Вимоги

iPhone з iOS 17 або новішою (вбудованому Tor це потрібно).

## Встановлення

1. Завантажте `Cibula.ipa` із [Telegram-каналу](#завантажити).
2. Підпишіть його власним сертифікатом і профілем (bundle ID має збігатися з профілем) і встановіть на пристрій.

## Зібрати самому

Без Mac найпростіше через файл `codemagic.yaml` із репозиторію: підключіть репозиторій до [Codemagic](https://codemagic.io/), оберіть workflow `cibula-ipa` і запустіть збірку. Коли вона завершиться, завантажте `Cibula-ipa.zip` з артефактів і перейменуйте на `Cibula.ipa`.

На Mac можна зібрати через Xcode, див. [BUILD.md](BUILD.md).

## Безпека

Прочитайте [SECURITY.md](SECURITY.md), особливо розділ про відомі обмеження. Tor сам по собі не робить вас анонімним.

## Подяки

- [Onion Browser](https://github.com/OnionBrowser/OnionBrowser): Майк Тігас, учасники проєкту та перекладачі. Cibula — форк і побудований на їхній роботі.
- [Endless](https://github.com/jcs/endless): joshua stein, на ньому ґрунтується Onion Browser.
- [The Tor Project](https://www.torproject.org/) та відкриті бібліотеки, які приносять Tor на iOS.

## Ліцензія

Див. [LICENSE](LICENSE). Там лежать ліцензія Onion Browser і ліцензія Endless, вони діють для цього проєкту.
