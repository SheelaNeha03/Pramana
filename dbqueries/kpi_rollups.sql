
-- =====================================================
-- KPI ROLLUPS: DISTRICT & STATE LEVEL
-- Government School Monitoring System
-- =====================================================

-- DISTRICT STUDENT ATTENDANCE KPI
CREATE OR REPLACE VIEW district_student_attendance_kpi AS
SELECT
    s.district,
    COUNT(CASE WHEN sa.status = 'Present' THEN 1 END)::FLOAT /
    COUNT(sa.attendance_id) * 100 AS attendance_percentage
FROM student_attendance sa
JOIN student st ON sa.student_id = st.student_id
JOIN school s ON st.school_id = s.school_id
GROUP BY s.district;

-- DISTRICT EXAM PASS KPI
CREATE OR REPLACE VIEW district_exam_pass_kpi AS
SELECT
    s.district,
    COUNT(CASE WHEN er.pass_status = TRUE THEN 1 END)::FLOAT /
    COUNT(er.result_id) * 100 AS pass_percentage
FROM exam_result er
JOIN student st ON er.student_id = st.student_id
JOIN school s ON st.school_id = s.school_id
GROUP BY s.district;

-- DISTRICT SPORTS PARTICIPATION KPI
CREATE OR REPLACE VIEW district_sports_participation_kpi AS
SELECT
    s.district,
    COUNT(DISTINCT sp.student_id)::FLOAT /
    COUNT(DISTINCT st.student_id) * 100 AS sports_participation_rate
FROM student st
JOIN school s ON st.school_id = s.school_id
LEFT JOIN sports_participation sp ON st.student_id = sp.student_id
GROUP BY s.district;

-- DISTRICT ACTIVITY ENGAGEMENT KPI
CREATE OR REPLACE VIEW district_activity_engagement_kpi AS
SELECT
    s.district,
    COUNT(DISTINCT ap.student_id)::FLOAT /
    COUNT(DISTINCT st.student_id) * 100 AS activity_engagement_rate
FROM student st
JOIN school s ON st.school_id = s.school_id
LEFT JOIN activity_participation ap ON st.student_id = ap.student_id
GROUP BY s.district;

-- DISTRICT INFRASTRUCTURE KPI
CREATE OR REPLACE VIEW district_infrastructure_kpi AS
SELECT
    s.district,
    COUNT(CASE WHEN sf.availability = TRUE THEN 1 END)::FLOAT /
    COUNT(sf.facility_id) * 100 AS facility_availability_rate
FROM school_facility sf
JOIN school s ON sf.school_id = s.school_id
GROUP BY s.district;

-- DISTRICT COMPOSITE KPI
CREATE OR REPLACE VIEW district_composite_kpi AS
SELECT
    a.district,
    (0.35 * e.pass_percentage +
     0.25 * a.attendance_percentage +
     0.15 * sp.sports_participation_rate +
     0.15 * ac.activity_engagement_rate +
     0.10 * i.facility_availability_rate) AS district_performance_index
FROM district_student_attendance_kpi a
JOIN district_exam_pass_kpi e ON a.district = e.district
JOIN district_sports_participation_kpi sp ON a.district = sp.district
JOIN district_activity_engagement_kpi ac ON a.district = ac.district
JOIN district_infrastructure_kpi i ON a.district = i.district;

-- STATE STUDENT ATTENDANCE KPI
CREATE OR REPLACE VIEW state_student_attendance_kpi AS
SELECT
    'STATE' AS state_name,
    COUNT(CASE WHEN status = 'Present' THEN 1 END)::FLOAT /
    COUNT(attendance_id) * 100 AS attendance_percentage
FROM student_attendance;

-- STATE EXAM PASS KPI
CREATE OR REPLACE VIEW state_exam_pass_kpi AS
SELECT
    'STATE' AS state_name,
    COUNT(CASE WHEN pass_status = TRUE THEN 1 END)::FLOAT /
    COUNT(result_id) * 100 AS pass_percentage
FROM exam_result;

-- STATE COMPOSITE KPI
CREATE OR REPLACE VIEW state_composite_kpi AS
SELECT
    'STATE' AS state_name,
    (0.35 * e.pass_percentage +
     0.25 * a.attendance_percentage +
     0.15 * sp.sports_participation_rate +
     0.15 * ac.activity_engagement_rate +
     0.10 * i.facility_availability_rate) AS state_performance_index
FROM state_student_attendance_kpi a,
     state_exam_pass_kpi e,
     (SELECT COUNT(DISTINCT student_id)::FLOAT / (SELECT COUNT(*) FROM student) * 100
      AS sports_participation_rate FROM sports_participation) sp,
     (SELECT COUNT(DISTINCT student_id)::FLOAT / (SELECT COUNT(*) FROM student) * 100
      AS activity_engagement_rate FROM activity_participation) ac,
     (SELECT COUNT(CASE WHEN availability = TRUE THEN 1 END)::FLOAT / COUNT(*) * 100
      AS facility_availability_rate FROM school_facility) i;
