from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import pandas as pd
import mysql.connector
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, auth

# ✅ Initialize Firebase Admin SDK
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

# ✅ Load Model
try:
    pipeline = joblib.load("diabetes_model.joblib")
    print("✅ Model loaded successfully!")
except Exception as e:
    print("❌ Error loading model:", e)
    pipeline = None

# ✅ MySQL Connection
try:
    db = mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="diabetes_app"
    )
    cursor = db.cursor(dictionary=True)

    print("✅ Connected to MySQL successfully!")
except mysql.connector.Error as err:
    print(f"❌ Database connection error: {err}")
    db = None


@app.route("/")
def home():
    return "✅ DiabetesCare+ Flask API is running successfully!"


# ✅ PREDICT & SAVE TO DB
@app.route("/predict", methods=["POST"])
def predict():
    try:
        # ✅ Verify Firebase Token
        auth_header = request.headers.get('Authorization')
        if not auth_header or "Bearer " not in auth_header:
            return jsonify({"error": "Missing Authorization header"}), 401

        token = auth_header.split("Bearer ")[1]
        decoded_token = auth.verify_id_token(token)
        user_id = decoded_token["uid"]  # Firebase UID

        data = request.get_json()

        FEATURES = [
            'HighBP', 'BMI', 'overweight', 'GenHlth', 'HighChol', 'DiffWalk',
            'Age', 'HeartDiseaseorAttack', 'PhysHlth', 'Stroke', 'MentHlth',
            'Smoker', 'CholCheck', 'Education', 'Income', 'PhysActivity',
            'Fruits', 'Veggies', 'HvyAlcoholConsump'
        ]

        features = pd.DataFrame([{
            key: data.get(key, 0) for key in FEATURES
        }])

        # ✅ Run Prediction
        probability = float(pipeline.predict_proba(features[FEATURES])[0][1])
        risk_percentage = round(probability * 100, 2)
        prediction = int(probability > 0.5)

        if risk_percentage < 30:
            risk_level = "Low"
        elif 30 <= risk_percentage <= 70:
            risk_level = "Moderate"
        else:
            risk_level = "High"

        print(f"🧮 Probability: {risk_percentage}%, Risk Level: {risk_level}")

        # ✅ Insert into prediction_results table
        cursor = db.cursor()
        sql = """
        INSERT INTO prediction_results (
            user_id, HighBP, BMI, overweight, GenHlth, HighChol, DiffWalk, Age,
            HeartDiseaseorAttack, PhysHlth, Stroke, MentHlth, Smoker,
            CholCheck, Education, Income, PhysActivity, Fruits, Veggies,
            HvyAlcoholConsump, risk_level, risk_percentage, prediction_date
        ) VALUES (
            %(user_id)s, %(HighBP)s, %(BMI)s, %(overweight)s, %(GenHlth)s, %(HighChol)s, %(DiffWalk)s,
            %(Age)s, %(HeartDiseaseorAttack)s, %(PhysHlth)s, %(Stroke)s, %(MentHlth)s, %(Smoker)s,
            %(CholCheck)s, %(Education)s, %(Income)s, %(PhysActivity)s, %(Fruits)s, %(Veggies)s,
            %(HvyAlcoholConsump)s, %(risk_level)s, %(risk_percentage)s, %(prediction_date)s
        )
        """

        values = {
            "user_id": user_id,
            "HighBP": data.get("HighBP"),
            "BMI": data.get("BMI"),
            "overweight": data.get("overweight"),
            "GenHlth": data.get("GenHlth"),
            "HighChol": data.get("HighChol"),
            "DiffWalk": data.get("DiffWalk"),
            "Age": data.get("Age"),
            "HeartDiseaseorAttack": data.get("HeartDiseaseorAttack"),
            "PhysHlth": data.get("PhysHlth"),
            "Stroke": data.get("Stroke"),
            "MentHlth": data.get("MentHlth"),
            "Smoker": data.get("Smoker"),
            "CholCheck": data.get("CholCheck"),
            "Education": data.get("Education"),
            "Income": data.get("Income"),
            "PhysActivity": data.get("PhysActivity"),
            "Fruits": data.get("Fruits"),
            "Veggies": data.get("Veggies"),
            "HvyAlcoholConsump": data.get("HvyAlcoholConsump"),
            "risk_level": risk_level,
            "risk_percentage": risk_percentage,
            "prediction_date": datetime.now()
        }

        cursor.execute(sql, values)
        db.commit()
        cursor.close()

        return jsonify({
            "prediction": prediction,
            "risk_level": risk_level,
            "risk_percentage": risk_percentage
        }), 200

    except Exception as e:
        print("🔥 Error in /predict:", e)
        return jsonify({"error": str(e)}), 500


