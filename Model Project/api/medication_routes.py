from flask import Blueprint, request, jsonify
from datetime import datetime
from models.database import get_cursor, get_db

medication_bp = Blueprint('medication', __name__)

@medication_bp.route('/add_medicine', methods=['POST'])
def add_medicine():
    try:
        patient_id = request.form['patient_id']
        med_name = request.form['med_name']
        med_time = request.form['med_time']
        med_dosage = request.form.get('med_dosage', '')
        frequency = request.form.get('frequency', 'Daily')

        cursor = get_cursor()
        cursor.execute("""
            INSERT INTO medication (patient_id, med_name, med_dosage, med_time, frequency, status) 
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (patient_id, med_name, med_dosage, med_time, frequency, "Pending"))
        get_db().commit()
        cursor.close()
        
        return jsonify({"message": "success"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@medication_bp.route('/get_medicines', methods=['POST'])
def get_medicines():
    try:
        patient_id = request.form['patient_id']
        cursor = get_cursor()
        cursor.execute("""
            SELECT * FROM medication 
            WHERE patient_id=%s 
            ORDER BY 
                CASE status 
                    WHEN 'Pending' THEN 1 
                    WHEN 'Taken' THEN 2 
                END,
                med_time
        """, (patient_id,))
        result = cursor.fetchall()
        meds = []

        for row in result:
            meds.append({
                "med_id": row["med_id"],
                "patient_id": row["patient_id"],
                "med_name": row["med_name"],
                "med_dosage": row["med_dosage"],
                "med_time": str(row["med_time"]),
                "frequency": row["frequency"],
                "status": row["status"],
                "taken_at": row["taken_at"].isoformat() if row["taken_at"] else None
            })

        cursor.close()
        return jsonify(meds)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@medication_bp.route('/mark_taken', methods=['POST'])
def mark_taken():
    try:
        med_id = request.form['med_id']
        cursor = get_cursor()
        
        # Update medication status
        cursor.execute("""
            UPDATE medication 
            SET status='Taken', taken_at=%s 
            WHERE med_id=%s
        """, (datetime.now(), med_id))
        
        # Add to history
        cursor.execute("""
            INSERT INTO medication_history (med_id, patient_id, med_name, med_time, taken_at)
            SELECT med_id, patient_id, med_name, med_time, %s
            FROM medication WHERE med_id=%s
        """, (datetime.now(), med_id))
        
        get_db().commit()
        cursor.close()
        return jsonify({"message": "updated"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@medication_bp.route('/get_taken_history', methods=['POST'])
def get_taken_history():
    try:
        patient_id = request.form['patient_id']
        cursor = get_cursor()
        cursor.execute("""
            SELECT mh.*, m.med_dosage, m.frequency 
            FROM medication_history mh
            LEFT JOIN medication m ON mh.med_id = m.med_id
            WHERE mh.patient_id=%s 
            ORDER BY mh.taken_at DESC
            LIMIT 50
        """, (patient_id,))
        result = cursor.fetchall()
        history = []

        for row in result:
            history.append({
                "history_id": row["history_id"],
                "med_id": row["med_id"],
                "patient_id": row["patient_id"],
                "med_name": row["med_name"],
                "med_dosage": row["med_dosage"],
                "med_time": str(row["med_time"]),
                "frequency": row["frequency"],
                "taken_at": row["taken_at"].isoformat() if row["taken_at"] else None
            })

        cursor.close()
        return jsonify(history)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@medication_bp.route('/delete_medicine', methods=['POST'])
def delete_medicine():
    try:
        med_id = request.form['med_id']
        cursor = get_cursor()
        
        # Delete from history first
        cursor.execute("DELETE FROM medication_history WHERE med_id=%s", (med_id,))
        
        # Delete from medications
        cursor.execute("DELETE FROM medication WHERE med_id=%s", (med_id,))
        
        get_db().commit()
        cursor.close()
        return jsonify({"message": "deleted"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@medication_bp.route('/get_today_medications', methods=['POST'])
def get_today_medications():
    try:
        patient_id = request.form['patient_id']
        today = datetime.now().date()
        cursor = get_cursor()
        
        cursor.execute("""
            SELECT * FROM medication 
            WHERE patient_id=%s AND status='Pending'
            ORDER BY med_time
        """, (patient_id,))
        
        result = cursor.fetchall()
        meds = []

        for row in result:
            meds.append({
                "med_id": row["med_id"],
                "med_name": row["med_name"],
                "med_dosage": row["med_dosage"],
                "med_time": str(row["med_time"]),
                "frequency": row["frequency"]
            })

        cursor.close()
        return jsonify(meds)
    except Exception as e:
        return jsonify({"error": str(e)}), 500