# ComfyUI + Flux + zhangp365 PuLID + 4 검증 패치 = 우리 production stack
# 베이스: runpod/comfyui:latest (ComfyUI 0.18.2)
FROM runpod/comfyui:latest

# 1) zhangp365 PuLID + 4 **kwargs 패치
WORKDIR /workspace/runpod-slim/ComfyUI/custom_nodes
RUN rm -rf ComfyUI-PuLID-Flux \
 && git clone https://github.com/zhangp365/ComfyUI-PuLID-Flux.git \
 && cd ComfyUI-PuLID-Flux \
 && git checkout 191cd99775

# 패치 1: zhangp365 pulidflux.py forward_orig — **kwargs 추가
RUN python3 - <<'EOF'
p = '/workspace/runpod-slim/ComfyUI/custom_nodes/ComfyUI-PuLID-Flux/pulidflux.py'
with open(p) as f: src = f.read()
old = 'attn_mask: Tensor = None,\n    ) -> Tensor:'
new = 'attn_mask: Tensor = None,\n        **kwargs,\n    ) -> Tensor:'
if old in src:
    src = src.replace(old, new, 1)
    with open(p,'w') as f: f.write(src)
    print('[patch1] zhangp365 forward_orig **kwargs APPLIED')
else:
    print('[patch1] signature not found — fork may be different version')
EOF

# 패치 2-4: lldacing pulid 함수들 (runpod-slim 이미지에 기본 설치돼있을 수 있음)
RUN python3 - <<'EOF'
import os, re
base = '/workspace/runpod-slim/ComfyUI/custom_nodes'
patches = [
    ('comfyui_pulid_flux_ll/pulidflux.py', ['pulid_outer_sample_wrappers_with_override','pulid_outer_sample_wrappers']),
    ('comfyui_pulid_flux_ll/PulidFluxHook.py', ['pulid_forward_orig']),
]
for f, fns in patches:
    p = os.path.join(base, f)
    if not os.path.exists(p):
        print(f'[patch] {f} not present (skip)')
        continue
    with open(p) as fp: src = fp.read()
    orig = src
    for fn in fns:
        pat = re.compile(r'(def ' + fn + r'\([^)]+?)(\)\s*(?:->[^:]+)?\s*:)', re.DOTALL)
        def repl(m):
            if '**kwargs' in m.group(1): return m.group(0)
            return m.group(1) + ', **kwargs' + m.group(2)
        src = pat.sub(repl, src)
    if src != orig:
        with open(p,'w') as fp: fp.write(src)
        print(f'[patch] {f} patched')
    else:
        print(f'[patch] {f} no changes')
EOF

# 2) pip 의존성 박음 (stop/start 시 안 날아감 — image layer)
RUN pip install --no-cache-dir facexlib insightface onnxruntime onnxruntime-gpu ftfy timm

# 3) ComfyUI 시작 옵션 미리 환경변수로 (사용자가 override 가능)
ENV COMFYUI_EXTRA_ARGS="--lowvram --disable-smart-memory"

# 4) 검증 표식 (이미지 빌드 확인용)
RUN echo "comfyui-pulid-v1: zhangp365 191cd99775 + 4 kwargs patches + pip deps" > /etc/image-stack.txt

WORKDIR /workspace/runpod-slim/ComfyUI

# 기본 ComfyUI 시작 명령 (runpod/comfyui:latest의 /start.sh가 이미 처리)
CMD ["/start.sh"]
