-- =====================================================================
-- АНАЛИЗ РАСПРЕДЕЛЕНИЯ ЗАДАЧ МЕЖДУ ИСПОЛНИТЕЛЯМИ
-- Используем FOR UPDATE SKIP LOCKED
-- =====================================================================

SET track_io_timing = on;

-- =====================================================================
-- ЭТАП 1: БАЗОВЫЙ СЦЕНАРИЙ - FOR UPDATE SKIP LOCKED
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 1: ДЕМОНСТРАЦИЯ FOR UPDATE SKIP LOCKED'
\echo '=========================================================='

-- Проверяем количество новых задач
SELECT 'Total new jobs:' as info, count(*) FROM jobs WHERE status = 'new';

-- Пример извлечения одной задачи с блокировкой
\echo 'Извлекаем задачу с FOR UPDATE SKIP LOCKED:'
BEGIN;
SELECT * FROM jobs 
WHERE status = 'new' 
ORDER BY priority DESC, created_at ASC
FOR UPDATE SKIP LOCKED 
LIMIT 1;
-- Пока транзакция открыта, другие сессии пропустят эту строку
ROLLBACK;

-- =====================================================================
-- ЭТАП 2: СИМУЛЯЦИЯ ПАРАЛЛЕЛЬНОЙ ОБРАБОТКИ (2 рабочих)
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 2: ПРОВЕРКА ОТСУТСТВИЯ КОНФЛИКТОВ'
\echo '=========================================================='

-- Сбрасываем статусы
UPDATE jobs SET status = 'new', worker_id = NULL, started_at = NULL;

-- Создаем функцию для имитации работы воркера
CREATE OR REPLACE FUNCTION process_next_job(p_worker_id INT)
RETURNS TABLE(job_id INT, job_title VARCHAR) AS $$
DECLARE
    v_locked_job RECORD;
BEGIN
    -- Извлекаем следующую доступную задачу
    SELECT j.id, j.title INTO v_locked_job
    FROM jobs j
    WHERE j.status = 'new'
    ORDER BY j.priority DESC, j.created_at ASC
    FOR UPDATE SKIP LOCKED
    LIMIT 1;
    
    IF v_locked_job.id IS NOT NULL THEN
        -- Обновляем статус задачи
        UPDATE jobs 
        SET status = 'processing', 
            worker_id = p_worker_id,
            started_at = now()
        WHERE id = v_locked_job.id;
        
        -- Логгируем начало обработки
        INSERT INTO job_log (job_id, worker_id, action)
        VALUES (v_locked_job.id, p_worker_id, 'started');
        
        -- Имитируем обработку (в реальности здесь была бы работа)
        PERFORM pg_sleep(0.01);
        
        -- Завершаем задачу
        UPDATE jobs 
        SET status = 'completed',
            completed_at = now()
        WHERE id = v_locked_job.id;
        
        -- Логгируем завершение
        INSERT INTO job_log (job_id, worker_id, action)
        VALUES (v_locked_job.id, p_worker_id, 'completed');
        
        job_id := v_locked_job.id;
        job_title := v_locked_job.title;
        RETURN NEXT;
    END IF;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

\echo 'Функция process_next_job создана'

-- =====================================================================
-- ЭТАП 3: ТЕСТИРОВАНИЕ ПАРАЛЛЕЛЬНОЙ ОБРАБОТКИ
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 3: ЗАПУСК 2-Х "ПАРАЛЛЕЛЬНЫХ" РАБОЧИХ'
\echo '=========================================================='

-- Сброс
UPDATE jobs SET status = 'new', worker_id = NULL, started_at = NULL, completed_at = NULL;
TRUNCATE job_log;

-- Симуляция работы двух воркеров (последовательно, но с проверкой)
\echo 'Worker 1 берет задачу:'
SELECT * FROM process_next_job(1);

\echo 'Worker 2 берет задачу (должна быть ДРУГАЯ):'
SELECT * FROM process_next_job(2);

