from flask import Blueprint, request, jsonify
from models.database import get_cursor, get_db
from datetime import datetime, timedelta
import json
from firebase_admin import auth
import logging
import uuid

glucose_bp = Blueprint('glucose', __name__)
logger = logging.getLogger(__name__)

# ================================================================
#             CREATE PATIENT IF NOT EXISTS (FIXED)
# ================================================================
def create_patient_if_not_exists(firebase_uid, email=None):
    """Create a patient record if it doesn't exist"""
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        
        # Check if user exists
        cursor.execute("SELECT user_id FROM users WHERE firebase_uid = %s", (firebase_uid,))
        user = cursor.fetchone()
        
        if user:
            user_id = user["user_id"]
            print(f"✅ User exists with ID: {user_id}")
        else:
            # Create user
            email = email or f"user_{firebase_uid[:8]}@example.com"
            cursor.execute("""
                INSERT INTO users (firebase_uid, email, full_name, role)
                VALUES (%s, %s, %s, %s)
            """, (firebase_uid, email, "Patient User", "patient"))
            user_id = cursor.lastrowid
            print(f"✅ Created new user with ID: {user_id}")
        
        # Check if patient exists
        cursor.execute("SELECT patient_id FROM patients WHERE user_id = %s", (user_id,))
        patient = cursor.fetchone()
        
        if patient:
            patient_id = patient["patient_id"]
            print(f"✅ Patient exists with ID: {patient_id}")
        else:
            # Create patient
            cursor.execute("""
                INSERT INTO patients (user_id)
                VALUES (%s)
            """, (user_id,))
            patient_id = cursor.lastrowid
            print(f"✅ Created new patient with ID: {patient_id}")
        
        db.commit()
        return patient_id
        
    except Exception as e:
        logger.error(f"Error creating patient: {e}")
        db.rollback()
        return None
    finally:
        cursor.close()

