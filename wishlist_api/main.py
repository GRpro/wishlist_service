from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional
from bson import ObjectId
import logging

from shared_dal.mongo_client import MongoDBClient
from shared_dal.redis_client import RedisCache
from shared_dal.neo4j_client import Neo4jClient

app = FastAPI(title="Wishlist Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

mongo = MongoDBClient()
redis_cache = RedisCache()
neo4j_graph = Neo4jClient()

def serialize_doc(doc):
    if "_id" in doc:
        doc["id"] = str(doc.pop("_id"))
    return doc

class WishRequest(BaseModel):
    title: str = Field(..., description="Назва бажання")
    url: str = Field(..., description="Посилання на товар/послугу")
    tags: Optional[List[str]] = []

class WishResponse(WishRequest):
    id: str
    user_id: str

@app.post("/v1/wishes", response_model=WishResponse)
def create_wish(user_id: str, wish: WishRequest):
    """
    1. Записує бажання в MongoDB.
    2. Створює зв'язок у графі Neo4j для майбутніх рекомендацій.
    3. Інвалідує кеш Redis.
    """
    wish_dict = wish.model_dump()
    wish_dict["user_id"] = user_id
    
    wishes_col = mongo.get_wishes_collection()
    result = wishes_col.insert_one(wish_dict)
    wish_dict["_id"] = result.inserted_id

    cypher_query = """
    MERGE (u:User {id: $user_id})
    MERGE (w:Wish {url: $url})
    ON CREATE SET w.title = $title
    MERGE (u)-[:HAS]->(w)
    """
    neo4j_graph.execute_write(
        cypher_query, 
        {"user_id": user_id, "url": wish.url, "title": wish.title}
    )

    redis_cache.invalidate(f"wl:{user_id}")
    redis_cache.invalidate(f"reco:{user_id}")

    return serialize_doc(wish_dict)


@app.get("/v1/wishlist", response_model=List[WishResponse])
def get_wishlist(user_id: str):
    """
    Отримує вішліст. Спочатку перевіряє Redis (кеш). 
    Якщо там пусто — йде в MongoDB і оновлює кеш.
    """
    cache_key = f"wl:{user_id}"
    
    cached_data = redis_cache.get_json(cache_key)
    if cached_data:
        logging.info(f"Cache HIT for user {user_id}")
        return cached_data

    logging.info(f"Cache MISS for user {user_id}. Fetching from MongoDB.")
    wishes_col = mongo.get_wishes_collection()
    cursor = wishes_col.find({"user_id": user_id})
    
    wishes_list = [serialize_doc(doc) for doc in cursor]

    redis_cache.set_json(cache_key, wishes_list, ttl_seconds=3600)

    return wishes_list


@app.delete("/v1/wishes/{wish_id}")
def delete_wish(user_id: str, wish_id: str):
    """
    Видаляє бажання з MongoDB, прибирає зв'язок з графа та чистить кеш.
    """
    wishes_col = mongo.get_wishes_collection()

    wish_to_delete = wishes_col.find_one({"_id": ObjectId(wish_id), "user_id": user_id})
    if not wish_to_delete:
        raise HTTPException(status_code=404, detail="Wish not found or access denied")

    wishes_col.delete_one({"_id": ObjectId(wish_id)})

    cypher_query = """
    MATCH (u:User {id: $user_id})-[r:HAS]->(w:Wish {url: $url})
    DELETE r
    """
    neo4j_graph.execute_write(cypher_query, {"user_id": user_id, "url": wish_to_delete["url"]})

    redis_cache.invalidate(f"wl:{user_id}")
    redis_cache.invalidate(f"reco:{user_id}")

    return {"status": "success", "message": f"Wish {wish_id} deleted."}