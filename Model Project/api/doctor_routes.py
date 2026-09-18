from flask import Blueprint, request, jsonify
from models.database import get_cursor, get_db

doctor_bp = Blueprint('doctor', __name__)

@doctor_bp.route('/doctors', methods=['GET'])
def get_doctors():
    try:
        cursor = get_cursor()
        cursor.execute("SELECT * FROM doctors")
        doctors = cursor.fetchall()
        cursor.close()
        return jsonify(doctors)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@doctor_bp.route('/doctor/<int:doctor_id>', methods=['GET'])
def get_doctor(doctor_id):
    try:
        cursor = get_cursor()
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
        return jsonify({"error": str(e)}), 500

@doctor_bp.route('/book_appointment', methods=['POST'])
def book_appointment():
    try:
        data = request.get_json()
        patient_id = data.get('patient_id')
        doctor_id = data.get('doctor_id')
        appointment_date = data.get('appointment_date')
        appointment_time = data.get('appointment_time')

        if not all([patient_id, doctor_id, appointment_date, appointment_time]):
            return jsonify({"error": "Missing data"}), 400

        cursor = get_cursor()
        cursor.execute("""
            INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time, status)
            VALUES (%s, %s, %s, %s, %s)
        """, (patient_id, doctor_id, appointment_date, appointment_time, "Pending"))
        get_db().commit()
        cursor.close()

        return jsonify({"message": "Appointment booked successfully!"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500