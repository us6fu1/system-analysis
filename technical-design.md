# Техническое предложение

## Статус

Сейчас приложение работает локально и хранит данные в JSON. Ниже я описал
простой вариант серверной версии с REST API и PostgreSQL. Это TO-BE-модель, она
пока не реализована в коде.

## Модель данных

Я оставил только те сущности, которые нужны для основного сценария. Пользователей
и роли не добавлял, потому что в текущей версии с приложением работает один
преподаватель. Вариант теста вынесен в отдельную сущность: так вопросы и экспорт
нельзя случайно связать с несуществующим номером варианта.

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

Связующая таблица `test_question` хранит выбранный вопрос и его позицию внутри
конкретного варианта. Поле `replaced_from_question_id` заполняется после замены
и помогает понять, какой вопрос был до неё.

Генерация в этой версии предложения синхронная: `POST /tests` либо возвращает
готовый тест, либо ошибку. Поэтому поле `status` не используется. Состояния
`processing`, `ready` и `failed` понадобились бы только при переходе на
асинхронную обработку с ответом `202 Accepted`.

## Основные методы API

| Метод | URL | Для чего нужен |
|---|---|---|
| `GET` | `/textbooks` | получить доступные учебники и их идентификаторы |
| `GET` | `/tests` | получить историю с фильтрами и пагинацией |
| `POST` | `/tests` | создать тест по заданным параметрам |
| `GET` | `/tests/{testId}` | получить ранее созданный тест |
| `POST` | `/tests/{testId}/variants/{variantNumber}/questions/{position}/replace` | заменить один вопрос варианта |
| `POST` | `/tests/{testId}/variants/{variantNumber}/exports` | создать DOCX и запись экспорта |
| `GET` | `/exports/{exportId}/file` | скачать созданный DOCX |

Для замены я оставил отдельный `POST`, потому что это действие со своими
проверками, а не обычное редактирование полей вопроса. Номер варианта находится
в URL, поэтому сервер однозначно понимает, где делать замену. В текущем
десктопном приложении эта функция доступна только при открытом тесте с одним
вариантом; возможность указать вариант — часть TO-BE-контракта.

При экспорте сервер сначала создаёт ресурс экспорта и возвращает `exportId` и
`downloadUrl`. Сам файл клиент получает отдельным `GET`. Путь к локальной папке
в API не передаётся: для серверной версии он не имеет смысла.

## Создание теста

```mermaid
sequenceDiagram
    actor Teacher as Преподаватель
    participant UI as Интерфейс
    participant API as REST API
    participant Selection as Подбор вопросов
    participant DB as PostgreSQL

    Teacher->>UI: Указывает тему и параметры
    UI->>API: POST /tests
    API->>API: Проверяет обязательные поля
    API->>Selection: Передаёт параметры теста
    Selection->>DB: Запрашивает подходящие вопросы
    DB-->>Selection: Возвращает вопросы
    Selection-->>API: Возвращает готовые варианты
    API->>DB: Сохраняет тест и позиции вопросов
    DB-->>API: Возвращает id теста
    API-->>UI: 201 Created и готовый тест
    UI-->>Teacher: Показывает результат для проверки
```

Если тема пустая или для всех типов заданий указано количество `0`, API
возвращает ошибку `400` и не создаёт тест. Если вопросов не хватило,
возвращается `409`.

## Замена одного вопроса

```mermaid
sequenceDiagram
    actor Teacher as Преподаватель
    participant UI as Интерфейс
    participant API as REST API
    participant Selection as Подбор вопросов
    participant DB as PostgreSQL

    Teacher->>UI: Выбирает вопрос для замены
    UI->>API: POST /tests/{id}/variants/{n}/questions/{position}/replace
    API->>DB: Получает вопрос и остальные вопросы варианта
    DB-->>API: Текущий состав варианта
    API->>Selection: Ищет вопрос того же типа без дублей
    Selection-->>API: Кандидат или пустой результат
    alt Замена найдена
        API->>DB: Обновляет позицию вопроса
        DB-->>API: Изменение сохранено
        API-->>UI: 200 OK и новый вопрос
        UI-->>Teacher: Показывает обновлённый тест
    else Замена не найдена
        API-->>UI: 409, тест не изменён
        UI-->>Teacher: Показывает причину
    end
```

Замену лучше применять только после того, как новый вопрос найден и проверен.
Так исходный вариант не будет испорчен при ошибке.

## Экспорт и получение файла

```mermaid
sequenceDiagram
    actor Teacher as Преподаватель
    participant UI as Интерфейс
    participant API as REST API
    participant DOCX as Сервис экспорта
    participant DB as PostgreSQL

    Teacher->>UI: Выбирает состав документа
    UI->>API: POST /tests/{id}/variants/{n}/exports
    API->>DOCX: Передаёт вариант и настройки
    DOCX-->>API: Готовый файл
    API->>DB: Сохраняет запись экспорта
    API-->>UI: 201 Created, exportId и downloadUrl
    UI->>API: GET /exports/{exportId}/file
    API-->>UI: DOCX application/vnd.openxmlformats-officedocument.wordprocessingml.document
    UI-->>Teacher: Сохраняет файл
```

В запрос экспорта входят класс, ответы, пояснения и отдельный лист ответов. Это
соответствует настройкам текущего интерфейса, кроме выбора локальной папки.

## Связанные файлы

- [OpenAPI](openapi.yaml)
- [схема данных](schema.sql)
- [SQL-запросы](queries.sql)