\echo 'Worker 1 берет еще одну задачу:'
SELECT * FROM process_next_job(1);

-- Проверяем, что задачи разные
\echo 'Проверка распределения задач между воркерами:'
SELECT 
    worker_id,
    count(*) as tasks_processed,
    array_agg(job_id ORDER BY id) as job_ids
FROM job_log
WHERE action = 'started'
GROUP BY worker_id
ORDER BY worker_id;

-- =====================================================================
-- ЭТАП 4: СРАВНЕНИЕ С ОБЫЧНЫМ UPDATE (БЕЗ SKIP LOCKED)
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 4: СРАВНЕНИЕ С FOR UPDATE (БЕЗ SKIP LOCKED)'
\echo '=========================================================='

-- Сброс
UPDATE jobs SET status = 'new', worker_id = NULL;
TRUNCATE job_log;

-- Функция с обычным FOR UPDATE (блокирующая)
CREATE OR REPLACE FUNCTION process_next_job_blocking(p_worker_id INT)
RETURNS TABLE(job_id INT, job_title VARCHAR) AS $$
DECLARE
    v_locked_job RECORD;
BEGIN
    -- Блокирующий вариант - ждет освобождения строки
    SELECT j.id, j.title INTO v_locked_job
    FROM jobs j
    WHERE j.status = 'new'
    ORDER BY j.priority DESC, j.created_at ASC
    FOR UPDATE  -- БЕЗ SKIP LOCKED - будет ждать!
    LIMIT 1;
    
    IF v_locked_job.id IS NOT NULL THEN
        UPDATE jobs 
        SET status = 'processing', 
            worker_id = p_worker_id,
            started_at = now()
        WHERE id = v_locked_job.id;
        
        INSERT INTO job_log (job_id, worker_id, action)
        VALUES (v_locked_job.id, p_worker_id, 'started');
        
        PERFORM pg_sleep(0.01);
        
        UPDATE jobs 
        SET status = 'completed',
            completed_at = now()
        WHERE id = v_locked_job.id;
        
        INSERT INTO job_log (job_id, worker_id, action)
        VALUES (v_locked_job.id, p_worker_id, 'completed');
        
        job_id := v_locked_job.id;
        job_title := v_locked_job.title;
        RETURN NEXT;
    END IF;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

\echo 'Функция process_next_job_blocking создана'

-- =====================================================================
-- ЭТАП 5: MASS PROCESSING - ОБРАБОТКА ВСЕХ ЗАДАЧ
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 5: ОБРАБОТКА 100 ЗАДАЧ ДВУМЯ МЕТОДАМИ'
\echo '=========================================================='

-- Метод 1: SKIP LOCKED
\echo '--- МЕТОД 1: FOR UPDATE SKIP LOCKED ---'

-- Сброс
UPDATE jobs SET status = 'new', worker_id = NULL, started_at = NULL, completed_at = NULL;
TRUNCATE job_log;

-- Создаем процедуру для массовой обработки
CREATE OR REPLACE PROCEDURE mass_process_jobs_skip_locked(
    p_worker_count INT,
    p_tasks_per_worker INT
) AS $$
DECLARE
    v_worker_id INT;
    v_task_num INT;
    v_job_record RECORD;
BEGIN
    FOR v_worker_id IN 1..p_worker_count LOOP
        FOR v_task_num IN 1..p_tasks_per_worker LOOP
            -- Извлекаем и обрабатываем задачу
            SELECT j.id, j.title INTO v_job_record
            FROM jobs j
            WHERE j.status = 'new'
            ORDER BY j.priority DESC, j.created_at ASC
            FOR UPDATE SKIP LOCKED
            LIMIT 1;
            
            IF v_job_record.id IS NOT NULL THEN
                UPDATE jobs 
                SET status = 'processing', 
                    worker_id = v_worker_id,
                    started_at = now()
                WHERE id = v_job_record.id;
                
                INSERT INTO job_log (job_id, worker_id, action)
                VALUES (v_job_record.id, v_worker_id, 'started');
                
                PERFORM pg_sleep(0.001);  -- имитация работы
                
                UPDATE jobs 
                SET status = 'completed',
                    completed_at = now()
                WHERE id = v_job_record.id;
                
                INSERT INTO job_log (job_id, worker_id, action)
                VALUES (v_job_record.id, v_worker_id, 'completed');
            END IF;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

