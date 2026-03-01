# LLM Integration Guide for Government School Monitoring System

## Overview
This guide explains how to leverage LLM models to generate insights, predictions, and recommendations from your school monitoring data.

## Use Cases for LLMs

### 1. **Data Analysis & Insights Generation**
- Identify patterns and trends in student performance
- Detect at-risk students early
- Recommend interventions for underperforming schools
- Analyze correlation between attendance and academic performance
- Generate executive summaries for administrators

### 2. **Predictive Analytics**
- Predict student dropout risk
- Forecast future performance trends
- Identify schools likely to need intervention
- Predict resource requirements

### 3. **Natural Language Queries**
- Allow administrators to ask questions in plain English
- "Which districts have the lowest attendance rates?"
- "Show me students at risk of dropping out"
- "What factors contribute to high-performing schools?"

### 4. **Report Generation**
- Automated monthly/quarterly reports
- Customized reports for different stakeholders
- Comparative analysis reports
- Intervention recommendation reports

---

## Implementation Approaches

## Approach 1: Direct LLM API Integration (Recommended for Quick Start)

### Using OpenAI GPT-4 / Claude / Gemini

**Step 1: Export Data from Database**

```sql
-- Export comprehensive data for LLM analysis
SELECT 
    'DISTRICT' AS level,
    d.district_name AS name,
    s.state_name AS state,
    ROUND(sa.attendance_percentage, 2) AS student_attendance,
    ROUND(ep.pass_percentage, 2) AS pass_rate,
    ROUND(sp.sports_participation_rate, 2) AS sports_participation,
    ROUND(ae.activity_engagement_rate, 2) AS activity_engagement,
    ROUND(ta.teacher_attendance_percentage, 2) AS teacher_attendance,
    ROUND(i.avg_inspection_score, 2) AS inspection_score,
    ROUND(c.district_performance_index, 2) AS composite_index
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
```

**Step 2: Create Python Script to Call LLM**

```python
import openai
import pandas as pd
import mysql.connector
import json

# Configure OpenAI API
openai.api_key = 'your-api-key-here'

# Connect to Aurora Database
conn = mysql.connector.connect(
    host='your-aurora-endpoint.rds.amazonaws.com',
    user='your-username',
    password='your-password',
    database='school_monitoring'
)

# Fetch data
query = """
SELECT 
    d.district_name,
    ROUND(c.district_performance_index, 2) AS performance_index,
    ROUND(sa.attendance_percentage, 2) AS attendance,
    ROUND(ep.pass_percentage, 2) AS pass_rate
FROM district d
LEFT JOIN district_composite_kpi c ON d.district_id = c.district_id
LEFT JOIN district_student_attendance_kpi sa ON d.district_id = sa.district_id
LEFT JOIN district_exam_pass_kpi ep ON d.district_id = ep.district_id
ORDER BY performance_index DESC;
"""

df = pd.read_sql(query, conn)
data_json = df.to_json(orient='records', indent=2)

# Create prompt for LLM
prompt = f"""
You are an education data analyst. Analyze the following district performance data 
from a government school monitoring system and provide insights:

Data:
{data_json}

Please provide:
1. Top 3 performing districts and what makes them successful
2. Bottom 3 districts that need immediate attention
3. Key patterns and correlations you observe
4. Specific recommendations for improvement
5. Priority interventions for underperforming districts

Format your response as a structured report.
"""

# Call OpenAI API
response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[
        {"role": "system", "content": "You are an expert education data analyst."},
        {"role": "user", "content": prompt}
    ],
    temperature=0.7,
    max_tokens=2000
)

# Print insights
print(response.choices[0].message.content)

conn.close()
```

---

## Approach 2: AWS Bedrock Integration (Recommended for AWS Environment)

### Using Amazon Bedrock with Claude

