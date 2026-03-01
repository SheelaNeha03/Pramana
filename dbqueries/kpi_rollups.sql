-- =====================================================
-- KPI ROLLUPS: DISTRICT & STATE LEVEL
-- Government School Monitoring System
-- Compatible with MariaDB 10.5+
-- =====================================================

-- DISTRICT STUDENT ATTENDANCE KPI
DROP VIEW IF EXISTS district_student_attendance_kpi;
CREATE VIEW district_student_attendance_kpi AS
SELECT
    d.district_id,
    d.district_name,
    COUNT(CASE WHEN sa.status = 'Present' THEN 1 END) * 100.0 /
    NULLIF(COUNT(sa.attendance_id), 0) AS attendance_percentage
FROM student_attendance sa
JOIN student st ON sa.student_id = st.student_id
JOIN school s ON st.school_id = s.school_id
JOIN block b ON s.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
GROUP BY d.district_id, d.district_name;

-- DISTRICT EXAM PASS KPI
DROP VIEW IF EXISTS district_exam_pass_kpi;
CREATE VIEW district_exam_pass_kpi AS
SELECT
    d.district_id,
    d.district_name,
    COUNT(CASE WHEN er.pass_status = 1 THEN 1 END) * 100.0 /
    NULLIF(COUNT(er.result_id), 0) AS pass_percentage
FROM exam_result er
JOIN student st ON er.student_id = st.student_id
JOIN school s ON st.school_id = s.school_id
JOIN block b ON s.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
GROUP BY d.district_id, d.district_name;

-- DISTRICT SPORTS PARTICIPATION KPI
DROP VIEW IF EXISTS district_sports_participation_kpi;
CREATE VIEW district_sports_participation_kpi AS
SELECT
    d.district_id,
    d.district_name,
    COUNT(DISTINCT sp.student_id) * 100.0 /
    NULLIF(COUNT(DISTINCT st.student_id), 0) AS sports_participation_rate
FROM student st
JOIN school s ON st.school_id = s.school_id
JOIN block b ON s.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
LEFT JOIN sports_participation sp ON st.student_id = sp.student_id
GROUP BY d.district_id, d.district_name;

-- DISTRICT ACTIVITY ENGAGEMENT KPI
DROP VIEW IF EXISTS district_activity_engagement_kpi;
CREATE VIEW district_activity_engagement_kpi AS
SELECT
    d.district_id,
    d.district_name,
    COUNT(DISTINCT ap.student_id) * 100.0 /
    NULLIF(COUNT(DISTINCT st.student_id), 0) AS activity_engagement_rate
FROM student st
JOIN school s ON st.school_id = s.school_id
JOIN block b ON s.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
LEFT JOIN activity_participation ap ON st.student_id = ap.student_id
GROUP BY d.district_id, d.district_name;

-- DISTRICT TEACHER ATTENDANCE KPI
DROP VIEW IF EXISTS district_teacher_attendance_kpi;
CREATE VIEW district_teacher_attendance_kpi AS
SELECT
    d.district_id,
    d.district_name,
    COUNT(CASE WHEN ta.status = 'Present' THEN 1 END) * 100.0 /
    NULLIF(COUNT(ta.attendance_id), 0) AS teacher_attendance_percentage
FROM teacher_attendance ta
JOIN teacher t ON ta.teacher_id = t.teacher_id
JOIN school s ON t.school_id = s.school_id
JOIN block b ON s.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
GROUP BY d.district_id, d.district_name;

-- DISTRICT INSPECTION SCORE KPI
DROP VIEW IF EXISTS district_inspection_kpi;
CREATE VIEW district_inspection_kpi AS
SELECT
    d.district_id,
    d.district_name,
    AVG(i.overall_score) AS avg_inspection_score
FROM inspection i
JOIN school s ON i.school_id = s.school_id
JOIN block b ON s.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
GROUP BY d.district_id, d.district_name;

-- DISTRICT COMPOSITE KPI
DROP VIEW IF EXISTS district_composite_kpi;
CREATE VIEW district_composite_kpi AS
SELECT
    a.district_id,
    a.district_name,
    (0.30 * COALESCE(e.pass_percentage, 0) +
     0.20 * COALESCE(a.attendance_percentage, 0) +
     0.15 * COALESCE(sp.sports_participation_rate, 0) +
     0.15 * COALESCE(ac.activity_engagement_rate, 0) +
     0.10 * COALESCE(ta.teacher_attendance_percentage, 0) +
     0.10 * COALESCE(i.avg_inspection_score * 10, 0)) AS district_performance_index
FROM district_student_attendance_kpi a
LEFT JOIN district_exam_pass_kpi e ON a.district_id = e.district_id
LEFT JOIN district_sports_participation_kpi sp ON a.district_id = sp.district_id
LEFT JOIN district_activity_engagement_kpi ac ON a.district_id = ac.district_id
LEFT JOIN district_teacher_attendance_kpi ta ON a.district_id = ta.district_id
LEFT JOIN district_inspection_kpi i ON a.district_id = i.district_id;

