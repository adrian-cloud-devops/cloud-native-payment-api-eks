from flask import Flask, jsonify, request
import boto3
import uuid
import os

app = Flask(__name__)

# DynamoDB client — credentials przez IRSA automatycznie
dynamodb = boto3.resource(
    "dynamodb",
    region_name=os.getenv("AWS_REGION", "eu-central-1")
)
table = dynamodb.Table(os.getenv("DYNAMODB_TABLE", "payment-api-payments"))


@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "version": os.getenv("APP_VERSION", "unknown")
    })


@app.route("/payments", methods=["POST"])
def create_payment():
    payment_id = str(uuid.uuid4())
    item = {
        "payment_id": payment_id,
        "status": "created"
    }
    table.put_item(Item=item)
    return jsonify(item), 201


@app.route("/payments/<payment_id>")
def get_payment(payment_id):
    response = table.get_item(
        Key={"payment_id": payment_id}
    )
    item = response.get("Item")
    if not item:
        return jsonify({"error": "not found"}), 404
    return jsonify(item)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)