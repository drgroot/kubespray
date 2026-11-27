import asyncio
import hmac
import logging
import os
from contextlib import asynccontextmanager
from datetime import timedelta
from pathlib import Path

import httpx
from mcp import ClientSession, StdioServerParameters, types
from mcp.client.stdio import stdio_client
from mcp.client.streamable_http import streamable_http_client
from mcp.server.lowlevel import Server
from mcp.server.streamable_http_manager import StreamableHTTPSessionManager
from mcp.server.transport_security import TransportSecuritySettings
from mcp.shared.exceptions import McpError
from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import PlainTextResponse
from starlette.routing import Route

logger = logging.getLogger(__name__)
secrets = Path(os.environ.get("MCP_SECRET_DIR", "/var/run/mcp-secrets"))
timeout = timedelta(seconds=50)


def read_secret(name: str) -> str:
    value = (secrets / name).read_text().strip()
    if not value:
        raise ValueError(f"Empty credential: {name}")
    return value


@asynccontextmanager
async def gitea_transport():
    server = StdioServerParameters(
        command="gitea-mcp",
        args=["-t", "stdio", "-H", os.environ["GITEA_URL"]],
        env={"GITEA_ACCESS_TOKEN": read_secret("gitea-token"), "HOME": "/tmp"},
    )
    with open(os.devnull, "w") as errlog:
        async with stdio_client(server, errlog=errlog) as streams:
            yield streams


@asynccontextmanager
async def affine_transport():
    async with httpx.AsyncClient(
        headers={"Authorization": f"Bearer {read_secret('affine-mcp-token')}"},
        timeout=httpx.Timeout(timeout.total_seconds(), connect=5),
        trust_env=False,
    ) as client:
        async with streamable_http_client(
            os.environ["AFFINE_MCP_URL"], http_client=client
        ) as (read, write, _):
            yield read, write


transports = {"gitea": gitea_transport, "affine": affine_transport}


@asynccontextmanager
async def upstream(provider):
    try:
        async with asyncio.timeout(timeout.total_seconds()):
            async with transports[provider]() as (read, write):
                async with ClientSession(read, write, read_timeout_seconds=timeout) as session:
                    await session.initialize()
                    yield session
    except Exception as error:
        logger.warning("%s MCP request failed (%s)", provider, type(error).__name__)
        raise McpError(
            types.ErrorData(code=-32000, message=f"{provider} MCP request failed")
        ) from None


async def list_upstream_tools(provider: str) -> list[types.Tool]:
    tools = []
    async with upstream(provider) as session:
        cursor = None
        while True:
            page = await session.list_tools(cursor)
            tools.extend(
                tool.model_copy(update={"name": f"{provider}_{tool.name}"})
                for tool in page.tools
            )
            cursor = page.nextCursor
            if cursor is None:
                return tools


server = Server("onprem-mcp")


@server.list_tools()
async def list_tools() -> list[types.Tool]:
    gitea, affine = await asyncio.gather(
        list_upstream_tools("gitea"), list_upstream_tools("affine")
    )
    return gitea + affine


async def call_tool(request: types.CallToolRequest) -> types.ServerResult:
    provider, _, name = request.params.name.partition("_")
    if provider not in transports or not name:
        raise McpError(types.ErrorData(code=-32602, message="Unknown tool"))
    async with upstream(provider) as session:
        result = await session.send_request(
            types.ClientRequest(
                types.CallToolRequest(
                    params=types.CallToolRequestParams(
                        name=name, arguments=request.params.arguments
                    )
                )
            ),
            types.CallToolResult,
        )
    return types.ServerResult(result)


server.request_handlers[types.CallToolRequest] = call_tool
host = os.environ.get("MCP_HOSTNAME", "mcp.yusufali.ca")
manager = StreamableHTTPSessionManager(
    server,
    stateless=True,
    json_response=True,
    security_settings=TransportSecuritySettings(
        allowed_hosts=[host, f"{host}:443", "localhost:*", "127.0.0.1:*"],
        allowed_origins=[f"https://{host}"],
    ),
)


class AuthenticatedMcp:
    async def __call__(self, scope, receive, send):
        request = Request(scope)
        candidates = request.query_params.getlist("token")
        try:
            expected = read_secret("onprem-mcp-token")
        except (OSError, ValueError):
            await PlainTextResponse("Service unavailable", status_code=503)(scope, receive, send)
            return
        if len(candidates) != 1 or not hmac.compare_digest(
            expected.encode(), candidates[0].encode()
        ):
            await PlainTextResponse("Unauthorized", status_code=401)(scope, receive, send)
            return
        await manager.handle_request({**scope, "query_string": b""}, receive, send)


async def health(request):
    return PlainTextResponse("ok")


async def ready(request):
    try:
        for name in ("onprem-mcp-token", "gitea-token", "affine-mcp-token"):
            read_secret(name)
    except (OSError, ValueError):
        return PlainTextResponse("Credentials unavailable", status_code=503)
    return PlainTextResponse("ok")


@asynccontextmanager
async def lifespan(app):
    async with manager.run():
        yield


app = Starlette(
    routes=[
        Route("/healthz", health),
        Route("/readyz", ready),
        Route("/", AuthenticatedMcp()),
        Route("/mcp", AuthenticatedMcp()),
    ],
    lifespan=lifespan,
)
