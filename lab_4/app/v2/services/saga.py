# app/v2/services/saga.py
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from motor.motor_asyncio import AsyncIOMotorDatabase
from redis.asyncio import Redis

from app.v2.postgres.repositories.inventory import InventoryRepository
from app.v2.mongo.repositories.events import MongoEventRepository
from app.v2.redis.repositories.reservations import RedisReservationRepository
from app.v2.mongo.models import InventoryEvent, EventType

class OrderConfirmationSaga:
    """
    Saga подтверждения заказа.
    Выполняет шаги последовательно. Если шаг падает, запускает компенсирующие действия.
    """
    
    def __init__(
        self, 
        pg_session: AsyncSession, 
        mongo_db: AsyncIOMotorDatabase, 
        redis_client: Redis
    ):
        self.pg_repo = InventoryRepository(pg_session)
        self.mongo_repo = MongoEventRepository(mongo_db)
        self.redis_repo = RedisReservationRepository(redis_client)
        self.pg_session = pg_session

    async def execute(
        self, 
        order_id: UUID,
        user_id: UUID, 
        product_id: UUID, 
        warehouse_id: UUID, 
        quantity: int
    ) -> bool:
        
        # ШАГ 1: Уменьшаем физический остаток в PostgreSQL
        print(f"[Saga] Step 1: Decreasing stock in Postgres...")
        stock_decreased = await self.pg_repo.decrease_stock(product_id, warehouse_id, quantity)
        
        if not stock_decreased:
            # Товара не хватило или его нет. Откат не нужен, просто фейл.
            await self.pg_session.rollback()
            raise ValueError("Insufficient stock in warehouse")
            
        # Коммитим транзакцию Postgres
        await self.pg_session.commit()

        try:
            # ШАГ 2: Записываем событие в MongoDB (Event Sourcing)
            print(f"[Saga] Step 2: Saving event to MongoDB...")
            event = InventoryEvent(
                event_type=EventType.STOCK_DECREASED,
                product_id=product_id,
                warehouse_id=warehouse_id,
                quantity=-quantity,
                metadata={"order_id": str(order_id), "user_id": str(user_id)}
            )
            await self.mongo_repo.save_event(event)

        except Exception as e:
            # MongoDB упала! Запускаем КОМПЕНСАЦИЮ Шага 1
            print(f"[Saga] Step 2 failed! Compensating Step 1... Error: {e}")
            await self._compensate_stock_decrease(product_id, warehouse_id, quantity)
            raise RuntimeError("Failed to save event, stock restored")

        try:
            # ШАГ 3: Удаляем резерв из Redis
            print(f"[Saga] Step 3: Removing reservation from Redis...")
            await self.redis_repo.remove_product_from_reserve(user_id, product_id, warehouse_id, quantity)
            
        except Exception as e:
            # Redis упал. 
            # Постгрес уже списал товар, Монго записала событие. 
            # Мы не можем "отменить" продажу, поэтому просто логируем.
            # В проде здесь был бы алерт и фоновый воркер, который почистит Redis.
            print(f"[Saga] Step 3 failed! Manual intervention required. Error: {e}")
            # Не рейзим ошибку, так как бизнес-операция (продажа) по факту успешна.

        print(f"[Saga] Successfully completed for order {order_id}")
        return True

    async def _compensate_stock_decrease(self, product_id: UUID, warehouse_id: UUID, quantity: int):
        """Компенсирующая транзакция для Postgres."""
        try:
            await self.pg_repo.increase_stock(product_id, warehouse_id, quantity)
            await self.pg_session.commit()
            print("[Saga] Compensation successful: stock restored in Postgres.")
        except Exception as comp_error:
            # Если даже компенсация упала - это критическая ошибка (рассинхрон).
            print(f"[Saga] CRITICAL: Compensation failed! {comp_error}")