# ================================================================
#             GET PATIENT ID FROM FIREBASE (UPDATED)
# ================================================================
def get_patient_id_from_firebase(firebase_uid, email=None):
    """Helper function to get or create patient_id from firebase_uid"""
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT p.patient_id 
            FROM patients p
            JOIN users u ON p.user_id = u.user_id
            WHERE u.firebase_uid = %s
        """, (firebase_uid,))
        
        patient = cursor.fetchone()
        cursor.close()
        
        if patient:
            return patient["patient_id"]
        else:
            print(f"⚠️ No patient found for Firebase UID: {firebase_uid}")
            print("💡 Creating new patient record...")
            
            # Create patient if not exists
            patient_id = create_patient_if_not_exists(firebase_uid, email)
            if patient_id:
                print(f"✅ Created patient with ID: {patient_id}")
                return patient_id
            else:
                print("❌ Failed to create patient")
                return None
                
    except Exception as e:
        logger.error(f"Error getting patient_id: {e}")
        return None

# ================================================================
#             VERIFY FIREBASE TOKEN (NEW FUNCTION)
# ================================================================
def verify_firebase_token(token):
    """Verify Firebase token and return decoded token"""
    try:
        # Add clock tolerance for timing issues
        decoded_token = auth.verify_id_token(
            token, 
            clock_skew_seconds=60  # Allow 60 seconds clock skew
        )
        return decoded_token
    except auth.ExpiredIdTokenError:
        print("❌ Firebase token expired")
        raise
    except auth.InvalidIdTokenError:
        print("❌ Firebase token invalid")
        raise
    except Exception as e:
        print(f"❌ Firebase token verification error: {e}")
        raise

# ================================================================
#             ADD GLUCOSE READING (FIXED)
# ================================================================
@glucose_bp.route('/add_glucose_reading', methods=['POST', 'OPTIONS'])
def add_glucose_reading():
    # Handle CORS preflight
    if request.method == 'OPTIONS':
        return jsonify({"message": "CORS preflight"}), 200
    
    try:
        print(f"🔍 Request Headers: {dict(request.headers)}")
        
        # -----------------------
        # 1. DUAL AUTHENTICATION MODE
        # -----------------------
        patient_id = None
        auth_method = None
        firebase_uid = None
        user_email = None
        
        auth_header = request.headers.get('Authorization')
        
        # Option 1: Firebase Authentication
        if auth_header and auth_header.startswith('Bearer '):
            try:
                token = auth_header.split("Bearer ")[1]
                print(f"🔍 Token received (first 50 chars): {token[:50]}...")
                
                # Verify token with clock tolerance
                decoded_token = verify_firebase_token(token)
                firebase_uid = decoded_token.get("uid")
                user_email = decoded_token.get("email")
                print(f"✅ Firebase UID: {firebase_uid}")
                print(f"✅ User Email: {user_email}")
                
                # Get or create patient_id from firebase_uid
                patient_id = get_patient_id_from_firebase(firebase_uid, user_email)
                if patient_id:
                    auth_method = "firebase"
                    print(f"✅ Using Firebase auth, patient_id: {patient_id}")
                else:
                    print("❌ Could not get or create patient record")
                    return jsonify({
                        "error": "Could not create patient record",
                        "firebase_uid": firebase_uid,
                        "success": False
                    }), 400
                    
            except Exception as e:
                print(f"❌ Firebase authentication failed: {e}")
                # Continue to direct patient_id method
        
        # Option 2: Direct patient_id from request body (Legacy support)
        if not patient_id:
            data = request.get_json()
            if not data:
                return jsonify({"error": "No JSON data provided", "success": False}), 400
                
            patient_id = data.get('patient_id')
            if patient_id:
                auth_method = "direct"
                print(f"⚠️ Using direct patient_id from body: {patient_id}")
            else:
                # If no patient_id, use default
                patient_id = 1  # Default test patient
                auth_method = "default"
                print(f"⚠️ No patient_id provided, using default: {patient_id}")
        
        # -----------------------
        # 2. INPUT DATA
        # -----------------------
        data = request.get_json()
        print(f"📥 Received glucose data: {data}")
        
        if not data:
            return jsonify({"error": "No JSON data provided", "success": False}), 400
            
        glucose_value = data.get('glucose_value')
        measurement_type = data.get('measurement_type', 'Random')
        meal_type = data.get('meal_type')
        fasting_hours = data.get('fasting_hours')
        notes = data.get('notes')
        device_type = data.get('device_type', 'Mobile App')
        
        print(f"🔍 Parsed data - patient_id: {patient_id}, glucose_value: {glucose_value}")
        
        # Validation
        if not glucose_value:
            return jsonify({"error": "Missing glucose_value", "success": False}), 400
        
        # Convert to proper types
        try:
            glucose_float = float(glucose_value)
        except (ValueError, TypeError) as e:
            return jsonify({"error": f"Invalid glucose value: {str(e)}", "success": False}), 400
        
        # Determine category based on glucose value
        category = "Normal"
        if glucose_float < 70:
            category = "Hypoglycemia"
        elif glucose_float <= 100:
            category = "Normal"
        elif glucose_float <= 140:
            category = "Normal"
        elif glucose_float <= 180:
            category = "High"
        elif glucose_float <= 250:
            category = "Dangerous"
        else:
            category = "Critical"
        
        print(f"📊 Category determined: {category}")
        
        # -----------------------
        # 3. SAVE TO DATABASE
        # -----------------------
        db = get_db()
        cursor = db.cursor(dictionary=True)
        
        # Insert glucose reading
        cursor.execute("""
            INSERT INTO glucose_readings (
                patient_id, glucose_value, measurement_type, category,
                meal_type, fasting_hours, notes, device_type,
                reading_date, reading_time
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, CURDATE(), CURTIME())
        """, (
            patient_id, glucose_float, measurement_type, category,
            meal_type,
            fasting_hours,
            notes,
            device_type
        ))
        
        glucose_id = cursor.lastrowid
        
        print(f"✅ Inserted glucose reading with ID: {glucose_id} for patient: {patient_id}")
        
        # If critical reading, create emergency alert
        if category in ['Critical', 'Dangerous', 'Hypoglycemia']:
            print(f"⚠️ Creating emergency alert for {category}")
            
            # Get patient info
            cursor.execute("""
                SELECT u.full_name, p.emergency_contact_name, p.emergency_contact_phone
                FROM patients p
                LEFT JOIN users u ON p.user_id = u.user_id
                WHERE p.patient_id = %s
            """, (patient_id,))
            patient_info = cursor.fetchone()
            
            if patient_info and patient_info.get('full_name'):
                alert_message = f"Patient {patient_info['full_name']} has {category} glucose level: {glucose_float} mg/dL"
                
                # Get assigned doctor
                cursor.execute("""
                    SELECT d.doctor_id 
                    FROM patients p 
                    LEFT JOIN doctors d ON p.doctor_id = d.doctor_id 
                    WHERE p.patient_id = %s
                """, (patient_id,))
                doctor = cursor.fetchone()
                
                doctor_id = doctor['doctor_id'] if doctor and doctor.get('doctor_id') else None
                
                # Create emergency alert
                cursor.execute("""
                    INSERT INTO emergency_alerts (
                        patient_id, glucose_reading_id, alert_type,
                        glucose_value, alert_message, severity, sent_to_doctor_id
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, (
                    patient_id, glucose_id, category, glucose_float,
                    alert_message, 
                    'Critical' if category == 'Critical' else 'Severe',
                    doctor_id
                ))
        
        db.commit()
        cursor.close()
        
        response_data = {
            "success": True,
            "message": "Glucose reading saved successfully",
            "glucose_id": glucose_id,
            "category": category,
            "patient_id": patient_id,
            "auth_method": auth_method,
            "glucose_value": glucose_float,
            "timestamp": datetime.now().isoformat()
        }
        
        if firebase_uid:
            response_data["firebase_uid"] = firebase_uid
            
        return jsonify(response_data), 200
        
    except Exception as e:
        print(f"❌ Error in add_glucose_reading: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e), "success": False}), 500

# ================================================================
#        GET GLUCOSE HISTORY (FIXED)
# ================================================================
@glucose_bp.route('/get_glucose_history', methods=['POST', 'OPTIONS'])
def get_glucose_history():
    if request.method == 'OPTIONS':
        return jsonify({"message": "CORS preflight"}), 200
    
    try:
        # -----------------------
        # 1. DUAL AUTHENTICATION
        # -----------------------
        patient_id = None
        firebase_uid = None
        
        auth_header = request.headers.get('Authorization')
        
        # Option 1: Firebase Authentication
        if auth_header and auth_header.startswith('Bearer '):
            try:
                token = auth_header.split("Bearer ")[1]
                decoded_token = verify_firebase_token(token)
                firebase_uid = decoded_token.get("uid")
                user_email = decoded_token.get("email")
                print(f"✅ Firebase UID: {firebase_uid}")
                
                # Get or create patient_id from firebase_uid
                patient_id = get_patient_id_from_firebase(firebase_uid, user_email)
                if not patient_id:
                    return jsonify({"error": "Could not create patient record", "success": False}), 400
                    
            except Exception as e:
                print(f"❌ Firebase authentication failed: {e}")
                # Continue to direct method
        
        # Option 2: Direct patient_id from request body
        if not patient_id:
            data = request.get_json()
            if not data:
                return jsonify({"error": "No JSON data provided", "success": False}), 400
                
            patient_id = data.get('patient_id')
            if not patient_id:
                # Use default test patient
                patient_id = 1
                print(f"⚠️ No patient_id provided, using default: {patient_id}")
        
        # -----------------------
        # 2. INPUT DATA
        # -----------------------
        data = request.get_json() or {}
        days = data.get('days', 30)
        
        db = get_db()
        cursor = db.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT 
                glucose_id, patient_id, glucose_value, measurement_type,
                category, meal_type, fasting_hours, notes, device_type,
                reading_date, reading_time, created_at
            FROM glucose_readings 
            WHERE patient_id = %s 
            AND reading_date >= DATE_SUB(CURDATE(), INTERVAL %s DAY)
            ORDER BY reading_date DESC, reading_time DESC
        """, (patient_id, days))
        
        rows = cursor.fetchall()
        
        result_data = []
        for r in rows:
            result_data.append({
                "glucose_id": r["glucose_id"],
                "patient_id": r["patient_id"],
                "glucose_value": float(r["glucose_value"]),
                "measurement_type": r["measurement_type"],
                "category": r["category"],
                "meal_type": r["meal_type"],
                "fasting_hours": r["fasting_hours"],
                "notes": r["notes"],
                "device_type": r["device_type"],
                "reading_date": str(r["reading_date"]) if r["reading_date"] else None,
                "reading_time": str(r["reading_time"]).split('.')[0] if r["reading_time"] else None,
                "created_at": str(r["created_at"]) if r["created_at"] else None
            })
        
        cursor.close()
        
        return jsonify({
            "success": True,
            "patient_id": patient_id,
            "history": result_data,
            "count": len(result_data),
            "days": days
        }), 200
        
    except Exception as e:
        logger.error(f"Error in get_glucose_history: {str(e)}")
        return jsonify({"error": str(e), "success": False}), 500

# ================================================================
#        GET GLUCOSE STATS (FIXED)
# ================================================================
@glucose_bp.route('/get_glucose_stats', methods=['POST', 'OPTIONS'])
def get_glucose_stats():
    if request.method == 'OPTIONS':
        return jsonify({"message": "CORS preflight"}), 200
    
    try:
        # -----------------------
        # 1. DUAL AUTHENTICATION
        # -----------------------
        patient_id = None
        
        auth_header = request.headers.get('Authorization')
        
        # Option 1: Firebase Authentication
        if auth_header and auth_header.startswith('Bearer '):
            try:
                token = auth_header.split("Bearer ")[1]
                decoded_token = verify_firebase_token(token)
                firebase_uid = decoded_token.get("uid")
                user_email = decoded_token.get("email")
                
                # Get or create patient_id from firebase_uid
                patient_id = get_patient_id_from_firebase(firebase_uid, user_email)
                if not patient_id:
                    return jsonify({"error": "Could not create patient record", "success": False}), 400
                    
            except Exception as e:
                print(f"❌ Firebase authentication failed: {e}")
                # Continue to direct method
        
        # Option 2: Direct patient_id from request body
        if not patient_id:
            data = request.get_json()
            if not data:
                return jsonify({"error": "No JSON data provided", "success": False}), 400
                
            patient_id = data.get('patient_id')
            if not patient_id:
                # Use default test patient
                patient_id = 1
                print(f"⚠️ No patient_id provided, using default: {patient_id}")
        
        # -----------------------
        # 2. INPUT DATA
        # -----------------------
        data = request.get_json() or {}
        days = data.get('days', 30)
        
        db = get_db()
        cursor = db.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT 
                COUNT(*) as total_readings,
                AVG(glucose_value) as average_glucose,
                MIN(glucose_value) as min_glucose,
                MAX(glucose_value) as max_glucose,
                SUM(CASE WHEN category = 'Hypoglycemia' THEN 1 ELSE 0 END) as hypoglycemia_count,
                SUM(CASE WHEN category = 'Normal' THEN 1 ELSE 0 END) as normal_count,
                SUM(CASE WHEN category IN ('High', 'Dangerous', 'Critical') THEN 1 ELSE 0 END) as hyperglycemia_count
            FROM glucose_readings
            WHERE patient_id = %s
            AND reading_date >= DATE_SUB(CURDATE(), INTERVAL %s DAY)
        """, (patient_id, days))
        
        stats = cursor.fetchone()
        cursor.close()
        
        return jsonify({
            "success": True,
            "patient_id": patient_id,
            "total_readings": int(stats["total_readings"] or 0),
            "average_glucose": round(float(stats["average_glucose"] or 0), 1),
            "min_glucose": round(float(stats["min_glucose"] or 0), 1),
            "max_glucose": round(float(stats["max_glucose"] or 0), 1),
            "hypoglycemia_count": int(stats["hypoglycemia_count"] or 0),
            "normal_count": int(stats["normal_count"] or 0),
            "hyperglycemia_count": int(stats["hyperglycemia_count"] or 0),
            "days": days
        }), 200
        
    except Exception as e:
        logger.error(f"Error in get_glucose_stats: {str(e)}")
        return jsonify({"error": str(e), "success": False}), 500

