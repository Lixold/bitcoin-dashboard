# MIT License
#
# Copyright (c) 2026 Daniel Nagel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, subject to the conditions in the LICENSE
# file in the project root.
"""
Shared Cloudflare R2 upload client.

R2 is S3-compatible, so we use boto3 with a custom endpoint URL. Credentials
and the Cloudflare account ID are read from environment variables so the same
code works locally (developer laptop with .env) and in GitHub Actions (secrets).

Environment variables (all required):
    CF_ACCOUNT_ID           — Cloudflare account ID (used in the endpoint URL)
    R2_ACCESS_KEY_ID        — R2 API token, access key part
    R2_SECRET_ACCESS_KEY    — R2 API token, secret key part

The bucket name is fixed (`bitcoin-dashboard-data`) because there is exactly
one bucket per project; making it configurable would only invite typos.
"""

from __future__ import annotations

import json
import logging
import os
from typing import Any

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

# Fixed bucket — see ADR-003. Public read access is configured at the
# Cloudflare side via a custom domain (data.bitcoin-dashboard.app).
BUCKET_NAME = "bitcoin-dashboard-data"

# 15 minutes matches the most aggressive refresh cadence (market data,
# news). Files refreshed less frequently are still safe to cache for 15
# minutes; clients can override via query strings if needed.
DEFAULT_CACHE_CONTROL = "public, max-age=900"
DEFAULT_CONTENT_TYPE = "application/json"

log = logging.getLogger(__name__)


class R2ConfigError(RuntimeError):
    """Raised when required R2 environment variables are missing."""


def _build_client():
    """Create a boto3 S3 client pointing at the Cloudflare R2 endpoint."""
    account_id = os.environ.get("CF_ACCOUNT_ID")
    access_key = os.environ.get("R2_ACCESS_KEY_ID")
    secret_key = os.environ.get("R2_SECRET_ACCESS_KEY")

    missing = [
        name
        for name, value in (
            ("CF_ACCOUNT_ID", account_id),
            ("R2_ACCESS_KEY_ID", access_key),
            ("R2_SECRET_ACCESS_KEY", secret_key),
        )
        if not value
    ]
    if missing:
        raise R2ConfigError(
            f"Missing required environment variables: {', '.join(missing)}"
        )

    endpoint_url = f"https://{account_id}.r2.cloudflarestorage.com"

    # `auto` is the canonical region for R2; signature v4 is required.
    return boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name="auto",
        config=Config(signature_version="s3v4", retries={"max_attempts": 3}),
    )


def upload_json(
    key: str,
    data: Any,
    *,
    cache_control: str = DEFAULT_CACHE_CONTROL,
    content_type: str = DEFAULT_CONTENT_TYPE,
) -> None:
    """
    Serialize `data` to JSON and upload it to R2 under the given key.

    Args:
        key: Object key inside the bucket (e.g. ``data/history-1D.json``).
        data: Any JSON-serializable Python object.
        cache_control: HTTP `Cache-Control` header. CDN respects this.
        content_type: HTTP `Content-Type` header.

    Raises:
        R2ConfigError:  If credentials are missing.
        ClientError:    If the upload itself fails (network, auth, quota).
    """
    body = json.dumps(data, separators=(",", ":"), ensure_ascii=False).encode(
        "utf-8"
    )

    client = _build_client()
    try:
        client.put_object(
            Bucket=BUCKET_NAME,
            Key=key,
            Body=body,
            ContentType=content_type,
            CacheControl=cache_control,
        )
    except (BotoCoreError, ClientError) as exc:
        # Re-raise so callers (and GitHub Actions) see a non-zero exit, but
        # log a structured line first so failures are easy to diagnose.
        log.error("R2 upload failed for key=%s: %s", key, exc)
        raise

    log.info("Uploaded %d bytes to r2://%s/%s", len(body), BUCKET_NAME, key)
