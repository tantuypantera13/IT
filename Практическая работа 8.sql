-- Практическая работа 8
-- Анализ данных с помощью SQL-запросов (PostgreSQL)
-- Скрипт рассчитан на выполнение в базе с таблицами:
-- students, groups, disciplines, teachers, lessons.

-- 1. Список всех студентов с названиями их групп
SELECT
    s.student_id,
    s.last_name || ' ' || s.first_name || ' ' || COALESCE(s.middle_name, '') AS фио,
    g.group_name AS группа,
    g.specialty AS специальность
FROM students s
JOIN groups g ON s.group_id = g.group_id
ORDER BY g.group_name, s.last_name;

-- 2. Количество студентов в каждой группе
SELECT
    g.group_name AS группа,
    COUNT(s.student_id) AS студентов
FROM groups g
LEFT JOIN students s ON g.group_id = s.group_id
GROUP BY g.group_id, g.group_name
ORDER BY студентов DESC, группа;

-- 3. Расписание занятий с полной информацией
SELECT
    l.lesson_date AS дата,
    g.group_name AS группа,
    d.discipline_name AS дисциплина,
    t.last_name || ' ' || t.first_name AS преподаватель,
    l.lesson_type AS вид_занятия
FROM lessons l
JOIN groups g ON l.group_id = g.group_id
JOIN disciplines d ON l.discipline_id = d.discipline_id
JOIN teachers t ON l.teacher_id = t.teacher_id
ORDER BY l.lesson_date, g.group_name;

-- 4. Нагрузка преподавателей
SELECT
    t.last_name || ' ' || t.first_name AS преподаватель,
    t.department AS кафедра,
    COUNT(l.lesson_id) AS количество_занятий
FROM teachers t
LEFT JOIN lessons l ON t.teacher_id = l.teacher_id
GROUP BY t.teacher_id, t.last_name, t.first_name, t.department
ORDER BY количество_занятий DESC;

-- 5. Студенты, родившиеся после 2007 года
SELECT
    last_name || ' ' || first_name AS фио,
    birth_date AS дата_рождения
FROM students
WHERE birth_date > DATE '2007-01-01'
ORDER BY birth_date;

-- 6. Дисциплины с количеством часов больше 72
SELECT discipline_name AS дисциплина, hours AS часы
FROM disciplines
WHERE hours > 72
ORDER BY hours DESC;

-- 7. Группы, в которых больше одного студента
SELECT
    g.group_name AS группа,
    COUNT(s.student_id) AS студентов
FROM groups g
JOIN students s ON g.group_id = s.group_id
GROUP BY g.group_id, g.group_name
HAVING COUNT(s.student_id) > 1
ORDER BY студентов DESC;

-- 8. Средняя нагрузка на преподавателя
SELECT ROUND(AVG(занятий), 2) AS среднее_количество_занятий
FROM (
    SELECT teacher_id, COUNT(lesson_id) AS занятий
    FROM lessons
    GROUP BY teacher_id
) AS подзапрос;

-- 9. Список групп и специальностей без дубликатов
SELECT DISTINCT specialty AS специальность
FROM groups
ORDER BY specialty;

-- 10. Студенты и их группы с использованием подзапроса
SELECT
    last_name || ' ' || first_name AS фио,
    (SELECT group_name FROM groups WHERE group_id = s.group_id) AS группа
FROM students s
ORDER BY last_name;

-- 11. Демонстрация проверки ограничений целостности.
-- Следующие INSERT намеренно вызывают ошибки и поэтому закомментированы:
-- INSERT INTO groups (group_id, group_name, specialty, admission_year)
-- VALUES (1, 'Новая группа', 'Тест', 2026); -- дубликат первичного ключа
-- INSERT INTO students (first_name, birth_date, group_id)
-- VALUES ('Иван', DATE '2007-01-01', 1); -- last_name NOT NULL
-- INSERT INTO groups (group_name, specialty, admission_year)
-- VALUES ('П-21', 'Другая специальность', 2026); -- дубликат group_name