# ✅ GET ALL PREDICTIONS
@app.route("/get_predictions", methods=["GET"])
def get_predictions():
    try:
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM prediction_results ORDER BY prediction_date DESC")
        results = cursor.fetchall()
        cursor.close()
        return jsonify(results)
    except Exception as e:
        print("🔥 Error fetching predictions:", e)
        return jsonify({"error": str(e)}), 500


# ✅ GET LAST PREDICTION (Safely)
@app.route("/get_last_prediction", methods=["GET"])
def get_last_prediction():
    try:
        user_id = request.args.get("user_id")
        if not user_id:
            return jsonify({"error": "Missing user_id"}), 400

        cursor = db.cursor(dictionary=True)
        cursor.execute("""
            SELECT * FROM prediction_results 
            WHERE user_id = %s 
            ORDER BY prediction_date DESC 
            LIMIT 1
        """, (user_id,))
        result = cursor.fetchone()
        cursor.close()

        if result:
            return jsonify(result), 200
        else:
            return jsonify({"message": "No prediction found"}), 404
    except Exception as e:
        print("🔥 Error fetching last prediction:", e)
        return jsonify({"error": str(e)}), 500


# ✅ GET DOCTORS
@app.route('/doctors', methods=['GET'])
def get_doctors():
    try:
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM doctors")
        doctors = cursor.fetchall()
        cursor.close()
        return jsonify(doctors)
    except Exception as e:
        print("🔥 Error fetching doctors:", e)
        return jsonify({"error": str(e)}), 500


# ✅ GET DOCTOR DETAILS WITH SLOTS
@app.route('/doctor/<int:doctor_id>', methods=['GET'])
def get_doctor(doctor_id):
    try:
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM doctors WHERE doctor_id=%s", (doctor_id,))
        doctor = cursor.fetchone()

        if not doctor:
            return jsonify({"error": "Doctor not found"}), 404

        cursor.execute("""
            SELECT CONCAT(available_date, ' ', TIME_FORMAT(available_time, '%h:%i %p')) AS slot
            FROM doctor_availability
            WHERE doctor_id=%s
            ORDER BY available_date, available_time
        """, (doctor_id,))
        slots = [row["slot"] for row in cursor.fetchall()]
        cursor.close()

        return jsonify({
            "doctor": doctor,
            "availability_slots": slots
        })
    except Exception as e:
        print("🔥 Error fetching doctor:", e)
        return jsonify({"error": str(e)}), 500


# ✅ BOOK APPOINTMENT
@app.route('/book_appointment', methods=['POST'])
def book_appointment():
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        doctor_id = data.get('doctor_id')
        appointment_date = data.get('appointment_date')
        appointment_time = data.get('appointment_time')

        if not all([patient_id, doctor_id, appointment_date, appointment_time]):
            return jsonify({"error": "Missing data"}), 400

        cursor = db.cursor()
        cursor.execute("""
            INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time, status)
            VALUES (%s, %s, %s, %s, %s)
        """, (patient_id, doctor_id, appointment_date, appointment_time, "Pending"))
        db.commit()
        cursor.close()

        return jsonify({"message": "Appointment booked successfully!"})
    except Exception as e:
        print("🔥 Error booking appointment:", e)
        return jsonify({"error": str(e)}), 500


