import functions_framework
import os
import re
import yaml
import zipfile
from google.cloud import storage
from google.cloud.devtools import cloudbuild_v1

project_id = os.environ.get("PROJECT_ID")
region = os.environ.get("REGION", "asia-southeast1")
service_name = os.environ.get("SERVICE_NAME", "my-app")
repo_name = os.environ.get("REPO_NAME", "myapp-repo")

def camel_to_snake(obj):
    if isinstance(obj, list):
        return [camel_to_snake(i) for i in obj]
    elif isinstance(obj, dict):
        new_dict = {}
        for k, v in obj.items():
            # Chuyển đổi key (VD: 'waitFor' -> 'wait_for', 'machineType' -> 'machine_type')
            new_key = re.sub(r'(?<!^)(?=[A-Z])', '_', k).lower()
            new_dict[new_key] = camel_to_snake(v)
        return new_dict
    else:
        return obj

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

        # 2. Đọc và parse file cloudbuild.yaml từ bên trong file zip
        with zipfile.ZipFile(local_zip_path, 'r') as zip_ref:
            yaml_content = zip_ref.read('cloudbuild.yaml')  # Hoặc codebuild.yaml tùy tên bạn đặt
            raw_build_config = yaml.safe_load(yaml_content)
        
        build_config = camel_to_snake(raw_build_config)
        
        # 3. Gắn source trỏ đến file zip vừa được push lên GCS
        build_config['source'] = {
            'storage_source': {
                'bucket': bucket,
                'object': file_name
            }
        }

        # 4. Gắn các biến substitutions như thiết kế cũ của bạn
        build_config['substitutions'] = {
            "_VERSION":   version,
            "_BUCKET":    bucket,
            "_REGION":    region,
            "_SERVICE":   service_name,
            "_REPO_NAME": repo_name
        }

        # 5. Khởi tạo Cloud Build Job bằng Python SDK
        build_client = cloudbuild_v1.CloudBuildClient()
        
        # Nếu dùng location cụ thể (ví dụ asia-southeast1), sử dụng tham số parent
        # Nếu dùng global, parent = f"projects/{PROJECT_ID}/locations/global"
        parent = f"projects/{project_id}/locations/{region}"

        print("[INFO] Submitting build to Cloud Build...")
        operation = build_client.create_build(
            parent=parent,
            project_id=project_id,
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
