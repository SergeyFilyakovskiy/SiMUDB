# app/api/v2/schemas/products.py
from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime


class ProductCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, description="Название товара")
    sku: str = Field(..., min_length=1, max_length=100, description="Артикул товара (уникальный)")
    category: str = Field(..., min_length=1, max_length=100, description="Категория товара")


class ProductOut(BaseModel):
    id: UUID
    name: str
    sku: str
    category: str
    created_at: datetime

    class Config:
        from_attributes = True


class StockUpdate(BaseModel):
    quantity: int = Field(..., ge=0, description="Количество товара на складе")


class ReserveRequest(BaseModel):
    product_id: UUID
    warehouse_id: UUID
    quantity: int = Field(..., gt=0, description="Количество для резервирования")


class ConfirmOrderRequest(BaseModel):
    order_id: UUID
    user_id: UUID
    product_id: UUID
    warehouse_id: UUID
    quantity: int = Field(..., gt=0)


class AvailabilityResponse(BaseModel):
    product_id: UUID
    warehouse_id: UUID
    total_physical: int = Field(description="Физически есть на складе (Postgres)")
    currently_reserved: int = Field(description="Сейчас в чужих корзинах (Redis)")
    available_to_buy: int = Field(description="Сколько можно купить прямо сейчас")


class OperationResult(BaseModel):
    success: bool
    message: str