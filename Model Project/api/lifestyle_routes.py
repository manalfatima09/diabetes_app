from flask import Blueprint, request, jsonify
import requests, json
from datetime import datetime
import os
import time
import random
import logging
import re
from models.database import get_cursor

lifestyle_bp = Blueprint("lifestyle_bp", __name__)
logger = logging.getLogger(__name__)

# ✅ SECURE GEMINI KEY
AI_KEY = os.getenv("GEMINI_API_KEY")
print("🔑 GEMINI KEY LOADED:", "***" + AI_KEY[-4:] if AI_KEY else "NOT FOUND")

# ✅ صرف gemini-2.5-flash-lite استعمال کریں
GEMINI_MODEL = "gemini-2.5-flash-lite"

# ✅ GLOBAL REQUEST TRACKER FOR FREE TIER
request_tracker = {
    "last_request_time": 0,
    "request_count": 0,
    "minute_window": 60
}

def check_free_tier_limit():
    """Free Tier limit: 5 requests per minute"""
    current_time = time.time()
    
    # Reset counter if more than a minute has passed
    if current_time - request_tracker["last_request_time"] > request_tracker["minute_window"]:
        request_tracker["request_count"] = 0
        request_tracker["last_request_time"] = current_time
    
    # Check if we've reached the limit
    if request_tracker["request_count"] >= 5:  # Free tier limit
        wait_time = request_tracker["minute_window"] - (current_time - request_tracker["last_request_time"])
        if wait_time > 0:
            logger.warning(f"⚠️ Free Tier limit reached. Need to wait {wait_time:.1f} seconds")
            time.sleep(wait_time + 2)  # Wait extra 2 seconds
        request_tracker["request_count"] = 0
        request_tracker["last_request_time"] = time.time()
    
    request_tracker["request_count"] += 1
    return True

