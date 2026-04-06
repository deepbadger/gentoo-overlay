# Руководство разработчика

Инструкции по разработке и тестированию ebuilds для оверлея **Badger**.

Справочник: https://devmanual.gentoo.org/

## Структура пакета

```
<category>/<package>/
    <package>-<version>.ebuild   # по одному файлу на версию
    metadata.xml                  # двуязычное описание (en + ru)
    Manifest                      # контрольные суммы, генерируется portage
```

## Шаг 1. Создать ebuild и сгенерировать Manifest

```bash
# Сгенерировать / обновить Manifest (скачивает дистрибутив, считает хэши)
ebuild <category>/<pkg>/<pkg>-<ver>.ebuild manifest
```

## Шаг 2. Запустить фазы сборки вручную

Фазы выполняются последовательно: `fetch → unpack → prepare → configure → compile → install → qmerge`.  
Указание более поздней фазы автоматически запускает все предыдущие, которые ещё не выполнялись.

```bash
# Сбросить рабочую директорию и скачать исходники
ebuild <category>/<pkg>/<pkg>-<ver>.ebuild clean fetch

# Распаковать и проверить структуру архива (убедиться, что S= указан правильно)
ebuild <category>/<pkg>/<pkg>-<ver>.ebuild unpack
ls /var/tmp/portage/<category>/<pkg>-<ver>/work/

# Выполнить установку в образ
ebuild <category>/<pkg>/<pkg>-<ver>.ebuild install

# Проверить образ до слияния с живой системой
ls /var/tmp/portage/<category>/<pkg>-<ver>/image/

# Слить в живую систему
ebuild <category>/<pkg>/<pkg>-<ver>.ebuild qmerge
```

## Шаг 3. Установить через emerge

```bash
# Предварительный просмотр без установки
emerge --pretend --tree --verbose <category>/<pkg>

# Установить с подтверждением
emerge --ask <category>/<pkg>

# Переустановить, даже если версия уже установлена
emerge --ask --oneshot <category>/<pkg>
```

## Шаг 4. QA-проверка через pkgcheck

`pkgcheck` — современная замена устаревшему `repoman`.

```bash
# Установить, если отсутствует
emerge dev-util/pkgcheck

# Проверить директорию пакета
cd <category>/<pkg>
pkgcheck scan

# Проверить с сетевыми проверками (доступность URL и т.д.)
pkgcheck scan --net

# Проверить только незапушенные изменения
pkgcheck scan --commits
```

Типичные ошибки, которые нужно исправить до коммита: `DeprecatedEapi`, `MissingLicense`, `InvalidKeywords`, нарушения sandbox.

## Шаг 5. Проверить результат установки

```bash
# Список установленных файлов
equery files <category>/<pkg>

# Проверить .desktop-файл
desktop-file-validate /usr/share/applications/<name>.desktop

# Проверить симлинки
ls -la /usr/bin/<pkg>

# Запустить приложение
/usr/bin/<pkg> &
```

## Шаг 6. Удалить пакет

```bash
emerge --ask --unmerge <category>/<pkg>
```

## Sandbox

Portage sandbox активен во время фаз `src_unpack`, `src_compile`, `src_test` и `src_install` — блокирует запись вне разрешённых директорий. Для бинарных пакетов этого оверлея используется `QA_PREBUILT="*"`, чтобы подавить предупреждения QA о strip/prelink. Отключать sandbox не следует.
