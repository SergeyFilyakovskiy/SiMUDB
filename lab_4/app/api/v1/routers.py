# app/api/v1/routers.py
from fastapi import APIRouter

from app.api.v1.endpoints import products, reserve

v1_router = APIRouter(prefix="/api/v1")
v1_router.include_router(products.router)
v1_router.include_router(reserve.router)
