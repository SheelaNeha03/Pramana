-- =====================================================
-- PRAMANA - Government School Monitoring System
-- Complete Enterprise Version
-- Compatible with MariaDB 10.5+
-- =====================================================

SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================
-- ADMIN HIERARCHY
-- =====================================================

CREATE TABLE state (
    state_id INT NOT NULL AUTO_INCREMENT,
    state_name VARCHAR(150) NOT NULL UNIQUE,
    PRIMARY KEY (state_id)
) ENGINE=InnoDB;

CREATE TABLE district (
    district_id INT NOT NULL AUTO_INCREMENT,
    state_id INT NOT NULL,
    district_name VARCHAR(150) NOT NULL,
    PRIMARY KEY (district_id),
    FOREIGN KEY (state_id) REFERENCES state(state_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE block (
    block_id INT NOT NULL AUTO_INCREMENT,
    district_id INT NOT NULL,
    block_name VARCHAR(150) NOT NULL,
    PRIMARY KEY (block_id),
    FOREIGN KEY (district_id) REFERENCES district(district_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================
-- SCHOOL
-- =====================================================

CREATE TABLE school (
    school_id INT NOT NULL AUTO_INCREMENT,
    block_id INT NOT NULL,
    school_code VARCHAR(50) NOT NULL UNIQUE,
    school_name VARCHAR(255) NOT NULL,
    school_type VARCHAR(50),
    management_type VARCHAR(50),
    village_or_ward VARCHAR(150),
    established_year INT,
    principal_name VARCHAR(255),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (school_id),
    FOREIGN KEY (block_id) REFERENCES block(block_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================
-- ROLE & USERS
-- =====================================================

CREATE TABLE role (
    role_id INT NOT NULL AUTO_INCREMENT,
    role_name VARCHAR(100) NOT NULL UNIQUE,
    PRIMARY KEY (role_id)
) ENGINE=InnoDB;

CREATE TABLE app_user (
    user_id INT NOT NULL AUTO_INCREMENT,
    role_id INT NOT NULL,
    school_id INT NULL,
    block_id INT NULL,
    district_id INT NULL,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    FOREIGN KEY (role_id) REFERENCES role(role_id),
    FOREIGN KEY (school_id) REFERENCES school(school_id),
    FOREIGN KEY (block_id) REFERENCES block(block_id),
    FOREIGN KEY (district_id) REFERENCES district(district_id)
) ENGINE=InnoDB;

-- =====================================================
-- CLASS & SUBJECTS
-- =====================================================

CREATE TABLE class (
    class_id INT NOT NULL AUTO_INCREMENT,
    school_id INT NOT NULL,
    grade INT,
    section VARCHAR(10),
    academic_year VARCHAR(9) NOT NULL,
    PRIMARY KEY (class_id),
    UNIQUE (school_id, grade, section, academic_year),
    FOREIGN KEY (school_id) REFERENCES school(school_id) ON DELETE CASCADE,
    CHECK (grade BETWEEN 1 AND 12)
) ENGINE=InnoDB;

CREATE TABLE subject (
    subject_id INT NOT NULL AUTO_INCREMENT,
    subject_name VARCHAR(100) NOT NULL UNIQUE,
    PRIMARY KEY (subject_id)
) ENGINE=InnoDB;

CREATE TABLE class_subject (
    id INT NOT NULL AUTO_INCREMENT,
    class_id INT NOT NULL,
    subject_id INT NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (class_id, subject_id),
    FOREIGN KEY (class_id) REFERENCES class(class_id) ON DELETE CASCADE,
    FOREIGN KEY (subject_id) REFERENCES subject(subject_id)
) ENGINE=InnoDB;

-- =====================================================
-- STUDENTS
-- =====================================================

CREATE TABLE student (
    student_id INT NOT NULL AUTO_INCREMENT,
    school_id INT NOT NULL,
    class_id INT NOT NULL,
    admission_number VARCHAR(50) NOT NULL UNIQUE,
    student_name VARCHAR(255) NOT NULL,
    gender VARCHAR(20),
    dob DATE,
    caste_category VARCHAR(50),
    enrolment_date DATE,
    status VARCHAR(30) DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (student_id),
    FOREIGN KEY (school_id) REFERENCES school(school_id),
    FOREIGN KEY (class_id) REFERENCES class(class_id),
    CHECK (gender IN ('Male','Female','Other')),
    CHECK (status IN ('Active','Dropped','Transferred','Completed'))
) ENGINE=InnoDB;

-- =====================================================
-- TEACHERS
-- =====================================================

CREATE TABLE teacher (
    teacher_id INT NOT NULL AUTO_INCREMENT,
    school_id INT NOT NULL,
    teacher_name VARCHAR(255) NOT NULL,
    designation VARCHAR(100),
    qualification VARCHAR(100),
    subject_specialization VARCHAR(100),
    date_of_joining DATE,
    employment_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (teacher_id),
    FOREIGN KEY (school_id) REFERENCES school(school_id),
    CHECK (employment_type IN ('Permanent','Contract','Guest'))
) ENGINE=InnoDB;

CREATE TABLE class_teacher (
    id INT NOT NULL AUTO_INCREMENT,
    class_id INT NOT NULL UNIQUE,
    teacher_id INT NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (class_id) REFERENCES class(class_id),
    FOREIGN KEY (teacher_id) REFERENCES teacher(teacher_id)
) ENGINE=InnoDB;

-- =====================================================
-- ATTENDANCE
-- =====================================================

CREATE TABLE student_attendance (
    attendance_id INT NOT NULL AUTO_INCREMENT,
    student_id INT NOT NULL,
    attendance_date DATE NOT NULL,
    status VARCHAR(10),
    reason VARCHAR(255),
    PRIMARY KEY (attendance_id),
    UNIQUE (student_id, attendance_date),
    FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE,
    CHECK (status IN ('Present','Absent'))
) ENGINE=InnoDB;

CREATE TABLE teacher_attendance (
    attendance_id INT NOT NULL AUTO_INCREMENT,
    teacher_id INT NOT NULL,
    attendance_date DATE NOT NULL,
    status VARCHAR(10),
    PRIMARY KEY (attendance_id),
    UNIQUE (teacher_id, attendance_date),
    FOREIGN KEY (teacher_id) REFERENCES teacher(teacher_id) ON DELETE CASCADE,
    CHECK (status IN ('Present','Absent'))
) ENGINE=InnoDB;

-- =====================================================
-- EXAMS & INTERNAL ASSESSMENT
-- =====================================================

CREATE TABLE exam (
    exam_id INT NOT NULL AUTO_INCREMENT,
    exam_name VARCHAR(100) NOT NULL,
    exam_type VARCHAR(50),
    academic_year VARCHAR(9),
    max_marks INT,
    PRIMARY KEY (exam_id),
    CHECK (exam_type IN ('Internal','External','Board')),
    CHECK (max_marks > 0)
) ENGINE=InnoDB;

CREATE TABLE exam_result (
    result_id INT NOT NULL AUTO_INCREMENT,
    student_id INT NOT NULL,
    exam_id INT NOT NULL,
    subject_id INT NOT NULL,
    marks_obtained INT,
    grade VARCHAR(10),
    pass_status TINYINT(1),
    PRIMARY KEY (result_id),
    UNIQUE (student_id, exam_id, subject_id),
    FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE,
    FOREIGN KEY (exam_id) REFERENCES exam(exam_id),
    FOREIGN KEY (subject_id) REFERENCES subject(subject_id),
    CHECK (marks_obtained >= 0)
) ENGINE=InnoDB;

CREATE TABLE internal_assessment (
    assessment_id INT NOT NULL AUTO_INCREMENT,
    student_id INT NOT NULL,
    subject_id INT NOT NULL,
    assessment_type VARCHAR(50),
    assessment_date DATE,
    marks_obtained INT,
    max_marks INT,
    PRIMARY KEY (assessment_id),
    FOREIGN KEY (student_id) REFERENCES student(student_id),
    FOREIGN KEY (subject_id) REFERENCES subject(subject_id)
) ENGINE=InnoDB;

-- =====================================================
-- INSPECTION MODULE
-- =====================================================

CREATE TABLE inspection (
    inspection_id INT NOT NULL AUTO_INCREMENT,
    school_id INT NOT NULL,
    inspector_id INT NOT NULL,
    inspection_date DATE NOT NULL,
    overall_score DECIMAL(5,2),
    remarks TEXT,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (inspection_id),
    FOREIGN KEY (school_id) REFERENCES school(school_id),
    FOREIGN KEY (inspector_id) REFERENCES app_user(user_id)
) ENGINE=InnoDB;

CREATE TABLE inspection_checklist (
    checklist_id INT NOT NULL AUTO_INCREMENT,
    inspection_id INT NOT NULL,
    parameter_name VARCHAR(255),
    score INT,
    comments TEXT,
    PRIMARY KEY (checklist_id),
    FOREIGN KEY (inspection_id) REFERENCES inspection(inspection_id) ON DELETE CASCADE,
    CHECK (score BETWEEN 0 AND 10)
) ENGINE=InnoDB;

CREATE TABLE inspection_photo (
    photo_id INT NOT NULL AUTO_INCREMENT,
    inspection_id INT NOT NULL,
    photo_url TEXT NOT NULL,
    PRIMARY KEY (photo_id),
    FOREIGN KEY (inspection_id) REFERENCES inspection(inspection_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================
-- WELFARE SCHEMES
-- =====================================================

CREATE TABLE midday_meal_record (
    meal_id INT NOT NULL AUTO_INCREMENT,
    school_id INT NOT NULL,
    meal_date DATE NOT NULL,
    students_served INT DEFAULT 0,
    meals_prepared INT DEFAULT 0,
    remarks TEXT,
    PRIMARY KEY (meal_id),
    UNIQUE (school_id, meal_date),
    FOREIGN KEY (school_id) REFERENCES school(school_id)
) ENGINE=InnoDB;

CREATE TABLE scholarship_distribution (
    scholarship_id INT NOT NULL AUTO_INCREMENT,
    student_id INT NOT NULL,
    scheme_name VARCHAR(150),
    amount DECIMAL(10,2),
    distribution_date DATE,
    PRIMARY KEY (scholarship_id),
    FOREIGN KEY (student_id) REFERENCES student(student_id)
) ENGINE=InnoDB;

-- =====================================================
-- SPORTS & ACTIVITIES
-- =====================================================

CREATE TABLE sports_participation (
    sports_id INT NOT NULL AUTO_INCREMENT,
    student_id INT NOT NULL,
    sport_name VARCHAR(100),
    level VARCHAR(50),
    participation_date DATE,
    achievement VARCHAR(255),
    PRIMARY KEY (sports_id),
    FOREIGN KEY (student_id) REFERENCES student(student_id)
) ENGINE=InnoDB;

CREATE TABLE activity_participation (
    activity_id INT NOT NULL AUTO_INCREMENT,
    student_id INT NOT NULL,
    activity_type VARCHAR(100),
    role VARCHAR(50),
    start_date DATE,
    end_date DATE,
    PRIMARY KEY (activity_id),
    FOREIGN KEY (student_id) REFERENCES student(student_id)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;