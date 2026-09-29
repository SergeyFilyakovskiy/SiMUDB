
from typing import List
from uuid import UUID
from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo.errors import DuplicateKeyError

from app.v2.mongo.models import InventoryEvent

class MongoEventRepository:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db
        self.collection = db["inventory_events"]

    async def save_event(self, event: InventoryEvent) -> bool:
        """Сохраняет событие. Возвращает False, если оно уже есть (идемпотентность)."""
        try:
            event_dict = event.model_dump(mode="json")
            await self.collection.insert_one(event_dict)
            return True
        except DuplicateKeyError:
            return False
        except Exception as e:
            print(f"Mongo save error: {e}")
            raise e