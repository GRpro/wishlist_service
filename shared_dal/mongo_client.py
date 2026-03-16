import os
from pymongo import MongoClient

class MongoDBClient:
    def __init__(self):
        uri = os.getenv("MONGO_URI", "mongodb://localhost:27017")
        self.client = MongoClient(uri)
        self.db = self.client.wishlist_db

    def get_wishes_collection(self):
        return self.db.wishes

    def get_user_recommendations_collection(self):
        return self.db.user_recommendations