-- 12. Изменение структуры таблицы (выполнять отдельно при необходимости)
-- ALTER TABLE students ALTER COLUMN middle_name TYPE VARCHAR(100);
-- ALTER TABLE teachers RENAME COLUMN department TO kafedra;
-- ALTER TABLE teachers RENAME COLUMN kafedra TO department;
-- ALTER TABLE teachers ADD COLUMN temp_column VARCHAR(50);
-- ALTER TABLE teachers DROP COLUMN temp_column;
-- ALTER TABLE groups ADD CONSTRAINT chk_admission_year
--     CHECK (admission_year BETWEEN 2000 AND 2100);

-- 13. Транзакции и SAVEPOINT
BEGIN;
UPDATE students SET group_id = 2 WHERE student_id = 1;
UPDATE groups SET group_name = 'П-21 (обновленная)' WHERE group_id = 1;
COMMIT;

BEGIN;
DELETE FROM students;
-- Внутри транзакции таблица пуста:
-- SELECT COUNT(*) FROM students;
ROLLBACK;

BEGIN;
INSERT INTO groups (group_name, specialty, admission_year)
VALUES ('ВРЕМ-01', 'Временная', 2026);
SAVEPOINT sp1;
INSERT INTO groups (group_name, specialty, admission_year)
VALUES ('ВРЕМ-02', 'Временная', 2026);
ROLLBACK TO SAVEPOINT sp1;
COMMIT;

-- 14. Представление студентов и групп
CREATE OR REPLACE VIEW v_students_with_groups AS
SELECT
    s.student_id,
    s.last_name || ' ' || s.first_name AS full_name,
    s.birth_date,
    g.group_name,
    g.specialty
FROM students s
JOIN groups g ON s.group_id = g.group_id;

SELECT * FROM v_students_with_groups WHERE group_name = 'П-21';
-- DROP VIEW v_students_with_groups;

-- 15. Индексы и проверка плана запроса
CREATE INDEX IF NOT EXISTS idx_students_last_name ON students(last_name);
CREATE INDEX IF NOT EXISTS idx_lessons_date ON lessons(lesson_date);
EXPLAIN ANALYZE SELECT * FROM students WHERE last_name = 'Иванов';
-- DROP INDEX IF EXISTS idx_students_last_name;