# ✅ LIFESTYLE PLAN
@app.route("/lifestyle_plan", methods=["POST"])
def get_lifestyle_plan():
    try:
        data = request.get_json()
        age = data.get("age")
        risk_level = data.get("risk_level")

        cursor = db.cursor(dictionary=True)

        # Determine age group
        if age < 31:
            age_group = "18-30"
        elif 31 <= age <= 50:
            age_group = "31-50"
        else:
            age_group = "51+"

        cursor.execute("""
            SELECT * FROM lifestyle_plan
            WHERE risk_level = %s AND age_group = %s
            LIMIT 1
        """, (risk_level, age_group))
        plan = cursor.fetchone()

        if not plan:
            cursor.close()
            return jsonify({"message": "No lifestyle plan found"}), 404

        plan_id = plan["plan_id"]

        cursor.execute("SELECT activity_name, duration, description FROM physical_activities WHERE plan_id = %s", (plan_id,))
        activities = cursor.fetchall()

        cursor.execute("SELECT meal_type, description FROM meal_plans WHERE plan_id = %s", (plan_id,))
        meals = cursor.fetchall()
        cursor.close()

        return jsonify({
            "plan_id": plan_id,
            "risk_level": plan["risk_level"],
            "age_group": plan["age_group"],
            "description": plan["description"],
            "physical_activities": activities,
            "meal_plans": meals
        }), 200
    except Exception as e:
        print("🔥 Error fetching lifestyle plan:", e)
        return jsonify({"error": str(e)}), 500


# ✅ API to Save Tracking Data
@app.route('/save_tracking', methods=['POST'])
def save_tracking():
    data = request.json

    patient_name = data.get("patient_name")
    task = data.get("task")
    date = data.get("date")[:10]  # Extract only YYYY-MM-DD
    status = data.get("status")

    sql = """
        INSERT INTO lifestyle_tracking (patient_name, task, date, status)
        VALUES (%s, %s, %s, %s)
    """
    val = (patient_name, task, date, status)
    cursor.execute(sql, val)
    db.commit()

    return jsonify({"message": "Task saved successfully"}), 200


# ✅ API to Fetch Weekly / Monthly Analytics
@app.route('/lifestyle_analytics', methods=['POST'])
def lifestyle_analytics():
    data = request.json
    patient_name = data.get("patient_name")

    # ✅ Weekly Count
    cursor.execute("""
        SELECT 
            SUM(status = 'done') AS done,
            COUNT(*) AS total
        FROM lifestyle_tracking
        WHERE patient_name=%s 
          AND YEARWEEK(date) = YEARWEEK(NOW())
    """, (patient_name,))
    
    weekly = cursor.fetchone()

    # ✅ Monthly Count
    cursor.execute("""
        SELECT 
            SUM(status = 'done') AS done,
            COUNT(*) AS total
        FROM lifestyle_tracking
        WHERE patient_name=%s
          AND MONTH(date) = MONTH(NOW())
    """, (patient_name,))
    
    monthly = cursor.fetchone()

    return jsonify({
        "weekly_done": weekly["done"] or 0,
        "weekly_total": weekly["total"] or 0,
        "monthly_done": monthly["done"] or 0,
        "monthly_total": monthly["total"] or 0
    })
@app.route("/get_tracking", methods=["GET"])
def get_tracking():
    patient_name = request.args.get("patient_name")
    cursor = db.cursor(dictionary=True)

    # Weekly progress (last 7 days)
    cursor.execute("""
        SELECT task, 
               SUM(CASE WHEN status='done' THEN 1 ELSE 0 END) as weekly_done,
               COUNT(*) as weekly_target
        FROM lifestyle_tracking
        WHERE patient_name=%s AND date >= CURDATE() - INTERVAL 7 DAY
        GROUP BY task
    """, (patient_name,))
    weekly_data = cursor.fetchall()

    # Monthly progress (last 30 days)
    cursor.execute("""
        SELECT task, 
               SUM(CASE WHEN status='done' THEN 1 ELSE 0 END) as monthly_done,
               COUNT(*) as monthly_target
        FROM lifestyle_tracking
        WHERE patient_name=%s AND date >= CURDATE() - INTERVAL 30 DAY
        GROUP BY task
    """, (patient_name,))
    monthly_data = cursor.fetchall()

    # Combine into a single list
    tasks = {}
    for row in weekly_data:
        tasks[row['task']] = {
            "task": row['task'],
            "weekly_done": row['weekly_done'],
            "weekly_target": row['weekly_target'],
            "monthly_done": 0,
            "monthly_target": 0
        }

    for row in monthly_data:
        if row['task'] in tasks:
            tasks[row['task']]['monthly_done'] = row['monthly_done']
            tasks[row['task']]['monthly_target'] = row['monthly_target']
        else:
            tasks[row['task']] = {
                "task": row['task'],
                "weekly_done": 0,
                "weekly_target": 0,
                "monthly_done": row['monthly_done'],
                "monthly_target": row['monthly_target']
            }

    return jsonify(list(tasks.values()))

