-- Небольшой набор данных для проверки schema.sql и queries.sql.
-- Идентификаторы заданы явно, чтобы примеры запросов можно было запускать без правок.

INSERT INTO textbook (id, title, grade)
VALUES (1, 'История Древнего мира', 5);

INSERT INTO question (
    id,
    textbook_id,
    question_type,
    topic,
    difficulty,
    question_text,
    options_json,
    answer_json,
    explanation,
    source_page
)
VALUES
    (
        1,
        1,
        'test',
        'Древний Египет',
        'medium',
        'Какую роль играл Нил в жизни Древнего Египта?',
        '["Был основой земледелия", "Отделял Египет от Средиземного моря", "Служил границей с Грецией"]'::jsonb,
        '{"values": ["Был основой земледелия"]}'::jsonb,
        'Разливы Нила увлажняли почву и оставляли плодородный ил.',
        '78'
    ),
    (
        2,
        1,
        'open',
        'Древний Египет',
        'medium',
        'Почему земледелие было главным занятием жителей Египта?',
        '[]'::jsonb,
        '{"values": ["Разливы Нила делали почву плодородной"]}'::jsonb,
        'Ответ может быть сформулирован своими словами.',
        '79'
    ),
    (
        3,
        1,
        'match',
        'Древний Египет',
        'medium',
        'Соотнесите понятия и их значения.',
        '["Фараон", "Папирус", "Иероглиф"]'::jsonb,
        '{"pairs": [{"left": "Фараон", "right": "Правитель Египта"}, {"left": "Папирус", "right": "Материал для письма"}, {"left": "Иероглиф", "right": "Знак египетского письма"}]}'::jsonb,
        NULL,
        '82'
    ),
    (
        4,
        1,
        'chronology',
        'Древний Египет',
        'medium',
        'Расположите события в хронологическом порядке.',
        '["Объединение Египта", "Строительство пирамиды Хеопса", "Правление Тутмоса III"]'::jsonb,
        '{"order": ["Объединение Египта", "Строительство пирамиды Хеопса", "Правление Тутмоса III"]}'::jsonb,
        NULL,
        '84'
    ),
    (
        5,
        1,
        'test',
        'Древний Египет',
        'medium',
        'Почему разливы Нила были важны для земледелия?',
        '["Они делали почву плодородной", "Они уничтожали посевы каждый год", "Они приносили морскую соль"]'::jsonb,
        '{"values": ["Они делали почву плодородной"]}'::jsonb,
        'После разлива на полях оставался плодородный ил.',
        '81'
    ),
    (
        6,
        1,
        'test',
        'Древний Египет',
        'easy',
        'На чём писали древние египтяне?',
        '["На папирусе", "На бересте", "На шёлке"]'::jsonb,
        '{"values": ["На папирусе"]}'::jsonb,
        NULL,
        '83'
    ),
    (
        7,
        1,
        'open',
        'Древняя Греция',
        'medium',
        'Что называли полисом в Древней Греции?',
        '[]'::jsonb,
        '{"values": ["Город-государство"]}'::jsonb,
        NULL,
        '112'
    );

INSERT INTO generated_test (id, textbook_id, topic, difficulty, model_name, created_at)
VALUES
    (1, 1, 'Древний Египет', 'medium', 'local-gguf', '2026-05-21 18:40:00+00'),
    (2, 1, 'Древний Египет', 'medium', 'local-gguf', '2026-05-22 10:15:00+00');

INSERT INTO test_variant (id, test_id, variant_number)
VALUES
    (1, 1, 1),
    (2, 1, 2),
    (3, 2, 1);

INSERT INTO test_question (variant_id, position, question_id, replaced_from_question_id)
VALUES
    (1, 1, 5, 1),
    (1, 2, 2, NULL),
    (1, 3, 3, NULL),
    (1, 4, 4, NULL),
    (2, 1, 1, NULL),
    (2, 2, 2, NULL),
    (3, 1, 5, NULL);

INSERT INTO export_history (id, variant_id, file_name, storage_key, created_at)
VALUES
    (1, 1, 'test-1-variant-1.docx', 'exports/test-1/variant-1/first.docx', '2026-05-21 18:45:00+00'),
    (2, 1, 'test-1-variant-1-v2.docx', 'exports/test-1/variant-1/second.docx', '2026-05-21 18:50:00+00'),
    (3, 2, 'test-1-variant-2.docx', 'exports/test-1/variant-2/first.docx', '2026-05-21 18:48:00+00');

SELECT setval(pg_get_serial_sequence('textbook', 'id'), (SELECT MAX(id) FROM textbook));
SELECT setval(pg_get_serial_sequence('question', 'id'), (SELECT MAX(id) FROM question));
SELECT setval(pg_get_serial_sequence('generated_test', 'id'), (SELECT MAX(id) FROM generated_test));
SELECT setval(pg_get_serial_sequence('test_variant', 'id'), (SELECT MAX(id) FROM test_variant));
SELECT setval(pg_get_serial_sequence('export_history', 'id'), (SELECT MAX(id) FROM export_history));
