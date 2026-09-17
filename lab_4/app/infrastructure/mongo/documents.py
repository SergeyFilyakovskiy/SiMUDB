from beanie import Document


class Product(Document):

    name: str
    price: float
    quantity: int
    tags: list[str] = []

    class Settings:
        name = "products"
