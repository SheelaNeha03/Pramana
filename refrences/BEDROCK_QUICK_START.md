# AWS Bedrock Integration - Quick Start

## 🚀 Deploy in 5 Minutes

### Prerequisites
- AWS Account with Bedrock access
- Aurora MySQL database with KPI views
- AWS CLI configured

### Step 1: Enable Bedrock Models (2 minutes)

1. Go to AWS Console → **Bedrock**
2. Click **Model access** → **Manage model access**
3. Select **Anthropic Claude 3 Sonnet** and **Claude 3 Haiku**
4. Click **Request model access**
5. Wait for approval (usually instant)

### Step 2: Deploy Lambda Function (3 minutes)

```bash
# Make script executable
chmod +x deploy_to_aws.sh

# Run deployment script
./deploy_to_aws.sh
```

The script will prompt you for:
- Aurora database endpoint
- Database credentials
- VPC configuration

That's it! Your integration is deployed.

---

## 📊 Test Your Integration

### Quick Test

```bash
# Test with quick summary (fast, cheap)
python test_bedrock_integration.py quick_summary haiku

# Test comprehensive analysis
python test_bedrock_integration.py comprehensive sonnet

# Run all tests
python test_bedrock_integration.py all
```

### Manual Test via AWS CLI

```bash
aws lambda invoke \
  --function-name SchoolMonitoringBedrockAnalysis \
  --payload '{"analysis_type":"quick_summary","model":"haiku"}' \
  --cli-binary-format raw-in-base64-out \
  response.json

cat response.json | jq .
```

---

## 💡 Usage Examples

### 1. Daily Summary Report

```bash
aws lambda invoke \
  --function-name SchoolMonitoringBedrockAnalysis \
  --payload '{
    "analysis_type": "quick_summary",
    "model": "haiku"
  }' \
  response.json
```

**Cost:** ~$0.002 per run
**Time:** ~5 seconds

### 2. Comprehensive Monthly Analysis

```bash
aws lambda invoke \
  --function-name SchoolMonitoringBedrockAnalysis \
  --payload '{
    "analysis_type": "comprehensive",
    "model": "sonnet"
  }' \
  response.json
```

**Cost:** ~$0.03 per run
**Time:** ~15 seconds

### 3. At-Risk District Identification

```bash
aws lambda invoke \
  --function-name SchoolMonitoringBedrockAnalysis \
  --payload '{
    "analysis_type": "at_risk",
    "model": "sonnet"
  }' \
  response.json
```

**Cost:** ~$0.02 per run
**Time:** ~10 seconds

### 4. At-Risk Student Analysis

```bash
aws lambda invoke \
  --function-name SchoolMonitoringBedrockAnalysis \
  --payload '{
    "analysis_type": "at_risk_students",
    "model": "haiku"
  }' \
  response.json
```

**Cost:** ~$0.001 per run
**Time:** ~5 seconds

---

## 🔄 Automate Reports

### Daily Report at 8 AM

```bash
# Create EventBridge rule
aws events put-rule \
  --name DailySchoolReport \
  --schedule-expression "cron(0 8 * * ? *)"

# Add Lambda as target
aws events put-targets \
  --rule DailySchoolReport \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:ACCOUNT-ID:function:SchoolMonitoringBedrockAnalysis","Input"='{"analysis_type":"quick_summary","model":"haiku"}'

# Grant permission
aws lambda add-permission \
  --function-name SchoolMonitoringBedrockAnalysis \
  --statement-id DailyReportPermission \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com
```

### Weekly Comprehensive Report (Mondays at 9 AM)

```bash
aws events put-rule \
  --name WeeklySchoolReport \
  --schedule-expression "cron(0 9 ? * MON *)"

aws events put-targets \
  --rule WeeklySchoolReport \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:ACCOUNT-ID:function:SchoolMonitoringBedrockAnalysis","Input"='{"analysis_type":"comprehensive","model":"sonnet"}'
```

---

## 📁 View Reports in S3

All reports are automatically saved to S3:

```bash
# List recent reports
aws s3 ls s3://school-monitoring-reports/reports/ --recursive

# Download a specific report
aws s3 cp s3://school-monitoring-reports/reports/comprehensive/20240315_080000.json .

# View report
cat 20240315_080000.json | jq .analysis
```

---

## 🔍 Monitor and Debug

### View Lambda Logs

```bash
# Tail logs in real-time
aws logs tail /aws/lambda/SchoolMonitoringBedrockAnalysis --follow

# View recent logs
python test_bedrock_integration.py logs
```

### Check Lambda Metrics

