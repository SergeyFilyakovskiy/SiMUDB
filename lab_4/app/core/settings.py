from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic.types import SecretStr
from pydantic import Field
from pathlib import Path

ENV_FILE = Path(__file__).parent.parent / ".env"

class Config(BaseSettings):

    model_config = SettingsConfigDict(
        env_file= ENV_FILE if ENV_FILE.exists() else None,
        case_sensitive=True,
        extra='ignore'
    )

    redis_password: SecretStr = Field(validation_alias='REDIS_PASSWORD')
    redis_host: str = Field(validation_alias='REDIS_HOST')
    redis_port: int = Field(validation_alias='REDIS_PORT')
    redis_db: str = Field(validation_alias='REDIS_DB')

    mongo_password: SecretStr = Field(validation_alias='MONGO_PASSWORD')
    mongo_host: str = Field(validation_alias='MONGO_HOST')
    mongo_port: int = Field(validation_alias='MONGO_PORT')
    mongo_user: str = Field(validation_alias='MONGO_USER')
    mongo_db: str = Field(validation_alias='MONGO_DB')

    @property
    def redis_url(self)-> str:
        return(
            f"redis://{self.redis_password.get_secret_value()}"
            f"@{self.redis_host}:{self.redis_port}/{self.redis_db}"
        )

    @property
    def mongo_url(self)-> str:
        return(
            f"mongodb://{self.mongo_user}:{self.mongo_password.get_secret_value()}"
            f"@{self.mongo_host}:{self.mongo_port}/{self.mongo_db}"
        )
    