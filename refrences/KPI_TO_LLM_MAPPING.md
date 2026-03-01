# KPI to LLM Mapping Guide

## Why You Need Database Views

### Views are Essential Because:

1. **Pre-computed Aggregations** - Views calculate complex KPIs once, making queries fast
2. **Consistent Metrics** - Everyone uses the same calculation logic
3. **Simplified Queries** - Instead of complex JOINs, just `SELECT * FROM district_composite_kpi`
4. **Performance** - LLM calls are expensive; views make data fetching instant
5. **Data Quality** - Views ensure clean, validated data goes to LLMs

### The Flow:
```
Raw Tables → Views (KPI Calculations) → Python/API → LLM → Insights
```

**Without Views:**
- Complex queries every time
- Inconsistent calculations
- Slow performance
- Hard to maintain

**With Views:**
- Simple SELECT statements
- Consistent KPIs
- Fast queries
- Easy to update logic

---

## How to Map KPIs to LLM Models

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     DATABASE LAYER                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Raw Tables   │→ │  KPI Views   │→ │ Query Results│     │
│  │ (student,    │  │ (district_   │  │ (JSON/CSV)   │     │
│  │  school,     │  │  composite_  │  │              │     │
│  │  attendance) │  │  kpi)        │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   INTEGRATION LAYER                         │
│  ┌──────────────────────────────────────────────────┐      │
│  │  Python Script / Lambda Function / API           │      │
│  │  - Fetch data from views                         │      │
│  │  - Format for LLM (JSON/Text)                    │      │
│  │  - Add context and instructions                  │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      LLM LAYER                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Prompt     │→ │  LLM Model   │→ │   Analysis   │     │
│  │  Engineering │  │ (GPT-4/      │  │  & Insights  │     │
│  │              │  │  Claude)     │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   APPLICATION LAYER                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Dashboard   │  │   Reports    │  │   Alerts     │     │
│  │  (Streamlit) │  │   (PDF)      │  │   (Email)    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## KPI Mapping Strategy

### 1. Direct KPI Mapping (Simple)

**Use Case:** Send KPI values directly to LLM for analysis

```python
# Fetch from view
query = "SELECT * FROM district_composite_kpi ORDER BY district_performance_index DESC;"
kpi_data = pd.read_sql(query, conn)

# Map to LLM prompt
prompt = f"""
Analyze these district performance KPIs:

{kpi_data.to_json(orient='records', indent=2)}

Each district has:
- district_performance_index: Overall score (0-100)
- Components: attendance, pass_rate, sports, activities, teacher_attendance, inspection

Provide insights on top/bottom performers and recommendations.
"""
```

### 2. Contextual KPI Mapping (Better)

**Use Case:** Add business context to KPIs

```python
# Fetch KPIs
kpi_data = pd.read_sql("SELECT * FROM district_composite_kpi", conn)

# Add context
prompt = f"""
You are analyzing government school performance in India.

CONTEXT:
- Performance Index: Weighted score (0-100) where:
  * 30% = Exam pass rate
  * 20% = Student attendance
  * 15% = Sports participation
  * 15% = Activity engagement
  * 10% = Teacher attendance
  * 10% = Inspection score

- Benchmarks:
  * Excellent: >80
  * Good: 70-80
  * Average: 60-70
  * Needs Improvement: <60

DATA:
{kpi_data.to_json(orient='records', indent=2)}

ANALYSIS REQUIRED:
1. Identify districts below 60 (urgent intervention needed)
2. Find patterns in high performers
3. Recommend specific actions for low performers
"""
```

### 3. Multi-Level KPI Mapping (Advanced)

**Use Case:** Combine multiple KPI views for comprehensive analysis

```python
# Fetch multiple KPI views
district_kpis = pd.read_sql("SELECT * FROM district_composite_kpi", conn)
state_kpis = pd.read_sql("SELECT * FROM state_composite_kpi", conn)
attendance_kpis = pd.read_sql("SELECT * FROM district_student_attendance_kpi", conn)

# Create hierarchical context
prompt = f"""
GOVERNMENT SCHOOL MONITORING SYSTEM - COMPREHENSIVE ANALYSIS

STATE LEVEL PERFORMANCE:
{state_kpis.to_json(orient='records', indent=2)}

DISTRICT LEVEL PERFORMANCE:
{district_kpis.to_json(orient='records', indent=2)}

DETAILED ATTENDANCE BREAKDOWN:
{attendance_kpis.to_json(orient='records', indent=2)}

ANALYSIS TASKS:
1. Compare state-level performance
2. Identify best/worst districts within each state
3. Analyze attendance patterns and their impact on overall performance
4. Provide state-specific and district-specific recommendations
"""
```