# ================================================================
#        LEGACY COMPATIBILITY ENDPOINTS
# ================================================================
@glucose_bp.route('/add_glucose', methods=['POST', 'OPTIONS'])
def add_glucose_legacy():
    """Legacy endpoint for old Flutter app compatibility"""
    if request.method == 'OPTIONS':
        return jsonify({"message": "CORS preflight"}), 200
    
    try:
        data = request.get_json() or request.form
        
        print(f"📥 Legacy endpoint received data: {data}")
        
        patient_id = data.get('patient_id') or data.get('p_id')
        glucose_value = data.get('glucose') or data.get('glucose_value')
        
        if not patient_id or not glucose_value:
            return jsonify({"error": "Missing patient_id or glucose_value", "success": False}), 400
        
        # Call the main function
        return add_glucose_reading()
        
    except Exception as e:
        print(f"❌ Error in legacy endpoint: {e}")
        return jsonify({"error": str(e), "success": False}), 500

@glucose_bp.route('/get_glucose', methods=['POST', 'OPTIONS'])
def get_glucose_legacy():
    """Legacy endpoint for old Flutter app compatibility"""
    if request.method == 'OPTIONS':
        return jsonify({"message": "CORS preflight"}), 200
    
    try:
        data = request.get_json() or request.form
        
        patient_id = data.get('patient_id') or data.get('p_id')
        if not patient_id:
            return jsonify({"error": "Missing patient_id", "success": False}), 400
        
        # Call the main function
        return get_glucose_history()
        
    except Exception as e:
        print(f"❌ Error in legacy endpoint: {e}")
        return jsonify({"error": str(e), "success": False}), 500

