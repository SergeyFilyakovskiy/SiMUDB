# app/db/postgres/models.py
import uuid
from datetime import datetime
from sqlalchemy import String, Integer, ForeignKey, UniqueConstraint, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.ext.asyncio import AsyncAttrs

class Base(DeclarativeBase, AsyncAttrs):

    __abstract__ = True

class Product(Base):
    """Каталог товаров."""
    __tablename__ = "products"
    
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), 
        primary_key=True, 
        default=uuid.uuid4
        )
    
    name: Mapped[str] = mapped_column(
        String(255), 
        nullable=False
        )
    
    sku: Mapped[str] = mapped_column(
        String(100), 
        unique=True, 
        nullable=False, 
        index=True
        )

    category: Mapped[str] = mapped_column(
        String(100), 
        nullable=False, 
        index=True
        )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        )

class Warehouse(Base):
    """Справочник складов."""

    __tablename__ = "warehouses"
    
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), 
        primary_key=True, 
        default=uuid.uuid4
        )
    
    name: Mapped[str] = mapped_column(
        String(255), 
        nullable=False
        )
    
    location: Mapped[str] = mapped_column(
        String(255), 
        nullable=False
        )

class WarehouseStock(Base):
    """Фактические остатки товаров на складах."""

    __tablename__ = "warehouse_stock"
    
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), 
        primary_key=True, 
        default=uuid.uuid4
        )
    
    warehouse_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), 
        ForeignKey("warehouses.id"), 
        nullable=False
        )
    
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), 
        ForeignKey("products.id"),
        nullable=False
        )
    
    quantity: Mapped[int] = mapped_column(
        Integer, 
        nullable=False, 
        default=0
        )

    __table_args__ = (
        UniqueConstraint('warehouse_id', 'product_id', name='_warehouse_product_uc'),
    )
    