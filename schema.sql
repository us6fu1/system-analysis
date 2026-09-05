-- TO-BE-схема для PostgreSQL.
-- Текущая версия приложения использует локальные JSON-файлы.

CREATE TABLE textbook (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    grade INTEGER CHECK (grade BETWEEN 5 AND 11),
    UNIQUE (title, grade)
);

CREATE TABLE question (
    id BIGSERIAL PRIMARY KEY,
    textbook_id BIGINT NOT NULL REFERENCES textbook(id) ON DELETE CASCADE,
    question_type VARCHAR(20) NOT NULL
        CHECK (question_type IN ('test', 'open', 'match', 'chronology')),
    topic VARCHAR(255) NOT NULL,
    difficulty VARCHAR(10) NOT NULL
        CHECK (difficulty IN ('easy', 'medium', 'hard')),
    question_text TEXT NOT NULL,
    options_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    correct_answer TEXT,
    source_page VARCHAR(50),
    UNIQUE (textbook_id, question_text)
);

CREATE TABLE generated_test (
    id BIGSERIAL PRIMARY KEY,
    textbook_id BIGINT NOT NULL REFERENCES textbook(id),
    topic VARCHAR(255) NOT NULL,
    difficulty VARCHAR(10) NOT NULL
        CHECK (difficulty IN ('easy', 'medium', 'hard')),
    status VARCHAR(10) NOT NULL DEFAULT 'ready'
        CHECK (status IN ('ready', 'failed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE test_question (
    test_id BIGINT NOT NULL REFERENCES generated_test(id) ON DELETE CASCADE,
    variant_number INTEGER NOT NULL CHECK (variant_number > 0),
    position INTEGER NOT NULL CHECK (position > 0),
    question_id BIGINT NOT NULL REFERENCES question(id),
    replaced_from_question_id BIGINT REFERENCES question(id),
    PRIMARY KEY (test_id, variant_number, position),
    UNIQUE (test_id, variant_number, question_id)
);

CREATE TABLE export_history (
    id BIGSERIAL PRIMARY KEY,
    test_id BIGINT NOT NULL REFERENCES generated_test(id) ON DELETE CASCADE,
    variant_number INTEGER NOT NULL CHECK (variant_number > 0),
    file_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_question_filter
    ON question (textbook_id, topic, question_type, difficulty);

CREATE INDEX idx_generated_test_created_at
    ON generated_test (created_at DESC);
