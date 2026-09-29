# app/infrastructure/mongo/product_quantity_service.py
from __future__ import annotations

from beanie import PydanticObjectId
from fastapi import HTTPException, status

from .documents import Product


class ProductQuantityService:
    """Сервис для работы с количеством товаров."""

    async def get_quantity(self, product_id: PydanticObjectId) -> int:
        """Получить текущее количество товара на складе."""
        product = await Product.get(product_id)
        if not product:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Product {product_id} not found",
            )
        return product.quantity

    async def decrease_quantity(
        self,
        product_id: PydanticObjectId,
        amount: int,
    ) -> int:
        """
        Уменьшить количество товара на складе.
        Возвращает новое количество.
        """
        product = await Product.get(product_id)
        if not product:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Product {product_id} not found",
            )

        if product.quantity < amount:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient quantity. Available: {product.quantity}, requested: {amount}",
            )

        product.quantity -= amount
        await product.save()
        return product.quantity

    async def increase_quantity(
        self,
        product_id: PydanticObjectId,
        amount: int,
    ) -> int:
        """
        Увеличить количество товара на складе.
        Возвращает новое количество.
        """
        product = await Product.get(product_id)
        if not product:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Product {product_id} not found",
            )

        product.quantity += amount
        await product.save()
        return product.quantity