# ================================================================
#        SIMPLE TEST ENDPOINT
# ================================================================
@glucose_bp.route('/test_glucose', methods=['GET'])
def test_glucose():
    """Test endpoint to verify glucose routes are working"""
    db = get_db()
    cursor = db.cursor(dictionary=True)
    
    try:
        # Get sample patient or create one
        cursor.execute("SELECT patient_id FROM patients LIMIT 1")
        patient = cursor.fetchone()
        
        if not patient:
            # Create a test patient
            cursor.execute("""
                INSERT INTO users (firebase_uid, email, full_name, role)
                VALUES (%s, %s, %s, %s)
            """, ("test_uid_123", "test@example.com", "Test Patient", "patient"))
            user_id = cursor.lastrowid
            
            cursor.execute("""
                INSERT INTO patients (user_id)
                VALUES (%s)
            """, (user_id,))
            patient_id = cursor.lastrowid
            
            db.commit()
            patient = {"patient_id": patient_id}
        
        cursor.execute("SELECT COUNT(*) as count FROM glucose_readings")
        count = cursor.fetchone()
        
        return jsonify({
            "success": True,
            "status": "Glucose routes are working",
            "sample_patient_id": patient["patient_id"] if patient else None,
            "total_glucose_readings": count["count"] if count else 0,
            "endpoints": {
                "add_glucose_reading": "POST /add_glucose_reading (with Firebase token or patient_id)",
                "get_glucose_history": "POST /get_glucose_history",
                "get_glucose_stats": "POST /get_glucose_stats",
                "legacy_add": "POST /add_glucose (for old Flutter app)",
                "legacy_get": "POST /get_glucose (for old Flutter app)"
            }
        }), 200
        
    except Exception as e:
        return jsonify({"error": str(e), "success": False}), 500
    finally:
        cursor.close()

