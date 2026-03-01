-- =====================================================
-- KPI VIEW QUERIES
-- Query the created views to see KPI metrics
-- =====================================================

-- =====================================================
-- DISTRICT LEVEL KPIs
-- =====================================================

-- 1. District Student Attendance KPI
SELECT 
    district_id,
    district_name,
    ROUND(attendance_percentage, 2) AS attendance_pct
FROM district_student_attendance_kpi
ORDER BY attendance_percentage DESC;

-- 2. District Exam Pass Rate KPI
SELECT 
    district_id,
    district_name,
    ROUND(pass_percentage, 2) AS pass_pct
FROM district_exam_pass_kpi
ORDER BY pass_percentage DESC;

-- 3. District Sports Participation KPI
SELECT 
    district_id,
    district_name,
    ROUND(sports_participation_rate, 2) AS sports_pct
FROM district_sports_participation_kpi
ORDER BY sports_participation_rate DESC;

-- 4. District Activity Engagement KPI
SELECT 
    district_id,
    district_name,
    ROUND(activity_engagement_rate, 2) AS activity_pct
FROM district_activity_engagement_kpi
ORDER BY activity_engagement_rate DESC;

-- 5. District Teacher Attendance KPI
SELECT 
    district_id,
    district_name,
    ROUND(teacher_attendance_percentage, 2) AS teacher_attendance_pct
FROM district_teacher_attendance_kpi
ORDER BY teacher_attendance_percentage DESC;

-- 6. District Inspection Score KPI
SELECT 
    district_id,
    district_name,
    ROUND(avg_inspection_score, 2) AS avg_inspection_score
FROM district_inspection_kpi
ORDER BY avg_inspection_score DESC;

-- 7. District Composite KPI (Overall Performance Index)
SELECT 
    district_id,
    district_name,
    ROUND(district_performance_index, 2) AS performance_index
FROM district_composite_kpi
ORDER BY district_performance_index DESC;

-- =====================================================
-- STATE LEVEL KPIs
-- =====================================================

-- 8. State Student Attendance KPI
SELECT 
    state_id,
    state_name,
    ROUND(attendance_percentage, 2) AS attendance_pct
FROM state_student_attendance_kpi
ORDER BY attendance_percentage DESC;

-- 9. State Exam Pass Rate KPI
SELECT 
    state_id,
    state_name,
    ROUND(pass_percentage, 2) AS pass_pct
FROM state_exam_pass_kpi
ORDER BY pass_percentage DESC;

-- 10. State Sports Participation KPI
SELECT 
    state_id,
    state_name,
    ROUND(sports_participation_rate, 2) AS sports_pct
FROM state_sports_participation_kpi
ORDER BY sports_participation_rate DESC;

-- 11. State Activity Engagement KPI
SELECT 
    state_id,
    state_name,
    ROUND(activity_engagement_rate, 2) AS activity_pct
FROM state_activity_engagement_kpi
ORDER BY activity_engagement_rate DESC;

-- 12. State Teacher Attendance KPI
SELECT 
    state_id,
    state_name,
    ROUND(teacher_attendance_percentage, 2) AS teacher_attendance_pct
FROM state_teacher_attendance_kpi
ORDER BY teacher_attendance_percentage DESC;

-- 13. State Inspection Score KPI
SELECT 
    state_id,
    state_name,
    ROUND(avg_inspection_score, 2) AS avg_inspection_score
FROM state_inspection_kpi
ORDER BY avg_inspection_score DESC;

-- 14. State Composite KPI (Overall Performance Index)
SELECT 
    state_id,
    state_name,
    ROUND(state_performance_index, 2) AS performance_index
FROM state_composite_kpi
ORDER BY state_performance_index DESC;

-- =====================================================
-- COMPREHENSIVE DISTRICT DASHBOARD
-- =====================================================

-- All District KPIs in one view
SELECT 
    d.district_id,
    d.district_name,
    ROUND(sa.attendance_percentage, 2) AS student_attendance,
    ROUND(ep.pass_percentage, 2) AS pass_rate,
    ROUND(sp.sports_participation_rate, 2) AS sports_participation,
    ROUND(ae.activity_engagement_rate, 2) AS activity_engagement,
    ROUND(ta.teacher_attendance_percentage, 2) AS teacher_attendance,
    ROUND(i.avg_inspection_score, 2) AS inspection_score,
    ROUND(c.district_performance_index, 2) AS composite_index
