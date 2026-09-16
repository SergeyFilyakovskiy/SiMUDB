-- ========================================
-- Генератор тестовых задач для очереди
-- ========================================

TRUNCATE job_log, jobs RESTART IDENTITY CASCADE;

-- Создаем 1000 задач с разным приоритетом
INSERT INTO jobs (title, description, status, priority)
SELECT 
    'Task ' || i,
    'Description for task ' || i || ' - ' || md5(random()::text),
    'new',
    (random() * 10)::int  -- приоритет от 0 до 10
FROM generate_series(1, 1000) AS i;

SELECT 'jobs' AS table_name, count(*) FROM jobs;