```python
import boto3
import json
import pandas as pd
import pymysql

# Initialize Bedrock client
bedrock = boto3.client(
    service_name='bedrock-runtime',
    region_name='us-east-1'
)

# Connect to Aurora
conn = pymysql.connect(
    host='your-aurora-endpoint.rds.amazonaws.com',
    user='your-username',
    password='your-password',
    database='school_monitoring'
)

# Fetch data
query = "SELECT * FROM district_composite_kpi ORDER BY district_performance_index DESC;"
df = pd.read_sql(query, conn)

# Prepare prompt
prompt = f"""
Analyze this government school district performance data:

{df.to_string()}

Provide:
1. Performance summary
2. At-risk districts
3. Success factors
4. Actionable recommendations
"""

# Call Bedrock with Claude
body = json.dumps({
    "prompt": f"\n\nHuman: {prompt}\n\nAssistant:",
    "max_tokens_to_sample": 2000,
    "temperature": 0.7,
    "top_p": 0.9,
})

response = bedrock.invoke_model(
    modelId='anthropic.claude-v2',
    body=body
)

response_body = json.loads(response['body'].read())
print(response_body['completion'])

conn.close()
```

---

## Approach 3: RAG (Retrieval Augmented Generation) System

### Using LangChain + Vector Database

**Architecture:**
1. Store data summaries in vector database (Pinecone, Weaviate, or AWS OpenSearch)
2. Use LangChain to query and retrieve relevant data
3. Pass to LLM for analysis

```python
from langchain.embeddings import OpenAIEmbeddings
from langchain.vectorstores import Pinecone
from langchain.chains import RetrievalQA
from langchain.llms import OpenAI
import pinecone

# Initialize Pinecone
pinecone.init(api_key='your-key', environment='us-west1-gcp')
index = pinecone.Index('school-monitoring')

# Create embeddings
embeddings = OpenAIEmbeddings()

# Load data summaries into vector store
# (You would prepare summaries from your data_summary_expanded.md)
vectorstore = Pinecone.from_documents(
    documents=data_summaries,
    embedding=embeddings,
    index_name='school-monitoring'
)

# Create QA chain
qa_chain = RetrievalQA.from_chain_type(
    llm=OpenAI(temperature=0),
    chain_type="stuff",
    retriever=vectorstore.as_retriever()
)

# Ask questions
question = "Which districts have the lowest student attendance and what interventions are recommended?"
answer = qa_chain.run(question)
print(answer)
```

---

## Approach 4: Fine-tuned Model (Advanced)

### Fine-tune a model on your specific domain

**When to use:**
- You have large amounts of historical data
- Need domain-specific terminology understanding
- Want to reduce API costs for high-volume queries

**Process:**
1. Prepare training data from historical reports and analyses
2. Fine-tune GPT-3.5 or Llama 2 on your data
3. Deploy on AWS SageMaker or use OpenAI fine-tuning

```python
# Example: Prepare training data
training_data = []

# Format: {"prompt": "...", "completion": "..."}
for district in districts:
    prompt = f"Analyze performance for {district['name']}: attendance={district['attendance']}, pass_rate={district['pass_rate']}"
    completion = f"District {district['name']} shows {'strong' if district['performance'] > 75 else 'weak'} performance..."
    
    training_data.append({
        "prompt": prompt,
        "completion": completion
    })

# Save and upload to OpenAI for fine-tuning
with open('training_data.jsonl', 'w') as f:
    for item in training_data:
        f.write(json.dumps(item) + '\n')
```

---

## Approach 5: Chatbot Interface (User-Friendly)

### Build a Streamlit Dashboard with LLM Backend

```python
import streamlit as st
import openai
import pandas as pd
import pymysql

st.title("School Monitoring AI Assistant")

# Database connection
@st.cache_resource
def get_connection():
    return pymysql.connect(
        host='your-aurora-endpoint.rds.amazonaws.com',
        user='your-username',
        password='your-password',
        database='school_monitoring'
    )

conn = get_connection()

# Chat interface
user_question = st.text_input("Ask a question about school performance:")

if user_question:
    # Fetch relevant data based on question
    if "attendance" in user_question.lower():
        query = "SELECT * FROM district_student_attendance_kpi ORDER BY attendance_percentage ASC LIMIT 5;"
    elif "performance" in user_question.lower():
        query = "SELECT * FROM district_composite_kpi ORDER BY district_performance_index DESC;"
    else:
        query = "SELECT * FROM district_composite_kpi;"
    
    df = pd.read_sql(query, conn)
    
    # Create prompt with data
    prompt = f"""
    User question: {user_question}
    
    Relevant data:
    {df.to_string()}
    
    Provide a clear, actionable answer based on this data.
    """
    
    # Call LLM
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are a helpful education data analyst."},
            {"role": "user", "content": prompt}
        ]
    )
    
    # Display answer
    st.write(response.choices[0].message.content)
    
    # Show data table
    st.dataframe(df)
```

