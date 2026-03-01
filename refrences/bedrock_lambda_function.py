"""
AWS Lambda Function for School Monitoring Bedrock Integration
Deploy this to AWS Lambda to analyze KPIs with Bedrock
"""

import json
import boto3
import pymysql
import os
from datetime import datetime

# Initialize AWS clients
bedrock = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
s3 = boto3.client('s3')

# Database configuration from environment variables
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']
DB_NAME = os.environ.get('DB_NAME', 'school_monitoring')
S3_BUCKET = os.environ.get('S3_BUCKET', 'school-monitoring-reports')

def get_db_connection():
    """Create database connection to Aurora"""
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5
    )

def fetch_district_kpis():
    """Fetch district KPIs from database views"""
    conn = get_db_connection()
    
    query = """
    SELECT 
        d.district_name,
        s.state_name,
        ROUND(COALESCE(c.district_performance_index, 0), 2) AS performance_index,
        ROUND(COALESCE(sa.attendance_percentage, 0), 2) AS student_attendance,
        ROUND(COALESCE(ep.pass_percentage, 0), 2) AS pass_rate,
        ROUND(COALESCE(sp.sports_participation_rate, 0), 2) AS sports_participation,
        ROUND(COALESCE(ae.activity_engagement_rate, 0), 2) AS activity_engagement,
        ROUND(COALESCE(ta.teacher_attendance_percentage, 0), 2) AS teacher_attendance,
        ROUND(COALESCE(i.avg_inspection_score, 0), 2) AS inspection_score
    FROM district d
    JOIN state s ON d.state_id = s.state_id
    LEFT JOIN district_composite_kpi c ON d.district_id = c.district_id
    LEFT JOIN district_student_attendance_kpi sa ON d.district_id = sa.district_id
    LEFT JOIN district_exam_pass_kpi ep ON d.district_id = ep.district_id
    LEFT JOIN district_sports_participation_kpi sp ON d.district_id = sp.district_id
    LEFT JOIN district_activity_engagement_kpi ae ON d.district_id = ae.district_id
    LEFT JOIN district_teacher_attendance_kpi ta ON d.district_id = ta.district_id
    LEFT JOIN district_inspection_kpi i ON d.district_id = i.district_id
    ORDER BY c.district_performance_index DESC;
    """
    
    try:
        with conn.cursor() as cursor:
            cursor.execute(query)
            results = cursor.fetchall()
        print(f"Fetched {len(results)} districts from database")
        return results
    finally:
        conn.close()

def fetch_at_risk_students():
    """Fetch students at risk of dropping out"""
    conn = get_db_connection()
    
    query = """
    SELECT 
        s.student_name,
        s.gender,
        sc.school_name,
        d.district_name,
        ROUND(AVG(er.marks_obtained), 2) as avg_marks,
        ROUND(COUNT(CASE WHEN sa.status = 'Present' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(sa.attendance_id), 0), 2) as attendance_pct
    FROM student s
    JOIN school sc ON s.school_id = sc.school_id
    JOIN block b ON sc.block_id = b.block_id
    JOIN district d ON b.district_id = d.district_id
    LEFT JOIN exam_result er ON s.student_id = er.student_id
    LEFT JOIN student_attendance sa ON s.student_id = sa.student_id
    WHERE s.status = 'Active'
    GROUP BY s.student_id
    HAVING avg_marks < 60 OR attendance_pct < 70
    ORDER BY avg_marks ASC, attendance_pct ASC
    LIMIT 20;
    """
    
    try:
        with conn.cursor() as cursor:
            cursor.execute(query)
            results = cursor.fetchall()
        print(f"Identified {len(results)} at-risk students")
        return results
    finally:
        conn.close()

