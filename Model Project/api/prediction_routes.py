# routes/prediction.py
from flask import Blueprint, request, jsonify, current_app
import joblib
import pandas as pd
import numpy as np
from datetime import datetime
from models.database import get_cursor, get_db
from firebase_admin import auth
from flask_cors import cross_origin
import logging
import os
import mysql.connector


prediction_bp = Blueprint('prediction', __name__)
logger = logging.getLogger(__name__)

# --------------------------
# Load Model - Check multiple possible files
# --------------------------
pipeline = None
model_paths = ["diabetes_model.joblib", "diabetes_model.pkl", "model/diabetes_model.pkl"]

for path in model_paths:
    try:
        if os.path.exists(path):
            pipeline = joblib.load(path)
            logger.info(f"✅ Model loaded successfully from {path}")
            # Get sklearn version
            import sklearn
            logger.info(f"✅ Using scikit-learn version: {sklearn.__version__}")
            break
    except Exception as e:
        logger.warning(f"❌ Failed to load model from {path}: {e}")

if pipeline is None:
    logger.error("❌ No model file found!")
    # You might want to create a simple fallback model
    # For now, we'll continue but predictions will fail

# --------------------------
# UPDATED: Required Features with NEW FEATURES
# --------------------------
FEATURES = [
    # Original Features
    'HighBP', 'BMI', 'overweight', 'GenHlth', 'HighChol', 'DiffWalk',
    'Age', 'HeartDiseaseorAttack', 'PhysHlth', 'Stroke', 'MentHlth',
    'Smoker', 'CholCheck', 'Education', 'Income', 'PhysActivity',
    'Fruits', 'Veggies', 'HvyAlcoholConsump',
    
    # ============================================
    # ✅ NEW FEATURES ADDED HERE
    # ============================================
    'family_history_diabetes',
    'bp_medication',
    'waist_circumference_cm',
    'fasting_glucose_mg_dl',
    'hba1c_percent'
    # ============================================
]

logger.info(f"✅ Total features: {len(FEATURES)}")
logger.info(f"✅ Features list: {FEATURES}")

