# ComfyUI + Flux + PuLID Docker Image

빌드된 이미지: `ghcr.io/woodykim/comfyui-pulid:latest`

RunPod에서 사용:
1. 새 pod 만들 때 Image 필드에 `ghcr.io/woodykim/comfyui-pulid:latest` 입력
2. spawn → ComfyUI + PuLID + 패치 + pip deps 다 박혀있음
3. Flux/LoRA 모델만 별도 다운 (Network Volume에 박는 게 좋음)

검증된 stack:
- ComfyUI 0.18.2 (runpod/comfyui:latest 베이스)
- zhangp365 PuLID 191cd99775 + 4 **kwargs 패치
- pip: facexlib insightface onnxruntime onnxruntime-gpu ftfy timm
