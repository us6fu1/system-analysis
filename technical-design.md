# Техническое предложение

## Статус

Сейчас приложение работает локально и хранит данные в JSON. Ниже я описал
простой вариант серверной версии с REST API и PostgreSQL. Это TO-BE-модель, она
пока не реализована в коде.

## Модель данных

Я оставил только те сущности, которые нужны для основного сценария. Пользователей
и роли не добавлял, потому что в текущей версии с приложением работает один
преподаватель.

```mermaid
erDiagram
    TEXTBOOK ||--o{ QUESTION : contains
    TEXTBOOK ||--o{ GENERATED_TEST : used_for
    GENERATED_TEST ||--|{ TEST_QUESTION : consists_of
    QUESTION ||--o{ TEST_QUESTION : selected_as
    GENERATED_TEST ||--o{ EXPORT_HISTORY : exported_to

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
        text correct_answer
    }
    GENERATED_TEST {
        bigint id PK
        bigint textbook_id FK
        string topic
        string difficulty
        string status
        datetime created_at
    }
    TEST_QUESTION {
        bigint test_id FK
        int variant_number
        int position
        bigint question_id FK
        bigint replaced_from_question_id FK
    }
    EXPORT_HISTORY {
        bigint id PK
        bigint test_id FK
        int variant_number
        string file_name
        datetime created_at
    }
```

Связующая таблица `test_question` хранит не только выбранный вопрос, но и его
позицию в варианте. Поле `replaced_from_question_id` заполняется после замены и
помогает понять, какой вопрос был до неё.

## Основные методы API

| Метод | URL | Для чего нужен |
|---|---|---|
| `POST` | `/tests` | создать тест по заданным параметрам |
| `GET` | `/tests/{testId}` | получить ранее созданный тест |
| `POST` | `/tests/{testId}/questions/{position}/replace` | заменить один вопрос |
| `POST` | `/tests/{testId}/exports` | сохранить вариант в DOCX |

Для замены я оставил отдельный `POST`, потому что это отдельное действие со
своими проверками, а не обычное редактирование всех полей вопроса. Полное
описание запросов и ответов находится в `openapi.yaml`.

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
    UI->>API: POST /tests/{id}/questions/{position}/replace
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

## Связанные файлы

- [OpenAPI](openapi.yaml)
- [схема данных](schema.sql)
- [SQL-запросы](queries.sql)
