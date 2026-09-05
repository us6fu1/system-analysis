# Системный анализ AI History Helper

Это аналитическая часть моего дипломного проекта
[AI History Helper](https://github.com/us6fu1/AI_History_Helper) — десктопного
приложения для подготовки тестов по истории.

Само приложение я делал как разработчик. Позже решил разобрать его с позиции
системного аналитика: описать пользовательский процесс, требования, ошибки и то,
как можно развивать продукт дальше.

![Процесс подготовки теста](ai-history-helper-portfolio-as-is.png)

Это схема текущего процесса. Замена вопроса работает только для одного
открытого варианта, а изменённая версия пока не сохраняется обратно в историю.

## Что делает приложение

Преподаватель выбирает учебник и тему, задаёт количество и типы вопросов, после
чего приложение подбирает задания из подготовленного банка. Результат можно
проверить, заменить в нём отдельный вопрос и сохранить в DOCX.

Приложение работает с локальной GGUF-моделью и не требует отправлять учебники во
внешний сервис.

## Что я описал

- основной процесс подготовки теста в BPMN 2.0;
- границы продукта, требования и бизнес-правила;
- основные и ошибочные пользовательские сценарии;
- критерии приёмки;
- влияние изменения «заменить один вопрос, не пересоздавая весь тест».

## Документация

Вся аналитическая часть собрана в одном файле:

**[Открыть системный анализ проекта](system-analysis.md)**

Там находятся описание задачи, границы, требования, бизнес-правила, Use Cases,
критерии приёмки, анализ изменения и открытые вопросы.

Редактируемая диаграмма находится в
[`ai-history-helper-portfolio-as-is.bpmn`](ai-history-helper-portfolio-as-is.bpmn).
Рядом лежат PNG и SVG для просмотра.

## Техническое продолжение

Я отдельно набросал вариант серверной версии. Это **TO-BE**, в текущем
десктопном приложении сервера и PostgreSQL пока нет.

- [`technical-design.md`](technical-design.md) — ER-модель и две Sequence Diagram;
- [`openapi.yaml`](openapi.yaml) — черновик REST API;
- [`schema.sql`](schema.sql) — схема данных для PostgreSQL;
- [`queries.sql`](queries.sql) — примеры запросов к этой схеме.

### ER-модель

```mermaid
erDiagram
    TEXTBOOK ||--o{ QUESTION : contains
    TEXTBOOK ||--o{ GENERATED_TEST : used_for
    GENERATED_TEST ||--|{ TEST_VARIANT : contains
    TEST_VARIANT ||--|{ TEST_QUESTION : consists_of
    QUESTION ||--o{ TEST_QUESTION : selected_as
    TEST_VARIANT ||--o{ EXPORT_HISTORY : exported_to

    TEXTBOOK {
        bigint id PK
        string title
        int grade
    }
    QUESTION {
        bigint id PK
        bigint textbook_id FK
        string question_type
        string topic
        string difficulty
        text question_text
        json options_json
        text correct_answer
        string source_page
    }
    GENERATED_TEST {
        bigint id PK
        bigint textbook_id FK
        string topic
        string difficulty
        datetime created_at
    }
    TEST_VARIANT {
        bigint id PK
        bigint test_id FK
        int variant_number
    }
    TEST_QUESTION {
        bigint variant_id FK
        int position
        bigint question_id FK
        bigint replaced_from_question_id FK
    }
    EXPORT_HISTORY {
        bigint id PK
        bigint variant_id FK
        string file_name
        datetime created_at
    }
```

### REST API

| Метод | URL | Результат |
|---|---|---|
| `GET` | `/textbooks` | получить список доступных учебников |
| `GET` | `/tests` | получить историю тестов |
| `POST` | `/tests` | создать тест |
| `GET` | `/tests/{testId}` | получить созданный тест |
| `POST` | `/tests/{testId}/variants/{variantNumber}/questions/{position}/replace` | заменить вопрос варианта |
| `POST` | `/tests/{testId}/variants/{variantNumber}/exports` | создать DOCX |
| `GET` | `/exports/{exportId}/file` | скачать готовый файл |

Полный контракт с параметрами и ошибками находится в
[`openapi.yaml`](openapi.yaml).

Генерация в этом варианте API синхронная: успешный `POST /tests` сразу
возвращает готовый тест. При экспорте сначала создаётся ресурс с `downloadUrl`,
а затем DOCX скачивается отдельным запросом.

### Создание теста

```mermaid
sequenceDiagram
    actor Teacher as Преподаватель
    participant UI as Интерфейс
    participant API as REST API
    participant Selection as Подбор вопросов
    participant DB as PostgreSQL

    Teacher->>UI: Указывает тему и параметры
    UI->>API: POST /tests
    API->>API: Проверяет входные данные
    API->>Selection: Передаёт параметры теста
    Selection->>DB: Запрашивает подходящие вопросы
    DB-->>Selection: Возвращает вопросы
    Selection-->>API: Возвращает готовый вариант
    API->>DB: Сохраняет тест
    API-->>UI: 201 Created и готовый тест
    UI-->>Teacher: Показывает результат
```

### Замена вопроса

```mermaid
sequenceDiagram
    actor Teacher as Преподаватель
    participant UI as Интерфейс
    participant API as REST API
    participant Selection as Подбор вопросов
    participant DB as PostgreSQL

    Teacher->>UI: Выбирает вопрос для замены
    UI->>API: POST /tests/{id}/variants/{n}/questions/{position}/replace
    API->>DB: Получает состав варианта
    API->>Selection: Ищет вопрос того же типа без дублей
    alt Замена найдена
        Selection-->>API: Новый вопрос
        API->>DB: Обновляет позицию
        API-->>UI: 200 OK
        UI-->>Teacher: Показывает обновлённый тест
    else Замена не найдена
        Selection-->>API: Подходящих вопросов нет
        API-->>UI: 409, тест не изменён
        UI-->>Teacher: Показывает причину
    end
```

### Что есть в SQL

В [`queries.sql`](queries.sql) находятся примеры:

- выбор вопросов варианта через несколько `JOIN`;
- подсчёт вопросов по типам отдельно для каждого варианта;
- поиск заменённых и неиспользованных вопросов;
- получение последнего экспорта через `ROW_NUMBER()`.

## Что в кейсе настоящее, а что учебное

Приложение и его исходный код существуют. BPMN и документ сделаны на основе
разбора текущего поведения моего дипломного проекта. Это учебный кейс, а не
коммерческий опыт.

## Что я заметил во время анализа

- термин «генерация» может создать впечатление, что модель пишет задания с нуля,
  хотя основой служит подготовленный банк вопросов;
- замена вопроса сейчас доступна только для одного варианта;
- изменённый вопрос пока не записывается обратно в историю, поэтому после
  повторного открытия будет показана старая версия;
- понятие одинаковой сложности для разных типов заданий пока не определено;
- сервер и база данных локальному приложению сейчас не обязательны.

## Что хочу сделать дальше

- провести короткое настоящее интервью с преподавателем;
- проверить сценарии на реальном пользователе;
- уточнить правила формирования нескольких вариантов;
- уточнить, нужна ли продукту серверная версия вообще.