-- STATE STUDENT ATTENDANCE KPI
DROP VIEW IF EXISTS state_student_attendance_kpi;
CREATE VIEW state_student_attendance_kpi AS
SELECT
    st.state_id,
    st.state_name,
    COUNT(CASE WHEN sa.status = 'Present' THEN 1 END) * 100.0 /
    NULLIF(COUNT(sa.attendance_id), 0) AS attendance_percentage
FROM student_attendance sa
JOIN student s ON sa.student_id = s.student_id
JOIN school sc ON s.school_id = sc.school_id
JOIN block b ON sc.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
JOIN state st ON d.state_id = st.state_id
GROUP BY st.state_id, st.state_name;

-- STATE EXAM PASS KPI
DROP VIEW IF EXISTS state_exam_pass_kpi;
CREATE VIEW state_exam_pass_kpi AS
SELECT
    st.state_id,
    st.state_name,
    COUNT(CASE WHEN er.pass_status = 1 THEN 1 END) * 100.0 /
    NULLIF(COUNT(er.result_id), 0) AS pass_percentage
FROM exam_result er
JOIN student s ON er.student_id = s.student_id
JOIN school sc ON s.school_id = sc.school_id
JOIN block b ON sc.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
JOIN state st ON d.state_id = st.state_id
GROUP BY st.state_id, st.state_name;

-- STATE SPORTS PARTICIPATION KPI
DROP VIEW IF EXISTS state_sports_participation_kpi;
CREATE VIEW state_sports_participation_kpi AS
SELECT
    st.state_id,
    st.state_name,
    COUNT(DISTINCT sp.student_id) * 100.0 /
    NULLIF(COUNT(DISTINCT s.student_id), 0) AS sports_participation_rate
FROM student s
JOIN school sc ON s.school_id = sc.school_id
JOIN block b ON sc.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
JOIN state st ON d.state_id = st.state_id
LEFT JOIN sports_participation sp ON s.student_id = sp.student_id
GROUP BY st.state_id, st.state_name;

-- STATE ACTIVITY ENGAGEMENT KPI
DROP VIEW IF EXISTS state_activity_engagement_kpi;
CREATE VIEW state_activity_engagement_kpi AS
SELECT
    st.state_id,
    st.state_name,
    COUNT(DISTINCT ap.student_id) * 100.0 /
    NULLIF(COUNT(DISTINCT s.student_id), 0) AS activity_engagement_rate
FROM student s
JOIN school sc ON s.school_id = sc.school_id
JOIN block b ON sc.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
JOIN state st ON d.state_id = st.state_id
LEFT JOIN activity_participation ap ON s.student_id = ap.student_id
GROUP BY st.state_id, st.state_name;

-- STATE TEACHER ATTENDANCE KPI
DROP VIEW IF EXISTS state_teacher_attendance_kpi;
CREATE VIEW state_teacher_attendance_kpi AS
SELECT
    st.state_id,
    st.state_name,
    COUNT(CASE WHEN ta.status = 'Present' THEN 1 END) * 100.0 /
    NULLIF(COUNT(ta.attendance_id), 0) AS teacher_attendance_percentage
FROM teacher_attendance ta
JOIN teacher t ON ta.teacher_id = t.teacher_id
JOIN school sc ON t.school_id = sc.school_id
JOIN block b ON sc.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
JOIN state st ON d.state_id = st.state_id
GROUP BY st.state_id, st.state_name;

-- STATE INSPECTION SCORE KPI
DROP VIEW IF EXISTS state_inspection_kpi;
CREATE VIEW state_inspection_kpi AS
SELECT
    st.state_id,
    st.state_name,
    AVG(i.overall_score) AS avg_inspection_score
FROM inspection i
JOIN school sc ON i.school_id = sc.school_id
JOIN block b ON sc.block_id = b.block_id
JOIN district d ON b.district_id = d.district_id
JOIN state st ON d.state_id = st.state_id
GROUP BY st.state_id, st.state_name;

-- STATE COMPOSITE KPI
DROP VIEW IF EXISTS state_composite_kpi;
CREATE VIEW state_composite_kpi AS
SELECT
    a.state_id,
    a.state_name,
    (0.30 * COALESCE(e.pass_percentage, 0) +
     0.20 * COALESCE(a.attendance_percentage, 0) +
     0.15 * COALESCE(sp.sports_participation_rate, 0) +
     0.15 * COALESCE(ac.activity_engagement_rate, 0) +
     0.10 * COALESCE(ta.teacher_attendance_percentage, 0) +
     0.10 * COALESCE(i.avg_inspection_score * 10, 0)) AS state_performance_index
FROM state_student_attendance_kpi a
LEFT JOIN state_exam_pass_kpi e ON a.state_id = e.state_id
LEFT JOIN state_sports_participation_kpi sp ON a.state_id = sp.state_id
LEFT JOIN state_activity_engagement_kpi ac ON a.state_id = ac.state_id
LEFT JOIN state_teacher_attendance_kpi ta ON a.state_id = ta.state_id
LEFT JOIN state_inspection_kpi i ON a.state_id = i.state_id;