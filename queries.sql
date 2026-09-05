-- Примеры запросов к TO-BE-схеме PostgreSQL.

-- 1. Получить вопросы первого варианта теста в нужном порядке.
SELECT
    tq.position,
    q.question_type,
    q.question_text,
    q.correct_answer
FROM generated_test AS gt
JOIN test_variant AS tv
    ON tv.test_id = gt.id
JOIN test_question AS tq
    ON tq.variant_id = tv.id
JOIN question AS q
    ON q.id = tq.question_id
WHERE gt.id = 1
  AND tv.variant_number = 1
ORDER BY tq.position;

-- 2. Посчитать число вопросов каждого типа отдельно для каждого варианта теста.
SELECT
    tv.variant_number,
    q.question_type,
    COUNT(*) AS question_count
FROM test_variant AS tv
JOIN test_question AS tq
    ON tq.variant_id = tv.id
JOIN question AS q
    ON q.id = tq.question_id
WHERE tv.test_id = 1
GROUP BY tv.variant_number, q.question_type
ORDER BY tv.variant_number, q.question_type;

-- 3. Показать вопросы, которые заменяли.
SELECT
    tv.test_id,
    tv.variant_number,
    tq.position,
    old_q.question_text AS old_question,
    new_q.question_text AS new_question
FROM test_variant AS tv
JOIN test_question AS tq
    ON tq.variant_id = tv.id
JOIN question AS new_q
    ON new_q.id = tq.question_id
JOIN question AS old_q
    ON old_q.id = tq.replaced_from_question_id
WHERE tq.replaced_from_question_id IS NOT NULL
ORDER BY tv.test_id, tv.variant_number, tq.position;

-- 4. Найти темы, по которым создано больше одного теста.
SELECT
    topic,
    COUNT(*) AS test_count
FROM generated_test
GROUP BY topic
HAVING COUNT(*) > 1
ORDER BY test_count DESC, topic;

-- 5. Получить последний экспорт каждого варианта.
SELECT test_id, variant_number, file_name, created_at
FROM (
    SELECT
        tv.test_id,
        tv.variant_number,
        eh.file_name,
        eh.created_at,
        eh.id,
        ROW_NUMBER() OVER (
            PARTITION BY eh.variant_id
            ORDER BY eh.created_at DESC, eh.id DESC
        ) AS row_number
    FROM export_history AS eh
    JOIN test_variant AS tv
        ON tv.id = eh.variant_id
) AS ranked_exports
WHERE row_number = 1
ORDER BY test_id, variant_number;

-- 6. Найти вопросы, которые ещё не использовались в тестах.
SELECT
    q.id,
    q.topic,
    q.question_text
FROM question AS q
WHERE NOT EXISTS (
    SELECT 1
    FROM test_question AS tq
    WHERE tq.question_id = q.id
)
ORDER BY q.topic, q.id;
