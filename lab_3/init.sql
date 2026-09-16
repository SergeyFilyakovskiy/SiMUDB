-- ========================================
-- Создание таблицы очереди задач
-- ========================================

CREATE TABLE IF NOT EXISTS jobs (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    status      VARCHAR(20) DEFAULT 'new',  -- new / processing / completed
    priority    INT DEFAULT 0,
    worker_id   INT,
    created_at  TIMESTAMP DEFAULT now(),
    started_at  TIMESTAMP,
    completed_at TIMESTAMP
);

-- Индексы для ускорения поиска задач
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_status_priority ON jobs(status, priority DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_worker_id ON jobs(worker_id);

-- Таблица для логирования обработки задач
CREATE TABLE IF NOT EXISTS job_log (
    id          SERIAL PRIMARY KEY,
    job_id      INT REFERENCES jobs(id),
    worker_id   INT NOT NULL,
    action      VARCHAR(50),  -- started / completed
    action_time TIMESTAMP DEFAULT now()
);

-- Индекс для логирования
CREATE INDEX IF NOT EXISTS idx_job_log_job_id ON job_log(job_id);

SELECT 'Tables created successfully' AS status;