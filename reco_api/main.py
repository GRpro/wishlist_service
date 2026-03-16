from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
from datetime import datetime
import logging

from shared_dal.mongo_client import MongoDBClient
from shared_dal.redis_client import RedisCache
from shared_dal.neo4j_client import Neo4jClient

app = FastAPI(title="Recommendation Gateway Service", version="1.0.0")

mongo = MongoDBClient()
redis_cache = RedisCache()
neo4j_graph = Neo4jClient()

class RecommendationItem(BaseModel):
    url: str
    title: str
    tags: List[str]
    score: float # Метрика релевантності

@app.get("/v1/recommendations/{user_id}", response_model=List[RecommendationItem])
def get_recommendations(user_id: str):
    """
    Агрегуючий ендпоінт.
    1. Перевіряє Redis (Швидкий кеш).
    2. Якщо пусто - запускає алгоритм Jaccard у Neo4j.
    3. Збагачує результати даними з MongoDB.
    4. Зберігає знімок (snapshot) у Mongo та оновлює Redis.
    """
    cache_key = f"reco:{user_id}"

    cached_reco = redis_cache.get_json(cache_key)
    if cached_reco:
        logging.info(f"Cache HIT for recommendations: User {user_id}")
        return cached_reco

    logging.info(f"Cache MISS. Calculating Jaccard Collaborative Filtering for User {user_id}...")

    # Обчислення Collaborative Filtering (Jaccard) у Neo4j
    cypher_query = """
    // 1. Знаходимо користувачів, які мають спільні бажання з нашим юзером (u1)
    MATCH (u1:User {id: $user_id})-[:HAS]->(w:Wish)<-[:HAS]-(u2:User)
    WITH u1, u2, COUNT(w) AS intersection
    
    // 2. Рахуємо загальну кількість бажань у нашого юзера
    MATCH (u1)-[:HAS]->(w1:Wish)
    WITH u1, u2, intersection, COUNT(w1) AS u1_wishes
    
    // 3. Рахуємо загальну кількість бажань у "сусіда" (u2)
    MATCH (u2)-[:HAS]->(w2:Wish)
    WITH u1, u2, intersection, u1_wishes, COUNT(w2) AS u2_wishes
    
    // 4. Обчислюємо Jaccard Index
    WITH u1, u2, toFloat(intersection) / (u1_wishes + u2_wishes - intersection) AS jaccard_index
    
    // 5. Знаходимо товари "сусіда", яких ЩЕ НЕМАЄ у нашого юзера
    MATCH (u2)-[:HAS]->(reco_wish:Wish)
    WHERE NOT (u1)-[:HAS]->(reco_wish)
    
    // 6. Групуємо, сумуємо скор (якщо товар рекомендують кілька сусідів) і сортуємо
    RETURN reco_wish.url AS url, SUM(jaccard_index) AS final_score
    ORDER BY final_score DESC
    LIMIT 10
    """
    
    neo4j_results = neo4j_graph.execute_read(cypher_query, {"user_id": user_id})
    
    if not neo4j_results:
        return []

    recommended_urls = [record["url"] for record in neo4j_results]
    score_map = {record["url"]: record["final_score"] for record in neo4j_results}

    wishes_col = mongo.get_wishes_collection()
    
    mongo_docs = list(wishes_col.find({"url": {"$in": recommended_urls}}))
    
    unique_wishes = {}
    for doc in mongo_docs:
        if doc["url"] not in unique_wishes:
            unique_wishes[doc["url"]] = doc

    final_recommendations = []
    for url in recommended_urls:
        if url in unique_wishes:
            doc = unique_wishes[url]
            final_recommendations.append({
                "url": url,
                "title": doc.get("title", "Без назви"),
                "tags": doc.get("tags", []),
                "score": round(score_map[url], 3)
            })

    snapshot = {
        "user_id": user_id,
        "recommendations": final_recommendations,
        "calculated_at": datetime.utcnow()
    }
    mongo.get_user_recommendations_collection().update_one(
        {"user_id": user_id}, 
        {"$set": snapshot}, 
        upsert=True
    )

    redis_cache.set_json(cache_key, final_recommendations, ttl_seconds=3600)

    logging.info(f"Successfully generated and cached {len(final_recommendations)} recommendations.")
    return final_recommendations