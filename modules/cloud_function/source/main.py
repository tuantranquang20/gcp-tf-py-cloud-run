import functions_framework
import google.auth
import google.auth.transport.requests
import requests
import os
import re
import json

PROJECT_ID             = os.environ.get("PROJECT_ID")
REGION                 = os.environ.get("REGION", "asia-southeast1")
CLOUD_BUILD_TRIGGER_ID = os.environ.get("CLOUD_BUILD_TRIGGER_ID")

@functions_framework.cloud_event
def trigger_build(cloud_event):
    data      = cloud_event.data
    bucket    = data.get("bucket", "")
    file_name = data.get("name", "")

    print(f"[INFO] Event: gs://{bucket}/{file_name}")

    if not file_name.startswith("releases/") or not file_name.endswith(".zip"):
        print(f"[SKIP] Not a release artifact: {file_name}")
        return

    match   = re.search(r"app-(.+)\.zip$", file_name)
    version = match.group(1) if match else "unknown"

    print(f"[INFO] Triggering build for version: {version}")

    try:
        credentials, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
        auth_req = google.auth.transport.requests.Request()
        credentials.refresh(auth_req)
        token = credentials.token

        # Dùng GLOBAL endpoint (không có /locations/region/)
        # Global endpoint nhận RepoSource trực tiếp trong body
        url = (
            f"https://cloudbuild.googleapis.com/v1/"
            f"projects/{PROJECT_ID}/"
            f"triggers/{CLOUD_BUILD_TRIGGER_ID}:run"
        )

        # Body là RepoSource object trực tiếp — không wrap trong "source"
        body = {
            "branchName": "main",
            "substitutions": {
                "_VERSION":  version,
                "_BUCKET":   bucket,
                "_ZIP_FILE": file_name,
            }
        }

        response = requests.post(
            url,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type":  "application/json",
            },
            data=json.dumps(body),
        )

        print(f"[DEBUG] Status: {response.status_code}")
        print(f"[DEBUG] Response: {response.text}")

        response.raise_for_status()
        result   = response.json()
        build_id = result.get("metadata", {}).get("build", {}).get("id", "N/A")
        print(f"[SUCCESS] Build triggered. ID: {build_id}")

    except requests.exceptions.HTTPError as e:
        print(f"[ERROR] HTTP {e.response.status_code}: {e.response.text}")
        raise e
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        raise e
