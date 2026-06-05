from flask import Flask, jsonify, request
import uuid
import os

app = Flask(__name__)

# in-memory storage — DynamoDB wchodzi w Sprint 2
payments = {}

@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "version": os.getenv("APP_VERSION", "0.1.0")
    })

@app.route("/payments", methods=["POST"])
def create_payment():
    payment_id = str(uuid.uuid4())
    payments[payment_id] = {
        "id": payment_id,
        "status": "created"
    }
    return jsonify(payments[payment_id]), 201

@app.route("/payments/<payment_id>")
def get_payment(payment_id):
    payment = payments.get(payment_id)
    if not payment:
        return jsonify({"error": "not found"}), 404
    return jsonify(payment)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
