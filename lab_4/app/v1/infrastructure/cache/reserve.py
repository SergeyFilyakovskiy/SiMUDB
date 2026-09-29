# app/infrastructure/cache/reserve.py
from __future__ import annotations

from typing import Dict

from beanie import PydanticObjectId
from redis.asyncio import Redis

from uuid import UUID


class RedisReserveProduct:
    """Сервис для работы с резервами в Redis."""

    def __init__(self, redis: Redis) -> None:
        self.redis = redis

    @staticmethod
    def _cart_key(user_id: UUID) -> str:
        """Ключ для корзины пользователя."""
        return f"cart:{user_id}"

    async def reserve_product(
        self,
        user_id: UUID,
        product_id: PydanticObjectId,
        ttl: int,
        quantity: int,
    ) -> bool:
        """
        Зарезервировать товар для пользователя.
        TTL в секундах.
        """
        key = self._cart_key(user_id)

        # Используем pipeline для атомарности
        pipe = self.redis.pipeline()
        pipe.hincrby(key, str(product_id), quantity)
        pipe.expire(key, ttl)
        await pipe.execute()

        return True

    async def remove_product_from_reserve(
        self,
        user_id: UUID,
        product_id: PydanticObjectId,
        quantity: int,
    ) -> int:
        """
        Убрать товар из резерва.
        Возвращает новое количество в резерве (0 если товара больше нет).
        """
        key = self._cart_key(user_id)

        pipe = self.redis.pipeline()
        pipe.hincrby(key, str(product_id), -quantity)
        results = await pipe.execute()

        new_quantity = results[0]

        if new_quantity <= 0:
            await self.redis.hdel(key, str(product_id))
            return 0

        return new_quantity

    async def get_user_reservations(
        self,
        user_id: UUID,
    ) -> Dict[str, int]:
        """
        Получить все резервы пользователя.
        Возвращает словарь {product_id: quantity}.
        """
        key = self._cart_key(user_id)
        raw_data = await self.redis.hgetall(key)

        return {
            k.decode("utf-8"): int(v)  # pyright: ignore[reportAttributeAccessIssue]
            for k, v in raw_data.items()
        }

    async def clear_user_reservations(self, user_id: UUID) -> None:
        """Очистить все резервы пользователя."""
        await self.redis.delete(self._cart_key(user_id))

    async def get_reserved_quantity(
        self,
        user_id: UUID,
        product_id: PydanticObjectId,
    ) -> int:
        """Получить количество конкретного товара в резерве."""
        key = self._cart_key(user_id)
        quantity = await self.redis.hget(key, str(product_id))
        return int(quantity) if quantity else 0