FROM district d
LEFT JOIN district_student_attendance_kpi sa ON d.district_id = sa.district_id
LEFT JOIN district_exam_pass_kpi ep ON d.district_id = ep.district_id
LEFT JOIN district_sports_participation_kpi sp ON d.district_id = sp.district_id
LEFT JOIN district_activity_engagement_kpi ae ON d.district_id = ae.district_id
LEFT JOIN district_teacher_attendance_kpi ta ON d.district_id = ta.district_id
LEFT JOIN district_inspection_kpi i ON d.district_id = i.district_id
LEFT JOIN district_composite_kpi c ON d.district_id = c.district_id
ORDER BY c.district_performance_index DESC;

-- =====================================================
-- COMPREHENSIVE STATE DASHBOARD
-- =====================================================

-- All State KPIs in one view
SELECT 
    s.state_id,
    s.state_name,
    ROUND(sa.attendance_percentage, 2) AS student_attendance,
    ROUND(ep.pass_percentage, 2) AS pass_rate,
    ROUND(sp.sports_participation_rate, 2) AS sports_participation,
    ROUND(ae.activity_engagement_rate, 2) AS activity_engagement,
    ROUND(ta.teacher_attendance_percentage, 2) AS teacher_attendance,
    ROUND(i.avg_inspection_score, 2) AS inspection_score,
    ROUND(c.state_performance_index, 2) AS composite_index
FROM state s
LEFT JOIN state_student_attendance_kpi sa ON s.state_id = sa.state_id
LEFT JOIN state_exam_pass_kpi ep ON s.state_id = ep.state_id
LEFT JOIN state_sports_participation_kpi sp ON s.state_id = sp.state_id
LEFT JOIN state_activity_engagement_kpi ae ON s.state_id = ae.state_id
LEFT JOIN state_teacher_attendance_kpi ta ON s.state_id = ta.state_id
LEFT JOIN state_inspection_kpi i ON s.state_id = i.state_id
LEFT JOIN state_composite_kpi c ON s.state_id = c.state_id
ORDER BY c.state_performance_index DESC;

-- =====================================================
-- TOP & BOTTOM PERFORMERS
-- =====================================================

-- Top 5 Districts by Performance
SELECT 
    district_name,
    ROUND(district_performance_index, 2) AS performance_index
FROM district_composite_kpi
ORDER BY district_performance_index DESC
LIMIT 5;

-- Bottom 5 Districts by Performance (Need Attention)
SELECT 
    district_name,
    ROUND(district_performance_index, 2) AS performance_index
FROM district_composite_kpi
ORDER BY district_performance_index ASC
LIMIT 5;

-- Districts with Low Attendance (<75%)
SELECT 
    district_name,
    ROUND(attendance_percentage, 2) AS attendance_pct
FROM district_student_attendance_kpi
WHERE attendance_percentage < 75
ORDER BY attendance_percentage ASC;

-- Districts with Low Pass Rate (<80%)
SELECT 
    district_name,
    ROUND(pass_percentage, 2) AS pass_pct
FROM district_exam_pass_kpi
WHERE pass_percentage < 80
ORDER BY pass_percentage ASC;

-- =====================================================
-- COMPARISON QUERIES
-- =====================================================

-- Compare Districts within a State (Karnataka example)
SELECT 
    d.district_name,
    ROUND(c.district_performance_index, 2) AS performance_index,
    ROUND(sa.attendance_percentage, 2) AS attendance,
    ROUND(ep.pass_percentage, 2) AS pass_rate
FROM district d
JOIN state s ON d.state_id = s.state_id
LEFT JOIN district_composite_kpi c ON d.district_id = c.district_id
LEFT JOIN district_student_attendance_kpi sa ON d.district_id = sa.district_id
LEFT JOIN district_exam_pass_kpi ep ON d.district_id = ep.district_id
WHERE s.state_name = 'Karnataka'
ORDER BY c.district_performance_index DESC;

-- State-wise Comparison
SELECT 
    state_name,
    ROUND(state_performance_index, 2) AS performance_index,
    ROUND(attendance_percentage, 2) AS attendance,
    ROUND(pass_percentage, 2) AS pass_rate,
    ROUND(sports_participation_rate, 2) AS sports_participation
FROM state_composite_kpi sc
JOIN state_student_attendance_kpi sa USING (state_id)
JOIN state_exam_pass_kpi ep USING (state_id)
JOIN state_sports_participation_kpi sp USING (state_id)
ORDER BY state_performance_index DESC;

