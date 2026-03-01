#!/usr/bin/env python3
"""
Test script for AWS Bedrock integration
Run this locally to test your Lambda function
"""

import boto3
import json
import time
from datetime import datetime

# Configuration
FUNCTION_NAME = 'SchoolMonitoringBedrockAnalysis'
REGION = 'us-east-1'

# Initialize Lambda client
lambda_client = boto3.client('lambda', region_name=REGION)

def invoke_lambda(analysis_type, model='sonnet'):
    """Invoke Lambda function and return results"""
    
    print(f"\n{'='*80}")
    print(f"Testing: {analysis_type} with {model}")
    print(f"{'='*80}\n")
    
    payload = {
        'analysis_type': analysis_type,
        'model': model,
        'save_to_s3': True
    }
    
    print(f"Invoking Lambda function: {FUNCTION_NAME}")
    print(f"Payload: {json.dumps(payload, indent=2)}\n")
    
    start_time = time.time()
    
    try:
        response = lambda_client.invoke(
            FunctionName=FUNCTION_NAME,
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )
        
        execution_time = time.time() - start_time
        
        # Parse response
        response_payload = json.loads(response['Payload'].read())
        
        if response['StatusCode'] == 200:
            body = json.loads(response_payload['body'])
            
            print(f"✓ Success! (Execution time: {execution_time:.2f}s)")
            print(f"\nMetadata:")
            print(f"  - Timestamp: {body['timestamp']}")
            print(f"  - Analysis Type: {body['analysis_type']}")
            print(f"  - Records Analyzed: {body['metadata']['records_analyzed']}")
            print(f"  - Model: {body['metadata']['model']}")
            print(f"  - S3 Path: {body.get('s3_path', 'Not saved')}")
            
            print(f"\n{'='*80}")
            print("ANALYSIS RESULTS:")
            print(f"{'='*80}\n")
            print(body['analysis'])
            print(f"\n{'='*80}\n")
            
            return body
        else:
            print(f"✗ Error: Status code {response['StatusCode']}")
            print(response_payload)
            return None
            
    except Exception as e:
        print(f"✗ Error invoking Lambda: {str(e)}")
        import traceback
        traceback.print_exc()
        return None

def test_all_analysis_types():
    """Test all analysis types"""
    
    print("\n" + "="*80)
    print("AWS BEDROCK INTEGRATION TEST SUITE")
    print("="*80)
    
    tests = [
        ('quick_summary', 'haiku'),
        ('comprehensive', 'sonnet'),
        ('at_risk', 'sonnet'),
        ('at_risk_students', 'haiku'),
    ]
    
    results = []
    
    for analysis_type, model in tests:
        result = invoke_lambda(analysis_type, model)
        results.append({
            'analysis_type': analysis_type,
            'model': model,
            'success': result is not None
        })
        time.sleep(2)  # Brief pause between tests
    
    # Summary
    print("\n" + "="*80)
    print("TEST SUMMARY")
    print("="*80 + "\n")
    
    for result in results:
        status = "✓ PASS" if result['success'] else "✗ FAIL"
        print(f"{status} - {result['analysis_type']} ({result['model']})")
    
    success_count = sum(1 for r in results if r['success'])
    print(f"\nTotal: {success_count}/{len(results)} tests passed")

def test_specific_analysis(analysis_type='comprehensive', model='sonnet'):
    """Test a specific analysis type"""
    invoke_lambda(analysis_type, model)

def check_lambda_logs():
    """Check recent Lambda logs"""
    logs_client = boto3.client('logs', region_name=REGION)
    log_group = f'/aws/lambda/{FUNCTION_NAME}'
    
    print(f"\nFetching recent logs from {log_group}...")
    
    try:
        # Get log streams
        response = logs_client.describe_log_streams(
            logGroupName=log_group,
            orderBy='LastEventTime',
            descending=True,
            limit=1
        )
        
        if response['logStreams']:
            log_stream = response['logStreams'][0]['logStreamName']
            
            # Get log events
            events = logs_client.get_log_events(
                logGroupName=log_group,
                logStreamName=log_stream,
                limit=50
            )
            
            print(f"\nRecent logs from {log_stream}:\n")
            for event in events['events']:
                timestamp = datetime.fromtimestamp(event['timestamp']/1000)
                print(f"[{timestamp}] {event['message']}")
        else:
            print("No log streams found")
            
    except Exception as e:
        print(f"Error fetching logs: {str(e)}")

def main():
    """Main test function"""
    
    import sys
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == 'all':
            test_all_analysis_types()
        elif command == 'logs':
            check_lambda_logs()
        elif command in ['comprehensive', 'at_risk', 'quick_summary', 'at_risk_students', 'predictive']:
            model = sys.argv[2] if len(sys.argv) > 2 else 'sonnet'
            test_specific_analysis(command, model)
        else:
            print(f"Unknown command: {command}")
            print("\nUsage:")
            print("  python test_bedrock_integration.py all")
            print("  python test_bedrock_integration.py comprehensive [sonnet|haiku]")
            print("  python test_bedrock_integration.py at_risk [sonnet|haiku]")
            print("  python test_bedrock_integration.py quick_summary [sonnet|haiku]")
            print("  python test_bedrock_integration.py logs")
    else:
        # Default: run quick summary test
        print("Running default test (quick_summary with haiku)...")
        print("Use 'python test_bedrock_integration.py all' to run all tests\n")
        test_specific_analysis('quick_summary', 'haiku')

if __name__ == "__main__":
    main()
