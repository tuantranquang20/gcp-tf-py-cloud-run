import functions_framework
import os
import re
import yaml
import zipfile
from google.cloud import storage
from google.cloud.devtools import cloudbuild_v1

PROJECT_ID = os.environ.get("PROJECT_ID")
# Khuyến nghị dùng regional build nếu bạn triển khai ở asia-southeast1
REGION = os.environ.get("REGION", "global") 
REPO_NAME = os.environ.get("REPO_NAME", "myapp-repo") 

@functions_framework.cloud_event
def trigger_build(cloud_event):
    data      = cloud_event.data
    bucket    = data.get("bucket", "")
    file_name = data.get("name", "")

    print(f"[INFO] Event: gs://{bucket}/{file_name}")

    if not file_name.startswith("releases/") or not file_name.endswith(".zip"):
        print(f"[SKIP] Not a release artifact: {file_name}")
        return

    # Sửa lại regex: bỏ bớt dấu backslash dư thừa so với code cũ của bạn
    match   = re.search(r"app-(.+)\.zip$", file_name)
    version = match.group(1) if match else "unknown"

    print(f"[INFO] Triggering build for version: {version}")

    local_zip_path = f"/tmp/{os.path.basename(file_name)}"

    try:
        # 1. Tải file zip từ GCS về thư mục tạm
        storage_client = storage.Client()
        gcs_bucket = storage_client.bucket(bucket)
        blob = gcs_bucket.blob(file_name)
        blob.download_to_filename(local_zip_path)

        # 2. Đọc và parse file codebuild.yaml từ bên trong file zip
        with zipfile.ZipFile(local_zip_path, 'r') as zip_ref:
            # Ghi chú: Đảm bảo file yaml nằm ở thư mục gốc trong file zip
            yaml_content = zip_ref.read('codebuild.yaml')
            build_config = yaml.safe_load(yaml_content)

        # 3. Gắn source trỏ đến file zip vừa được push lên GCS
        build_config['source'] = {
            'storage_source': {
                'bucket': bucket,
                'object': file_name
            }
        }

        # 4. Gắn các biến substitutions như thiết kế cũ của bạn
        build_config['substitutions'] = {
            "_VERSION":  version,
            "_BUCKET":   bucket,
            "_REPO_NAME": REPO_NAME
        }

        # 5. Khởi tạo Cloud Build Job bằng Python SDK
        build_client = cloudbuild_v1.CloudBuildClient()
        
        # Nếu dùng location cụ thể (ví dụ asia-southeast1), sử dụng tham số parent
        # Nếu dùng global, parent = f"projects/{PROJECT_ID}/locations/global"
        parent = f"projects/{PROJECT_ID}/locations/{REGION}"

        print("[INFO] Submitting build to Cloud Build...")
        operation = build_client.create_build(
            parent=parent,
            project_id=PROJECT_ID,
            build=build_config
        )

        # Metadata của operation chứa ID của tiến trình build
        build_id = operation.metadata.build.id
        print(f"[SUCCESS] Build triggered successfully. ID: {build_id}")

    except KeyError:
         print("[ERROR] Không tìm thấy file 'codebuild.yaml' trong file zip.")
    except Exception as e:
        print(f"[ERROR] Quá trình trigger thất bại: {str(e)}")
        raise e
    finally:
        # 6. Dọn dẹp file tạm để tránh tràn bộ nhớ (Memory Leak) của Cloud Function
        if os.path.exists(local_zip_path):
            os.remove(local_zip_path)
            print("[DEBUG] Cleaned up temporary zip file.")