-- =====================================================
-- TREND ANALYSIS QUERIES
-- =====================================================

-- Districts Ranked by Each KPI Component
SELECT 
    'Student Attendance' AS kpi_metric,
    district_name,
    ROUND(attendance_percentage, 2) AS score
FROM district_student_attendance_kpi
ORDER BY attendance_percentage DESC
LIMIT 3

UNION ALL

SELECT 
    'Pass Rate' AS kpi_metric,
    district_name,
    ROUND(pass_percentage, 2) AS score
FROM district_exam_pass_kpi
ORDER BY pass_percentage DESC
LIMIT 3

UNION ALL

SELECT 
    'Sports Participation' AS kpi_metric,
    district_name,
    ROUND(sports_participation_rate, 2) AS score
FROM district_sports_participation_kpi
ORDER BY sports_participation_rate DESC
LIMIT 3

UNION ALL

SELECT 
    'Teacher Attendance' AS kpi_metric,
    district_name,
    ROUND(teacher_attendance_percentage, 2) AS score
FROM district_teacher_attendance_kpi
ORDER BY teacher_attendance_percentage DESC
LIMIT 3;

-- =====================================================
-- EXPORT ALL KPI DATA (For LLM Analysis)
-- =====================================================

-- Complete District KPI Export
SELECT 
    'DISTRICT' AS level,
    d.district_id AS id,
    d.district_name AS name,
    s.state_name AS parent_name,
    ROUND(COALESCE(sa.attendance_percentage, 0), 2) AS student_attendance,
    ROUND(COALESCE(ep.pass_percentage, 0), 2) AS pass_rate,
    ROUND(COALESCE(sp.sports_participation_rate, 0), 2) AS sports_participation,
    ROUND(COALESCE(ae.activity_engagement_rate, 0), 2) AS activity_engagement,
    ROUND(COALESCE(ta.teacher_attendance_percentage, 0), 2) AS teacher_attendance,
    ROUND(COALESCE(i.avg_inspection_score, 0), 2) AS inspection_score,
    ROUND(COALESCE(c.district_performance_index, 0), 2) AS composite_index
FROM district d
JOIN state s ON d.state_id = s.state_id
LEFT JOIN district_student_attendance_kpi sa ON d.district_id = sa.district_id
LEFT JOIN district_exam_pass_kpi ep ON d.district_id = ep.district_id
LEFT JOIN district_sports_participation_kpi sp ON d.district_id = sp.district_id
LEFT JOIN district_activity_engagement_kpi ae ON d.district_id = ae.district_id
LEFT JOIN district_teacher_attendance_kpi ta ON d.district_id = ta.district_id
LEFT JOIN district_inspection_kpi i ON d.district_id = i.district_id
LEFT JOIN district_composite_kpi c ON d.district_id = c.district_id

UNION ALL

-- Complete State KPI Export
SELECT 
    'STATE' AS level,
    st.state_id AS id,
    st.state_name AS name,
    'NATIONAL' AS parent_name,
    ROUND(COALESCE(sa.attendance_percentage, 0), 2) AS student_attendance,
    ROUND(COALESCE(ep.pass_percentage, 0), 2) AS pass_rate,
    ROUND(COALESCE(sp.sports_participation_rate, 0), 2) AS sports_participation,
    ROUND(COALESCE(ae.activity_engagement_rate, 0), 2) AS activity_engagement,
    ROUND(COALESCE(ta.teacher_attendance_percentage, 0), 2) AS teacher_attendance,
    ROUND(COALESCE(i.avg_inspection_score, 0), 2) AS inspection_score,
    ROUND(COALESCE(c.state_performance_index, 0), 2) AS composite_index
FROM state st
LEFT JOIN state_student_attendance_kpi sa ON st.state_id = sa.state_id
LEFT JOIN state_exam_pass_kpi ep ON st.state_id = ep.state_id
LEFT JOIN state_sports_participation_kpi sp ON st.state_id = sp.state_id
LEFT JOIN state_activity_engagement_kpi ae ON st.state_id = ae.state_id
LEFT JOIN state_teacher_attendance_kpi ta ON st.state_id = ta.state_id
LEFT JOIN state_inspection_kpi i ON st.state_id = i.state_id
LEFT JOIN state_composite_kpi c ON st.state_id = c.state_id
ORDER BY level DESC, composite_index DESC;
