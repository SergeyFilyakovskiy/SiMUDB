# app/api/v1/endpoints/reserve.py
from typing import Annotated
from uuid import UUID

from beanie import PydanticObjectId
from fastapi import APIRouter, Depends, HTTPException, status

from app.api.v1.schemas.reserve import (
    CancelAllResult,
    CancelResult,
    ReserveCancel,
    ReserveCreate,
    ReserveResult,
    UserReservations,
)
from app.core.dependencies import get_reserve_service
from app.infrastructure.services.reserve_service import ReserveService

router = APIRouter(prefix="/reserve", tags=["reserve"])


@router.post(
    "/",
    response_model=ReserveResult,
    summary="Зарезервировать товар",
)
async def reserve_product(
    payload: ReserveCreate,
    user_id: UUID,
    reserve_service: ReserveService = Depends(get_reserve_service),
) -> ReserveResult:
    """Резервирует товар для пользователя."""
    product_id = PydanticObjectId(payload.product_id)
    
    try:
        result = await reserve_service.reserve(
            user_id=user_id,
            product_id=product_id,
            quantity=payload.quantity,
            ttl=payload.ttl,
        )
        return ReserveResult(**result)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.delete(
    "/",
    response_model=CancelResult,
    summary="Отменить резерв товара",
)
async def cancel_reserve(
    payload: ReserveCancel,
    user_id: UUID,
    reserve_service: ReserveService = Depends(get_reserve_service),
) -> CancelResult:
    """Отменяет резерв товара."""
    product_id = PydanticObjectId(payload.product_id)
    
    try:
        result = await reserve_service.cancel_reserve(
            user_id=user_id,
            product_id=product_id,
            quantity=payload.quantity,
        )
        return CancelResult(**result)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get(
    "/{user_id}",
    response_model=UserReservations,
    summary="Получить резервы пользователя",
)
async def get_user_reservations(
    user_id: UUID,
    reserve_service: ReserveService = Depends(get_reserve_service),
) -> UserReservations:
    """Возвращает все резервы пользователя."""
    result = await reserve_service.get_user_reservations(user_id)
    return UserReservations(**result)


@router.delete(
    "/{user_id}/all",
    response_model=CancelAllResult,
    summary="Отменить все резервы пользователя",
)
async def cancel_all_reservations(
    user_id: UUID,
    reserve_service: ReserveService = Depends(get_reserve_service),
) -> CancelAllResult:
    """Отменяет все резервы пользователя."""
    result = await reserve_service.cancel_all_reservations(user_id)
    return CancelAllResult(**result)