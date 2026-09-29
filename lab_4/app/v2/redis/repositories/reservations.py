from uuid import UUID

from redis.asyncio import Redis


class RedisReservationRepository:
    def __init__(self, redis: Redis):
        self.redis = redis

    @staticmethod
    def _cart_key(user_id: UUID) -> str:
        return f"cart:{user_id}"

    @staticmethod
    def _product_reserve_key(product_id: UUID, warehouse_id: UUID) -> str:
        return f"product_reserves:{warehouse_id}:{product_id}"

    async def reserve_product(
        self,
        user_id: UUID,
        product_id: UUID,
        warehouse_id: UUID,
        quantity: int,
        ttl: int = 900,
    ) -> None:
        """Добавить товар в корзину пользователя и увеличить глобальный счётчик резервов."""
        cart_key = self._cart_key(user_id)
        product_key = self._product_reserve_key(product_id, warehouse_id)
        field = f"{warehouse_id}:{product_id}"

        await self.redis.hincrby(cart_key, field, quantity)
        await self.redis.expire(cart_key, ttl)
        await self.redis.incrby(product_key, quantity)

    async def remove_product_from_reserve(
        self,
        user_id: UUID,
        product_id: UUID,
        warehouse_id: UUID,
        quantity: int,
    ) -> None:
        """Убрать товар из корзины и уменьшить глобальный счётчик резервов."""
        cart_key = self._cart_key(user_id)
        product_key = self._product_reserve_key(product_id, warehouse_id)
        field = f"{warehouse_id}:{product_id}"

        await self.redis.hincrby(cart_key, field, -quantity)
        await self.redis.decrby(product_key, quantity)

    async def get_reserved_quantity(self, product_id: UUID, warehouse_id: UUID) -> int:
        """Сколько товара сейчас зарезервировано ВСЕМИ пользователями."""
        value = await self.redis.get(self._product_reserve_key(product_id, warehouse_id))
        return int(value) if value else 0