# ================================================================
#        CREATE TEST PATIENT ENDPOINT
# ================================================================
@glucose_bp.route('/create_test_patient', methods=['POST', 'GET', 'OPTIONS'])
def create_test_patient():
    """Create a test patient for development"""
    if request.method == 'OPTIONS':
        return jsonify({"message": "CORS preflight"}), 200
    
    try:
        db = get_db()
        cursor = db.cursor(dictionary=True)
        
        # Generate unique firebase_uid for testing
        test_firebase_uid = f"test_uid_{uuid.uuid4().hex[:16]}"
        test_email = f"test_{uuid.uuid4().hex[:8]}@example.com"
        
        # Create user
        cursor.execute("""
            INSERT INTO users (firebase_uid, email, full_name, role)
            VALUES (%s, %s, %s, %s)
        """, (test_firebase_uid, test_email, "Test Patient", "patient"))
        user_id = cursor.lastrowid
        
        # Create patient
        cursor.execute("""
            INSERT INTO patients (user_id)
            VALUES (%s)
        """, (user_id,))
        patient_id = cursor.lastrowid
        
        db.commit()
        
        return jsonify({
            "success": True,
            "message": "Test patient created successfully",
            "patient_id": patient_id,
            "firebase_uid": test_firebase_uid,
            "email": test_email,
            "note": "Use this patient_id or firebase_uid for testing"
        }), 200
        
    except Exception as e:
        print(f"❌ Error creating test patient: {e}")
        return jsonify({"error": str(e), "success": False}), 500
    finally:
        cursor.close()

