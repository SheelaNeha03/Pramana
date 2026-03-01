#!/usr/bin/env python3
"""
Complete Example: LLM-Powered School Monitoring Analysis
This script demonstrates how to use LLMs to analyze school performance data
"""

import os
import json
import pandas as pd
import pymysql
from datetime import datetime

# Choose your LLM provider (uncomment one)
# Option 1: OpenAI
# import openai
# openai.api_key = os.getenv('OPENAI_API_KEY')

# Option 2: AWS Bedrock
# import boto3
# bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')

# Option 3: Anthropic Claude
# import anthropic
# client = anthropic.Anthropic(api_key=os.getenv('ANTHROPIC_API_KEY'))


class SchoolMonitoringAnalyzer:
    """Analyze school monitoring data using LLMs"""
    
    def __init__(self, db_config):
        """Initialize with database configuration"""
        self.db_config = db_config
        self.conn = None
        
    def connect_db(self):
        """Connect to Aurora MySQL database"""
        self.conn = pymysql.connect(
            host=self.db_config['host'],
            user=self.db_config['user'],
            password=self.db_config['password'],
            database=self.db_config['database'],
            cursorclass=pymysql.cursors.DictCursor
        )
        print("✓ Connected to database")
        
    def fetch_district_kpis(self):
        """Fetch district-level KPI data"""
        query = """
        SELECT 
            d.district_name,
            s.state_name,
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
        ORDER BY composite_index DESC;
        """
        
        with self.conn.cursor() as cursor:
            cursor.execute(query)
            results = cursor.fetchall()
        
        df = pd.DataFrame(results)
        print(f"✓ Fetched data for {len(df)} districts")
        return df
    
    def fetch_at_risk_students(self):
        """Fetch students at risk of dropping out"""
        query = """
        SELECT 
            s.student_name,
            s.gender,
            s.caste_category,
            sc.school_name,
            d.district_name,
            AVG(er.marks_obtained) as avg_marks,
            COUNT(CASE WHEN sa.status = 'Present' THEN 1 END) * 100.0 / 
            NULLIF(COUNT(sa.attendance_id), 0) as attendance_pct,
            COUNT(DISTINCT sp.sports_id) as sports_count,
            COUNT(DISTINCT ap.activity_id) as activity_count
        FROM student s
        JOIN school sc ON s.school_id = sc.school_id
        JOIN block b ON sc.block_id = b.block_id
        JOIN district d ON b.district_id = d.district_id
        LEFT JOIN exam_result er ON s.student_id = er.student_id
        LEFT JOIN student_attendance sa ON s.student_id = sa.student_id
        LEFT JOIN sports_participation sp ON s.student_id = sp.student_id
        LEFT JOIN activity_participation ap ON s.student_id = ap.student_id
        WHERE s.status = 'Active'
        GROUP BY s.student_id
        HAVING avg_marks < 60 OR attendance_pct < 70
        ORDER BY avg_marks ASC, attendance_pct ASC
        LIMIT 20;
        """
        
        with self.conn.cursor() as cursor:
            cursor.execute(query)
            results = cursor.fetchall()
        
        df = pd.DataFrame(results)
        print(f"✓ Identified {len(df)} at-risk students")
        return df
    
    def analyze_with_llm_openai(self, data, analysis_type):
        """Analyze data using OpenAI GPT-4"""
        import openai
        
        prompts = {
            'district_performance': f"""
You are an expert education data analyst for government schools in India.

Analyze this district performance data:

{data.to_string()}

Provide a comprehensive analysis including:

1. **Executive Summary** (2-3 sentences)
2. **Top Performers** (Top 3 districts and what makes them successful)
3. **Underperformers** (Bottom 3 districts needing immediate attention)
4. **Key Insights** (Patterns, correlations, trends)
5. **Recommendations** (Specific, actionable interventions)
6. **Priority Actions** (What to do first, with timeline)

Format your response in clear sections with bullet points.
""",
            'at_risk_students': f"""
You are an education counselor analyzing at-risk students in government schools.

Student data:

{data.to_string()}

For each student or group, provide:

1. **Risk Assessment** (High/Medium/Low risk level)
2. **Risk Factors** (What's causing the issues)
3. **Intervention Plan** (Specific actions to take)
4. **Timeline** (When to implement interventions)
5. **Success Metrics** (How to measure improvement)

Prioritize students by risk level and provide actionable guidance.
"""
        }
        
        prompt = prompts.get(analysis_type, prompts['district_performance'])
        
        response = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": "You are an expert education data analyst specializing in government school systems in India."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=2000
        )
        
        return response.choices[0].message.content
    
    def analyze_with_llm_claude(self, data, analysis_type):
        """Analyze data using Anthropic Claude"""
        import anthropic
        
        client = anthropic.Anthropic(api_key=os.getenv('ANTHROPIC_API_KEY'))
        
        prompts = {
            'district_performance': f"""
Analyze this government school district performance data from India:

{data.to_string()}

Provide:
1. Executive summary
2. Top 3 performing districts and success factors
3. Bottom 3 districts needing intervention
4. Key patterns and insights
5. Specific recommendations with priority levels
6. Implementation roadmap

Be specific and actionable.
""",
            'at_risk_students': f"""
Analyze these at-risk students from government schools:

{data.to_string()}

For each student/group:
1. Risk level (High/Medium/Low)
2. Primary risk factors
3. Recommended interventions
4. Timeline for action
5. Expected outcomes

Prioritize by urgency.
"""
        }
        
        prompt = prompts.get(analysis_type, prompts['district_performance'])
        
        message = client.messages.create(
            model="claude-3-sonnet-20240229",
            max_tokens=2000,
            messages=[
                {"role": "user", "content": prompt}
            ]
        )
        
        return message.content[0].text
    
    def analyze_with_llm_bedrock(self, data, analysis_type):
        """Analyze data using AWS Bedrock"""
        import boto3
        
        bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
        
        prompts = {
            'district_performance': f"""
Analyze this district performance data:

{data.to_string()}

Provide comprehensive analysis with insights and recommendations.
""",
            'at_risk_students': f"""
Analyze these at-risk students:

{data.to_string()}

Provide risk assessment and intervention recommendations.
"""
        }
        
        prompt = prompts.get(analysis_type, prompts['district_performance'])
        
        body = json.dumps({
            "prompt": f"\n\nHuman: {prompt}\n\nAssistant:",
            "max_tokens_to_sample": 2000,
            "temperature": 0.7,
        })
        
        response = bedrock.invoke_model(
            modelId='anthropic.claude-v2',
            body=body
        )
        
        response_body = json.loads(response['body'].read())
        return response_body['completion']
    
    def generate_report(self, analysis, report_type):
        """Generate formatted report"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        report = f"""
{'='*80}
GOVERNMENT SCHOOL MONITORING SYSTEM
{report_type.upper()} ANALYSIS REPORT
Generated: {timestamp}
{'='*80}

