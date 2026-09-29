
from datetime import datetime

from beanie import Document
from pymongo import IndexModel


class Product(Document):
    name: str
    price: float
    quantity: int
    tags: list[str] = []
    created_at: datetime
    updated_at: datetime

    class Settings:
        name = "products"
        indexes = [
            [("name", 1)], 
            [("tags", 1)],
            [("quantity", 1)],
            [("created_at", -1)],
            [("tags", 1), ("quantity", -1)], 
            IndexModel([("price", -1)], name="price_desc"),
            "name",
        ]