# ================== manage lifestyle template ==================

# ================== LIFESTYLE PLAN ==================
@app.route("/lifestyle_plan", methods=["GET"])
def get_plans():
    cursor.execute("SELECT * FROM lifestyle_plan")
    plans = cursor.fetchall()
    return jsonify(plans)

@app.route("/lifestyle_plan/<int:plan_id>", methods=["GET"])
def get_plan(plan_id):
    cursor.execute("SELECT * FROM lifestyle_plan WHERE plan_id=%s", (plan_id,))
    plan = cursor.fetchone()
    return jsonify(plan)

@app.route("/lifestyle_plan", methods=["POST"])
def add_plan():
    data = request.json
    cursor.execute(
        "INSERT INTO lifestyle_plan (risk_level, age_group, description) VALUES (%s,%s,%s)",
        (data['risk_level'], data['age_group'], data['description'])
    )
    db.commit()
    return jsonify({"message": "Plan added successfully"}), 201

@app.route("/lifestyle_plan/<int:plan_id>", methods=["PUT"])
def update_plan(plan_id):
    data = request.json
    cursor.execute(
        "UPDATE lifestyle_plan SET risk_level=%s, age_group=%s, description=%s WHERE plan_id=%s",
        (data['risk_level'], data['age_group'], data['description'], plan_id)
    )
    db.commit()
    return jsonify({"message": "Plan updated successfully"})

@app.route("/lifestyle_plan/<int:plan_id>", methods=["DELETE"])
def delete_plan(plan_id):
    cursor.execute("DELETE FROM lifestyle_plan WHERE plan_id=%s", (plan_id,))
    db.commit()
    return jsonify({"message": "Plan deleted successfully"})

# ================== MEAL PLANS ==================
@app.route("/meal_plans/<int:plan_id>", methods=["GET"])
def get_meals(plan_id):
    cursor.execute("SELECT * FROM meal_plans WHERE plan_id=%s", (plan_id,))
    meals = cursor.fetchall()
    return jsonify(meals)

@app.route("/meal_plans", methods=["POST"])
def add_meal():
    data = request.json
    cursor.execute(
        "INSERT INTO meal_plans (plan_id, meal_type, description) VALUES (%s,%s,%s)",
        (data['plan_id'], data['meal_type'], data['description'])
    )
    db.commit()
    return jsonify({"message": "Meal added successfully"}), 201

@app.route("/meal_plans/<int:meal_id>", methods=["PUT"])
def update_meal(meal_id):
    data = request.json
    cursor.execute(
        "UPDATE meal_plans SET meal_type=%s, description=%s WHERE meal_id=%s",
        (data['meal_type'], data['description'], meal_id)
    )
    db.commit()
    return jsonify({"message": "Meal updated successfully"})

@app.route("/meal_plans/<int:meal_id>", methods=["DELETE"])
def delete_meal(meal_id):
    cursor.execute("DELETE FROM meal_plans WHERE meal_id=%s", (meal_id,))
    db.commit()
    return jsonify({"message": "Meal deleted successfully"})

# ================== PHYSICAL ACTIVITIES ==================
@app.route("/activities/<int:plan_id>", methods=["GET"])
def get_activities(plan_id):
    cursor.execute("SELECT * FROM physical_activities WHERE plan_id=%s", (plan_id,))
    activities = cursor.fetchall()
    return jsonify(activities)

@app.route("/activities", methods=["POST"])
def add_activity():
    data = request.json
    cursor.execute(
        "INSERT INTO physical_activities (plan_id, activity_name, duration, description) VALUES (%s,%s,%s,%s)",
        (data['plan_id'], data['activity_name'], data['duration'], data['description'])
    )
    db.commit()
    return jsonify({"message": "Activity added successfully"}), 201

