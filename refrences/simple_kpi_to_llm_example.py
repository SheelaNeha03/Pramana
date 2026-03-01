#!/usr/bin/env python3
"""
SIMPLE EXAMPLE: How Views + LLMs Work Together

This shows the complete flow from database views to LLM insights
"""

import pandas as pd
import pymysql
import json

# ============================================================================
# STEP 1: FETCH DATA FROM VIEWS (Fast & Consistent)
# ============================================================================

def fetch_kpis_from_views():
    """
    Views make this simple! No complex JOINs needed.
    Views have already calculated all the KPIs.
    """
    
    # Database connection
    conn = pymysql.connect(
        host='your-aurora-endpoint.rds.amazonaws.com',
        user='your-username',
        password='your-password',
        database='school_monitoring'
    )
    
    # Simple query - views do all the heavy lifting!
    query = """
    SELECT 
        district_name,
        ROUND(district_performance_index, 2) AS performance_index,
        ROUND(attendance_percentage, 2) AS attendance,
        ROUND(pass_percentage, 2) AS pass_rate,
        ROUND(sports_participation_rate, 2) AS sports,
        ROUND(teacher_attendance_percentage, 2) AS teacher_attendance
    FROM district_composite_kpi dck
    JOIN district_student_attendance_kpi dsa USING (district_id)
    JOIN district_exam_pass_kpi dep USING (district_id)
    JOIN district_sports_participation_kpi dsp USING (district_id)
    JOIN district_teacher_attendance_kpi dta USING (district_id)
    ORDER BY performance_index DESC;
    """
    
    # Execute query (fast because views are pre-computed)
    df = pd.read_sql(query, conn)
    conn.close()
    
    print("✓ Fetched KPIs from views")
    print(f"  Found {len(df)} districts")
    print("\nSample data:")
    print(df.head(3).to_string())
    
    return df


# ============================================================================
# STEP 2: MAP KPIs TO LLM PROMPT (Add Context)
# ============================================================================

def create_llm_prompt(kpi_data):
    """
    Transform KPI data into a well-structured prompt for LLM
    """
    
    # Convert to JSON for LLM
    data_json = kpi_data.to_json(orient='records', indent=2)
    
    # Create structured prompt with context
    prompt = f"""
You are an education policy advisor for government schools in India.

CONTEXT:
- Performance Index: Overall district score (0-100)
  * Excellent: 80-100
  * Good: 70-79
  * Average: 60-69
  * Needs Improvement: <60

- KPI Components:
  * Attendance: Student attendance percentage
  * Pass Rate: Exam pass percentage
  * Sports: Sports participation rate
  * Teacher Attendance: Teacher attendance percentage

DISTRICT PERFORMANCE DATA:
{data_json}

ANALYSIS REQUIRED:

1. EXECUTIVE SUMMARY
   - Overall state of districts (2-3 sentences)
   - Key finding

2. TOP PERFORMERS
   - List top 3 districts
   - What makes them successful?
   - Common patterns

3. UNDERPERFORMERS
   - List bottom 3 districts
   - What are their main issues?
   - Root causes

4. KEY INSIGHTS
   - Correlation between KPIs
   - Surprising patterns
   - Critical observations

5. RECOMMENDATIONS
   - 3 specific, actionable recommendations
   - Priority level (High/Medium/Low)
   - Expected impact

Format your response clearly with sections and bullet points.
"""
    
    print("\n✓ Created LLM prompt with context")
    return prompt


# ============================================================================
# STEP 3: SEND TO LLM (Choose Your Provider)
# ============================================================================

def analyze_with_openai(prompt):
    """Send to OpenAI GPT-4"""
    import openai
    import os
    
    openai.api_key = os.getenv('OPENAI_API_KEY')
    
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are an expert education data analyst."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.7,
        max_tokens=1500
    )
    
    return response.choices[0].message.content


def analyze_with_claude(prompt):
    """Send to Anthropic Claude"""
    import anthropic
    import os
    
    client = anthropic.Anthropic(api_key=os.getenv('ANTHROPIC_API_KEY'))
    
    message = client.messages.create(
        model="claude-3-sonnet-20240229",
        max_tokens=1500,
        messages=[
            {"role": "user", "content": prompt}
        ]
    )
    
    return message.content[0].text


def analyze_with_bedrock(prompt):
    """Send to AWS Bedrock"""
    import boto3
    
    bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
    
    body = json.dumps({
        "prompt": f"\n\nHuman: {prompt}\n\nAssistant:",
        "max_tokens_to_sample": 1500,
        "temperature": 0.7,
    })
    
    response = bedrock.invoke_model(
        modelId='anthropic.claude-v2',
        body=body
    )
    
    response_body = json.loads(response['body'].read())
    return response_body['completion']