def create_bedrock_prompt(data, analysis_type='comprehensive'):
    """Create prompt for Bedrock based on analysis type"""
    
    data_json = json.dumps(data, indent=2)
    
    prompts = {
        'comprehensive': f"""
You are an expert education data analyst for government schools in India.

Analyze this district performance data:

{data_json}

Provide a comprehensive analysis including:

1. EXECUTIVE SUMMARY
   - Overall state of districts (2-3 sentences)
   - Key finding

2. TOP PERFORMERS
   - List top 3 districts
   - What makes them successful?
   - Common success patterns

3. UNDERPERFORMERS
   - List bottom 3 districts
   - What are their main issues?
   - Root causes

4. KEY INSIGHTS
   - Correlation between KPIs
   - Surprising patterns
   - Critical observations

5. RECOMMENDATIONS
   - 5 specific, actionable recommendations
   - Priority level (High/Medium/Low)
   - Expected impact
   - Timeline for implementation

Format with clear sections and bullet points.
""",
        
        'at_risk': f"""
Analyze these at-risk districts (performance index < 60):

{data_json}

For each district:
1. RISK LEVEL: High/Medium/Low
2. PRIMARY ISSUES: What's causing poor performance?
3. IMMEDIATE ACTIONS: What to do in next 30 days?
4. MEDIUM-TERM PLAN: 3-6 month improvement strategy
5. RESOURCES NEEDED: Budget, staff, infrastructure

Prioritize by urgency and feasibility.
""",
        
        'quick_summary': f"""
Provide a brief summary of district performance:

{data_json}

Include:
- Overall state (1 sentence)
- Top 3 performers
- Bottom 3 performers  
- One key recommendation

Keep it concise (under 200 words).
""",
        
        'at_risk_students': f"""
Analyze these at-risk students:

{data_json}

For each student or group:
1. RISK ASSESSMENT: High/Medium/Low risk level
2. RISK FACTORS: What's causing the issues?
3. INTERVENTION PLAN: Specific actions to take
4. TIMELINE: When to implement interventions
5. SUCCESS METRICS: How to measure improvement

Prioritize students by risk level.
""",
        
        'predictive': f"""
Based on this current performance data:

{data_json}

Provide predictive analysis:
1. TRENDS: Which districts are improving/declining?
2. PREDICTIONS: Expected performance next quarter
3. EARLY WARNINGS: Signs of potential problems
4. OPPORTUNITIES: Districts ready for breakthrough
5. PREVENTIVE ACTIONS: What to do now to improve outcomes

Use data-driven reasoning.
"""
    }
    
    return prompts.get(analysis_type, prompts['comprehensive'])

def invoke_bedrock(prompt, model_id='anthropic.claude-3-sonnet-20240229-v1:0'):
    """Call AWS Bedrock with Claude model"""
    
    # Prepare request body for Claude 3
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 2000,
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ],
        "temperature": 0.7,
        "top_p": 0.9
    })
    
    print(f"Invoking Bedrock model: {model_id}")
    
    # Invoke model
    response = bedrock.invoke_model(
        modelId=model_id,
        body=body
    )
    
    # Parse response
    response_body = json.loads(response['body'].read())
    analysis_text = response_body['content'][0]['text']
    
    print(f"Received response: {len(analysis_text)} characters")
    
    return analysis_text

def save_to_s3(analysis, analysis_type, metadata):
    """Save analysis results to S3"""
    try:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        key = f"reports/{analysis_type}/{timestamp}.json"
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'analysis_type': analysis_type,
            'metadata': metadata,
            'analysis': analysis
        }
        
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=key,
            Body=json.dumps(report, indent=2),
            ContentType='application/json'
        )
        
        s3_path = f"s3://{S3_BUCKET}/{key}"
        print(f"Saved report to {s3_path}")
        return s3_path
    except Exception as e:
        print(f"Warning: Could not save to S3: {str(e)}")
        return None

def lambda_handler(event, context):
    """
    Main Lambda handler
    
    Event parameters:
    - analysis_type: 'comprehensive', 'at_risk', 'quick_summary', 'at_risk_students', 'predictive'
    - model: 'sonnet' (default), 'haiku', or 'claude-2'
    - save_to_s3: true/false (default: true)
    """
    
    start_time = datetime.now()
    
    try:
        # Get parameters from event
        analysis_type = event.get('analysis_type', 'comprehensive')
        model_choice = event.get('model', 'sonnet')
        save_s3 = event.get('save_to_s3', True)
        
        print(f"Starting analysis: type={analysis_type}, model={model_choice}")
        
        # Map model choice to model ID
        models = {
            'sonnet': 'anthropic.claude-3-sonnet-20240229-v1:0',
            'haiku': 'anthropic.claude-3-haiku-20240307-v1:0',
            'claude-2': 'anthropic.claude-v2:1'
        }
        model_id = models.get(model_choice, models['sonnet'])
        
        # Fetch data based on analysis type
        if analysis_type == 'at_risk_students':
            data = fetch_at_risk_students()
            if not data:
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': 'No at-risk students identified',
                        'analysis': 'All students are performing well!'
                    })
                }
        else:
            data = fetch_district_kpis()
        
        # Create prompt
        prompt = create_bedrock_prompt(data, analysis_type)
        
        # Call Bedrock
        analysis = invoke_bedrock(prompt, model_id)
        
        # Calculate execution time
        execution_time = (datetime.now() - start_time).total_seconds()
        
        # Prepare metadata
        metadata = {
            'model': model_choice,
            'model_id': model_id,
            'records_analyzed': len(data),
            'execution_time_seconds': execution_time
        }
        
        # Save to S3 if requested
        s3_path = None
        if save_s3:
            s3_path = save_to_s3(analysis, analysis_type, metadata)
        
        # Return response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'timestamp': datetime.now().isoformat(),
                'analysis_type': analysis_type,
                'metadata': metadata,
                's3_path': s3_path,
                'analysis': analysis
            }, indent=2)
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'error_type': type(e).__name__
            })
        }