```bash
# Get invocation count
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=SchoolMonitoringBedrockAnalysis \
  --start-time 2024-03-01T00:00:00Z \
  --end-time 2024-03-15T23:59:59Z \
  --period 86400 \
  --statistics Sum
```

---

## 💰 Cost Estimation

### Per Analysis Costs

| Analysis Type | Model | Input Tokens | Output Tokens | Cost |
|--------------|-------|--------------|---------------|------|
| Quick Summary | Haiku | ~2,000 | ~500 | $0.001 |
| Comprehensive | Sonnet | ~2,500 | ~1,500 | $0.03 |
| At-Risk | Sonnet | ~2,000 | ~1,000 | $0.02 |
| At-Risk Students | Haiku | ~1,500 | ~800 | $0.001 |

### Monthly Cost Examples

**Scenario 1: Daily Quick Summaries**
- 30 runs/month × $0.001 = **$0.03/month**

**Scenario 2: Daily Quick + Weekly Comprehensive**
- 30 quick × $0.001 = $0.03
- 4 comprehensive × $0.03 = $0.12
- **Total: $0.15/month**

**Scenario 3: Full Automation**
- Daily quick: $0.03
- Weekly comprehensive: $0.12
- Weekly at-risk: 4 × $0.02 = $0.08
- **Total: $0.23/month**

**Very affordable!** 🎉

---

## 🎯 Analysis Types Explained

### 1. Quick Summary
- **Use:** Daily check-ins, quick status updates
- **Output:** Brief overview, top/bottom performers, one recommendation
- **Time:** ~5 seconds
- **Model:** Haiku (fast & cheap)

### 2. Comprehensive
- **Use:** Monthly reports, strategic planning, board presentations
- **Output:** Detailed analysis, insights, 5+ recommendations
- **Time:** ~15 seconds
- **Model:** Sonnet (high quality)

### 3. At-Risk
- **Use:** Identify districts needing intervention
- **Output:** Risk assessment, action plans, resource requirements
- **Time:** ~10 seconds
- **Model:** Sonnet (detailed analysis needed)

### 4. At-Risk Students
- **Use:** Student-level intervention planning
- **Output:** Individual risk levels, intervention plans
- **Time:** ~5 seconds
- **Model:** Haiku (sufficient for student data)

### 5. Predictive
- **Use:** Forecast future performance, early warnings
- **Output:** Trends, predictions, preventive actions
- **Time:** ~12 seconds
- **Model:** Sonnet (complex reasoning)

---

## 🔧 Troubleshooting

### Issue: "AccessDeniedException" from Bedrock
**Solution:** Enable model access in Bedrock console

### Issue: Lambda timeout
**Solution:** Increase timeout to 60-120 seconds
```bash
aws lambda update-function-configuration \
  --function-name SchoolMonitoringBedrockAnalysis \
  --timeout 120
```

### Issue: Database connection fails
**Solution:** Check VPC configuration and security groups
```bash
# Update VPC config
aws lambda update-function-configuration \
  --function-name SchoolMonitoringBedrockAnalysis \
  --vpc-config SubnetIds=subnet-xxx,SecurityGroupIds=sg-xxx
```

### Issue: No data returned
**Solution:** Verify KPI views exist in database
```sql
SHOW TABLES LIKE '%kpi%';
SELECT * FROM district_composite_kpi LIMIT 5;
```

---

## 📚 Files Reference

- **AWS_BEDROCK_INTEGRATION.md** - Complete detailed guide
- **bedrock_lambda_function.py** - Lambda function code
- **deploy_to_aws.sh** - Automated deployment script
- **test_bedrock_integration.py** - Testing script
- **BEDROCK_QUICK_START.md** - This file

---

## ✅ Next Steps

1. ✅ Deploy Lambda function
2. ✅ Test with quick summary
3. ✅ Set up daily automated report
4. ✅ Review first week of insights
5. ✅ Add email notifications (SNS)
6. ✅ Create dashboard to display insights
7. ✅ Scale to more analysis types

---

## 🎓 Best Practices

1. **Start with Haiku** for testing (cheaper)
2. **Use Sonnet** for important reports
3. **Cache results** for repeated queries
4. **Monitor costs** via AWS Cost Explorer
5. **Review insights** before taking action
6. **Iterate prompts** to improve quality
7. **Save reports to S3** for audit trail

---

## 🆘 Support

**View logs:**
```bash
aws logs tail /aws/lambda/SchoolMonitoringBedrockAnalysis --follow
```

**Test connection:**
```bash
python test_bedrock_integration.py quick_summary haiku
```

**Check Bedrock access:**
```bash
aws bedrock list-foundation-models --region us-east-1
```

---

**You're all set! Your KPIs are now AI-powered with AWS Bedrock.** 🚀