# ================================================================
#        DEBUG PATIENT INFO
# ================================================================
@glucose_bp.route('/debug_patient_info', methods=['GET'])
def debug_patient_info():
    """Debug endpoint to see all patients"""
    db = get_db()
    cursor = db.cursor(dictionary=True)
    
    try:
        cursor.execute("""
            SELECT p.patient_id, u.firebase_uid, u.email, u.full_name, 
                   COUNT(gr.glucose_id) as glucose_readings_count
            FROM patients p
            JOIN users u ON p.user_id = u.user_id
            LEFT JOIN glucose_readings gr ON p.patient_id = gr.patient_id
            GROUP BY p.patient_id
            ORDER BY p.patient_id
        """)
        
        patients = cursor.fetchall()
        
        result = []
        for p in patients:
            result.append({
                "patient_id": p["patient_id"],
                "firebase_uid": p["firebase_uid"],
                "email": p["email"],
                "full_name": p["full_name"],
                "glucose_readings_count": p["glucose_readings_count"]
            })
        
        return jsonify({
            "success": True,
            "total_patients": len(result),
            "patients": result
        }), 200
        
    except Exception as e:
        return jsonify({"error": str(e), "success": False}), 500
    finally:
        cursor.close()


@glucose_bp.route('/get_emergency_alerts', methods=['POST', 'OPTIONS'])
def get_emergency_alerts():
    """Return all emergency alerts for a doctor"""
    if request.method == 'OPTIONS':
        return jsonify({"message": "CORS preflight"}), 200

    try:
        data = request.get_json() or {}
        doctor_id = data.get('doctor_id')
        if not doctor_id:
            return jsonify({"error": "Missing doctor_id", "success": False}), 400

        db = get_db()
        cursor = db.cursor(dictionary=True)

        cursor.execute("""
            SELECT ea.alert_id, ea.patient_id, ea.glucose_reading_id, ea.alert_type,
                   ea.glucose_value, ea.alert_message, ea.severity, ea.sent_to_doctor_id,
                   p.patient_id, u.full_name as patient_name
            FROM emergency_alerts ea
            JOIN patients p ON ea.patient_id = p.patient_id
            JOIN users u ON p.user_id = u.user_id
            WHERE ea.sent_to_doctor_id = %s
            ORDER BY ea.created_at DESC
        """, (doctor_id,))

        alerts = cursor.fetchall()
        cursor.close()

        result = []
        for a in alerts:
            result.append({
                "alertId": a["alert_id"],
                "patientId": a["patient_id"],
                "patientName": a["patient_name"],
                "glucoseValue": float(a["glucose_value"]),
                "type": a["alert_type"],
                "message": a["alert_message"],
                "severity": a["severity"]
            })

        return jsonify({
            "success": True,
            "doctorId": doctor_id,
            "alerts": result,
            "count": len(result)
        }), 200

    except Exception as e:
        return jsonify({"error": str(e), "success": False}), 500
      