# ============================================================================
# STEP 4: DISPLAY INSIGHTS
# ============================================================================

def display_insights(insights):
    """Display the LLM analysis"""
    print("\n" + "="*80)
    print("LLM ANALYSIS RESULTS")
    print("="*80)
    print(insights)
    print("="*80)


# ============================================================================
# COMPLETE WORKFLOW
# ============================================================================

def main():
    """
    Complete workflow: Views → KPIs → LLM → Insights
    """
    
    print("\n" + "="*80)
    print("KPI TO LLM WORKFLOW DEMONSTRATION")
    print("="*80 + "\n")
    
    # Step 1: Fetch KPIs from views (fast!)
    print("STEP 1: Fetching KPIs from database views...")
    kpi_data = fetch_kpis_from_views()
    
    # Step 2: Create LLM prompt with context
    print("\nSTEP 2: Creating LLM prompt with business context...")
    prompt = create_llm_prompt(kpi_data)
    
    # Show what we're sending to LLM
    print("\n" + "-"*80)
    print("PROMPT PREVIEW (first 500 chars):")
    print("-"*80)
    print(prompt[:500] + "...")
    print("-"*80)
    
    # Step 3: Send to LLM (uncomment your provider)
    print("\nSTEP 3: Sending to LLM for analysis...")
    print("(Uncomment your preferred LLM provider in the code)")
    
    # Choose one:
    # insights = analyze_with_openai(prompt)
    # insights = analyze_with_claude(prompt)
    # insights = analyze_with_bedrock(prompt)
    
    # For demo, show what would happen
    print("\n✓ Prompt ready to send to LLM")
    print("\nTo enable LLM analysis:")
    print("1. Uncomment one of the analyze_with_* functions")
    print("2. Set your API key as environment variable:")
    print("   export OPENAI_API_KEY='your-key'")
    print("   export ANTHROPIC_API_KEY='your-key'")
    print("3. Run script again")
    
    # Step 4: Display insights (when LLM is enabled)
    # display_insights(insights)
    
    print("\n" + "="*80)
    print("WORKFLOW COMPLETE")
    print("="*80)
    
    # Show the value of views
    print("\n💡 WHY VIEWS ARE ESSENTIAL:")
    print("   - Query took <1 second (views are pre-computed)")
    print("   - No complex JOINs needed in application code")
    print("   - Consistent KPI calculations across all queries")
    print("   - Easy to maintain and update logic")
    print("   - LLM gets clean, structured data")


# ============================================================================
# BONUS: Show What Happens WITHOUT Views
# ============================================================================

def without_views_example():
    """
    This is what you'd have to do WITHOUT views (painful!)
    """
    
    complex_query = """
    -- WITHOUT VIEWS: Complex query every time!
    SELECT 
        d.district_name,
        -- Calculate attendance (complex)
        COUNT(CASE WHEN sa.status = 'Present' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(sa.attendance_id), 0) AS attendance,
        -- Calculate pass rate (complex)
        COUNT(CASE WHEN er.pass_status = 1 THEN 1 END) * 100.0 / 
        NULLIF(COUNT(er.result_id), 0) AS pass_rate,
        -- Calculate sports participation (complex)
        COUNT(DISTINCT sp.student_id) * 100.0 / 
        NULLIF(COUNT(DISTINCT st.student_id), 0) AS sports,
        -- Calculate composite index (very complex)
        (0.30 * pass_rate + 0.20 * attendance + ...) AS performance_index
    FROM district d
    JOIN block b ON d.district_id = b.district_id
    JOIN school sc ON b.block_id = sc.block_id
    JOIN student st ON sc.school_id = st.school_id
    LEFT JOIN student_attendance sa ON st.student_id = sa.student_id
    LEFT JOIN exam_result er ON st.student_id = er.student_id
    LEFT JOIN sports_participation sp ON st.student_id = sp.student_id
    -- ... many more JOINs and calculations
    GROUP BY d.district_id
    ORDER BY performance_index DESC;
    """
    
    print("\n" + "="*80)
    print("WITHOUT VIEWS (Don't do this!):")
    print("="*80)
    print(complex_query)
    print("\n❌ Problems:")
    print("   - Slow (calculates every time)")
    print("   - Error-prone (complex logic)")
    print("   - Inconsistent (different queries might calculate differently)")
    print("   - Hard to maintain")
    print("   - Difficult to debug")
    print("\n✅ WITH VIEWS:")
    print("   SELECT * FROM district_composite_kpi;")
    print("   - Fast, simple, consistent!")


if __name__ == "__main__":
    main()
    
    # Show the alternative (without views)
    print("\n")
    without_views_example()