{analysis}

{'='*80}
End of Report
{'='*80}
"""
        return report
    
    def save_report(self, report, filename):
        """Save report to file"""
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(report)
        print(f"✓ Report saved to {filename}")
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            print("✓ Database connection closed")


def main():
    """Main execution function"""
    
    print("\n" + "="*80)
    print("SCHOOL MONITORING SYSTEM - LLM ANALYSIS")
    print("="*80 + "\n")
    
    # Database configuration
    db_config = {
        'host': 'your-aurora-endpoint.rds.amazonaws.com',  # Replace with your Aurora endpoint
        'user': 'your-username',                            # Replace with your username
        'password': 'your-password',                        # Replace with your password
        'database': 'school_monitoring'                     # Your database name
    }
    
    # Initialize analyzer
    analyzer = SchoolMonitoringAnalyzer(db_config)
    
    try:
        # Connect to database
        analyzer.connect_db()
        
        # Analysis 1: District Performance
        print("\n📊 Analyzing District Performance...")
        district_data = analyzer.fetch_district_kpis()
        
        # Choose your LLM provider (uncomment one)
        # district_analysis = analyzer.analyze_with_llm_openai(district_data, 'district_performance')
        # district_analysis = analyzer.analyze_with_llm_claude(district_data, 'district_performance')
        # district_analysis = analyzer.analyze_with_llm_bedrock(district_data, 'district_performance')
        
        # For demo purposes, show what would be sent to LLM
        print("\nData that would be sent to LLM:")
        print(district_data.head(10).to_string())
        
        # district_report = analyzer.generate_report(district_analysis, 'District Performance')
        # analyzer.save_report(district_report, f'district_analysis_{datetime.now().strftime("%Y%m%d")}.txt')
        
        # Analysis 2: At-Risk Students
        print("\n⚠️  Identifying At-Risk Students...")
        student_data = analyzer.fetch_at_risk_students()
        
        if len(student_data) > 0:
            print("\nAt-Risk Students Data:")
            print(student_data.to_string())
            
            # student_analysis = analyzer.analyze_with_llm_openai(student_data, 'at_risk_students')
            # student_report = analyzer.generate_report(student_analysis, 'At-Risk Students')
            # analyzer.save_report(student_report, f'at_risk_students_{datetime.now().strftime("%Y%m%d")}.txt')
        else:
            print("✓ No at-risk students identified")
        
        print("\n✅ Analysis complete!")
        print("\nTo enable LLM analysis:")
        print("1. Uncomment your preferred LLM provider in the code")
        print("2. Set your API key as environment variable")
        print("3. Run the script again")
        
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()
    
    finally:
        analyzer.close()


if __name__ == "__main__":
    main()