-- 16. Таблица оценок
CREATE TABLE IF NOT EXISTS grades (
    grade_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL,
    discipline_id INT NOT NULL,
    grade INT NOT NULL CHECK (grade BETWEEN 2 AND 5),
    grade_date DATE NOT NULL,
    CONSTRAINT fk_grades_students
        FOREIGN KEY (student_id) REFERENCES students(student_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_grades_disciplines
        FOREIGN KEY (discipline_id) REFERENCES disciplines(discipline_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Пример заполнения оценок (добавляются только отсутствующие строки)
INSERT INTO grades (student_id, discipline_id, grade, grade_date)
SELECT v.student_id, v.discipline_id, v.grade, v.grade_date
FROM (VALUES
    (1, 1, 5, DATE '2026-09-15'), (1, 3, 4, DATE '2026-09-16'),
    (2, 1, 3, DATE '2026-09-15'), (2, 3, 3, DATE '2026-09-16'),
    (3, 1, 4, DATE '2026-09-17'), (3, 2, 5, DATE '2026-09-18'),
    (4, 2, 5, DATE '2026-09-18'), (4, 1, 3, DATE '2026-09-19'),
    (5, 2, 5, DATE '2026-09-20'), (5, 1, 4, DATE '2026-09-21')
) AS v(student_id, discipline_id, grade, grade_date)
WHERE EXISTS (SELECT 1 FROM students s WHERE s.student_id = v.student_id)
  AND EXISTS (SELECT 1 FROM disciplines d WHERE d.discipline_id = v.discipline_id)
  AND NOT EXISTS (
      SELECT 1 FROM grades g
      WHERE g.student_id = v.student_id
        AND g.discipline_id = v.discipline_id
        AND g.grade_date = v.grade_date
  );

-- 17. Аналитические запросы по оценкам
SELECT
    s.last_name || ' ' || s.first_name AS студент,
    ROUND(AVG(g.grade), 2) AS средний_балл
FROM grades g
JOIN students s ON g.student_id = s.student_id
GROUP BY s.student_id, s.last_name, s.first_name
ORDER BY средний_балл DESC;

SELECT
    d.discipline_name AS дисциплина,
    ROUND(AVG(g.grade), 2) AS средний_балл,
    COUNT(g.grade_id) AS количество_оценок
FROM grades g
JOIN disciplines d ON g.discipline_id = d.discipline_id
GROUP BY d.discipline_id, d.discipline_name
ORDER BY средний_балл DESC;

SELECT
    s.last_name || ' ' || s.first_name AS студент,
    d.discipline_name AS дисциплина,
    g.grade AS оценка,
    g.grade_date AS дата
FROM grades g
JOIN students s ON g.student_id = s.student_id
JOIN disciplines d ON g.discipline_id = d.discipline_id
WHERE g.grade < 4
ORDER BY g.grade, s.last_name;

-- Лучшие студенты: средний балл больше 4.5
SELECT
    s.last_name || ' ' || s.first_name AS студент,
    ROUND(AVG(g.grade), 2) AS средний_балл
FROM grades g
JOIN students s ON g.student_id = s.student_id
GROUP BY s.student_id, s.last_name, s.first_name
HAVING AVG(g.grade) > 4.5
ORDER BY средний_балл DESC;

-- 18. Аудит изменений
CREATE TABLE IF NOT EXISTS audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50),
    operation VARCHAR(10),
    record_id INT,
    old_data JSONB,
    new_data JSONB,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(50) DEFAULT CURRENT_USER
);

CREATE OR REPLACE FUNCTION audit_students_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log(table_name, operation, record_id, new_data)
        VALUES ('students', 'INSERT', NEW.student_id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log(table_name, operation, record_id, old_data, new_data)
        VALUES ('students', 'UPDATE', NEW.student_id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSE
        INSERT INTO audit_log(table_name, operation, record_id, old_data)
        VALUES ('students', 'DELETE', OLD.student_id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_students_audit ON students;
CREATE TRIGGER trg_students_audit
AFTER INSERT OR UPDATE OR DELETE ON students
FOR EACH ROW EXECUTE FUNCTION audit_students_changes();

-- Проверка аудита (тестовую запись удаляем после проверки)
INSERT INTO students (last_name, first_name, birth_date, group_id)
VALUES ('Новиков', 'Пётр', DATE '2007-05-05', 1);
UPDATE students SET first_name = 'Петр' WHERE last_name = 'Новиков';
DELETE FROM students WHERE last_name = 'Новиков';
SELECT * FROM audit_log WHERE table_name = 'students' ORDER BY changed_at;

-- Контроль диапазона оценок триггером
CREATE OR REPLACE FUNCTION check_grade_range()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.grade < 2 OR NEW.grade > 5 THEN
        RAISE EXCEPTION 'Оценка должна быть от 2 до 5, получено: %', NEW.grade;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_grade ON grades;
CREATE TRIGGER trg_check_grade
BEFORE INSERT OR UPDATE ON grades
FOR EACH ROW EXECUTE FUNCTION check_grade_range();

-- 19. Разграничение прав доступа (DCL).
-- Выполнять от имени администратора; имена ролей должны быть свободны.
-- CREATE ROLE teacher_role;
-- CREATE ROLE student_role;
-- CREATE USER teacher_ivanov WITH PASSWORD 'secure_password_1';
-- CREATE USER student_petrov WITH PASSWORD 'secure_password_2';
-- GRANT teacher_role TO teacher_ivanov;
-- GRANT student_role TO student_petrov;
-- GRANT SELECT ON students, lessons, groups, disciplines TO teacher_role;
-- CREATE OR REPLACE VIEW v_my_grades AS
-- SELECT gr.grade_id, s.student_id, d.discipline_name, gr.grade, gr.grade_date
-- FROM grades gr
-- JOIN students s ON gr.student_id = s.student_id
-- JOIN disciplines d ON gr.discipline_id = d.discipline_id;
-- GRANT SELECT ON v_my_grades TO student_role;