---

## Practical Mapping Examples

### Example 1: At-Risk District Identification

```python
# Use view to get low-performing districts
query = """
SELECT 
    district_name,
    district_performance_index,
    attendance_percentage,
    pass_percentage
FROM district_composite_kpi
WHERE district_performance_index < 60
ORDER BY district_performance_index ASC;
"""

at_risk_districts = pd.read_sql(query, conn)

# Map to LLM with specific instructions
prompt = f"""
URGENT: At-Risk Districts Analysis

These districts have performance index below 60 (critical threshold):

{at_risk_districts.to_json(orient='records', indent=2)}

For each district, provide:
1. PRIMARY ISSUE: What's the main problem? (attendance, pass rate, or both?)
2. ROOT CAUSE: Why is this happening? (infrastructure, teacher shortage, etc.)
3. IMMEDIATE ACTION: What to do in next 30 days?
4. MEDIUM-TERM PLAN: 3-6 month improvement strategy
5. RESOURCES NEEDED: Budget, staff, infrastructure requirements

Prioritize by severity and feasibility.
"""
```

### Example 2: Success Pattern Analysis

```python
# Use view to get top performers
query = """
SELECT 
    d.district_name,
    d.district_performance_index,
    sa.attendance_percentage,
    ep.pass_percentage,
    sp.sports_participation_rate,
    ta.teacher_attendance_percentage,
    i.avg_inspection_score
FROM district_composite_kpi d
JOIN district_student_attendance_kpi sa USING (district_id)
JOIN district_exam_pass_kpi ep USING (district_id)
JOIN district_sports_participation_kpi sp USING (district_id)
JOIN district_teacher_attendance_kpi ta USING (district_id)
JOIN district_inspection_kpi i USING (district_id)
WHERE d.district_performance_index > 75
ORDER BY d.district_performance_index DESC;
"""

top_performers = pd.read_sql(query, conn)

# Map to LLM for pattern recognition
prompt = f"""
SUCCESS PATTERN ANALYSIS

Top-performing districts (performance index > 75):

{top_performers.to_json(orient='records', indent=2)}

ANALYSIS REQUIRED:
1. What do these districts have in common?
2. Which KPIs correlate most strongly with success?
3. Are there any surprising patterns?
4. What can other districts learn from them?
5. Create a "playbook" for replicating their success

Focus on actionable insights that can be implemented elsewhere.
"""
```

### Example 3: Comparative Analysis

```python
# Use views to compare current vs target
query = """
SELECT 
    district_name,
    district_performance_index AS current_score,
    80 AS target_score,
    (80 - district_performance_index) AS gap,
    attendance_percentage,
    pass_percentage
FROM district_composite_kpi
WHERE district_performance_index < 80
ORDER BY gap DESC;
"""

gap_analysis = pd.read_sql(query, conn)

# Map to LLM for gap closure strategy
prompt = f"""
PERFORMANCE GAP ANALYSIS

Target: All districts should achieve 80+ performance index
Current State:

{gap_analysis.to_json(orient='records', indent=2)}

For each district:
1. Calculate effort required to close gap (Low/Medium/High)
2. Identify which KPI improvements would have biggest impact
3. Estimate timeline to reach target (3/6/12 months)
4. Recommend specific interventions
5. Estimate budget required

Prioritize "quick wins" - districts closest to target with smallest interventions needed.
"""
```

---

## KPI-to-Prompt Templates

### Template 1: Performance Summary

```python
def create_performance_summary_prompt(district_kpis):
    return f"""
DISTRICT PERFORMANCE SUMMARY

Data:
{district_kpis.to_json(orient='records', indent=2)}

Generate:
1. Executive summary (3 sentences)
2. Key statistics (averages, ranges, outliers)
3. Top 3 insights
4. Bottom line recommendation

Keep it concise and actionable.
"""
```

### Template 2: Intervention Planning

