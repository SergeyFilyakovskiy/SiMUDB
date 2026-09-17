from datetime import datetime

from pydantic import ConfigDict, BaseModel, Field

class ProductCreate(BaseModel):
    """Schema for product creating."""

    name: str = Field(min_length=1, max_length=200, examples=["TWS heaphones"])
    price: float = Field(gt=0, examples=[99999.99])
    quantity: int = Field(ge=0, examples=[10])
    tags: list[str] = Field(default_factory=list, examples=[["laptops", "glasses"]])

class ProductUpdate(BaseModel):
    """Schema for update product."""
    name: str | None = Field(default=None, min_length=1, max_length=200)
    price: float | None = Field(default=None, gt=0)
    quantity: int | None = Field(default=None, ge=0)
    tags: list[str] | None = None


class ProductOut(BaseModel):
    """Schema with info about product."""
    model_config = ConfigDict(from_attributes=True)

    id: str = Field(alias="id", examples=["65f1a2b3c4d5e6f7g8h9i0j1"])
    name: str
    price: float
    quantity: int
    tags: list[str]
    created_at: datetime
    updated_at: datetime


class ProductListOut(BaseModel):
    """Schema for list of products."""
    items: list[ProductOut]
    total: int = Field(ge=0)
    skip: int = Field(ge=0)
    limit: int = Field(ge=1, le=100)
