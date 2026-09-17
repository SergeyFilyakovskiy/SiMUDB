# app/api/v1/schemas/reserve.py
from datetime import datetime
from typing import Dict
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ReserveCreate(BaseModel):
    """Схема для создания резерва."""
    product_id: str = Field(examples=["65f1a2b3c4d5e6f7g8h9i0j1"])
    quantity: int = Field(gt=0, examples=[5])
    ttl: int = Field(default=3600, gt=0, description="TTL в секундах", examples=[3600])


class ReserveCancel(BaseModel):
    """Схема для отмены резерва."""
    product_id: str = Field(examples=["65f1a2b3c4d5e6f7g8h9i0j1"])
    quantity: int = Field(gt=0, examples=[2])


class ReserveResult(BaseModel):
    """Результат операции резервирования."""
    model_config = ConfigDict(from_attributes=True)

    product_id: str
    reserved_quantity: int
    remaining_quantity: int


class CancelResult(BaseModel):
    """Результат отмены резерва."""
    model_config = ConfigDict(from_attributes=True)

    product_id: str
    cancelled_quantity: int
    remaining_reserved: int
    available_quantity: int


class UserReservations(BaseModel):
    """Резервы пользователя."""
    user_id: str
    reservations: Dict[str, int]


class CancelledItem(BaseModel):
    """Отменённый товар."""
    product_id: str
    quantity: int


class CancelAllResult(BaseModel):
    """Результат отмены всех резервов."""
    user_id: str
    cancelled_items: list[CancelledItem]