import os
from neo4j import GraphDatabase

class Neo4jClient:
    def __init__(self):
        uri = os.getenv("NEO4J_URI", "bolt://localhost:7687")
        user = os.getenv("NEO4J_USER", "neo4j")
        password = os.getenv("NEO4J_PASSWORD", "testpassword123")
        self.driver = GraphDatabase.driver(uri, auth=(user, password))

    def close(self):
        self.driver.close()

    def execute_write(self, query, parameters=None):
        """Використовується для створення вузлів та зв'язків (CREATE, MERGE, DELETE)"""
        with self.driver.session() as session:
            result = session.run(query, parameters)
            return result.data()

    def execute_read(self, query, parameters=None):
        """Використовується для пошуку рекомендацій та алгоритму Jaccard (MATCH)"""
        with self.driver.session() as session:
            result = session.run(query, parameters)
            return result.data()