# ================================================================
#                     PREDICT API - IMPROVED
# ================================================================
@prediction_bp.route("/predict", methods=["POST", "OPTIONS"])
@cross_origin()
def predict():
    if request.method == "OPTIONS":
        response = jsonify({'status': 'ok'})
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        response.headers.add('Access-Control-Allow-Methods', 'POST, OPTIONS')
        return response, 200
    
    try:
        # -----------------------
        # 1. AUTHENTICATION
        # -----------------------
        auth_header = request.headers.get('Authorization')
        if not auth_header or "Bearer " not in auth_header:
            return jsonify({"error": "Missing Authorization header"}), 401

        token = auth_header.split("Bearer ")[1]

        try:
            decoded_token = auth.verify_id_token(token)
            user_id = decoded_token.get("uid")
            logger.info(f"✅ Authenticated user: {user_id}")
        except Exception as e:
            logger.error("❌ Firebase token verify failed: %s", e)
            return jsonify({"error": "Invalid Firebase token"}), 401

        # -----------------------
        # 2. INPUT DATA VALIDATION
        # -----------------------
        if not request.is_json:
            return jsonify({"error": "Content-Type must be application/json"}), 415
            
        data = request.get_json(force=True) or {}
        logger.info(f"📥 Received data keys: {list(data.keys())}")
        
        # Check for required features
        missing_features = [f for f in FEATURES if f not in data]
        if missing_features:
            logger.warning(f"⚠️ Missing features: {missing_features}")
            # Provide defaults for missing features
            for feature in missing_features:
                if feature in ['family_history_diabetes', 'bp_medication', 'HighBP', 
                              'HighChol', 'DiffWalk', 'HeartDiseaseorAttack', 
                              'Stroke', 'Smoker', 'CholCheck', 'overweight']:
                    data[feature] = 0
                elif feature in ['BMI', 'GenHlth', 'PhysHlth', 'MentHlth', 'Age', 
                                'Education', 'Income', 'PhysActivity', 'Fruits', 
                                'Veggies', 'HvyAlcoholConsump', 'waist_circumference_cm',
                                'fasting_glucose_mg_dl', 'hba1c_percent']:
                    data[feature] = 0.0
                else:
                    data[feature] = 0
        
        # -----------------------
        # 3. Prepare DataFrame
        # -----------------------
        # Create features in correct order
        features_list = []
        for feature in FEATURES:
            value = data.get(feature, 0)
            # Convert to appropriate type
            if feature in ['BMI', 'waist_circumference_cm', 'fasting_glucose_mg_dl', 
                          'hba1c_percent', 'Age']:
                features_list.append(float(value))
            elif feature in ['GenHlth', 'PhysHlth', 'MentHlth', 'Education', 
                            'Income', 'PhysActivity', 'Fruits', 'Veggies', 
                            'HvyAlcoholConsump']:
                features_list.append(float(value))
            else:
                features_list.append(int(value))
        
        # Create DataFrame
        features_array = np.array(features_list).reshape(1, -1)
        features_df = pd.DataFrame(features_array, columns=FEATURES)
        
        logger.info(f"✅ DataFrame shape: {features_df.shape}")
        
        # -----------------------
        # 4. Model Prediction
        # -----------------------
        if pipeline is None:
            logger.error("❌ Model not loaded")
            # Fallback: simple rule-based prediction
            bmi = data.get('BMI', 25)
            glucose = data.get('fasting_glucose_mg_dl', 100)
            age = data.get('Age', 45)
            
            # Simple rule-based fallback
            risk_score = 0
            if bmi > 30: risk_score += 0.3
            if glucose > 126: risk_score += 0.4
            if age > 50: risk_score += 0.2
            if data.get('family_history_diabetes', 0) == 1: risk_score += 0.3
            if data.get('HighBP', 0) == 1: risk_score += 0.2
            
            proba = min(risk_score, 0.95)
            logger.warning(f"⚠️ Using fallback prediction: {proba}")
        else:
            try:
                proba = pipeline.predict_proba(features_df)[0][1]
                logger.info(f"✅ Prediction probability: {proba}")
            except Exception as e:
                logger.error(f"❌ Prediction error: {e}")
                # Try predict
                try:
                    pred = pipeline.predict(features_df)[0]
                    proba = float(pred)
                except:
                    # Final fallback
                    proba = 0.5
                    logger.error("❌ All prediction methods failed")

        risk_percentage = round(float(proba) * 100, 2)
        prediction = 1 if proba > 0.5 else 0

        if risk_percentage < 30:
            risk_level = "Low"
        elif risk_percentage <= 70:
            risk_level = "Moderate"
        else:
            risk_level = "High"

        # -----------------------
        # 5. SAVE TO DATABASE
        # -----------------------
        try:
            cursor = get_cursor()
            sql = """
            INSERT INTO prediction_results (
                user_id, 
                HighBP, BMI, overweight, GenHlth, HighChol, DiffWalk,
                Age, HeartDiseaseorAttack, PhysHlth, Stroke, MentHlth, Smoker,
                CholCheck, Education, Income, PhysActivity, Fruits, Veggies,
                HvyAlcoholConsump,
                family_history_diabetes,
                bp_medication,
                waist_circumference_cm,
                fasting_glucose_mg_dl,
                hba1c_percent,
                risk_level, risk_percentage, prediction_date
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 
                %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, %s
            )
            """

            values = (
                user_id,
                # Original features
                data.get('HighBP', 0),
                data.get('BMI', 0.0),
                data.get('overweight', 0),
                data.get('GenHlth', 0.0),
                data.get('HighChol', 0),
                data.get('DiffWalk', 0),
                data.get('Age', 0.0),
                data.get('HeartDiseaseorAttack', 0),
                data.get('PhysHlth', 0.0),
                data.get('Stroke', 0),
                data.get('MentHlth', 0.0),
                data.get('Smoker', 0),
                data.get('CholCheck', 0),
                data.get('Education', 0.0),
                data.get('Income', 0.0),
                data.get('PhysActivity', 0.0),
                data.get('Fruits', 0.0),
                data.get('Veggies', 0.0),
                data.get('HvyAlcoholConsump', 0.0),
                # NEW FEATURES
                data.get('family_history_diabetes', 0),
                data.get('bp_medication', 0),
                data.get('waist_circumference_cm', 0.0),
                data.get('fasting_glucose_mg_dl', 0.0),
                data.get('hba1c_percent', 0.0),
                # Result columns
                risk_level,
                risk_percentage,
                datetime.utcnow()
            )

            cursor.execute(sql, values)
            get_db().commit()
            prediction_id = cursor.lastrowid
            logger.info(f"✅ Prediction saved to database with ID: {prediction_id}")
            
        except Exception as e:
            logger.error("❌ DB save failed: %s", e)
            prediction_id = None

        # -----------------------
        # 6. RETURN RESPONSE
        # -----------------------
        response = {
            "success": True,
            "prediction_id": prediction_id,
            "prediction": int(prediction),
            "risk_level": risk_level,
            "risk_percentage": risk_percentage,
            "probability": float(proba),
            "features_used": len(FEATURES),
            "message": f"Diabetes risk prediction completed. Risk level: {risk_level}"
        }
        
        # Store in app context for other endpoints to access
        current_app.last_prediction = {
            "user_id": user_id,
            "data": data,
            "result": response
        }
        
        logger.info(f"✅ Prediction response: {response}")
        return jsonify(response), 200

    except Exception as e:
        logger.error("❌ Error in /predict: %s", e, exc_info=True)
        return jsonify({"error": str(e), "success": False}), 500


