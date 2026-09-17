# app/infrastructure/services/reserve_service.py
from __future__ import annotations

from uuid import UUID

from beanie import PydanticObjectId

from app.infrastructure.cache.reserve import RedisReserveProduct
from app.infrastructure.mongo.product_quantity_service import ProductQuantityService


class ReserveService:
    """Бизнес-логика резервирования товаров."""

    def __init__(
        self,
        reserve_repo: RedisReserveProduct,
        quantity_service: ProductQuantityService,
    ) -> None:
        self.reserve_repo = reserve_repo
        self.quantity_service = quantity_service

    async def reserve(
        self,
        user_id: UUID,
        product_id: PydanticObjectId,
        quantity: int,
        ttl: int = 3600,
    ) -> dict:
        """
        Зарезервировать товар.
        1. Проверяем наличие на складе
        2. Уменьшаем количество на складе
        3. Добавляем в резерв
        """
        # Проверяем, что товара достаточно
        available = await self.quantity_service.get_quantity(product_id)
        if available < quantity:
            raise ValueError(
                f"Insufficient quantity. Available: {available}, requested: {quantity}"
            )

        try:
            # Уменьшаем количество на складе
            new_quantity = await self.quantity_service.decrease_quantity(
                product_id, quantity
            )

            # Добавляем в резерв
            await self.reserve_repo.reserve_product(
                user_id, product_id, ttl, quantity
            )

            return {
                "product_id": str(product_id),
                "reserved_quantity": quantity,
                "remaining_quantity": new_quantity,
            }
        except Exception:
            # Если что-то пошло не так, откатываем изменения на складе
            await self.quantity_service.increase_quantity(product_id, quantity)
            raise

    async def cancel_reserve(
        self,
        user_id: UUID,
        product_id: PydanticObjectId,
        quantity: int,
    ) -> dict:
        """
        Отменить резерв товара.
        1. Убираем из резерва
        2. Возвращаем количество на склад
        """
        # Проверяем, что товар в резерве
        reserved = await self.reserve_repo.get_reserved_quantity(
            user_id, product_id
        )
        if reserved < quantity:
            raise ValueError(
                f"Cannot cancel. Reserved: {reserved}, requested to cancel: {quantity}"
            )

        # Убираем из резерва
        new_reserved = await self.reserve_repo.remove_product_from_reserve(
            user_id, product_id, quantity
        )

        # Возвращаем на склад
        new_quantity = await self.quantity_service.increase_quantity(
            product_id, quantity
        )

        return {
            "product_id": str(product_id),
            "cancelled_quantity": quantity,
            "remaining_reserved": new_reserved,
            "available_quantity": new_quantity,
        }

    async def get_user_reservations(self, user_id: UUID) -> dict:
        """Получить все резервы пользователя."""
        reservations = await self.reserve_repo.get_user_reservations(user_id)
        return {"user_id": str(user_id), "reservations": reservations}

    async def cancel_all_reservations(self, user_id: UUID) -> dict:
        """Отменить все резервы пользователя."""
        reservations = await self.reserve_repo.get_user_reservations(user_id)

        cancelled_items = []
        for product_id_str, quantity in reservations.items():
            product_id = PydanticObjectId(product_id_str)
            
            # Возвращаем на склад
            await self.quantity_service.increase_quantity(product_id, quantity)
            
            cancelled_items.append(
                {"product_id": product_id_str, "quantity": quantity}
            )

        # Очищаем резервы
        await self.reserve_repo.clear_user_reservations(user_id)

        return {
            "user_id": str(user_id),
            "cancelled_items": cancelled_items,
        }