@app.route("/activities/<int:activity_id>", methods=["PUT"])
def update_activity(activity_id):
    data = request.json
    cursor.execute(
        "UPDATE physical_activities SET activity_name=%s, duration=%s, description=%s WHERE activity_id=%s",
        (data['activity_name'], data['duration'], data['description'], activity_id)
    )
    db.commit()
    return jsonify({"message": "Activity updated successfully"})

@app.route("/activities/<int:activity_id>", methods=["DELETE"])
def delete_activity(activity_id):
    cursor.execute("DELETE FROM physical_activities WHERE activity_id=%s", (activity_id,))
    db.commit()
    return jsonify({"message": "Activity deleted successfully"})



#  add feedback
@app.route('/add_feedback', methods=['POST'])
def add_feedback():
    data = request.json
    patient_uid = data.get('patient_uid')
    feedback_text = data.get('feedback_text')

    if not patient_uid or not feedback_text:
        return jsonify({"error": "Missing patient_uid or feedback_text"}), 400

    query = "INSERT INTO feedback (patient_uid, feedback_text) VALUES (%s, %s)"
    cursor.execute(query, (patient_uid, feedback_text))
    db.commit()
    return jsonify({"message": "Feedback added successfully"}), 201

# 2️⃣ Get all feedback (for admin)
@app.route('/get_all_feedback', methods=['GET'])
def get_all_feedback():
    query = "SELECT id, patient_uid, feedback_text, reply_text, timestamp FROM feedback ORDER BY timestamp DESC"
    cursor.execute(query)
    results = cursor.fetchall()  # this is a list of dicts

    feedback_list = []
    for row in results:
        feedback_list.append({
            "id": row['id'],  # ✅ use keys instead of indices
            "patient_uid": row['patient_uid'],
            "feedback_text": row['feedback_text'],
            "reply_text": row['reply_text'] if row['reply_text'] else "",
            "timestamp": row['timestamp'].strftime("%Y-%m-%d %H:%M:%S")
        })

    return jsonify(feedback_list), 200


# 3️⃣ Reply to feedback (admin)
@app.route('/reply_feedback/<int:feedback_id>', methods=['POST'])
def reply_to_feedback(feedback_id):
    data = request.json
    reply_text = data.get('reply_text')
    if not reply_text:
        return jsonify({"error": "Reply text is required"}), 400

    now = datetime.now()
    query = "UPDATE feedback SET reply_text=%s, replied_at=%s WHERE id=%s"
    cursor.execute(query, (reply_text, now, feedback_id))
    db.commit()
    return jsonify({"message": "Reply sent successfully"}), 200

@app.route('/get_feedback_by_user/<string:patient_uid>', methods=['GET'])
def get_feedback_by_user(patient_uid):
    cursor = db.cursor(dictionary=True)
    query = """
        SELECT id, patient_uid, feedback_text, reply_text, timestamp 
        FROM feedback 
        WHERE patient_uid=%s 
        ORDER BY timestamp DESC
    """
    cursor.execute(query, (patient_uid,))
    results = cursor.fetchall()
    
    feedback_list = []
    for row in results:
        feedback_list.append({
            "id": row['id'],
            "patient_uid": row['patient_uid'],
            "feedback_text": row['feedback_text'],
            "reply_text": row['reply_text'] if row['reply_text'] else "",
            "timestamp": row['timestamp'].strftime("%Y-%m-%d %H:%M:%S")
        })

    return jsonify(feedback_list), 200


# 5️⃣ Submit feedback (called by Flutter)
@app.route("/submit_feedback", methods=["POST"])
def submit_feedback_flutter():
    data = request.get_json()
    patient_uid = data.get("patient_uid")
    feedback_text = data.get("feedback_text")
    timestamp = data.get("timestamp") or datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    if not patient_uid or not feedback_text:
        return jsonify({"error": "Missing patient_uid or feedback_text"}), 400

    query = "INSERT INTO feedback (patient_uid, feedback_text, timestamp) VALUES (%s, %s, %s)"
    cursor.execute(query, (patient_uid, feedback_text, timestamp))
    db.commit()

    return jsonify({"status": "success"}), 200
   
   # -------------------------------
