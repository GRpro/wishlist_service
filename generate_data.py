import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import random
import logging
from faker import Faker
from typing import List, Dict

from shared_dal.mongo_client import MongoDBClient
from shared_dal.neo4j_client import Neo4jClient
from shared_dal.redis_client import RedisCache

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
fake = Faker('uk_UA')

NUM_USERS = 1000
NUM_UNIQUE_ITEMS = 500
TOTAL_WISHES = 10000

def generate_test_data():
    mongo = MongoDBClient()
    neo4j = Neo4jClient()
    redis = RedisCache()

    logging.info("Очищення старих даних...")
    mongo.get_wishes_collection().delete_many({})
    mongo.get_user_recommendations_collection().delete_many({})
    redis.client.flushdb()
    neo4j.execute_write("MATCH (n) DETACH DELETE n")

    logging.info(f"Генерація пулу з {NUM_UNIQUE_ITEMS} унікальних товарів...")
    items_pool = []
    tags_pool = ["техніка", "книги", "одяг", "спорт", "ігри", "подорожі", "дім"]
    
    for _ in range(NUM_UNIQUE_ITEMS):
        items_pool.append({
            "url": fake.url() + f"?item={random.randint(1000, 9999)}",
            "title": fake.catch_phrase(),
            "tags": random.sample(tags_pool, k=random.randint(1, 3))
        })

    logging.info(f"Генерація {NUM_USERS} користувачів...")
    users_pool = [fake.uuid4() for _ in range(NUM_USERS)]

    logging.info(f"Розподіл {TOTAL_WISHES} бажань між користувачами...")
    mongo_wishes_batch = []
    neo4j_relationships_batch = []
    
    user_wishes_map = {u: set() for u in users_pool}
    
    while len(mongo_wishes_batch) < TOTAL_WISHES:
        user_id = random.choice(users_pool)
        item = random.choice(items_pool)
        
        if item["url"] not in user_wishes_map[user_id]:
            user_wishes_map[user_id].add(item["url"])
            
            mongo_wishes_batch.append({
                "user_id": user_id,
                "title": item["title"],
                "url": item["url"],
                "tags": item["tags"]
            })
            
            neo4j_relationships_batch.append({
                "user_id": user_id,
                "url": item["url"],
                "title": item["title"]
            })
    
    logging.info("Запис у MongoDB...")
    mongo.get_wishes_collection().insert_many(mongo_wishes_batch)
    
    logging.info("Запис у Neo4j (це може зайняти кілька секунд)...")
    cypher_batch_query = """
    UNWIND $batch AS row
    MERGE (u:User {id: row.user_id})
    MERGE (w:Wish {url: row.url})
    ON CREATE SET w.title = row.title
    MERGE (u)-[:HAS]->(w)
    """
    neo4j.execute_write(cypher_batch_query, {"batch": neo4j_relationships_batch})

    logging.info("✅ Генерація успішно завершена!")
    logging.info(f"Створено юзерів: {NUM_USERS}, Унікальних бажань: {NUM_UNIQUE_ITEMS}, Всього зв'язків: {TOTAL_WISHES}")
    
    random_users = random.sample(users_pool, 10)
    logging.info("Для тестування використовуйте один з наступних User ID:")
    for uid in random_users:
        print(uid)

if __name__ == "__main__":
    generate_test_data()
