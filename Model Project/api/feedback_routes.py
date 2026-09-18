from flask import Blueprint, request, jsonify
from datetime import datetime
from models.database import get_cursor, get_db

feedback_bp = Blueprint('feedback', __name__)

# ✅ ADD FEEDBACK
@feedback_bp.route('/add_feedback', methods=['POST'])
def add_feedback():
    try:
        data = request.json
        patient_uid = data.get('patient_uid')
        feedback_text = data.get('feedback_text')

        if not patient_uid or not feedback_text:
            return jsonify({"error": "Missing patient_uid or feedback_text"}), 400

        cursor = get_cursor()
        query = "INSERT INTO feedback (patient_uid, feedback_text) VALUES (%s, %s)"
        cursor.execute(query, (patient_uid, feedback_text))
        get_db().commit()
        cursor.close()
        
        return jsonify({"message": "Feedback added successfully"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ✅ GET ALL FEEDBACK (FOR ADMIN)
@feedback_bp.route('/get_all_feedback', methods=['GET'])
def get_all_feedback():
    try:
        cursor = get_cursor()
        query = """
            SELECT id, patient_uid, feedback_text, reply_text, timestamp 
            FROM feedback 
            ORDER BY timestamp DESC
        """
        cursor.execute(query)
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

        cursor.close()
        return jsonify(feedback_list), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ✅ REPLY TO FEEDBACK (ADMIN)
@feedback_bp.route('/reply_feedback/<int:feedback_id>', methods=['POST'])
def reply_to_feedback(feedback_id):
    try:
        data = request.json
        reply_text = data.get('reply_text')
        
        if not reply_text:
            return jsonify({"error": "Reply text is required"}), 400

        cursor = get_cursor()
        now = datetime.now()
        query = "UPDATE feedback SET reply_text=%s, replied_at=%s WHERE id=%s"
        cursor.execute(query, (reply_text, now, feedback_id))
        get_db().commit()
        cursor.close()
        
        return jsonify({"message": "Reply sent successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ✅ GET FEEDBACK BY USER
@feedback_bp.route('/get_feedback_by_user/<string:patient_uid>', methods=['GET'])
def get_feedback_by_user(patient_uid):
    try:
        cursor = get_cursor()
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

        cursor.close()
        return jsonify(feedback_list), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ✅ SUBMIT FEEDBACK (FLUTTER)
@feedback_bp.route("/submit_feedback", methods=["POST"])
def submit_feedback_flutter():
    try:
        data = request.get_json()
        patient_uid = data.get("patient_uid")
        feedback_text = data.get("feedback_text")
        timestamp = data.get("timestamp") or datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        if not patient_uid or not feedback_text:
            return jsonify({"error": "Missing patient_uid or feedback_text"}), 400

        cursor = get_cursor()
        query = "INSERT INTO feedback (patient_uid, feedback_text, timestamp) VALUES (%s, %s, %s)"
        cursor.execute(query, (patient_uid, feedback_text, timestamp))
        get_db().commit()
        cursor.close()

        return jsonify({"status": "success"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ✅ UPDATE FEEDBACK
@feedback_bp.route('/update_feedback/<int:feedback_id>', methods=['POST'])
def update_feedback(feedback_id):
    try:
        data = request.get_json()
        feedback_text = data.get('feedback_text')

        if not feedback_text:
            return jsonify({'error': 'Feedback text required'}), 400

        cursor = get_cursor()
        cursor.execute(
            "UPDATE feedback SET feedback_text=%s, timestamp=%s WHERE id=%s",
            (feedback_text, datetime.now(), feedback_id)
        )
        get_db().commit()
        cursor.close()
        
        return jsonify({'message': 'Feedback updated successfully'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ✅ DELETE FEEDBACK
@feedback_bp.route('/delete_feedback/<int:feedback_id>', methods=['DELETE'])
def delete_feedback(feedback_id):
    try:
        cursor = get_cursor()
        cursor.execute("DELETE FROM feedback WHERE id=%s", (feedback_id,))
        get_db().commit()
        cursor.close()
        
        return jsonify({'message': 'Feedback deleted successfully'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500