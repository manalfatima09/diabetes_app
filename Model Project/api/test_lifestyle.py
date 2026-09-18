import requests
import json

# Test the lifestyle plan endpoint
url = "http://localhost:5000/lifestyle_plan_ai"

# Test data
test_data = {
    "age": 30,
    "risk_level": "medium",
    "has_diabetes": True,
    "scenario": "leg injury, fruits nahi pasand",
    "patient_name": "Test User",
    "preferences": ["Fruits nahi pasand"],
    "restrictions": ["Leg injury"]
}

try:
    print("🚀 Testing Lifestyle Plan API...")
    response = requests.post(url, json=test_data, timeout=10)
    
    print(f"✅ Status Code: {response.status_code}")
    print(f"✅ Response Headers: {response.headers}")
    
    if response.status_code == 200:
        result = response.json()
        print("\n🎯 AI/Local Plan Generated:")
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(f"❌ Error: {response.text}")
        
except requests.exceptions.ConnectionError:
    print("❌ Connection Error: Make sure Flask server is running on http://localhost:5000")
    print("   Run: python app.py")
except Exception as e:
    print(f"❌ Unexpected error: {e}")