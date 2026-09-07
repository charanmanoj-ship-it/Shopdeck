import os

from strands.models.openai import OpenAIModel
from bedrock_agentcore.identity.auth import requires_api_key

IDENTITY_PROVIDER_NAME = ""
IDENTITY_ENV_VAR = "OPENAI_API_KEY"


@requires_api_key(provider_name=IDENTITY_PROVIDER_NAME)
def _agentcore_identity_api_key_provider(api_key: str) -> str:
    """Fetch API key from AgentCore Identity."""
    return api_key


def _get_api_key() -> str:
    """
    Uses AgentCore Identity for API key management in deployed environments.
    For local development, run via 'agentcore dev' which loads agentcore/.env.local.
    OPENAI_API_KEY in the environment is always accepted so local invokes work.
    """
    api_key = os.getenv("OPENAI_API_KEY") or os.getenv(IDENTITY_ENV_VAR)
    if api_key:
        return api_key
    if os.getenv("LOCAL_DEV") == "1":
        raise RuntimeError(
            f"{IDENTITY_ENV_VAR} not found. Add {IDENTITY_ENV_VAR}=your-key to agentcore/.env.local"
        )
    return _agentcore_identity_api_key_provider()


def load_model() -> OpenAIModel:
    """Get authenticated OpenAI model client."""
    return OpenAIModel(
        client_args={"api_key": _get_api_key()},
        model_id="gpt-4.1",
    )