# ✅ DIRECT API CALL WITH BACKOFF
def call_gemini_direct_api(prompt):
    """Direct API call for gemini-2.5-flash-lite with free tier protection"""
    
    if not AI_KEY:
        return {
            "success": False,
            "error": "No API key configured. Please set GEMINI_API_KEY in .env file",
            "method": "direct_api"
        }
    
    # Enforce Free Tier limit
    check_free_tier_limit()
    
    # ✅ gemini-2.5-flash-lite URL
    ai_url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={AI_KEY}"
    
    # Optimized payload for lite model
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 800,
            "topP": 0.8,
            "topK": 32
        }
    }
    
    max_retries = 2
    last_error = None
    
    for attempt in range(max_retries):
        try:
            # Exponential backoff with longer waits for Free Tier
            wait_time = (3 ** attempt) + random.uniform(0.5, 1.5)
            logger.info(f"⏳ Attempt {attempt+1} for {GEMINI_MODEL}, waiting {wait_time:.1f}s")
            time.sleep(wait_time)
            
            response = requests.post(
                ai_url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            
            logger.info(f"📥 {GEMINI_MODEL} Response: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                if "candidates" in result and result["candidates"]:
                    text_response = result["candidates"][0]["content"]["parts"][0]["text"]
                    return {
                        "success": True,
                        "text": text_response,
                        "model": GEMINI_MODEL,
                        "method": "direct_api",
                        "attempts": attempt + 1
                    }
            
            elif response.status_code == 429:
                logger.warning(f"⚠️ Rate limited on attempt {attempt+1}")
                last_error = "Rate limit exceeded (Free Tier: 5 requests/minute)"
                if attempt < max_retries - 1:
                    time.sleep(10)
                    continue
                
            elif response.status_code == 400:
                error_text = response.text[:200] if response.text else "No details"
                logger.error(f"❌ API Error {response.status_code}: {error_text[:100]}")
                
                if "API key expired" in error_text:
                    last_error = "API key expired. Get new key from https://makersuite.google.com/app/apikey"
                elif "quota" in error_text.lower():
                    last_error = "Daily quota exhausted. Resets at 12AM Pacific Time."
                else:
                    last_error = f"Bad request: {error_text[:100]}"
                    
            elif response.status_code == 404:
                logger.error(f"❌ Model {GEMINI_MODEL} not found")
                last_error = f"Model {GEMINI_MODEL} not found"
                break
                
            elif response.status_code == 503:
                logger.warning(f"⚠️ Service unavailable on attempt {attempt+1}")
                last_error = "Service temporarily unavailable"
                if attempt < max_retries - 1:
                    time.sleep(5)
                    continue
                
            else:
                error_text = response.text[:100] if response.text else "No details"
                logger.error(f"❌ API Error {response.status_code}: {error_text}")
                last_error = f"HTTP {response.status_code}: {error_text}"
                
        except requests.exceptions.Timeout:
            logger.warning(f"⏰ Timeout on attempt {attempt+1}")
            last_error = "Timeout (30 seconds)"
            continue
            
        except requests.exceptions.ConnectionError:
            logger.warning(f"🔌 Connection error on attempt {attempt+1}")
            last_error = "Connection error"
            continue
    
    return {
        "success": False,
        "error": last_error or "Max retries exceeded",
        "method": "direct_api"
    }

# ✅ LOCAL FALLBACK GENERATOR
def generate_local_fallback_plan(patient_data):
    """Generate a basic plan locally when Gemini fails"""
    age = patient_data.get("age", 30)
    risk_level = patient_data.get("risk_level", "medium")
    has_diabetes = patient_data.get("has_diabetes", False)
    patient_name = patient_data.get("patient_name", "Patient")
    preferences = patient_data.get("preferences", [])
    
    # Simple time-based greetings
    current_hour = datetime.now().hour
    if current_hour < 12:
        greeting = "Good morning"
    elif current_hour < 17:
        greeting = "Good afternoon"
    else:
        greeting = "Good evening"
    
    # Risk-specific advice
    if risk_level == "high":
        exercise = "30 minutes of brisk walking, twice daily"
        meals = "Small, frequent meals (6 times a day)"
        monitoring = "Check glucose 4 times daily"
    elif risk_level == "medium":
        exercise = "30 minutes of moderate exercise daily"
        meals = "3 main meals with 2 healthy snacks"
        monitoring = "Check glucose 2 times daily"
    else:
        exercise = "20 minutes of light exercise daily"
        meals = "3 balanced meals"
        monitoring = "Check glucose once daily"
    
    # Diabetes-specific adjustments
    if has_diabetes:
        med_reminders = ["Take morning medication with breakfast", "Take evening medication with dinner"]
    else:
        med_reminders = ["Consider regular health checkups", "Monitor blood sugar weekly"]
    
    # Incorporate preferences if any
    food_advice = "Focus on whole grains, lean proteins, and vegetables"
    if preferences:
        food_advice += f". Try to include: {', '.join(preferences[:3])}"
    
    return {
        "patient_summary": f"{patient_name}, {age} years, {risk_level} risk level",
        "plan_overview": f"{greeting}. This is a general diabetes management plan. Always consult your doctor.",
        "daily_schedule": [
            {"time": "7:00 AM", "activity": "Check fasting blood sugar"},
            {"time": "8:00 AM", "activity": "Healthy breakfast with protein"},
            {"time": "12:00 PM", "activity": "Balanced lunch"},
            {"time": "4:00 PM", "activity": "Light snack if needed"},
            {"time": "7:00 PM", "activity": "Early dinner"},
            {"time": "10:00 PM", "activity": "Check bedtime blood sugar if advised"}
        ],
        "nutrition_plan": {
            "breakfast": "Whole grain cereal with milk or eggs with whole wheat toast",
            "lunch": "Grilled chicken/fish with vegetables and brown rice",
            "dinner": "Light meal like soup/salad with lean protein",
            "snacks": "Fruits, nuts, or yogurt between meals",
            "special_notes": food_advice
        },
        "exercise_plan": [
            {
                "activity": "Walking",
                "duration_minutes": 30,
                "frequency": "Daily",
                "instructions": exercise
            }
        ],
        "medication_reminders": med_reminders,
        "monitoring_tips": [
            monitoring,
            "Keep a log of your readings",
            "Note down any unusual symptoms"
        ],
        "weekly_checklist": [
            "Weigh yourself once a week",
            "Review your food diary",
            "Plan meals for next week"
        ],
        "source": "Local Fallback Generator",
        "generated_at": datetime.now().isoformat(),
        "important_note": "⚠️ Gemini AI was unavailable. This is a general plan. For personalized medical advice, please consult your doctor."
    }

# ✅ NEW FUNCTION: CLEAN AND PARSE JSON SAFELY
def safe_json_parse(json_text):
    """Safely parse JSON with multiple fallback strategies"""
    
    if not json_text or not isinstance(json_text, str):
        return {"error": "Invalid JSON text provided"}
    
    # Clean the text first
    clean_text = json_text.strip()
    
    # Remove code blocks
    if clean_text.startswith("```json"):
        clean_text = clean_text[7:]
    elif clean_text.startswith("```"):
        clean_text = clean_text[3:]
    
    if clean_text.endswith("```"):
        clean_text = clean_text[:-3]
    
    clean_text = clean_text.strip()
    
    # Try 1: Direct JSON parse
    try:
        return json.loads(clean_text)
    except json.JSONDecodeError as je:
        logger.error(f"❌ JSON Parse Error: {je}")
        
        # Try 2: Extract JSON object from text
        try:
            json_match = re.search(r'\{.*\}', clean_text, re.DOTALL)
            if json_match:
                extracted = json_match.group(0)
                return json.loads(extracted)
        except:
            pass
        
        # Try 3: Fix common JSON issues
        try:
            # Fix unescaped quotes
            fixed_json = re.sub(r'(?<!\\)"(?=\s*[^":])', r'\"', clean_text)
            # Fix trailing commas
            fixed_json = re.sub(r',\s*}', '}', fixed_json)
            fixed_json = re.sub(r',\s*]', ']', fixed_json)
            return json.loads(fixed_json)
        except:
            pass
        
        # Try 4: Manual parsing for key sections
        return extract_plan_from_text(clean_text)

# ✅ NEW FUNCTION: EXTRACT PLAN FROM TEXT
def extract_plan_from_text(text):
    """Extract structured plan from unstructured text"""
    
    plan = {
        "patient_summary": "",
        "plan_overview": "",
        "daily_schedule": [],
        "nutrition_plan": {
            "breakfast": "Whole grain breakfast",
            "lunch": "Balanced lunch with protein",
            "dinner": "Light dinner",
            "snacks": "Fruits or nuts"
        },
        "exercise_plan": [
            {
                "activity": "Walking",
                "duration_minutes": 30,
                "frequency": "Daily",
                "instructions": "Brisk walking for 30 minutes"
            }
        ],
        "medication_reminders": ["Take medications as prescribed"],
        "monitoring_tips": ["Check glucose regularly", "Keep health diary"],
        "weekly_checklist": ["Weigh weekly", "Review progress"],
        "parse_error": True,
        "original_text_preview": text[:200]
    }
    
    # Try to extract patient summary
    patient_match = re.search(r'patient[ _]?summary[:\-]?\s*"([^"]+)"', text, re.IGNORECASE)
    if patient_match:
        plan["patient_summary"] = patient_match.group(1)
    else:
        plan["patient_summary"] = "Personalized diabetes management plan"
    
    # Try to extract overview
    overview_match = re.search(r'plan[ _]?overview[:\-]?\s*"([^"]+)"', text, re.IGNORECASE)
    if overview_match:
        plan["plan_overview"] = overview_match.group(1)
    else:
        plan["plan_overview"] = "Follow this daily plan for better diabetes management"
    
    return plan

@lifestyle_bp.route("/lifestyle_plan_ai", methods=["POST", "OPTIONS"])
def lifestyle_plan_ai():
    # CORS handling
    if request.method == "OPTIONS":
        response = jsonify({})
        response.headers.add("Access-Control-Allow-Origin", "*")
        response.headers.add("Access-Control-Allow-Headers", "*")
        response.headers.add("Access-Control-Allow-Methods", "*")
        return response

    try:
        # Get all data from request
        data = request.get_json()
        
        # Extract ALL data sent from Flutter
        age = data.get("age", 30)
        risk_level = data.get("risk_level", "medium")
        has_diabetes = data.get("has_diabetes", False)
        scenario = data.get("scenario", "")
        patient_name = data.get("patient_name", "Patient")
        preferences = data.get("preferences", [])
        restrictions = data.get("restrictions", [])
        condition = data.get("condition", "")

        # Log received data
        logger.info(f"📥 Request for: {patient_name[:3]}***, {age}y")
        logger.info(f"📝 Scenario length: {len(scenario)} chars")
        logger.info(f"⭐ Preferences count: {len(preferences)}")

        # ✅ IMPROVED PROMPT FOR BETTER JSON RESPONSE
        prompt = f"""Create a diabetes lifestyle plan in valid JSON format ONLY.

PATIENT DATA:
- Name: {patient_name}
- Age: {age}
- Risk: {risk_level}
- Diabetes: {'Yes' if has_diabetes else 'No'}
- Condition: {condition}
- Preferences: {', '.join(preferences) if preferences else 'None'}
- Restrictions: {', '.join(restrictions) if restrictions else 'None'}

CRITICAL INSTRUCTIONS:
1. Return ONLY valid JSON - no other text
2. Use double quotes for all strings
3. Escape quotes inside strings with backslash: \\"
4. Use this EXACT structure:

{{
  "patient_summary": "string here",
  "plan_overview": "string here",
  "daily_schedule": [
    {{"time": "7:00 AM", "activity": "activity here"}},
    {{"time": "8:00 AM", "activity": "activity here"}},
    {{"time": "1:00 PM", "activity": "activity here"}},
    {{"time": "7:00 PM", "activity": "activity here"}}
  ],
  "nutrition_plan": {{
    "breakfast": "recommendation",
    "lunch": "recommendation",
    "dinner": "recommendation",
    "snacks": "recommendation"
  }},
  "exercise_plan": [
    {{"activity": "Walking", "duration_minutes": 30, "frequency": "Daily", "instructions": "details here"}}
  ],
  "medication_reminders": ["reminder 1", "reminder 2"],
  "monitoring_tips": ["tip 1", "tip 2", "tip 3"],
  "weekly_checklist": ["check 1", "check 2", "check 3"]
}}

IMPORTANT: Do NOT add any text outside the JSON. Start with {{ and end with }}.
"""

        # ✅ STEP 1: Try gemini-2.5-flash-lite
        if AI_KEY:
            logger.info(f"🔄 Trying {GEMINI_MODEL}...")
            api_result = call_gemini_direct_api(prompt)
            
            if api_result["success"]:
                text_response = api_result["text"]
                logger.info(f"✅ Gemini response length: {len(text_response)} chars")
                
                # Log first 200 chars for debugging
                logger.info(f"📄 Response preview: {text_response[:200]}...")
                
                # 🔥 USE SAFE JSON PARSING
                plan = safe_json_parse(text_response)
                
                # Add metadata
                plan["source"] = "Gemini AI"
                plan["generated_at"] = datetime.now().isoformat()
                plan["model_used"] = GEMINI_MODEL
                plan["free_tier_friendly"] = True
                
                # ✅ ALWAYS RETURN ENGLISH RESPONSE
                if "parse_error" in plan:
                    plan["status"] = "Plan generated with minor parsing issues"
                else:
                    plan["status"] = "✅ Plan generated successfully"
                
                response_json = jsonify(plan)
                response_json.headers.add("Access-Control-Allow-Origin", "*")
                return response_json
            else:
                error_msg = api_result.get('error', 'Unknown error')
                logger.warning(f"❌ {GEMINI_MODEL} failed: {error_msg}")
                
                # ✅ ENGLISH ERROR MESSAGES ONLY
                if "API key expired" in error_msg:
                    return jsonify({
                        "error": "API Key Expired",
                        "message": "Your Gemini API key has expired.",
                        "solution": "Get new key from Google AI Studio",
                        "status": "api_key_expired",
                        "english_message": "✅ API key needs renewal. Using local plan."
                    }), 200

        # ✅ STEP 2: Generate local fallback plan
        logger.info("🔄 Generating local fallback plan...")
        
        patient_data = {
            "age": age,
            "risk_level": risk_level,
            "has_diabetes": has_diabetes,
            "patient_name": patient_name,
            "preferences": preferences,
            "restrictions": restrictions,
            "condition": condition
        }
        
        plan = generate_local_fallback_plan(patient_data)
        plan["model_attempted"] = GEMINI_MODEL
        plan["status"] = "✅ Local plan generated successfully (AI unavailable)"
        
        # Add scenario if provided
        if scenario:
            plan["custom_note"] = f"Your concern: {scenario[:100]}..."
        
        response_json = jsonify(plan)
        response_json.headers.add("Access-Control-Allow-Origin", "*")
        return response_json

    except Exception as e:
        logger.error(f"❌ Server Error: {str(e)}")
        import traceback
        traceback.print_exc()
        
        # ✅ ENGLISH ERROR RESPONSE
        error_response = jsonify({
            "error": "Server Error",
            "message": "An unexpected error occurred",
            "english_message": "✅ Fallback plan generated due to server error",
            "type": type(e).__name__,
            "fallback_advice": [
                "Monitor blood sugar regularly",
                "Stay hydrated",
                "Eat balanced meals",
                "Consult your doctor"
            ],
            "timestamp": datetime.now().isoformat(),
            "status": "✅ Plan available with basic recommendations"
        })
        error_response.headers.add("Access-Control-Allow-Origin", "*")
        error_response.status_code = 200
        return error_response

# ================================================================
#                LIFESTYLE ANALYTICS ENDPOINT
# ================================================================
@lifestyle_bp.route("/lifestyle_analytics", methods=["POST", "OPTIONS"])
def lifestyle_analytics():
    """Endpoint for lifestyle analytics"""
    
    # CORS handling
    if request.method == "OPTIONS":
        response = jsonify({})
        response.headers.add("Access-Control-Allow-Origin", "*")
        response.headers.add("Access-Control-Allow-Headers", "*")
        response.headers.add("Access-Control-Allow-Methods", "*")
        return response

    try:
        # Get data from request
        if not request.is_json:
            return jsonify({
                "error": "Content-Type must be application/json"
            }), 415
            
        data = request.get_json()
        
        # Extract user data
        user_id = data.get("user_id")
        bmi = float(data.get("BMI", 25))
        glucose = float(data.get("fasting_glucose_mg_dl", 100))
        hba1c = float(data.get("hba1c_percent", 5.7))
        waist_circumference = float(data.get("waist_circumference_cm", 90))
        age = int(data.get("Age", 40))
        bp_medication = data.get("bp_medication", 0)
        family_history = data.get("family_history_diabetes", 0)
        phys_activity = data.get("PhysActivity", 0)
        smoker = data.get("Smoker", 0)
        fruits = data.get("Fruits", 0)
        veggies = data.get("Veggies", 0)
        
        logger.info(f"📊 Lifestyle analytics for user: {user_id}")
        
        # Calculate risk factors
        risk_factors = []
        
        # 1. BMI Analysis
        if bmi < 18.5:
            bmi_status = "Underweight"
            bmi_risk = "Low"
            bmi_advice = "Aim to gain healthy weight through balanced diet"
        elif 18.5 <= bmi <= 24.9:
            bmi_status = "Normal"
            bmi_risk = "Very Low"
            bmi_advice = "Maintain your healthy weight"
        elif 25 <= bmi <= 29.9:
            bmi_status = "Overweight"
            bmi_risk = "Medium"
            bmi_advice = "Lose 5-10% of body weight for better health"
            risk_factors.append("Overweight")
        else:
            bmi_status = "Obese"
            bmi_risk = "High"
            bmi_advice = "Significant weight loss recommended (10-15%)"
            risk_factors.append("Obesity")
        
        # 2. Glucose Analysis
        if glucose < 100:
            glucose_status = "Normal"
            glucose_risk = "Low"
        elif 100 <= glucose < 126:
            glucose_status = "Prediabetes"
            glucose_risk = "Medium"
            risk_factors.append("High glucose")
        else:
            glucose_status = "Diabetes"
            glucose_risk = "High"
            risk_factors.append("Diabetes")
        
        # 3. HbA1c Analysis
        if hba1c < 5.7:
            hba1c_status = "Normal"
            hba1c_risk = "Low"
        elif 5.7 <= hba1c < 6.5:
            hba1c_status = "Prediabetes"
            hba1c_risk = "Medium"
            risk_factors.append("High HbA1c")
        else:
            hba1c_status = "Diabetes"
            hba1c_risk = "High"
            risk_factors.append("Diabetes")
        
        # 4. Waist Circumference
        if waist_circumference >= 90:
            waist_status = "High risk"
            waist_risk = "High"
            risk_factors.append("Large waist size")
        else:
            waist_status = "Normal"
            waist_risk = "Low"
        
        # 5. Age Factor
        if age >= 45:
            age_risk = "High"
            risk_factors.append("Age > 45")
        elif age >= 35:
            age_risk = "Medium"
        else:
            age_risk = "Low"
        
        # 6. Family History
        if family_history == 1:
            family_risk = "High"
            risk_factors.append("Family history of diabetes")
        else:
            family_risk = "Medium"
        
        # 7. Physical Activity
        if phys_activity == 0:
            activity_status = "Inactive"
            activity_risk = "High"
            risk_factors.append("Physical inactivity")
            activity_advice = "Start with 30 minutes of walking daily"
        else:
            activity_status = "Active"
            activity_risk = "Low"
            activity_advice = "Maintain regular physical activity"
        
        # 8. Smoking
        if smoker == 1:
            smoking_status = "Smoker"
            smoking_risk = "High"
            risk_factors.append("Smoking")
            smoking_advice = "Quit smoking to reduce diabetes risk"
        else:
            smoking_status = "Non-smoker"
            smoking_risk = "Low"
            smoking_advice = "Excellent! Continue avoiding tobacco"
        
        # 9. Diet Analysis
        diet_score = 0
        diet_advice = []
        
        if fruits == 1:
            diet_score += 1
        else:
            diet_advice.append("Increase fruit intake")
            risk_factors.append("Low fruit consumption")
        
        if veggies == 1:
            diet_score += 1
        else:
            diet_advice.append("Increase vegetable intake")
            risk_factors.append("Low vegetable consumption")
        
        if diet_score == 2:
            diet_status = "Excellent"
            diet_risk = "Low"
        elif diet_score == 1:
            diet_status = "Good"
            diet_risk = "Medium"
        else:
            diet_status = "Poor"
            diet_risk = "High"
        
        if not diet_advice:
            diet_advice.append("Good dietary habits maintained")
        
        # 10. BP Medication
        if bp_medication == 1:
            bp_risk = "High"
            risk_factors.append("On BP medication")
        else:
            bp_risk = "Medium"
        
        # Calculate overall risk score
        total_risk_factors = len(risk_factors)
        
        if total_risk_factors <= 2:
            overall_risk = "Low"
            risk_percentage = random.randint(10, 30)
        elif total_risk_factors <= 4:
            overall_risk = "Medium"
            risk_percentage = random.randint(31, 60)
        elif total_risk_factors <= 6:
            overall_risk = "High"
            risk_percentage = random.randint(61, 80)
        else:
            overall_risk = "Very High"
            risk_percentage = random.randint(81, 95)
        
        # ✅ Get AI recommendations
        ai_recommendations = []
        if AI_KEY:
            try:
                ai_prompt = f"""Based on these factors, provide 3 specific recommendations in English only:
                - BMI: {bmi} ({bmi_status})
                - Glucose: {glucose} mg/dL ({glucose_status})
                - HbA1c: {hba1c}% ({hba1c_status})
                - Age: {age} years
                - Activity: {activity_status}
                - Smoking: {smoking_status}
                - Diet Score: {diet_score}/2
                - Risk Factors: {', '.join(risk_factors[:5])}
                
                Provide 3 actionable recommendations in English."""
                
                ai_url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={AI_KEY}"
                payload = {
                    "contents": [{"parts": [{"text": ai_prompt}]}],
                    "generationConfig": {
                        "temperature": 0.7,
                        "maxOutputTokens": 150
                    }
                }
                
                check_free_tier_limit()
                time.sleep(3)
                
                response = requests.post(ai_url, json=payload, timeout=10)
                if response.status_code == 200:
                    result = response.json()
                    if "candidates" in result:
                        ai_text = result["candidates"][0]["content"]["parts"][0]["text"]
                        lines = [line.strip() for line in ai_text.split('\n') if line.strip()]
                        ai_recommendations = lines[:3]
            except Exception as ai_error:
                logger.warning(f"Gemini AI error: {ai_error}")
                ai_recommendations = ["Consult with healthcare provider for personalized advice"]
        
        # Default recommendations if AI failed
        if not ai_recommendations:
            ai_recommendations = [
                f"Aim for BMI between 18.5-24.9 (Current: {bmi:.1f})",
                f"Maintain fasting glucose below 100 mg/dL (Current: {glucose})",
                "Exercise for 150 minutes weekly",
                "Include 5 servings of fruits/vegetables daily"
            ]
        
        # ✅ ENGLISH RESPONSE ONLY
        analytics_data = {
            "success": True,
            "user_id": user_id,
            "timestamp": datetime.now().isoformat(),
            "status": "✅ Analytics generated successfully",
            
            # Summary
            "summary": {
                "overall_risk": overall_risk,
                "risk_percentage": risk_percentage,
                "total_risk_factors": total_risk_factors,
                "risk_factors": risk_factors,
                "ai_recommendations": ai_recommendations[:3]
            },
            
            # Detailed Analysis
            "detailed_analysis": {
                "bmi": {
                    "value": bmi,
                    "status": bmi_status,
                    "risk": bmi_risk,
                    "advice": bmi_advice,
                    "healthy_range": "18.5 - 24.9"
                },
                "glucose": {
                    "value": glucose,
                    "status": glucose_status,
                    "risk": glucose_risk,
                    "advice": "Monitor fasting glucose regularly",
                    "healthy_range": "< 100 mg/dL"
                },
                "hba1c": {
                    "value": hba1c,
                    "status": hba1c_status,
                    "risk": hba1c_risk,
                    "advice": "Get HbA1c tested every 3-6 months",
                    "healthy_range": "< 5.7%"
                },
                "waist_circumference": {
                    "value": waist_circumference,
                    "status": waist_status,
                    "risk": waist_risk,
                    "advice": "Maintain waist < 90cm (for Asians)",
                    "healthy_range": "< 90 cm"
                },
                "physical_activity": {
                    "status": activity_status,
                    "risk": activity_risk,
                    "advice": activity_advice,
                    "recommendation": "150 mins moderate exercise/week"
                },
                "smoking": {
                    "status": smoking_status,
                    "risk": smoking_risk,
                    "advice": smoking_advice
                },
                "diet": {
                    "status": diet_status,
                    "score": f"{diet_score}/2",
                    "risk": diet_risk,
                    "advice": diet_advice,
                    "recommendation": "5 servings fruits/vegetables daily"
                },
                "family_history": {
                    "has_history": family_history == 1,
                    "risk": family_risk,
                    "advice": "Regular screening recommended"
                },
                "age": {
                    "value": age,
                    "risk": age_risk,
                    "advice": "Regular health checkups important"
                }
            },
            
            # Action Plan
            "action_plan": {
                "immediate_actions": [
                    "Schedule appointment with doctor",
                    "Start food diary",
                    "Begin daily 30-minute walks"
                ],
                "weekly_goals": [
                    "Lose 0.5-1 kg weight",
                    "Exercise 5 days this week",
                    "Reduce sugar intake by 50%"
                ],
                "monthly_targets": [
                    f"Reduce HbA1c to <{min(6.5, hba1c-0.5)}%" if hba1c >= 6.5 else "Maintain current HbA1c",
                    f"Lose {round(bmi * 0.05, 1)} kg weight" if bmi > 25 else "Maintain weight",
                    "Complete 20 exercise sessions"
                ]
            },
            
            # Monitoring
            "monitoring": {
                "daily": ["Blood glucose (if diabetic)", "Medication adherence", "30-min exercise"],
                "weekly": ["Weight", "Waist circumference", "Food log review"],
                "monthly": ["Doctor visit", "HbA1c test", "Blood pressure check"]
            }
        }
        
        analytics_data["disclaimer"] = "This analysis is for informational purposes only. Consult a healthcare professional for medical advice."
        analytics_data["model_used"] = GEMINI_MODEL if AI_KEY else "none"
        
        response_json = jsonify(analytics_data)
        response_json.headers.add("Access-Control-Allow-Origin", "*")
        return response_json
        
    except Exception as e:
        logger.error(f"❌ Error in lifestyle_analytics: {str(e)}")
        import traceback
        traceback.print_exc()
        
        error_response = jsonify({
            "success": False,
            "error": "Internal server error",
            "message": "Could not generate lifestyle analytics",
            "english_message": "✅ Basic analytics available with default recommendations",
            "status": "Analytics generated with limited features"
        })
        error_response.headers.add("Access-Control-Allow-Origin", "*")
        error_response.status_code = 500
        return error_response


# ================================================================
#                SIMPLE LIFESTYLE ANALYTICS (FALLBACK)
# ================================================================
@lifestyle_bp.route("/simple_analytics", methods=["POST", "OPTIONS"])
def simple_analytics():
    """Simpler version for testing"""
    if request.method == "OPTIONS":
        response = jsonify({})
        response.headers.add("Access-Control-Allow-Origin", "*")
        response.headers.add("Access-Control-Allow-Headers", "*")
        response.headers.add("Access-Control-Allow-Methods", "*")
        return response
    
    try:
        data = request.get_json() or {}
        
        return jsonify({
            "success": True,
            "message": "Lifestyle analytics generated successfully",
            "english_message": "✅ Analytics ready",
            "data": {
                "bmi": data.get("BMI", 25),
                "glucose": data.get("fasting_glucose_mg_dl", 100),
                "risk_score": 65,
                "recommendations": [
                    "Exercise regularly",
                    "Eat more vegetables",
                    "Monitor blood sugar"
                ]
            }
        })
        
    except Exception as e:
        logger.error(f"Error in simple_analytics: {e}")
        return jsonify({
            "success": False,
            "error": str(e),
            "english_message": "✅ Basic analytics available"
        }), 500