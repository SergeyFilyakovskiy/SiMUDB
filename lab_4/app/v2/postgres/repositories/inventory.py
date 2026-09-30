import sqlalchemy as sa
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.v2.postgres.models import Product, WarehouseStock


class InventoryRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_product(self, product_id: UUID) -> Product | None:
        """Получить товар по ID."""
        stmt = sa.select(Product).where(Product.id == product_id)
        return (await self.session.scalars(stmt)).one_or_none()

    async def get_stock(self, product_id: UUID, warehouse_id: UUID) -> WarehouseStock | None:
        """Получить текущий физический остаток товара на складе."""
        stmt = (
            sa.select(WarehouseStock)
            .where(WarehouseStock.product_id == product_id)
            .where(WarehouseStock.warehouse_id == warehouse_id)
        )
        return (await self.session.scalars(stmt)).one_or_none()

    async def decrease_stock(self, product_id: UUID, warehouse_id: UUID, quantity: int) -> bool:
        """Атомарно уменьшает остаток. Возвращает True при успехе."""
        stmt = (
            sa.update(WarehouseStock)
            .where(WarehouseStock.product_id == product_id)
            .where(WarehouseStock.warehouse_id == warehouse_id)
            .where(WarehouseStock.quantity >= quantity)  # защита от оверселлинга
            .values(quantity=WarehouseStock.quantity - quantity)
            .returning(WarehouseStock.id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none() is not None

    async def increase_stock(self, product_id: UUID, warehouse_id: UUID, quantity: int) -> None:
        """Компенсирующая транзакция: возвращает товар на склад."""
        stmt = (
            sa.update(WarehouseStock)
            .where(WarehouseStock.product_id == product_id)
            .where(WarehouseStock.warehouse_id == warehouse_id)
            .values(quantity=WarehouseStock.quantity + quantity)
        )
        await self.session.execute(stmt)