\echo 'Запускаем обработку 100 задач 2 воркерами (SKIP LOCKED)...'
\timing on
CALL mass_process_jobs_skip_locked(2, 50);
\timing off

\echo 'Результаты:'
SELECT 
    worker_id,
    count(*) as tasks_completed
FROM job_log
WHERE action = 'completed'
GROUP BY worker_id
ORDER BY worker_id;

\echo 'Всего обработано:'
SELECT count(*) as total_completed FROM jobs WHERE status = 'completed';

-- =====================================================================
-- ЭТАП 6: АНАЛИЗ БЛОКИРОВОК И ПРОИЗВОДИТЕЛЬНОСТИ
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 6: АНАЛИЗ ЭФФЕКТИВНОСТИ SKIP LOCKED'
\echo '=========================================================='

-- Проверяем отсутствие дублирования
\echo 'Проверка на дублирование (должно быть 0):'
SELECT 
    job_id,
    count(*) as process_count
FROM job_log
WHERE action = 'started'
GROUP BY job_id
HAVING count(*) > 1;

-- Статистика по задачам
\echo 'Статистика обработки:'
SELECT 
    status,
    count(*) as count,
    COALESCE(avg(EXTRACT(EPOCH FROM (completed_at - started_at))), 0) as avg_processing_time_sec
FROM jobs
GROUP BY status;

-- =====================================================================
-- ЭТАП 7: EXPLAIN ANALYZE ДЛЯ SKIP LOCKED
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 7: EXPLAIN ANALYZE - SKIP LOCKED'
\echo '=========================================================='

-- Сброс для чистого теста
UPDATE jobs SET status = 'new', worker_id = NULL;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM jobs 
WHERE status = 'new' 
ORDER BY priority DESC, created_at ASC
FOR UPDATE SKIP LOCKED 
LIMIT 1;

-- =====================================================================
-- ЭТАП 8: СРАВНЕНИЕ ПЛАНОВ ВЫПОЛНЕНИЯ
-- =====================================================================
\echo '=========================================================='
\echo 'ЭТАП 8: FOR UPDATE (без SKIP LOCKED) - для сравнения'
\echo '=========================================================='

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM jobs 
WHERE status = 'new' 
ORDER BY priority DESC, created_at ASC
FOR UPDATE 
LIMIT 1;

-- =====================================================================
-- ЭТАП 9: ИТОГОВАЯ СТАТИСТИКА
-- =====================================================================
\echo '=========================================================='
\echo 'ИТОГОВАЯ СТАТИСТИКА'
\echo '=========================================================='

SELECT 
    'Общее количество задач' as metric,
    count(*)::text as value
FROM jobs
UNION ALL
SELECT 'Выполнено задач', count(*)::text FROM jobs WHERE status = 'completed'
UNION ALL
SELECT 'Записей в логе', count(*)::text FROM job_log
UNION ALL
SELECT 'Уникальных воркеров', count(DISTINCT worker_id)::text FROM job_log;

\echo '=========================================================='
\echo 'ВЫВОДЫ:'
\echo '1. FOR UPDATE SKIP LOCKED позволяет избежать блокировок'
\echo '2. Каждая задача обрабатывается ТОЛЬКО ОДНИМ воркером'
\echo '3. Воркеры не ждут освобождения строк - высокая параллельность'
\echo '4. Идеально для очередей задач и фоновых джоб'
\echo '=========================================================='