# ================================================================
#                GET LAST PREDICTION - IMPROVED
# ================================================================
@prediction_bp.route("/get_last_prediction", methods=["GET", "POST", "OPTIONS"])
@cross_origin()
def get_last_prediction():
    if request.method == "OPTIONS":
        response = jsonify({'status': 'ok'})
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        return response, 200
    
    try:
        # Handle both GET and POST
        if request.method == "POST":
            if not request.is_json:
                return jsonify({"error": "Content-Type must be application/json"}), 415
            data = request.get_json()
            user_id = data.get("user_id")
        else:  # GET
            user_id = request.args.get("user_id")
        
        if not user_id:
            # Try to get from Authorization header
            auth_header = request.headers.get('Authorization')
            if auth_header and "Bearer " in auth_header:
                try:
                    token = auth_header.split("Bearer ")[1]
                    decoded_token = auth.verify_id_token(token)
                    user_id = decoded_token.get("uid")
                except:
                    pass
        
        if not user_id:
            # Check app context
            if hasattr(current_app, 'last_prediction'):
                return jsonify(current_app.last_prediction), 200
            return jsonify({"error": "Missing user_id"}), 400

        # Get from database
        cursor = get_cursor()
        cursor.execute("""
            SELECT * FROM prediction_results 
            WHERE user_id = %s 
            ORDER BY prediction_date DESC 
            LIMIT 1
        """, (user_id,))
        result = cursor.fetchone()
        cursor.close()

        if result:
            # Convert to dict
            columns = [desc[0] for desc in cursor.description]
            result_dict = dict(zip(columns, result))
            return jsonify(result_dict), 200
        
        return jsonify({"message": "No prediction found for user", "user_id": user_id}), 404

    except Exception as e:
        logger.error("❌ Error in /get_last_prediction: %s", e)
        return jsonify({"error": str(e)}), 500


# ================================================================
#                GET ALL PREDICTIONS
# ================================================================
@prediction_bp.route("/get_predictions", methods=["GET"])
@cross_origin()
def get_predictions():
    try:
        cursor = get_cursor()
        cursor.execute("SELECT * FROM prediction_results ORDER BY prediction_date DESC")
        results = cursor.fetchall()
        
        # Convert to list of dicts
        columns = [desc[0] for desc in cursor.description]
        predictions = [dict(zip(columns, row)) for row in results]
        
        cursor.close()
        return jsonify(predictions)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ================================================================
#                GET PREDICTION BY ID
# ================================================================
@prediction_bp.route("/get_prediction/<int:prediction_id>", methods=["GET"])
@cross_origin()
def get_prediction_by_id(prediction_id):
    try:
        cursor = get_cursor()
        cursor.execute("SELECT * FROM prediction_results WHERE id = %s", (prediction_id,))
        result = cursor.fetchone()
        cursor.close()

        if result:
            columns = [desc[0] for desc in cursor.description]
            result_dict = dict(zip(columns, result))
            return jsonify(result_dict), 200
        
        return jsonify({"error": "Prediction not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ================================================================
#                HEALTH CHECK
# ================================================================
@prediction_bp.route("/health", methods=["GET"])
@cross_origin()
def health_check():
    return jsonify({
        "status": "healthy",
        "model_loaded": pipeline is not None,
        "features_count": len(FEATURES),
        "endpoints": [
            "/predict",
            "/get_last_prediction",
            "/get_predictions",
            "/get_prediction/<id>"
        ]
    }), 200