```python
def create_intervention_prompt(low_performing_districts):
    return f"""
INTERVENTION PLANNING

Low-performing districts:
{low_performing_districts.to_json(orient='records', indent=2)}

For each district, create intervention plan:

DISTRICT: [name]
CURRENT SCORE: [score]
TARGET SCORE: 70 (minimum acceptable)

INTERVENTION PLAN:
- Phase 1 (0-30 days): [immediate actions]
- Phase 2 (1-3 months): [short-term improvements]
- Phase 3 (3-6 months): [sustainable changes]

RESOURCES REQUIRED:
- Budget: ₹[amount]
- Staff: [number and type]
- Infrastructure: [specific needs]

SUCCESS METRICS:
- 30-day target: [specific KPI improvements]
- 90-day target: [specific KPI improvements]
- 180-day target: [reach score of 70]

Format as actionable project plan.
"""
```

### Template 3: Predictive Analysis

```python
def create_prediction_prompt(historical_kpis, current_kpis):
    return f"""
PREDICTIVE ANALYSIS

Historical Performance (Last Quarter):
{historical_kpis.to_json(orient='records', indent=2)}

Current Performance (This Quarter):
{current_kpis.to_json(orient='records', indent=2)}

PREDICT:
1. Next quarter performance for each district
2. Which districts are improving/declining?
3. Early warning signs of problems
4. Opportunities for breakthrough improvements

PROVIDE:
- Predicted scores with confidence levels
- Trend analysis (improving/stable/declining)
- Risk factors to monitor
- Preventive actions to take now

Use data-driven reasoning.
"""
```

---

## Complete Working Example

```python
import pandas as pd
import pymysql
import openai
import os

# Configuration
openai.api_key = os.getenv('OPENAI_API_KEY')

db_config = {
    'host': 'your-aurora-endpoint.rds.amazonaws.com',
    'user': 'your-username',
    'password': 'your-password',
    'database': 'school_monitoring'
}

# Connect to database
conn = pymysql.connect(**db_config)

# Step 1: Fetch KPIs from views (fast and consistent)
district_kpis = pd.read_sql("""
    SELECT 
        district_name,
        ROUND(district_performance_index, 2) AS performance_index,
        ROUND(attendance_percentage, 2) AS attendance,
        ROUND(pass_percentage, 2) AS pass_rate
    FROM district_composite_kpi dck
    JOIN district_student_attendance_kpi dsa USING (district_id)
    JOIN district_exam_pass_kpi dep USING (district_id)
    ORDER BY performance_index DESC
""", conn)

# Step 2: Map KPIs to LLM prompt
prompt = f"""
You are an education policy advisor analyzing government school performance.

DISTRICT PERFORMANCE DATA:
{district_kpis.to_json(orient='records', indent=2)}

CONTEXT:
- Performance Index: Overall score (0-100)
- Attendance: Student attendance percentage
- Pass Rate: Exam pass percentage

PROVIDE:
1. Top 3 performing districts and why they succeed
2. Bottom 3 districts and specific problems
3. Correlation between attendance and pass rate
4. 5 actionable recommendations for improvement
5. Priority interventions for next quarter

Be specific and data-driven.
"""

# Step 3: Send to LLM
response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[
        {"role": "system", "content": "You are an expert education data analyst."},
        {"role": "user", "content": prompt}
    ],
    temperature=0.7
)

# Step 4: Get insights
insights = response.choices[0].message.content
print(insights)

# Step 5: Save report
with open('district_analysis_report.txt', 'w') as f:
    f.write(insights)

conn.close()
```

---

## Best Practices for KPI-to-LLM Mapping

### 1. Always Use Views
✅ DO: `SELECT * FROM district_composite_kpi`
❌ DON'T: Write complex JOINs every time

### 2. Add Business Context
✅ DO: Explain what KPIs mean and their thresholds
❌ DON'T: Send raw numbers without context

### 3. Structure Your Prompts
✅ DO: Use clear sections (CONTEXT, DATA, ANALYSIS REQUIRED)
❌ DON'T: Dump data and hope for the best

### 4. Be Specific About Output
✅ DO: "Provide 5 bullet points with specific actions"
❌ DON'T: "Analyze this data"

### 5. Validate LLM Output
✅ DO: Cross-check insights against actual data
❌ DON'T: Blindly trust LLM recommendations

---

## Summary

**Views are ESSENTIAL because:**
- They pre-calculate KPIs (fast queries)
- Ensure consistent metrics
- Simplify data fetching for LLMs
- Make maintenance easier

**Mapping Process:**
1. Query views to get KPIs
2. Add business context
3. Format for LLM (JSON/text)
4. Send with specific instructions
5. Validate and use insights

**The views are your data layer, LLMs are your intelligence layer. Both are needed!**