# Update feedback
# -------------------------------
@app.route('/update_feedback/<int:feedback_id>', methods=['POST'])
def update_feedback(feedback_id):
    data = request.get_json()
    feedback_text = data.get('feedback_text')

    if not feedback_text:
        return jsonify({'error': 'Feedback text required'}), 400

    try:
        cursor.execute(
            "UPDATE feedback SET feedback_text=%s, timestamp=%s WHERE id=%s",
            (feedback_text, datetime.now(), feedback_id)
        )
        db.commit()
        return jsonify({'message': 'Feedback updated successfully'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# -------------------------------
# Delete feedback
# -------------------------------
@app.route('/delete_feedback/<int:feedback_id>', methods=['DELETE'])
def delete_feedback(feedback_id):
    try:
        cursor.execute("DELETE FROM feedback WHERE id=%s", (feedback_id,))
        db.commit()
        return jsonify({'message': 'Feedback deleted successfully'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/add_medicine', methods=['POST'])
def add_medicine():
    patient_id = request.form['patient_id']
    med_name = request.form['med_name']
    med_time = request.form['med_time']

    cur = mysql.connection.cursor()
    cur.execute("INSERT INTO medication (patient_id, med_name, med_time, status) VALUES (%s, %s, %s, %s)",
                (patient_id, med_name, med_time, "Pending"))
    mysql.connection.commit()
    cur.close()
    return "success"
    

@app.route('/get_medicines', methods=['POST'])
def get_medicines():
    patient_id = request.form['patient_id']
    cur = mysql.connection.cursor()
    cur.execute("SELECT * FROM medication WHERE patient_id=%s", (patient_id,))
    result = cur.fetchall()
    meds = []

    for row in result:
        meds.append({
            "med_id": row[0],
            "patient_id": row[1],
            "med_name": row[2],
            "med_time": row[3],
            "status": row[4]
        })

    cur.close()
    return jsonify(meds)


@app.route('/mark_taken', methods=['POST'])
def mark_taken():
    med_id = request.form['med_id']
    cur = mysql.connection.cursor()
    cur.execute("UPDATE medication SET status='Taken' WHERE med_id=%s", (med_id,))
    mysql.connection.commit()
    cur.close()
    return "updated"


@app.route('/delete_medicine', methods=['POST'])
def delete_medicine():
    med_id = request.form['med_id']
    cur = mysql.connection.cursor()
    cur.execute("DELETE FROM medication WHERE med_id=%s", (med_id,))
    mysql.connection.commit()
    cur.close()
    return "deleted"

@app.route('/add_glucose', methods=['POST'])
def add_glucose():
    patient_id = request.form['patient_id']
    glucose = request.form['glucose']

    cur = mysql.connection.cursor()
    cur.execute(
        "INSERT INTO glucose (patient_id, glucose, g_date, g_time) VALUES (%s, %s, CURDATE(), CURTIME())",
        (patient_id, glucose)
    )
    mysql.connection.commit()
    cur.close()
    return "success"


@app.route('/get_glucose', methods=['POST'])
def get_glucose():
    patient_id = request.form['patient_id']
    cur = mysql.connection.cursor()
    cur.execute("SELECT * FROM glucose WHERE patient_id=%s", (patient_id,))
    rows = cur.fetchall()

    data = []
    for r in rows:
        data.append({
            "g_id": r[0],
            "patient_id": r[1],
            "glucose": r[2],
            "g_date": str(r[3]),
            "g_time": str(r[4])
        })

    cur.close()
    return jsonify(data)


@app.route('/delete_glucose', methods=['POST'])
def delete_glucose():
    g_id = request.form['g_id']
    cur = mysql.connection.cursor()
    cur.execute("DELETE FROM glucose WHERE g_id=%s", (g_id,))
    mysql.connection.commit()
    cur.close()
    return "deleted"


# ✅ RUN SERVER
if __name__ == "__main__":
    print("🚀 Flask server running on http://0.0.0.0:5000")
    app.run(host="0.0.0.0", port=5000, debug=True)