---

## Specific LLM Use Cases with Sample Prompts

### 1. At-Risk Student Identification

```python
prompt = f"""
Analyze this student data and identify students at high risk of dropping out:

{student_data}

For each at-risk student, provide:
- Risk level (High/Medium/Low)
- Key risk factors
- Recommended interventions
- Timeline for action

Format as a prioritized action list.
"""
```

### 2. School Performance Report Generation

```python
prompt = f"""
Generate a comprehensive monthly performance report for {school_name}:

Data:
- Student Attendance: {attendance}%
- Pass Rate: {pass_rate}%
- Teacher Attendance: {teacher_attendance}%
- Inspection Score: {inspection_score}/10

Include:
1. Executive Summary
2. Key Achievements
3. Areas of Concern
4. Comparative Analysis (vs district average)
5. Action Items for Next Month

Format as a professional report suitable for school board presentation.
"""
```

### 3. Resource Allocation Optimization

```python
prompt = f"""
Given this district-level data and a budget of ₹10,00,000, recommend optimal resource allocation:

Districts:
{district_data}

Consider:
- Performance gaps
- Student population
- Current infrastructure scores
- Teacher-student ratios

Provide:
1. Recommended budget allocation per district
2. Justification for each allocation
3. Expected impact on KPIs
4. Implementation timeline
"""
```

### 4. Predictive Analytics

```python
prompt = f"""
Based on historical trends and current data, predict performance for next quarter:

Current Quarter Data:
{current_data}

Previous Quarter Data:
{previous_data}

Provide:
1. Predicted KPI values for next quarter
2. Confidence levels for predictions
3. Key factors influencing predictions
4. Early warning indicators to monitor
5. Preventive actions to improve outcomes
"""
```

---

## Best Practices

### 1. Data Preparation
- Always provide context with your data
- Include the data summary document (data_summary_expanded.md)
- Format data clearly (JSON, CSV, or tables)
- Limit data size to avoid token limits (use aggregated data)

### 2. Prompt Engineering
- Be specific about what you want
- Provide examples of desired output format
- Include domain context (government schools, Indian education system)
- Ask for structured outputs (JSON, tables, bullet points)

### 3. Security & Privacy
- Never send PII (student names, addresses) to external LLMs
- Use anonymized IDs instead of names
- Consider on-premise LLM deployment for sensitive data
- Use AWS Bedrock for data residency compliance

### 4. Cost Optimization
- Cache frequently used analyses
- Use smaller models (GPT-3.5) for simple queries
- Batch similar queries together
- Implement rate limiting

### 5. Validation
- Always validate LLM outputs against actual data
- Have human experts review critical recommendations
- Track accuracy of predictions over time
- A/B test different prompts and models

---

## Sample Integration Architecture

```
┌─────────────────┐
│  AWS Aurora     │
│  (MySQL)        │
└────────┬────────┘
         │
         │ SQL Queries
         │
┌────────▼────────┐
│  Python/Lambda  │
│  Data Fetcher   │
└────────┬────────┘
         │
         │ Formatted Data
         │
┌────────▼────────┐
│  LLM Service    │
│  (GPT-4/Claude/ │
│   Bedrock)      │
└────────┬────────┘
         │
         │ Insights
         │
┌────────▼────────┐
│  Application    │
│  (Dashboard/    │
│   Reports/API)  │
└─────────────────┘
```

---

## Quick Start Checklist

- [ ] Choose LLM provider (OpenAI, AWS Bedrock, etc.)
- [ ] Set up API credentials
- [ ] Export sample data from Aurora
- [ ] Test with data_summary_expanded.md document
- [ ] Create initial prompts for your use cases
- [ ] Build Python script to connect database + LLM
- [ ] Test with real queries
- [ ] Build user interface (optional)
- [ ] Deploy to production
- [ ] Monitor and optimize

---

## Example: Complete End-to-End Script

See the next file for a complete working example!
