
from pydantic import BaseModel, Field
from uuid import UUID, uuid4
from datetime import datetime
from enum import Enum

class EventType(str, Enum):
    STOCK_RECEIVED = "STOCK_RECEIVED"
    PRODUCT_RESERVED = "PRODUCT_RESERVED"
    RESERVATION_CANCELLED = "RESERVATION_CANCELLED"
    STOCK_DECREASED = "STOCK_DECREASED"

class InventoryEvent(BaseModel):
    event_id: UUID = Field(default_factory=uuid4)
    event_type: EventType
    product_id: UUID
    warehouse_id: UUID
    quantity: int
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    metadata: dict = Field(default_factory=dict)